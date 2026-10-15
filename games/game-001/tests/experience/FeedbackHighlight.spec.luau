local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local HighlightDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackHighlightController")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")

describe("FeedbackHighlightController (FL-0115, G13.6)", function()
	local env, world, entities, models, input, talk, controller

	local function rig(id, parented)
		local model = roblox.Instance.new("Model")
		model.Name = `Citizen{id}`
		if parented ~= false then
			model.Parent = world
		end
		models[id] = model
		return model
	end

	local function outlineOf(model, name)
		return model:FindFirstChild(name)
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 115, isServer = false, localPlayer = { userId = 11501 } })
		world = roblox.Instance.new("Folder")
		models = {}
		entities = {
			rendered = Signal.new(),
			released = Signal.new(),
			getModel = function(_, id)
				return models[id]
			end,
			pick = function(_, screenPos)
				return if screenPos.X == 100 then 1 elseif screenPos.X == 200 then 2 else nil
			end,
		}
		talk = { opened = Signal.new(), closed = Signal.new() }
		local registry = Loader.load(env, {
			{
				name = "EntityController",
				new = function()
					return entities
				end,
			},
			{
				name = "ConversationController",
				new = function()
					return talk
				end,
			},
			InputModeDef, -- the real one: hoverAt and select drive the outlines
			HighlightDef,
		})
		input = registry:get("InputModeController")
		controller = registry:get("FeedbackHighlightController")
	end)

	it("outlines the citizen under the mouse, follows it, and clears when the mouse leaves", function()
		local a, b = rig(1), rig(2)
		input:hoverAt(Vector2.new(100, 0))
		local light = outlineOf(a, "ForgeHoverOutline")
		assert(light, "the hovered citizen is outlined")
		expect(light.Adornee).toBe(a)
		expect(light.DepthMode).toBe(Enum.HighlightDepthMode.AlwaysOnTop) -- roofs never hide it
		input:hoverAt(Vector2.new(200, 0))
		expect(outlineOf(a, "ForgeHoverOutline")).toBeNil()
		expect(outlineOf(b, "ForgeHoverOutline")).toBe(light) -- one Highlight, moved
		input:hoverAt(Vector2.new(900, 0))
		expect(light.Parent).toBeNil()
	end)

	it("the selected citizen keeps a gold outline; hovering it shows only that one", function()
		local a, b = rig(1), rig(2)
		input:select("citizen", 1)
		local gold = outlineOf(a, "ForgeSelectedOutline")
		assert(gold, "the selected citizen is outlined")
		expect(gold.OutlineColor).toEqual(HighlightDef.STYLE.selected.outline)
		input:hoverAt(Vector2.new(100, 0)) -- over the selected citizen
		expect(outlineOf(a, "ForgeHoverOutline")).toBeNil()
		input:hoverAt(Vector2.new(200, 0)) -- over another
		assert(outlineOf(b, "ForgeHoverOutline"), "the other citizen is hovered")
		expect(outlineOf(a, "ForgeSelectedOutline")).toBe(gold)
		input:select("none", "")
		expect(gold.Parent).toBeNil()
		input:select("building", 7) -- buildings keep FORGE-03's look
		expect(controller.selectedId).toBeNil()
	end)

	it("a released rig loses its outline; the citizen's next rig (a job change) gets it back", function()
		local a = rig(1)
		input:select("citizen", 1)
		entities.released:fire(1, a) -- getModel still returns the pooled rig here
		expect(outlineOf(a, "ForgeSelectedOutline")).toBeNil()
		local again = rig(1)
		entities.rendered:fire(1, again)
		assert(outlineOf(again, "ForgeSelectedOutline"), "the new rig is outlined")
	end)

	it("no outline on a rig hidden by LOD, or while the conversation stage shows", function()
		rig(1, false)
		input:select("citizen", 1)
		expect(outlineOf(models[1], "ForgeSelectedOutline")).toBeNil()
		local b = rig(2)
		input:select("citizen", 2)
		talk.opened:fire(2, Vector3.zero)
		expect(outlineOf(b, "ForgeSelectedOutline")).toBeNil()
		talk.closed:fire(2)
		assert(outlineOf(b, "ForgeSelectedOutline"), "back after the conversation")
	end)

	it("placing a building clears the hover outline", function()
		local a = rig(1)
		input:hoverAt(Vector2.new(100, 0))
		assert(outlineOf(a, "ForgeHoverOutline"), "hovered")
		input:set("build")
		expect(outlineOf(a, "ForgeHoverOutline")).toBeNil()
	end)

	it("runs inert without EntityController (headless boot)", function()
		local bare = MockEnv.new({ seed = 116, isServer = false, localPlayer = { userId = 11502 } })
		Loader.load(bare, { InputModeDef, HighlightDef })
		bare.mock:advance(1)
		expect(bare.mock:hasLog("info", "FeedbackHighlightController: no InputModeController or EntityController")).toBe(
			true
		)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)
