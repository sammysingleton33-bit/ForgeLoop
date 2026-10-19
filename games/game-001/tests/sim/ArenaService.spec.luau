--[[
	ArenaService, SupportService and the Arena.* remotes (FL-0071; CONTRACTS G12.2/G12.4) on the real match: the arena
	host MatchService calls at the end of Endgame, the stages the clients see, who may vote, choose and act, the duel on the
	server's own geometry, forfeits and cancels, and the match result the crowning reports. Stages are shortened (config
	Arena is a table the service reads, so the specs hand it a short one); the logic under test reads only the config.
	Lune has no characters: the spawn adapter and the placement hook are recording doubles.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local ArenaFlow = require("@game/ReplicatedStorage/Game/Arena/ArenaFlow")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")
local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local ArenaRemotes = require("@game/ReplicatedStorage/Game/Arena/Remotes")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")
local LeadershipServiceDef = require("@game/ServerScriptService/Game/Services/LeadershipService")
local SupportServiceDef = require("@game/ServerScriptService/Game/Services/SupportService")
local ArenaServiceDef = require("@game/ServerScriptService/Game/Services/ArenaService")

local FAST_PHASES = { Lobby = 2, Founding = 3, Expansion = 3, Conflict = 3, Endgame = 3, Results = 2 }
local savedMode = MatchConfig.mode
local registries = {}

-- short stages and a ring close enough to fight on
local function shortConfig(): any
	local config = table.clone(ArenaConfig)
	config.voteSeconds = 4
	config.loadoutSeconds = 4
	config.introSeconds = 2
	config.duelMaxSeconds = 30
	config.crowningSeconds = 3
	config.enabled = true
	config.site = { x = 0, z = 0, separation = 3 }
	return config
end

local function remote(env: any, name: string): any
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

local function received(env: any, name: string, player: any?): { any }
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, name)) do
		if player == nil or entry.direction == "toAllClients" or entry.player == player then
			table.insert(out, entry.args)
		end
	end
	return out
end

local function invoke(env: any, player: any, name: string, ...: any)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

local function fire(env: any, player: any, name: string, ...: any)
	local args = table.pack(...)
	env.mock.remotes:asClient(player, function()
		remote(env, name):FireServer(table.unpack(args, 1, args.n))
	end)
end

afterEach(function()
	local problem: string? = nil
	for _, booted in registries do
		booted.registry:destroy()
		for _, entry in booted.env.mock.logs do
			if entry.level == "error" and problem == nil then
				problem = `server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`
			end
		end
	end
	table.clear(registries)
	MatchConfig.mode = savedMode
	GameEvents.disconnectAll()
	if problem then
		error(problem)
	end
end)

