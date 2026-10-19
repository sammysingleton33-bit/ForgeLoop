--[[
	Arena/DuelAI (FL-0071; design §2): the AI champion's hands. Deterministic, only sends what a client could send,
	answers telegraphed heavies, never swings with no breath, and a better AI beats a worse one over many duels.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Duel = require("@game/ReplicatedStorage/Forge/Config/Duel")
local DuelAI = require("@game/ReplicatedStorage/Game/Arena/DuelAI")
local DuelModel = require("@game/ReplicatedStorage/Game/Arena/DuelModel")

local DT = 1 / 30
local ACTIONS = { light = true, heavy = true, block = true, blockEnd = true, parry = true, dodge = true }

-- plays one duel between two AIs; returns the finished state and the log of every action sent
local function play(skillA: number, skillB: number, seed: number, setupA: any?, setupB: any?)
	local state = DuelModel.new(
		nil,
		setupA or { weapon = "swordShield", armour = "medium" },
		setupB or { weapon = "swordShield", armour = "medium" },
		seed
	)
	local ai = { a = DuelAI.new("a", skillA, seed * 7 + 1), b = DuelAI.new("b", skillB, seed * 13 + 5) }
	local log = {}
	for _ = 1, math.floor(Duel.rules.hardCap / DT) + 10 do
		if state.ended then
			break
		end
		local snapshot = DuelModel.snapshot(state)
		local inputs = {}
		for _, side in { "a", "b" } do
			local action = ai[side]:decide(snapshot)
			if action then
				table.insert(log, `{side}:{action}:{string.format("%.2f", state.t)}`)
			end
			inputs[side] = { action = action, inRange = true, facing = true }
		end
		local events = DuelModel.step(state, inputs, DT)
		ai.a:observe(events)
		ai.b:observe(events)
	end
	return state, log
end

describe("DuelAI: behaviour", function()
	it("is deterministic: the same seed and skill give the same duel", function()
		local _, first = play(0.5, 0.5, 11)
		local _, second = play(0.5, 0.5, 11)
		expect(table.concat(first, "|")).toBe(table.concat(second, "|"))
		local _, other = play(0.5, 0.5, 12)
		expect(table.concat(first, "|") ~= table.concat(other, "|")).toBe(true)
	end)

	it("only sends actions a client could send", function()
		for seed = 1, 6 do
			local _, log = play(0.1 * seed, 0.9 - 0.1 * seed, seed)
			expect(#log > 0).toBe(true)
			for _, entry in log do
				local action = string.split(entry, ":")[2]
				expect(ACTIONS[action]).toBe(true)
			end
		end
	end)

	it("every duel between two AIs ends well before the hard cap", function()
		local ko, clock = 0, 0
		local longest = 0
		for seed = 1, 12 do
			local state = play(0.5, 0.5, seed)
			expect(state.ended).toBe(true)
			-- a double KO is a "draw" ending (rare); the hard cap would mean an AI that stalls
			if state.reason == "hardCap" then
				error(
					`seed {seed}: reason {state.reason} winner {state.winner} t {state.t} hp {state.a.hp}/{state.b.hp}`
				)
			end
			longest = math.max(longest, state.t)
			if state.reason == "ko" then
				ko += 1
			else
				clock += 1
			end
		end
		expect(ko + clock).toBe(12)
		expect(longest < Duel.rules.hardCap).toBe(true)
	end)

	it("does not send a swing it cannot pay for, and never sends while the duel is over", function()
		local state = DuelModel.new(
			nil,
			{ weapon = "swordShield", armour = "medium" },
			{ weapon = "swordShield", armour = "medium" },
			3
		)
		local ai = DuelAI.new("a", 0.5, 9)
		state.a.stamina = 2
		local snapshot = DuelModel.snapshot(state)
		for _ = 1, 40 do
			snapshot.t += 0.2
			local action = ai:decide(snapshot)
			expect(action ~= "light" and action ~= "heavy").toBe(true)
		end
		local fresh = DuelAI.new("a", 0.5, 9)
		local live = DuelModel.snapshot(state)
		live.t = 5
		expect(fresh:decide(live)).never.toBeNil() -- a live duel: it acts
		local over = DuelAI.new("a", 0.5, 9)
		live.ended = true
		expect(over:decide(live)).toBeNil() -- the same moment, but the duel is over
	end)

	it("answers a telegraphed heavy: a defence goes out before the impact", function()
		local answered = 0
		local trials = 30
		for seed = 1, trials do
			local ai = DuelAI.new("b", 1, seed)
			local state = DuelModel.new(
				nil,
				{ weapon = "swordShield", armour = "medium" },
				{ weapon = "swordShield", armour = "medium" },
				seed
			)
			state.t = 20
			local snapshot = DuelModel.snapshot(state)
			ai:observe({ { t = 20, kind = "heavyWindup", side = "a", data = { impactAt = 20.8, warned = 0 } } })
			local sent = nil
			for step = 1, 40 do
				snapshot.t = 20 + step * DT
				local action = ai:decide(snapshot)
				if
					action
					and snapshot.t < 20.8
					and sent == nil
					and (action == "parry" or action == "dodge" or action == "block")
				then
					sent = action
				end
			end
			if sent then
				answered += 1
			end
		end
		expect(answered >= trials * 0.7).toBe(true) -- skill 1 sees ~90 %
	end)

	it("a heavy it has not been told about is not answered", function()
		local ai = DuelAI.new("b", 1, 4)
		local state = DuelModel.new(
			nil,
			{ weapon = "mace", armour = "light" },
			{ weapon = "mace", armour = "light" },
			4
		)
		local snapshot = DuelModel.snapshot(state)
		snapshot.a.stamina = 0 -- nothing to attack with on the other side; the AI only has itself to act on
		ai:observe({ { t = 5, kind = "hit", side = "a", data = { damage = 6 } } }) -- not a telegraph
		expect(#ai._threats).toBe(0)
		ai:observe({ { t = 5, kind = "heavyWindup", side = "b", data = { impactAt = 5.8 } } }) -- its own windup
		expect(#ai._threats).toBe(0)
		ai:observe({ { t = 5, kind = "heavyWindup", side = "a", data = {} } }) -- no impact time
		expect(#ai._threats).toBe(0)
	end)

	it("releases a block when nothing is coming", function()
		local ai = DuelAI.new("a", 0.5, 2)
		local state = DuelModel.new(
			nil,
			{ weapon = "mace", armour = "light" },
			{ weapon = "mace", armour = "light" },
			2
		)
		state.a.state = "block"
		local snapshot = DuelModel.snapshot(state)
		local released = false
		for step = 1, 20 do
			snapshot.t = step * 0.2
			if ai:decide(snapshot) == "blockEnd" then
				released = true
			end
		end
		expect(released).toBe(true)
	end)

	it("clamps its skill and refuses a bad side", function()
		expect(DuelAI.new("a", 7, 1)._skill).toBe(1)
		expect(DuelAI.new("a", -3, 1)._skill).toBe(0)
		expect(DuelAI.new("a", 0 / 0, 1)._skill).toBe(0.5)
		expect(function()
			DuelAI.new("c", 0.5, 1)
		end).toThrow("side must be")
	end)
end)

describe("DuelAI: strength", function()
	it("a skilled AI beats a novice AI clearly, and equal skill is close to even", function()
		local wins, games = 0, 40
		for seed = 1, games do
			local state = play(0.9, 0.1, seed * 3)
			if state.winner == "a" then
				wins += 1
			end
		end
		expect(wins / games >= 0.6).toBe(true)
		local evenWins = 0
		for seed = 1, games do
			local state = play(0.5, 0.5, seed * 5)
			if state.winner == "a" then
				evenWins += 1
			end
		end
		expect(evenWins / games >= 0.25 and evenWins / games <= 0.75).toBe(true)
	end)
end)
