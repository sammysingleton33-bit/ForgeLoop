-- FL-0059: the pure parts of the kingdom HUD and build menu (layout, text, client store, HUD and
-- build models, placement maths and the throttled Build.CanPlace checker).
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local BuildModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/BuildModel")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Crest = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Crest")
local HudModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/HudModel")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local KingdomStore = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/KingdomStore")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local Placement = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Placement")
local Text = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Text")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")
local Toast = require("@game/ReplicatedStorage/Forge/UI/Components/Toast")

local function kingdoms(mine: string?)
	return {
		mine = mine,
		kingdoms = {
			{
				id = "crimson",
				name = "Emberhold",
				rulers = { 1, 2 },
				isAI = false,
				keepBuildingId = 10,
				crownPoints = 12,
				regions = { "crimson_home" },
			},
			{
				id = "azure",
				name = "Frostmere",
				rulers = { 3 },
				isAI = false,
				crownPoints = 20,
				regions = { "a", "b" },
			},
			{ id = "emerald", name = "Thornwood", rulers = {}, isAI = true, crownPoints = 0, regions = { "e" } },
			{ id = "gold", name = "Sunspire", rulers = {}, isAI = true, crownPoints = 0, regions = { "g" } },
		},
	}
end

local function store(opts: { [string]: any }?)
	local o = opts or {}
	local s = KingdomStore.new()
	s:applyKingdoms(kingdoms(if o.mine == false then nil else "crimson"))
	s:applyBuildings({
		{ id = 10, kingdom = "crimson", type = "keep", level = 1, state = "complete", progress = 1 },
		{ id = 11, kingdom = "crimson", type = "farm", level = 1, state = "complete", progress = 1 },
		{ id = 12, kingdom = "crimson", type = "house", level = 1, state = "constructing", progress = 0.456 },
		{ id = 13, kingdom = "crimson", type = "farm", level = 1, state = "planned", progress = 0 },
		{ id = 20, kingdom = "azure", type = "house", level = 1, state = "constructing", progress = 0.5 },
	}, true)
	if o.treasury ~= false then
		s:applyTreasury(o.treasury or { food = 120, wood = 100, stone = 50, gold = 0 })
	end
	return s
end

describe("Layout (prototype layout(), safe-area sizes)", function()
	it("picks breakpoint and scale and keeps whole logical pixels", function()
		local phone = Layout.compute(750, 311)
		expect(phone.breakpoint).toBe("phone")
		expect(phone.scale).toBe(1)
		local tablet = Layout.compute(1024, 690)
		expect(tablet.breakpoint).toBe("tablet")
		expect(tablet.scale).toBeNear(690 / 630, 1e-6)
		expect(tablet.width).toBe(math.floor(1024 / tablet.scale))
		local desktop = Layout.compute(1920, 1022)
		expect(desktop.breakpoint).toBe("desktop")
		expect(desktop.scale).toBeNear(1022 / 850, 1e-6)
		for _, m in { phone, tablet, desktop } do
			expect(m.drawer.x % 1).toBe(0)
			expect(m.drawer.x + m.drawer.width).toBeLessThan(m.width - m.rail.button)
			expect(m.drawer.y + m.drawer.height).toBeLessThan(m.height + 1)
		end
	end)

	it("keeps the HUD and the drawer apart", function()
		local tablet = Layout.compute(1024, 690)
		expect(tablet.drawer.y).toBeGreaterThan(tablet.hud.bottom)
		expect(tablet.hud.members).toBeTruthy()
		local phone = Layout.compute(750, 311)
		expect(phone.hud.members).toBeNil()
		local pillsEnd = phone.hud.pills.x
			+ Layout.PHONE_PILLS * Layout.PHONE_PILL
			+ (Layout.PHONE_PILLS - 1) * Layout.PHONE_PILL_GAP
		expect(phone.drawer.x).toBeGreaterThan(pillsEnd)
	end)
end)

