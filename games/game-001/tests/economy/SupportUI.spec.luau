-- FL-0073 support meter end to end, headless: the real KingdomHudController and SupportMeterController talk through the
-- framework RemoteService to a FORGE-01 SupportService double (doubles/SupportDoubles: the real Arena/SupportModel on
-- fixture samples, moments from config Support.acts). Taps are simulated with Create.fire on what a player would press.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Sup = require("./doubles/SupportDoubles")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportMeterDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SupportMeterController")
local SupportMeterModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/SupportMeterModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

-- adoring: the weighted average of these is 0.2*90 + ... well above 85
local ADORING = {
	components = {
		reputation = 92,
		happiness = 90,
		stability = 88,
		morale = 90,
		loyalty = 93,
		conduct = 95,
		valour = 85,
	},
	acts = { "keepUpgraded", "fedRatioKept", "petitionFulfilled" },
}

local function find(root, name)
	if root == nil then
		return nil
	end
	if root.Name == name then
		return root
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
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	expect(Create.fire(instance, "Activated")).toBeGreaterThan(0)
end

local function newWorld(opts)
	local o = opts or {}
	local world = KingdomWorld.new({
		kingdom = o.kingdom,
		noPlayerGui = o.noPlayerGui,
		remotes = if o.dark then nil else Sup.REMOTES,
		services = if o.dark then nil else { Sup.service(o.support or ADORING) },
		clientDefinitions = { KingdomHudDef, SupportMeterDef },
	})
	world.hud = world.client:get("KingdomHudController")
	world.sup = world.client:get("SupportMeterController")
	if not o.dark then
		world.server_sup = world.server:get("SupportService")
	end
	if not o.noPlayerGui then
		world.hud:setViewport(o.width or 1920, o.height or 1022)
	end
	world:advance(0.2)
	return world
end

local function meter(world)
	return world.sup.meter and world.sup.meter.instance
end

local function panel(world)
	return find(world.hud.guis.menus, "SupportPanel")
end

-- offsets only (the test connector has no layout engine; the renders and phone-audit check the drawn pixels)
local function inside(gui, w, h)
	local x, y = gui.Position.X.Offset, gui.Position.Y.Offset
	return x >= 0 and y >= 0 and x + gui.Size.X.Offset <= w and y + gui.Size.Y.Offset <= h
end

local function overlaps(a, b)
	return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
end

