--[[
	EntityController (CONTRACTS G4 client rules, G4.1 API, D-025/D-026 rendering; FL-0049).

	One client MockEnv plays both ends: RemoteService creates the Sim remotes and stands in for the
	server (EntityService is not needed: the spec encodes Sim.Snapshot / Sim.Events buffers itself and
	answers Sim.GetEntities), while the controller listens through RemoteClient as the local player.
	Engine calls go through a recording adapter: BulkMoveTo writes the root CFrames, Motor6D.Transform
	writes are recorded, the camera is a top-down projection and the LOD centre is set per test.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")
local Def = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/EntityController")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")

local T0 = 5 -- server time (seconds since match start) at virtual elapsed 0

local function serverTime(env): number
	return T0 + env.mock:elapsed()
end

-- A G4 "full" record (spawn fields + state); `extra` overrides fields.
local function full(id: number, x: number, z: number, extra: { [string]: any }?)
	local e = {
		type = "full",
		id = id,
		kind = "citizen",
		job = "farmer",
		kingdom = "crimson",
		x = x,
		y = 0,
		z = z,
		yaw = 0,
		action = "idle",
	}
	for k, v in extra or {} do
		e[k] = v
	end
	return e
end

local function spawnRecord(id: number, extra: { [string]: any }?)
	local e = { type = "spawn", id = id, kind = "citizen", job = "farmer", kingdom = "crimson" }
	for k, v in extra or {} do
		e[k] = v
	end
	return e
end

local function record(id: number, x: number, z: number, extra: { [string]: any }?)
	local r = { id = id, x = x, y = 0, z = z, yaw = 0, action = "walk" }
	for k, v in extra or {} do
		r[k] = v
	end
	return r
end

local function recorder()
	local rec = { moves = {}, transforms = {}, writes = 0, focus = nil :: Vector3? }
	rec.adapter = {
		bulkMove = function(parts, cframes)
			table.insert(rec.moves, #parts)
			for i, part in parts do
				part.CFrame = cframes[i]
			end
		end,
		setTransform = function(motor, cframe)
			rec.transforms[motor] = cframe
			rec.writes += 1
		end,
		focus = function()
			return rec.focus
		end,
		-- top-down camera: screen = (500 + 2x, 500 + 2z), depth = 200 - y
		project = function(p: Vector3)
			return Vector2.new(500 + p.X * 2, 500 + p.Z * 2), 200 - p.Y
		end,
	}
	return rec
end

-- Builds the client env, the server stand-in and the controller (not started).
local function setup(world: { any }?)
	local env = MockEnv.new({
		seed = 4,
		isServer = false,
		localPlayer = { userId = 1001, name = "Ruler" },
		sharedModules = { Remotes = { Sim = SimRemotes } },
	})
	local h: { [string]: any } = {
		env = env,
		remotes = RemoteServiceDef.new(env, {}),
		player = env.mock.localPlayer,
		world = world or {},
		gets = 0,
		seq = 0,
		rendered = {},
		released = {},
		events = {},
		order = {},
	}
	h.remotes:handle("Sim.GetEntities", function()
		h.gets += 1
		if h.onGet then
			h.onGet()
		end
		return EventCodec.encode(serverTime(env), h.world)
	end)
	h.rec = recorder()
	h.controller = Def.new(env, {})
	h.controller.adapter = h.rec.adapter
	h.controller.rendered:connect(function(id, model)
		table.insert(h.rendered, { id = id, model = model })
		table.insert(h.order, `rendered:{id}`)
	end)
	h.controller.released:connect(function(id, model)
		table.insert(h.released, { id = id, model = model })
		table.insert(h.order, `released:{id}`)
	end)
	h.controller.event:connect(function(id, cue, payload, model)
		table.insert(h.events, { id = id, cue = cue, payload = payload, model = model })
	end)
	return h
end

local function start(h)
	h.controller:start()
	return h
end

local function snapshot(h, records: { any }, seq: number?)
	h.seq = seq or (h.seq + 1)
	h.remotes:fire("Sim.Snapshot", h.player, SnapshotCodec.encode(records, h.seq, serverTime(h.env)))
end

local function events(h, list: { any })
	h.remotes:fire("Sim.Events", h.player, EventCodec.encode(serverTime(h.env), list))
end

-- advance virtual time, then render one frame
local function frame(h, seconds: number)
	if seconds > 0 then
		h.env.mock:advance(seconds)
	end
	h.controller:step(seconds)
end

local function pivotOf(model): Vector3
	local root = model.PrimaryPart
	return (root.CFrame * root.PivotOffset).Position
end

local function snapshotRemote(h)
	return h.env.ReplicatedStorage.ForgeRemotes:FindFirstChild("Sim"):FindFirstChild("Snapshot")
end

local function renderedIds(h): { number }
	local ids = {}
	for _, r in h.rendered do
		table.insert(ids, r.id)
	end
	table.sort(ids)
	return ids
end

describe("EntityController: initial state", function()
	it("builds pooled Kit rigs from Sim.GetEntities under one Workspace folder and fires rendered", function()
		local h = start(setup({
			full(1, 0, 0),
			full(2, 10, 0, { job = "woodcutter", kingdom = "azure" }),
			full(3, 20, 5, { kind = "soldier", job = "soldier", kingdom = "gold", yaw = math.pi / 2 }),
		}))
		expect(h.gets).toBe(1)
		frame(h, 0)
		expect(renderedIds(h)).toEqual({ 1, 2, 3 })
		local folder = h.controller.folder
		expect(folder.Name).toBe(Def.FOLDER_NAME)
		expect(folder.Parent).toBe(h.env.Workspace)
		for _, r in h.rendered do
			expect(h.controller:getModel(r.id)).toBe(r.model)
			expect(r.model.Parent).toBe(folder)
			expect(r.model:GetAttribute("EntityId")).toBe(r.id)
		end
		local two = h.controller:getModel(2)
		expect(two:GetAttribute("KitJob")).toBe("woodcutter")
		local azure = Kit.character("citizen", "woodcutter", Color3.fromRGB(40, 110, 210))
		expect(two:FindFirstChild("Torso").Color).toEqual(azure:FindFirstChild("Torso").Color)
		expect((pivotOf(two) - Vector3.new(10, 0, 0)).Magnitude).toBeLessThan(1e-3)
		local three = h.controller:getModel(3)
		expect(three:GetAttribute("KitKind")).toBe("soldier")
		-- yaw turns about +Y; the rig faces -Z at yaw 0, so yaw π/2 faces -X
		expect((three.PrimaryPart.CFrame.LookVector - Vector3.new(-1, 0, 0)).Magnitude).toBeLessThan(1e-3)
		expect(h.controller:getModel(99)).toBeNil()
	end)

	it("connects Sim.Snapshot and Sim.Events before it calls Sim.GetEntities", function()
		local h = setup({ full(1, 0, 0) })
		-- while the server answers GetEntities, it spawns entity 50 and sends its first (unreliable) snapshot:
		-- both reach the client only if the handlers were already connected
		h.onGet = function()
			events(h, { spawnRecord(50) })
			snapshot(h, { record(50, 7, 7) })
		end
		start(h)
		expect(h.gets).toBe(1)
		frame(h, 0)
		expect(renderedIds(h)).toEqual({ 1, 50 })
		expect((pivotOf(h.controller:getModel(50)) - Vector3.new(7, 0, 7)).Magnitude).toBeLessThan(1e-3)
	end)

	it("retries Sim.GetEntities while the server has no answer yet", function()
		local env = MockEnv.new({
			isServer = false,
			localPlayer = { userId = 1001 },
			sharedModules = { Remotes = { Sim = SimRemotes } },
		})
		local remotes = RemoteServiceDef.new(env, {})
		local controller = Def.new(env, {})
		controller.adapter = recorder().adapter
		controller:start()
		expect(controller:getModel(1)).toBeNil()
		remotes:handle("Sim.GetEntities", function()
			return EventCodec.encode(1, { full(1, 3, 3) })
		end)
		env.mock:advance(Def.RETRY_SECONDS)
		controller:step(0)
		expect(controller:getModel(1)).never.toBeNil()
		controller:destroy()
	end)

	it("keeps retrying without errors when the Sim remotes never appear", function()
		local env = MockEnv.new({ isServer = false, localPlayer = { userId = 1001 } })
		local controller = Def.new(env, {})
		controller.adapter = recorder().adapter
		controller:start()
		env.mock:advance(25)
		expect(env.mock:hasLog("warn", "Sim remotes unavailable")).toBe(true)
		expect(env.mock.threadErrors).toEqual({})
		controller:destroy()
	end)
end)

describe("EntityController: snapshots (G4 client rules)", function()
	it("interpolates position and yaw about 200 ms behind the newest server time", function()
		local h = start(setup({ full(1, 0, 0) }))
		for k = 1, 10 do
			h.env.mock:advance(0.1)
			snapshot(h, { record(1, k * 10, 0, { yaw = math.rad(k * 8) }) })
		end
		frame(h, 0)
		local model = h.controller:getModel(1)
		-- newest sample: x = 100 at T0 + 1.0; render time T0 + 0.8 shows x = 80
		expect(pivotOf(model).X).toBeNear(80, 0.05)
		frame(h, 0.05)
		expect(pivotOf(model).X).toBeNear(85, 0.05)
		local _, yaw = model.PrimaryPart.CFrame:ToEulerAnglesYXZ()
		expect(math.deg(yaw)).toBeNear(68, 1.5) -- between 64° and 72°
		-- the server stops: the rig holds the newest sample, never extrapolates
		frame(h, 1)
		expect(pivotOf(model).X).toBeNear(100, 0.05)
	end)

	it("drops a snapshot whose seq is not newer than the newest applied, across the u16 wrap", function()
		local h = start(setup({ full(1, 0, 0) }))
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 10, 0) }, 65534)
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 20, 0) }, 65535)
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 30, 0) }, 0) -- wrapped: newer
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 99, 0) }, 65535) -- stale
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 98, 0) }, 40000) -- more than half the range behind 0: stale
		expect(h.controller.stats.stale).toBe(2)
		expect(h.controller.stats.snapshots).toBe(3)
		frame(h, 1)
		expect(pivotOf(h.controller:getModel(1)).X).toBeNear(30, 0.05)
	end)

	it("applies every chunk of the same seq (90 entities in two buffers)", function()
		local world, records = {}, {}
		for id = 1, 90 do
			table.insert(world, full(id, id, 0))
			table.insert(records, record(id, id, 50))
		end
		local h = start(setup(world))
		h.env.mock:advance(0.1)
		local chunks = SnapshotCodec.encodeChunks(records, 7, serverTime(h.env))
		expect(#chunks).toBe(2)
		for _, buf in chunks do
			h.remotes:fire("Sim.Snapshot", h.player, buf)
		end
		expect(h.controller.stats.stale).toBe(0)
		frame(h, 1)
		for id = 1, 90 do
			expect(pivotOf(h.controller:getModel(id)).Z).toBeNear(50, 1e-3)
		end
	end)

	it("keeps the newest snapshot when deliveries arrive out of order", function()
		local h = start(setup({ full(1, 0, 0) }))
		local remote = snapshotRemote(h)
		h.env.mock.remotes:holdUnreliable(remote)
		for _, x in { 10, 50, 30 } do -- seq 1, 2, 3 at T0 + 0.1, 0.2, 0.3
			h.env.mock:advance(0.1)
			snapshot(h, { record(1, x, 0) })
		end
		expect(h.env.mock.remotes:heldCount(remote)).toBe(3)
		expect(h.env.mock.remotes:releaseUnreliable(remote, "reverse")).toBe(3) -- seq 3, then 2, then 1
		expect(h.controller.stats.stale).toBe(2)
		-- render time T0 + 0.2: straight from the full record (x 0 at T0) toward seq 3 (x 30 at T0 + 0.3);
		-- the late seq 2 (x 50) was dropped
		frame(h, 0.1)
		expect(pivotOf(h.controller:getModel(1)).X).toBeNear(20, 0.05)
		frame(h, 1)
		expect(pivotOf(h.controller:getModel(1)).X).toBeNear(30, 0.05)
	end)

	it("ignores an unknown id, then renders it after its spawn record and a snapshot", function()
		local h = start(setup({}))
		h.env.mock:advance(0.1)
		snapshot(h, { record(7, 1, 1) })
		expect(h.controller.stats.unknown).toBe(1)
		frame(h, 0)
		expect(h.controller:getModel(7)).toBeNil()
		events(h, { spawnRecord(7) })
		frame(h, 0)
		expect(#h.rendered).toBe(0) -- known, but no position yet
		h.env.mock:advance(0.1)
		snapshot(h, { record(7, 2, 2) })
		frame(h, 0)
		expect(renderedIds(h)).toEqual({ 7 })
		expect((pivotOf(h.controller:getModel(7)) - Vector3.new(2, 0, 2)).Magnitude).toBeLessThan(1e-3)
	end)

	it("never brings a despawned id back from a late snapshot or a stale full record", function()
		local h = start(setup({ full(1, 0, 0) }))
		frame(h, 0)
		events(h, { { type = "despawn", id = 1 } })
		expect(h.controller:getModel(1)).toBeNil()
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 5, 5) })
		frame(h, 0)
		expect(h.controller:getModel(1)).toBeNil()
		expect(h.controller.stats.despawned).toBe(1)
		events(h, { full(1, 3, 3) }) -- e.g. a GetEntities picture taken before the despawn
		frame(h, 0.1)
		expect(h.controller:getModel(1)).toBeNil()
		expect(#h.rendered).toBe(1)
		-- an explicit spawn record clears the id
		events(h, { spawnRecord(1) })
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 6, 6) })
		frame(h, 0)
		expect(h.controller:getModel(1)).never.toBeNil()
		expect(#h.rendered).toBe(2)
	end)