-- The match in "match" mode with fast phases, players seated, and the arena services. `humans` = userIds to add.
local function boot(humans: { number }, parties: { [number]: string }?): any
	MatchConfig.mode = "match"
	local env = MockEnv.new({
		seed = 9,
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Arena = ArenaRemotes } },
	})
	local pacing = {
		name = "PacingService",
		new = function()
			return {
				phaseDurations = function()
					return table.clone(FAST_PHASES)
				end,
			}
		end,
	}
	local registry = Loader.load(env, {
		RemoteServiceDef,
		MatchServiceDef,
		KingdomServiceDef,
		LeadershipServiceDef,
		SupportServiceDef,
		ArenaServiceDef,
		pacing,
	})
	table.insert(registries, { registry = registry, env = env })
	local world = { env = env, registry = registry }
	world.match = registry:get("MatchService")
	world.kingdoms = registry:get("KingdomService")
	world.arena = registry:get("ArenaService")
	world.support = registry:get("SupportService")
	world.leadership = registry:get("LeadershipService")
	world.arena.config = shortConfig()
	world.placed = {}
	world.kingdoms.adapter = {
		partyOf = function(player: any)
			return if parties then parties[player.UserId] else nil
		end,
		load = function(player: any)
			env.wait()
			local character = env.newInstance("Model")
			character.Name = player.Name
			local root = env.newInstance("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.new(0, 5, 100 + player.UserId)
			root.Parent = character
			character.Parent = env.Workspace
			player.Character = character
			return character
		end,
		pivot = function(character: any, cframe: any)
			character.HumanoidRootPart.CFrame = cframe
		end,
		attach = function() end,
		onDied = function()
			return { Disconnect = function() end }
		end,
		respawnDelay = function()
			return 5
		end,
	}
	-- the placement hook: record, and stand the character there so the server's geometry sees it
	world.arena.placeAt = function(userId: number, x: number, z: number, toX: number, toZ: number, height: number?)
		table.insert(world.placed, { userId = userId, x = x, z = z, toX = toX, toZ = toZ, height = height })
		local player = env.Players:GetPlayerByUserId(userId)
		local root = player.Character.HumanoidRootPart
		local dx, dz = toX - x, toZ - z
		local length = math.sqrt(dx * dx + dz * dz)
		root.CFrame = CFrame.lookAt(Vector3.new(x, 5, z), Vector3.new(x + dx / length, 5, z + dz / length))
	end
	world.players = {}
	for _, userId in humans do
		world.players[userId] = env.mock.players:add({ userId = userId })
	end
	env.mock:advance(FAST_PHASES.Lobby + 1)
	world.sim = world.match.host.match.sim
	return world
end

-- advances in small steps until the arena shows `stage` (fails loudly if it never does)
local function advanceTo(world: any, stage: string, limit: number?)
	local waited = 0
	while world.arena:state().stage ~= stage and waited < (limit or 60) do
		world.env.mock:advance(0.1)
		waited += 0.1
	end
	expect(world.arena:state().stage).toBe(stage)
end

-- every phase the match reports from now on
local function watchPhases(world: any): { [string]: boolean }
	local seen = {}
	world.match.phaseChanged:connect(function(phase: string)
		seen[phase] = true
	end)
	return seen
end

-- the two kingdoms the players rule, made the top two in Crown Points, then Endgame run out: the arena begins
local function reachArena(world: any)
	local a = world.sim:kingdomOfUser(1)
	local b = world.sim:kingdomOfUser(2)
	assert(a and b, "both players rule a kingdom")
	world.a, world.b = a.id, b.id
	world.sim:addCrownPoints(a.id, 100, "spec")
	world.sim:addCrownPoints(b.id, 50, "spec")
	world.env.mock:advance(FAST_PHASES.Founding * 3 + 1)
	world.env.mock:advance(FAST_PHASES.Endgame)
end

describe("ArenaService: the host", function()
	it(
		"is the arena MatchService asks at the end of Endgame, with the two kingdoms that have the most Crown Points",
		function()
			local world = boot({ 1, 2 })
			reachArena(world)
			local state = world.arena:state()
			expect(state.stage).toBe("loadout") -- one ruler each: no vote
			expect(state.a.kingdom).toBe(world.a)
			expect(state.b.kingdom).toBe(world.b)
			expect(state.a.userId).toBe(1)
			expect(state.b.userId).toBe(2)
			expect(world.match:getPhase()).toBe("Endgame") -- the arena holds the match
		end
	)

	it("closes the leadership ledger when the arena begins: the Endgame fed ratio is credited", function()
		local world = boot({ 1, 2 })
		world.sim.kingdoms[world.sim:kingdomOfUser(1).id].fedRatio = 1
		reachArena(world)
		expect(world.arena:state().stage).toBe("loadout")
		local kept = 0
		for _, moment in world.leadership:getMoments(world.a, 1, 200) do
			if moment.act == "fedRatioKept" then
				kept += 1
			end
		end
		expect(kept).toBe(1)
	end)

	it("shows each kingdom's living citizens to the stands", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		local state = world.arena:state()
		local living = 0
		for _, id in world.sim.kingdoms[world.a].citizenIds do
			local citizen = world.sim.citizens[id]
			if citizen and citizen.alive ~= false then
				living += 1
			end
		end
		expect(living > 0).toBe(true)
		expect(state.a.citizens).toBe(living)
		expect(state.b.citizens > 0).toBe(true)
	end)

	it("only `enabled = true` switches the arena on (a truthy value does not)", function()
		local world = boot({ 1, 2 })
		local sloppy = shortConfig()
		sloppy.enabled = 1 :: any
		world.arena.config = sloppy
		reachArena(world)
		expect(world.arena:state().stage).toBe("done")
		expect(world.arena._flow).toBeNil()
	end)

	it("ships switched off: the match goes to Crown Points at once, as with no host", function()
		local world = boot({ 1, 2 })
		world.arena.config = ArenaConfig -- the shipped config
		expect(ArenaConfig.enabled).toBe(false)
		local phases = watchPhases(world)
		reachArena(world)
		expect(world.arena:state().stage).toBe("done")
		expect(world.arena._flow).toBeNil()
		world.env.mock:advance(MatchConfig.tickSeconds * 3)
		expect(phases.Results).toBe(true)
	end)

	it("publishes the state to everyone on every change, and answers Arena.GetState", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		local pushed = received(world.env, "Arena.State")
		expect(#pushed >= 1).toBe(true)
		expect(pushed[#pushed][1].stage).toBe("loadout")
		local state = invoke(world.env, world.players[1], "Arena.GetState")
		expect(state.stage).toBe("loadout")
		expect(state.a.userId).toBe(1)
		local spectator = boot({ 1, 2 })
		local idle = invoke(spectator.env, spectator.players[1], "Arena.GetState")
		expect(idle.stage).toBe("done") -- no arena yet
	end)
end)

describe("ArenaService: pushes", function()
	it("does not push the state again while nothing has changed", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		local before = #received(world.env, "Arena.State")
		world.env.mock:advance(0.5)
		world.env.mock:advance(0.5)
		expect(#received(world.env, "Arena.State")).toBe(before)
	end)
end)

describe("ArenaService: voting and the loadout", function()
	it("co-rulers vote for their champion over Arena.Vote, and the vote closes when all have voted", function()
		local world = boot({ 1, 2, 3 }, { [1] = "crew", [3] = "crew" })
		reachArena(world)
		local state = world.arena:state()
		expect(state.stage).toBe("vote")
		expect(invoke(world.env, world.players[1], "Arena.Vote", 3)).toBe(true)
		expect(world.arena:state().stage).toBe("vote") -- one voter has yet to choose
		expect(invoke(world.env, world.players[3], "Arena.Vote", 3)).toBe(true)
		world.env.mock:advance(0.5)
		state = world.arena:state()
		expect(state.stage).toBe("loadout")
		expect(state.a.userId == 3 or state.b.userId == 3).toBe(true)
		expect(invoke(world.env, world.players[2], "Arena.Vote", 3)).toBe(false) -- not a voter, and the vote is over
	end)

	it("a second arena cannot begin while one is running", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		expect(world.arena:_begin({ world.a, world.b })).toBe(false)
		expect(world.arena:state().stage).toBe("loadout")
	end)

	it("refuses a vote outside the vote stage", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		expect(invoke(world.env, world.players[1], "Arena.Vote", 1)).toBe(false)
		expect(invoke(world.env, world.players[1], "Arena.Vote", 0 / 0)).toBeNil() -- the remote layer drops a bad argument
	end)

	it("takes the champion's choice from the sender, not from the call", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		local ok, reason = invoke(world.env, world.players[1], "Arena.Choose", "mace", "heavy", {})
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		local state = world.arena:state()
		expect(state.a.weapon).toBe("mace")
		expect(state.a.armour).toBe("heavy")
		expect(state.b.weapon).toBe(ArenaConfig.defaultWeapon) -- the other champion's loadout is untouched
		ok, reason = invoke(world.env, world.players[1], "Arena.Choose", "mace", "heavy", { "reforge" })
		expect(ok).toBe(false)
		expect(reason).toBe("not_offered") -- nobody has offered a perk yet
		ok, reason = invoke(world.env, world.players[1], "Arena.Choose", "mace", "heavy", { "crowdRally" })
		expect(reason).toBe("not_offered") -- the Rally is for the Adoring tier only; the server built the offers
		expect(invoke(world.env, world.players[1], "Arena.Choose", "laser", "heavy", {})).toBeNil() -- bad enum: dropped
	end)

	it("a spectator's Choose is refused", function()
		local world = boot({ 1, 2, 3 })
		reachArena(world)
		local stranger = nil
		for userId, player in world.players do
			if userId ~= 1 and userId ~= 2 then
				stranger = player
			end
		end
		local ok, reason = invoke(world.env, stranger, "Arena.Choose", "mace", "heavy", {})
		expect(ok).toBe(false)
		expect(reason).toBe("not_champion")
	end)
end)

describe("ArenaService: the duel", function()
	-- runs the stages up to the duel
	local function toDuel(world: any)
		reachArena(world)
		advanceTo(world, "duel")
	end

	it("without a site override the champions stand on the venue's marks, at their height", function()
		local world = boot({ 1, 2 })
		local config = shortConfig()
		config.site = nil
		world.arena.config = config
		reachArena(world)
		advanceTo(world, "intro")
		local marks = WorldLayout.arena
		expect(#world.placed).toBe(2)
		local first, second = world.placed[1], world.placed[2]
		expect(math.abs(first.x - marks.spawnA.Position.X) < 1e-6).toBe(true)
		expect(math.abs(first.z - marks.spawnA.Position.Z) < 1e-6).toBe(true)
		expect(math.abs(first.toX - marks.spawnB.Position.X) < 1e-6).toBe(true)
		expect(math.abs(second.x - marks.spawnB.Position.X) < 1e-6).toBe(true)
		expect(math.abs(second.toX - marks.spawnA.Position.X) < 1e-6).toBe(true)
		expect(math.abs(first.height - marks.spawnA.Position.Y) < 1e-6).toBe(true)
		expect(math.abs(second.height - marks.spawnB.Position.Y) < 1e-6).toBe(true)
	end)

	it("takes the champions' support into the duel: the tier's blessing reaches the model", function()
		local world = boot({ 1, 2 })
		world.support.forChampion = function(): any
			return { score = 95, tier = "adoring", offers = {}, slots = 0, reasons = {} }
		end
		toDuel(world)
		local model = world.arena._runner._model
		expect(model.a.passive.damageReduction > 0).toBe(true)
		expect(model.b.passive.damageReduction > 0).toBe(true)
	end)

	it("places both champions on the ring, facing each other, at the start of the intro", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		advanceTo(world, "intro")
		expect(#world.placed).toBe(2)
		expect(world.placed[1].userId).toBe(1)
		expect(world.placed[1].x).toBe(-1.5)
		expect(world.placed[1].toX).toBe(1.5)
		expect(world.placed[2].userId).toBe(2)
		expect(world.placed[2].x).toBe(1.5)
	end)

	it("relays shares-only events, and a champion's Arena.Action lands a hit on the server's geometry", function()
		local world = boot({ 1, 2 })
		toDuel(world)
		fire(world.env, world.players[1], "Arena.Action", "light")
		world.env.mock:advance(1.5)
		local hit = nil
		local snapshots = 0
		for _, args in received(world.env, "Arena.Events") do
			for _, event in args[1] do
				if event.kind == "hit" and hit == nil then
					hit = event
				end
				if event.kind == "snapshot" then
					snapshots += 1
				end
			end
		end
		assert(hit, "the swing landed")
		expect(hit.side).toBe("a")
		expect(hit.data.damageShare > 0).toBe(true)
		expect(hit.data.damage).toBeNil()
		expect(snapshots >= 3).toBe(true)
	end)

	it("drops an action from a stranger, from a champion outside the duel, and a bad action", function()
		local world = boot({ 1, 2, 3 })
		reachArena(world)
		fire(world.env, world.players[1], "Arena.Action", "light") -- loadout stage: nothing runs
		expect(#received(world.env, "Arena.Events")).toBe(0)
		advanceTo(world, "duel")
		fire(world.env, world.players[3], "Arena.Action", "light") -- a spectator
		fire(world.env, world.players[1], "Arena.Action", "fireball") -- not a DuelAction: dropped by the remote layer
		world.env.mock:advance(1.5)
		for _, args in received(world.env, "Arena.Events") do
			for _, event in args[1] do
				expect(event.kind ~= "hit").toBe(true)
			end
		end
	end)

	it("a knockout ends the duel, crowns the winner's kingdom, and the match ends with it as the winner", function()
		local world = boot({ 1, 2 })
		local ended = {}
		GameEvents.MatchEnded:connect(function(payload)
			table.insert(ended, payload)
		end)
		local phases = watchPhases(world)
		toDuel(world)
		world.arena._runner._model.b.hp = 1
		fire(world.env, world.players[1], "Arena.Action", "light")
		world.env.mock:advance(1.5)
		local state = world.arena:state()
		expect(state.stage).toBe("crowning")
		expect(state.winner).toBe(1)
		advanceTo(world, "done")
		world.env.mock:advance(MatchConfig.tickSeconds * 3)
		expect(phases.Results).toBe(true)
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBe(world.a)
	end)

	it("the champion with fewer Crown Points can win the match by the duel", function()
		local world = boot({ 1, 2 })
		local ended = {}
		GameEvents.MatchEnded:connect(function(payload)
			table.insert(ended, payload)
		end)
		toDuel(world)
		world.arena._runner._model.a.hp = 1
		fire(world.env, world.players[2], "Arena.Action", "light")
		world.env.mock:advance(1.5)
		expect(world.arena:state().winner).toBe(2)
		advanceTo(world, "done")
		world.env.mock:advance(MatchConfig.tickSeconds * 3)
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBe(world.b) -- a led on Crown Points
	end)

	it("a player who leaves during the duel forfeits: the other champion's kingdom wins", function()
		local world = boot({ 1, 2 })
		toDuel(world)
		world.env.mock.players:remove(world.players[1])
		world.env.mock:advance(0.2)
		expect(world.arena:state().stage).toBe("duel") -- a forfeit settles over the simultaneous window first
		world.env.mock:advance(ArenaConfig.simultaneousSeconds + 0.5)
		local state = world.arena:state()
		expect(state.stage).toBe("crowning")
		expect(state.winner).toBe(2)
		local forfeit = false
		for _, args in received(world.env, "Arena.Events") do
			for _, event in args[1] do
				forfeit = forfeit or (event.kind == "ended" and event.data.reason == "forfeit" and event.side == "b")
			end
		end
		expect(forfeit).toBe(true)
	end)

	it("a player who leaves before the duel forfeits through the flow", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		world.env.mock.players:remove(world.players[2])
		world.env.mock:advance(0.2)
		expect(world.arena:state().stage).toBe("crowning")
		expect(world.arena:state().winner).toBe(1)
	end)

	it("a draw by the clock reports no winner: the match falls back to Crown Points", function()
		local world = boot({ 1, 2 })
		local ended = {}
		GameEvents.MatchEnded:connect(function(payload)
			table.insert(ended, payload)
		end)
		local phases = watchPhases(world)
		toDuel(world)
		-- nobody swings: this arena's safety clock is shorter than the duel's own time cap, so the clock ends it: a draw
		advanceTo(world, "crowning", world.arena.config.duelMaxSeconds + 5)
		expect(world.arena:state().winner).toBeNil()
		advanceTo(world, "done")
		world.env.mock:advance(MatchConfig.tickSeconds * 3)
		expect(phases.Results).toBe(true)
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBe(world.a) -- no duel winner (above): Crown Points decide, and a leads
	end)

	it("a cancel from the match clears the arena and reports no result of its own", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		world.match.host.match:_cancelArena("spec")
		expect(world.arena:state().stage).toBe("done")
		local last = received(world.env, "Arena.State")
		expect(last[#last][1].stage).toBe("done")
	end)
end)

describe("ArenaService: AI kingdoms", function()
	it("a qualified kingdom with no human ruler fields an AI champion, and an all-AI arena runs by itself", function()
		local world = boot({})
		local phases = watchPhases(world)
		assert(world.match.host.match:debugSetPhase("Endgame")) -- no players: start the match by hand
		world.sim:addCrownPoints("crimson", 100, "spec")
		world.sim:addCrownPoints("azure", 50, "spec")
		world.env.mock:advance(FAST_PHASES.Endgame + 0.5)
		local state = world.arena:state()
		expect(state.stage).toBe("intro") -- two AI champions: no vote, no loadout
		expect(state.a.isAI).toBe(true)
		expect(state.a.userId).toBe(ArenaFlow.AI_USER_ID.a)
		expect(state.b.userId).toBe(ArenaFlow.AI_USER_ID.b)
		advanceTo(world, "duel")
		advanceTo(world, "done", world.arena.config.duelMaxSeconds + world.arena.config.crowningSeconds + 5)
		world.env.mock:advance(MatchConfig.tickSeconds * 3)
		expect(phases.Results).toBe(true)
	end)
end)

describe("SupportService", function()
	it("gives a ruler their own view over the Kingdom.GetSupport remote, and nobody else's", function()
		local world = boot({ 1, 2, 3 })
		world.leadership:sample()
		local view = invoke(world.env, world.players[1], "Kingdom.GetSupport")
		assert(view, "a view")
		expect(view.userId).toBe(1)
		expect(view.kingdom).toBe(world.sim:kingdomOfUser(1).id)
		expect(view.score >= 0 and view.score <= 100).toBe(true)
		expect(type(view.tier)).toBe("string")
		expect(view.slots).toBeTruthy()
		local other = invoke(world.env, world.players[2], "Kingdom.GetSupport")
		expect(other.userId).toBe(2)
		expect(other.kingdom).toBe(world.sim:kingdomOfUser(2).id)
	end)

	it("stays dark while the arena is switched off: GetSupport answers nil and nothing is pushed", function()
		local world = boot({ 1, 2 })
		world.arena.config = ArenaConfig -- the shipped config: enabled = false
		expect(world.support:enabled()).toBe(false)
		local before = #received(world.env, "Kingdom.Support", world.players[1])
		world.leadership:sample()
		expect(#received(world.env, "Kingdom.Support", world.players[1])).toBe(before)
		expect(invoke(world.env, world.players[1], "Kingdom.GetSupport")).toBeNil()
		-- the model behind it is untouched: switching on brings the same view
		world.arena.config = shortConfig()
		expect(world.support:enabled()).toBe(true)
		world.env.mock:advance(world.leadership.config.sampling.intervalSeconds + 1)
		world.leadership:sample()
		expect(#received(world.env, "Kingdom.Support", world.players[1]) > before).toBe(true)
		local view = invoke(world.env, world.players[1], "Kingdom.GetSupport")
		assert(view, "a view")
		expect(view.userId).toBe(1)
	end)

	it("pushes Kingdom.Support to every ruler after each leadership sample", function()
		local world = boot({ 1, 2 })
		local before = #received(world.env, "Kingdom.Support", world.players[1])
		world.leadership:sample()
		expect(#received(world.env, "Kingdom.Support", world.players[1])).toBe(before + 1)
		expect(#received(world.env, "Kingdom.Support", world.players[2]) >= 1).toBe(true)
	end)

	it("an AI champion's reasons are the kingdom's own moments, not a departed ruler's personal ones", function()
		local world = boot({ 1, 2 })
		local kingdom = world.sim:kingdomOfUser(1).id
		world.leadership:record(kingdom, 1, "starvation", 1) -- ruler 1's own conduct
		world.leadership:record(kingdom, nil, "keepUpgraded", 1) -- the kingdom's reputation
		world.leadership:sample()
		local human = world.support:forChampion(1, kingdom)
		assert(human, "support")
		expect(table.find(human.reasons, "Let the kingdom go hungry")).never.toBeNil()
		local ai = world.support:forChampion(nil, kingdom)
		assert(ai, "support")
		expect(table.find(ai.reasons, "Let the kingdom go hungry")).toBeNil()
		expect(table.find(ai.reasons, "Raised the keep for all to see")).never.toBeNil()
	end)

	it("names the three moments that moved the score most as the champion's reasons, each text once", function()
		local world = boot({ 1, 2 })
		local kingdom = world.sim:kingdomOfUser(1).id
		world.leadership:record(kingdom, 1, "starvation", 1) -- -5
		world.leadership:record(kingdom, 1, "fedRatioKept", 1) -- +4
		world.leadership:record(kingdom, 1, "defendedRaid", 1) -- +3
		world.leadership:record(kingdom, 1, "petitionFulfilled", 1) -- +3
		world.leadership:record(kingdom, 1, "starvation", 1)
		world.leadership:sample()
		local support = world.support:forChampion(1, kingdom)
		assert(support, "support")
		expect(#support.reasons).toBe(3)
		expect(support.reasons[1]).toBe("Let the kingdom go hungry")
		expect(support.reasons[2]).toBe("Kept the kingdom fed through the phase")
		expect(support.reasons[3]).toBe("Heard a citizen's petition") -- of the two +3 acts, the newer
	end)

	it("has no view for a kingdom that is not in the match", function()
		local world = boot({ 1 })
		expect(world.support:getView("nowhere", 1)).toBeNil()
		expect(world.support:forChampion(1, "nowhere")).toBeNil()
	end)
end)
