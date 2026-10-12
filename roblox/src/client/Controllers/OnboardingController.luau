--!strict
--[[
	OnboardingController (FORGE-04, client) — shows the current tutorial step and reports what the
	player did. The server (OnboardingService) decides progress; this controller never completes a
	step on its own.

		OnboardingController:report(action) -> boolean   -- UI code reports client actions, e.g. FORGE-03's HUD:
		                                                  -- "ResourceInspected" (resource bar tapped), "GoalAcknowledged"
		OnboardingController:skip()                      -- the always-visible Skip button calls this
		OnboardingController.state                       -- last snapshot from Experience.OnboardingState
		OnboardingController.changed: Signal (state)

	View (thin, built with Instances until FORGE-03's Panel/Button land; then only _render changes):
	- one small card at the top centre (ScreenGui DisplayOrder 60, the onboarding band of interfaces §9):
	  title, one line of body, "n/total", and a Skip button with a 44 px touch target; never modal,
	  never captures input
	- world targets (hint.target.kind = "world"): a Highlight plus a bobbing arrow over the first
	  instance tagged hint.target.tag; UI targets: a UIStroke on the GuiObject whose OnboardingTarget
	  attribute equals hint.target.name
	- escalated (the player is stuck): the card border and arrow turn gold
	Detectors (client actions the server whitelists in config.clientActions):
		RulerMoved / CharacterMoved   the character moved MOVE_STUDS from where the step began
		ReachedCastle                 within REACH_STUDS of an instance tagged "OnboardingCastle"
	Idle hints: after the tutorial, VFXController.idleNudge (dead air in a match) shows a phase hint
	for IDLE_HINT_SEC when the showHints setting is on.
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local OnboardingController = {}
OnboardingController.__index = OnboardingController

local Def = { name = "OnboardingController", dependencies = { "SettingsController" } }

Def.MOVE_STUDS = 8
Def.REACH_STUDS = 15
Def.POLL_SEC = 0.25
Def.IDLE_HINT_SEC = 6
Def.IDLE_HINTS = table.freeze({
	Opening = "Build another farm: more food means more citizens.",
	Development = "Upgrade your Town Hall to unlock new buildings.",
	Competition = "Rivals are near. Train soldiers at the Barracks.",
	Conflict = "Defend your walls, or strike a rival's town.",
	Resolution = "Hold your lands to win the crown.",
})

local MOVE_ACTIONS = { RulerMoved = true, CharacterMoved = true }
local GOLD = Color3.fromRGB(255, 207, 92)
local INK = Color3.fromRGB(245, 240, 228)
local PANEL = Color3.fromRGB(38, 30, 22)

function Def.create(env: any, registry: any, options: { [string]: any }?)
	local opts = options or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_settings = registry:get("SettingsController"),
		_playerGui = opts.playerGui,
		_links = {},
		_connections = {},
		_view = nil :: any,
		_marks = {},
		_detectorToken = 0,
		state = nil :: any,
		changed = Signal.new(),
	}, OnboardingController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function OnboardingController:start()
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Experience.OnboardingState", function(state)
			self:apply(state)
		end)
	)
	local vfx = self._registry:find("VFXController")
	if vfx and vfx.idleNudge then
		table.insert(
			self._connections,
			vfx.idleNudge:connect(function(phase)
				self:showIdleHint(phase)
			end)
		)
	end
end

function OnboardingController:destroy()
	self._detectorToken += 1
	for _, link in self._links do
		link:disconnect()
	end
	for _, connection in self._connections do
		connection:disconnect()
	end
	self:_clearMarks()
	if self._view then
		self._view.gui:Destroy()
		self._view = nil
	end
	self.changed:disconnectAll()
end

-- ------------------------------------------------------------------ state from the server

function OnboardingController:apply(state: any)
	if type(state) ~= "table" then
		return
	end
	self.state = state
	self:_render()
	self:_startDetector()
	self.changed:fire(state)
end

function OnboardingController:report(action: string): boolean
	local state = self.state
	if state == nil or state.done or type(action) ~= "string" then
		return false
	end
	return RemoteLink.send(self._env, "Experience.OnboardingAction", state.flowId, action)
end

function OnboardingController:skip()
	local state = self.state
	if state == nil or state.done then
		return
	end
	RemoteLink.send(self._env, "Experience.OnboardingSkip", state.flowId)
	-- hide at once; the server's snapshot (skipped = true) follows
	local hidden = table.clone(state)
	hidden.done, hidden.skipped = true, true
	self:apply(hidden)
end

-- ------------------------------------------------------------------ detectors

local function rootOf(player: any): any
	local character = player and player.Character
	if character == nil then
		return nil
	end
	return character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
end

function OnboardingController:_startDetector()
	self._detectorToken += 1
	local token = self._detectorToken
	local state = self.state
	local action = if state and not state.done then state.clientAction else nil
	if action == nil or (not MOVE_ACTIONS[action] and action ~= "ReachedCastle") then
		return
	end
	local env = self._env
	env.spawn(function()
		local origin = nil
		while self._detectorToken == token do
			local root = rootOf(env.Players.LocalPlayer)
			if root then
				local position = root.Position
				if MOVE_ACTIONS[action] then
					origin = origin or position
					if (position - origin).Magnitude >= Def.MOVE_STUDS then
						self:report(action)
						return
					end
				else
					for _, castle in env.CollectionService:GetTagged("OnboardingCastle") do
						local target = if castle:IsA("Model") then castle.PrimaryPart else castle
						if target and (target.Position - position).Magnitude <= Def.REACH_STUDS then
							self:report(action)
							return
						end
					end
				end
			end
			env.wait(Def.POLL_SEC)
		end
	end)
