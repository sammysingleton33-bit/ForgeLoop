--[[
	Doubles for the FL-0053 ruler specs (FORGE-04). Lune instances have properties but no events,
	so engine events come from MockSignal and characters are real Lune instances.

		local D = require("./RulerDoubles")
		local actions = D.actions()              -- ContextActionService-like
		actions:press("ForgeRulerSprint", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.LeftShift })
		local userInput = D.userInput()          -- InputBegan/Ended/Changed, TouchPan/Pinch/Rotate
		local player = D.player()                -- CharacterAdded / CharacterRemoving + camera zoom fields
		local character = D.character(Vector3.new(0, 3, 0))   -- Model + Humanoid + HumanoidRootPart
		local boot = D.boot(env, { ruler = opts, camera = opts, input = opts, extra = { defs } })
]]

local roblox = require("@lune/roblox")
local MockSignal = require("../../../../roblox/tests/mocks/MockSignal")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")
local RulerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerController")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")

local Instance = roblox.Instance

local D = {}

function D.actions()
	local actions = { bound = {}, titles = {}, unbound = {} }
	local function bind(name, handler, touch, priority, keys)
		actions.bound[name] = { handler = handler, touch = touch, priority = priority, keys = keys }
	end
	function actions:BindAction(name, handler, touch, ...)
		bind(name, handler, touch, nil, { ... })
	end
	function actions:BindActionAtPriority(name, handler, touch, priority, ...)
		bind(name, handler, touch, priority, { ... })
	end
	function actions:UnbindAction(name)
		self.bound[name] = nil
		table.insert(self.unbound, name)
	end
	function actions:SetTitle(name, title)
		self.titles[name] = title
	end
	-- Calls the bound handler like the engine; returns its ContextActionResult (nil if not bound).
	function actions:press(name, state, input)
		local entry = self.bound[name]
		if entry == nil then
			return nil
		end
		return entry.handler(name, state, input or {})
	end
	return actions
end

function D.userInput()
	local events = {}
	for _, name in { "InputBegan", "InputEnded", "InputChanged", "TouchPan", "TouchPinch", "TouchRotate" } do
		events[name] = MockSignal.new({ name = `UserInputService.{name}` })
	end
	return events
end

function D.player()
	return {
		Character = nil,
		CharacterAdded = MockSignal.new({ name = "Player.CharacterAdded" }),
		CharacterRemoving = MockSignal.new({ name = "Player.CharacterRemoving" }),
		CameraMinZoomDistance = 0.5,
		CameraMaxZoomDistance = 400,
	}
end

function D.character(position)
	local model = Instance.new("Model")
	model.Name = "Ruler"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = roblox.CFrame.new(position or roblox.Vector3.new(0, 3, 0))
	root.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model, humanoid, root
end

-- Loads InputMode + Ruler + RulerCamera (and `extra` defs) with injected doubles.
function D.boot(env, opts)
	opts = opts or {}
	local defs = {
		{
			name = "InputModeController",
			dependencies = {},
			new = function(e, r)
				return InputModeDef.create(e, r, opts.input)
			end,
		},
		{
			name = "RulerController",
			dependencies = { "InputModeController" },
			new = function(e, r)
				return RulerDef.create(e, r, opts.ruler)
			end,
		},
	}
	if opts.camera ~= false then
		table.insert(defs, {
			name = "RulerCameraController",
			dependencies = { "RulerController", "InputModeController" },
			new = function(e, r)
				return CameraDef.create(e, r, opts.camera)
			end,
		})
	end
	for _, def in opts.extra or {} do
		table.insert(defs, def)
	end
	return Loader.load(env, defs)
end

-- A SettingsController double: get(key) and reducedMotion().
function D.settings(values)
	return {
		name = "SettingsController",
		dependencies = {},
		new = function()
			return {
				values = values,
				get = function(self, key)
					return self.values[key]
				end,
				reducedMotion = function(self)
					return self.values.reducedMotion == true or self.values.platformReduced == true
				end,
			}
		end,
	}
end

return D
