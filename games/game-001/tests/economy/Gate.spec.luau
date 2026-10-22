-- FL-0129c slice 2: the gate (FORGE-01's Build.PlaceGate, FL-0126 part 2 slice 2, #306; handoff
-- 2026-10-22-forge-01-to-all-place-line "Slice 2"): UI/GatePick, and the build menu's pick-a-wall mode against the real
-- KingdomHudController and BuildMenuController over RemoteService, with doubles/GateDoubles (written from the handoff).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local BuildModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/BuildModel")
local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local GateDoubles = require("./doubles/GateDoubles")
local GatePick = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/GatePick")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Text = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Text")

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function row(id, buildingType, x, z, yaw, state)
	return {
		id = id,
		type = buildingType,
		state = state or "complete",
		cframe = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0),
	}
end

local function newWorld(opts)
	local o = opts or {}
	if not o.noGate then
		o.remotes = GateDoubles.REMOTES
		o.services = { GateDoubles.service }
	end
	o.clientDefinitions = { KingdomHudDef, BuildMenuDef }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.menu = world.client:get("BuildMenuController")
	world.gate = if o.noGate then nil else world.server:get("GateDouble")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function bar(world)
	return find(world.hud.guis.hud, "PlacementBar")
end

local function amountOf(world, currency)
	local chip = find(bar(world), "Chip_" .. currency)
	return chip and find(chip, "Amount").Text
end

local function mine(world, buildingType)
	local n = 0
	for _, b in world.hud.store:myBuildings() do
		if b.type == buildingType and b.state ~= "destroyed" then
			n += 1
		end
	end
	return n
end

local NET = GatePick.cost(Costs.building("gate", 1).cost, Costs.building("wall", 1).cost, BuildingsConfig.cancelRefund)

local world, previous = nil, nil
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