end

-- ------------------------------------------------------------------ view

function OnboardingController:_gui(): any
	if self._playerGui then
		return self._playerGui
	end
	local player = self._env.Players.LocalPlayer
	return if player then player:FindFirstChildOfClass("PlayerGui") else nil
end

local function label(env: any, name: string, text: string, size: number, bold: boolean): any
	local l = env.newInstance("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = INK
	l.TextSize = size
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	return l
end

function OnboardingController:_build(): any
	local env = self._env
	local parent = self:_gui()
	if parent == nil then
		return nil
	end
	local gui = env.newInstance("ScreenGui")
	gui.Name = "ForgeOnboarding"
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	gui.Parent = parent
	local card = env.newInstance("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 72)
	card.Size = UDim2.new(0.92, 0, 0, 88)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.1
	card.Parent = gui
	local limit = env.newInstance("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 88)
	limit.Parent = card
	local stroke = env.newInstance("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Transparency = 0.6
	stroke.Parent = card
	local title = label(env, "Title", "", 18, true)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -120, 0, 24)
	title.Parent = card
	local body = label(env, "Body", "", 14, false)
	body.Position = UDim2.fromOffset(14, 34)
	body.Size = UDim2.new(1, -120, 0, 44)
	body.Parent = card
	local counter = label(env, "Counter", "", 13, false)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.Position = UDim2.new(1, -104, 0, 8)
	counter.Size = UDim2.fromOffset(90, 20)
	counter.Parent = card
	local skip = env.newInstance("TextButton")
	skip.Name = "Skip"
	skip.Text = "Skip tutorial"
	skip.TextSize = 14
	skip.Font = Enum.Font.GothamBold
	skip.TextColor3 = INK
	skip.BackgroundColor3 = Color3.fromRGB(70, 58, 44)
	skip.Position = UDim2.new(1, -104, 1, -52)
	skip.Size = UDim2.fromOffset(92, 44) -- touch target >= 44 px (interfaces §9)
	skip.Parent = card
	pcall(function() -- GuiButton.Activated: real in Roblox; Lune instances have no events
		skip.Activated:Connect(function()
			self:skip()
		end)
	end)
	return { gui = gui, card = card, stroke = stroke, title = title, body = body, counter = counter, skip = skip }
end

function OnboardingController:_clearMarks()
	for _, mark in self._marks do
		mark:Destroy()
	end
	table.clear(self._marks)
end

function OnboardingController:_mark(target: any, escalated: boolean)
	local env = self._env
	if target == nil then
		return
	end
	if target.kind == "world" then
		local tagged = env.CollectionService:GetTagged(target.tag)
		local instance = tagged[1]
		if instance == nil then
			return
		end
		local highlight = env.newInstance("Highlight")
		highlight.Name = "ForgeOnboardingHighlight"
		highlight.FillTransparency = 0.8
		highlight.OutlineColor = if escalated then GOLD else INK
		highlight.Adornee = instance
		highlight.Parent = instance
		table.insert(self._marks, highlight)
		local adornee = if instance:IsA("Model") then instance.PrimaryPart else instance
		if adornee then
			local arrow = env.newInstance("BillboardGui")
			arrow.Name = "ForgeOnboardingArrow"
			arrow.Size = UDim2.fromOffset(48, 48)
			arrow.StudsOffset = Vector3.new(0, 6, 0)
			arrow.AlwaysOnTop = true
			arrow.Adornee = adornee
			local glyph = env.newInstance("TextLabel")
			glyph.BackgroundTransparency = 1
			glyph.Size = UDim2.fromScale(1, 1)
			glyph.Text = "▼"
			glyph.TextScaled = true
			glyph.TextColor3 = if escalated then GOLD else INK
			glyph.Parent = arrow
			arrow.Parent = adornee
			table.insert(self._marks, arrow)
		end
	elseif target.kind == "ui" then
		local root = self:_gui()
		if root == nil then
			return
		end
		for _, item in root:GetDescendants() do
			if item:IsA("GuiObject") and item:GetAttribute("OnboardingTarget") == target.name then
				local stroke = env.newInstance("UIStroke")
				stroke.Name = "ForgeOnboardingStroke"
				stroke.Thickness = if escalated then 4 else 3
				stroke.Color = GOLD
				stroke.Parent = item
				table.insert(self._marks, stroke)
				break
			end
		end
	end
end

function OnboardingController:_render()
	local state = self.state
	self:_clearMarks()
	if state == nil or state.done or state.hint == nil then
		if self._view then
			self._view.gui.Enabled = false
		end
		return
	end
	self._view = self._view or self:_build()
	local view = self._view
	if view == nil then
		return
	end
	view.gui.Enabled = true
	view.title.Text = state.hint.title or ""
	view.body.Text = state.hint.body or ""
	view.counter.Text = `{state.step}/{state.total}`
	view.stroke.Color = if state.escalated then GOLD else INK
	view.stroke.Transparency = if state.escalated then 0 else 0.6
	self:_mark(state.hint.target, state.escalated)
end

function OnboardingController:showIdleHint(phase: string): boolean
	local text = Def.IDLE_HINTS[phase]
	if text == nil or self._settings:get("showHints") == false then
		return false
	end
	if self.state and not self.state.done then
		return false -- the tutorial card is already guiding
	end
	local notifications = self._registry:find("NotificationController")
	if notifications then
		notifications:show({ title = text, kind = "info", durationSec = Def.IDLE_HINT_SEC })
		return true
	end
	self._env.log("info", "onboarding: idle hint (NotificationController not loaded)", { phase = phase })
	return false
end

return Def
