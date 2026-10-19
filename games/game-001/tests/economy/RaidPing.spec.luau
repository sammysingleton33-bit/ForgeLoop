-- "Raid" on the rail (FL-0129 with FORGE-04's FL-0130 part 2, #183): while FeedbackWarController.alert()
-- reports enemies in our lands the rail shows a Raid button, and a tap calls goToAlert() (the aerial
-- camera to the raid). On a phone there are no keys (G / D-pad up), so the button is the way in. The
-- real KingdomHudController over a double of FORGE-04's FeedbackWarController.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")

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

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

-- FORGE-04's FeedbackWarController: alert() is the raid while it lasts, goToAlert() moves the camera.
local function warDef(state)
	return {
		name = "FeedbackWarController",
		new = function()
			return {
				alert = function()
					if state.broken then
						error("boom")
					end
					return state.alert
				end,
				goToAlert = function()
					state.went += 1
					return true
				end,
			}
		end,
	}
end

local function newWorld(opts)
	local o = opts or {}
	local state = { alert = nil, went = 0, broken = false }
	local defs = { KingdomHudDef }
	if not o.noWar then
		table.insert(defs, warDef(state))
	end
	local world = KingdomWorld.new({ clientDefinitions = defs })
	world.state = state
	world.hud = world.client:get("KingdomHudController")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function button(world)
	return find(world.hud.guis.hud, "Menu_raid")
end

describe("Raid on the rail (FL-0129, FORGE-04's raid ping)", function()
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

	it("shows while a raid lasts; a tap sends the camera there; gone when the lands are clear", function()
		world = newWorld()
		expect(button(world)).toBeNil()
		world.state.alert = { position = Vector3.new(10, 0, 5), kingdom = "azure", at = 1 }
		world:advance(1.2)
		expect(button(world)).toBeTruthy()
		expect(button(world):GetAttribute("OnboardingTarget")).toBe("HUD.RaidButton") -- FL-0137 tips (FL-0138)
		tap(button(world))
		expect(world.state.went).toBe(1)
		world.state.alert = nil
		world:advance(1.2)
		expect(button(world)).toBeNil()
	end)

	it(
		"phone 667 × 375: the button is there (no keys on a phone); no FORGE-04 controller or a failing one: none",
		function()
			world = newWorld({ width = 667, height = 375 })
			world.state.alert = { position = Vector3.new(0, 0, 0), at = 1 }
			world:advance(1.2)
			expect(button(world)).toBeTruthy()
			world.state.broken = true
			world:advance(1.2)
			expect(button(world)).toBeNil()
			world:destroy()
			world = newWorld({ noWar = true })
			world:advance(1.2)
			expect(button(world)).toBeNil()
		end
	)
end)
