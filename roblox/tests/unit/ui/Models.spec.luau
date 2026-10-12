local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local UI = "@game/StarterPlayer/StarterPlayerScripts/Forge/UI/"
local BuildMenuModel = require(UI .. "Kingdom/BuildMenuModel")
local Construction = require("@game/ReplicatedStorage/Forge/Economy/Construction")
local Currencies = require("@game/ReplicatedStorage/Forge/Economy/Currencies")
local Format = require(UI .. "Format")
local KingdomPanelModel = require(UI .. "Kingdom/KingdomPanelModel")
local Layout = require(UI .. "Layout")
local Text = require(UI .. "Kingdom/Text")

local catalog = Construction.default()
local currencies = Currencies.default()

local function kingdom(extra)
	local k = {
		kingdomId = "k1",
		name = "Aldmere",
		hall = 1,
		version = 3,
		territory = { tiles = 6 },
		citizens = { total = 9, housing = 10, working = 6, building = 1, idle = 2 },
		builders = { busy = 1, total = 2 },
		buildings = {
			{ uid = "u1", buildingId = "townhall", level = 1, state = "ready", workers = 0 },
			{ uid = "u2", buildingId = "farm", level = 1, state = "ready", workers = 3 },
			{ uid = "u3", buildingId = "lumbercamp", level = 1, state = "ready", workers = 3 },
			{
				uid = "u4",
				buildingId = "house",
				level = 0,
				state = "constructing",
				workers = 0,
				startedAt = 100,
				completesAt = 112,
			},
		},
	}
	for key, v in extra or {} do
		k[key] = v
	end
	return k
end

local function treasury(balances)
	return {
		kingdomId = "k1",
		version = 5,
		balances = balances or { food = 136, wood = 85, stone = 50, gold = 50 },
		caps = { food = 500, wood = 500, stone = 300, gold = 300 },
	}
end

local function input(extra)
	local i =
		{ catalog = catalog, currencies = currencies, kingdom = kingdom(), treasury = treasury(), category = "economy" }
	for key, v in extra or {} do
		i[key] = v
	end
	return i
end

local function row(view, id)
	for _, r in view.rows do
		if r.id == id then
			return r
		end
	end
	return nil
end

