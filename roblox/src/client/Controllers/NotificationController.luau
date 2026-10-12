--!strict
--[[
	NotificationController (FORGE-04, client, FL-0027; interfaces §8): every transient toast and every
	celebration moment goes through here.

		NotificationController:show({ title, body?, kind?, key?, durationSec?, icon?, important? }) -> (Item?, how)
		    kind: "info" | "success" | "warning" | "error" | "reward" | "achievement" (default "info")
		    key:  repeats with the same key coalesce into one toast with a "×N" badge
		NotificationController:celebrate(kind, payload?) -> boolean
		    FORGE-03's reward reveal calls celebrate("reward", { rarity, itemId, qty }) at its end;
		    FORGE-04 never reacts to RewardRolled itself, so a reward is never celebrated twice.
		NotificationController:registerCelebration(kind, spec) -> { string }   -- games add moments (FL-0062)
		NotificationController:dismiss(id)
		NotificationController.shown: Signal (item)     .celebrated: Signal (kind, payload)
		NotificationController.queue                     -- Experience/NotificationQueue (rules and stats)

	Queue rules (priority, stack of 3, coalescing, the "important" filter): Experience/NotificationQueue.
	The `notifications` setting ("all" | "important") is applied live.

	Celebrations: CELEBRATIONS below, plus whatever a game registers. A spec is
		{ sound: string?, vfx: string?, toast: { kind, title, body? }?, cooldownSec: number? }
	where title and body may contain {field} placeholders filled from the payload's string and number
	fields (any other value leaves the placeholder empty). Sounds play through AudioController and
	effects through VFXController (both found with registry:find, so either may be absent). The same
	kind within cooldownSec (default 1 s) is coalesced into the first one, so two systems reporting
	one moment never give a double fanfare. Every celebration has a visual: a spec with a sound and
	neither a toast nor a vfx is rejected (accessibility rule, as in CueDirector).

	View: FORGE-03's UI kit (`UI/Components/Toast`, FL-0020). ScreenGui "ForgeNotifications",
	DisplayOrder 70 (the notifications band, interfaces §9), ScreenInsets CoreUISafeInsets, a stack in
	the top right at most 300 px or 46 % of the screen wide, newest on top. Each card is a Toast (kind
	accent and icon, title, body, the ×N badge); a change of title, body or count rebuilds the card,
	since Toast has no update API. A transparent "Dismiss" button over the card makes a tap dismiss
	it. A toast never blocks input elsewhere.
]]

local NotificationQueue = require("@game/ReplicatedStorage/Forge/Experience/NotificationQueue")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Toast = require("@game/ReplicatedStorage/Forge/UI/Components/Toast")

local NotificationController = {}
NotificationController.__index = NotificationController

local Def = { name = "NotificationController", dependencies = { "SettingsController" } }

Def.DISPLAY_ORDER = 70
Def.TICK_SEC = 0.1
Def.WIDTH = 300
Def.KIND_SOUND = table.freeze({
	info = "notify.info",
	success = "notify.info",
	warning = "notify.warning",
	error = "notify.warning",
	reward = "notify.reward",
	achievement = "notify.achievement",
})

-- Factory celebrations (every game). Game moments are added with registerCelebration.
Def.CELEBRATIONS = table.freeze({
	reward = table.freeze({
		sound = "reward.{rarity}",
		fallbackSound = "notify.reward",
		vfx = "reward.burst",
		toast = table.freeze({ kind = "reward", title = "{title}", body = "{body}" }),
	}),
	achievement = table.freeze({
		sound = "notify.achievement",
		vfx = "levelup.column",
		toast = table.freeze({ kind = "achievement", title = "{title}", body = "{body}" }),
	}),
	levelUp = table.freeze({
		sound = "celebrate.levelup",
		vfx = "levelup.column",
		toast = table.freeze({ kind = "achievement", title = "{title}", body = "{body}" }),
	}),
	onboardingComplete = table.freeze({
		sound = "onboarding.complete",
		vfx = "reward.burst",
		toast = table.freeze({ kind = "achievement", title = "Tutorial complete", body = "{body}" }),
	}),
	streak = table.freeze({
		sound = "celebrate.streak",
		toast = table.freeze({ kind = "reward", title = "{title}", body = "{body}" }),
	}),
})

local function fill(template: any, payload: any): string?
	if type(template) ~= "string" then
		return nil
	end
	local text = string.gsub(template, "{(%w+)}", function(field)
		local value = if type(payload) == "table" then payload[field] else nil
		if type(value) == "string" or type(value) == "number" then
			return tostring(value)
		end
		return ""
	end)
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return if text == "" then nil else text
end

