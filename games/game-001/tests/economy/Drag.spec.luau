-- FL-0123 (built on the FL-0120 helpers below): press-and-hold a building to drag it, with FORGE-04's edge-pan.
-- FL-0120 base editing, the UI (CONTRACTS G13.9 v0.4-g9j; the user's first Studio feedback: "select,
-- move, and rearrange placed buildings"): the upgrade panel's Move, the move ghost tinted by Build.CanMove,
-- turning, the plot snap with Build.MoveToSlot, every refusal in words, the dimmed original and the
-- cooldown. The real KingdomHudController, BuildMenuController, UpgradePanelController and
-- PlotPickerController over RemoteService, with FORGE-01 doubles (KingdomWorld, SlotDoubles,
-- MoveDoubles) and a FORGE-04 InputModeController double.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local MoveDoubles = require("./doubles/MoveDoubles")
local Placement = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Placement")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SlotDoubles = require("./doubles/SlotDoubles")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

local function find(root, name)
	if root == nil then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root)
	local out = {}
	for _, d in if root then root:GetDescendants() else {} do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

-- FORGE-04's InputModeController as a double: "edit" (FL-0121) only when `edit` is true.
local function inputModeDef(log, edit)
	return {
		name = "InputModeController",
		new = function()
			local c = { mode = "explore", changed = Signal.new(), selected = Signal.new() }
			function c:set(mode)
				if mode == "edit" and not edit then
					return false
				end
				table.insert(log, mode)
				if self.mode ~= mode then
					local previous = self.mode
					self.mode = mode
					self.changed:fire(mode, previous)
				end
				return true
			end
			function c:select() end
			return c
		end,
	}
end

local function newWorld(opts)
	local o = opts or {}
	local modes = {}
	o.remotes = if o.noMove then SlotDoubles.TURN_REMOTES else MoveDoubles.remotes(SlotDoubles.TURN_REMOTES)
	o.services = { SlotDoubles.turnService }
	if not o.noMove then
		table.insert(o.services, MoveDoubles.service)
	end
	o.clientDefinitions =
		{ KingdomHudDef, BuildMenuDef, UpgradePanelDef, PlotPickerDef, inputModeDef(modes, o.edit == true) }
	if o.camera then
		table.insert(o.clientDefinitions, o.camera)
	end
	local world = KingdomWorld.new(o)
	world.modes = modes
	world.hud = world.client:get("KingdomHudController")
	world.build = world.client:get("BuildMenuController")
	world.panel = world.client:get("UpgradePanelController")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

-- A complete house of mine at `position`, facing `rot` quarter turns, pushed to the client.
local function house(world, position, rot)
	local service = world.server:get("BuildingService")
	local id = service:add("crimson", "house", 1, "complete", position)
	service.buildings[id].cframe = MoveDoubles.cframe(position, (rot or 0) * math.pi / 2)
	service:push(id)
	world:advance(0.1)
	return id
end

local function idOf(world, buildingType)
	for id, b in world.server:get("BuildingService").buildings do
		if b.type == buildingType and b.kingdom == "crimson" then
			return id
		end
	end
	return nil
end

-- FORGE-04's RulerCameraController reduced to setEditDrag (#142): it records every call.
local function cameraDef(log)
	return {
		name = "RulerCameraController",
		new = function()
			return {
				setEditDrag = function(_, on)
					table.insert(log, on)
					return on
				end,
			}
		end,
	}
end

local HOLD = BuildMenuDef.DRAG_HOLD_SEC

