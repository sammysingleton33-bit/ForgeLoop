-- Desktop fit (FL-0138 c): the HUD metrics at 1280 × 720, 1920 × 1080 and 2560 × 1440 (CoreUISafeInsets: the 58 px
-- top bar removed), and the Kingdom drawer header at the tablet breakpoint with the fourth (Rivals) tab. Rendered and
-- audited with design/ui/render/desktop-audit.py; this pins what the renders showed.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DiplomacyDoubles = require("./doubles/DiplomacyDoubles")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")

-- the drawer's own title (the panel header's Title, not a body label with the same name)
local function title(panel)
	local header = panel and panel:FindFirstChild("Header")
	return header and header:FindFirstChild("Title")
end

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
		if d.Name == name then
			return d
		end
	end
	return nil
end

-- every box stays on the logical screen, the drawer keeps clear of the rail and the top-left stack
local function fits(m)
	local d = m.drawer
	expect(d.x >= 0).toBe(true)
	expect(d.y >= m.hud.bottom).toBe(true)
	expect(d.y + d.height <= m.height - m.margin).toBe(true)
	expect(d.x + d.width <= m.width - m.rail.right - m.rail.button).toBe(true)
	local o = m.hud.objectives
	expect(o.x + o.width <= d.x - 12).toBe(true)
	expect(o.maxHeight >= 44).toBe(true)
end

describe("Desktop fit (FL-0138): Layout at the desktop sizes", function()
	it("1280 × 720 is the tablet breakpoint at scale 662/630; everything fits", function()
		local m = Layout.compute(1280, 662)
		expect(m.breakpoint).toBe("tablet")
		expect(math.abs(m.scale - 662 / 630) < 1e-9).toBe(true)
		expect(m.drawer.width).toBe(560)
		fits(m)
	end)

	it("1920 × 1080 is desktop at scale 1022/850; everything fits", function()
		local m = Layout.compute(1920, 1022)
		expect(m.breakpoint).toBe("desktop")
		expect(math.abs(m.scale - 1022 / 850) < 1e-9).toBe(true)
		expect(m.drawer.width).toBe(620)
		fits(m)
	end)

	it("2560 × 1440 clamps at scale 1.5 (1706 × 921 logical); everything fits", function()
		local m = Layout.compute(2560, 1382)
		expect(m.breakpoint).toBe("desktop")
		expect(m.scale).toBe(1.5)
		expect(m.width).toBe(1706)
		expect(m.height).toBe(921)
		fits(m)
	end)

	it("without the reputation strip the same sizes still fit", function()
		for _, size in { { 1280, 662 }, { 1920, 1022 }, { 2560, 1382 } } do
			fits(Layout.compute(size[1], size[2], { reputation = false }))
		end
	end)
end)

describe("Desktop fit (FL-0138): the Kingdom drawer header", function()
	local world, previous
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

	-- the Rivals tab shows when the server has the diplomacy remotes (FL-0129); without them, three tabs
	local function open(width, height, rivals)
		world = KingdomWorld.new({
			clientDefinitions = { KingdomHudDef },
			remotes = if rivals then DiplomacyDoubles.remotes(nil) else nil,
			services = if rivals then { DiplomacyDoubles.service } else nil,
		})
		world.hud = world.client:get("KingdomHudController")
		world.hud:setViewport(width, height)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 600)
		world:advance(0.6)
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		return find(world.hud.guis.menus, "KingdomPanel")
	end

	it(
		"tablet (1280 × 720) with four tabs: no title, so Rivals keeps clear of Close; the tabs keep their labels",
		function()
			local panel = open(1280, 662, true)
			expect(find(panel, "Tab_rivals")).toBeTruthy()
			expect(title(panel)).toBeNil()
			local labels = {}
			for _, d in find(panel, "Tab_rivals"):GetDescendants() do
				if d:IsA("TextLabel") then
					table.insert(labels, d.Text)
				end
			end
			expect(table.find(labels, "Rivals")).toBeTruthy()
		end
	)

	it("tablet with three tabs keeps the title", function()
		local panel = open(1280, 662, false)
		expect(find(panel, "Tab_rivals")).toBeNil()
		expect(title(panel).Text).toBe("Kingdom")
	end)

	it("desktop (1920 × 1080, 2560 × 1440) with four tabs keeps the title", function()
		for _, size in { { 1920, 1022 }, { 2560, 1382 } } do
			local panel = open(size[1], size[2], true)
			expect(find(panel, "Tab_rivals")).toBeTruthy()
			expect(title(panel).Text).toBe("Kingdom")
			world:destroy()
			world = nil
		end
	end)
end)