end)

describe("EntityController: rigs, cues and reset", function()
	it("fires released before the rig returns to the pool, and a later spawn reuses it", function()
		local h = start(setup({ full(1, 0, 0), full(2, 5, 0) }))
		frame(h, 0)
		local folder = h.controller.folder
		local first = h.controller:getModel(1)
		local seen
		h.controller.released:connect(function(id, model)
			seen = {
				id = id,
				parent = model.Parent,
				held = h.controller:getModel(id) == model,
				attribute = model:GetAttribute("EntityId"),
			}
		end)
		events(h, { { type = "despawn", id = 1 } })
		expect(seen).toEqual({ id = 1, parent = folder, held = true, attribute = 1 })
		expect(first.Parent).toBeNil()
		expect(first:GetAttribute("EntityId")).toBeNil()
		expect(h.controller:getModel(1)).toBeNil()
		-- same kind, job and kingdom: the pooled rig comes back
		events(h, { spawnRecord(10), spawnRecord(11, { kingdom = "azure" }) })
		h.env.mock:advance(0.1)
		snapshot(h, { record(10, 3, 3), record(11, 4, 4) })
		frame(h, 0)
		expect(h.controller:getModel(10)).toBe(first)
		expect(first.Parent).toBe(folder)
		expect(first:GetAttribute("EntityId")).toBe(10)
		expect(h.controller:getModel(11)).never.toBe(first)
	end)

	it("pools rigs per Kit.lookKey and keeps at most POOL_MAX spares in all, the oldest destroyed first", function()
		local function look(skin: number)
			return { skin = skin, hair = 2, hairColor = 1, outfit = 1 }
		end
		local h = start(setup({ full(1, 0, 0, { look = look(1) }), full(2, 5, 0, { look = look(2) }), full(3, 9, 0) }))
		frame(h, 0)
		local a, b, plain = h.controller:getModel(1), h.controller:getModel(2), h.controller:getModel(3)
		expect(a:GetAttribute("KitLook")).toBe(Kit.lookKey(look(1)))
		expect(b:GetAttribute("KitLook")).toBe(Kit.lookKey(look(2)))
		events(h, { { type = "despawn", id = 1 }, { type = "despawn", id = 2 }, { type = "despawn", id = 3 } })
		-- a spawn takes the spare built for its own look, never another look's rig
		events(h, {
			spawnRecord(10, { look = look(2) }),
			spawnRecord(11, { look = table.clone(Kit.DEFAULT_LOOK) }), -- = no look, Kit's default
			spawnRecord(12, { look = look(3) }),
		})
		h.env.mock:advance(0.1)
		snapshot(h, { record(10, 1, 1), record(11, 2, 2), record(12, 3, 3) })
		frame(h, 0)
		expect(h.controller:getModel(10)).toBe(b)
		expect(h.controller:getModel(11)).toBe(plain)
		local fresh = h.controller:getModel(12)
		expect(fresh).never.toBe(a)
		expect(fresh:GetAttribute("KitLook")).toBe(Kit.lookKey(look(3)))
		-- one bound over every key: with POOL_MAX 3, six released looks leave the three newest
		local max = Def.POOL_MAX
		Def.POOL_MAX = 3
		local list, models = {}, {}
		for i = 1, 6 do
			table.insert(list, spawnRecord(20 + i, { look = look(i), kingdom = "azure" }))
		end
		events(h, list)
		h.env.mock:advance(0.1)
		local records = {}
		for i = 1, 6 do
			table.insert(records, record(20 + i, i, 0))
		end
		snapshot(h, records)
		frame(h, 0)
		for i = 1, 6 do
			models[i] = h.controller:getModel(20 + i)
			events(h, { { type = "despawn", id = 20 + i } })
		end
		expect(#h.controller._spares).toBe(3) -- the older spare (a) went first, then looks 1..3
		Def.POOL_MAX = max
		local function destroyed(model): boolean
			return not pcall(function()
				return model.Name
			end)
		end
		expect({ destroyed(a), destroyed(models[1]), destroyed(models[3]), destroyed(models[4]) }).toEqual({
			true,
			true,
			true,
			false,
		})
		local again = {}
		for _, i in { 1, 6 } do
			table.insert(again, spawnRecord(40 + i, { look = look(i), kingdom = "azure" }))
		end
		events(h, again)
		h.env.mock:advance(0.1)
		snapshot(h, { record(41, 1, 1), record(46, 6, 6) })
		frame(h, 0)
		expect(destroyed(h.controller:getModel(41))).toBe(false) -- look 1 was evicted: built anew
		expect(h.controller:getModel(41):GetAttribute("KitLook")).toBe(Kit.lookKey(look(1)))
		expect(h.controller:getModel(46) == models[6]).toBe(true)
		-- two spares of one key: the newest comes back first (older ones age out of the pool)
		events(h, { spawnRecord(51, { look = look(5) }), spawnRecord(52, { look = look(5) }) })
		h.env.mock:advance(0.1)
		snapshot(h, { record(51, 5, 5), record(52, 6, 6) })
		frame(h, 0)
		local older, newer = h.controller:getModel(51), h.controller:getModel(52)
		events(h, { { type = "despawn", id = 51 }, { type = "despawn", id = 52 } })
		events(h, { spawnRecord(53, { look = look(5) }) })
		h.env.mock:advance(0.1)
		snapshot(h, { record(53, 7, 7) })
		frame(h, 0)
		expect(h.controller:getModel(53) == newer).toBe(true)
		expect(h.controller:getModel(53) == older).toBe(false)
	end)

	it("swaps the rig on a job change: released, then rendered with the new job", function()
		local h = start(setup({ full(1, 4, 0) }))
		frame(h, 0)
		local old = h.controller:getModel(1)
		table.clear(h.order)
		events(h, { { type = "job", id = 1, job = "woodcutter" } })
		expect(h.order).toEqual({ "released:1", "rendered:1" })
		local new = h.controller:getModel(1)
		expect(new).never.toBe(old)
		expect(new:GetAttribute("KitJob")).toBe("woodcutter")
		expect(new.Parent).toBe(h.controller.folder)
		expect((pivotOf(new) - Vector3.new(4, 0, 0)).Magnitude).toBeLessThan(1e-3) -- placed before rendered
		expect(old.Parent).toBeNil()
		events(h, { { type = "job", id = 1, job = "woodcutter" } }) -- unchanged: no swap
		expect(#h.order).toBe(2)
	end)

	it("fires event for cues with their payload and the model", function()
		local h = start(setup({ full(1, 0, 0) }))
		frame(h, 0)
		local model = h.controller:getModel(1)
		events(h, {
			{ type = "cue", id = 1, cue = "deposit", resource = "wood" },
			{ type = "cue", id = 1, cue = "hit" },
			{ type = "cue", id = 1, cue = "celebrate" },
			{ type = "cue", id = 99, cue = "hit" }, -- unknown: ignored
		})
		expect(h.events).toEqual({
			{ id = 1, cue = "deposit", payload = { resource = "wood" }, model = model },
			{ id = 1, cue = "hit", payload = {}, model = model },
			{ id = 1, cue = "celebrate", payload = {}, model = model },
		})
	end)

	it("fires event for the G13.3 thought, reaction, kcue and strike events, per listed citizen (v0.4-g6)", function()
		local h = start(setup({ full(1, 0, 0), full(2, 5, 0) }))
		frame(h, 0)
		local model = h.controller:getModel(1)
		-- 3: known, no rig yet; 2: despawned while its dead pose still plays (the corpse is kept)
		events(h, { spawnRecord(3), { type = "cue", id = 2, cue = "die" }, { type = "despawn", id = 2 } })
		expect(h.controller:getModel(2)).never.toBeNil()
		table.clear(h.events)
		events(h, {
			{ type = "thought", id = 1, scenarioId = "farmer_drought", text = "Le blé ! 🌾", icon = "request" },
			{ type = "reaction", id = 1, text = "", tone = "angry" },
			{ type = "reaction", id = 3, text = "Hm.", tone = "neutral" },
			{ type = "kcue", id = 1, cue = "bow" },
			{ type = "kcue", id = 3, occupation = "farmer", cue = "salute" },
			{ type = "kcue", occupation = "farmer", cue = "strike_placard", entityIds = { 1, 3, 99 } }, -- 99 unknown
			{ type = "kcue", id = 1, cue = "grumble", entityIds = { 1, 3 } }, -- 1 listed twice: once
			{ type = "kcue", occupation = "farmer", cue = "rest" }, -- no ids: never fanned out by occupation
			{ type = "kcue", cue = "celebrate" },
			{ type = "strike", occupation = "farmer", on = true, entityIds = { 1, 99, 2 } }, -- only the known
			{ type = "strike", occupation = "miner", on = false, entityIds = { 3 } },
			{ type = "strike", occupation = "farmer", on = false, entityIds = {} }, -- nobody: nothing
			{ type = "thought", id = 99, scenarioId = "s", text = "?", icon = "idea" }, -- unknown: dropped
			{ type = "reaction", id = 2, text = "…", tone = "sad" }, -- despawned: dropped
			{ type = "kcue", id = 99, cue = "cower" }, -- unknown: dropped
		})
		expect(h.events).toEqual({
			{
				id = 1,
				cue = "thought",
				payload = { scenarioId = "farmer_drought", text = "Le blé ! 🌾", icon = "request" },
				model = model,
			},
			{ id = 1, cue = "reaction", payload = { text = "", tone = "angry" }, model = model },
			{ id = 3, cue = "reaction", payload = { text = "Hm.", tone = "neutral" } }, -- no rig: model nil
			{ id = 1, cue = "bow", payload = {}, model = model },
			{ id = 3, cue = "salute", payload = { occupation = "farmer" } },
			{ id = 1, cue = "strike_placard", payload = { occupation = "farmer" }, model = model },
			{ id = 3, cue = "strike_placard", payload = { occupation = "farmer" } },
			{ id = 1, cue = "grumble", payload = {}, model = model },
			{ id = 3, cue = "grumble", payload = {} },
			{ cue = "rest", payload = { occupation = "farmer" } }, -- HUD or keep only: id and model nil
			{ cue = "celebrate", payload = {} },
			{ id = 1, cue = "strike", payload = { occupation = "farmer", on = true }, model = model },
			{ id = 3, cue = "strike", payload = { occupation = "miner", on = false } },
		})
	end)

	it("plays the dead pose on die, then releases the rig after a short delay", function()
		local h = start(setup({ full(1, 0, 0) }))
		frame(h, 0)
		local model = h.controller:getModel(1)
		local torsoMotor = model.PrimaryPart:FindFirstChild("Torso")
		events(h, { { type = "cue", id = 1, cue = "die" }, { type = "despawn", id = 1 } })
		expect(h.events[1].cue).toBe("die")
		expect(h.events[1].model).toBe(model)
		expect(h.controller:getModel(1)).toBe(model) -- the corpse stays while the pose plays
		frame(h, Def.DEATH_BLEND + 0.1)
		local dead = Pose.sample("dead", "farmer", 0, 0).Torso
		local got = h.rec.transforms[torsoMotor]
		expect((got.Position - dead.Position).Magnitude).toBeLessThan(1e-3)
		expect(got.UpVector:Dot(dead.UpVector)).toBeGreaterThan(0.999)
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 40, 40) }) -- despawned: never moves the corpse
		frame(h, 0.1)
		expect(pivotOf(model).X).toBeNear(0, 1e-3)
		expect(#h.released).toBe(0)
		frame(h, Def.DEATH_DELAY)
		expect(#h.released).toBe(1)
		expect(h.controller:getModel(1)).toBeNil()
		frame(h, 0.1)
		expect(#h.rendered).toBe(1)
	end)

	it("a reset releases everything and forgets the despawned ids and the clock, not the seq", function()
		local h = start(setup({ full(1, 0, 0), full(2, 5, 0), full(3, 10, 0) }))
		frame(h, 0)
		events(h, { { type = "despawn", id = 2 } })
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 1, 0), record(3, 11, 0) }, 500)
		table.clear(h.released)
		events(h, { { type = "reset" } })
		table.sort(h.released, function(a, b)
			return a.id < b.id
		end)
		expect(#h.released).toBe(2)
		expect(h.released[1].id).toBe(1)
		expect(h.released[2].id).toBe(3)
		for id = 1, 3 do
			expect(h.controller:getModel(id)).toBeNil()
		end
		-- the new match reuses ids; the server's seq keeps counting, so a late old-match packet is dropped
		events(h, { full(2, 1, 1) })
		h.env.mock:advance(0.1)
		snapshot(h, { record(2, 50, 50) }, 499) -- delayed from the old match
		expect(h.controller.stats.stale).toBe(1)
		snapshot(h, { record(2, 4, 4) }, 501)
		frame(h, 1)
		expect((pivotOf(h.controller:getModel(2)) - Vector3.new(4, 0, 4)).Magnitude).toBeLessThan(1e-3)
		expect(h.controller:getModel(1)).toBeNil()
	end)
end)

