--[[
	MatchService and KingdomService (CONTRACTS G3, G8, G9, G11; FL-0048) booted through the Loader with
	RemoteService and MockEnv, the way Main.server boots them: phases and deadlines (slice and match
	modes, PacingService or the built-in defaults), the G2 Kingdom view, Teams, assignment and parties,
	spawning at the plot after WorldService.ready with regalia, the membership signal, the Kingdom/Match
	remotes and the G9 events they fire.

	Lune has no characters, so specs replace KingdomService.adapter with a recording double; the default
	adapter's engine calls are covered by the Studio steps (roblox/studio-tests/gameplay.md K1).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")
local PacingServiceDef = require("@game/ServerScriptService/Game/Services/PacingService")
local ProductionServiceDef = require("@game/ServerScriptService/Game/Services/ProductionService")
local TreasuryServiceDef = require("@game/ServerScriptService/Game/Services/TreasuryService")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local TICK = MatchConfig.tickSeconds
local MATCH_DURATIONS = MatchConfig.durations.match
local registries = {} -- { { registry, env } }
local savedMode = MatchConfig.mode

-- Short phases for specs that need to reach Results without simulating a 45-minute match.
local FAST = { Lobby = 2, Founding = 3, Expansion = 3, Conflict = 3, Endgame = 3, Results = 2 }
local function fastPacing()
	return {
		phaseDurations = function()
			return table.clone(FAST)
		end,
	}
end

-- A service definition that hands out a prepared double.
local function double(name: string, instance: any)
	return {
		name = name,
		new = function()
			return instance
		end,
	}
end

local useAdapter

-- options: { mode?, pacing?, world?, parties?, others? } (pacing/world: service doubles; parties:
-- userId -> PartyId; others = true also boots FORGE-03's Treasury/Production and FORGE-04's Pacing).
-- Returns env, MatchService, KingdomService and the spawn adapter's log.
local function boot(options: any?)
	local opts = options or {}
	MatchConfig.mode = opts.mode or "slice" -- the specs that do not say are the VS-1 slice ones; the config default is "match" (D-053)
	local env = MockEnv.new({
		seed = 5,
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Treasury = TreasuryRemotes } },
	})
	local definitions = { RemoteServiceDef, MatchServiceDef, KingdomServiceDef }
	if opts.others then
		table.insert(definitions, TreasuryServiceDef)
		table.insert(definitions, ProductionServiceDef)
		table.insert(definitions, PacingServiceDef)
	end
	if opts.pacing then
		table.insert(definitions, double("PacingService", opts.pacing))
	end
	if opts.world then
		table.insert(definitions, double("WorldService", opts.world))
	end
	local registry = Loader.load(env, definitions)
	table.insert(registries, { registry = registry, env = env })
	local kingdoms = registry:get("KingdomService")
	local log = useAdapter(env, kingdoms, opts.parties)
	return env, registry:get("MatchService"), kingdoms, log
end

-- Recording stand-in for the engine calls behind spawning (KingdomService.adapter).
function useAdapter(env, kingdoms, parties: { [number]: string }?)
	local log = {
		loads = {},
		pivots = {},
		attached = {},
		died = {},
		respawnDelay = 5,
		sits = {},
		unseats = {}, -- { character, seat } per unseat (#89 L2)
		seatOf = {}, -- character -> seat (Humanoid.SeatPart)
		occupant = {}, -- seat -> character (Seat.Occupant)
	}
	kingdoms.adapter = {
		partyOf = function(player)
			return (parties or {})[player.UserId]
		end,
		load = function(player)
			env.wait() -- LoadCharacterAsync yields
			local character = env.newInstance("Model")
			character.Name = player.Name
			local root = env.newInstance("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.new()
			root.Parent = character
			character.Parent = env.Workspace
			player.Character = character
			table.insert(log.loads, player.UserId)
			return character
		end,
		pivot = function(character, cframe)
			character.HumanoidRootPart.CFrame = cframe
			table.insert(log.pivots, { character = character, cframe = cframe })
		end,
		attach = function(character, accessory)
			accessory.Parent = character
			table.insert(log.attached, { character = character, accessory = accessory })
		end,
		onDied = function(character, callback)
			log.died[character] = callback
			return {
				Disconnect = function()
					log.died[character] = nil
				end,
			}
		end,
		respawnDelay = function()
			return log.respawnDelay
		end,
		sit = function(character, seat)
			local old = log.seatOf[character]
			if old then
				log.occupant[old] = nil
			end
			log.seatOf[character] = seat
			log.occupant[seat] = character
			table.insert(log.sits, { character = character, seat = seat })
		end,
		seatOf = function(character)
			return log.seatOf[character]
		end,
		occupant = function(seat)
			return log.occupant[seat]
		end,
		unseat = function(character, seat)
			if log.occupant[seat] == character then
				log.occupant[seat] = nil
			end
			if log.seatOf[character] == seat then
				log.seatOf[character] = nil
			end
			table.insert(log.unseats, { character = character, seat = seat })
		end,
	}
	return log
end

local function count(list, value)
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
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

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	-- FindFirstChild: "Changed" would index the Instance event, not the remote
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

-- args of every firing of a server event that reached `player` (FireClient to them, or FireAllClients)
local function received(env, name, player)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, name)) do
		if entry.direction == "toAllClients" or entry.player == player then
			table.insert(out, entry.args)
		end
	end
	return out
end