describe("SupportMeterModel (pure)", function()
	it("is nil until the server sent a SupportView", function()
		expect(SupportMeterModel.view(nil)).toBeNil()
		expect(SupportMeterModel.view("garbage")).toBeNil()
		expect(SupportMeterModel.view({ tier = "loyal" })).toBeNil()
	end)

	it("says the tier in words and colour, the trend, and the points to the next tier", function()
		local v = SupportMeterModel.view({ score = 71.6, tier = "loyal", trend = 3.2, breakdown = {}, moments = {} })
		expect(v.score).toBe(72)
		expect(v.tier.name).toBe("Loyal")
		expect(v.chip).toBe("Loyal 72 ▲")
		expect(v.trend.text).toBe("Rising +3 in 5 min")
		expect(v.trend.color).toBe(Theme.color("vert"))
		expect(v.nextTier).toBe(`{Support.tiers.adoring.min - 72} points to Adoring`)
		local down = SupportMeterModel.view({ score = 30, tier = "restless", trend = -2.6 })
		expect(down.trend.arrow).toBe("▼")
		expect(down.trend.text).toBe("Falling −3 in 5 min")
		local steady = SupportMeterModel.view({ score = 30, tier = "restless", trend = 0.4 })
		expect(steady.trend.arrow).toBe("▬")
		expect(steady.trend.text).toBe("Steady")
		expect(SupportMeterModel.view({ score = 91, tier = "adoring" }).nextTier).toBeNil()
		expect(SupportMeterModel.view({ score = 64, tier = "divided" }).nextTier).toBe("1 point to Loyal")
	end)

	it("lists the seven components in config order with their config weights; a missing one shows a dash", function()
		local v = SupportMeterModel.view({ score = 50, tier = "divided", breakdown = { happiness = 81.4 } })
		expect(#v.components).toBe(#Support.componentOrder)
		for i, id in Support.componentOrder do
			expect(v.components[i].id).toBe(id)
			expect(v.components[i].weight).toBe(Support.components[id].weight)
		end
		expect(v.components[2].value).toBe(81)
		expect(v.components[2].bar).toBeNear(0.814, 1e-6)
		expect(v.components[1].value).toBeNil()
		expect(v.components[1].bar).toBe(0)
	end)

	it("puts the newest moments first, at most MOMENTS, and drops blank ones", function()
		local moments = {}
		for i = 1, 9 do
			table.insert(moments, { t = i, component = "conduct", delta = if i % 2 == 0 then 2 else -3, text = `m{i}` })
		end
		table.insert(moments, { t = 100, component = "conduct", delta = 1, text = "" })
		local v = SupportMeterModel.view({ score = 50, tier = "divided", moments = moments })
		expect(#v.moments).toBe(SupportMeterModel.MOMENTS)
		expect(v.moments[1].text).toBe("m9")
		expect(v.moments[1].deltaText).toBe("−3")
		expect(v.moments[1].positive).toBe(false)
		expect(v.moments[2].deltaText).toBe("+2")
		expect(v.moments[1].component).toBe("Your conduct")
		expect(v.noMoments).toBeNil()
		expect(SupportMeterModel.view({ score = 50, tier = "divided" }).noMoments).toBeTruthy()
	end)

	it("the arena line comes from config: slots and the tier's blessing", function()
		local v = SupportMeterModel.view({ score = 91, tier = "adoring", slots = 3 })
		expect(v.slotsText).toBe("3 perk slots in the arena")
		expect(v.blessing).toBeTruthy()
		local r = SupportMeterModel.view({ score = 25, tier = "restless", slots = 1 })
		expect(r.slotsText).toBe("1 perk slot in the arena")
		expect(r.blessing).toBeNil()
	end)
end)

describe("Support meter (desktop)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("shows the tier in words, the score and the trend from the server's SupportView", function()
		local sv = world.server_sup:view(world.player)
		expect(sv.tier).toBe("adoring")
		local b = meter(world)
		expect(b).toBeTruthy()
		expect(b.Parent).toBe(world.hud.roots.hud)
		expect(b:GetAttribute("tier")).toBe("adoring")
		expect(b:GetAttribute("score")).toBe(math.floor(sv.score + 0.5))
		expect(find(b, "Label").Text).toBe(`Adoring {math.floor(sv.score + 0.5)}`)
		expect(find(b, "Kicker").Text).toBe("Support")
		expect(b:GetAttribute("OnboardingTarget")).toBe("HUD.Support")
	end)

	it("sits where Layout puts it, under the stack, and the drawer opens below it", function()
		local m = world.hud:metrics()
		local r = m.hud.support
		expect(r).toBeTruthy()
		local b = meter(world)
		expect(b.Position.X.Offset).toBe(r.x)
		expect(b.Position.Y.Offset).toBe(r.y)
		expect(b.Size.Y.Offset).toBe(r.height)
		expect(m.hud.bottom).toBe(r.y + r.height)
		tap(b)
		local p = panel(world)
		expect(p).toBeTruthy()
		expect(p.Position.Y.Offset).toBe(m.drawer.y)
		expect(m.drawer.y).toBeGreaterThan(r.y + r.height - 1)
	end)

	it("a tap opens the breakdown; a second tap closes it", function()
		tap(meter(world))
		expect(world.hud.state.menu).toBe("support")
		expect(panel(world)).toBeTruthy()
		tap(meter(world))
		expect(world.hud.state.menu).toBeNil()
		expect(panel(world)).toBeNil()
	end)

	it(
		"the breakdown: tier chip, trend, arena line, seven components with weights and values, latest moments",
		function()
			world.sup:open()
			local p = panel(world)
			local sv = world.server_sup:view(world.player)
			local all = texts(p)
			expect(all).toContain(`Adoring support · {math.floor(sv.score + 0.5)}`)
			expect(all).toContain("3 perk slots in the arena")
			expect(find(p, "Tier"):GetAttribute("tier")).toBe("adoring")
			for _, id in Support.componentOrder do
				local row = find(p, "Component_" .. id)
				expect(row).toBeTruthy()
				expect(row:GetAttribute("value")).toBe(math.floor(sv.breakdown[id] + 0.5))
				expect(find(row, "Weight").Text).toBe(`{Support.components[id].weight} %`)
			end
			-- newest first: the double's acts are oldest first
			expect(find(p, "Moment_1") and find(find(p, "Moment_1"), "Text").Text).toBe(
				Support.acts.petitionFulfilled.text
			)
			expect(find(find(p, "Moment_1"), "Delta").Text).toBe(`+{Support.acts.petitionFulfilled.delta}`)
			expect(find(p, "Moment_3")).toBeTruthy()
			expect(find(p, "NoMoments")).toBeNil()
		end
	)

	it("a pushed act updates the chip and puts the moment on top of the open breakdown", function()
		world.sup:open()
		local before = world.server_sup.pushes
		world.server_sup:act("starvation")
		world:advance(0.1)
		expect(world.server_sup.pushes).toBe(before + 1)
		local sv = world.server_sup:view(world.player)
		expect(meter(world):GetAttribute("score")).toBe(math.floor(sv.score + 0.5))
		local top = find(panel(world), "Moment_1")
		expect(find(top, "Text").Text).toBe(Support.acts.starvation.text)
		expect(find(top, "Delta").Text).toBe(`−{-Support.acts.starvation.delta}`)
		expect(find(top, "Delta").TextColor3).toBe(Theme.color("gules"))
	end)

	it("a falling score changes the tier and the trend arrow", function()
		local low = {}
		for _, id in Support.componentOrder do
			low[id] = 10
		end
		for _ = 1, 6 do -- five minutes of a failing kingdom after a good match, a sample every 50 s
			world.server_sup:set(low)
			world:advance(50)
		end
		world.server_sup:push(world.player)
		world:advance(0.1)
		local sv = world.server_sup:view(world.player)
		expect(sv.tier).never.toBe("adoring")
		expect(sv.trend).toBeLessThan(-SupportMeterModel.TREND_STEP)
		expect(meter(world):GetAttribute("tier")).toBe(sv.tier)
		expect(meter(world):GetAttribute("trend")).toBe("down")
		expect(find(meter(world), "Label").Text).toBe(`{world.sup.view.tier.name} {math.floor(sv.score + 0.5)}`)
	end)

	it("treasury pushes leave the chip and the open breakdown alone (in-place HUD)", function()
		world.sup:open()
		local b, p = meter(world), panel(world)
		world.treasury:deposit("crimson", "food", 5, "sup:food", "test")
		world:advance(0.1)
		expect(meter(world)).toBe(b)
		expect(panel(world)).toBe(p)
	end)

	it("ignores a malformed push and keeps what the server said before", function()
		local score = meter(world):GetAttribute("score")
		world.remotes:fire("Kingdom.Support", world.player, "garbage")
		world.remotes:fire("Kingdom.Support", world.player, { tier = "hostile" })
		world:advance(0.1)
		expect(meter(world):GetAttribute("score")).toBe(score)
		expect(meter(world):GetAttribute("tier")).toBe("adoring")
	end)

	it("after destroy a push builds nothing", function()
		local view = world.server_sup:view(world.player)
		world.sup:destroy()
		world.server_sup:act("starvation")
		world:advance(0.1)
		expect(meter(world)).toBeNil()
		local before = world.sup.view
		world.sup:apply(view, true) -- a push already in flight when the controller went
		expect(meter(world)).toBeNil()
		expect(world.sup.view).toBe(before)
	end)
end)

describe("Support meter edge cases", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("dark until Kingdom.Support is served: no chip, no room in Layout, no request", function()
		local world = newWorld({ dark = true })
		expect(world.hud:hasRemote("Kingdom.GetSupport")).toBe(false)
		expect(meter(world)).toBeNil()
		expect(world.hud:metrics().hud.support).toBeNil()
		expect(world.hud.state.support).never.toBe(true)
		-- not even asked: an undeclared remote is never invoked
		local asked = 0
		local remotes = world.hud.remotes
		local invoke = remotes.invoke
		remotes.invoke = function(self, name, ...)
			if name == "Kingdom.GetSupport" then
				asked += 1
			end
			return invoke(self, name, ...)
		end
		world.sup:refresh()
		remotes.invoke = invoke
		expect(asked).toBe(0)
		world.sup:open()
		expect(panel(world)).toBeNil()
		world:destroy()
	end)

	it("hides the chip without a kingdom and fills it after a late join", function()
		local world = newWorld({ kingdom = false })
		expect(meter(world)).toBeNil()
		world.kingdoms:join(world.player, "azure", nil, true)
		world:advance(0.2)
		expect(meter(world)).toBeTruthy()
		expect(meter(world):GetAttribute("tier")).toBe("adoring")
		world:destroy()
	end)

	it("an empty match says nothing has moved support yet", function()
		local world = newWorld({ support = { samples = false } })
		world.sup:open()
		expect(find(panel(world), "NoMoments")).toBeTruthy()
		expect(find(panel(world), "Moment_1")).toBeNil()
		world:destroy()
	end)

	it("does not yield in start(): the chip appears once the PlayerGui does", function()
		local world = newWorld({ noPlayerGui = true })
		expect(meter(world)).toBeNil()
		local playerGui = world.env.newInstance("PlayerGui")
		playerGui.Parent = world.player
		world:advance(0.3)
		world.hud:setViewport(1920, 1022)
		world:advance(0.1)
		expect(meter(world)).toBeTruthy()
		world:destroy()
	end)
end)

describe("Support meter phone fit (667 × 375, L7)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld({ width = 667, height = 375 })
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("the chip fits on screen, keeps a readable label and drops the kicker", function()
		local m = world.hud:metrics()
		expect(m.breakpoint).toBe("phone")
		local b = meter(world)
		expect(b).toBeTruthy()
		expect(find(b, "Kicker")).toBeNil()
		expect(find(b, "Label").Text).toContain("Adoring")
		expect(inside(b, m.width, m.height)).toBe(true)
		local r = m.hud.support
		for _, other in { m.hud.objectives, m.hud.pills } do
			if other and other.width and other.height then
				expect(overlaps(r, other)).toBe(false)
			end
		end
	end)

	it("the breakdown fits the drawer and every component row stays on screen when scrolled to", function()
		world.sup:open()
		local m = world.hud:metrics()
		local p = panel(world)
		expect(p).toBeTruthy()
		expect(inside(p, m.width, m.height)).toBe(true)
		local body = find(p, "Body")
		expect(body:IsA("ScrollingFrame")).toBe(true)
		for _, id in Support.componentOrder do
			expect(find(p, "Component_" .. id)).toBeTruthy()
		end
		expect(p.Size.Y.Offset).toBeGreaterThan(150) -- room to read, scrolled
	end)
end)
