local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local CrowdDirector = require("@game/ReplicatedStorage/Game/Feedback/CrowdDirector")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local FiguresDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CrowdFiguresController")

local function pivotOf(model): CFrame
	local primary = model.PrimaryPart
	return primary.CFrame * primary.PivotOffset
end

local function near(a: Vector3, b: Vector3, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

local function director(tierA, kingdomA, tierB, kingdomB)
	return CrowdDirector.new(Crowd, {
		a = { tier = tierA, kingdom = kingdomA },
		b = { tier = tierB, kingdom = kingdomB },
	})
end

describe("CrowdFiguresController pure helpers (FL-0074 part 2c)", function()
	it("seats fill the front row first, each row from its centre out; FORGE-02's variant formula", function()
		local order = FiguresDef.order()
		expect(#order).toBe(72)
		expect(order[1]).toEqual({ row = 1, seat = 9 })
		expect(order[2]).toEqual({ row = 1, seat = 10 })
		expect(order[3]).toEqual({ row = 1, seat = 8 })
		expect(order[17]).toEqual({ row = 1, seat = 1 })
		expect(order[18]).toEqual({ row = 1, seat = 18 })
		expect(order[19]).toEqual({ row = 2, seat = 9 })
		expect(order[72]).toEqual({ row = 4, seat = 18 })
		expect(FiguresDef.variant(1, 1)).toBe((1 * 5 + 1 * 3) % Kit.CROWD_VARIANTS + 1)
		expect(FiguresDef.variant(4, 18)).toBe((4 * 5 + 18 * 3) % Kit.CROWD_VARIANTS + 1)
	end)

	it(
		"counts: one figure per two citizens, at most 60, then the tier's fill; unknown citizens = a full stand",
		function()
			expect(FiguresDef.counts({ a = 40, b = nil }, { a = "loyal", b = "hostile" })).toEqual({ a = 20, b = 30 })
			expect(FiguresDef.counts({ a = 0, b = 500 }, { a = "adoring", b = "restless" })).toEqual({ a = 0, b = 42 })
			expect(FiguresDef.counts({}, { a = "divided" })).toEqual({ a = 54, b = 54 }) -- an unknown tier reads divided
			expect(Crowd.maxPerStand).toBe(60)
		end
	)

	it("moves: a share picks the same evenly spread figures every time", function()
		local function count(share, n)
			local moved = 0
			for index = 1, n do
				moved += if FiguresDef.moves(index, share) then 1 else 0
			end
			return moved
		end
		expect(count(1, 60)).toBe(60)
		expect(count(0, 60)).toBe(0)
		expect(count(0.5, 60)).toBe(30)
		expect(count(0.3, 60)).toBe(18)
		expect(FiguresDef.moves(1, 0.5)).toBe(false)
		expect(FiguresDef.moves(2, 0.5)).toBe(true)
	end)

	it("every reaction kind the director can play has a motion or is still on purpose", function()
		local still = { murmur = true, quiet = true, silence = true, calledOff = true }
		local kinds = { rally = true, perk = true, chant = true }
		for _, tier in Crowd.tiers do
			kinds[tier.idle], kinds[tier.good], kinds[tier.bad] = true, true, true
		end
		for _, ending in { "flood", "thinCrowning", "salute", "empty" } do
			kinds[ending] = true
		end
		for kind in kinds do
			expect(FiguresDef.MOTIONS[kind] ~= nil or still[kind] == true).toBe(true)
		end
		expect(FiguresDef.MOTIONS.turnBack.motion).toBe("turn") -- the strongest negative
	end)
end)

describe("CrowdFiguresController on FORGE-02's CrownArena (FL-0074 part 2c)", function()
	local env, controller, crowd, arena

	local function boot(opts)
		opts = opts or {}
		crowd = { director = nil, reacted = Signal.new() }
		controller = Loader.load(env, {
			{
				name = "FeedbackCrowdController",
				new = function()
					return crowd
				end,
			},
			{
				name = "CrowdFiguresController",
				dependencies = { "FeedbackCrowdController" },
				new = function(e, r)
					return FiguresDef.create(e, r, { model = opts.model, workspace = env.Workspace, kit = opts.kit })
				end,
			},
		}):get("CrowdFiguresController")
	end

	local function seatOf(name)
		local root = arena:FindFirstChild("Root")
		return root.CFrame * root:FindFirstChild(name).CFrame
	end

	beforeEach(function()
		env = MockEnv.new({ isServer = false, localPlayer = { userId = 1001 } })
		arena = Kit.arena()
	end)

	it("a duel fills both stands: each figure on its seat, Stand A for side a, the tier's fill", function()
		boot({ model = arena })
		controller:onArenaState({ stage = "duel", a = { citizens = 40 }, b = { citizens = 120 } })
		crowd.director = director("loyal", "crimson", "hostile", "azure")
		controller:step(0)
		expect(#controller.figures.a).toBe(20)
		expect(#controller.figures.b).toBe(30)
		local first = controller.figures.a[1]
		expect(near(pivotOf(first.model).Position, seatOf("StandA_Row1_Seat9").Position)).toBe(true)
		expect(near(pivotOf(controller.figures.b[1].model).Position, seatOf("StandB_Row1_Seat9").Position)).toBe(true)
		local last = controller.figures.b[30] -- the 30th seat in fill order: row 2, the 12th from the centre
		local spot = FiguresDef.order()[30]
		expect(near(pivotOf(last.model).Position, seatOf(`StandB_Row{spot.row}_Seat{spot.seat}`).Position)).toBe(true)
		-- figures face the ring: the seat's -Z looks at the centre
		local toCentre = (arena.Root.CFrame.Position - pivotOf(first.model).Position) * Vector3.new(1, 0, 1)
		expect(pivotOf(first.model).LookVector:Dot(toCentre.Unit) > 0.5).toBe(true)
		local folder = env.Workspace:FindFirstChild(FiguresDef.FOLDER)
		expect(folder).never.toBeNil()
		expect(#folder:GetChildren()).toBe(50)
		local parts = 0
		for _, d in folder:GetDescendants() do
			parts += if d:IsA("BasePart") then 1 else 0
		end
		expect(parts <= 50 * Kit.CROWD_MAX_PARTS).toBe(true)
	end)

	it("a new pair refills the stands; no director (done, Results, Lobby) empties them", function()
		boot({ model = arena })
		crowd.director = director("adoring", "emerald", "loyal", "gold")
		controller:step(0)
		local old = controller.figures.a[1].model
		expect(#controller.figures.a).toBe(60) -- citizens unknown: a full stand
		crowd.director = director("hostile", "crimson", "hostile", "azure")
		controller:step(0)
		expect(old.Parent).toBeNil()
		expect(#controller.figures.a).toBe(30)
		crowd.director = nil
		controller:step(0)
		expect(#controller.figures.a + #controller.figures.b).toBe(0)
		expect(env.Workspace:FindFirstChild(FiguresDef.FOLDER)).toBeNil()
	end)

	it("without the arena model, or for a kingdom the config lacks, nothing is built", function()
		boot({})
		crowd.director = director("loyal", "crimson", "loyal", "azure")
		controller:step(0)
		expect(#controller.figures.a + #controller.figures.b).toBe(0)
		-- a Kit that would build a neutral figure for a missing colour: still no figure for that stand
		local lenient = {
			crowdFigure = function(color, role, variant)
				return Kit.crowdFigure(color or Color3.new(0.5, 0.5, 0.5), role, variant)
			end,
		}
		boot({ model = arena, kit = lenient })
		crowd.director = director("loyal", "nowhere", "loyal", "azure")
		controller:step(0)
		expect(#controller.figures.a).toBe(0)
		expect(#controller.figures.b).toBe(60)
	end)

	it("a roar hops the reacting stand only, and every figure lands back on its seat", function()
		boot({ model = arena })
		crowd.director = director("loyal", "crimson", "loyal", "azure")
		controller:step(0)
		local t0 = env.clock()
		crowd.reacted:fire({ stand = "a", kind = "roar" }, "crimson")
		controller:step(t0 + 0.2)
		local lifted = 0
		for _, figure in controller.figures.a do
			lifted += if pivotOf(figure.model).Position.Y > figure.seat.Position.Y + 0.01 then 1 else 0
		end
		expect(lifted > 30).toBe(true)
		for _, figure in controller.figures.b do
			expect(near(pivotOf(figure.model).Position, figure.seat.Position)).toBe(true)
		end
		controller:step(t0 + FiguresDef.MOTIONS.roar.sec + 0.01)
		for _, figure in controller.figures.a do
			expect(near(pivotOf(figure.model).Position, figure.seat.Position)).toBe(true)
		end
	end)

	it("gasp slumps, turnBack turns the backs, murmur stays still; a new motion starts from the seats", function()
		boot({ model = arena })
		crowd.director = director("hostile", "crimson", "hostile", "azure")
		controller:step(0)
		local t0 = env.clock()
		crowd.reacted:fire({ stand = "b", kind = "turnBack" }, "azure")
		controller:step(t0 + 0.5)
		local figure = controller.figures.b[1]
		expect(pivotOf(figure.model).LookVector:Dot(figure.seat.LookVector) < -0.9).toBe(true)
		crowd.reacted:fire({ stand = "b", kind = "gasp" }, "azure")
		controller:step(t0 + 0.6)
		expect(pivotOf(figure.model).LookVector:Dot(figure.seat.LookVector) > 0.99).toBe(true)
		expect(pivotOf(figure.model).Position.Y < figure.seat.Position.Y - 0.1).toBe(true)
		controller:step(t0 + 0.6 + FiguresDef.MOTIONS.gasp.sec + 0.5)
		expect(near(pivotOf(figure.model).Position, figure.seat.Position)).toBe(true)
		crowd.reacted:fire({ stand = "a", kind = "murmur" }, "crimson")
		controller:step(t0 + 3)
		for _, f in controller.figures.a do
			expect(near(pivotOf(f.model).Position, f.seat.Position)).toBe(true)
		end
		-- a roar then a mixed (a third hops): the figures outside the third are back on their seats
		local t1 = env.clock() + 10
		crowd.reacted:fire({ stand = "a", kind = "roar" }, "crimson")
		controller._motions.a.started = t1
		controller:step(t1 + 0.2)
		crowd.reacted:fire({ stand = "a", kind = "mixed" }, "crimson")
		controller._motions.a.started = t1 + 0.2
		controller:step(t1 + 0.25)
		for index, f in controller.figures.a do
			if not FiguresDef.moves(index, FiguresDef.MOTIONS.mixed.share) then
				expect(near(pivotOf(f.model).Position, f.seat.Position)).toBe(true)
			end
		end
	end)
end)