describe("EntityController: frames, LOD and pick", function()
	it("hides rigs beyond 150 studs, skips their pose work and restores them near", function()
		local h = setup({ full(1, 10, 0), full(2, 200, 0) })
		h.rec.focus = Vector3.zero
		start(h)
		frame(h, 0)
		local near, far = h.controller:getModel(1), h.controller:getModel(2)
		expect(near.Parent).toBe(h.controller.folder)
		expect(far.Parent).toBeNil()
		table.clear(h.rec.transforms)
		frame(h, 1 / 60)
		expect(h.rec.moves[#h.rec.moves]).toBe(1)
		for motor in h.rec.transforms do
			expect(motor:IsDescendantOf(far)).toBe(false)
		end
		expect(next(h.rec.transforms)).never.toBeNil()
		h.rec.focus = Vector3.new(55, 0, 0) -- 145 studs: inside 150 but outside the 140 hysteresis
		frame(h, 1 / 60)
		expect(far.Parent).toBeNil()
		h.rec.focus = Vector3.new(65, 0, 0)
		frame(h, 1 / 60)
		expect(far.Parent).toBe(h.controller.folder)
		expect(h.rec.moves[#h.rec.moves]).toBe(2)
		h.rec.focus = Vector3.new(300, 0, 0)
		frame(h, 1 / 60)
		expect(near.Parent).toBeNil()
		expect(far.Parent).toBe(h.controller.folder)
	end)

	it("animates 50 entities through every action without errors, one BulkMoveTo per frame", function()
		local world = {}
		for id = 1, 50 do
			table.insert(world, full(id, (id % 10) * 6, (id // 10) * 6, { job = EventCodec.JOBS[id % 7 + 1] }))
		end
		local h = start(setup(world))
		for tick = 1, 30 do
			local records = {}
			for id = 1, 50 do
				local action = SnapshotCodec.ACTIONS[(id + tick // 10) % 8 + 1]
				table.insert(
					records,
					record(id, (id % 10) * 6 + tick * 0.4, (id // 10) * 6, {
						yaw = tick * 0.2,
						action = action,
						carrying = if action == "carry" then "stone" else nil,
					})
				)
			end
			for _ = 1, 6 do
				frame(h, 1 / 60)
			end
			snapshot(h, records)
		end
		expect(#h.rendered).toBe(50)
		expect(h.env.mock.threadErrors).toEqual({})
		expect(h.rec.moves[#h.rec.moves]).toBe(50)
		expect(#h.rec.moves).toBe(180)
		expect(h.rec.writes).toBeGreaterThan(50 * 6 * 150)
	end)

	it("RunService.Heartbeat drives the frames", function()
		local h = start(setup({ full(1, 0, 0) }))
		h.env.RunService.Heartbeat:Fire(1 / 60)
		expect(#h.rec.moves).toBe(1)
		expect(#h.rendered).toBe(1)
	end)

	it("pick returns the nearest visible entity to a screen point", function()
		local h = setup({ full(1, 0, 0), full(2, 10, 0), full(3, 300, 0), full(4, 0, 20) })
		h.rec.focus = Vector3.zero
		start(h)
		frame(h, 0)
		-- the projection puts entity 1 at (500, 500), 2 at (520, 500), 4 at (500, 540); 3 is LOD-hidden
		expect(h.controller:pick(Vector2.new(505, 500))).toBe(1)
		expect(h.controller:pick(Vector2.new(516, 503))).toBe(2)
		expect(h.controller:pick(Vector2.new(500, 535))).toBe(4)
		expect(h.controller:pick(Vector2.new(1100, 500))).toBeNil() -- 3 is hidden
		expect(h.controller:pick(Vector2.new(900, 900))).toBeNil() -- nothing within PICK_RADIUS
		events(h, { { type = "cue", id = 4, cue = "die" } })
		expect(h.controller:pick(Vector2.new(500, 535))).toBe(1) -- the dying are not picked; 1 is 35 px away
	end)

	it("destroy releases every rig, removes the folder and ignores later traffic", function()
		local h = start(setup({ full(1, 0, 0), full(2, 5, 0) }))
		frame(h, 0)
		local folder = h.controller.folder
		h.controller:destroy()
		expect(#h.released).toBe(2)
		expect(folder.Parent).toBeNil()
		h.env.mock:advance(0.1)
		snapshot(h, { record(1, 1, 1) })
		events(h, { spawnRecord(5) })
		h.controller:step(0.1)
		expect(h.controller:getModel(1)).toBeNil()
		expect(h.env.mock.threadErrors).toEqual({})
	end)
end)