describe("UI/GatePick: which wall piece, and the price less the refund", function()
	it("picks the piece the aim is on along a turned wall, the nearest of two, never a gone or unplaced one", function()
		local yaw = math.rad(30)
		local ux, uz = math.cos(yaw), -math.sin(yaw) -- the piece's local X in the world (CFrame.Angles(0, yaw, 0))
		local rows = { row(1, "wall", 0, 0, yaw), row(2, "wall", 32 * ux, 32 * uz, yaw) }
		expect(GatePick.wallAt(rows, Vector3.new(14 * ux, 0, 14 * uz)).id).toBe(1) -- along the piece, near its end
		expect(GatePick.wallAt(rows, Vector3.new(18 * ux, 0, 18 * uz)).id).toBe(2) -- past the joint: the next piece
		-- 4 studs half-width + 2 margin: 5.9 off the line picks, 6.1 does not (perpendicular: (-uz, ux) in x, z)
		expect(GatePick.wallAt(rows, Vector3.new(-5.9 * uz, 0, 5.9 * ux))).never.toBeNil()
		expect(GatePick.wallAt(rows, Vector3.new(-6.1 * uz, 0, 6.1 * ux))).toBeNil()
		expect(GatePick.wallAt(rows, Vector3.new(19 * ux, 0, 19 * uz), Vector2.new(32, 8), 0).id).toBe(2)
		local gone = { row(1, "wall", 0, 0, 0, "destroyed"), { id = 3, type = "wall", state = "complete" } }
		expect(GatePick.wallAt(gone, Vector3.zero)).toBeNil()
		expect(GatePick.wallAt({ row(4, "house", 0, 0, 0) }, Vector3.zero)).toBeNil()
		expect(GatePick.gates({ row(1, "gate", 0, 0), row(2, "gate", 9, 9, 0, "destroyed"), row(3, "wall", 0, 0) })).toBe(
			1
		)
	end)

	it("splits the price as the server does: half the wall back, floored, counted towards the gate", function()
		local split = GatePick.cost({ wood = 40, stone = 30 }, { stone = 21 }, 0.5)
		expect(split.refund).toEqual({ stone = 10 })
		expect(split.net).toEqual({ wood = 40, stone = 20 })
		expect(GatePick.cost({ stone = 5 }, { stone = 20 }, 0.5).net).toEqual({ stone = 0 }) -- never below zero
	end)

	it("words every Build.PlaceGate reason the gate's way, short enough for the phone bar", function()
		for _, code in
			{
				"not_found",
				"not_owner",
				"not_a_wall",
				"limit_reached",
				"busy",
				"blocked",
				"out_of_territory",
				"out_of_bounds",
				"cannot_afford",
			}
		do
			local text = Text.reason(code, "gate")
			expect(text).never.toBe(Text.reason(code))
			expect(#text <= 34).toBe(true)
		end
		expect(Text.reason("under_attack", "gate")).toBe(Text.reason("under_attack"))
		expect(Text.reason("not_a_wall")).never.toBe("That didn't work. Try again.")
	end)
end)

describe("Build menu: the gate (FL-0129c slice 2)", function()
	it("picks a wall piece, previews the gate there at the price less the refund, and sends the piece's id", function()
		world = newWorld()
		local m = world.menu
		local yaw = math.rad(30)
		local wallId = GateDoubles.wall(world, Vector3.new(60, 0, 0), yaw)
		world:advance(0.1)
		m:startPlacement("gate")
		expect(m.placing.gate).never.toBeNil()
		expect(find(bar(world), "Rotate")).toBeNil() -- the gate faces as its wall piece: no Turn
		expect(find(bar(world), "BuildingName").Text).toBe("Gate: pick a wall piece")
		expect(find(bar(world), "Hint").Text).toBe(
			"Point at one of your wall pieces · Click makes it the gate · Q cancels"
		)
		local asked = #world:callsNamed("Build.CanPlace")
		m:aimAt(Vector3.new(0, 0, 0)) -- open ground
		expect(m.placing.status).toBe("bad")
		expect(m.placing.reason).toBe(Text.reason("not_a_wall", "gate"))
		m:confirm()
		world:advance(0.2)
		expect(#world.gate.calls).toBe(0)
		m:aimAt(Vector3.new(66, 0, -3)) -- on the piece, off its centre
		expect(m.placing.status).toBe("ok")
		expect(m.placing.gate.wall.id).toBe(wallId)
		expect(#world:callsNamed("Build.CanPlace")).toBe(asked) -- the gate's ground is the server's call
		expect(find(bar(world), "BuildingName").Text).toBe("Gate here")
		expect(find(find(bar(world), "Place"), "Label").Text).toBe("Make gate")
		for currency, amount in NET.net do
			expect(amountOf(world, currency)).toBe(tostring(amount))
		end
		expect(m.ghost.visible).toBe(true)
		m:aimAt(Vector3.new(0, 0, 0)) -- off the wall again: no gate ghost, and Make gate is off
		expect(m.ghost.visible).toBe(false)
		expect(m.placing.status).toBe("bad")
		m:aimAt(Vector3.new(66, 0, -3))
		expect(m.ghost.visible).toBe(true)
		local before = world.hud.store:balances()
		tap(find(bar(world), "Place"))
		world:advance(0.2)
		expect(world.gate.calls).toEqual({ wallId })
		expect(m.placing).toBeNil() -- placed: build mode ends
		expect(mine(world, "gate")).toBe(1)
		expect(mine(world, "wall")).toBe(0)
		local after = world.hud.store:balances()
		for currency, amount in NET.net do
			expect(after[currency]).toBe(before[currency] - amount)
		end
	end)

	it("puts the gate where the wall stood, facing as it did", function()
		world = newWorld()
		local yaw = math.rad(30)
		local wallId = GateDoubles.wall(world, Vector3.new(60, 0, 0), yaw)
		world:advance(0.1)
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		local wall = world.hud.store:building(wallId).cframe
		local base = m.ghost.base.CFrame
		expect((base.Position - wall.Position) * Vector3.new(1, 0, 1)).toEqual(Vector3.zero)
		expect(base.LookVector:Dot(wall.LookVector) > 0.9999).toBe(true)
		expect(m.ghost.base.Size.X).toBe(BuildModel.footprint("gate", 1).X) -- the gate's own size, not the wall's
		expect(m.ghost.base.Size.Z).toBe(BuildModel.footprint("gate", 1).Y)
	end)

	it("lets a treasury that holds the price less the refund make the gate, and not one stud less", function()
		local full = Costs.building("gate", 1).cost
		world = newWorld({ treasury = NET.net })
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		world:advance(0.1)
		local detail = BuildModel.menu(
			world.hud.store,
			{ category = "military", selected = "gate", prices = world.menu:_gatePrices() }
		).detail
		expect(detail.type).toBe("gate")
		local view = BuildModel.menu(
			world.hud.store,
			{ category = "military", selected = "gate", prices = world.menu:_gatePrices() }
		)
		for _, r in view.rows do
			if r.id == "gate" then
				expect(r.ok).toBe(true) -- the list row reads the same net price
				for _, c in r.costs do
					expect(c.amount).toBe(NET.net[c.currency])
				end
			end
		end
		expect(detail.cta.state).toBe("ready") -- the full price is not held, the net is
		for currency, amount in full do
			if amount > (NET.net[currency] or 0) then
				expect((world.hud.store:balances()[currency] or 0) < amount).toBe(true)
			end
		end
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		expect(m.placing.status).toBe("ok")
		tap(find(bar(world), "Place"))
		world:advance(0.2)
		expect(#world.gate.calls).toBe(1)
		expect(m.placing).toBeNil()
	end)

	it("says what the client knows before Make gate: one gate per kingdom", function()
		world = newWorld()
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		GateDoubles.wall(world, Vector3.new(60, 0, 64), 0)
		world:advance(0.1)
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		tap(find(bar(world), "Place"))
		world:advance(0.2)
		expect(mine(world, "gate")).toBe(1)
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 64))
		expect(m.placing.status).toBe("bad")
		expect(m.placing.reason).toBe(Text.reason("limit_reached", "gate"))
		m:confirm()
		world:advance(0.2)
		expect(#world.gate.calls).toBe(1) -- nothing sent for the second
	end)

	it("turns bad when the treasury drops below the net price while the gate is being placed", function()
		world = newWorld({ treasury = NET.net })
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		GateDoubles.wall(world, Vector3.new(60, 0, 64), 0)
		world:advance(0.1)
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		expect(m.placing.status).toBe("ok")
		world.treasury:spend(world.kingdomId, { wood = 1 }, "spec:spend", "spec")
		world:advance(0.1)
		m:aimAt(Vector3.new(60, 0, 64)) -- the next piece: checked again against the treasury now
		expect(m.placing.status).toBe("bad")
		expect(m.placing.reason).toBe(Text.reason("cannot_afford", "gate"))
		m:confirm()
		world:advance(0.2)
		expect(#world.gate.calls).toBe(0)
	end)

	it("keeps Place off in the menu for a treasury one short of the price less the refund", function()
		local short = table.clone(NET.net)
		short.wood -= 1
		world = newWorld({ treasury = short })
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		world:advance(0.1)
		local detail = BuildModel.menu(
			world.hud.store,
			{ category = "military", selected = "gate", prices = world.menu:_gatePrices() }
		).detail
		expect(detail.cta.state).toBe("disabled")
		world.menu:startPlacement("gate")
		expect(world.menu.placing).toBeNil()
	end)

	it("keeps the gate mode open with the server's reason when it refuses, and Turn does nothing", function()
		world = newWorld()
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		world:advance(0.1)
		world.gate.answer = { nil, "blocked" }
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		m:rotate(1)
		expect(m.placing.rot).toBe(0)
		tap(find(bar(world), "Place"))
		world:advance(0.2)
		expect(#world.gate.calls).toBe(1)
		expect(m.placing).never.toBeNil()
		expect(m.placing.status).toBe("bad")
		expect(m.placing.reason).toBe(Text.reason("blocked", "gate"))
		world.gate.answer = "drop"
		m.placing.status = "ok"
		m:confirm()
		world:advance(0.2)
		expect(m.placing).never.toBeNil() -- no answer: still open, never "placed"
		expect(m.placing.reason).toBe(Text.reason(nil, "gate"))
		m:cancel()
		expect(m.placing).toBeNil()
		expect(m.ghost).toBeNil()
	end)

	it("places a gate as one spot, at the full price, when the server does not serve Build.PlaceGate", function()
		world = newWorld({ noGate = true })
		local m = world.menu
		m:startPlacement("gate")
		expect(m.placing).never.toBeNil()
		expect(m.placing.gate).toBeNil()
		local full = Costs.building("gate", 1).cost
		for currency, amount in full do
			expect(amountOf(world, currency)).toBe(tostring(amount))
		end
	end)

	it("fits the phone bar (667 × 375) with the gate's words and no Turn", function()
		world = newWorld({ width = 667, height = 375 })
		GateDoubles.wall(world, Vector3.new(60, 0, 0), 0)
		world:advance(0.1)
		local m = world.menu
		m:startPlacement("gate")
		m:aimAt(Vector3.new(60, 0, 0))
		local root = bar(world)
		expect(find(root, "Rotate")).toBeNil()
		expect(find(root, "Hint")).toBeNil() -- phones get no key hint
		expect(find(find(root, "Place"), "Label").Text).toBe("Make gate")
	end)
end)
