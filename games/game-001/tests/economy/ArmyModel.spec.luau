-- FL-0060: the pure parts of the army drawer, the objective tracker and the slice summary —
-- sentences (UI/ArmyText), the drawer model (UI/ArmyModel), the tracker model (UI/ObjectiveModel),
-- the summary model (UI/SummaryModel), the store's unit costs and the tracker's Layout zone.
local fs = require("@lune/fs")
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ArmyModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArmyModel")
local ArmyText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArmyText")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local KingdomStore = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/KingdomStore")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local ObjectiveModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ObjectiveModel")
local SummaryModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/SummaryModel")

local KINGDOMS = {
	{ id = "crimson", name = "Emberhold", color = Color3.fromRGB(184, 64, 46), rulers = { 1 }, isAI = false },
	{ id = "azure", name = "Frostmere", color = Color3.fromRGB(63, 114, 181), rulers = { 7 }, isAI = false },
	{ id = "emerald", name = "Thornwood", color = Color3.fromRGB(62, 138, 75), rulers = {}, isAI = true },
	{ id = "gold", name = "Sunspire", color = Color3.fromRGB(201, 154, 54), rulers = {}, isAI = true },
}

local function store(opts: { [string]: any }?)
	local o = opts or {}
	local s = KingdomStore.new()
	s:applyKingdoms({ mine = if o.mine == false then nil else "crimson", kingdoms = KINGDOMS })
	if o.treasury ~= false then
		s:applyTreasury(o.treasury or { food = 120, wood = 100, stone = 50, gold = 0 })
	end
	local buildings = {
		{ id = 1, kingdom = "crimson", type = "keep", level = 1, state = "complete" },
		{ id = 9, kingdom = "azure", type = "barracks", level = 3, state = "complete" },
	}
	for _, b in o.buildings or {} do
		table.insert(buildings, b)
	end
	s:applyBuildings(buildings, true)
	if o.soldiers ~= nil then
		s:applyPopulation({ total = 10, cap = 12, byJob = { farmer = 3, soldier = o.soldiers } })
	end
	return s
end

local BARRACKS = { id = 5, kingdom = "crimson", type = "barracks", level = 1, state = "complete" }

describe("ArmyText (FL-0060)", function()
	it("turns reason codes into sentences and never shows an unknown code", function()
		expect(ArmyText.reason("recruit_cap")).toBe("No free bunks. Upgrade the barracks or build another") -- D-041
		expect(ArmyText.reason("cannot_afford")).toBe("Not enough resources")
		expect(ArmyText.reason("barracks_not_ready")).toBe("Finish building the barracks first")
		expect(ArmyText.reason("requires_barracks_level")).toBe("Upgrade the barracks first")
		-- every code FORGE-01's Army.Recruit sends has its own sentence: read from the reasons line of
		-- Army/Remotes.luau, so a code added there fails here until it is worded (parentheses explain)
		local source = fs.readFile(T.root .. "/games/game-001/src/shared/Army/Remotes.luau")
		local line = string.match(source, "Army%.Recruit reasons:(.-)Army%.Command")
		assert(line, "Army/Remotes.luau has no 'Army.Recruit reasons:' line")
		local count = 0
		for code in string.gmatch((string.gsub(line, "%b()", "")), "[%l_]+") do
			count += 1
			local sentence = ArmyText.reason(code)
			if sentence == ArmyText.GENERIC or string.find(sentence, code, 1, true) then
				error(`Army.Recruit: "{code}" reads "{sentence}"`)
			end
		end
		expect(count >= 9).toBe(true)
		-- unreachable through Recruit's validation, but worded anyway, and the rest of the panel's codes
		for _, code in { "requires_barracks_level", "unknown_unit", "invalid_args", "not_ruler", "unknown_command" } do
			expect(ArmyText.reason(code)).never.toBe(ArmyText.GENERIC)
		end
		-- codes the server never sends are not vocabulary
		for _, code in { "busy", "phase", "no_kingdom", "rate", "no_barracks", "population_cap" } do
			expect(ArmyText.reason(code)).toBe(ArmyText.GENERIC)
		end
		expect(ArmyText.reason(nil)).toBe(ArmyText.UNREACHABLE)
		local generic = ArmyText.reason("weird_code_42")
		expect(generic).toBe(ArmyText.GENERIC)
		expect(generic).never.toContain("weird_code_42")
		expect(ArmyText.reason(42)).toBe(ArmyText.GENERIC)
	end)

	it("formats counts, times and names", function()
		expect(ArmyText.recruitCta(1)).toBe("Recruit 1 soldier")
		expect(ArmyText.recruitCta(3)).toBe("Recruit 3 soldiers")
		expect(ArmyText.recruited(1)).toBe("1 soldier recruited")
		expect(ArmyText.each(8)).toBe("0:08 each")
		expect(ArmyText.upkeep(4)).toBe("Upkeep 4 Food/min")
		expect(ArmyText.objectiveName("watchtower")).toBe("Watchtower")
		expect(ArmyText.objectiveName("old_ford")).toBe("Old Ford")
		expect(ArmyText.lasted(754)).toBe("Lasted 12:34")
	end)
end)