describe("Text", function()
	it("turns server reasons into sentences and never shows a raw code", function()
		expect(Text.reason("out_of_territory")).toBe("Build inside your kingdom")
		expect(Text.reason("blocked")).toBe("Leave room for upgrades")
		expect(Text.reason("cannot_afford")).toBe("Not enough resources")
		expect(Text.reason("requires_keep_level")).toBe("Upgrade your keep first")
		expect(Text.reason("weird_code")).toBe("That didn't work. Try again.")
		expect(Text.reason(nil)).toBe("No answer from the server. Try again in a moment.")
		-- on a plot, the same refusals name the plot
		expect(Text.reason("blocked", "slot")).toBe("This plot is already built on")
		expect(Text.reason("out_of_territory", "slot")).toBe("This plot isn't yours")
	end)

	it("FL-0105: every refusal code the server returns has its own sentence", function()
		local generic = Text.reason("not_a_code_at_all")
		local function covered(code: string, where: string)
			local sentence = Text.reason(code)
			if sentence == generic or string.find(sentence, code, 1, true) then
				error(`{where}: "{code}" reads "{sentence}"`)
			end
		end
		-- the server's own list: the Reasons line of FORGE-01's Build/Remotes.luau, read from source so
		-- a code added there fails here until it is worded
		local source = fs.readFile(T.root .. "/games/game-001/src/shared/Build/Remotes.luau")
		local line = string.match(source, "Reasons:%s*([^%]]-)%]%]")
		assert(line, "Build/Remotes.luau has no Reasons line")
		local count = 0
		for code in string.gmatch(line, "[%a_]+") do
			covered(code, "Build/Remotes")
			count += 1
		end
		expect(count).toBeGreaterThan(10)
		-- the rest of FORGE-01's table (handoff 2026-10-13-forge-01-to-forge-03-refusal-codes.md)
		for remote, codes in
			{
				["Build.CanPlace / Build.Place"] = { "kingdom_eliminated" },
				["Build.Upgrade"] = { "not_found", "kingdom_eliminated" },
				["Kingdom.Gather"] = {
					"no_character",
					"too_far",
					"cooldown",
					"depleted",
					"unknown_node",
					"not_ruler",
					"kingdom_eliminated",
				},
				["Kingdom.SetJobQuota"] = { "invalid_args", "unknown_job", "not_in_match" },
			}
		do
			for _, code in codes do
				covered(code, remote)
			end
		end
		-- codes the server never sends are not vocabulary (they read as the generic sentence)
		for _, code in
			{ "territory", "overlap", "zone", "cost", "insufficient", "phase", "no_kingdom", "rate", "unknown_type" }
		do
			expect(Text.reason(code)).toBe(generic)
		end
	end)

	it("names every shortfall in resource order", function()
		expect(Text.missing({ wood = 120, stone = 60 }, { wood = 100, stone = 50 })).toBe("Need 20 Wood and 10 Stone")
		expect(Text.missing({ wood = 40 }, { wood = 40 })).toBeNil()
		expect(Text.missing({ gold = 5 }, {})).toBe("Need 5 Gold")
	end)
end)

