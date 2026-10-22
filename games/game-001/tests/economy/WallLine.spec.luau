-- FL-0129c: the wall line (FORGE-01's Build.PlaceLine, FL-0126 part 2 slice 1; handoff
-- 2026-10-22-forge-01-to-all-place-line): UI/WallLine's pieces, and the build menu's two-ends mode against the real
-- KingdomHudController and BuildMenuController over RemoteService, with doubles/LineDoubles (written from the handoff).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local LineDoubles = require("./doubles/LineDoubles")
local Text = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Text")
local WallLine = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/WallLine")

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

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

local function newWorld(opts)
	local o = opts or {}
	if not o.noLine then
		o.remotes = LineDoubles.REMOTES
		o.services = { LineDoubles.service }
	end
	o.clientDefinitions = { KingdomHudDef, BuildMenuDef }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.build = world.client:get("BuildMenuController")
	world.line = if o.noLine then nil else world.server:get("LineDouble")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function ghostFolders(world): number
	local n = 0
	for _, child in world.env.Workspace:GetChildren() do
		if child.Name == "BuildGhost" then
			n += 1
		end
	end
	return n
end

local function bar(world)
	return find(world.hud.guis.hud, "PlacementBar")
end

-- start a line at `from` (checked like any spot), then aim the far end at `to`
local function draw(world, from: Vector3, to: Vector3)
	world.build:startPlacement("wall")
	world.build:aimAt(from)
	world:advance(0.5) -- Build.CanPlace answers
	world.build:confirm() -- Set start
	world.build:aimAt(to)
	world:advance(0.1)
end

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

