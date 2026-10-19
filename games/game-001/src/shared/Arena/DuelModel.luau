--!strict
--[[
	Arena/DuelModel — the Crown Arena duel as a pure, deterministic step function (CONTRACTS G12.2, design §5).
	Owner: FORGE-01. No Roblox API, no clock, no randomness: the same setups, inputs and dt give the same duel, so the
	fairness harness (FORGE-05) and the specs simulate thousands of duels headless. DuelService (server) feeds it
	validated, rate-limited actions and the `inRange` / `facing` it derives from real positions.

		DuelModel.new(config?, a: DuellistSetup, b: DuellistSetup, seed: number): DuelState
		DuelModel.step(state, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
			dt must be a finite number > 0; anything else steps nothing, and dt is clamped to 1 s
		DuelModel.view(state, side: "a" | "b") -> { t, hp, stamina, canAct, blocking, opponentHp }
		DuelModel.snapshot(state) -> the public picture of the duel for the HUD and the crowd (no hidden state)
		DuelModel.CONFIG, DuelModel.WEAPONS, DuelModel.ARMOUR     config Duel (rules / weapons / armour)

	`config` is the rules table (config Duel `rules`) or a whole Duel config `{ rules, weapons, armour }`; nil = config Duel.
	DuellistSetup = { weapon: Weapon?, armour: Armour?, modifiers: { Modifier }? }. The modifiers are the support effects
	(Arena/Types Modifier); DuelService passes them through Caps.check first, the model trusts them.
	DuelInput = { action: DuelAction?, inRange: boolean, facing: boolean }. An action is read only when the duellist can
	act (idle), so a held key does nothing extra; anything unknown is ignored.
	DuelEvent = { t, kind, side, data? }, kinds:
		hit        side = the hitter; data { damage (hp), heavy, targetHp, targetHpShare }
		miss, dodged (side = the dodger), parry (side = the parrier), stagger, staminaOut
		heavyWindup  side = the attacker; data { impactAt, warned }
		triggerFired side = who it helps; data { source }
		hype       side = whose crowd meter filled
		ended      side = the winner ("a" | "b" | "draw"); data { winner, loser?, reason = "ko" | "timeCap" | "hardCap" |
		           "draw", hpA, hpB, durationSec }. Defeat is a kneel and a yield (presentation), not a death.
	Support is applied the G12.3 way: passive bonuses all duel; each trigger fires once, never in the first 10 s, when its
	condition first holds; two active triggers on one stat do not stack (the stronger applies); healing is spread over the
	trigger's duration; nothing touches the opponent.
]]

local Duel = require("@game/ReplicatedStorage/Forge/Config/Duel")
local Types = require("./Types")

export type DuelInput = Types.DuelInput
export type DuelEvent = Types.DuelEvent

local DuelModel = {}

local MAX_STEP = 1 -- seconds; the service steps at 1/30 s or so

DuelModel.CONFIG = Duel.rules
DuelModel.WEAPONS = Duel.weapons
DuelModel.ARMOUR = Duel.armour

local ACTIONS = { light = true, heavy = true, block = true, blockEnd = true, parry = true, dodge = true }

local function other(id: string): string
	return if id == "a" then "b" else "a"
end

local function newSide(id: string, setup: any, config: any, weapons: any, armours: any): any
	local weapon = setup.weapon or "swordShield"
	local armour = setup.armour or "medium"
	assert(weapons[weapon], `DuelModel: unknown weapon '{weapon}'`)
	assert(armours[armour], `DuelModel: unknown armour '{armour}'`)
	local side = {
		id = id,
		hp = config.maxHp,
		stamina = config.maxStamina,
		state = "idle",
		timer = 0,
		kind = nil :: string?,
		hits = false,
		weapon = weapon,
		armour = armour,
		passive = { damageReduction = 0, damage = 0, staminaRegen = 0 },
		triggers = {}, -- { source, kind, stat?, magnitude?, duration, condition, earliest?, fired }
		active = {}, -- { stat, magnitude, endsAt }
		heals = {}, -- { rate (HP per second), endsAt }
		warning = nil :: any, -- { lead, usesLeft, endsAt }
		latched = {} :: { [string]: boolean },
		hype = 0,
		lastHitAt = -math.huge,
	}
	local triggerBySource = {}
	for _, m in setup.modifiers or {} do
		if m.kind == "passive" then
			side.passive[m.stat] += m.magnitude
		else
			local trigger = triggerBySource[m.source]
			if trigger == nil then
				trigger = {
					source = m.source,
					condition = m.condition,
					earliest = m.earliest,
					duration = m.duration,
					effects = {},
					fired = false,
				}
				triggerBySource[m.source] = trigger
				table.insert(side.triggers, trigger)
			end
			table.insert(trigger.effects, m)
		end
	end
	return side
end

function DuelModel.new(config: any?, a: any, b: any, seed: number): any
	local cfg = config or Duel
	local rules = cfg.rules or cfg -- the rules table alone, or a whole Duel config
	local weapons = cfg.weapons or Duel.weapons
	local armours = cfg.armour or Duel.armour
	return {
		t = 0,
		seed = seed,
		config = rules,
		weapons = weapons,
		armours = armours,
		a = newSide("a", a, rules, weapons, armours),
		b = newSide("b", b, rules, weapons, armours),
		suddenDeath = false,
		ended = false,
		winner = nil :: string?,
	}
end

local function bonus(state: any, side: any, stat: string): number
	local strongest = 0
	for _, effect in side.active do
		if effect.stat == stat and effect.endsAt > state.t and effect.magnitude > strongest then
			strongest = effect.magnitude
		end
	end
	return side.passive[stat] + strongest
end

local function emit(state: any, events: { DuelEvent }, kind: string, side: string, data: { [string]: any }?)
	table.insert(events, { t = state.t, kind = kind, side = side, data = data })
end

local function spend(state: any, side: any, cost: number, events: { DuelEvent })
	side.stamina = math.max(0, side.stamina - cost)
	if side.stamina <= 0 and not side.latched.staminaOut then
		side.latched.staminaOut = true
		emit(state, events, "staminaOut", side.id)
	end
end

local function addHype(state: any, side: any, amount: number, events: { DuelEvent })
	side.hype += amount
	if side.hype >= 100 then
		side.hype = 0
		side.latched.hype = true
		emit(state, events, "hype", side.id)
	end
end

local function fire(state: any, side: any, trigger: any, events: { DuelEvent })
	trigger.fired = true
	local endsAt = state.t + trigger.duration
	for _, effect in trigger.effects do
		if effect.kind == "trigger" then
			table.insert(side.active, { stat = effect.stat, magnitude = effect.magnitude, endsAt = endsAt })
		elseif effect.kind == "heal" then
			table.insert(
				side.heals,
				{ rate = state.config.maxHp * effect.magnitude / trigger.duration, endsAt = endsAt }
			)
		elseif effect.kind == "telegraph" then
			side.warning = { lead = effect.lead or 0, usesLeft = effect.uses or 1, endsAt = endsAt }
		end
	end
	emit(state, events, "triggerFired", side.id, { source = trigger.source })
end

local function canFire(state: any, trigger: any): boolean
	return not trigger.fired and state.t >= math.max(state.config.quietStart, trigger.earliest or 0)
end

local function conditionHolds(state: any, side: any, condition: string): boolean
	if type(condition) ~= "string" then
		return false -- Caps refuses a trigger without one; a model fed an unchecked setup never fires it, it does not throw
	end
	local threshold = string.match(condition, "^hpBelow:([%d%.]+)$")
	if threshold then
		local limit = tonumber(threshold)
		if limit == nil then
			return false -- "hpBelow:." or "1.2.3" is no number; Caps refuses it, a model fed an unchecked setup never fires it
		end
		if side.hp / state.config.maxHp < limit then
			side.latched[condition] = true
		end
		return side.latched[condition] == true
	end
	return side.latched[condition] == true -- staminaOut, hype
end

-- The defender's telegraph trigger (Called Warning) fires on the opponent's first heavy after the quiet
-- start and shows that heavy and the next ones (uses) earlier, while it lasts.
local function warningFor(state: any, defender: any, events: { DuelEvent }): number
	for _, trigger in defender.triggers do
		if trigger.condition == "opponentHeavy" and canFire(state, trigger) then
			fire(state, defender, trigger, events)
		end
	end
	local warning = defender.warning
	if warning and warning.usesLeft > 0 and state.t < warning.endsAt then
		warning.usesLeft -= 1
		return warning.lead
	end
	return 0
end

local function applyInput(state: any, side: any, input: DuelInput?, events: { DuelEvent })
	if input == nil or input.action == nil or not ACTIONS[input.action] then
		return
	end
	local cfg = state.config
	local action = input.action
	local weapon = state.weapons[side.weapon]
	if action == "light" or action == "heavy" then
		local cost = if action == "heavy" then cfg.heavyCost else cfg.lightCost
		if side.state ~= "idle" or side.stamina < cost then
			return
		end
		spend(state, side, cost, events)
		side.state = "windup"
		side.kind = action
		side.hits = input.inRange == true and input.facing == true
		side.timer = if action == "heavy" then weapon.heavyWindup else weapon.lightWindup
		if action == "heavy" then
			local defender = state[other(side.id)]
			local warned = warningFor(state, defender, events)
			emit(state, events, "heavyWindup", side.id, { impactAt = state.t + side.timer, warned = warned })
		end
	elseif action == "block" then
		if side.state == "idle" then
			side.state = "block"
		end
	elseif action == "blockEnd" then
		if side.state == "block" then
			side.state = "idle"
		end
	elseif action == "parry" then
		if (side.state == "idle" or side.state == "block") and side.stamina >= cfg.parryCost then
			spend(state, side, cfg.parryCost, events)
			side.state = "parry"
			side.timer = cfg.parryWindow
		end
	elseif action == "dodge" then
		local cost = state.armours[side.armour].dodgeCost
		if (side.state == "idle" or side.state == "block") and side.stamina >= cost then
			spend(state, side, cost, events)
			side.state = "dodge"
			side.timer = cfg.dodgeTime
		end
	end
end

local function resolveAttack(state: any, attacker: any, defender: any, events: { DuelEvent })
	local cfg = state.config
	local weapon = state.weapons[attacker.weapon]
	local heavy = attacker.kind == "heavy"
	attacker.state = "recover"
	attacker.timer = if heavy then cfg.heavyRecover else cfg.lightRecover
	if not attacker.hits then
		emit(state, events, "miss", attacker.id)
		return
	end
	if defender.state == "dodge" then
		emit(state, events, "dodged", defender.id)
		return
	end
	if defender.state == "parry" then
		emit(state, events, "parry", defender.id)
		attacker.state = "stagger"
		attacker.timer = cfg.staggerTime
		emit(state, events, "stagger", attacker.id)
		addHype(state, defender, cfg.hypeParry, events)
		return
	end
	local damage = (if heavy then weapon.heavy else weapon.light)
		* (1 + bonus(state, attacker, "damage"))
		* (1 - state.armours[defender.armour].reduction)
		* (1 - bonus(state, defender, "damageReduction"))
	if state.suddenDeath then
		damage *= cfg.suddenDeathDamage
	end
	if defender.state == "block" then
		damage *= state.weapons[defender.weapon].blockFactor
		spend(state, defender, cfg.blockHitCost * weapon.guardDamage, events)
		if defender.stamina <= 0 then
			defender.state = "stagger"
			defender.timer = cfg.guardBreakTime
			emit(state, events, "stagger", defender.id)
		end
	end
	defender.hp -= damage
	emit(state, events, "hit", attacker.id, {
		damage = damage,
		heavy = heavy,
		targetHp = math.max(0, defender.hp),
		targetHpShare = math.max(0, defender.hp) / cfg.maxHp,
	})
	local combo = state.t - attacker.lastHitAt <= cfg.comboWindow
	attacker.lastHitAt = state.t
	addHype(state, attacker, if combo then cfg.hypeCombo else cfg.hypeHit, events)
end

local function advance(state: any, side: any, dt: number, events: { DuelEvent })
	if
		side.state == "windup"
		or side.state == "recover"
		or side.state == "parry"
		or side.state == "dodge"
		or side.state == "stagger"
	then
		side.timer -= dt
		if side.timer <= 1e-9 then
			if side.state == "windup" then
				resolveAttack(state, side, state[other(side.id)], events)
			else
				side.state = "idle"
				side.timer = 0
			end
		end
	end
end

local function regenerate(state: any, side: any, dt: number)
	local cfg = state.config
	if side.state == "idle" or side.state == "recover" or side.state == "stagger" then
		local rate = cfg.staminaRegen * state.armours[side.armour].regen * (1 + bonus(state, side, "staminaRegen"))
		side.stamina = math.min(cfg.maxStamina, side.stamina + rate * dt)
	end
	for _, heal in side.heals do
		if state.t <= heal.endsAt + 1e-9 then
			side.hp = math.min(cfg.maxHp, side.hp + heal.rate * dt)
		end
	end
end

local function evaluateTriggers(state: any, side: any, events: { DuelEvent })
	for _, trigger in side.triggers do
		if
			trigger.condition ~= "opponentHeavy"
			and canFire(state, trigger)
			and conditionHolds(state, side, trigger.condition)
		then
			fire(state, side, trigger, events)
		end
	end
end

local function finish(state: any, winner: string, reason: string, events: { DuelEvent })
	state.ended = true
	state.winner = winner
	state.reason = reason
	emit(state, events, "ended", winner, {
		winner = winner,
		loser = if winner == "draw" then nil else other(winner),
		reason = reason,
		hpA = math.max(0, state.a.hp),
		hpB = math.max(0, state.b.hp),
		durationSec = state.t,
	})
end

function DuelModel.step(state: any, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
	local events: { DuelEvent } = {}
	if state.ended then
		return events
	end
	-- A bad step (NaN, infinite, zero or negative) lets no time pass: a NaN clock would never reach a cap, a negative one
	-- would rewind. A long step is clamped, so one stall cannot end the duel in a single call.
	if not (dt > 0 and dt < math.huge) then
		return events
	end
	dt = math.min(dt, MAX_STEP)
	state.t += dt
	local a, b = state.a, state.b
	applyInput(state, a, inputs.a, events)
	applyInput(state, b, inputs.b, events)
	advance(state, a, dt, events)
	advance(state, b, dt, events)
	regenerate(state, a, dt)
	regenerate(state, b, dt)
	if a.hp > 0 and b.hp > 0 then
		evaluateTriggers(state, a, events)
		evaluateTriggers(state, b, events)
	end

	local cfg = state.config
	if a.hp <= 0 or b.hp <= 0 then
		if a.hp <= 0 and b.hp <= 0 then
			finish(state, "draw", "draw", events)
		else
			finish(state, if a.hp <= 0 then "b" else "a", "ko", events)
		end
	elseif state.t >= cfg.hardCap then
		finish(state, "draw", "hardCap", events)
	elseif state.t >= cfg.timeCap and not state.suddenDeath then
		if math.abs(a.hp - b.hp) > 1e-9 then
			finish(state, if a.hp > b.hp then "a" else "b", "timeCap", events)
		else
			state.suddenDeath = true
		end
	end
	return events
end

function DuelModel.view(state: any, id: string): { [string]: any }
	local side, opponent = state[id], state[other(id)]
	return {
		t = state.t,
		hp = side.hp,
		stamina = side.stamina,
		canAct = side.state == "idle",
		blocking = side.state == "block",
		opponentHp = opponent.hp,
	}
end

-- The public picture of the duel (what the HUD and the crowd may show): no triggers still in reserve, no opponent
-- internals beyond what a spectator sees.
function DuelModel.snapshot(state: any): { [string]: any }
	local function side(s: any): { [string]: any }
		return {
			hp = s.hp,
			hpShare = math.max(0, s.hp) / state.config.maxHp,
			stamina = s.stamina,
			staminaShare = s.stamina / state.config.maxStamina,
			state = s.state,
			hype = s.hype,
			weapon = s.weapon,
			armour = s.armour,
		}
	end
	return {
		t = state.t,
		suddenDeath = state.suddenDeath,
		ended = state.ended,
		winner = state.winner,
		reason = state.reason,
		a = side(state.a),
		b = side(state.b),
	}
end

return DuelModel