describe("BuildMenuModel", function()
	it("lists a category in config order with costs, counts and locks", function()
		local view = BuildMenuModel.build(input())
		local ids = {}
		for _, r in view.rows do
			table.insert(ids, r.id)
		end
		expect(ids).toEqual({ "farm", "lumbercamp", "quarry", "goldmine" })
		expect(row(view, "farm").count).toBe(1)
		expect(row(view, "farm").maxCount).toBe(6)
		expect(row(view, "quarry").costs).toEqual({
			{ currency = "food", amount = 20, short = false },
			{ currency = "wood", amount = 50, short = false },
		})
		expect(row(view, "goldmine").locked).toBe(true)
		expect(row(view, "goldmine").lockText).toBe("Town Hall Lv 2")
		expect(view.loading).toBe(false)
	end)

	it("never offers the prebuilt Town Hall for construction", function()
		local view = BuildMenuModel.build(input({ category = "civic" }))
		expect(row(view, "townhall")).toBeNil()
		expect(row(view, "house")).toBeTruthy()
	end)

	it("selects the first row by default and keeps a valid selection", function()
		expect(BuildMenuModel.build(input()).selected).toBe("farm")
		local view = BuildMenuModel.build(input({ selected = "quarry" }))
		expect(view.selected).toBe("quarry")
		expect(row(view, "quarry").selected).toBe(true)
		expect(BuildMenuModel.build(input({ selected = "barracks" })).selected).toBe("farm") -- other tab
	end)

	it("explains costs with have and need, and a ready Build button", function()
		local d = BuildMenuModel.build(input({ selected = "quarry" })).detail
		expect(d.name).toBe("Quarry")
		expect(d.meta).toBe("Economy · Level 1 · 0/3 built")
		expect(d.buildSec).toBe(18)
		expect(d.rate).toEqual({ { currency = "stone", perMinute = 12 } })
		expect(d.costs[2]).toEqual({ currency = "wood", name = "Wood", amount = 50, have = 85, short = false, need = 0 })
		expect(d.cta).toEqual({ state = "ready", text = "Build Quarry", icon = "build", variant = "primary" })
		expect(d.needsConfirm).toBe(false)
	end)

	it("says exactly what is missing when the treasury is short", function()
		local d = BuildMenuModel.build(
			input({ selected = "quarry", treasury = treasury({ food = 5, wood = 30, stone = 0, gold = 0 }) })
		).detail
		expect(d.cta.state).toBe("disabled")
		expect(d.cta.text).toBe("Need 15 more Food and 20 more Wood")
		expect(d.costs[2].short).toBe(true)
		expect(d.costs[2].need).toBe(20)
		local view = BuildMenuModel.build(input({ treasury = treasury({ food = 0, wood = 0, stone = 0, gold = 0 }) }))
		expect(row(view, "farm").costs[1].short).toBe(true)
	end)

	it("shows the requirement first for locked buildings", function()
		local d = BuildMenuModel.build(input({ selected = "goldmine" })).detail
		expect(d.cta.text).toBe("Requires Town Hall Lv 2")
		expect(d.cta.icon).toBe("lock")
		expect(d.requirements).toEqual({ { text = "Town Hall Lv 2", met = false } })
	end)

	it("reflects limits, busy builders, loading and in-flight states", function()
		local full = kingdom({ builders = { busy = 2, total = 2 } })
		expect(BuildMenuModel.build(input({ kingdom = full, selected = "farm" })).detail.cta.text).toBe(
			"All builders are busy"
		)
		local k = kingdom()
		for i = 1, 3 do
			table.insert(
				k.buildings,
				{ uid = "q" .. i, buildingId = "quarry", level = 1, state = "ready", workers = 0 }
			)
		end
		expect(BuildMenuModel.build(input({ kingdom = k, selected = "quarry" })).detail.cta.text).toBe(
			"Limit reached (3/3)"
		)
		expect(BuildMenuModel.build(input({ selected = "quarry", pending = "quarry" })).detail.cta.state).toBe(
			"loading"
		)
		local done = BuildMenuModel.build(input({ selected = "quarry", done = "quarry" })).detail.cta
		expect(done.state).toBe("done")
		expect(done.text).toBe("Construction started")
		local loading = BuildMenuModel.build(input({ treasury = false }))
		expect(loading.loading).toBe(true)
		expect(loading.detail.cta.text).toBe("Loading your kingdom…")
	end)

	it("asks for confirmation only for large spends", function()
		expect(BuildMenuModel.isLargeSpend({ wood = 50, food = 20 }, { wood = 85, food = 136 })).toBe(false) -- small total
		expect(
			BuildMenuModel.isLargeSpend({ wood = 150, stone = 100, gold = 40 }, { wood = 180, stone = 400, gold = 400 })
		).toBe(true)
		expect(
			BuildMenuModel.isLargeSpend({ wood = 150, stone = 100, gold = 40 }, { wood = 999, stone = 999, gold = 999 })
		).toBe(false)
	end)

	it("builds the upgrade detail for an existing building", function()
		local i = input({ treasury = treasury({ food = 0, wood = 85, stone = 50, gold = 50 }) })
		local d = BuildMenuModel.detail(i, "townhall", "u1")
		expect(d.action).toBe("upgrade")
		expect(d.meta).toBe("Civic · Level 1 → 2")
		expect(d.cta.text).toBe("Need 65 more Wood and 50 more Stone")
		local rich = BuildMenuModel.detail(
			input({ treasury = treasury({ food = 0, wood = 300, stone = 120, gold = 50 }) }),
			"townhall",
			"u1"
		)
		expect(rich.cta.text).toBe("Upgrade to Lv 2")
		expect(rich.needsConfirm).toBe(true)
	end)
end)

