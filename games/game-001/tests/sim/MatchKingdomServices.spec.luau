--[[
	MatchService and KingdomService (CONTRACTS G3, G9; FL-0048) booted through the Loader with
	RemoteService and MockEnv, the way Main.server boots them: phases and deadlines, the G2 Kingdom
	view, assignment and parties, the membership signal and the G9 events they fire.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")

local TICK = MatchConfig.tickSeconds
local registries = {}

local function boot()
	local env = MockEnv.new({ seed = 5, sharedModules = { Remotes = { Kingdom = KingdomRemotes } } })
	local registry = Loader.load(env, { RemoteServiceDef, MatchServiceDef, KingdomServiceDef })
	table.insert(registries, registry)
	return env, registry:get("MatchService"), registry:get("KingdomService")
end

-- every (player, kingdomId) the signal reports, as { userId, kingdomId | false }
local function recordMembership(kingdoms)
	local out = {}
	kingdoms.membershipChanged:connect(function(player, kingdomId)
		table.insert(out, { player.UserId, kingdomId or false })
	end)
	return out
end

local function recordJoined()
	local out = {}
	GameEvents.KingdomJoined:connect(function(player, kingdomId)
		table.insert(out, { player.UserId, kingdomId })
	end)
	return out
end

afterEach(function()
	for _, registry in registries do
		registry:destroy()
	end
	table.clear(registries)
	GameEvents.disconnectAll()
end)

describe("MatchService (G3)", function()
	it("is in the Lobby with no deadline until a player arrives, then counts down to Founding", function()
		local env, match = boot()
		expect(match:getPhase()).toBe("Lobby")
		expect(match:getEndsAt()).toBeNil()
		local changes, contract = {}, {}
		match.phaseChanged:connect(function(phase, info)
			table.insert(changes, { phase = phase, endsAt = info.endsAt })
		end)
		GameEvents.MatchPhaseChanged:connect(function(phase)
			table.insert(contract, phase)
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK * 2)
		expect(match:getPhase()).toBe("Lobby")
		local countdownEnds = match:getEndsAt()
		expect(countdownEnds).toBeTruthy()
		expect(countdownEnds - env.serverTimeNow()).toBeNear(MatchConfig.countdownSec, 0.5)
		env.mock:advance(MatchConfig.countdownSec + TICK)
		expect(match:getPhase()).toBe("Founding")
		expect(match:getEndsAt() - env.serverTimeNow()).toBeNear(MatchConfig.phaseDurations.Founding, 0.5)
		expect(contract).toEqual({ "Founding" })
		-- the countdown start ("Lobby" with its deadline), then Founding; nothing fires twice
		expect(#changes).toBe(2)
		expect(changes[1].phase).toBe("Lobby")
		expect(changes[1].endsAt).toBeNear(countdownEnds, 1e-6)
		expect(changes[2].phase).toBe("Founding")
		expect(changes[2].endsAt).toBeNear(match:getEndsAt(), 1e-6)
	end)

	it("cancels the countdown when the last player leaves before it ends", function()
		local env, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK * 2)
		expect(match:getEndsAt()).toBeTruthy()
		env.mock.players:remove(p1)
		env.mock:advance(MatchConfig.countdownSec + 1)
		expect(match:getPhase()).toBe("Lobby")
		expect(match:getEndsAt()).toBeNil()
	end)

	it("only reports contract MatchPhase names", function()
		local env, match = boot()
		local seen = {}
		match.phaseChanged:connect(function(phase)
			seen[phase] = true
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(MatchConfig.countdownSec + MatchConfig.phaseDurations.Founding + 5)
		for phase in seen do
			expect(table.find(Types.MATCH_PHASES, phase)).toBeTruthy()
		end
		expect(seen.Expansion).toBe(true)
	end)
end)

describe("KingdomService (G3)", function()
	it("returns a G2 Kingdom view that is a copy, and nil for unknown ids", function()
		local env, _, kingdoms = boot()
		env.mock.players:add({ userId = 7 })
		env.mock:advance(TICK)
		local view = kingdoms:getKingdom("crimson")
		local keys = {}
		for key in view do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "alive", "color", "crownPoints", "id", "isAI", "keepBuildingId", "name", "rulers" })
		expect(view.id).toBe("crimson")
		expect(typeof(view.color)).toBe("Color3")
		expect(view.rulers).toEqual({ 7 })
		expect(view.isAI).toBe(false)
		expect(view.alive).toBe(true)
		expect(typeof(view.keepBuildingId)).toBe("number")
		expect(kingdoms:getKingdom("azure").isAI).toBe(true)
		table.insert(view.rulers, 99) -- callers cannot reach the simulation through the view
		expect(kingdoms:getKingdom("crimson").rulers).toEqual({ 7 })
		expect(kingdoms:getKingdom("nowhere")).toBeNil()
	end)

	it("seats arriving players in balanced kingdoms and maps each kingdom to its Team", function()
		local env, _, kingdoms = boot()
		local players = {}
		for userId = 1, 8 do
			players[userId] = env.mock.players:add({ userId = userId })
		end
		env.mock:advance(TICK)
		local counts = {}
		for userId, player in players do
			local kingdomId = kingdoms:getKingdomOf(player)
			expect(table.find(Types.KINGDOM_IDS, kingdomId)).toBeTruthy()
			counts[kingdomId] = (counts[kingdomId] or 0) + 1
			expect(player.Team).toBeTruthy()
			expect(player.Team:GetAttribute("KingdomId")).toBe(kingdomId)
			expect(table.find(kingdoms:getKingdom(kingdomId).rulers, userId)).toBeTruthy()
		end
		for _, id in Types.KINGDOM_IDS do
			expect(counts[id]).toBe(2)
		end
	end)

	it("assign switches kingdom in the Lobby and keeps the current one afterwards", function()
		local env, match, kingdoms = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
		expect(kingdoms:assign(p1, "gold")).toBe("gold")
		expect(kingdoms:getKingdomOf(p1)).toBe("gold")
		expect(p1.Team:GetAttribute("KingdomId")).toBe("gold")
		expect(kingdoms:assign(p1)).toBe("gold") -- no preference: stays
		env.mock:advance(MatchConfig.countdownSec + TICK)
		expect(match:getPhase()).toBe("Founding")
		expect(kingdoms:assign(p1, "azure")).toBe("gold") -- too late to defect
		expect(kingdoms:getKingdomOf(p1)).toBe("gold")
		expect(p1.Team:GetAttribute("KingdomId")).toBe("gold")
	end)

	it("assign returns nil for a spectator when every seat is taken", function()
		local env, _, kingdoms = boot()
		local seats = 4 * 4 -- Kingdoms.maxRulersPerKingdom per kingdom
		for userId = 1, seats do
			env.mock.players:add({ userId = userId })
		end
		local extra = env.mock.players:add({ userId = 100 })
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(extra)).toBeNil()
		expect(kingdoms:assign(extra)).toBeNil()
		expect(extra.Team).toBeNil()
		expect(env.mock:hasLog("info", "spectating")).toBe(true)
	end)

	it("assignParty regroups already-seated party members in the Lobby", function()
		local env, _, kingdoms = boot()
		local a = env.mock.players:add({ userId = 1 }) -- crimson
		local b = env.mock.players:add({ userId = 2 }) -- azure
		local c = env.mock.players:add({ userId = 3 }) -- emerald
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(a)).never.toBe(kingdoms:getKingdomOf(b))
		local result = kingdoms:assignParty({ a, b, c })
		assert(result, "assignParty returned nil")
		local together = result[a]
		expect(result[b]).toBe(together)
		expect(result[c]).toBe(together)
		expect(#kingdoms:getKingdom(together).rulers).toBe(3)
		for _, player in { a, b, c } do
			expect(kingdoms:getKingdomOf(player)).toBe(together)
			expect(player.Team:GetAttribute("KingdomId")).toBe(together)
		end
	end)

	it(
		"assignParty keeps seated members where they are once the match runs, and refuses parties above the cap",
		function()
			local env, _, kingdoms = boot()
			local a = env.mock.players:add({ userId = 1 })
			local b = env.mock.players:add({ userId = 2 })
			env.mock:advance(MatchConfig.countdownSec + TICK * 2)
			local before = { kingdoms:getKingdomOf(a), kingdoms:getKingdomOf(b) }
			local result = kingdoms:assignParty({ a, b })
			assert(result, "assignParty returned nil")
			expect({ result[a], result[b] }).toEqual(before)
			local big = {}
			for userId = 10, 14 do
				table.insert(big, env.mock.players:add({ userId = userId }))
			end
			expect(kingdoms:assignParty(big)).toBeNil()
		end
	)

	it("addCrownPoints adds to the view and rejects non-finite amounts", function()
		local _, _, kingdoms = boot()
		local start = kingdoms:getKingdom("emerald").crownPoints
		kingdoms:addCrownPoints("emerald", 25, "test")
		expect(kingdoms:getKingdom("emerald").crownPoints).toBe(start + 25)
		kingdoms:addCrownPoints("nowhere", 25, "test") -- unknown kingdom: ignored
		expect(function()
			kingdoms:addCrownPoints("emerald", 0 / 0, "nan")
		end).toThrow("amount")
		expect(function()
			kingdoms:addCrownPoints("emerald", math.huge, "inf")
		end).toThrow("amount")
		expect(function()
			kingdoms:addCrownPoints("emerald", "5" :: any, "string")
		end).toThrow("amount")
		expect(kingdoms:getKingdom("emerald").crownPoints).toBe(start + 25)
	end)
end)