describe("UI/WallLine: the server's pieces (Simulation:placeLine)", function()
	it(
		"snaps both ends to the grid and lays round(length / 32) pieces from the start, facing along the line",
		function()
			local plan = WallLine.plan(Vector3.new(1, 5, 1), Vector3.new(97, 0, 2))
			expect(plan.from).toEqual(Vector3.new(0, 5, 0)) -- y is the start's
			expect(plan.to).toEqual(Vector3.new(96, 5, 4))
			expect(plan.count).toBe(3)
			expect(plan.reason).toBeNil()
			expect(#plan.pieces).toBe(3)
			local along = WallLine.plan(Vector3.new(0, 0, 0), Vector3.new(64, 0, 0))
			expect(along.pieces[1].position).toEqual(Vector3.new(16, 0, 0))
			expect(along.pieces[2].position).toEqual(Vector3.new(48, 0, 0))
			expect(near(along.yaw, 0)).toBe(true)
			-- +Z: yaw = atan2(-1, 0); the long side runs (cos yaw, -sin yaw) = (0, 1) in x, z
			local south = WallLine.plan(Vector3.new(0, 0, 0), Vector3.new(0, 0, 64))
			expect(near(south.yaw, -math.pi / 2)).toBe(true)
			local look = south.pieces[1].cframe.RightVector
			expect(near(look.X, 0) and near(look.Z, 1)).toBe(true)
		end
	)

	it("rounds to whole pieces and keeps at least one; too short and too long are the server's reasons", function()
		expect(WallLine.plan(Vector3.zero, Vector3.new(15, 0, 0)).count).toBe(1) -- 16 studs: one piece
		expect(WallLine.plan(Vector3.zero, Vector3.new(48, 0, 0)).count).toBe(2) -- 1.5 rounds up
		expect(WallLine.plan(Vector3.zero, Vector3.new(44, 0, 0)).count).toBe(1)
		local short = WallLine.plan(Vector3.new(1, 0, 1), Vector3.new(-1, 0, -1))
		expect(short.reason).toBe("too_short")
		expect(#short.pieces).toBe(0)
		local max = BuildingsConfig.maxLineSegments
		expect(WallLine.plan(Vector3.zero, Vector3.new(32 * max, 0, 0)).reason).toBeNil()
		local long = WallLine.plan(Vector3.zero, Vector3.new(32 * (max + 1), 0, 0))
		expect(long.reason).toBe("too_long")
		expect(#long.pieces).toBe(0)
	end)

	it("prices a line at its level-1 price per piece", function()
		expect(WallLine.cost({ stone = 20, gold = 1 }, 3)).toEqual({ stone = 60, gold = 3 })
	end)

	it("words every Build.PlaceLine reason, the line's own way for one piece's refusal", function()
		for _, reason in { "not_a_line_piece", "too_short", "too_long" } do
			expect(Text.reason(reason)).never.toBe("That didn't work. Try again.")
		end
		expect(Text.reason("too_long")).toContain(tostring(BuildingsConfig.maxLineSegments))
		expect(Text.reason("blocked", "line")).toBe("No room for part of it")
		expect(Text.reason("cannot_afford", "line")).toBe("Not enough for the whole wall")
		expect(Text.reason("not_owner", "line")).toBe(Text.reason("not_owner")) -- the rest as Build.Place says them
	end)
end)

describe("Build menu: the wall line (FL-0129c)", function()
	it("sets the start, previews the pieces with the total, and sends both ends in one call", function()
		world = newWorld()
		local b = world.build
		b:startPlacement("wall")
		expect(b.placing.line).never.toBeNil()
		expect(find(bar(world), "Rotate")).toBeNil() -- a line faces along itself: no Turn
		expect(find(bar(world), "BuildingName").Text).toBe("Wall line: the start")
		b:aimAt(Vector3.new(60, 0, 0))
		world:advance(0.5)
		expect(b.placing.status).toBe("ok") -- the start is checked like any spot (Build.CanPlace)
		expect(find(find(bar(world), "Place"), "Label").Text).toBe("Set start")
		b:confirm()
		expect(b.placing.line.from).toEqual(Vector3.new(60, 0, 0))
		expect(b.placing.status).toBe("bad") -- the far end starts on the start: too short until it moves
		expect(b.placing.reason).toBe(Text.reason("too_short", "line"))
		b:aimAt(Vector3.new(60, 0, 64)) -- two pieces: the starting treasury pays for two
		world:advance(0.1)
		expect(b.placing.status).toBe("ok")
		expect(#b.placing.line.plan.pieces).toBe(2)
		expect(ghostFolders(world)).toBe(2) -- one ghost per piece
		expect(find(bar(world), "BuildingName").Text).toBe("Wall line · 2 pieces")
		expect(find(find(bar(world), "Place"), "Label").Text).toBe("Build wall")
		local per = Costs.building("wall", 1).cost
		for currency, amount in per do
			local chip = find(bar(world), "Chip_" .. currency)
			expect(find(chip, "Amount").Text).toBe(tostring(amount * 2))
		end
		tap(find(bar(world), "Place"))
		world:advance(0.2)
		expect(#world.line.calls).toBe(1)
		local call = world.line.calls[1]
		expect(call.kind).toBe("wall")
		expect(call.from).toEqual(Vector3.new(60, 0, 0))
		expect(call.to).toEqual(Vector3.new(60, 0, 64))
		expect(b.placing).toBeNil() -- placed: build mode ends
		expect(ghostFolders(world)).toBe(0)
		local walls = 0
		for _, row in world.hud.store:myBuildings() do
			if row.type == "wall" then
				walls += 1
			end
		end
		expect(walls).toBe(2)
	end)

	it("says what the client knows before Build wall: too long, and the whole line's price", function()
		world = newWorld()
		local b = world.build
		draw(world, Vector3.new(60, 0, 0), Vector3.new(60, 0, 60 + 32 * (BuildingsConfig.maxLineSegments + 1)))
		expect(b.placing.status).toBe("bad")
		expect(b.placing.reason).toBe(Text.reason("too_long", "line"))
		b:confirm()
		world:advance(0.2)
		expect(#world.line.calls).toBe(0) -- nothing is sent for a line the server would refuse
		-- a line the treasury cannot pay for in full: bad, the short costs red, nothing sent
		b:aimAt(Vector3.new(60, 0, 32 * (BuildingsConfig.maxLineSegments - 1))) -- 11 pieces
		world:advance(0.1)
		local per = Costs.building("wall", 1).cost
		local count = b.placing.line.plan.count
		local have = world.hud.store:balances()
		local short = false
		for currency, amount in per do
			if (have[currency] or 0) < amount * count then
				short = true
			end
		end
		expect(short).toBe(true) -- the starting treasury does not pay for 11 pieces
		expect(b.placing.status).toBe("bad")
		expect(b.placing.reason).toBe(Text.reason("cannot_afford", "line"))
		b:confirm()
		world:advance(0.2)
		expect(#world.line.calls).toBe(0)
	end)

	it("keeps the line open with the server's reason when it refuses, and Turn does nothing", function()
		world = newWorld()
		local b = world.build
		draw(world, Vector3.new(60, 0, 0), Vector3.new(60, 0, 64))
		expect(b.placing.status).toBe("ok")
		world.line.answer = { nil, "blocked" }
		b:rotate(1)
		expect(b.placing.rot).toBe(0)
		b:confirm()
		world:advance(0.2)
		expect(#world.line.calls).toBe(1)
		expect(b.placing).never.toBeNil()
		expect(b.placing.status).toBe("bad")
		expect(b.placing.reason).toBe("No room for part of it")
		expect(find(bar(world), "Status").Text).toContain("No room for part of it")
		world.line.answer = { {}, nil } -- an empty list builds nothing: not a success
		b:aimAt(Vector3.new(60, 0, 56))
		world:advance(0.1)
		b:confirm()
		world:advance(0.2)
		expect(b.placing).never.toBeNil()
		expect(b.placing.status).toBe("bad")
		world.line.answer = "drop"
		b:aimAt(Vector3.new(60, 0, 48)) -- a new far end (still two pieces) clears the refusal
		world:advance(0.1)
		expect(b.placing.status).toBe("ok")
		b:confirm()
		world:advance(0.2)
		expect(b.placing.reason).toBe(Text.reason(nil)) -- no answer: never "the server is down"
		b:cancel()
		expect(b.placing).toBeNil()
		expect(ghostFolders(world)).toBe(0) -- every piece's ghost goes
	end)

	it("places one wall as before when the server does not serve Build.PlaceLine", function()
		world = newWorld({ noLine = true })
		local b = world.build
		b:startPlacement("wall")
		expect(b.placing.line).toBeNil()
		expect(find(bar(world), "Rotate")).never.toBeNil()
		expect(find(bar(world), "BuildingName").Text).toBe(b.placing.name)
	end)

	it("only walls are drawn: other buildings keep the one-spot placement", function()
		world = newWorld()
		world.build:startPlacement("house")
		expect(world.build.placing.line).toBeNil()
	end)

	it("fits the phone bar (667 × 375) with the line's words and no Turn", function()
		world = newWorld({ width = 667, height = 375 })
		draw(world, Vector3.new(60, 0, 0), Vector3.new(60, 0, 64))
		local root = bar(world)
		expect(root).never.toBeNil()
		expect(find(root, "Rotate")).toBeNil()
		expect(find(root, "Hint")).toBeNil() -- phones get no key hint
		expect(find(find(root, "Place"), "Label").Text).toBe("Build wall")
	end)
end)