local function invoke(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

afterEach(function()
	for _, booted in registries do
		booted.registry:destroy()
		-- a failing host tick is logged and swallowed (MatchHost keeps the kingdom running): fail loudly here
		for _, entry in booted.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
		expect(booted.env.mock.threadErrors).toEqual({})
	end
	table.clear(registries)
	GameEvents.disconnectAll()
	MatchConfig.mode = savedMode
end)

describe("MatchService (G3, G11)", function()
	it(
		"slice mode (the VS-1 slice, a debug command away since D-053): Founding starts with the first join and is untimed",
		function()
			local env, match = boot()
			expect(match.mode).toBe("slice")
			expect(match.durationsSource).toBe("defaults")
			expect(match:getPhase()).toBe("Lobby")
			local changes, contract = {}, {}
			match.phaseChanged:connect(function(phase, info)
				table.insert(changes, { phase, info.endsAt or false })
			end)
			GameEvents.MatchPhaseChanged:connect(function(phase)
				table.insert(contract, phase)
			end)
			env.mock:advance(30)
			expect(match:getPhase()).toBe("Lobby") -- nobody here
			env.mock.players:add({ userId = 1 })
			env.mock:advance(TICK)
			expect(match:getPhase()).toBe("Founding")
			expect(match:getEndsAt()).toBeNil()
			env.mock:advance(600)
			expect(match:getPhase()).toBe("Founding")
			expect(changes).toEqual({ { "Founding", false } })
			expect(contract).toEqual({ "Founding" })
		end
	)

	it("match mode: counts down in the Lobby, then Founding with a deadline", function()
		local env, match = boot({ mode = "match" })
		local changes = {}
		match.phaseChanged:connect(function(phase, info)
			table.insert(changes, { phase = phase, endsAt = info.endsAt })
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK * 2)
		expect(match:getPhase()).toBe("Lobby")
		local countdownEnds = match:getEndsAt()
		expect(countdownEnds - env.serverTimeNow()).toBeNear(MATCH_DURATIONS.Lobby, 0.5)
		env.mock:advance(MATCH_DURATIONS.Lobby + TICK)
		expect(match:getPhase()).toBe("Founding")
		expect(match:getEndsAt() - env.serverTimeNow()).toBeNear(MATCH_DURATIONS.Founding, 0.5)
		expect(#changes).toBe(2)
		expect(changes[1].phase).toBe("Lobby")
		expect(changes[1].endsAt).toBeNear(countdownEnds, 1e-6)
		expect(changes[2].phase).toBe("Founding")
	end)

	it("match mode: cancels the countdown when the last player leaves before it ends", function()
		local env, match = boot({ mode = "match" })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK * 2)
		expect(match:getEndsAt()).toBeTruthy()
		env.mock.players:remove(p1)
		env.mock:advance(MATCH_DURATIONS.Lobby + 1)
		expect(match:getPhase()).toBe("Lobby")
		expect(match:getEndsAt()).toBeNil()
	end)

	it("takes phase lengths from PacingService:phaseDurations(mode) when it is present", function()
		local asked = {}
		local pacing = {
			phaseDurations = function(_, mode)
				table.insert(asked, mode)
				return { Lobby = 3, Founding = 7, Expansion = 7, Conflict = 7, Endgame = 7, Results = 4 }
			end,
		}
		local env, match = boot({ mode = "match", pacing = pacing })
		expect(asked).toEqual({ "match" })
		expect(match.durationsSource).toBe("pacing")
		env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(match:getEndsAt() - env.serverTimeNow()).toBeNear(3, 0.3)
		env.mock:advance(3 + 7 + TICK)
		expect(match:getPhase()).toBe("Expansion")
	end)

	it(
		"falls back to the built-in durations, with a warning, when PacingService fails or returns bad lengths",
		function()
			for _, pacing in
				{
					{
						phaseDurations = function()
							error("config broken")
						end,
					},
					{
						phaseDurations = function()
							return { Lobby = 0, Founding = 0, Expansion = 1, Conflict = 1, Endgame = 1, Results = 1 }
						end,
					},
				}
			do
				local env, match = boot({ mode = "match", pacing = pacing })
				expect(match.durationsSource).toBe("defaults")
				expect(env.mock:hasLog("warn", "PacingService durations unusable")).toBe(true)
				env.mock.players:add({ userId = 1 })
				env.mock:advance(TICK)
				expect(match:getEndsAt() - env.serverTimeNow()).toBeNear(MATCH_DURATIONS.Lobby, 0.5)
			end
		end
	)

	it("only reports contract MatchPhase names", function()
		local env, match = boot({ mode = "match", pacing = fastPacing() })
		local seen = {}
		match.phaseChanged:connect(function(phase)
			seen[phase] = true
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(FAST.Lobby + FAST.Founding * 4 + 1)
		for phase in seen do
			expect(table.find(Types.MATCH_PHASES, phase)).toBeTruthy()
		end
		expect(seen.Expansion).toBe(true)
		expect(seen.Results).toBe(true)
	end)
end)

describe("KingdomService (G3)", function()
	it("returns a G2 Kingdom view that is a copy, with the home region, and nil for unknown ids", function()
		local env, _, kingdoms = boot()
		env.mock.players:add({ userId = 7 })
		env.mock:advance(TICK)
		local view = kingdoms:getKingdom("crimson")
		local keys = {}
		for key in view do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({
			"alive",
			"color",
			"crownPoints",
			"happiness",
			"id",
			"isAI",
			"keepBuildingId",
			"morale",
			"name",
			"regions",
			"rulers",
			"stability",
		})
		expect(view.id).toBe("crimson")
		expect(typeof(view.color)).toBe("Color3")
		expect(view.rulers).toEqual({ 7 })
		expect(view.isAI).toBe(false)
		expect(view.alive).toBe(true)
		expect(view.regions).toEqual({ Layout.WORLD.plots.crimson.regionId })
		expect(typeof(view.keepBuildingId)).toBe("number")
		expect(kingdoms:getKingdom("azure").isAI).toBe(true)
		table.insert(view.rulers, 99) -- callers cannot reach the simulation through the view
		expect(kingdoms:getKingdom("crimson").rulers).toEqual({ 7 })
		expect(kingdoms:getKingdom("nowhere")).toBeNil()
	end)

	it("creates four Teams with AutoAssignable off and distinct named TeamColors from config Kingdoms", function()
		local env = boot()
		local teams = env.Teams:GetChildren()
		expect(#teams).toBe(4)
		local colors, ids = {}, {}
		for _, team in teams do
			expect(team.AutoAssignable).toBe(false)
			local id = team:GetAttribute("KingdomId")
			table.insert(ids, id)
			local identity
			for _, entry in KingdomsConfig.identities do
				if entry.id == id then
					identity = entry
				end
			end
			expect(team.TeamColor.Name).toBe(identity.teamColor)
			expect(colors[team.TeamColor.Name]).toBeNil()
			colors[team.TeamColor.Name] = true
		end
		table.sort(ids)
		local expected = table.clone(Types.KINGDOM_IDS)
		table.sort(expected)
		expect(ids).toEqual(expected)
	end)

	it("lays no ground of its own: WorldService owns the terrain and the river (F1)", function()
		local env = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local root = env.Workspace:FindFirstChild("ForgeKingdoms")
		expect(root).never.toBeNil() -- the interim world view still runs (buildings, nodes)
		for _, part in env.Workspace:GetDescendants() do
			expect(part.Name).never.toBe("Ground")
		end
	end)

	it("seats 1..16 arriving players in balanced kingdoms, sets Player.Team, and spectates the 17th", function()
		local env, _, kingdoms = boot()
		for userId = 1, 16 do
			local player = env.mock.players:add({ userId = userId })
			local counts = {}
			for _, id in Types.KINGDOM_IDS do
				counts[id] = #kingdoms:getKingdom(id).rulers
			end
			local lo, hi = math.huge, 0
			for _, c in counts do
				lo, hi = math.min(lo, c), math.max(hi, c)
			end
			expect(hi - lo <= 1).toBe(true)
			local kingdomId = kingdoms:getKingdomOf(player)
			expect(player.Team:GetAttribute("KingdomId")).toBe(kingdomId)
		end
		local extra = env.mock.players:add({ userId = 100 })
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(extra)).toBeNil()
		expect(kingdoms:assign(extra)).toBeNil()
		expect(extra.Team).toBeNil()
		expect(env.mock:hasLog("info", "spectating")).toBe(true)
	end)

	it("groups arriving players by Player.PartyId, then balances everyone else", function()
		local env, _, kingdoms = boot({
			parties = { [1] = "party-a", [3] = "party-a", [4] = "party-a", [2] = "party-b", [5] = "party-b" },
		})
		local players = {}
		for userId = 1, 6 do
			players[userId] = env.mock.players:add({ userId = userId })
		end
		local a = kingdoms:getKingdomOf(players[1])
		local b = kingdoms:getKingdomOf(players[2])
		expect(a).never.toBe(b)
		expect(kingdoms:getKingdomOf(players[3])).toBe(a)
		expect(kingdoms:getKingdomOf(players[4])).toBe(a)
		expect(kingdoms:getKingdomOf(players[5])).toBe(b)
		local solo = kingdoms:getKingdomOf(players[6])
		expect(solo).never.toBe(a)
		expect(solo).never.toBe(b) -- balanced into an empty kingdom
	end)

	it("a party larger than the free seats overflows into the balanced kingdoms", function()
		local parties = {}
		for userId = 1, 6 do
			parties[userId] = "big"
		end
		local env, _, kingdoms = boot({ parties = parties })
		local seatsPerKingdom = KingdomsConfig.maxRulersPerKingdom
		local players = {}
		for userId = 1, 6 do
			players[userId] = env.mock.players:add({ userId = userId })
		end
		local first = kingdoms:getKingdomOf(players[1])
		expect(#kingdoms:getKingdom(first).rulers).toBe(seatsPerKingdom)
		for userId = seatsPerKingdom + 1, 6 do
			expect(kingdoms:getKingdomOf(players[userId])).never.toBe(first)
		end
	end)

	it("assign switches kingdom in the Lobby and keeps the current one afterwards", function()
		local env, match, kingdoms = boot({ mode = "match" })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
		expect(kingdoms:assign(p1, "gold")).toBe("gold")
		expect(p1.Team:GetAttribute("KingdomId")).toBe("gold")
		expect(kingdoms:assign(p1)).toBe("gold") -- no preference: stays
		env.mock:advance(MATCH_DURATIONS.Lobby + 1)
		expect(match:getPhase()).toBe("Founding")
		expect(kingdoms:assign(p1, "azure")).toBe("gold") -- too late to defect
		expect(p1.Team:GetAttribute("KingdomId")).toBe("gold")
	end)

	it("assignParty regroups already-seated party members in the Lobby", function()
		local env, _, kingdoms = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 }) -- crimson
		local b = env.mock.players:add({ userId = 2 }) -- azure
		local c = env.mock.players:add({ userId = 3 }) -- emerald
		env.mock:advance(TICK)
		local result = kingdoms:assignParty({ a, b, c })
		assert(result, "assignParty returned nil")
		local together = result[a]
		expect(result[b]).toBe(together)
		expect(result[c]).toBe(together)
		expect(#kingdoms:getKingdom(together).rulers).toBe(3)
		for _, player in { a, b, c } do
			expect(player.Team:GetAttribute("KingdomId")).toBe(together)
		end
	end)

	it(
		"assignParty keeps seated members where they are once the match runs, and refuses parties above the cap",
		function()
			local env, _, kingdoms = boot()
			local a = env.mock.players:add({ userId = 1 })
			local b = env.mock.players:add({ userId = 2 })
			env.mock:advance(TICK * 2)
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
		for _, bad in { 0 / 0, math.huge, "5" :: any } do
			expect(function()
				kingdoms:addCrownPoints("emerald", bad, "bad")
			end).toThrow("amount")
		end
		expect(kingdoms:getKingdom("emerald").crownPoints).toBe(start + 25)
	end)
end)

describe("KingdomService spawning (G3, D-026)", function()
	it("waits for WorldService.ready, then spawns at the plot wearing regalia in the kingdom colour", function()
		local ready = false
		local world = { ready = Signal.new() }
		function world.isReady()
			return ready
		end
		local env, _, kingdoms, log = boot({ world = world })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(5)
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
		expect(log.loads).toEqual({}) -- seated, but the world is not built yet
		ready = true
		world.ready:fire()
		env.mock:advance(TICK)
		expect(log.loads).toEqual({ 1 })
		expect(#log.pivots).toBe(1)
		local spawnAt = Layout.WORLD.plots.crimson.spawn
		expect((log.pivots[1].cframe.Position - spawnAt.Position).Magnitude).toBeNear(0, 1e-6)
		expect(p1.Character.HumanoidRootPart.CFrame.Position.X).toBeNear(spawnAt.Position.X, 1e-3)
		local names = {}
		for _, entry in log.attached do
			expect(entry.character).toBe(p1.Character)
			table.insert(names, entry.accessory.Name)
		end
		table.sort(names)
		expect(names).toEqual({ "KitCape", "KitCrown" })
		local cape = p1.Character:FindFirstChild("KitCape")
		local crimson = kingdoms:getKingdom("crimson").color
		expect(cape.Handle.Color.R).toBeNear(crimson.R, 1e-2)
		world.ready:fire() -- a second ready changes nothing
		env.mock:advance(TICK)
		expect(log.loads).toEqual({ 1 })
	end)

	it("spawns anyway, with a warning, when WorldService never fires ready (F3)", function()
		local world = { ready = Signal.new() }
		function world.isReady()
			return false
		end
		local env, _, kingdoms, log = boot({ world = world })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(KingdomServiceDef.WORLD_READY_TIMEOUT - 1)
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
		expect(log.loads).toEqual({})
		env.mock:advance(2)
		expect(log.loads).toEqual({ 1 })
		expect(#log.pivots).toBe(1)
		local warned = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "WorldService not ready", 1, true) then
				warned += 1
			end
		end
		expect(warned).toBe(1)
		world.ready:fire() -- a late ready spawns nobody twice
		env.mock:advance(1)
		expect(log.loads).toEqual({ 1 })
	end)

	it("retries a failing character load with backoff and a warning per attempt (F2)", function()
		local env, _, kingdoms, log = boot()
		local load = kingdoms.adapter.load
		local attempts = {}
		kingdoms.adapter.load = function(player)
			table.insert(attempts, env.clock())
			if #attempts <= 2 then
				error("LoadCharacter failed: test")
			elseif #attempts == 3 then
				return nil -- no character
			end
			return load(player)
		end
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(10)
		expect(#attempts).toBe(4)
		expect(attempts[2] - attempts[1]).toBeNear(1, 0.1)
		expect(attempts[3] - attempts[2]).toBeNear(2, 0.1)
		expect(attempts[4] - attempts[3]).toBeNear(4, 0.1)
		expect(log.loads).toEqual({ 1 })
		expect(#log.pivots).toBe(1)
		expect(p1.Character).never.toBeNil()
		local warnings = {}
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "character load failed", 1, true) then
				table.insert(warnings, entry.fields.error)
			end
		end
		expect(#warnings).toBe(3)
		expect(string.find(warnings[1], "LoadCharacter failed", 1, true)).never.toBeNil()
		expect(warnings[3]).toBe("no character")
	end)

	it("stops retrying once the player leaves (F2)", function()
		local env, _, kingdoms, log = boot()
		local attempts = 0
		kingdoms.adapter.load = function()
			attempts += 1
			error("LoadCharacter failed: player left")
		end
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(2.5) -- attempts at 0 and 1
		expect(attempts).toBe(2)
		env.mock.players:remove(p1)
		env.mock:advance(120)
		expect(attempts).toBe(2)
		expect(log.loads).toEqual({})
	end)

	it("does not warn about a load that fails because the player left during it (F2)", function()
		local env, _, kingdoms = boot()
		local attempts = 0
		kingdoms.adapter.load = function()
			attempts += 1
			env.wait(0.5) -- LoadCharacterAsync yields; the player leaves meanwhile
			error("LoadCharacter failed: player left")
		end
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.25)
		env.mock.players:remove(p1)
		env.mock:advance(10)
		expect(attempts).toBe(1)
		for _, entry in env.mock.logs do
			expect(string.find(entry.message, "character load failed", 1, true)).toBeNil()
		end
	end)

	it("spawns at once when there is no WorldService, once per player", function()
		local env, _, _, log = boot()
		env.mock.players:add({ userId = 1 })
		env.mock.players:add({ userId = 2 })
		env.mock:advance(1)
		table.sort(log.loads)
		expect(log.loads).toEqual({ 1, 2 })
		env.mock:advance(30)
		expect(#log.loads).toBe(2)
	end)

	it("tells the match host when it moves a ruler's character, so the position clamp starts over (FL-0122)", function()
		local env, matchService, _, log = boot()
		local snapped = {}
		local host = matchService.host
		local original = host.snapRuler
		host.snapRuler = function(self, userId)
			table.insert(snapped, { userId = userId, pivots = #log.pivots })
			return original(self, userId)
		end
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		expect(#snapped).toBe(1)
		expect(snapped[1]).toEqual({ userId = 1, pivots = 1 }) -- right after the pivot to the plot spawn
		env.spawn(log.died[p1.Character])
		env.mock:advance(log.respawnDelay + 1)
		expect(#snapped).toBe(2) -- and again after the respawn's pivot
		expect(snapped[2]).toEqual({ userId = 1, pivots = 2 })
	end)

	it("respawns at the plot after a death (after RespawnTime) and never after leaving", function()
		local env, _, _, log = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local first = p1.Character
		env.spawn(log.died[first])
		env.mock:advance(log.respawnDelay - 1)
		expect(count(log.loads, 1)).toBe(1) -- still waiting out the respawn delay
		env.mock:advance(2)
		expect(count(log.loads, 1)).toBe(2)
		expect(p1.Character).never.toBe(first)
		expect(log.pivots[2].cframe.Position).toEqual(Layout.WORLD.plots.crimson.spawn.Position)
		local second = p1.Character
		local onDied = log.died[second]
		env.mock.players:remove(p1)
		env.mock:advance(TICK * 2)
		expect(log.died[second]).toBeNil() -- disconnected when the ruler left
		env.spawn(onDied) -- a death signal that was already in flight
		env.mock:advance(log.respawnDelay + 1)
		expect(count(log.loads, 1)).toBe(2)
	end)

	it("respawns at the new keep when the kingdom changes in the Lobby", function()
		local env, _, kingdoms, log = boot({ mode = "match" })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		kingdoms:assign(p1, "gold")
		env.mock:advance(1)
		expect(#log.pivots).toBe(2)
		expect(log.pivots[2].cframe.Position).toEqual(Layout.WORLD.plots.gold.spawn.Position)
	end)

	it("seats the ruler on the keep's Throne after spawn and again after a respawn (G13.6)", function()
		local env, match, _, log = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local host = match.host
		local keep = host:buildingModel(host.match.sim.kingdoms.crimson.keepId)
		local throne = keep:FindFirstChild("Throne", true)
		expect(throne:IsA("Seat")).toBe(true)
		expect(#log.sits).toBe(1)
		expect(log.sits[1].character).toBe(p1.Character)
		expect(log.sits[1].seat).toBe(throne) -- after the pivot to the plot spawn and the regalia
		expect(#log.pivots).toBe(1)
		expect(#log.attached > 0).toBe(true)
		local first = p1.Character
		log.seatOf[first], log.occupant[throne] = nil, nil -- the dead ruler falls off the seat
		env.spawn(log.died[first])
		env.mock:advance(log.respawnDelay + 1)
		expect(#log.sits).toBe(2)
		expect(log.sits[2].character).toBe(p1.Character)
		expect(log.sits[2].character).never.toBe(first)
		expect(log.sits[2].seat).toBe(throne)
		env.mock:advance(5) -- still seated: the checks do nothing more
		expect(#log.sits).toBe(2)
	end)

	it("a throne that fails to seat the ruler never stops the respawns (#89 L1)", function()
		local env, _, kingdoms, log = boot()
		local broken = 0
		kingdoms.adapter.sit = function()
			broken += 1
			error("seat broke")
		end
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		expect(broken).toBe(1)
		local first = p1.Character
		expect(log.died[first]).never.toBeNil() -- the respawn hook is connected all the same
		env.spawn(log.died[first])
		env.mock:advance(log.respawnDelay + 1)
		expect(count(log.loads, 1)).toBe(2)
		expect(p1.Character).never.toBe(first)
		local warned = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "cannot seat the ruler", 1, true) then
				warned += 1
			end
		end
		expect(warned >= 1).toBe(true)
		-- spec-local: no thread errors from the broken seat
		expect(env.mock.threadErrors).toEqual({})
	end)

	it("a co-ruler stands while the throne is held, and each kingdom has its own throne", function()
		local env, match, _, log = boot({ parties = { [1] = "party", [2] = "party" } })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local p2 = env.mock.players:add({ userId = 2 })
		local p3 = env.mock.players:add({ userId = 3 })
		env.mock:advance(1)
		local host = match.host
		expect(host:kingdomOf(p2)).toBe("crimson")
		local sitters = {}
		for _, entry in log.sits do
			sitters[entry.character] = entry.seat
		end
		expect(sitters[p1.Character]).never.toBeNil()
		expect(sitters[p2.Character]).toBeNil() -- p1 holds crimson's throne
		local theirs = host:buildingModel(host.match.sim.kingdoms[host:kingdomOf(p3)].keepId)
		expect(sitters[p3.Character]).toBe(theirs:FindFirstChild("Throne", true))
		expect(sitters[p3.Character]).never.toBe(sitters[p1.Character])
	end)

	it("seats a seated ruler again when an upgrade rebuilds the keep; not one who got up", function()
		local env, match, _, log = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local host = match.host
		local sim = host.match.sim
		local keepId = sim.kingdoms.crimson.keepId
		local before = host:buildingModel(keepId)
		sim.buildings[keepId].level = 2 -- the upgrade completes: the view rebuilds the keep model
		env.mock:advance(TICK + KingdomServiceDef.THRONE_CHECK)
		local after = host:buildingModel(keepId)
		expect(after == before).toBe(false) -- (the old model is destroyed: compare, never print it)
		expect(#log.sits).toBe(2)
		expect(log.sits[2].character).toBe(p1.Character)
		expect(log.sits[2].seat).toBe(after:FindFirstChild("Throne", true))
		-- walk mode: the ruler got up; the next rebuild leaves them standing
		log.seatOf[p1.Character] = nil
		env.mock:advance(1)
		sim.buildings[keepId].level = 3
		env.mock:advance(TICK + KingdomServiceDef.THRONE_CHECK)
		expect(host:buildingModel(keepId) == after).toBe(false)
		expect(#log.sits).toBe(2)
	end)

	-- #89 L2: a character sits on a throne the way a touch would (no server seat call)
	local function touchSit(log, character, seat)
		local old = log.seatOf[character]
		if old then
			log.occupant[old] = nil
		end
		log.seatOf[character] = seat
		log.occupant[seat] = character
	end

	-- walk mode: the character gets up
	local function standUp(log, character)
		local old = log.seatOf[character]
		if old then
			log.occupant[old] = nil
		end
		log.seatOf[character] = nil
	end

	local function throneOf(match, kingdomId)
		local host = match.host
		return host:buildingModel(host.match.sim.kingdoms[kingdomId].keepId):FindFirstChild("Throne", true)
	end

	it("unseats another kingdom's ruler, a spectator and any other humanoid from a throne (#89 L2)", function()
		local env, match, kingdoms, log = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p3 = env.mock.players:add({ userId = 3 })
		env.mock:advance(1)
		local host = match.host
		expect(host:kingdomOf(p3)).never.toBe("crimson")
		local throne = throneOf(match, "crimson")
		expect(log.occupant[throne]).toBe(p1.Character)
		standUp(log, p1.Character)
		local theirs = throneOf(match, host:kingdomOf(p3))
		-- another kingdom's ruler walks over and sits down
		touchSit(log, p3.Character, throne)
		env.mock:advance(KingdomServiceDef.THRONE_CHECK + 0.1)
		expect(log.occupant[throne]).toBeNil()
		expect(log.seatOf[p3.Character]).toBeNil()
		expect(#log.unseats).toBe(1)
		expect(log.unseats[1].character).toBe(p3.Character)
		expect(log.unseats[1].seat).toBe(throne)
		-- on their own throne they stay
		touchSit(log, p3.Character, theirs)
		env.mock:advance(2)
		expect(log.occupant[theirs]).toBe(p3.Character)
		expect(#log.unseats).toBe(1)
		-- a spectator's character, and a humanoid that is nobody's character
		for userId = 4, 17 do -- every seat taken: the next arrival watches
			env.mock.players:add({ userId = userId })
		end
		local spectator = env.mock.players:add({ userId = 99 })
		env.mock:advance(1)
		expect(kingdoms:getKingdomOf(spectator)).toBeNil()
		if log.occupant[throne] then -- a crimson ruler who just spawned sat down: up again
			standUp(log, log.occupant[throne])
		end
		local stray = env.newInstance("Model")
		spectator.Character = stray
		touchSit(log, stray, throne)
		env.mock:advance(KingdomServiceDef.THRONE_CHECK + 0.1)
		expect(log.occupant[throne]).toBeNil()
		local npc = env.newInstance("Model")
		touchSit(log, npc, throne)
		env.mock:advance(KingdomServiceDef.THRONE_CHECK + 0.1)
		expect(log.occupant[throne]).toBeNil()
		expect(#log.unseats).toBe(3)
		expect(log.unseats[2].character).toBe(stray)
		expect(log.unseats[3].character).toBe(npc)
	end)

	it("lets a co-ruler sit on their own throne while the other ruler is up (#89 L2)", function()
		local env, match, kingdoms, log = boot({ parties = { [1] = "party", [2] = "party" } })
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local p2 = env.mock.players:add({ userId = 2 })
		env.mock:advance(1)
		expect(kingdoms:getKingdomOf(p2)).toBe("crimson")
		local throne = throneOf(match, "crimson")
		standUp(log, p1.Character)
		touchSit(log, p2.Character, throne)
		env.mock:advance(3)
		expect(log.occupant[throne]).toBe(p2.Character)
		expect(#log.unseats).toBe(0)
	end)

	it("a ruler who spawns onto a throne an outsider holds takes it at once (#89 L2)", function()
		local env, match, kingdoms, log = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p3 = env.mock.players:add({ userId = 3 })
		env.mock:advance(1)
		local throne = throneOf(match, "crimson")
		standUp(log, p1.Character)
		touchSit(log, p3.Character, throne)
		-- before any throne check runs: the seat call itself clears the outsider
		local sits = #log.sits
		kingdoms:_seat(p1.UserId, p1.Character, "crimson")
		expect(#log.sits).toBe(sits + 1)
		expect(log.occupant[throne]).toBe(p1.Character)
		expect(log.seatOf[p3.Character]).toBeNil()
		expect(#log.unseats).toBe(1)
		expect(log.unseats[1].character).toBe(p3.Character)
		env.mock:advance(2) -- and the checks leave the rightful ruler alone
		expect(log.occupant[throne]).toBe(p1.Character)
		expect(#log.unseats).toBe(1)
	end)

	it("gives spectators no character", function()
		local env, _, _, log = boot()
		for userId = 1, 17 do
			env.mock.players:add({ userId = userId })
		end
		env.mock:advance(1)
		expect(#log.loads).toBe(16)
		expect(count(log.loads, 17)).toBe(0)
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
		local env, _, kingdoms = boot({ mode = "match" })
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
		local env, match, kingdoms, log = boot({ mode = "match", pacing = fastPacing() })
		env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		local changes, joined = recordMembership(kingdoms), recordJoined()
		local total = 0
		for _, seconds in FAST do
			total += seconds
		end
		env.mock:advance(total + 1)
		expect(match:getPhase()).toBe("Lobby")
		expect(changes).toEqual({ { 1, "crimson" } })
		expect(joined).toEqual({ { 1, "crimson" } })
		expect(count(log.loads, 1)).toBe(2) -- respawned at the fresh world's keep
	end)
end)

describe("With the other workers' services (G7, G11)", function()
	it("runs on the real TreasuryService and PacingService: deposits land, members get Treasury.Changed", function()
		local env, match, kingdoms = boot({ others = true })
		expect(match.durationsSource).toBe("pacing")
		local treasury = match.host.match.sim.treasury
		expect(treasury.seed).toBeNil() -- FORGE-03's service, not the local double
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(match:getPhase()).toBe("Founding")
		local start = treasury:get("crimson")
		env.mock:advance(90)
		local now = treasury:get("crimson")
		expect(now.wood).toBeGreaterThan(start.wood)
		expect(now.stone).toBeGreaterThan(start.stone)
		expect(treasury:get("azure")).toEqual(start) -- no ruler, no citizens: untouched
		local changed = received(env, "Treasury.Changed", p1)
		expect(#changed).toBeGreaterThan(0)
		expect(changed[#changed][1]).toEqual(now) -- the member sees the current totals
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
	end)
end)

describe("Studio debug commands (FL-0068)", function()
	it("registers match.phase, kingdom.respawn and preset vs1.row3 once, acting on the running services", function()
		boot() -- an earlier server in this process
		local env, match, _, log = boot()
		local names = {}
		for _, command in DebugCommands.list() do
			names[command.name] = (names[command.name] or 0) + 1
		end
		expect(names["match.phase"]).toBe(1)
		expect(names["kingdom.respawn"]).toBe(1)
		local presets = {}
		for _, preset in DebugCommands.presets() do
			presets[preset.name] = true
		end
		expect(presets["vs1.row3"]).toBe(true)

		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		expect(count(log.loads, 1)).toBe(1)
		local ok, message = DebugCommands.run(p1, "match.phase", "Conflict")
		expect(ok).toBe(true)
		expect(message).toContain("Conflict")
		expect(match:getPhase()).toBe("Conflict")
		expect((DebugCommands.run(p1, "match.phase", "Results"))).toBe(false) -- not an active phase
		expect((DebugCommands.run(p1, "match.phase", "Lobby"))).toBe(false)
		expect(DebugCommands.runPreset(p1, "vs1.row3")).toBe(true)
		env.mock:advance(1)
		expect(count(log.loads, 1)).toBe(2) -- respawned by the preset
		for userId = 2, 16 do
			env.mock.players:add({ userId = userId })
		end
		local spectator = env.mock.players:add({ userId = 100 })
		env.mock:advance(1)
		local _, why = DebugCommands.run(spectator, "kingdom.respawn")
		expect(why).toContain("not in a kingdom")
	end)
end)

describe("Kingdom and Match remotes (G8)", function()
	it("Match.GetState and Match.State carry (phase, endsAtServerTime?, startedAtServerTime)", function()
		local env = boot({ mode = "match" })
		local p1 = env.mock.players:add({ userId = 1 })
		local first = received(env, "Match.State", p1)
		expect(#first).toBe(1) -- on arrival
		expect(first[1][1]).toBe("Lobby")
		env.mock:advance(TICK)
		local phase, endsAt, startedAt = invoke(env, p1, "Match.GetState")
		expect(phase).toBe("Lobby")
		expect(endsAt - env.serverTimeNow()).toBeNear(MATCH_DURATIONS.Lobby, 0.5)
		expect(type(startedAt)).toBe("number")
		env.mock:advance(MATCH_DURATIONS.Lobby + TICK)
		phase, endsAt, startedAt = invoke(env, p1, "Match.GetState")
		expect(phase).toBe("Founding")
		expect(endsAt - env.serverTimeNow()).toBeNear(MATCH_DURATIONS.Founding, 0.5)
		expect(env.serverTimeNow() - startedAt).toBeNear(TICK, TICK + 0.01) -- Founding just began
		local states = received(env, "Match.State", p1)
		expect(states[#states][1]).toBe("Founding")
		expect(states[#states][3]).toBe(startedAt)
	end)

	it("Kingdom.GetState returns every kingdom and mine; Kingdom.State follows membership", function()
		local env = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		local state = invoke(env, p1, "Kingdom.GetState")
		expect(state.mine).toBe("crimson")
		expect(#state.kingdoms).toBe(4)
		expect(state.kingdoms[1].id).toBe("crimson")
		expect(state.kingdoms[1].rulers).toEqual({ 1 })
		local before = #received(env, "Kingdom.State", p1)
		env.mock.players:add({ userId = 2 })
		env.mock:advance(TICK)
		local pushed = received(env, "Kingdom.State", p1)
		expect(#pushed).toBe(before + 1)
		expect(pushed[#pushed][1].mine).toBe("crimson")
		expect(pushed[#pushed][1].kingdoms[2].rulers).toEqual({ 2 })
		-- a membership change goes out on the next tick even inside the 0.5 s throttle window
		env.mock.players:add({ userId = 3 })
		env.mock:advance(TICK)
		pushed = received(env, "Kingdom.State", p1)
		expect(#pushed).toBe(before + 2)
		expect(pushed[#pushed][1].kingdoms[3].rulers).toEqual({ 3 })
		env.mock:advance(30)
		expect(#received(env, "Kingdom.State", p1)).toBe(before + 2) -- nothing changed, nothing sent
	end)

	it("Kingdom.State goes out again when a kingdom condition moves by a whole point (#68 L4)", function()
		local env, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		local k = match.host.match.sim.kingdoms.crimson
		k.conditions = { happiness = 50, stability = 50, morale = 50 }
		env.mock:advance(1)
		local before = #received(env, "Kingdom.State", p1)
		k.conditions.happiness = 50.3 -- a drift step: not worth a push
		env.mock:advance(1)
		expect(#received(env, "Kingdom.State", p1)).toBe(before)
		k.conditions.happiness = 51.2
		env.mock:advance(1)
		local pushed = received(env, "Kingdom.State", p1)
		expect(#pushed).toBe(before + 1)
		expect(pushed[#pushed][1].kingdoms[1].happiness).toBe(51.2)
		k.conditions.morale = 45
		env.mock:advance(1)
		expect(#received(env, "Kingdom.State", p1)).toBe(before + 2)
	end)

	it("Kingdom.SetJobQuota returns a boolean and validates its arguments", function()
		local env = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(TICK)
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 5)).toBe(true)
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 51)).toBeNil() -- rejected before the handler
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "hauler", 2)).toBeNil() -- the pool has no quota
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 1.5)).toBeNil()
		local second = env.mock.players:add({ userId = 2 })
		env.mock:advance(TICK)
		expect(invoke(env, second, "Kingdom.SetJobQuota", "miner", 1)).toBe(true)
	end)

	it("Match.Ended and the G9 MatchEnded fire once when the slice ends on the first capture", function()
		local env, match = boot()
		local ended = {}
		GameEvents.MatchEnded:connect(function(payload)
			table.insert(ended, payload)
		end)
		local captured = {}
		GameEvents.ObjectiveCaptured:connect(function(objectiveId, kingdomId)
			table.insert(captured, { objectiveId, kingdomId })
		end)
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		-- stand the ruler on the watchtower (the host reads the character's HumanoidRootPart)
		local tower = match.host.match.sim.objectives.list[1]
		local spawn = p1.Character.HumanoidRootPart.CFrame.Position
		p1.Character.HumanoidRootPart.CFrame = CFrame.new(tower.x, 3, tower.z)
		-- the sim follows the character at Match.rulerMaxSpeed (FL-0122): the walk from the spawn, then the capture
		local walk = math.sqrt((tower.x - spawn.X) ^ 2 + (tower.z - spawn.Z) ^ 2) / MatchConfig.rulerMaxSpeed
		env.mock:advance(walk + tower.captureSeconds + 2)
		expect(match:getPhase()).toBe("Results")
		expect(captured).toEqual({ { "watchtower", "crimson" } })
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBe("crimson")
		expect(#ended[1].standings).toBe(4)
		local keys = {}
		for key in ended[1] do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "durationSec", "standings", "winner" })
		local remoteEnded = received(env, "Match.Ended", p1)
		expect(#remoteEnded).toBe(1)
		expect(remoteEnded[1][1]).toEqual(ended[1])
		env.mock:advance(120)
		expect(match:getPhase()).toBe("Results")
		expect(#ended).toBe(1)
		-- a player who arrives during Results gets the summary too (#70 M2); the first one not again
		local late = env.mock.players:add({ userId = 2 })
		env.mock:advance(TICK)
		local function sentTo(player)
			local out = {}
			for _, entry in env.mock.remotes:sent(remote(env, "Match.Ended")) do
				if entry.player == player then
					table.insert(out, entry.args)
				end
			end
			return out
		end
		local lateEnded = sentTo(late) -- (the broadcast went out before this player existed)
		expect(#lateEnded).toBe(1)
		expect(lateEnded[1][1]).toEqual(ended[1])
		expect(#sentTo(p1)).toBe(0) -- the first player had the broadcast only
		expect(#received(env, "Match.Ended", p1)).toBe(1)
	end)

	it("match mode: the summary goes to arrivals during Results only, never after (#70 M2)", function()
		local env, match = boot({ mode = "match", pacing = fastPacing() })
		local function sentTo(player)
			local out = {}
			for _, entry in env.mock.remotes:sent(remote(env, "Match.Ended")) do
				if entry.player == player then
					table.insert(out, entry.args)
				end
			end
			return out
		end
		local early = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		expect(#sentTo(early)).toBe(0) -- nothing to summarise yet
		local guard = 0
		while match:getPhase() ~= "Results" and guard < 400 do
			env.mock:advance(TICK)
			guard += 1
		end
		expect(match:getPhase()).toBe("Results")
		local during = env.mock.players:add({ userId = 2 })
		env.mock:advance(TICK)
		expect(#sentTo(during)).toBe(1)
		guard = 0
		while match:getPhase() == "Results" and guard < 400 do
			env.mock:advance(TICK)
			guard += 1
		end
		expect(match:getPhase()).toBe("Lobby")
		local after = env.mock.players:add({ userId = 3 })
		env.mock:advance(TICK)
		expect(#sentTo(after)).toBe(0) -- a new match: the old summary is gone
	end)
end)
