--[[
	Arena/DuelModel (FL-0071, design §5, CONTRACTS G12.2): the duel as a pure, deterministic step function. Each action's
	rules, the end of a duel (KO, time cap, sudden death, hard cap), the support triggers the way G12.3 applies them,
	determinism, and bad input.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local DuelModel = require("@game/ReplicatedStorage/Game/Arena/DuelModel")

local DT = 0.05

local function input(action: string?, inRange: boolean?, facing: boolean?)
	return { action = action, inRange = inRange ~= false, facing = facing ~= false }
end

local function duel(a: any?, b: any?, config: any?)
	return DuelModel.new(
		config,
		a or { weapon = "swordShield", armour = "medium" },
		b or { weapon = "swordShield", armour = "medium" },
		1
	)
end

-- steps `seconds` of duel time with no input; returns every event
local function idle(state: any, seconds: number): { any }
	local events = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		for _, e in DuelModel.step(state, {}, DT) do
			table.insert(events, e)
		end
	end
	return events
end

local function kinds(events: { any }, kind: string): { any }
	local out = {}
	for _, e in events do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- one input for one step, then idle until `seconds` have passed in total
local function act(state: any, side: string, action: string, seconds: number, extra: any?): { any }
	local inputs = { [side] = input(action) }
	if extra then
		for k, v in extra do
			inputs[k] = v
		end
	end
	local events = DuelModel.step(state, inputs, DT)
	for _, e in idle(state, seconds - DT) do
		table.insert(events, e)
	end
	return events
end

describe("Arena/DuelModel: attacks", function()
	it("a light attack costs stamina, lands after its wind-up and takes the weapon's damage off armour", function()
		local s = duel()
		local before = s.a.stamina
		local events = act(s, "a", "light", 0.5)
		expect(s.a.stamina < before).toBe(true)
		local hits = kinds(events, "hit")
		expect(#hits).toBe(1)
		expect(hits[1].side).toBe("a")
		local expected = DuelModel.WEAPONS.swordShield.light * (1 - DuelModel.ARMOUR.medium.reduction)
		expect(math.abs(hits[1].data.damage - expected) < 1e-9).toBe(true)
		expect(math.abs(s.b.hp - (DuelModel.CONFIG.maxHp - expected)) < 1e-9).toBe(true)
		expect(hits[1].t >= DuelModel.WEAPONS.swordShield.lightWindup - 1e-9).toBe(true)
	end)

	it("a heavy attack is telegraphed (heavyWindup with its impact time) and hits harder", function()
		local s = duel()
		local events = act(s, "a", "heavy", 1.2)
		local windups = kinds(events, "heavyWindup")
		expect(#windups).toBe(1)
		expect(windups[1].data.warned).toBe(0)
		expect(windups[1].data.impactAt > windups[1].t).toBe(true)
		local hit = kinds(events, "hit")[1]
		expect(hit.data.heavy).toBe(true)
		expect(hit.data.damage > DuelModel.WEAPONS.swordShield.light).toBe(true)
	end)

	it("misses when the target is out of range or the attacker is not facing it", function()
		local s = duel()
		local events = DuelModel.step(s, { a = input("light", false, true) }, DT)
		for _, e in idle(s, 0.6) do
			table.insert(events, e)
		end
		expect(#kinds(events, "miss")).toBe(1)
		expect(s.b.hp).toBe(DuelModel.CONFIG.maxHp)
		local s2 = duel()
		local events2 = DuelModel.step(s2, { a = input("heavy", true, false) }, DT)
		for _, e in idle(s2, 1.2) do
			table.insert(events2, e)
		end
		expect(#kinds(events2, "miss")).toBe(1)
		expect(s2.b.hp).toBe(DuelModel.CONFIG.maxHp)
	end)

	it("cannot start an attack without stamina, or while busy (an input mid-swing is ignored)", function()
		local s = duel()
		s.a.stamina = 5
		DuelModel.step(s, { a = input("light") }, DT)
		expect(s.a.state).toBe("idle")
		expect(s.a.stamina < 5 + 1).toBe(true)
		local s2 = duel()
		DuelModel.step(s2, { a = input("light") }, DT)
		local stamina = s2.a.stamina
		DuelModel.step(s2, { a = input("heavy") }, DT) -- mid wind-up: ignored, nothing spent
		expect(s2.a.state).toBe("windup")
		expect(s2.a.kind).toBe("light")
		expect(s2.a.stamina >= stamina).toBe(true)
	end)

	it("armour reduces damage taken: light takes more than heavy", function()
		local takes = {}
		for _, armour in { "light", "medium", "heavy" } do
			local s = duel(nil, { weapon = "swordShield", armour = armour })
			act(s, "a", "heavy", 1.2)
			takes[armour] = DuelModel.CONFIG.maxHp - s.b.hp
		end
		expect(takes.light > takes.medium).toBe(true)
		expect(takes.medium > takes.heavy).toBe(true)
	end)

	it("weapons differ: the greatsword's heavy hits harder than the sword's", function()
		local sword = duel({ weapon = "swordShield" })
		local great = duel({ weapon = "greatsword" })
		act(sword, "a", "heavy", 1.4)
		act(great, "a", "heavy", 1.4)
		expect(sword.b.hp > great.b.hp).toBe(true)
	end)
end)

describe("Arena/DuelModel: defence", function()
	it("a block lets only blockFactor of the damage through and costs stamina", function()
		local s = duel()
		DuelModel.step(s, { b = input("block") }, DT)
		expect(s.b.state).toBe("block")
		local stamina = s.b.stamina
		act(s, "a", "heavy", 1.2)
		local open = duel()
		act(open, "a", "heavy", 1.2)
		local blocked = DuelModel.CONFIG.maxHp - s.b.hp
		local unblocked = DuelModel.CONFIG.maxHp - open.b.hp
		expect(math.abs(blocked - unblocked * DuelModel.WEAPONS.swordShield.blockFactor) < 1e-6).toBe(true)
		expect(s.b.stamina < stamina).toBe(true)
		DuelModel.step(s, { b = input("blockEnd") }, DT)
		expect(s.b.state).toBe("idle")
	end)

	it("a block with no stamina left breaks the guard: a stagger", function()
		local s = duel()
		DuelModel.step(s, { b = input("block") }, DT)
		s.b.stamina = 3
		local events = act(s, "a", "heavy", 1.2)
		expect(#kinds(events, "stagger") >= 1).toBe(true)
		expect(#kinds(events, "staminaOut") >= 1).toBe(true)
	end)

	it("a parry in time costs the attacker a stagger, takes no damage and fills the crowd", function()
		local s = duel()
		DuelModel.step(s, { a = input("heavy") }, DT)
		-- b parries so that the window covers the impact
		idle(s, 0.6)
		DuelModel.step(s, { b = input("parry") }, DT)
		local events = idle(s, 0.5)
		expect(#kinds(events, "parry")).toBe(1)
		expect(s.a.state == "stagger" or s.a.state == "idle").toBe(true)
		expect(s.b.hp).toBe(DuelModel.CONFIG.maxHp)
		expect(s.b.hype >= DuelModel.CONFIG.hypeParry).toBe(true)
	end)

	it("a parry that is too early or too late does not stop the hit", function()
		local late = duel()
		DuelModel.step(late, { a = input("light") }, DT)
		idle(late, 0.5)
		DuelModel.step(late, { b = input("parry") }, DT)
		expect(late.b.hp < DuelModel.CONFIG.maxHp).toBe(true)
		local early = duel()
		DuelModel.step(early, { b = input("parry") }, DT)
		idle(early, 0.4) -- the window (0.25 s) is over before the swing lands
		DuelModel.step(early, { a = input("light") }, DT)
		idle(early, 0.5)
		expect(early.b.hp < DuelModel.CONFIG.maxHp).toBe(true)
	end)

	it("a dodge avoids a hit that lands inside it, and costs the armour's stamina", function()
		local s = duel(nil, { weapon = "swordShield", armour = "heavy" })
		DuelModel.step(s, { a = input("light") }, DT)
		idle(s, 0.15)
		local stamina = s.b.stamina
		DuelModel.step(s, { b = input("dodge") }, DT)
		expect(math.abs(stamina - s.b.stamina - DuelModel.ARMOUR.heavy.dodgeCost) < 1.5).toBe(true) -- minus a little regen
		local events = idle(s, 0.5)
		expect(#kinds(events, "dodged")).toBe(1)
		expect(s.b.hp).toBe(DuelModel.CONFIG.maxHp)
	end)
end)

describe("Arena/DuelModel: the end of a duel", function()
	it("a KO ends it: the other side wins, with a yield (reason ko), once", function()
		local s = duel()
		s.b.hp = 3
		local events = act(s, "a", "light", 0.6)
		local ended = kinds(events, "ended")
		expect(#ended).toBe(1)
		expect(ended[1].data.winner).toBe("a")
		expect(ended[1].data.loser).toBe("b")
		expect(ended[1].data.reason).toBe("ko")
		expect(s.ended).toBe(true)
		expect(#DuelModel.step(s, { a = input("light") }, DT)).toBe(0) -- nothing after the end
	end)

	it("at the time cap the higher HP wins", function()
		local s = duel()
		s.a.hp = 70
		s.b.hp = 40
		local events = idle(s, DuelModel.CONFIG.timeCap + 0.5)
		local ended = kinds(events, "ended")
		expect(ended[1].data.winner).toBe("a")
		expect(ended[1].data.reason).toBe("timeCap")
		expect(ended[1].t >= DuelModel.CONFIG.timeCap - 1e-6).toBe(true)
	end)

	it("a tie at the cap is sudden death: both take +20 % damage, then someone wins", function()
		local s = duel()
		idle(s, DuelModel.CONFIG.timeCap + 0.5)
		expect(s.suddenDeath).toBe(true)
		expect(s.ended).toBe(false)
		local events = act(s, "a", "light", 0.6)
		local hit = kinds(events, "hit")[1]
		local plain = DuelModel.WEAPONS.swordShield.light * (1 - DuelModel.ARMOUR.medium.reduction)
		expect(math.abs(hit.data.damage - plain * DuelModel.CONFIG.suddenDeathDamage) < 1e-9).toBe(true)
		idle(s, 1)
		s.b.hp = 1
		local finish = act(s, "a", "light", 0.8)
		expect(kinds(finish, "ended")[1].data.winner).toBe("a")
	end)

	it("a hard cap with no winner is a draw", function()
		local s = duel()
		idle(s, DuelModel.CONFIG.hardCap + 0.5)
		expect(s.ended).toBe(true)
		expect(s.winner).toBe("draw")
		expect(s.reason).toBe("hardCap")
	end)
end)

-- A support trigger: Reforge-like, +8 % damage reduction for 6 s once HP is below 50 %.
local function reforge()
	return {
		{
			source = "perk:reforge",
			kind = "trigger",
			stat = "damageReduction",
			magnitude = 0.08,
			duration = 6,
			condition = "hpBelow:0.5",
		},
	}
end

describe("Arena/DuelModel: support (CONTRACTS G12.3)", function()
	it("a malformed hpBelow condition never fires and never throws", function()
		for _, condition in { "hpBelow:.", "hpBelow:1.2.3", "hpBelow:" } do
			local s = duel({
				weapon = "swordShield",
				armour = "medium",
				modifiers = {
					{
						source = "perk:reforge",
						kind = "trigger",
						stat = "damageReduction",
						magnitude = 0.08,
						duration = 6,
						condition = condition,
					},
				},
			})
			s.a.hp = 1
			local fired = kinds(idle(s, 12), "triggerFired")
			expect(#fired).toBe(0)
		end
	end)

	it("a trigger never fires in the first 10 seconds, then fires once when its condition holds", function()
		local s = duel({ modifiers = reforge() })
		s.a.hp = 30 -- the condition holds from the start
		local early = idle(s, 9.5)
		expect(#kinds(early, "triggerFired")).toBe(0)
		local later = idle(s, 1)
		local fired = kinds(later, "triggerFired")
		expect(#fired).toBe(1)
		expect(fired[1].side).toBe("a")
		expect(fired[1].data.source).toBe("perk:reforge")
		expect(#kinds(idle(s, 20), "triggerFired")).toBe(0) -- once
	end)

	it("an active trigger lasts only its duration", function()
		local s = duel({ modifiers = reforge() })
		s.a.hp = 30
		idle(s, 10.2)
		local withIt = duel({ modifiers = reforge() })
		withIt.a.hp = 30
		idle(withIt, 10.2)
		-- during the 6 s the hit is softer than after it
		local function takes(state: any)
			local before = state.a.hp
			DuelModel.step(state, { b = input("heavy") }, DT)
			idle(state, 1.2)
			return before - state.a.hp
		end
		local during = takes(s)
		idle(s, 8)
		local after = takes(s)
		expect(during < after).toBe(true)
	end)

	it("passive bonuses apply all duel; two active triggers on one stat do not stack, the stronger applies", function()
		local s = duel({
			modifiers = {
				{ source = "tier:adoring", kind = "passive", stat = "damage", magnitude = 0.05 },
				{
					source = "perk:b",
					kind = "trigger",
					stat = "damage",
					magnitude = 0.10,
					duration = 6,
					condition = "staminaOut",
				},
				{
					source = "perk:a",
					kind = "trigger",
					stat = "damage",
					magnitude = 0.04,
					duration = 6,
					condition = "staminaOut",
				},
			},
		})
		s.a.stamina = 0
		s.a.latched.staminaOut = true
		idle(s, 10.2)
		local events = act(s, "a", "light", 0.6)
		-- stamina was zero: regen has brought some back; the attack needs 10
		local hit = kinds(events, "hit")[1]
		if hit then
			local plain = DuelModel.WEAPONS.swordShield.light * (1 - DuelModel.ARMOUR.medium.reduction)
			expect(math.abs(hit.data.damage - plain * 1.15) < 1e-9).toBe(true) -- 5 % passive + the stronger 10 %
		else
			error("expected a hit")
		end
	end)

	it("healing is spread over the trigger's duration and cannot pass max HP", function()
		local s = duel({
			modifiers = {
				{ source = "perk:remedy", kind = "heal", magnitude = 0.08, duration = 6, condition = "hpBelow:0.5" },
			},
		})
		s.a.hp = 30
		idle(s, 10.2)
		local mid = s.a.hp
		expect(mid > 30).toBe(true)
		idle(s, 8)
		expect(math.abs(s.a.hp - (30 + 8)) < 0.6).toBe(true) -- 8 % of 100 HP, once
		s.a.hp = 99
		local full = duel({
			modifiers = {
				{ source = "perk:remedy", kind = "heal", magnitude = 0.08, duration = 6, condition = "staminaOut" },
			},
		})
		full.a.latched.staminaOut = true
		idle(full, 12)
		expect(full.a.hp <= DuelModel.CONFIG.maxHp).toBe(true)
	end)

	it("nothing a supporter has acts on the opponent: the opponent's stats are untouched", function()
		local s = duel({ modifiers = reforge() })
		local plain = duel()
		s.a.hp = 30
		idle(s, 12)
		idle(plain, 12)
		expect(s.b.hp).toBe(plain.b.hp)
		expect(s.b.stamina).toBe(plain.b.stamina)
	end)

	it(
		"a Called Warning shows the opponent's heavy earlier (warned > 0) on its first heavy after the quiet start",
		function()
			local s = duel(nil, {
				modifiers = {
					{
						source = "perk:warning",
						kind = "telegraph",
						lead = 0.25,
						uses = 1,
						duration = 8,
						condition = "opponentHeavy",
					},
				},
			})
			idle(s, 10.2)
			local events = act(s, "a", "heavy", 1.2)
			local windup = kinds(events, "heavyWindup")[1]
			expect(windup.data.warned).toBe(0.25)
			idle(s, 1) -- recovered
			local second = act(s, "a", "heavy", 1.2)
			expect(kinds(second, "heavyWindup")[1].data.warned).toBe(0) -- one use
		end
	)
end)

describe("Arena/DuelModel: unchecked support", function()
	it("a telegraph without a lead reports warned = 0, never nil", function()
		local s = duel(nil, {
			modifiers = {
				{ source = "perk:warning", kind = "telegraph", uses = 1, duration = 8, condition = "opponentHeavy" },
			},
		})
		idle(s, 10.2)
		local windup = kinds(act(s, "a", "heavy", 1.2), "heavyWindup")[1]
		expect(windup.data.warned).toBe(0)
	end)

	it("a trigger with no condition never fires and never throws (Caps refuses it before a real duel)", function()
		local s = duel({
			modifiers = {
				{ source = "perk:broken", kind = "trigger", stat = "damageReduction", magnitude = 0.05, duration = 5 },
				{ source = "perk:heal", kind = "heal", magnitude = 0.05, duration = 4 },
			},
		})
		local ok, err = pcall(function()
			idle(s, 30)
		end)
		expect(ok).toBe(true)
		expect(err).toBeNil()
		for _, trigger in s.a.triggers do
			expect(trigger.fired).toBe(false)
		end
	end)
end)

describe("Arena/DuelModel: determinism and bad input", function()
	local function play(seed: number)
		local s = DuelModel.new(
			nil,
			{ weapon = "mace", armour = "light", modifiers = reforge() },
			{ weapon = "spear", armour = "heavy" },
			seed
		)
		local script = { "light", "heavy", "block", "blockEnd", "parry", "dodge", "light" }
		local log = {}
		for i = 1, 600 do
			local action = script[(i // 7) % #script + 1]
			local events = DuelModel.step(s, { a = input(action), b = input(script[(i // 5) % #script + 1]) }, DT)
			for _, e in events do
				table.insert(log, `{e.kind}:{e.side}:{string.format("%.3f", e.t)}`)
			end
		end
		return table.concat(log, "|") .. `#{s.a.hp}#{s.b.hp}`
	end

	it("the same setups and inputs give the same duel, whatever the seed", function()
		expect(play(1)).toBe(play(1))
		expect(play(1)).toBe(play(99))
		expect(#play(1) > 10).toBe(true)
	end)

	it("ignores unknown actions and missing inputs, and rejects unknown weapons and armour", function()
		local s = duel()
		DuelModel.step(s, { a = { action = "fireball" :: any, inRange = true, facing = true } }, DT)
		expect(s.a.state).toBe("idle")
		DuelModel.step(s, { a = { inRange = true, facing = true } }, DT)
		DuelModel.step(s, {}, DT)
		expect(s.a.state).toBe("idle")
		expect(function()
			DuelModel.new(nil, { weapon = "bazooka" :: any }, {}, 1)
		end).toThrow("unknown weapon")
		expect(function()
			DuelModel.new(nil, { armour = "plate" :: any }, {}, 1)
		end).toThrow("unknown armour")
	end)

	it(
		"a bad step (NaN, infinite, zero, negative) lets no time pass, so a clock can never go NaN or backwards",
		function()
			local state = duel()
			idle(state, 1)
			local t = state.t
			for _, bad in { 0 / 0, math.huge, -math.huge, 0, -1 } do
				expect(#DuelModel.step(state, { a = input("light") }, bad)).toBe(0)
				expect(state.t).toBe(t)
			end
			expect(state.ended).toBe(false)
			idle(state, 1)
			expect(state.t > t).toBe(true) -- the duel is still alive and still ticks
		end
	)

	it("clamps a long step to one second: a stall cannot end the duel in a single call", function()
		local state = duel()
		DuelModel.step(state, {}, 10000)
		expect(state.ended).toBe(false)
		expect(state.t).toBe(1)
	end)

	it("takes a config: custom rules change the duel", function()
		local rules = table.clone(DuelModel.CONFIG)
		rules.maxHp = 10
		local s = DuelModel.new(rules, {}, {}, 1)
		expect(s.a.hp).toBe(10)
		act(s, "a", "heavy", 1.2)
		expect(s.ended).toBe(true) -- 14 damage against 10 HP
		expect(s.winner).toBe("a")
	end)

	it("the snapshot is the public picture: shares, states, no hidden triggers", function()
		local s = duel({ modifiers = reforge() })
		local snap = DuelModel.snapshot(s)
		expect(snap.a.hpShare).toBe(1)
		expect(snap.a.state).toBe("idle")
		expect(snap.a.triggers).toBeNil()
		expect(snap.ended).toBe(false)
		local view = DuelModel.view(s, "a")
		expect(view.canAct).toBe(true)
		expect(view.opponentHp).toBe(DuelModel.CONFIG.maxHp)
	end)
end)
