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
local Slots = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Slots")
local Text = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Text")
local Turns = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Turns")
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

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
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

describe("Move in the building panel (FL-0120)", function()
	local previous, world
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("offers Move on my own buildings, never on the keep, a foreign building or before the server moves", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		world.panel:open(id)
		world:advance(0.1)
		local panel = find(world.hud.guis.menus, "UpgradePanel")
		local side = find(panel, "Side")
		expect(side).toBeTruthy()
		expect(texts(side)).toContain("Move")
		expect(find(side, "Face"):GetAttribute("side")).toBe("ready")
		world.panel:open(idOf(world, "keep"))
		world:advance(0.1)
		expect(find(find(world.hud.guis.menus, "UpgradePanel"), "Side")).toBeNil()
		world.panel:open(2) -- azure's keep: not mine
		world:advance(0.1)
		expect(find(find(world.hud.guis.menus, "UpgradePanel"), "Side")).toBeNil()
		world:destroy()
		world = newWorld({ noMove = true })
		id = house(world, Vector3.new(40, 0, 40))
		world.panel:open(id)
		world:advance(0.1)
		expect(find(find(world.hud.guis.menus, "UpgradePanel"), "Side")).toBeNil()
		expect(world.build:startMove(id)).toBe(false)
	end)

	it("Move picks the building up: panel closed, ghost where it stands, the original dimmed, edit mode", function()
		world = newWorld({ edit = true })
		local id = house(world, Vector3.new(40, 0, 40), 1)
		-- the building's world model (WorldView draws it; BuildingId attribute)
		local model = Instance.new("Model")
		model.Name = "House"
		model:SetAttribute("BuildingId", id)
		local part = Instance.new("Part")
		part.Parent = model
		model.Parent = world.env.Workspace
		world.panel:open(id)
		world:advance(0.1)
		tap(find(find(world.hud.guis.menus, "UpgradePanel"), "Side"))
		world:advance(0.2)
		expect(world.hud.state.menu).toBeNil()
		local p = world.build.placing
		expect(p).toBeTruthy()
		expect(p.move.id).toBe(id)
		expect(p.rot).toBe(1)
		expect(world.modes[#world.modes]).toBe("edit")
		expect(model:GetAttribute("ForgeMoving")).toBe(true) -- (Lune has no LocalTransparencyModifier)
		local checks = world:callsNamed("CanMove")
		expect(#checks).toBe(1)
		expect(checks[1].args[1]).toBe(id)
		expect(checks[1].args[2]).toBe(Vector3.new(40, 0, 40))
		expect(checks[1].args[3]).toBe(1)
		expect(#world:callsNamed("CanPlace")).toBe(0)
		local bar = find(world.hud.guis.hud, "PlacementBar")
		expect(texts(bar)).toContain("Move House")
		expect(texts(bar)).toContain("Move here")
		expect(find(bar, "Costs"):FindFirstChildWhichIsA("Frame")).toBeNil() -- moving is free
		world.build:cancel()
		expect(world.build.placing).toBeNil()
		expect(world.build.ghost).toBeNil()
		expect(model:GetAttribute("ForgeMoving")).toBeNil()
		expect(world.modes[#world.modes]).toBe("explore")
	end)

	it("falls back to build mode while the input controller has no edit mode (FORGE-04 FL-0121)", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		expect(world.build:startMove(id)).toBe(true)
		expect(world.modes[#world.modes]).toBe("build")
		expect(world.build.placing).toBeTruthy() -- the build-mode listener keeps it
	end)

	it("moves it: CanMove tints the ghost, Move here sends Build.Move, a toast, then the cooldown", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:startMove(id)
		world:advance(0.2)
		world.build:aimAt(Vector3.new(500, 0, 0)) -- outside my land
		world:advance(0.2)
		expect(world.build.placing.status).toBe("bad")
		expect(world.build.placing.reason).toBe("Move it inside your keep's land")
		local bar = find(world.hud.guis.hud, "PlacementBar")
		expect(find(find(bar, "Place"), "Face"):GetAttribute("cta")).toBe("disabled")
		world.build:aimAt(Vector3.new(100.6, 0, 99.2))
		world:advance(0.2)
		world.build:rotate(-1)
		world:advance(0.2)
		expect(world.build.placing.status).toBe("ok")
		expect(world.build.ghost.base.Color).toBe(Color3.fromRGB(91, 174, 95))
		tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
		world:advance(0.2)
		local moves = world:callsNamed("Move")
		expect(#moves).toBe(1)
		expect(moves[1].args[1]).toBe(id)
		expect(moves[1].args[2]).toBe(Placement.snap(Vector3.new(100.6, 0, 99.2)))
		expect(moves[1].args[3]).toBe(3)
		expect(texts(world.hud.guis.notices)).toContain("House moved")
		expect(world.build.placing).toBeNil()
		-- the building arrives where it was set down (Build.Buildings re-sends it)
		local b = world.hud.store:building(id)
		expect((b.cframe.Position - Vector3.new(100, 0, 100)).Magnitude).toBeLessThan(1e-4)
		-- the panel counts the server's 10 s from my own accepted move, then offers Move again
		world.panel:open(id)
		world:advance(0.1)
		local side = find(find(world.hud.guis.menus, "UpgradePanel"), "Side")
		expect(texts(side)).toContain("Moved")
		expect(find(side, "Face"):GetAttribute("side")).toBe("disabled")
		Create.fire(find(side, "Face"), "Activated")
		world:advance(0.1)
		expect(world.build.placing).toBeNil()
		world:advance(10.2)
		side = find(find(world.hud.guis.menus, "UpgradePanel"), "Side")
		expect(texts(side)).toContain("Move")
		expect(find(side, "Face"):GetAttribute("side")).toBe("ready")
	end)

	it("explains every refusal in words and keeps the move open to try again", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:startMove(id)
		world:advance(0.2)
		for code, words in
			{
				alarm = "Not while the alarm bell rings",
				under_attack = "Not while it's under attack",
				cooldown = "It just moved. Wait a few seconds",
				not_found = "That building is gone",
			}
		do
			world.moveRefuse = code
			world.build:aimAt(Vector3.new(60 + #code * 2, 0, 80))
			world:advance(0.2)
			expect(world.build.placing.status).toBe("bad")
			expect(world.build.placing.reason).toBe(words)
		end
		-- a refusal on Move here itself (the state changed after the green ghost)
		world.moveRefuse = nil
		world.build:aimAt(Vector3.new(120, 0, 120))
		world:advance(0.2)
		expect(world.build.placing.status).toBe("ok")
		world.moveRefuse = "under_attack"
		tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
		world:advance(0.2)
		expect(texts(world.hud.guis.notices)).toContain("Couldn't move the House")
		expect(texts(world.hud.guis.notices)).toContain("Not while it's under attack")
		expect(world.build.placing).toBeTruthy()
		expect(world.build.placing.status).toBe("bad")
		expect(world.server:get("BuildingService").positions[id]).toBe(Vector3.new(40, 0, 40))
		-- the keep is never picked up
		expect(world.build:startMove(idOf(world, "keep"))).toBe(false)
	end)

	it("snaps to a free plot that fits, turns through the turns that fit and moves with Build.MoveToSlot", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		world.build:startMove(id)
		world:advance(0.2)
		local frame = Slots.frame("crimson_slot5")
		local nearCentre = frame.center + Vector3.new(2, 0, 1)
		local checksBefore = #world:callsNamed("CanMove")
		world.build:aimAt(nearCentre)
		world:advance(0.2)
		local p = world.build.placing
		expect(p.move.slot.id).toBe("crimson_slot5")
		expect(p.move.slot.allowed).toEqual(Turns.allowed("house", "M"))
		expect(p.status).toBe("ok")
		expect(#world:callsNamed("CanMove")).toBe(checksBefore) -- the plot needs no CanMove
		local bar = find(world.hud.guis.hud, "PlacementBar")
		expect(texts(bar)).toContain("✓ Faces the street")
		local ghost = world.build.ghost
		expect((ghost.base.CFrame.Position * Vector3.new(1, 0, 1) - frame.center * Vector3.new(1, 0, 1)).Magnitude).toBeLessThan(
			1e-4
		)
		expect((ghost.base.CFrame.LookVector - CFrame.Angles(0, frame.yaw, 0).LookVector).Magnitude).toBeLessThan(1e-4)
		world.build:rotate(1)
		world:advance(0.1)
		expect(p.move.turn).toBe(1)
		expect(texts(find(world.hud.guis.hud, "PlacementBar"))).toContain("Faces right")
		expect((ghost.base.CFrame.LookVector - CFrame.Angles(0, frame.yaw + math.pi / 2, 0).LookVector).Magnitude).toBeLessThan(
			1e-4
		)
		world.build:rotate(-1)
		expect(p.move.turn).toBe(0)
		world.build:rotate(-1)
		world:advance(0.1)
		expect(p.move.turn).toBe(3)
		tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
		world:advance(0.2)
		local calls = world:callsNamed("MoveToSlot")
		expect(#calls).toBe(1)
		expect(calls[1].args).toEqual({ id, "crimson_slot5", 3 })
		expect(#world:callsNamed("Move")).toBe(0)
		expect(texts(world.hud.guis.notices)).toContain("House moved")
		expect(world.hud.store:slot("crimson_slot5").occupiedBy).toBe(id)
		-- off the plot again: a free move, checked with CanMove
		world:advance(10.5)
		world.build:startMove(id)
		world:advance(0.2)
		world.build:aimAt(Vector3.new(150, 0, 150))
		world:advance(0.2)
		expect(world.build.placing.move.slot).toBeNil()
		expect(world:callsNamed("CanMove")[#world:callsNamed("CanMove")].args[2]).toBe(Vector3.new(150, 0, 150))
	end)

	it("keeps the move through taps on my own building and plot in edit mode (FORGE-07 B1 on #148)", function()
		for _, edit in { true, false } do
			world = newWorld({ edit = edit })
			local id = house(world, Vector3.new(40, 0, 40))
			local other = idOf(world, "storehouse")
			expect(world.build:startMove(id)).toBe(true)
			world:advance(0.5) -- past the mode's settle time
			local input = world.client:get("InputModeController")
			expect(input.mode).toBe(if edit then "edit" else "build")
			-- what FL-0121's edit mode fires for a tap on my own targets (and on anything else)
			for _, selection in
				{ { "building", other }, { "building", id }, { "slot", "crimson_slot5" }, { "none", "" } }
			do
				input.selected:fire(selection[1], selection[2])
				world:advance(0.1)
				expect(world.build.placing).toBeTruthy()
				expect(world.build.placing.move.id).toBe(id)
				expect(world.hud.state.menu).toBeNil()
			end
			world.build:cancel()
			-- back in explore mode the same taps open the panels again
			input.selected:fire("building", other)
			world:advance(0.1)
			expect(world.hud.state.menu).toBe("upgrade")
			input.selected:fire("slot", "crimson_slot5")
			world:advance(0.1)
			expect(world.hud.state.menu).toBe("plot")
			world:destroy()
			world = nil
		end
	end)

	it(
		"starts at the turn it stands at on its own plot, and putting it back changes nothing (FORGE-07 M1, L3)",
		function()
			world = newWorld()
			local id = house(world, Vector3.new(40, 0, 40))
			local frame = Slots.frame("crimson_slot5")
			local service = world.server:get("BuildingService")
			service.buildings[id].cframe = MoveDoubles.cframe(frame.center, frame.yaw + math.pi / 2)
			service:push(id)
			world.server:get("SlotService"):occupy("crimson_slot5", id)
			world:advance(0.2)
			expect(world.build:startMove(id)).toBe(true)
			world:advance(0.2)
			local p = world.build.placing
			expect(p.move.slot.id).toBe("crimson_slot5") -- its own plot, under it
			expect(p.move.turn).toBe(1)
			expect(texts(find(world.hud.guis.hud, "PlacementBar"))).toContain("Faces right")
			expect(texts(find(world.hud.guis.hud, "PlacementBar"))).toContain("Click moves")
			-- Move here where it stands: no remote, no toast, no cooldown
			tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
			world:advance(0.2)
			expect(world.build.placing).toBeNil()
			expect(#world:callsNamed("MoveToSlot")).toBe(0)
			expect(texts(world.hud.guis.notices)).never.toContain("House moved")
			expect(world.build.movedAt[id]).toBeNil()
			-- a turn on the same plot is a move
			world.build:startMove(id)
			world:advance(0.2)
			world.build:rotate(1)
			world:advance(0.1)
			tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
			world:advance(0.2)
			expect(world:callsNamed("MoveToSlot")[1].args).toEqual({ id, "crimson_slot5", 2 })
			-- off a plot: set down on the cell it stands on, at the same rot, is no move either
			world:advance(10.5)
			local free = house(world, Vector3.new(100, 0, 100), 3)
			world.build:startMove(free)
			world:advance(0.2)
			expect(world.build.placing.move.slot).toBeNil()
			expect(world.build.placing.status).toBe("ok")
			tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
			world:advance(0.2)
			expect(world.build.placing).toBeNil()
			expect(#world:callsNamed("Move")).toBe(0)
			expect(world.build.movedAt[free]).toBeNil()
		end
	)

	it("never snaps where the building can't stand: another building's plot, a type that doesn't fit, walls", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		local slots = world.server:get("SlotService")
		local frame = Slots.frame("crimson_slot5")
		slots:occupy("crimson_slot5", idOf(world, "storehouse"))
		world:advance(0.2)
		world.build:startMove(id)
		world:advance(0.2)
		world.build:aimAt(frame.center)
		world:advance(0.2)
		expect(world.build.placing.move.slot).toBeNil()
		world.build:cancel()
		-- a barracks fits a medium plot only facing the street or away
		slots:occupy("crimson_slot5", nil)
		world:advance(0.2)
		local service = world.server:get("BuildingService")
		local barracks = service:add("crimson", "barracks", 1, "complete", Vector3.new(-40, 0, 40))
		service.buildings[barracks].cframe = MoveDoubles.cframe(Vector3.new(-40, 0, 40), 0)
		service:push(barracks)
		world:advance(0.1)
		world.build:startMove(barracks)
		world:advance(0.2)
		world.build:aimAt(frame.center)
		world:advance(0.2)
		expect(world.build.placing.move.slot.allowed).toEqual({ 0, 2 })
		world.build:rotate(1)
		expect(world.build.placing.move.turn).toBe(2)
		world.build:rotate(1)
		expect(world.build.placing.move.turn).toBe(0)
		world.build:cancel()
		-- a wall never snaps to a plot (not_on_plot)
		local wall = service:add("crimson", "wall", 1, "complete", Vector3.new(0, 0, 120))
		service.buildings[wall].cframe = MoveDoubles.cframe(Vector3.new(0, 0, 120), 0)
		service:push(wall)
		world:advance(0.1)
		world.build:startMove(wall)
		world:advance(0.2)
		world.build:aimAt(frame.center)
		world:advance(0.2)
		expect(world.build.placing.move.slot).toBeNil()
	end)

	it("keeps the turn only where it fits: a quarter turn on a medium plot falls back on a small one", function()
		world = newWorld()
		local id = house(world, Vector3.new(40, 0, 40))
		-- a small plot with a real world/Layout id next to the medium one
		local slots = world.server:get("SlotService")
		slots.slots.crimson_slot1 =
			{ id = "crimson_slot1", kingdom = "crimson", size = "S", center = Vector3.new(-170, 0, 170) }
		slots:publish("crimson")
		world:advance(0.2)
		world.build:startMove(id)
		world:advance(0.2)
		world.build:aimAt(Slots.frame("crimson_slot5").center)
		world.build:rotate(1)
		expect(world.build.placing.move.turn).toBe(1) -- a house turned a quarter fits 36 × 30
		world.build:aimAt(Slots.frame("crimson_slot1").center)
		world:advance(0.1)
		local p = world.build.placing
		expect(p.move.slot.id).toBe("crimson_slot1")
		expect(p.move.slot.allowed).toEqual({ 0, 2 }) -- 22 × 18 turned is 18 × 22: deeper than 20
		expect(p.move.turn).toBe(0)
		tap(find(find(world.hud.guis.hud, "PlacementBar"), "Place"))
		world:advance(0.2)
		expect(world:callsNamed("MoveToSlot")[1].args).toEqual({ id, "crimson_slot1", 0 })
	end)

	it("words every code the move remotes answer, none as the generic fallback", function()
		local generic = "That didn't work. Try again."
		for _, code in
			{
				"not_found",
				"not_owner",
				"not_movable",
				"alarm",
				"under_attack",
				"cooldown",
				"blocked",
				"out_of_territory",
				"out_of_bounds",
				"match_not_active",
				"kingdom_eliminated",
				"not_in_match",
			}
		do
			expect(Text.reason(code, "move") ~= generic).toBe(true)
		end
		for _, code in { "unknown_slot", "not_on_plot", "slot_occupied", "does_not_fit", "alarm", "cooldown" } do
			expect(Text.reason(code, "moveSlot") ~= generic).toBe(true)
		end
		expect(Text.reason("blocked", "moveSlot")).toBe("Something is in the way on this plot")
		expect(Text.reason("not_movable", "move")).toBe("The keep can't be moved")
	end)
end)

return T