describe("Drag a building (FL-0123)", function()
	local previous, world, editDrag
	beforeEach(function()
		previous = Create.useTestConnector()
		editDrag = {}
		world = newWorld({ edit = true, camera = cameraDef(editDrag) })
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("hold picks it up: the move starts in edit mode and the camera edge-pans", function()
		local id = house(world, Vector3.new(40, 0, 40))
		expect(world.build:dragPress(id, Vector2.new(400, 300))).toBe(true)
		world:advance(HOLD * 0.5)
		expect(world.build.placing).toBeNil() -- not yet: a tap is still possible
		world:advance(HOLD)
		expect(world.build:moving()).toBe(true)
		expect(world.build.placing.move.id).toBe(id)
		expect(world.build.dragging).toBe(true)
		expect(editDrag[#editDrag]).toBe(true)
		expect(world.modes[#world.modes]).toBe("edit")
	end)

	it("dragging moves the ghost; letting go on a good spot moves it (Build.Move) and ends the edge-pan", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		world.build:dragMove(Vector2.new(500, 320), Vector3.new(100.6, 0, 99.2))
		world:advance(0.3)
		expect(world.build.placing.position).toBe(Placement.snap(Vector3.new(100.6, 0, 99.2))) -- the ghost follows
		expect(world.build.placing.status).toBe("ok")
		world.build:dragRelease(Vector3.new(100.6, 0, 99.2))
		world:advance(0.3)
		local moves = world:callsNamed("Move")
		expect(#moves).toBe(1)
		expect(moves[1].args[1]).toBe(id)
		expect(moves[1].args[2]).toBe(Placement.snap(Vector3.new(100.6, 0, 99.2)))
		expect(world.build.placing).toBeNil()
		expect(world.build.dragging).toBe(false)
		expect(editDrag[#editDrag]).toBe(false)
		expect(texts(world.hud.guis.notices)).toContain("House moved")
	end)

	it("let go while the spot is still being checked: it moves as soon as the check says yes", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		world.build:dragRelease(Vector3.new(100.6, 0, 99.2)) -- no time for CanMove yet
		expect(world.build.placing.status).toBe("pending")
		expect(#world:callsNamed("Move")).toBe(0)
		world:advance(0.5)
		expect(#world:callsNamed("Move")).toBe(1)
		expect(world.build.placing).toBeNil()
	end)

	it("let go on a bad spot: the move stays open with the reason, nothing is sent", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		world.build:dragMove(Vector2.new(900, 300), Vector3.new(500, 0, 0)) -- outside my land
		world:advance(0.3)
		world.build:dragRelease(Vector3.new(500, 0, 0))
		world:advance(0.3)
		expect(#world:callsNamed("Move")).toBe(0)
		expect(world.build:moving()).toBe(true)
		expect(world.build.placing.reason).toBe("Move it inside your keep's land")
		expect(world.build.dragging).toBe(false)
		expect(editDrag[#editDrag]).toBe(false)
		-- a pending verdict that comes back bad does not move it either
		world.build:cancel()
		world:advance(0.1)
		world:advance(0.2)
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		world.build:dragRelease(Vector3.new(500, 0, 0))
		world:advance(0.5)
		expect(#world:callsNamed("Move")).toBe(0)
		expect(world.build:moving()).toBe(true)
	end)

	it("moving the pointer before the hold is a camera pan, not a drag; a quick release is a tap", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(0.1)
		world.build:dragMove(Vector2.new(400 + BuildMenuDef.DRAG_SLOP + 2, 300), nil)
		world:advance(HOLD)
		expect(world.build.placing).toBeNil()
		expect(#editDrag).toBe(0)
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(0.1)
		world.build:dragMove(Vector2.new(404, 302), nil) -- inside the slop: still a hold
		world.build:dragRelease(nil) -- let go before the hold
		world:advance(HOLD)
		expect(world.build.placing).toBeNil()
	end)

	it("the hold is longer than a tap, so the tap that opens the panel never also drags", function()
		expect(HOLD).toBeGreaterThan(0.4) -- InputModeController.DEFAULTS.tapSec
		expect(BuildMenuDef.DRAG_SLOP).toBe(8) -- InputModeController.DEFAULTS.tapPixels
	end)

	it("never on the keep, a foreign building, a destroyed one, during the cooldown or without Build.Move", function()
		local service = world.server:get("BuildingService")
		local keep = idOf(world, "keep")
		expect(world.build:dragPress(keep, Vector2.new(1, 1))).toBe(false)
		local foreign = service:add("azure", "house", 1, "complete", Vector3.new(900, 0, 900))
		service:push(foreign)
		world:advance(0.1)
		expect(world.build:dragPress(foreign, Vector2.new(1, 1))).toBe(false)
		local id = house(world, Vector3.new(40, 0, 40))
		world.build.movedAt[id] = world.env.clock() -- just moved
		expect(world.build:moveCooldownLeft(id)).toBeGreaterThan(0)
		expect(world.build:dragPress(id, Vector2.new(1, 1))).toBe(false)
		world:advance(10.5)
		expect(world.build:moveCooldownLeft(id)).toBe(0)
		expect(world.build:dragPress(id, Vector2.new(1, 1))).toBe(true)
		world.build:dragRelease(nil)
		world:destroy()
		world = newWorld({ edit = true, camera = cameraDef(editDrag), noMove = true })
		local other = house(world, Vector3.new(40, 0, 40))
		expect(world.build:dragPress(other, Vector2.new(1, 1))).toBe(false)
	end)

	it("not while another mode owns the pointer, nor during a move already under way", function()
		local id = house(world, Vector3.new(40, 0, 40))
		local input = world.client:get("InputModeController")
		input.mode = "walk"
		expect(world.build:dragPress(id, Vector2.new(1, 1))).toBe(false)
		input.mode = "explore"
		world.build:startMove(id)
		world:advance(0.1)
		expect(world.build:dragPress(id, Vector2.new(1, 1))).toBe(false)
	end)

	it("cancelling the move or destroying the controller ends the edge-pan", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		expect(editDrag[#editDrag]).toBe(true)
		world.build:cancel()
		expect(editDrag[#editDrag]).toBe(false)
		expect(world.build.dragging).toBe(false)
		world.build:dragPress(id, Vector2.new(400, 300))
		world:advance(HOLD + 0.1)
		expect(editDrag[#editDrag]).toBe(true)
		world.build:destroy()
		expect(editDrag[#editDrag]).toBe(false)
	end)

	it("the upgrade panel's Move uses the same cooldown rule", function()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build.movedAt[id] = world.env.clock()
		world.panel:open(id)
		world:advance(0.1)
		local side = find(find(world.hud.guis.menus, "UpgradePanel"), "Side")
		expect(texts(side)).toContain("Moved")
	end)
end)