describe("KingdomService membership signal and G9 KingdomJoined", function()
	it("reports a join once, with KingdomJoined once", function()
		local env, _, kingdoms = boot()
		local changes, joined = recordMembership(kingdoms), recordJoined()
		env.mock.players:add({ userId = 4 })
		env.mock:advance(TICK * 4)
		expect(changes).toEqual({ { 4, "crimson" } })
		expect(joined).toEqual({ { 4, "crimson" } })
	end)

	it("reports a Lobby switch as one change, not a leave and a join", function()
		local env, _, kingdoms = boot()
		local p1 = env.mock.players:add({ userId = 4 })
		env.mock:advance(TICK)
		local changes, joined = recordMembership(kingdoms), recordJoined()
		kingdoms:assign(p1, "emerald")
		env.mock:advance(TICK * 2)
		expect(changes).toEqual({ { 4, "emerald" } })
		expect(joined).toEqual({ { 4, "emerald" } })
	end)

	it("collapses a join and a switch in the same tick into one change", function()
		local env, _, kingdoms = boot()
		local changes, joined = recordMembership(kingdoms), recordJoined()
		local p1 = env.mock.players:add({ userId = 4 })
		kingdoms:assign(p1, "gold") -- before the tick that reports the join
		env.mock:advance(TICK * 2)
		expect(changes).toEqual({ { 4, "gold" } })
		expect(joined).toEqual({ { 4, "gold" } })
	end)

	it("reports (player, nil) when a ruler leaves the server, and nothing for a spectator", function()
		local env, _, kingdoms = boot()
		for userId = 1, 16 do
			env.mock.players:add({ userId = userId })
		end
		local spectator = env.mock.players:add({ userId = 50 })
		env.mock:advance(TICK)
		local changes = recordMembership(kingdoms)
		local leaver = env.mock.players:get(3)
		local leaverKingdom = kingdoms:getKingdomOf(leaver)
		env.mock.players:remove(leaver)
		env.mock.players:remove(spectator)
		env.mock:advance(TICK * 2)
		expect(changes).toEqual({ { 3, false } })
		expect(table.find(kingdoms:getKingdom(leaverKingdom).rulers, 3)).toBeNil()
	end)

	it("reports a returning ruler back in their old kingdom", function()
		local env, _, kingdoms = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock.players:add({ userId = 2 })
		env.mock:advance(TICK)
		local home = kingdoms:getKingdomOf(p1)
		local changes, joined = recordMembership(kingdoms), recordJoined()
		env.mock.players:remove(p1)
		env.mock:advance(TICK)
		local again = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(again)).toBe(home)
		expect(changes).toEqual({ { 1, false }, { 1, home } })
		expect(joined).toEqual({ { 1, home } })
	end)

	it("reports every ruler again when the next match seats them in a fresh world", function()
		local env, match, kingdoms = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		local changes, joined = recordMembership(kingdoms), recordJoined()
		local total = MatchConfig.countdownSec
			+ MatchConfig.phaseDurations.Founding
			+ MatchConfig.phaseDurations.Expansion
			+ MatchConfig.phaseDurations.Conflict
			+ MatchConfig.phaseDurations.Endgame
			+ MatchConfig.resultsSec
			+ 2
		env.mock:advance(total)
		expect(match:getPhase()).toBe("Lobby")
		expect(match.host.match.roundId).never.toBe(nil)
		expect(changes).toEqual({ { 1, "crimson" } })
		expect(joined).toEqual({ { 1, "crimson" } })
	end)
end)