describe("KingdomPanelModel", function()
	it("summarises citizens and production per match resource", function()
		local o = KingdomPanelModel.overview(kingdom(), treasury(), catalog, currencies)
		expect(o.citizens).toEqual({ total = 9, housing = 10, working = 6, building = 1, idle = 2 })
		expect(o.production[1]).toEqual({ currency = "food", name = "Food", perMinute = 18, amount = 136, cap = 500 })
		expect(o.production[2].perMinute).toBe(18)
		expect(o.production[3].perMinute).toBe(0)
	end)

	it("lists buildings: Town Hall first, then construction, with progress and worker controls", function()
		local rows = KingdomPanelModel.buildings(kingdom(), treasury(), catalog, 106)
		expect(rows[1].buildingId).toBe("townhall")
		expect(rows[2].buildingId).toBe("house")
		expect(rows[2].progress).toBe(0.5)
		expect(rows[2].timeLeft).toBe(6)
		expect(rows[2].canAdd).toBe(false)
		local farm = rows[3]
		expect(farm.buildingId).toBe("farm")
		expect(farm.workers).toBe(3)
		expect(farm.slots).toBe(3)
		expect(farm.canAdd).toBe(false)
		expect(farm.canRemove).toBe(true)
		expect(farm.rate).toEqual({ { currency = "food", perMinute = 18 } })
		expect(rows[1].canUpgrade).toBe(true)
	end)

	it("orders the construction queue by time left", function()
		local k = kingdom()
		table.insert(k.buildings, {
			uid = "u9",
			buildingId = "farm",
			level = 1,
			state = "upgrading",
			workers = 0,
			startedAt = 100,
			completesAt = 104,
		})
		local q = KingdomPanelModel.queue(k, catalog, 102)
		expect(#q).toBe(2)
		expect(q[1].uid).toBe("u9")
		expect(q[1].upgrade).toBe(true)
		expect(q[2].uid).toBe("u4")
	end)
end)

describe("Layout", function()
	it("classifies the three reference devices by their safe area", function()
		local phone = Layout.compute(750, 311) -- 844x390 minus notch insets and the top bar
		expect(phone.breakpoint).toBe("phone")
		expect(phone.scale).toBe(1)
		expect(phone.drawer.single).toBe(true)
		local tablet = Layout.compute(1024, 690)
		expect(tablet.breakpoint).toBe("tablet")
		expect(tablet.scale).toBeNear(1.095, 0.01)
		local desktop = Layout.compute(1920, 1022)
		expect(desktop.breakpoint).toBe("desktop")
		expect(desktop.scale).toBeNear(1.2, 0.01)
		expect(desktop.drawer.single).toBe(false)
	end)

	it("keeps the phone drawer right of the resource pills and inside the screen", function()
		local m = Layout.compute(750, 311)
		local pillsEnd = m.hud.x + Layout.PHONE_CREST + 8 + 4 * Layout.PHONE_PILL + 3 * Layout.PHONE_PILL_GAP
		expect(m.drawer.x).toBeGreaterThanOrEqual(pillsEnd)
		expect(m.drawer.x + m.drawer.width).toBeLessThanOrEqual(m.width - m.rail.button - m.rail.right)
		expect(m.drawer.height).toBeGreaterThan(250)
	end)

	it("keeps drawers clear of the rail and touch targets at least 44 px", function()
		for _, size in { { 750, 311 }, { 1024, 690 }, { 1920, 1022 }, { 1280, 662 } } do
			local m = Layout.compute(size[1], size[2])
			expect(m.drawer.x + m.drawer.width).toBeLessThanOrEqual(m.width - m.rail.right - m.rail.button)
			expect(m.drawer.y + m.drawer.height).toBeLessThanOrEqual(m.height)
			expect(m.rail.button).toBeGreaterThanOrEqual(44)
		end
	end)

	it("moves toasts and chips out from under an open drawer", function()
		local m = Layout.compute(750, 311)
		expect(Layout.freeArea(m, true).width).toBe(m.drawer.x)
		expect(Layout.toastTop(m, true)).toBeGreaterThan(m.hud.bottom)
		expect(Layout.toastTop(m, false)).toBe(m.hud.y)
	end)
end)

describe("Format and Text", function()
	it("formats amounts, signs, clocks and lists", function()
		expect(Format.amount(999)).toBe("999")
		expect(Format.amount(1234)).toBe("1.2k")
		expect(Format.amount(1000)).toBe("1k")
		expect(Format.amount(15300)).toBe("15k")
		expect(Format.amount(2500000)).toBe("2.5M")
		expect(Format.signed(-50)).toBe("−50")
		expect(Format.signed(12)).toBe("+12")
		expect(Format.clock(75)).toBe("1:15")
		expect(Format.clock(3725)).toBe("1:02:05")
		expect(Format.clock(-3)).toBe("0:00")
		expect(Format.clock(6.2)).toBe("0:07")
		expect(Format.list({ "a", "b", "c" })).toBe("a, b and c")
	end)

	it("maps every server refusal to a sentence", function()
		expect(Text.serverError(nil)).toBe("Couldn't reach the server. Try again.")
		expect(Text.serverError("insufficient")).toBe("Not enough resources")
		expect(Text.serverError("weird")).toBe("That didn't work. Try again.")
	end)
end)
