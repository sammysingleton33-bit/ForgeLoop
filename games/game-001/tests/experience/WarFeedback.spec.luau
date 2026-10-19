-- FL-0130 part 2: war feedback on the client (FeedbackWarController) and the spectate camera
-- (RulerSpectateController). Headless: engine doubles for audio, effects, camera and settings.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach
local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local Presets = require("@game/ReplicatedStorage/Game/Feedback/Presets")
local WarDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackWarController")
local SpectateDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerSpectateController")

local function rig(at: Vector3, parts: number?)
	local model = roblox.Instance.new("Model")
	local first
	for i = 1, parts or 3 do
		local part = roblox.Instance.new("Part")
		part.CFrame = CFrame.new(at + Vector3.new(i, 0, 0))
		part.Parent = model
		first = first or part
	end
	model.PrimaryPart = first
	return model
end

-- Workspace.ForgeKingdoms/<kingdom>/Buildings/<model with BuildingId, Kind, KingdomId>
local function world(env)
	local root = roblox.Instance.new("Folder")
	root.Name = "ForgeKingdoms"
	root.Parent = env.Workspace
	local folders = {}
	return function(kingdom: string, id: number, kind: string, at: Vector3)
		local folder = folders[kingdom]
		if folder == nil then
			folder = roblox.Instance.new("Folder")
			folder.Name = kingdom
			folder.Parent = root
			local buildings = roblox.Instance.new("Folder")
			buildings.Name = "Buildings"
			buildings.Parent = folder
			folders[kingdom] = folder
		end
		local model = rig(at, 4)
		model:SetAttribute("BuildingId", id)
		model:SetAttribute("Kind", kind)
		model:SetAttribute("KingdomId", kingdom)
		model.Parent = folder:FindFirstChild("Buildings")
		return model
	end
end

local function view(id, fields)
	local out = {
		id = id,
		kingdom = "crimson",
		type = "house",
		level = 1,
		state = "complete",
		hp = 100,
		maxHp = 100,
		cframe = CFrame.new(10 * id, 0, 0),
	}
	for k, v in fields or {} do
		out[k] = v
	end
	return out
end