describe("KingdomStore", function()
	it("follows Kingdom.State and ignores malformed pushes", function()
		local s = store()
		expect(s:mine().name).toBe("Emberhold")
		local fired = 0
		s.changed:connect(function()
			fired += 1
		end)
		s:applyKingdoms("nope")
		s:applyKingdoms({ kingdoms = 5 })
		s:applyTreasury({ wood = "a lot" })
		s:applyBuildings(nil, true)
		expect(fired).toBe(0)
		expect(s:mine().name).toBe("Emberhold")
		expect(s:balances().wood).toBe(100)
	end)

	it("merges Build.Buildings changes, drops destroyed buildings and replaces on a full list", function()
		local s = store()
		expect(#s:myBuildings()).toBe(4)
		s:applyBuildings(
			{ { id = 12, kingdom = "crimson", type = "house", level = 1, state = "complete", progress = 1 } },
			false
		)
		expect(s:myBuildings()[3].state).toBe("complete")
		s:applyBuildings({ { id = 13, kingdom = "crimson", type = "farm", level = 1, state = "destroyed" } }, false)
		expect(#s:myBuildings()).toBe(3)
		expect(s:count("farm")).toBe(1)
		s:applyBuildings({ { id = 10, kingdom = "crimson", type = "keep", level = 2, state = "complete" } }, true)
		expect(#s:myBuildings()).toBe(1)
		expect(s:keep().level).toBe(2)
	end)

	it("passes treasury deltas on and takes costs from Treasury.GetCosts once it answers", function()
		local s = store()
		local seen
		s.changed:connect(function(what, deltas)
			if what == "treasury" then
				seen = deltas
			end
		end)
		s:applyTreasury({ food = 120, wood = 50, stone = 50, gold = 0 }, { wood = -50 })
		expect(seen.wood).toBe(-50)
		expect(s:buildingCost("farm", 1).cost.wood).toBe(Costs.building("farm", 1).cost.wood)
		s:applyCosts({ buildings = { farm = { { cost = { wood = 7 }, buildSeconds = 3 } } } })
		expect(s:buildingCost("farm", 1).cost.wood).toBe(7)
		expect(s:buildingCost("house", 1)).toBeNil()
	end)
end)

describe("HudModel", function()
	it("builds the banner, rulers (you first) and standings", function()
		local s = store()
		local banner = HudModel.banner(s)
		expect(banner.name).toBe("Emberhold")
		expect(banner.emblem).toBe("emblem_flame")
		expect(banner.sub).toBe("Keep Lv 1 · 1 region · 12 Crown Points")
		local names = { [1] = "Sam", [2] = "Mira" }
		local members = HudModel.members(s, function(id)
			return names[id]
		end, 2)
		expect(members[1].name).toBe("Mira")
		expect(members[1].you).toBe(true)
		expect(members[2].initial).toBe("S")
		local standings = HudModel.standings(s)
		expect(standings[1].name).toBe("Frostmere")
		expect(standings[2].me).toBe(true)
		expect(standings[3].ai).toBe(true)
		expect(standings[4].rank).toBe(4)
		expect(HudModel.banner(store({ mine = false }))).toBeNil()
	end)

	it("shows a countdown, the match time or only the phase", function()
		expect(HudModel.timer({ phase = "Expansion", endsAt = 1090, startedAt = 0 }, 1000).clock).toBe("1:30")
		local untimed = HudModel.timer({ phase = "Founding", startedAt = 1000 }, 1192)
		expect(untimed.phase).toBe("Founding")
		expect(untimed.clock).toBe("3:12")
		expect(untimed.label).toBe("match time")
		expect(HudModel.timer({ phase = "Lobby", endsAt = 1010 }, 1000).label).toBe("until the match starts")
		expect(HudModel.timer({ phase = "Results", startedAt = 0 }, 1000).clock).toBeNil()
		expect(HudModel.timer(nil, 0)).toBeNil()
	end)

	it("lists only my buildings that are being built", function()
		local queue = HudModel.queue(store())
		expect(#queue).toBe(2)
		expect(queue[1].name).toBe("House")
		expect(queue[1].progress).toBeNear(0.456, 1e-9)
		expect(queue[2].waiting).toBe(true)
	end)
end)

describe("BuildModel", function()
	it("lists a tab's buildings with costs against the treasury", function()
		local view = BuildModel.menu(store(), { category = "military" })
		local ids = {}
		for _, row in view.rows do
			table.insert(ids, row.id)
		end
		expect(table.concat(ids, ",")).toBe("barracks,watchtower,wall,gate")
		expect(view.selected).toBe("barracks")
		expect(view.rows[1].ok).toBe(false)
		expect(view.rows[3].ok).toBe(true)
		expect(view.detail.cta.text).toBe("Need 20 Wood and 10 Stone")
		expect(view.detail.cta.state).toBe("disabled")
	end)

	it("offers Place with the Kit footprint and build time when affordable", function()
		local detail = BuildModel.placeDetail(store(), "farm")
		expect(detail.cta.state).toBe("ready")
		expect(detail.cta.text).toBe("Place Farm")
		expect(detail.meta).toBe("Economy · 34 × 28 studs")
		expect(detail.footprint).toBe(Vector2.new(34, 28))
		expect(detail.costs[1].have).toBe(100)
		expect(BuildModel.placeDetail(store({ treasury = false }), "farm").cta.state).toBe("disabled")
		expect(BuildModel.menu(store(), { category = "civic" }).rows[1].id).toBe("house")
	end)

	it("prices the next level, asks before a large spend and explains every refusal", function()
		local rich = store({ treasury = { food = 0, wood = 300, stone = 300, gold = 0 } })
		local keep = rich:keep()
		local up = BuildModel.upgradeDetail(rich, keep)
		expect(up.cta.text).toBe("Upgrade to Lv 2")
		expect(up.meta).toBe("Keep · Level 1 → 2")
		expect(up.needsConfirm).toBe(true)
		local richer = store({ treasury = { food = 0, wood = 3000, stone = 3000, gold = 0 } })
		expect(BuildModel.upgradeDetail(richer, richer:keep()).needsConfirm).toBe(false)
		local top = { id = 10, type = "keep", level = Costs.maxLevel("keep"), state = "complete" }
		expect(BuildModel.upgradeDetail(rich, top).cta.text).toBe("Highest level reached")
		local busy = { id = 10, type = "keep", level = 1, state = "constructing" }
		expect(BuildModel.upgradeDetail(rich, busy).cta.text).toBe("Finish building it first")
		expect(BuildModel.upgradeDetail(rich, keep, { pending = true }).cta.state).toBe("loading")
		expect(BuildModel.upgradeDetail(store(), keep).cta.state).toBe("disabled")
	end)
end)

describe("Placement", function()
	it("snaps to the grid, rotates in 90° steps and builds the server's CFrame", function()
		expect(Placement.snap(Vector3.new(60.7, 3.25, 61.2))).toBe(Vector3.new(60, 3.25, 62))
		expect(Placement.snap(Vector3.new(-0.9, 0, -3.1))).toBe(Vector3.new(0, 0, -4))
		expect(Placement.nextRotation(3)).toBe(0)
		expect(Placement.size(Vector2.new(34, 28), 1)).toBe(Vector2.new(28, 34))
		expect(Placement.size(Vector2.new(34, 28), 2)).toBe(Vector2.new(34, 28))
		local cf = Placement.cframe(Vector3.new(10, 0, 4), 1)
		local server = CFrame.new(Vector3.new(10, 0, 4)) * CFrame.Angles(0, math.pi / 2, 0)
		expect((cf.LookVector - server.LookVector).Magnitude).toBeLessThan(1e-6)
		expect(cf.Position).toBe(server.Position)
	end)

	it("Checker: one call in flight, calls spaced by the interval, the latest spot wins", function()
		local env = MockEnv.new({})
		local results, started = {}, {}
		local checker
		checker = Placement.Checker.new({
			invoke = function(_, position)
				table.insert(started, env.clock())
				env.wait(0.05) -- the round trip
				return position.X < 100, if position.X < 100 then nil else "territory"
			end,
			onResult = function(key, ok, reason)
				table.insert(results, { key = key, ok = ok, reason = reason })
			end,
			spawn = env.spawn,
			wait = env.wait,
			clock = env.clock,
		})
		for x = 1, 20 do
			checker:request("farm", Vector3.new(x * 10, 0, 0), 0)
		end
		env.mock:advance(1)
		expect(checker.calls).toBe(2)
		expect(results[#results].key).toBe(Placement.key("farm", Vector3.new(200, 0, 0), 0))
		expect(results[#results].ok).toBe(false)
		expect(results[#results].reason).toBe("territory")
		expect(started[2] - started[1]).toBeGreaterThan(0.119)
		-- 3 s of a moving mouse (a new spot every frame) stays under the remote's 10/s limit.
		local before = checker.calls
		for frame = 1, 180 do
			checker:request("farm", Vector3.new(frame, 0, 0), 0)
			env.mock:advance(1 / 60)
		end
		env.mock:advance(1)
		expect(checker.calls - before).toBeLessThan(31)
		expect(checker.calls - before).toBeGreaterThan(10)
	end)

	it("Checker: cancel drops the wish and the reply in flight; errors report not ok", function()
		local env = MockEnv.new({})
		local results = {}
		local checker = Placement.Checker.new({
			invoke = function(_, position)
				env.wait(0.05)
				if position.X == 7 then
					error("no remote")
				end
				return true
			end,
			onResult = function(key, ok, reason)
				table.insert(results, { key = key, ok = ok, reason = reason })
			end,
			spawn = env.spawn,
			wait = env.wait,
			clock = env.clock,
		})
		checker:request("farm", Vector3.new(1, 0, 0), 0)
		checker:cancel()
		env.mock:advance(1)
		expect(#results).toBe(0)
		checker:request("farm", Vector3.new(7, 0, 0), 0)
		env.mock:advance(1)
		expect(#results).toBe(1)
		expect(results[1].ok).toBe(false)
		expect(results[1].reason).toBeNil()
	end)
end)

describe("Crest emblems stay legible on every kingdom colour (D-033; FORGE-05 on #79)", function()
	it("every emblem keeps at least 3:1 against what it sits on, across the tile's gradient", function()
		for _, k in KingdomsConfig.identities do
			local color = Color3.fromRGB(k.color[1], k.color[2], k.color[3])
			local emblem = Crest.emblemColor(color)
			-- the tile is a gradient from 15 % lighter to 30 % darker (Crest); a light tile's emblem
			-- sits on the ivory roundel instead
			local backdrops = if Crest.isLight(color)
				then { Crest.backdrop(color) }
				else { color, color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3) }
			for _, backdrop in backdrops do
				local ratio = Crest.contrast(emblem, backdrop)
				if ratio < 3 then
					error(`{k.id}: emblem contrast {string.format("%.2f", ratio)} < 3 on {tostring(backdrop)}`)
				end
			end
		end
		expect(Crest.isLight(Color3.fromRGB(235, 185, 16))).toBe(true) -- gold needs the roundel
	end)

	it("gold's sun is drawn as a dark sunburst on an ivory roundel; a recolour adds or removes the roundel", function()
		local gold = Color3.fromRGB(235, 185, 16)
		local crimson = Color3.fromRGB(190, 40, 50)
		local sun = Crest.new(58, gold, "emblem_sun")
		local plate = sun:FindFirstChild("Plate")
		expect(plate).toBeTruthy()
		expect(plate.BackgroundColor3).toBe(Crest.backdrop(gold))
		local emblem = sun:FindFirstChild("Emblem")
		expect(emblem:GetAttribute("drawn")).toBe("sunburst")
		local rays = 0
		for _, child in emblem:GetChildren() do
			if string.match(child.Name, "^Ray_") then
				rays += 1
				expect(Crest.contrast(child.BackgroundColor3, Crest.backdrop(gold))).toBeGreaterThan(3)
			end
		end
		expect(rays).toBe(4) -- four bars through the centre: eight rays
		expect(plate.ZIndex < emblem.ZIndex).toBe(true) -- the roundel under the sun
		-- recolouring a crest adds the roundel once and takes it away again
		local crest = Crest.new(58, crimson, "emblem_flame")
		expect(crest:FindFirstChild("Plate")).toBeNil()
		Crest.recolor(crest, gold)
		Crest.recolor(crest, gold)
		local plates = 0
		for _, child in crest:GetChildren() do
			if child.Name == "Plate" then
				plates += 1
			end
		end
		expect(plates).toBe(1)
		expect(crest:FindFirstChild("Emblem").TextColor3).toBe(Crest.emblemColor(gold))
		Crest.recolor(crest, crimson)
		expect(crest:FindFirstChild("Plate")).toBeNil()
		expect(crest:FindFirstChild("Emblem").TextColor3).toBe(Crest.emblemColor(crimson))
	end)
end)

describe("Toast kinds with the AI Kingdoms icons (FL-0105)", function()
	it("an achievement toast shows the laurel by default, distinct from a reward's chest", function()
		-- the framework theme draws every icon as "•", so the default icon is checked here
		local laurel = Theme.icon("laurel").glyph
		expect(laurel).never.toBe(Theme.icon("chest").glyph)
		expect(Toast.new({ kind = "achievement", title = "First Farm built" }).instance.Icon.Text).toBe(laurel)
		expect(Toast.new({ kind = "reward", title = "Royal Chest opened" }).instance.Icon.Text).toBe(
			Theme.icon("chest").glyph
		)
	end)
end)
