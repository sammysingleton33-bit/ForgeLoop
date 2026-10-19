--!strict
--[[
	DuelDouble — a local stand-in for FORGE-01's DuelModel (CONTRACTS G12.2) so the fairness harness can
	be built and proven before FL-0070 lands (FL-0076, FORGE-05).

		DuelDouble.new(config?, a: DuellistSetup, b: DuellistSetup, seed: number): DuelState
		DuelDouble.step(state, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
		DuelDouble.view(state, side: "a" | "b") -> { t, hp, stamina, canAct, blocking, opponentHp }
		DuelDouble.CONFIG, DuelDouble.WEAPONS, DuelDouble.ARMOUR

	DuellistSetup = { weapon: string?, armour: string?, modifiers: { Modifier }? }  (CapsCheck shape)
	DuelInput     = { action: DuelAction?, inRange: boolean, facing: boolean }   (G12.2)
	DuelEvent     = { t, kind, side, data? }  kinds: hit, miss, dodged, parry, stagger, staminaOut,
	                heavyWindup (data.impactAt, data.warned), triggerFired (data.source), hype, ended (data.winner)

	The numbers are this file's own, not the game's. A result measured with the double says nothing
	about real fairness; it proves that the harness, the caps checks and the bound evaluation work and
	can fail. Support is applied the G12.3 way: passive bonuses all duel; each trigger fires once,
	never in the first 10 s, when its condition first holds; two active triggers on one stat do not
	stack (the stronger applies); healing is spread over the trigger's duration; nothing touches the
	opponent. Deterministic: no randomness inside (the seed is kept for parity with G12.2), so the
	same setups, inputs and dt give the same duel.
]]

local DuelDouble = {}

DuelDouble.CONFIG = table.freeze({
	maxHp = 100,
	maxStamina = 100,
	staminaRegen = 16, -- per second while not attacking, blocking, parrying or dodging
	lightCost = 10,
	heavyCost = 22,
	blockHitCost = 8,
	parryCost = 6,
	parryWindow = 0.25,
	dodgeTime = 0.35,
	staggerTime = 1.0,
	guardBreakTime = 0.8,
	lightRecover = 0.25,
	heavyRecover = 0.5,
	timeCap = 120, -- higher HP wins at the cap; a tie goes to sudden death
	suddenDeathDamage = 1.2,
	hardCap = 180, -- draw
	quietStart = 10,
	hypeParry = 40,
	hypeHit = 10,
	hypeCombo = 15,
	comboWindow = 2,
})

DuelDouble.WEAPONS = table.freeze({
	swordShield = { light = 6, heavy = 14, lightWindup = 0.30, heavyWindup = 0.80, blockFactor = 0.20, guardDamage = 1 },
	greatsword = {
		light = 7,
		heavy = 17,
		lightWindup = 0.36,
		heavyWindup = 0.90,
		blockFactor = 0.35,
		guardDamage = 1.2,
	},
	spear = { light = 6, heavy = 15, lightWindup = 0.26, heavyWindup = 0.80, blockFactor = 0.30, guardDamage = 1 },
	mace = { light = 6, heavy = 16, lightWindup = 0.32, heavyWindup = 0.85, blockFactor = 0.30, guardDamage = 1.5 },
})

DuelDouble.ARMOUR = table.freeze({
	light = { reduction = 0.00, regen = 1.10, dodgeCost = 14 },
	medium = { reduction = 0.06, regen = 1.00, dodgeCost = 18 },
	heavy = { reduction = 0.12, regen = 0.88, dodgeCost = 24 },
})

export type DuelInput = { action: string?, inRange: boolean, facing: boolean }
export type DuelEvent = { t: number, kind: string, side: string, data: { [string]: any }? }

local function other(id: string): string
	return if id == "a" then "b" else "a"
end

local function newSide(id: string, setup: any, config: any): any
	local weapon = setup.weapon or "swordShield"
	local armour = setup.armour or "medium"
	assert(DuelDouble.WEAPONS[weapon], `DuelDouble: unknown weapon '{weapon}'`)
	assert(DuelDouble.ARMOUR[armour], `DuelDouble: unknown armour '{armour}'`)
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

function DuelDouble.new(config: any?, a: any, b: any, seed: number): any
	local cfg = config or DuelDouble.CONFIG
	return {
		t = 0,
		seed = seed,
		config = cfg,
		a = newSide("a", a, cfg),
		b = newSide("b", b, cfg),
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
			side.warning = { lead = effect.lead, usesLeft = effect.uses or 1, endsAt = endsAt }
		end
	end
	emit(state, events, "triggerFired", side.id, { source = trigger.source })
end

local function canFire(state: any, trigger: any): boolean
	return not trigger.fired and state.t >= math.max(state.config.quietStart, trigger.earliest or 0)
end

local function conditionHolds(state: any, side: any, condition: string): boolean
	local threshold = string.match(condition, "^hpBelow:([%d%.]+)$")
	if threshold then
		if side.hp / state.config.maxHp < tonumber(threshold) :: number then
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
	if input == nil or input.action == nil then
		return
	end
	local cfg = state.config
	local action = input.action
	local weapon = DuelDouble.WEAPONS[side.weapon]
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
			emit(
				state,
				events,
				"heavyWindup",
				side.id,
				-- as DuelModel (#250): the windup that starts in this step also spends this step's dt
				{ impactAt = state.t + side.timer - (state.stepDt or 0), warned = warned }
			)
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
		local cost = DuelDouble.ARMOUR[side.armour].dodgeCost
		if (side.state == "idle" or side.state == "block") and side.stamina >= cost then
			spend(state, side, cost, events)
			side.state = "dodge"
			side.timer = cfg.dodgeTime
		end
	end
end

local function resolveAttack(state: any, attacker: any, defender: any, events: { DuelEvent })
	local cfg = state.config
	local weapon = DuelDouble.WEAPONS[attacker.weapon]
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
		* (1 - DuelDouble.ARMOUR[defender.armour].reduction)
		* (1 - bonus(state, defender, "damageReduction"))
	if state.suddenDeath then
		damage *= cfg.suddenDeathDamage
	end
	if defender.state == "block" then
		damage *= DuelDouble.WEAPONS[defender.weapon].blockFactor
		spend(state, defender, cfg.blockHitCost * weapon.guardDamage, events)
		if defender.stamina <= 0 then
			defender.state = "stagger"
			defender.timer = cfg.guardBreakTime
			emit(state, events, "stagger", defender.id)
		end
	end
	defender.hp -= damage
	emit(state, events, "hit", attacker.id, { damage = damage, heavy = heavy })
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
		local rate = cfg.staminaRegen * DuelDouble.ARMOUR[side.armour].regen * (1 + bonus(state, side, "staminaRegen"))
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

local function finish(state: any, winner: string, events: { DuelEvent })
	state.ended = true
	state.winner = winner
	emit(state, events, "ended", winner, { winner = winner })
end

function DuelDouble.step(state: any, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
	local events: { DuelEvent } = {}
	if state.ended then
		return events
	end
	state.t += dt
	state.stepDt = dt
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
			finish(state, "draw", events)
		else
			finish(state, if a.hp <= 0 then "b" else "a", events)
		end
	elseif state.t >= cfg.hardCap then
		finish(state, "draw", events)
	elseif state.t >= cfg.timeCap and not state.suddenDeath then
		if math.abs(a.hp - b.hp) > 1e-9 then
			finish(state, if a.hp > b.hp then "a" else "b", events)
		else
			state.suddenDeath = true
		end
	end
	return events
end

function DuelDouble.view(state: any, id: string): { [string]: any }
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

return DuelDouble