describe("FeedbackWarController (FL-0130 part 2)", function()
	local env, effects, stopped, played, focused, modes, shakes, reduced, focus, cameraMode, inputBegan, battles

	local function boot()
		local defs = {
			{
				name = "AudioController",
				new = function()
					return {
						play = function(_, id, o)
							table.insert(played, { id = id, position = o and o.position })
							return {}
						end,
					}
				end,
			},
			{
				name = "VFXController",
				new = function()
					return {
						play = function(_, id, o)
							local effect = { id = id, position = o and o.position }
							table.insert(effects, effect)
							return effect
						end,
						stop = function(_, effect)
							table.insert(stopped, effect)
						end,
					}
				end,
			},
			{
				name = "RulerCameraController",
				new = function()
					local camera = { mode = cameraMode }
					function camera.getFocus()
						return focus
					end
					function camera.focusOn(_, position)
						table.insert(focused, position)
						return true
					end
					function camera.setMode(self, mode)
						table.insert(modes, mode)
						self.mode = mode
						return true
					end
					function camera.shake(_, magnitude, duration)
						table.insert(shakes, { magnitude, duration })
						return true
					end
					return camera
				end,
			},
			{
				name = "SettingsController",
				new = function()
					return {
						get = function(_, key)
							return if key == "reducedMotion" then reduced else nil
						end,
					}
				end,
			},
			{
				name = "MusicController",
				new = function()
					return {
						combatNear = function()
							battles += 1
						end,
					}
				end,
			},
			{
				name = "FeedbackWarController",
				new = function(e, r)
					return WarDef.create(e, r, { userInput = { InputBegan = inputBegan } })
				end,
			},
		}
		return Loader.load(env, defs):get("FeedbackWarController")
	end

	local function count(list, id)
		local n = 0
		for _, item in list do
			if item.id == id then
				n += 1
			end
		end
		return n
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 130, isServer = false, localPlayer = { userId = 4130 } })
		effects, stopped, played, focused, modes, shakes = {}, {}, {}, {}, {}, {}
		reduced, focus, cameraMode, battles = false, Vector3.new(0, 0, 0), "overview", 0
		inputBegan = Signal.new()
		inputBegan.Connect = inputBegan.connect
	end)

	it("the presets fit the VFX budget and the sounds are registered, needed and silent", function()
		local ids = {}
		for _, preset in Presets do
			ids[preset.id] = true
		end
		for _, id in WarDef.FX do
			assert(ids[id], `missing preset {id}`)
		end
		expect(VfxPresets.validate(Presets)).toEqual({})
		for _, id in WarDef.SOUND do
			local entry = Sounds.registry:get(id)
			assert(entry, `missing sound {id}`)
			expect(entry.status).toBe("needed")
			expect(entry.asset).toBeNil()
		end
	end)

	it(
		"a hit flashes the rig briefly with sparks and a clash, at most once per gap, never far from the view",
		function()
			local war = boot()
			local soldier = rig(Vector3.new(5, 0, 5))
			war:onEntityEvent(7, "hit", {}, soldier)
			expect(war.stats.flashes).toBe(1)
			local highlight = nil
			for _, flash in war._flashes do
				highlight = flash.highlight
			end
			assert(highlight, "a flash")
			expect(highlight.Adornee).toBe(soldier)
			expect(highlight.Enabled).toBe(true)
			expect(count(effects, "war.hit")).toBe(1)
			expect(count(played, "war.hit")).toBe(1)
			expect(battles).toBe(1) -- battle music for whoever watches (#178 L4)
			war:onEntityEvent(7, "hit", {}, soldier) -- inside FLASH_GAP_SEC
			expect(war.stats.flashes).toBe(1)
			env.mock:advance(WarDef.FLASH_SEC + 0.01)
			war:step(0.2)
			expect(highlight.Enabled).toBe(false)
			-- (Studio also clears Adornee; Lune cannot clear a reference, so only Enabled is checked here)
			env.mock:advance(WarDef.FLASH_GAP_SEC)
			war:onEntityEvent(7, "hit", {}, soldier)
			expect(war.stats.flashes).toBe(2) -- the same Highlight, back from the pool
			focus = Vector3.new(1000, 0, 1000)
			war:onEntityEvent(8, "hit", {}, rig(Vector3.new(0, 0, 0)))
			expect(war.stats.flashes).toBe(2)
			expect(war.stats.skipped).toBe(1)
			expect(battles).toBe(2) -- the far one plays no battle music
			war:onEntityEvent(0 / 0, "hit", {}, soldier)
			war:onEntityEvent(9, "hit", {}, nil) -- no rig yet
			expect(war.stats.flashes).toBe(2)
		end
	)

	it("the pool never holds more than FLASH_MAX highlights at once", function()
		local war = boot()
		for id = 1, WarDef.FLASH_MAX + 4 do
			war:onEntityEvent(id, "hit", {}, rig(Vector3.new(id, 0, 0)))
		end
		local live = 0
		for _ in war._flashes do
			live += 1
		end
		expect(live).toBe(WarDef.FLASH_MAX)
	end)

	it("a death fades the rig out over DEATH_FADE, and a released rig is whole again", function()
		local war = boot()
		local body = rig(Vector3.new(2, 0, 2))
		war:onEntityEvent(3, "die", {}, body)
		local parts = body:GetDescendants()
		war:step(0)
		expect(parts[1].LocalTransparencyModifier).toBe(0) -- falling into the dead pose first
		env.mock:advance(1.4)
		war:step(0.1)
		local half = parts[1].LocalTransparencyModifier
		expect(half > 0.4 and half < 0.6).toBe(true)
		env.mock:advance(1)
		war:step(0.1)
		for _, part in parts do
			expect(part.LocalTransparencyModifier).toBe(1)
		end
		war:released(3, body)
		for _, part in parts do
			expect(part.LocalTransparencyModifier).toBe(0) -- the pool's next citizen is not a ghost
		end
		expect(war._dying[3]).toBeNil()
	end)

	it("a building that loses hp gets dust and a short shake, then stands exactly where it was", function()
		local war = boot()
		local add = world(env)
		local house = add("crimson", 4, "house", Vector3.new(20, 0, 0))
		local before = {}
		for i, part in house:GetDescendants() do
			before[i] = part.CFrame
		end
		war:onBuildings({ view(4) })
		expect(war.stats.hits).toBe(0) -- the first view is the baseline
		war:onBuildings({ view(4, { hp = 80, state = "damaged" }) })
		expect(war.stats.hits).toBe(1)
		expect(count(effects, "war.building.hit")).toBe(1)
		expect(war.stats.shakes).toBe(1)
		expect(battles).toBe(1)
		war:step(0.05)
		local moved = false
		for i, part in house:GetDescendants() do
			if part.CFrame ~= before[i] then
				moved = true
			end
		end
		expect(moved).toBe(true)
		war:onBuildings({ view(4, { hp = 70, state = "damaged" }) }) -- inside HIT_GAP_SEC
		expect(war.stats.hits).toBe(1)
		war:step(WarDef.SHAKE.sec)
		for i, part in house:GetDescendants() do
			expect(part.CFrame.Position).toEqual(before[i].Position)
		end
		-- repairs (hp up) are no hit
		env.mock:advance(1)
		war:onBuildings({ view(4, { hp = 90, state = "damaged" }) })
		expect(war.stats.hits).toBe(1)
		expect(#war:hotspots()).toBe(1)
	end)

	it("reduced motion keeps the dust and drops the shake; a burning building is left to its fire", function()
		reduced = true
		local war = boot()
		local add = world(env)
		add("crimson", 5, "farm", Vector3.new(30, 0, 0))
		local store = add("crimson", 6, "storehouse", Vector3.new(40, 0, 0))
		store:SetAttribute("Burning", true)
		war:onBuildings({ view(5), view(6) })
		war:onBuildings({ view(5, { hp = 60 }), view(6, { hp = 60 }) })
		expect(war.stats.hits).toBe(1)
		expect(war.stats.shakes).toBe(0)
		expect(count(effects, "war.building.hit")).toBe(1)
	end)

	it("a standing building that is destroyed collapses; a cancelled site and a new world do not", function()
		local war = boot()
		war:onBuildings({ view(1), view(2, { state = "constructing" }) })
		war:onBuildings({ view(1, { state = "destroyed", hp = 0 }), view(2, { state = "destroyed", hp = 0 }) })
		expect(war.stats.collapses).toBe(1)
		expect(count(effects, "war.building.collapse")).toBe(1)
		expect(effects[#effects].position).toEqual(Vector3.new(10, 4, 0))
		expect(count(played, "war.collapse")).toBe(1)
		expect(#shakes).toBe(1) -- near the view
		-- a new world: BuildingService sends every old building as destroyed, keeps of every kingdom
		war:onBuildings({ view(3), view(4, { kingdom = "azure", type = "keep" }), view(5, { type = "keep" }) })
		war:onBuildings({
			view(3, { state = "destroyed" }),
			view(4, { kingdom = "azure", type = "keep", state = "destroyed" }),
			view(5, { type = "keep", state = "destroyed" }),
		})
		expect(war.stats.collapses).toBe(1)
		expect(war.stats.resets).toBe(1)
		expect(WarDef.isWorldReset({ view(9, { type = "keep", state = "destroyed" }) })).toBe(false) -- one conquest
	end)

	it("a kingdom's fall collapses at most COLLAPSE_MAX buildings, nearest first, with one crash", function()
		local war = boot()
		local standing, gone = {}, {}
		for id = 1, 9 do
			table.insert(standing, view(id))
			table.insert(gone, view(id, { state = "destroyed" }))
		end
		war:onBuildings(standing)
		war:onBuildings(gone)
		expect(war.stats.collapses).toBe(WarDef.COLLAPSE_MAX)
		expect(count(played, "war.collapse")).toBe(1)
		expect(effects[1].position).toEqual(Vector3.new(10, 4, 0)) -- nearest the focus first
	end)

	it("a raid becomes the alert: a beacon there, G or DPadUp takes the camera to it, the end clears it", function()
		cameraMode = "follow"
		local war = boot()
		local at = Vector3.new(60, 0, -30)
		expect(war:goToAlert()).toBe(false)
		war:onMoment({ kind = "raid", kingdom = "crimson", on = true, count = 4, position = at })
		expect(count(effects, "war.raid.ping")).toBe(1)
		expect(war:alert().position).toBe(at)
		inputBegan:fire({ KeyCode = Enum.KeyCode.G }, false)
		expect(focused[1]).toBe(at)
		expect(modes[1]).toBe("overview") -- from walk mode to the aerial view
		inputBegan:fire({ KeyCode = Enum.KeyCode.DPadUp }, true) -- a GUI took it
		expect(#focused).toBe(1)
		war:onMoment({ kind = "raid", kingdom = "crimson", on = false })
		expect(war:alert()).toBeNil()
		expect(stopped[1].id).toBe("war.raid.ping")
		expect(war:goToAlert()).toBe(false)
		war:onMoment({ kind = "raid", kingdom = "crimson", on = true }) -- no position: nothing to show
		expect(war:alert()).toBeNil()
		war:onMoment({ kind = "raid", kingdom = "crimson", on = true, position = at })
		war:onMoment({ kind = "kingdomFell", kingdom = "crimson" })
		expect(war:alert()).toBeNil()
	end)

	it("hotspots merge within HOTSPOT_STUDS and expire after HOTSPOT_SEC", function()
		local war = boot()
		war:onEntityEvent(1, "hit", {}, rig(Vector3.new(0, 0, 0)))
		war:onEntityEvent(2, "hit", {}, rig(Vector3.new(10, 0, 0)))
		war:onEntityEvent(3, "hit", {}, rig(Vector3.new(150, 0, 0)))
		local spots = war:hotspots()
		expect(#spots).toBe(2)
		expect(spots[2].count + spots[1].count).toBe(3)
		env.mock:advance(WarDef.HOTSPOT_SEC + 1)
		expect(#war:hotspots()).toBe(0)
	end)

	it("destroy puts the rigs back and stops the beacon", function()
		local war = boot()
		local body = rig(Vector3.new(1, 0, 1))
		war:onEntityEvent(1, "die", {}, body)
		env.mock:advance(2)
		war:step(0.1)
		war:onMoment({ kind = "raid", kingdom = "crimson", on = true, position = Vector3.zero })
		war:destroy()
		expect(body:GetDescendants()[1].LocalTransparencyModifier).toBe(0)
		expect(#stopped).toBe(1)
	end)
end)

describe("RulerSpectateController (FL-0130 part 2)", function()
	local env, focused, modes, hotspots, inputBegan

	local function boot()
		local defs = {
			{
				name = "RulerCameraController",
				new = function()
					local camera = { mode = "follow" }
					function camera.focusOn(_, position)
						table.insert(focused, position)
						return true
					end
					function camera.setMode(self, mode)
						table.insert(modes, mode)
						self.mode = mode
						return true
					end
					return camera
				end,
			},
			{
				name = "FeedbackWarController",
				new = function()
					return {
						hotspots = function()
							return hotspots
						end,
					}
				end,
			},
			{
				name = "RulerSpectateController",
				dependencies = { "RulerCameraController" },
				new = function(e, r)
					return SpectateDef.create(e, r, { userInput = { InputBegan = inputBegan } })
				end,
			},
		}
		return Loader.load(env, defs):get("RulerSpectateController")
	end

	local function kingdoms(mine, aliveMine)
		return {
			mine = mine,
			kingdoms = {
				{ id = "crimson", name = "Emberhold", alive = aliveMine },
				{ id = "azure", name = "Frostmere", alive = true },
				{ id = "emerald", name = "Greenwatch", alive = true },
				{ id = "gold", name = "Sunspire", alive = false },
			},
		}
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 131, isServer = false, localPlayer = { userId = 4131 } })
		focused, modes, hotspots = {}, {}, {}
		inputBegan = Signal.new()
		inputBegan.Connect = inputBegan.connect
		local add = world(env)
		add("crimson", 1, "keep", Vector3.new(-100, 0, 0))
		add("azure", 2, "keep", Vector3.new(100, 0, 0))
		add("emerald", 3, "keep", Vector3.new(0, 0, 100))
		add("emerald", 4, "house", Vector3.new(10, 0, 100))
	end)

	it(
		"starts when our kingdom falls: overview, the first target; targets are battles, then the standing keeps",
		function()
			local spectate = boot()
			local changes = {}
			spectate.changed:connect(function(active)
				table.insert(changes, active)
			end)
			spectate:onKingdomState(kingdoms("crimson", true))
			expect(spectate.active).toBe(false)
			hotspots = { { position = Vector3.new(50, 0, 50), at = 0, count = 3 } }
			spectate:onKingdomState(kingdoms(nil, false)) -- after the fall `mine` may be nil: crimson is remembered
			expect(spectate.active).toBe(true)
			expect(changes).toEqual({ true })
			expect(modes).toEqual({ "overview" })
			expect(focused[1]).toEqual(Vector3.new(50, 0, 50)) -- the battle first
			local targets = spectate:targets()
			expect(#targets).toBe(3) -- the battle, azure's keep, emerald's keep (not ours, not fallen gold's)
			expect(targets[2].kind).toBe("keep")
			expect(targets[2].kingdomName).toBe("Frostmere")
			expect(targets[2].position).toEqual(Vector3.new(101, 0, 0))
			expect(targets[3].kingdom).toBe("emerald")
		end
	)

	it(
		"cycles with . and , (R1 and L1), wrapping, only while spectating; select() follows the screen's list",
		function()
			local spectate = boot()
			inputBegan:fire({ KeyCode = Enum.KeyCode.Period }, false)
			expect(#focused).toBe(0) -- not spectating
			spectate:onKingdomState(kingdoms("crimson", false))
			expect(focused[1]).toEqual(Vector3.new(101, 0, 0)) -- no battle: azure's keep
			inputBegan:fire({ KeyCode = Enum.KeyCode.Period }, false)
			expect(focused[2]).toEqual(Vector3.new(1, 0, 100))
			inputBegan:fire({ KeyCode = Enum.KeyCode.ButtonR1 }, false)
			expect(focused[3]).toEqual(Vector3.new(101, 0, 0)) -- wrapped
			inputBegan:fire({ KeyCode = Enum.KeyCode.Comma }, false)
			expect(focused[4]).toEqual(Vector3.new(1, 0, 100))
			local picked = nil
			spectate.targetChanged:connect(function(target)
				picked = target
			end)
			expect(spectate:select(1).kingdom).toBe("azure")
			expect(picked.kingdom).toBe("azure")
			expect(spectate:select(9)).toBeNil()
		end
	)

	it("follows FL-0125's Match.Spectate: true starts it, false ends it, and its kingdom is never a target", function()
		local spectate = boot()
		spectate:onKingdomState({ mine = nil, kingdoms = kingdoms(nil, true).kingdoms }) -- a spectator: mine is nil
		spectate:onSpectate(true, { reason = "eliminated", kingdomId = "crimson", by = "azure", standing = {} })
		expect(spectate.active).toBe(true)
		for _, target in spectate:targets() do
			expect(target.kingdom == "crimson").toBe(false)
		end
		spectate:onSpectate(false)
		expect(spectate.active).toBe(false)
		spectate:onSpectate(true, { reason = "match_full", standing = {} })
		expect(spectate.active).toBe(true)
		spectate:onSpectate("yes")
		expect(spectate.active).toBe(true)
	end)

	it(
		"never starts during Results or Lobby; a Match.Spectate(true) then waits for a playing phase (#189 M1)",
		function()
			local spectate = boot()
			spectate:onKingdomState(kingdoms("crimson", false))
			expect(spectate.active).toBe(true)
			spectate:onPhase("Results")
			expect(spectate.active).toBe(false)
			spectate:onKingdomState(kingdoms(nil, false)) -- a state push during Results (a ruler leaves)
			expect(spectate.active).toBe(false)
			spectate:onKingdomState(kingdoms("crimson", false))
			expect(spectate.active).toBe(false)
			expect(spectate:setActive(true)).toBe(false)
			-- a late joiner: Match.State(Results), then Match.Spectate(true)
			local late = boot()
			late:onPhase("Results")
			late:onSpectate(true, { reason = "match_full", standing = {} })
			expect(late.active).toBe(false)
			late:onPhase("Lobby")
			expect(late.active).toBe(false)
			late:onPhase("Founding")
			expect(late.active).toBe(true) -- still not seated: it watches the new match
			-- seated in the lobby: Match.Spectate(false) clears the pending start
			local seated = boot()
			seated:onPhase("Results")
			seated:onSpectate(true, { reason = "match_full", standing = {} })
			seated:onSpectate(false)
			seated:onPhase("Founding")
			expect(seated.active).toBe(false)
		end
	)

	it("ends at Results and Lobby; a new match forgets the old kingdom", function()
		local spectate = boot()
		spectate:onKingdomState(kingdoms("crimson", false))
		expect(spectate.active).toBe(true)
		spectate:onPhase("Endgame")
		expect(spectate.active).toBe(true)
		spectate:onPhase("Results")
		expect(spectate.active).toBe(false)
		expect(spectate:cycle(1)).toBeNil()
		spectate:onPhase("Lobby")
		spectate:onKingdomState(kingdoms(nil, false)) -- the old crimson is not ours any more
		expect(spectate.active).toBe(false)
		expect(spectate:setActive(true)).toBe(false) -- never in the lobby
		spectate:onPhase("Founding")
		expect(spectate.active).toBe(false) -- nothing pending: the new match plays normally
		expect(spectate:setActive(true)).toBe(true) -- by hand
		expect(spectate:setActive(true)).toBe(false)
		-- spectating by hand while our kingdom stands: our own keep is never a target
		spectate:setActive(false)
		spectate:onKingdomState(kingdoms("crimson", true))
		spectate:setActive(true)
		for _, target in spectate:targets() do
			expect(target.kingdom == "crimson").toBe(false)
		end
		expect(#spectate:targets()).toBe(2)
	end)

	it("the Lobby forgets our old kingdom: in the new match it is a target again (#203 L1)", function()
		local spectate = boot()
		spectate:onKingdomState(kingdoms("crimson", false))
		expect(spectate.active).toBe(true)
		spectate:onPhase("Results")
		spectate:onPhase("Lobby")
		spectate:onPhase("Founding")
		spectate:onKingdomState(kingdoms(nil, true)) -- not seated this match; crimson is someone else's
		expect(spectate.active).toBe(false)
		expect(spectate:setActive(true)).toBe(true)
		local crimson = false
		for _, target in spectate:targets() do
			if target.kingdom == "crimson" then
				crimson = true
			end
		end
		expect(crimson).toBe(true)
		expect(#spectate:targets()).toBe(3)
	end)
end)
