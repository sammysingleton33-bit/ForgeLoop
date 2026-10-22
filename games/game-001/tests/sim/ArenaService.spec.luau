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
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
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
-- A Kit that records what the arena asks of it and builds rigs with the Kit's own geometry rules: a Root part 3.2 above
-- the feet with PivotOffset (0, -3.2, 0), the front along -Z, a weapon modelled in grip space with `Grip` undoing its turned
-- Handle, and armour whose Handle holds an Attachment named for the body point it fits.
local ROOT_HEIGHT = 3.2
local WEAPON_REACH = 4
local WEAPON_HANDLE = CFrame.Angles(0, 0, math.rad(90)) -- the cylinder Handle is turned upright
local function fakeKit(env: any, log: { any }): any
	local function part(name: string, size: Vector3, at: CFrame, parent: any): any
		local p = env.newInstance("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at
		p.Parent = parent
		return p
	end
	-- Kit/Gear.luau builds an armour piece's Attachment as the inverse of its Handle's CFrame: the Handle is offset and
	-- tilted, the Attachment names the point on the body the piece fits.
	local ARMOUR_HANDLE = CFrame.new(0.3, 0.2, -0.1) * CFrame.Angles(0, 0, math.rad(8))
	local function accessory(name: string, attachment: string): any
		local a = env.newInstance("Accessory")
		a.Name = name
		local handle = part("Handle", Vector3.new(1, 1, 1), ARMOUR_HANDLE, a)
		local att = env.newInstance("Attachment")
		att.Name = attachment
		att.CFrame = ARMOUR_HANDLE:Inverse()
		att.Parent = handle
		return a
	end
	local kit = {}
	function kit.character(kind: string, job: string, color: Color3, _look: any, kingdom: string?): any
		table.insert(log, { what = "character", kind = kind, job = job, color = color, kingdom = kingdom })
		local model = env.newInstance("Model")
		model.Name = "Rig"
		local root = part("Root", Vector3.new(1, 1, 1), CFrame.new(0, ROOT_HEIGHT, 0), model)
		root.PivotOffset = CFrame.new(0, -ROOT_HEIGHT, 0)
		model.PrimaryPart = root
		part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 5.5, 0), model)
		part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.5, 0), model)
		part("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3.5, 0), model)
		local arm = model:FindFirstChild("RightArm")
		local held = part("Tool", Vector3.new(1, 4, 1), CFrame.new(1.5, 2.5, 0), model)
		local joint = env.newInstance("Motor6D") -- the rig's `Tool` joint drives the held item (Sim/Pose.JOINTS)
		joint.Name = "Tool"
		joint.Part0 = arm
		joint.Part1 = held
		joint.Parent = arm
		local orb = part("Orb", Vector3.new(1, 1, 1), CFrame.new(1.5, 4.5, 0), model) -- the governor's orb, a detail of the staff
		orb:SetAttribute("KitDetailKind", "orb")
		local detail = env.newInstance("Weld")
		detail.Name = "DetailWeld"
		detail.Part0 = held
		detail.Part1 = orb
		detail.Parent = orb
		return model
	end
	function kit.armour(name: string, color: Color3): { any }
		table.insert(log, { what = "armour", armour = name, color = color })
		return {
			accessory("Helm", "HatAttachment"),
			accessory("Plate", "BodyFrontAttachment"),
			accessory("Cape", "BodyBackAttachment"),
			accessory("PauldronL", "LeftCollarAttachment"),
			accessory("PauldronR", "RightCollarAttachment"),
		}
	end
	function kit.weapon(name: string, color: Color3): any
		table.insert(log, { what = "weapon", weapon = name, color = color })
		local tool = env.newInstance("Tool")
		tool.Name = "Blade"
		part("Handle", Vector3.new(1, 1, 1), WEAPON_HANDLE, tool)
		tool.Grip = WEAPON_HANDLE:Inverse() -- Kit.weapon: Grip = the Handle's CFrame inverse
		tool:SetAttribute("KitReach", WEAPON_REACH)
		return tool
	end
	function kit.arenaDress(model: any, colorA: Color3?, colorB: Color3?)
		table.insert(log, { what = "dress", model = model, colorA = colorA, colorB = colorB })
	end
	return kit
end

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
	world.kitLog = {}
	world.arena.kit = fakeKit(env, world.kitLog)
	world.venue = env.newInstance("Model") -- WorldService names and tags the real one CrownArena
	world.venue.Name = "CrownArena"
	world.venue.Parent = env.Workspace
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
			local humanoid = env.newInstance("Humanoid")
			humanoid.Name = "Humanoid"
			humanoid.WalkSpeed = 40
			humanoid.Parent = character
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

	it("ships switched on, and runs the arena on the shipped config", function()
		local world = boot({ 1, 2 })
		local shipped = table.clone(ArenaConfig)
		expect(shipped.enabled).toBe(true)
		world.arena.config = shipped
		reachArena(world)
		expect(world.arena._flow).never.toBeNil()
		expect(world.arena:state().stage).never.toBe("done")
	end)

	it("switched off: the match goes to Crown Points at once, as with no host", function()
		local world = boot({ 1, 2 })
		local off = table.clone(ArenaConfig)
		off.enabled = false
		world.arena.config = off
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

	it("puts a champion who walks out of the ring back at its edge, and leaves one inside alone", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		advanceTo(world, "duel")
		local root = world.players[1].Character.HumanoidRootPart
		local placedBefore = #world.placed
		root.CFrame = CFrame.new(1, 5, 1) -- well inside
		world.env.mock:advance(0.2)
		expect(#world.placed).toBe(placedBefore)
		local ring = world.arena.config.ring
		root.CFrame = CFrame.new(60, 5, 80) -- 100 studs out
		world.env.mock:advance(0.2)
		expect(#world.placed).toBe(placedBefore + 1)
		local back = world.placed[#world.placed]
		expect(back.userId).toBe(1)
		expect(math.abs(math.sqrt(back.x * back.x + back.z * back.z) - ring.fallbackRadius) < 1e-6).toBe(true)
		expect(math.abs(back.x / back.z - 60 / 80) < 1e-6).toBe(true) -- along the way out, not anywhere
		expect(back.toX).toBe(0) -- facing the ring's centre
		local at = root.CFrame.Position
		expect(math.sqrt(at.X * at.X + at.Z * at.Z) <= ring.fallbackRadius + ring.margin).toBe(true)
		-- the margin is allowed: just inside radius + margin stays where it is
		local count = #world.placed
		root.CFrame = CFrame.new(ring.fallbackRadius + ring.margin - 0.1, 5, 0)
		world.env.mock:advance(0.2)
		expect(#world.placed).toBe(count)
	end)

	it("bounds a champion by the venue ring when there is no site override", function()
		local world = boot({ 1, 2 })
		local config = shortConfig()
		config.site = nil
		world.arena.config = config
		reachArena(world)
		advanceTo(world, "duel")
		local venue = WorldLayout.arena
		local centre = venue.cframe.Position
		local root = world.players[1].Character.HumanoidRootPart
		root.CFrame = CFrame.new(centre.X + 200, 5, centre.Z)
		world.env.mock:advance(0.2)
		local back = world.placed[#world.placed]
		expect(math.abs(back.x - (centre.X + venue.duelRadius)) < 1e-6).toBe(true)
		expect(math.abs(back.z - centre.Z) < 1e-6).toBe(true)
		expect(math.abs(back.height - venue.spawnA.Position.Y) < 1e-6).toBe(true)
	end)

	it("fixes the champions' WalkSpeed for the intro and the duel and gives it back afterwards", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		local humanoid = world.players[1].Character.Humanoid
		expect(humanoid.WalkSpeed).toBe(40) -- the loadout stage leaves it alone
		advanceTo(world, "intro")
		expect(humanoid.WalkSpeed).toBe(world.arena.config.ring.walkSpeed)
		expect(world.players[2].Character.Humanoid.WalkSpeed).toBe(world.arena.config.ring.walkSpeed)
		advanceTo(world, "duel")
		expect(humanoid.WalkSpeed).toBe(world.arena.config.ring.walkSpeed)
		advanceTo(world, "crowning")
		world.env.mock:advance(0.2)
		expect(humanoid.WalkSpeed).toBe(40)
		expect(world.players[2].Character.Humanoid.WalkSpeed).toBe(40)
	end)

	it("a champion who resets is placed on their mark again with the fixed WalkSpeed", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		advanceTo(world, "duel")
		local placedBefore = #world.placed
		local env = world.env
		local character = env.newInstance("Model")
		character.Name = "reset"
		local root = env.newInstance("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.new(300, 5, 300) -- the spawn point, far from the ring
		root.Parent = character
		local humanoid = env.newInstance("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.WalkSpeed = 40
		humanoid.Parent = character
		character.Parent = env.Workspace
		world.players[1].Character = character
		env.mock:advance(0.2)
		expect(#world.placed).toBe(placedBefore + 1)
		local again = world.placed[#world.placed]
		expect(again.userId).toBe(1)
		local site = world.arena.config.site
		expect(math.abs(again.x - (site.x - site.separation / 2)) < 1e-6).toBe(true) -- side a's mark
		expect(humanoid.WalkSpeed).toBe(world.arena.config.ring.walkSpeed)
		-- and it is given back at the end
		advanceTo(world, "crowning")
		env.mock:advance(0.2)
		expect(humanoid.WalkSpeed).toBe(40)
	end)
	it("stands a seated champion up, off the throne, before placing them", function()
		local world = boot({ 1, 2 })
		world.arena.placeAt = nil -- the real ArenaService:_place
		reachArena(world)
		local adapter = world.kingdoms.adapter
		local humanoid = world.players[1].Character.Humanoid
		local seat = world.env.newInstance("Seat")
		local seated = world.players[1].Character
		humanoid.Jump = false
		local log: { string } = {}
		local jumpAtPivot = false
		adapter.seatOf = function(character: any): any?
			return if character == seated and seat ~= nil then seat else nil
		end
		adapter.unseat = function(character: any, from: any)
			expect(character).toBe(seated)
			expect(from).toBe(seat)
			table.insert(log, "unseat")
			seat = nil -- the character is free
		end
		local pivot = adapter.pivot
		adapter.pivot = function(character: any, cframe: any)
			if character == seated then
				table.insert(log, "pivot")
				jumpAtPivot = humanoid.Jump
			end
			pivot(character, cframe)
		end
		advanceTo(world, "intro")
		expect(log[1]).toBe("unseat")
		expect(log[2]).toBe("pivot")
		expect(jumpAtPivot).toBe(true) -- a jump besides, in case Sit = false alone leaves the weld
	end)

	it("gives the champions their WalkSpeed back when the match calls the arena off mid-duel", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		advanceTo(world, "duel")
		local humanoid = world.players[1].Character.Humanoid
		expect(humanoid.WalkSpeed).toBe(world.arena.config.ring.walkSpeed)
		world.match.host.match:_cancelArena("spec")
		world.env.mock:advance(0.2)
		expect(humanoid.WalkSpeed).toBe(40)
		expect(world.players[2].Character.Humanoid.WalkSpeed).toBe(40)
	end)

	it(
		"the real teleport puts each champion's character on its venue mark, at the mark's height, facing the other",
		function()
			local world = boot({ 1, 2 })
			local config = shortConfig()
			config.site = nil
			world.arena.config = config
			world.arena.placeAt = nil -- the real ArenaService:_place, not the spec's stand-in
			reachArena(world)
			advanceTo(world, "intro")
			local marks = WorldLayout.arena
			local rootA = world.players[1].Character.HumanoidRootPart
			local rootB = world.players[2].Character.HumanoidRootPart
			local function near(a: number, b: number): boolean
				return math.abs(a - b) < 1e-3
			end
			local at = rootA.CFrame.Position
			expect(
				near(at.X, marks.spawnA.Position.X)
					and near(at.Y, marks.spawnA.Position.Y)
					and near(at.Z, marks.spawnA.Position.Z)
			).toBe(true)
			at = rootB.CFrame.Position
			expect(
				near(at.X, marks.spawnB.Position.X)
					and near(at.Y, marks.spawnB.Position.Y)
					and near(at.Z, marks.spawnB.Position.Z)
			).toBe(true)
			-- each looks along the line to the other (the marks lie on the gate axis, A at -X)
			expect(rootA.CFrame.LookVector.X > 0.99).toBe(true)
			expect(rootB.CFrame.LookVector.X < -0.99).toBe(true)
		end
	)

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

-- player 1 rules a kingdom; the second qualifier has no human ruler, so it fields an AI champion
local function reachSolo(world: any)
	local mine = world.sim:kingdomOfUser(1)
	assert(mine, "player 1 rules a kingdom")
	local rival = "azure"
	if mine.id == rival then
		rival = "crimson"
	end
	world.a, world.b = mine.id, rival
	world.sim:addCrownPoints(mine.id, 100, "spec")
	world.sim:addCrownPoints(rival, 50, "spec")
	world.env.mock:advance(FAST_PHASES.Founding * 3 + 1)
	world.env.mock:advance(FAST_PHASES.Endgame)
end

local function logged(world: any, what: string): { any }
	local out = {}
	for _, entry in world.kitLog do
		if entry.what == what then
			table.insert(out, entry)
		end
	end
	return out
end

describe("ArenaService: the champions' bodies, gear and venue (FL-0140)", function()
	it("stands an AI champion on its mark as a figure in the kingdom's colour, and the duel measures it", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "intro")
		local state = world.arena:state()
		local aiSide = if state.a.isAI then "a" else "b"
		local aiId = state[aiSide].userId
		local rigs = logged(world, "character")
		expect(#rigs).toBe(1)
		expect(rigs[1].kind).toBe("governor")
		expect(rigs[1].kingdom).toBe(state[aiSide].kingdom)
		local folder = world.env.Workspace:FindFirstChild("ArenaFigures")
		assert(folder, "the figures folder")
		expect(folder:FindFirstChild(`ArenaChampion{aiId}`)).never.toBeNil()
		local figure = folder:FindFirstChild(`ArenaChampion{aiId}`)
		expect(figure:GetAttribute("ArenaSide")).toBe(aiSide) -- the DuelRunner side, for the client that poses it
		expect(world.env.CollectionService:HasTag(figure, "ArenaChampion")).toBe(true)
		local pose = world.arena:poseOf(aiId)
		assert(pose, "the AI champion has a pose")
		-- it faces the other champion across the ring (the marks lie on the gate axis)
		expect(math.abs(pose.fx) > 0.99).toBe(true)
	end)

	it("walks the AI figure up to its opponent in the duel, to just inside reach", function()
		local world = boot({ 1 })
		world.arena.config.site = { x = 0, z = 0, separation = 20 } -- the specs' own ring is too small to need a walk
		reachSolo(world)
		advanceTo(world, "duel")
		local state = world.arena:state()
		local aiId = if state.a.isAI then state.a.userId else state.b.userId
		local humanId = if state.a.isAI then state.b.userId else state.a.userId
		local config = world.arena.config
		local function gap(): number
			local a, b = world.arena:poseOf(aiId), world.arena:poseOf(humanId)
			assert(a and b, "both stand somewhere")
			return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		end
		local before = gap()
		expect(before > config.reach).toBe(true)
		for _ = 1, 100 do
			world.env.mock:advance(0.1)
			if world.arena:state().stage ~= "duel" then
				break
			end
		end
		expect(gap() < config.reach).toBe(true)
	end)

	it("never moves the AI figure faster than the fixed WalkSpeed", function()
		local world = boot({ 1 })
		world.arena.config.site = { x = 0, z = 0, separation = 20 }
		reachSolo(world)
		advanceTo(world, "duel")
		local state = world.arena:state()
		local aiId = if state.a.isAI then state.a.userId else state.b.userId
		local humanRoot = world.players[1].Character.HumanoidRootPart
		local ring = world.arena:_layout().ring
		local walkSpeed = world.arena.config.ring.walkSpeed
		-- the human stands at the far edge of the ring: the AI has all the room to run
		humanRoot.CFrame = CFrame.new(ring.x, 5, ring.z + ring.radius)
		world.env.mock:advance(0.05) -- the walk's clock starts
		local from = assert(world.arena:poseOf(aiId))
		local elapsed = 0
		for _ = 1, 5 do
			world.env.mock:advance(0.05)
			elapsed += 0.05
		end
		local to = assert(world.arena:poseOf(aiId))
		local moved = math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2)
		expect(moved > 0).toBe(true)
		-- stepped once a tick, so over a stretch it can run at most one tick ahead of the clock
		expect(moved <= walkSpeed * (elapsed + world.arena.config.tick) + 1e-6).toBe(true)
	end)

	it("keeps the AI figure inside the ring, whatever it is asked to walk towards", function()
		local world = boot({ 1 })
		world.arena.config.site = { x = 0, z = 0, separation = 20 }
		reachSolo(world)
		advanceTo(world, "intro")
		local state = world.arena:state()
		local aiId = if state.a.isAI then state.a.userId else state.b.userId
		local ring = world.arena:_layout().ring
		world.arena._figures:approach(aiId, ring.x + 60, ring.z, 100, 0, ring)
		local pose = assert(world.arena:poseOf(aiId))
		local out = math.sqrt((pose.x - ring.x) ^ 2 + (pose.z - ring.z) ^ 2)
		expect(out <= ring.radius + 1e-6).toBe(true)
		expect(out > ring.radius - 1e-3).toBe(true) -- and it did walk to the edge
	end)

	-- the geometry of the AI figure, on the venue's own marks (no `site` override), with the Kit's rig rules (see fakeKit)
	local function soloOnVenue(): any
		local world = boot({ 1 })
		world.arena.config.site = nil
		reachSolo(world)
		advanceTo(world, "intro")
		local state = world.arena:state()
		world.aiSide = if state.a.isAI then "a" else "b"
		world.aiId = state[world.aiSide].userId
		world.humanId = state[if world.aiSide == "a" then "b" else "a"].userId
		world.figure = world.env.Workspace:FindFirstChild("ArenaFigures"):FindFirstChild(`ArenaChampion{world.aiId}`)
		return world
	end
	local function feetOf(figure: any): Vector3
		local root = figure.PrimaryPart
		return (root.CFrame * root.PivotOffset).Position
	end

	it("stands the AI figure's feet on the floor under its mark, and keeps them there through the duel", function()
		local world = soloOnVenue()
		local mark = WorldLayout.arena[if world.aiSide == "a" then "spawnA" else "spawnB"].Position
		local floorY = mark.Y - 3 -- the venue's marks are a character's root height above the floor
		expect(math.abs(feetOf(world.figure).Y - floorY) < 1e-3).toBe(true)
		expect(math.abs(feetOf(world.figure).X - mark.X) < 1e-3).toBe(true)
		advanceTo(world, "duel")
		local lowest, highest = math.huge, -math.huge
		for _ = 1, 200 do
			world.env.mock:advance(0.05)
			if world.arena:state().stage ~= "duel" then
				break
			end
			local y = feetOf(world.figure).Y
			lowest, highest = math.min(lowest, y), math.max(highest, y)
		end
		expect(highest > -math.huge).toBe(true)
		expect(math.abs(lowest - floorY) < 1e-3 and math.abs(highest - floorY) < 1e-3).toBe(true)
	end)

	it("turns the AI figure to face its opponent, and keeps facing as it walks", function()
		local world = soloOnVenue()
		local function facing(): number
			local ai, me = assert(world.arena:poseOf(world.aiId)), assert(world.arena:poseOf(world.humanId))
			local dx, dz = me.x - ai.x, me.z - ai.z
			local length = math.sqrt(dx * dx + dz * dz)
			return (ai.fx * dx + ai.fz * dz) / length
		end
		expect(facing() > 0.9).toBe(true)
		advanceTo(world, "duel")
		for _ = 1, 40 do
			world.env.mock:advance(0.05)
		end
		expect(facing() > 0.9).toBe(true)
	end)

	it("holds the loadout weapon up from the AI figure's hand, and takes the rig's own spear away", function()
		local world = soloOnVenue()
		local arm = world.figure:FindFirstChild("RightArm", true)
		local held = world.figure:FindFirstChild("Tool", true)
		assert(held and held:IsA("BasePart"), "the rig's Tool part stays: the Tool joint drives it")
		local weld = nil
		for _, d in world.figure:GetDescendants() do
			if d:IsA("Weld") and d.Name == "ArenaGearWeld" and d.Part0 == held then
				weld = d
			end
		end
		assert(weld, "the weapon's weld on the Tool part")
		local hand = arm.CFrame * Vector3.new(0, -arm.Size.Y / 2, 0)
		-- the tip: KitReach up the grip frame (+Y), through the weld; the rig stands in the Kit's frame, front along -Z
		local tip = held.CFrame
			* weld.C0
			* weld.C1:Inverse()
			* WEAPON_HANDLE:Inverse()
			* Vector3.new(0, WEAPON_REACH, 0)
		local reach = tip - hand
		-- the weld sits on the hand point of the arm: its end, not the shoulder end
		local anchored = (held.CFrame * weld.C0).Position
		expect((anchored - hand).Magnitude < 1e-3).toBe(true)
		-- at rest the blade points forward (-Z), level: the hand's grip turn is in the weld, and FORGE-04's wrist poses
		-- (Feedback/DuelPoses: "the weapon's elevation is about the arm's swing") lift it from there
		expect(reach.Z < -(WEAPON_REACH - 0.5)).toBe(true)
		expect(math.abs(reach.Y) < 0.5 and math.abs(reach.X) < 0.5).toBe(true)
		-- the rig's own held item is gone: its part is invisible, its details (the orb) destroyed, its joint still works
		expect(held.Transparency).toBe(1)
		expect(world.figure:FindFirstChild("Orb", true)).toBeNil()
		local joint = arm:FindFirstChild("Tool")
		assert(joint, "the Tool joint")
		expect(joint.Part1).toBe(held)
	end)

	it(
		"puts the armour where its Attachment names: helm on the head top, plate on the chest, cape on the back, pauldrons at the collar",
		function()
			local world = soloOnVenue()
			local head, torso = world.figure:FindFirstChild("Head", true), world.figure:FindFirstChild("Torso", true)
			-- the world position of the point the piece's Attachment names, through the weld: the Handle sits where the weld
			-- puts it, the Attachment is on the Handle
			local function pointOf(accessoryName: string): Vector3
				local handle = world.figure:FindFirstChild(accessoryName, true):FindFirstChild("Handle")
				local w = handle:FindFirstChildOfClass("Weld")
				local attachment = handle:FindFirstChildOfClass("Attachment")
				return (w.Part0.CFrame * w.C0 * w.C1:Inverse() * attachment.CFrame).Position
			end
			local topOfHead = head.CFrame.Position + Vector3.new(0, head.Size.Y / 2, 0)
			local function near(a: Vector3, b: Vector3): boolean
				return (a - b).Magnitude < 1e-3
			end
			expect(near(pointOf("Helm"), topOfHead)).toBe(true) -- the top, not the bottom
			local chest = torso.CFrame.Position
			expect(near(pointOf("Plate"), chest + Vector3.new(0, 0, -torso.Size.Z / 2))).toBe(true) -- the front (-Z)
			expect(near(pointOf("Cape"), chest + Vector3.new(0, 0, torso.Size.Z / 2))).toBe(true) -- the back (+Z)
			expect(near(pointOf("PauldronL"), chest + Vector3.new(-torso.Size.X / 2, torso.Size.Y / 2, 0))).toBe(true)
			expect(near(pointOf("PauldronR"), chest + Vector3.new(torso.Size.X / 2, torso.Size.Y / 2, 0))).toBe(true)
		end
	)

	it("lets a stall of the server's clock move the AI figure no further than maxCatchup", function()
		local world = soloOnVenue()
		advanceTo(world, "duel")
		world.env.mock:advance(0.1)
		local before = assert(world.arena:poseOf(world.aiId))
		world.arena._figureClock = world.arena._figureClock - 100 -- a long stall since the last walk
		world.arena:_walkFigures(world.arena:_now())
		local after = assert(world.arena:poseOf(world.aiId))
		local moved = math.sqrt((after.x - before.x) ^ 2 + (after.z - before.z) ^ 2)
		expect(moved <= world.arena.config.maxCatchup * world.arena.config.ring.walkSpeed + 1e-6).toBe(true)
	end)

	it("dresses the venue's side A in the colour of the kingdom that stands on mark A", function()
		local world = soloOnVenue()
		local dress = logged(world, "dress")[1]
		local function colourOf(kingdom: string): Color3
			for _, identity in KingdomsConfig.identities do
				if identity.id == kingdom then
					return Color3.fromRGB(identity.color[1], identity.color[2], identity.color[3])
				end
			end
			error("unknown kingdom " .. kingdom)
		end
		local state = world.arena:state()
		expect(dress.colorA).toEqual(colourOf(state.a.kingdom))
		expect(dress.colorB).toEqual(colourOf(state.b.kingdom))
	end)

	it("tells the sim again when a champion is put back at the ring's edge", function()
		local world = boot({ 1 })
		world.arena.config.site = { x = 0, z = 0, separation = 20 }
		reachSolo(world)
		advanceTo(world, "duel")
		local snapped = 0
		local host = world.match.host
		local original = host.snapRuler
		host.snapRuler = function(self: any, userId: number)
			snapped += 1
			return original(self, userId)
		end
		local ring = world.arena:_layout().ring
		world.players[1].Character.HumanoidRootPart.CFrame = CFrame.new(ring.x + ring.radius + 30, 5, ring.z)
		world.env.mock:advance(0.2)
		expect(snapped >= 1).toBe(true)
	end)

	it("takes the figure away when the arena is destroyed mid-duel", function()
		local world = soloOnVenue()
		advanceTo(world, "duel")
		world.arena:destroy()
		expect(world.env.Workspace:FindFirstChild("ArenaFigures")).toBeNil()
		expect(#logged(world, "dress")).toBe(2) -- and the venue is back to neutral
	end)

	it("a human running circles round the ring edge at the AI's own speed stays within its reach", function()
		local world = boot({ 1 })
		world.arena.config.site = { x = 0, z = 0, separation = 20 }
		reachSolo(world)
		advanceTo(world, "duel")
		local state = world.arena:state()
		local aiId = if state.a.isAI then state.a.userId else state.b.userId
		local humanRoot = world.players[1].Character.HumanoidRootPart
		local ring = world.arena:_layout().ring
		local walkSpeed = world.arena.config.ring.walkSpeed
		local orbit = ring.radius - 1
		local angle = 0
		local samples, inReach, closest = 0, 0, math.huge
		for _ = 1, 300 do
			angle += walkSpeed * 0.05 / orbit
			humanRoot.CFrame = CFrame.new(ring.x + orbit * math.cos(angle), 5, ring.z + orbit * math.sin(angle))
			world.env.mock:advance(0.05)
			if world.arena:state().stage ~= "duel" then
				break
			end
			local ai, me =
				world.arena:poseOf(aiId), world.arena:poseOf(state.a.isAI and state.b.userId or state.a.userId)
			if ai and me then
				local gap = math.sqrt((ai.x - me.x) ^ 2 + (ai.z - me.z) ^ 2)
				samples += 1
				closest = math.min(closest, gap)
				if gap <= world.arena.config.reach then
					inReach += 1
				end
			end
		end
		-- measured (headless): the AI is within reach on every sample, and gets as close as ~1.7 studs; running is no escape
		expect(samples > 100).toBe(true)
		expect(inReach >= samples * 0.9).toBe(true)
		expect(closest < world.arena.config.reach).toBe(true)
	end)

	it("asks the Kit for the AI champion's own loadout, apart from the human's", function()
		local world = boot({ 1 })
		world.arena.config.ai = { weapon = "spear", armour = "heavy", skill = 0.5 } -- unlike the human's defaults
		reachSolo(world)
		advanceTo(world, "intro")
		local weapons, armours = {}, {}
		for _, entry in logged(world, "weapon") do
			weapons[entry.weapon] = true
		end
		for _, entry in logged(world, "armour") do
			armours[entry.armour] = true
		end
		expect(weapons.spear).toBe(true)
		expect(armours.heavy).toBe(true)
		expect(weapons[world.arena.config.defaultWeapon]).toBe(true) -- and the human got theirs
		expect(armours[world.arena.config.defaultArmour]).toBe(true)
	end)

	it("puts the loadout's weapon and armour on a human champion, in the kingdom's colour", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "intro")
		local state = world.arena:state()
		local humanSide = if state.a.isAI then "b" else "a"
		local armour, weapon = logged(world, "armour"), logged(world, "weapon")
		expect(#armour).toBe(2) -- one set for the human, one for the AI figure
		expect(#weapon).toBe(2)
		local champion = world.arena._flow:champion(humanSide)
		local mine = nil
		for _, entry in weapon do
			if entry.weapon == champion.weapon then
				mine = entry
			end
		end
		assert(mine, "the human's weapon was asked for")
		local character = world.players[1].Character
		local carried = false
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				carried = true
			end
		end
		expect(carried).toBe(true)
	end)

	it("dresses the venue in the two qualifiers' colours at the intro, and back to neutral afterwards", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "intro")
		local dressed = logged(world, "dress")
		expect(#dressed).toBe(1)
		expect(dressed[1].model).toBe(world.venue)
		expect(typeof(dressed[1].colorA)).toBe("Color3")
		expect(typeof(dressed[1].colorB)).toBe("Color3")
		expect(dressed[1].colorA ~= dressed[1].colorB).toBe(true)
		advanceTo(world, "done", world.arena.config.duelMaxSeconds + world.arena.config.crowningSeconds + 5)
		dressed = logged(world, "dress")
		expect(#dressed).toBe(2)
		expect(dressed[2].colorA).toBeNil()
		expect(dressed[2].colorB).toBeNil()
	end)

	it("takes the figure and the gear away after the crowning", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "duel")
		local folder = world.env.Workspace:FindFirstChild("ArenaFigures")
		assert(folder, "the figures folder")
		expect(#folder:GetChildren()).toBe(1)
		advanceTo(world, "done", world.arena.config.duelMaxSeconds + world.arena.config.crowningSeconds + 5)
		expect(world.env.Workspace:FindFirstChild("ArenaFigures")).toBeNil() -- the figures and their folder are gone
		for _, child in world.players[1].Character:GetChildren() do
			expect(child:IsA("Tool")).toBe(false)
		end
	end)

	it("takes the figure away when the only human leaves mid-duel and the AI is crowned", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "duel")
		local folder = world.env.Workspace:FindFirstChild("ArenaFigures")
		assert(folder, "the figures folder")
		expect(#folder:GetChildren()).toBe(1)
		world.env.mock.players:remove(world.players[1])
		world.env.mock:advance(0.5)
		advanceTo(world, "done", world.arena.config.crowningSeconds + 5)
		world.env.mock:advance(0.2)
		expect(world.env.Workspace:FindFirstChild("ArenaFigures")).toBeNil() -- the figures and their folder are gone
		expect(#logged(world, "dress")).toBe(2)
	end)

	it("takes the figure away when the match calls the arena off", function()
		local world = boot({ 1 })
		reachSolo(world)
		advanceTo(world, "intro")
		world.match.host.match:_cancelArena("spec")
		world.env.mock:advance(0.2)
		expect(world.env.Workspace:FindFirstChild("ArenaFigures")).toBeNil() -- the figures and their folder are gone
		expect(#logged(world, "dress")).toBe(2) -- dressed, then back to neutral
	end)

	it("tells the sim a champion was moved by the server, after each placement", function()
		local world = boot({ 1, 2 })
		local snapped: { number } = {}
		local host = world.match.host
		local original = host.snapRuler
		host.snapRuler = function(self: any, userId: number)
			table.insert(snapped, userId)
			return original(self, userId)
		end
		reachArena(world)
		advanceTo(world, "intro")
		table.sort(snapped)
		expect(snapped).toEqual({ 1, 2 })
	end)

	it("dresses a champion who resets again, and snaps the sim to where they were put back", function()
		local world = boot({ 1, 2 })
		reachArena(world)
		advanceTo(world, "duel")
		local weaponsBefore = #logged(world, "weapon")
		local snapped = 0
		local host = world.match.host
		local original = host.snapRuler
		host.snapRuler = function(self: any, userId: number)
			snapped += 1
			return original(self, userId)
		end
		local env = world.env
		local character = env.newInstance("Model")
		character.Name = "reset"
		local root = env.newInstance("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.new(300, 5, 300)
		root.Parent = character
		local humanoid = env.newInstance("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = character
		character.Parent = env.Workspace
		world.players[1].Character = character
		env.mock:advance(0.2)
		expect(snapped >= 1).toBe(true)
		expect(#logged(world, "weapon")).toBe(weaponsBefore + 1)
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
		local off = table.clone(ArenaConfig)
		off.enabled = false
		world.arena.config = off
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