-- A sound or effect id from a template: nil when any placeholder has no value ("reward.{rarity}"
-- without a rarity must not become the id "reward.").
local function fillId(template: any, payload: any): string?
	if type(template) ~= "string" then
		return nil
	end
	local missing = false
	local id = string.gsub(template, "{(%w+)}", function(field)
		local value = if type(payload) == "table" then payload[field] else nil
		if type(value) == "string" or type(value) == "number" then
			return string.lower(tostring(value))
		end
		missing = true
		return ""
	end)
	return if missing then nil else id
end

-- Problems with a celebration spec (empty = valid).
function Def.validateCelebration(kind: any, spec: any): { string }
	local problems = {}
	if type(kind) ~= "string" or kind == "" then
		table.insert(problems, "celebration kind must be a non-empty string")
	end
	if type(spec) ~= "table" then
		table.insert(problems, `celebration {tostring(kind)}: spec must be a table`)
		return problems
	end
	local hasVisual = spec.vfx ~= nil or spec.toast ~= nil
	if spec.sound ~= nil and not hasVisual then
		table.insert(problems, `celebration {kind}: sound-only; add a toast or a vfx (accessibility rule)`)
	end
	if spec.sound == nil and not hasVisual then
		table.insert(problems, `celebration {kind}: needs a toast, a vfx or a sound with one of them`)
	end
	if spec.toast ~= nil and (type(spec.toast) ~= "table" or type(spec.toast.title) ~= "string") then
		table.insert(problems, `celebration {kind}: toast needs a title`)
	end
	if spec.cooldownSec ~= nil and (type(spec.cooldownSec) ~= "number" or spec.cooldownSec < 0) then
		table.insert(problems, `celebration {kind}: cooldownSec must be >= 0`)
	end
	return problems
end

-- opts (specs): { playerGui, config (NotificationQueue config) }
function Def.create(env: any, registry: any, options: { [string]: any }?)
	local opts = options or {}
	local celebrations = table.clone(Def.CELEBRATIONS) -- games register more per controller
	local self = setmetatable({
		_env = env,
		_registry = registry,
		_settings = registry:get("SettingsController"),
		_playerGui = opts.playerGui,
		_celebrations = celebrations,
		_lastCelebration = {},
		_views = {},
		_connections = {},
		_running = false,
		_root = nil :: any,
		queue = NotificationQueue.new({ now = env.clock, config = opts.config }),
		shown = Signal.new(),
		celebrated = Signal.new(),
	}, NotificationController)
	return self
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function NotificationController:start()
	local settings = self._settings
	self.queue:setFilter(settings:get("notifications") or "all")
	table.insert(
		self._connections,
		settings.changed:connect(function(key, value)
			if key == "notifications" then
				self.queue:setFilter(value)
			end
		end)
	)
	self._running = true
	local env = self._env
	env.spawn(function()
		while self._running do
			self:_tick()
			env.wait(Def.TICK_SEC)
		end
	end)
end

function NotificationController:destroy()
	self._running = false
	for _, connection in self._connections do
		connection:disconnect()
	end
	table.clear(self._connections)
	if self._root then
		self._root.gui:Destroy()
		self._root = nil
	end
	table.clear(self._views)
	self.queue:clear()
	self.shown:disconnectAll()
	self.celebrated:disconnectAll()
end

function NotificationController:show(spec: any): (any, string)
	if type(spec) ~= "table" then
		return nil, "invalid"
	end
	local item, how = self.queue:push(spec)
	if item ~= nil and how ~= "coalesced" then
		item.silent = spec.silent == true
	end
	if how == "shown" or how == "replaced" then
		self:_announce(item, spec.silent == true)
	elseif how == "coalesced" then
		self:_refresh(item)
	end
	if how == "replaced" then
		self:_sync()
	end
	return item, how
end

function NotificationController:dismiss(id: number): boolean
	local removed = self.queue:dismiss(id)
	if removed then
		self:_sync()
		self:_tick()
	end
	return removed
end

function NotificationController:registerCelebration(kind: string, spec: any): { string }
	local problems = Def.validateCelebration(kind, spec)
	if #problems == 0 then
		self._celebrations[kind] = spec
	end
	return problems
end

function NotificationController:celebrate(kind: string, payload: any): boolean
	local spec = self._celebrations[kind]
	if spec == nil then
		self._env.log(
			"warn",
			`NotificationController: unknown celebration '{tostring(kind)}'`,
			{ kind = tostring(kind) }
		)
		return false
	end
	local now = self._env.clock()
	local last = self._lastCelebration[kind]
	if last ~= nil and now - last < (spec.cooldownSec or 1) then
		return false
	end
	self._lastCelebration[kind] = now
	local position = if type(payload) == "table" and typeof(payload.position) == "Vector3"
		then payload.position
		else nil

	local audio = self._registry:find("AudioController")
	if audio and spec.sound then
		local id = fillId(spec.sound, payload)
		local voice = if id then audio:play(id) else nil
		if voice == nil and spec.fallbackSound then
			audio:play(spec.fallbackSound)
		end
	end
	local vfx = self._registry:find("VFXController")
	if vfx and spec.vfx then
		vfx:play(spec.vfx, { position = position or self:_rulerPosition() })
	end
	if spec.toast then
		local title = fill(spec.toast.title, payload) or fill(payload and payload.title, payload)
		if title then
			-- the celebration already played its own sound: the toast stays silent
			self:show({
				title = title,
				body = fill(spec.toast.body, payload),
				kind = spec.toast.kind or "achievement",
				key = `celebrate:{kind}:{title}`,
				important = true,
				silent = true,
			})
		end
	end
	self.celebrated:fire(kind, payload)
	return true
