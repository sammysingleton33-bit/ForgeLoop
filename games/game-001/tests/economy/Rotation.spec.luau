-- Rotation (the user's first Studio playtest, 2026-10-13; production/handoffs/
-- 2026-10-13-forge-00-to-all-first-studio-feedback.md): free placement shows which way a building
-- faces (ghost door strip and facing arrow, the Turn button's dial; Shift+R turns back) and the plot
-- picker turns a building on its plot (CONTRACTS G13.5 v0.4-g9h, `Build.PlaceSlot(slotId, type,
-- turn?)`), against the real KingdomHudController, BuildMenuController and PlotPickerController over
-- RemoteService, with FORGE-01 doubles (doubles/KingdomWorld, doubles/SlotDoubles).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Ghost = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Ghost")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Placement = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Placement")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local SlotDoubles = require("./doubles/SlotDoubles")
local Turns = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Turns")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

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

local function near(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-4
end

local function newWorld(opts)
	local o = opts or {}
	if o.turns then
		o.remotes = SlotDoubles.TURN_REMOTES
		o.services = { SlotDoubles.turnService }
	else
		o.remotes = SlotDoubles.REMOTES
		o.services = { SlotDoubles.service }
	end
	o.clientDefinitions = { KingdomHudDef, BuildMenuDef, PlotPickerDef }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.build = world.client:get("BuildMenuController")
	world.picker = world.client:get("PlotPickerController")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

describe("Rotation maths", function()
	it("turns a quarter at a time, forward and back", function()
		expect(Placement.nextRotation(0)).toBe(1)
		expect(Placement.nextRotation(3)).toBe(0)
		expect(Placement.nextRotation(0, -1)).toBe(3)
		expect(Placement.nextRotation(2, -1)).toBe(1)
	end)

	it("says where the front faces on screen from the camera (0 up, 90 right, 180 down, 270 left)", function()
		-- the default camera looks along -Z: rot 0 faces away from it; +1 is a quarter counter-clockwise
		expect(Placement.screenAngle(0, nil)).toBe(0)
		expect(Placement.screenAngle(math.pi / 2, nil)).toBe(270)
		expect(Placement.screenAngle(math.pi, nil)).toBe(180)
		expect(Placement.screenAngle(3 * math.pi / 2, nil)).toBe(90)
		-- a camera looking along +X (yawed a quarter clockwise): a building facing -Z is on its left
		local east = CFrame.lookAt(Vector3.new(0, 50, 0), Vector3.new(40, 0, 0))
		expect(Placement.screenAngle(0, east)).toBe(270)
		expect(Placement.screenAngle(-math.pi / 2, east)).toBe(0) -- facing +X: away from that camera
		-- straight down: the camera's up vector stands in for its forward
		-- (screen-up along +X here, so a building facing -Z points left)
		local top = CFrame.lookAt(Vector3.new(0, 100, 0), Vector3.new(0, 0, 0), Vector3.new(1, 0, 0))
		expect(Placement.screenAngle(0, top)).toBe(270)
	end)

	it("offers only the turns the contract says fit, and nothing while the server takes no turn", function()
		-- main's Build/Remotes declares PlaceSlot with two arguments: no turn yet (FORGE-01 lands it)
		Turns.useSeam(nil)
		expect(Turns.supported()).toBe(false)
		expect(Turns.allowed("storehouse", "M")).toEqual({ 0 })
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		expect(Turns.allowed("storehouse", "M")).toEqual({ 0, 1, 2, 3 }) -- 22×18 fits 36×30 both ways
		expect(Turns.allowed("barracks", "M")).toEqual({ 0, 2 }) -- 34×22 turned is 22×34: deeper than 30
		expect(Turns.allowed("house", "S")).toEqual({ 0, 2 }) -- 22×18 turned is 18×22: deeper than 20
		expect(Turns.allowed("farm", "L")).toEqual({ 0, 1, 2, 3 }) -- 40×32 in 46×40
		expect(Turns.next({ 0, 2 }, 0)).toBe(2)
		expect(Turns.next({ 0, 2 }, 2)).toBe(0)
		expect(Turns.next({ 0, 1, 2, 3 }, 3)).toBe(0)
		expect(Turns.label(0)).toBe("Faces the street")
		expect(Turns.label(1)).toBe("Faces right")
		expect(Turns.label(2)).toBe("Faces away")
		expect(Turns.label(3)).toBe("Faces left")
		Turns.useSeam(nil)
	end)
end)

describe("Ghost facing marks", function()
	it("puts the door on the front edge and the arrow out in front, turning with the building", function()
		local env = MockEnv.new({})
		local ghost = Ghost.new(env)
		local size = Vector2.new(22, 18)
		for rot = 0, 3 do
			local cf = Placement.cframe(Vector3.new(10, 0, 20), rot)
			ghost:show(size, cf, nil)
			local front = cf.LookVector -- Kit models face -Z
			local centre = cf.Position
			-- the door strip sits just inside the front edge
			local door = ghost.door.CFrame.Position - centre
			expect(door:Dot(front)).toBeNear(size.Y / 2 - 0.5, 1e-4)
			-- the arrow's shaft and its chevron lie beyond the front edge, on the centre line
			local shaft = ghost.arrow.CFrame.Position - centre
			expect(shaft:Dot(front)).toBeGreaterThan(size.Y / 2)
			expect(math.abs(shaft:Dot(cf.RightVector))).toBeLessThan(1e-4)
			local length = Ghost.arrowLength(size)
			local tip = centre + front * (size.Y / 2 + Ghost.ARROW_GAP + length)
			for _, bar in { ghost.arrowLeft, ghost.arrowRight } do
				local cfBar = bar.CFrame
				local ends = {
					cfBar.Position + cfBar.LookVector * bar.Size.Z / 2,
					cfBar.Position - cfBar.LookVector * bar.Size.Z / 2,
				}
				local reaches = near(Vector3.new(ends[1].X, 0, ends[1].Z), Vector3.new(tip.X, 0, tip.Z))
					or near(Vector3.new(ends[2].X, 0, ends[2].Z), Vector3.new(tip.X, 0, tip.Z))
				expect(reaches).toBe(true) -- both bars meet at the tip
			end
			-- one bar on each side of the centre line
			local left = (ghost.arrowLeft.CFrame.Position - centre):Dot(cf.RightVector)
			local right = (ghost.arrowRight.CFrame.Position - centre):Dot(cf.RightVector)
			expect(left).toBeLessThan(0)
			expect(right).toBeGreaterThan(0)
		end
		-- the marks are cream whatever the verdict, visible while shown and gone when hidden
		ghost:tint("bad")
		for _, mark in { ghost.door, ghost.arrow, ghost.arrowLeft, ghost.arrowRight } do
			expect(mark.Color).toBe(Ghost.MARK)
			expect(mark.Transparency).toBeLessThan(0.5)
			expect(mark.CanQuery).toBe(false)
			expect(mark.CanCollide).toBe(false)
		end
		ghost:hide()
		for _, mark in { ghost.door, ghost.arrow, ghost.arrowLeft, ghost.arrowRight } do
			expect(mark.Transparency).toBe(1)
		end
		ghost:destroy()
	end)
end)

describe("Turning a building while placing it", function()
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

	it("labels Turn on desktop, shows the facing on its dial and turns back with Shift+R", function()
		world = newWorld()
		local build, hud = world.build, world.hud
		build:startPlacement("farm")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.2)
		local bar = find(hud.guis.hud, "PlacementBar")
		local turn = find(bar, "Rotate")
		expect(texts(turn)).toContain("Turn")
		local dial = find(turn, "Facing")
		expect(dial:GetAttribute("facing")).toBe(build:facing(0))
		tap(turn)
		world:advance(0.2)
		expect(build.placing.rot).toBe(1)
		expect(find(find(hud.guis.hud, "PlacementBar"), "Facing"):GetAttribute("facing")).toBe(build:facing(1))
		expect((build:facing(0) - build:facing(1)) % 360).toBe(90) -- a quarter counter-clockwise on screen
		expect(find(find(hud.guis.hud, "PlacementBar"), "Arrow").Rotation).toBe(build:facing(1))
		-- the ghost's arrow turned with it
		expect(near(build.ghost.base.CFrame.LookVector, Placement.cframe(Vector3.zero, 1).LookVector)).toBe(true)
		-- Shift+R (PlacementInput's rotate(-1)) turns back past 0 to 3
		build:rotate(-1)
		expect(build.placing.rot).toBe(0)
		build:rotate(-1)
		world:advance(0.2)
		expect(build.placing.rot).toBe(3)
		local checks = world:callsNamed("CanPlace")
		expect(checks[#checks].args[3]).toBe(3)
		expect(texts(bar)).toContain("Shift+R")
	end)

	it("keeps Turn and its dial on a phone, without the word, inside the bar", function()
		world = newWorld({ width = 750, height = 311 })
		local build, hud = world.build, world.hud
		build:startPlacement("lumbercamp")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.2)
		local bar = find(hud.guis.hud, "PlacementBar")
		local turn = find(bar, "Rotate")
		expect(turn).toBeTruthy()
		expect(find(turn, "Facing")).toBeTruthy()
		expect(find(turn, "Label")).toBeNil()
		expect(turn.Size.Y.Offset).toBeGreaterThan(43) -- a touch target
		expect(bar.Size.X.Offset).toBeLessThan(751)
	end)
end)

describe("Turning a building on its plot (v0.4-g9h)", function()
	local previous, world
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Turns.useSeam(nil)
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("shows no Turn and keeps PlaceSlot's two arguments while the server takes no turn", function()
		world = newWorld()
		world.picker:open("m1")
		world.picker:select("lumbercamp")
		world:advance(0.1)
		local detail = find(world.hud.guis.menus, "Detail")
		expect(detail).toBeTruthy()
		expect(find(detail, "FacingRow")).toBeNil()
		world.picker:turn() -- nothing to turn
		expect(world.picker.state.turn).toBe(0)
		tap(find(detail, "Cta"))
		world:advance(0.2)
		local calls = world:callsNamed("PlaceSlot")
		expect(#calls).toBe(1)
		expect(calls[1].args[3]).toBeNil()
	end)

	it("turns a storehouse through every quarter, previews it on the plot and builds it turned", function()
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		world = newWorld({ turns = true })
		local picker, hud = world.picker, world.hud
		picker:open("crimson_slot5")
		picker:select("storehouse")
		world:advance(0.1)
		local row = find(hud.guis.menus, "FacingRow")
		expect(row).toBeTruthy()
		expect(texts(row)).toContain("Faces the street")
		expect(row:GetAttribute("turn")).toBe(0)
		-- the ghost stands on the plot, facing the street, inside the plot's outline
		local frame = PlotPickerDef.slotFrame("crimson_slot5")
		expect(frame).toBeTruthy()
		local layoutSlot
		for _, s in WorldLayout.plots.crimson.buildSlots do
			if s.id == "crimson_slot5" then
				layoutSlot = s
			end
		end
		expect(near(frame.center, layoutSlot.center)).toBe(true)
		local ghost = picker.ghost
		expect(ghost).toBeTruthy()
		expect(near(ghost.base.CFrame.Position * Vector3.new(1, 0, 1), frame.center * Vector3.new(1, 0, 1))).toBe(true)
		expect(near(ghost.base.CFrame.LookVector, CFrame.Angles(0, frame.yaw, 0).LookVector)).toBe(true)
		expect(ghost.room.Size.X).toBeNear(frame.size.X, 1e-4)
		expect(ghost.room.Size.Z).toBeNear(frame.size.Y, 1e-4)
		local facing0 = find(row, "Facing"):GetAttribute("facing")

		tap(find(row, "Turn"))
		world:advance(0.1)
		row = find(hud.guis.menus, "FacingRow")
		expect(texts(row)).toContain("Faces right")
		expect(row:GetAttribute("turn")).toBe(1)
		expect((facing0 - find(row, "Facing"):GetAttribute("facing")) % 360).toBe(90)
		local turned = CFrame.Angles(0, frame.yaw + math.pi / 2, 0).LookVector
		expect(near(picker.ghost.base.CFrame.LookVector, turned)).toBe(true)
		-- the outline is the plot: it stays put while the building turns inside it
		local roomCf = picker.ghost.room.CFrame
		local alongSlotX = math.abs(roomCf.RightVector:Dot(CFrame.Angles(0, frame.yaw, 0).RightVector))
		local roomWidthOnSlotX = if alongSlotX > 0.5 then picker.ghost.room.Size.X else picker.ghost.room.Size.Z
		expect(roomWidthOnSlotX).toBeNear(frame.size.X, 1e-4)

		picker:turn()
		picker:turn()
		world:advance(0.1)
		expect(texts(find(hud.guis.menus, "FacingRow"))).toContain("Faces left")
		picker:turn()
		world:advance(0.1)
		expect(texts(find(hud.guis.menus, "FacingRow"))).toContain("Faces the street")
		picker:turn()
		world:advance(0.1)

		tap(find(find(hud.guis.menus, "Detail"), "Cta"))
		world:advance(0.2)
		local calls = world:callsNamed("PlaceSlot")
		expect(#calls).toBe(1)
		expect(calls[1].args[1]).toBe("crimson_slot5")
		expect(calls[1].args[2]).toBe("storehouse")
		expect(calls[1].args[3]).toBe(1)
		expect(texts(hud.guis.notices)).toContain("Storehouse ordered")
		-- the plot closed: no drawer, no ghost
		expect(hud.state.menu).toBeNil()
		expect(picker.ghost).toBeNil()
	end)

	it("offers only the turns that fit: a barracks on a medium plot faces the street or away", function()
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		world = newWorld({ turns = true })
		local picker, hud = world.picker, world.hud
		picker:open("crimson_slot5")
		picker:select("barracks")
		world:advance(0.1)
		expect(texts(find(hud.guis.menus, "FacingRow"))).toContain("Turn to change it")
		picker:turn()
		world:advance(0.1)
		expect(texts(find(hud.guis.menus, "FacingRow"))).toContain("Faces away")
		picker:turn()
		world:advance(0.1)
		expect(texts(find(hud.guis.menus, "FacingRow"))).toContain("Faces the street")
		-- another type starts facing the street again; a turn that would not fit is never kept
		picker.state.turn = 1
		picker:select("storehouse") -- 1 would fit a storehouse: a new type still starts at the street
		world:advance(0.1)
		expect(picker.state.turn).toBe(0)
		picker:select("barracks")
		world:advance(0.1)
		picker.state.turn = 3
		hud:render()
		expect(picker.state.turn).toBe(0) -- 3 does not fit a barracks here: back to a turn that does
	end)

	it("disables Turn with a reason when only one way fits, and the server refuses a misfit", function()
		Turns.useSeam({
			supported = true,
			fits = function(_, _, turn)
				return turn == 0
			end,
		})
		world = newWorld({ turns = true, treasury = { food = 900, wood = 900, stone = 900, gold = 900 } })
		local picker, hud = world.picker, world.hud
		picker:open("crimson_slot5")
		picker:select("storehouse")
		world:advance(0.1)
		local row = find(hud.guis.menus, "FacingRow")
		expect(texts(row)).toContain("Only this way fits")
		Create.fire(find(find(row, "Turn"), "Face"), "Activated") -- disabled: the tap does nothing
		world:advance(0.1)
		expect(picker.state.turn).toBe(0)
		picker:turn()
		world:advance(0.1)
		expect(picker.state.turn).toBe(0)
		-- the double's server applies the real rule: a barracks turned a quarter does not fit M
		Turns.useSeam({
			supported = true,
			fits = function()
				return true
			end,
		})
		picker:select("barracks")
		world:advance(0.1)
		picker:turn()
		world:advance(0.1)
		expect(picker.state.turn).toBe(1)
		tap(find(find(hud.guis.menus, "Detail"), "Cta"))
		world:advance(0.2)
		expect(texts(hud.guis.notices)).toContain("Couldn't build here")
		expect(hud.state.menu).toBe("plot") -- the picker stays for another try
	end)

	it("puts Turn beside the build button on a phone, with the facing as a chip", function()
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		world = newWorld({ turns = true, width = 750, height = 311 })
		local picker, hud = world.picker, world.hud
		picker:open("crimson_slot5")
		picker:select("storehouse")
		world:advance(0.1)
		local detail = find(hud.guis.menus, "Detail")
		expect(find(detail, "FacingRow")).toBeNil()
		expect(texts(find(detail, "FacingLabel"))).toContain("Faces the street")
		local turn = detail:FindFirstChild("Turn")
		local cta = detail:FindFirstChild("Cta")
		expect(turn.Size.Y.Offset).toBe(44)
		-- side by side at the bottom: Turn on the left, the CTA filling the rest
		expect(turn.Position.Y.Scale).toBe(1)
		expect(cta.Position.X.Offset).toBe(turn.Size.X.Offset + 8)
		tap(turn)
		world:advance(0.1)
		detail = find(hud.guis.menus, "Detail")
		expect(texts(find(detail, "FacingLabel"))).toContain("Faces right")
		expect(detail:FindFirstChild("Turn"):GetAttribute("turn")).toBe(1)
	end)

	it("keeps the turn the order went out with while it is on its way", function()
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		world = newWorld({ turns = true, latency = 0.3 })
		local picker, hud = world.picker, world.hud
		picker:open("crimson_slot5")
		picker:select("storehouse")
		world:advance(0.1)
		picker:turn()
		world:advance(0.1)
		tap(find(find(hud.guis.menus, "Detail"), "Cta"))
		world:advance(0.05)
		picker:turn() -- ignored: the order is out
		expect(picker.state.turn).toBe(1)
		world:advance(0.5)
		expect(world:callsNamed("PlaceSlot")[1].args[3]).toBe(1)
	end)

	it("removes the plot ghost when the picker closes", function()
		Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
		world = newWorld({ turns = true })
		world.picker:open("crimson_slot5")
		world:advance(0.1)
		expect(world.picker.ghost).toBeTruthy()
		local folder = world.picker.ghost.folder
		world.picker:close()
		world:advance(0.1)
		expect(world.picker.ghost).toBeNil()
		expect(folder.Parent).toBeNil()
	end)
end)

return T