describe("KingdomStore unit costs", function()
	it("reads Treasury.GetCosts units, else config Costs.unit", function()
		local s = KingdomStore.new()
		expect(s:unitCost("soldier")).toEqual(Costs.unit("soldier"))
		s:applyCosts({
			buildings = {},
			units = { soldier = { cost = { food = 40 }, trainSeconds = 5, upkeepFood = 2 } },
		})
		expect(s:unitCost("soldier")).toEqual({ cost = { food = 40 }, trainSeconds = 5, upkeepFood = 2 })
		local copy = s:unitCost("soldier")
		copy.cost.food = 1 -- a copy: callers cannot change the store
		expect(s:unitCost("soldier").cost.food).toBe(40)
		expect(s:unitCost("knight")).toBeNil()
		s:applyCosts({ buildings = {}, units = { soldier = { cost = "free", trainSeconds = 5 } } })
		expect(s:unitCost("soldier")).toBeNil()
	end)
end)

describe("ArmyModel (FL-0060)", function()
	it("recruits at my barracks: the preferred one, else my first finished one", function()
		local s = store({
			buildings = {
				{ id = 4, kingdom = "crimson", type = "barracks", level = 1, state = "constructing" },
				BARRACKS,
				{ id = 6, kingdom = "crimson", type = "barracks", level = 2, state = "complete" },
			},
		})
		expect(ArmyModel.barracks(s, nil).id).toBe(5)
		expect(ArmyModel.barracks(s, 6).id).toBe(6)
		expect(ArmyModel.barracks(s, 4).id).toBe(4)
		expect(ArmyModel.barracks(s, 9).id).toBe(5) -- Frostmere's barracks is not mine
		expect(ArmyModel.barracks(store(), nil)).toBeNil()
	end)

	it("prices the count against the treasury and says what is missing", function()
		local s = store({ buildings = { BARRACKS }, soldiers = 2 })
		local p = ArmyModel.panel(s, { count = 3 })
		expect(p.count).toBe(3)
		expect(p.costs[1].currency).toBe("food")
		expect(p.costs[1].amount).toBe(90)
		expect(p.costs[1].have).toBe(120)
		expect(p.costs[2].amount).toBe(30)
		expect(p.recruit.state).toBe("ready")
		expect(p.recruit.text).toBe("Recruit 3 soldiers")
		expect(p.tabs[1].label).toBe("Barracks · Lv 1")
		expect(p.tabs[2].id).toBe("army")
		expect(p.unit.each).toBe("0:08 each")
		local short = ArmyModel.panel(s, { count = 5 })
		expect(short.recruit.state).toBe("disabled")
		expect(short.recruit.text).toBe("Need 30 Food")
		expect(short.costs[1].short).toBe(true)
		expect(short.costs[2].short).toBe(false)
		expect(ArmyModel.panel(s, { count = 99 }).count).toBe(ArmyModel.MAX_COUNT)
		expect(ArmyModel.panel(s, { count = 0 }).count).toBe(1)
		expect(ArmyModel.panel(s, { count = 0 / 0 }).count).toBe(1)
		expect(ArmyModel.panel(s, { count = 1 }).canLess).toBe(false)
		expect(ArmyModel.panel(s, { count = 10 }).canMore).toBe(false)
		expect(ArmyModel.panel(s, { count = 3, pending = true }).recruit.state).toBe("loading")
	end)

	it("explains why recruiting is not possible", function()
		local none = ArmyModel.panel(store({ soldiers = 0 }), { count = 1 })
		expect(none.recruit.text).toBe(ArmyText.NO_BARRACKS_CTA)
		expect(none.notice).toBe(ArmyText.NO_BARRACKS)
		expect(#none.tabs).toBe(1)
		local building = ArmyModel.panel(
			store({
				buildings = { { id = 5, kingdom = "crimson", type = "barracks", level = 1, state = "constructing" } },
			}),
			{ count = 1 }
		)
		expect(building.recruit.text).toBe(ArmyText.UNFINISHED_CTA)
		local loading = ArmyModel.panel(store({ treasury = false, buildings = { BARRACKS } }), { count = 1 })
		expect(loading.recruit.text).toBe(ArmyText.LOADING)
	end)

	it("Send to capture: blocked only by what the server said", function()
		local s = store({ buildings = { BARRACKS }, soldiers = 4 })
		local ready = ArmyModel.panel(s, { count = 1 })
		expect(ready.send.state).toBe("ready")
		expect(ready.soldiersText).toBe("4")
		expect(ready.upkeep).toBe("Upkeep 4 Food/min")
		expect(ready.status.default).toBe(true)
		local unknown = ArmyModel.panel(store({ buildings = { BARRACKS } }), { count = 1 })
		expect(unknown.soldiersText).toBe("—")
		expect(unknown.send.state).toBe("ready") -- a count the server has not sent does not block it
		local zero = ArmyModel.panel(store({ soldiers = 0 }), { count = 1 })
		expect(zero.send.state).toBe("disabled")
		expect(zero.send.text).toBe(ArmyText.NO_SOLDIERS)
		local cooling = ArmyModel.panel(s, { count = 1, cooling = true })
		expect(cooling.send.state).toBe("done")
		expect(cooling.status.text).toBe(ArmyText.SENT_STATUS)
		local mine = ObjectiveModel.normalize({ { id = "watchtower", owner = "crimson", progress = { crimson = 1 } } })
		local held = ArmyModel.panel(s, { count = 1, objectives = mine })
		expect(held.send.state).toBe("disabled")
		expect(held.send.text).toBe(ArmyText.ALL_MINE)
		local neutral = ObjectiveModel.normalize({ { id = "watchtower", progress = { crimson = 0.5 } } })
		local target = ArmyModel.panel(s, { count = 1, objectives = neutral }).target
		expect(target.name).toBe("Watchtower")
		expect(target.text).toBe("Neutral · you 50%")
	end)
end)

describe("ObjectiveModel (FL-0060)", function()
	it("normalizes loosely: drops bad entries, clamps progress, ignores a non-table", function()
		expect(ObjectiveModel.normalize(nil)).toBeNil()
		expect(ObjectiveModel.normalize("nope")).toBeNil()
		local list = ObjectiveModel.normalize({
			{ id = 5 },
			"x",
			{ id = "", progress = {} },
			{
				id = "watchtower",
				owner = 3,
				progress = { crimson = 2, azure = -1, [1] = 0.5, gold = "a", emerald = 0 / 0 },
			},
		}) :: { any }
		expect(#list).toBe(1)
		expect(list[1].owner).toBeNil()
		expect(list[1].progress.crimson).toBe(1)
		expect(list[1].progress.azure).toBe(0)
		expect(list[1].progress.gold).toBeNil()
		expect(list[1].progress.emerald).toBeNil()
		local many = {}
		for i = 1, 40 do
			many[i] = { id = "o" .. i, progress = {} }
		end
		expect(#(ObjectiveModel.normalize(many) :: { any })).toBe(ObjectiveModel.MAX_OBJECTIVES)
	end)

	it("one bar per contesting kingdom: mine first, named, with a percentage", function()
		local s = store()
		local o = (ObjectiveModel.normalize({
			{ id = "watchtower", owner = "gold", progress = { azure = 0.5, crimson = 0.2, gold = 1, emerald = 0 } },
		}) :: { any })[1]
		local row = ObjectiveModel.row(o, nil, s, nil)
		expect(#row.bars).toBe(2) -- the owner holding it fully and a zero are left out
		expect(row.bars[1].kingdom).toBe("crimson")
		expect(row.bars[1].label).toBe("You")
		expect(row.bars[1].text).toBe("20%")
		expect(row.bars[2].label).toBe("Frostmere")
		expect(row.bars[2].text).toBe("50%")
		expect(row.owner.text).toBe("Sunspire")
		expect(row.status).toBeNil()
		local collapsed = ObjectiveModel.row(o, nil, s, 1)
		expect(#collapsed.bars).toBe(1)
		expect(collapsed.hidden).toBe(1)
		local tiny = ObjectiveModel.row({ id = "t", progress = { azure = 0.004, crimson = 0.999 } }, nil, s, nil)
		expect(tiny.bars[1].text).toBe("99%") -- never "100%" before the server says captured
		expect(tiny.bars[2].text).toBe("1%")
	end)

	it("owner and status in words", function()
		local s = store()
		expect(ObjectiveModel.row({ id = "w", progress = {} }, nil, s, nil).owner.text).toBe("Neutral")
		expect(ObjectiveModel.row({ id = "w", progress = {} }, nil, s, nil).status).toBe(ArmyText.STATUS_NEUTRAL)
		local mine = ObjectiveModel.row({ id = "w", owner = "crimson", progress = { crimson = 1 } }, nil, s, nil)
		expect(mine.owner.text).toBe("Yours")
		expect(mine.owner.mine).toBe(true)
		expect(mine.status).toBe(ArmyText.STATUS_MINE)
		local theirs = ObjectiveModel.row({ id = "w", owner = "azure", progress = { azure = 1 } }, nil, s, nil)
		expect(theirs.status).toBe(ArmyText.STATUS_FOREIGN)
		local unknown = ObjectiveModel.row({ id = "w", owner = "violet", progress = { violet = 0.5 } }, nil, s, nil)
		expect(unknown.owner.text).toBe("Violet")
		local contested = ObjectiveModel.row({ id = "w", contested = true, progress = { azure = 0.2 } }, nil, s, nil)
		expect(contested.height).toBe(ObjectiveModel.rowHeight(2))
	end)

	it("collapsed: the objective that matters, two bars, '+N more'; expanded: everything", function()
		local s = store()
		local list = ObjectiveModel.normalize({
			{ id = "ford", owner = "crimson", progress = { crimson = 1 } },
			{ id = "watchtower", progress = { crimson = 0.3, azure = 0.5, gold = 0.2 } },
			{ id = "hill", progress = {} },
		}) :: { any }
		expect(ObjectiveModel.focus(list, "crimson")).toBe(2)
		local t = ObjectiveModel.tracker(list, s, { expanded = false })
		expect(t.visible).toBe(true)
		expect(#t.rows).toBe(1)
		expect(t.rows[1].id).toBe("watchtower")
		expect(t.rows[1].number).toBe(2)
		expect(#t.rows[1].bars).toBe(2)
		expect(t.more).toBe("+3 more") -- 2 other objectives and 1 hidden bar
		expect(t.height).toBeGreaterThanOrEqual(ObjectiveModel.MIN_HEIGHT)
		local open = ObjectiveModel.tracker(list, s, { expanded = true })
		expect(#open.rows).toBe(3)
		expect(open.more).toBeNil()
		expect(open.title.text).toBe(ArmyText.OBJECTIVES)
		expect(open.rows[2].y).toBeGreaterThan(open.rows[1].y + open.rows[1].height - 1)
		local capped = ObjectiveModel.tracker(list, s, { expanded = true, maxHeight = 100 })
		expect(capped.height).toBe(100)
		expect(capped.scroll).toBe(true)
		local single = ObjectiveModel.tracker({ { id = "w", progress = {} } }, s, {})
		expect(single.rows[1].number).toBeNil()
		expect(single.height).toBeGreaterThanOrEqual(44)
		expect(ObjectiveModel.tracker({}, s, {}).visible).toBe(false)
		expect(ObjectiveModel.allMine({ { id = "w", owner = "crimson", progress = {} } }, "crimson")).toBe(true)
		expect(ObjectiveModel.allMine({}, "crimson")).toBe(false)
	end)
end)

describe("SummaryModel (FL-0060)", function()
	local STANDINGS = {
		{ kingdom = "crimson", crownPoints = 112 },
		{ kingdom = "azure", crownPoints = 120 },
		{ kingdom = "emerald", crownPoints = 40 },
		{ kingdom = "gold", crownPoints = 0 },
	}

	it("names the winner, ranks by Crown Points and marks mine and the AI kingdoms", function()
		local ended = SummaryModel.normalize({ winner = "azure", standings = STANDINGS, durationSec = 754 }) :: any
		local m = SummaryModel.build(ended, store())
		expect(m.tone).toBe("over")
		expect(m.kicker).toBe(ArmyText.MATCH_OVER)
		expect(m.headline).toBe("Frostmere")
		expect(m.sub).toBe(ArmyText.WINS)
		expect(m.duration).toBe("Lasted 12:34")
		expect(m.standings[1].id).toBe("azure")
		expect(m.standings[1].winner).toBe(true)
		expect(m.standings[2].id).toBe("crimson")
		expect(m.standings[2].mine).toBe(true)
		expect(m.standings[2].ai).toBe(false)
		expect(m.standings[3].ai).toBe(true)
		expect(m.standings[2].points).toBe("112")
	end)

	it("a win of mine, no winner, unknown kingdoms and bad payloads", function()
		local win =
			SummaryModel.build(SummaryModel.normalize({ winner = "crimson", standings = STANDINGS }) :: any, store())
		expect(win.tone).toBe("win")
		expect(win.kicker).toBe(ArmyText.VICTORY)
		expect(win.sub).toBe(ArmyText.YOU_WIN)
		expect(win.duration).toBeNil()
		local none =
			SummaryModel.build(SummaryModel.normalize({ standings = STANDINGS, durationSec = 60 }) :: any, store())
		expect(none.headline).toBe(ArmyText.NO_WINNER)
		expect(none.winner).toBeNil()
		expect(none.standings[1].winner).toBe(false)
		local odd = SummaryModel.normalize({
			winner = 5,
			standings = { "x", { kingdom = "violet", crownPoints = "many" }, { crownPoints = 3 } },
			durationSec = -4,
		}) :: any
		expect(odd.winner).toBeNil()
		expect(#odd.standings).toBe(1)
		expect(odd.standings[1].crownPoints).toBe(0)
		expect(odd.durationSec).toBeNil()
		expect(SummaryModel.build(odd, store()).standings[1].name).toBe("Violet")
		expect(SummaryModel.normalize(nil)).toBeNil()
		expect(SummaryModel.normalize("over")).toBeNil()
		expect(#(SummaryModel.normalize({}) :: any).standings).toBe(0)
	end)
end)

describe("Objective tracker zone (Layout, FL-0060)", function()
	it("sits under the stack, left of the drawer, at every size", function()
		for _, size in { { 750, 311 }, { 640, 360 }, { 1024, 690 }, { 1280, 662 }, { 1920, 1022 }, { 2560, 1340 } } do
			local m = Layout.compute(size[1], size[2])
			local z = m.hud.objectives
			expect(z.y).toBeGreaterThan(m.hud.bottom)
			expect(z.x + z.width + 12).toBeLessThanOrEqual(m.drawer.x)
			expect(z.maxHeight).toBeGreaterThanOrEqual(44)
			expect(z.y + z.maxHeight).toBeLessThanOrEqual(m.height - m.margin - Layout.CHIPS_CLEARANCE)
		end
		local phone = Layout.compute(750, 311)
		expect(Layout.toastTop(phone, true)).toBe(phone.hud.bottom + 8)
		expect(Layout.toastTop(phone, true, 160)).toBe(168)
		expect(Layout.toastTop(phone, false, 160)).toBe(phone.hud.y)
	end)
end)