end

-- ------------------------------------------------------------------ internals

function NotificationController:_rulerPosition(): Vector3?
	local ok, position = pcall(function()
		local character = self._env.Players.LocalPlayer.Character
		local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
		return root and root.CFrame.Position
	end)
	return if ok then position else nil
end

function NotificationController:_announce(item: any, silent: boolean)
	if not silent then
		local audio = self._registry:find("AudioController")
		if audio then
			audio:play(Def.KIND_SOUND[item.kind] or "notify.info")
		end
	end
	self:_sync()
	self.shown:fire(item)
end

function NotificationController:_tick()
	local shown, hidden = self.queue:tick()
	if #shown == 0 and #hidden == 0 then
		return
	end
	self:_sync()
	for _, item in shown do
		local audio = self._registry:find("AudioController")
		if audio and not item.silent then
			audio:play(Def.KIND_SOUND[item.kind] or "notify.info")
		end
		self.shown:fire(item)
	end
end

-- ------------------------------------------------------------------ view

function NotificationController:_gui(): any
	if self._playerGui then
		return self._playerGui
	end
	local ok, gui = pcall(function()
		local player = self._env.Players.LocalPlayer
		return if player then player:FindFirstChildOfClass("PlayerGui") else nil
	end)
	return if ok then gui else nil
end

function NotificationController:_rootView(): any
	if self._root then
		return self._root
	end
	local parent = self:_gui()
	if parent == nil then
		return nil
	end
	local env = self._env
	local gui = env.newInstance("ScreenGui")
	gui.Name = "ForgeNotifications"
	gui.DisplayOrder = Def.DISPLAY_ORDER
	gui.ResetOnSpawn = false
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	gui.Parent = parent
	local stack = env.newInstance("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -12, 0, 12)
	stack.Size = UDim2.new(0.46, 0, 1, -24)
	stack.Parent = gui
	local limit = env.newInstance("UISizeConstraint")
	limit.MaxSize = Vector2.new(Def.WIDTH, math.huge)
	limit.Parent = stack
	local list = env.newInstance("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = stack
	self._root = { gui = gui, stack = stack }
	return self._root
end

local function signature(item: any): string
	return `{item.title}\0{item.body or ""}\0{item.count}`
end

function NotificationController:_buildToast(item: any, parent: any, layoutOrder: number): any
	local toast = Toast.new({
		kind = item.kind,
		title = item.title,
		body = item.body,
		icon = item.icon,
		count = item.count,
		width = Def.WIDTH,
		layoutOrder = layoutOrder,
	})
	local frame = toast.instance
	frame.Name = `Toast_{item.id}`
	local dismiss = self._env.newInstance("TextButton") -- a tap dismisses the card
	dismiss.Name = "Dismiss"
	dismiss.Text = ""
	dismiss.BackgroundTransparency = 1
	dismiss.AutoButtonColor = false
	dismiss.Size = UDim2.fromScale(1, 1)
	dismiss.ZIndex = 5
	dismiss.Parent = frame
	pcall(function() -- GuiButton.Activated: real in Roblox; Lune instances have no events
		dismiss.Activated:Connect(function()
			self:dismiss(item.id)
		end)
	end)
	frame.Parent = parent
	return { toast = toast, frame = frame, signature = signature(item) }
end

function NotificationController:_refresh(item: any)
	if self._views[item.id] then
		self:_sync()
	end
end

-- Makes the stack match queue:visible(): newest on top.
function NotificationController:_sync()
	local root = self:_rootView()
	if root == nil then
		return
	end
	local visible = self.queue:visible()
	local keep = {}
	for order, item in visible do
		keep[item.id] = true
		local layoutOrder = #visible - order -- the newest (last) gets the lowest order: on top
		local view = self._views[item.id]
		if view ~= nil and view.signature ~= signature(item) then
			view.toast:destroy() -- Toast has no update API: rebuild with the new text or count
			view = nil
		end
		if view == nil then
			view = self:_buildToast(item, root.stack, layoutOrder)
			self._views[item.id] = view
		end
		view.frame.LayoutOrder = layoutOrder
	end
	for id, view in self._views do
		if not keep[id] then
			view.toast:destroy()
			self._views[id] = nil
		end
	end
end

return Def
