--!strict
--[[
	CitizenBubbleIndicatorController (game-001, FORGE-04, FL-0115 B16): open citizen requests ("!") the
	aerial view does not show, and a key to go to them. The user's first Studio playtest: citizen chat
	bubbles were hard to notice and to act on from the air.

	Reads CitizenBubbleController:requests() (rigs with an open "!" thought, LOD-hidden ones at their last
	pivot; the citizen in the conversation is left out). Pure placement: Feedback/Requests.

		- Edge indicators: each open request whose bubble is off screen (or behind the camera) gets a
		  gold "!" badge at the screen edge, where the line from the centre towards it leaves the screen,
		  with an arrow (a diamond) pointing out at it. Placed in this ScreenGui's own rectangle (Roblox's
		  core-UI safe insets: never under the top bar or a notch), INSET px in, from
		  Camera:WorldToScreenPoint (the same screen space as GuiObject.AbsolutePosition and taps).
		  Badges closer than GAP px share one (the oldest request leads; a count shows how many), at most
		  MAX on screen. 44 px, so a thumb can hit one. They keep clear of FORGE-03's HUD (UI/Layout on
		  the same safe area, Def.insets): the right-edge rail, the top row (crest, pills, phase timer),
		  the bottom bar (placement bar and construction chips), and the top-left stack (crest, pills,
		  reputation), out of which a badge slides along its edge.
		- A tap on a badge goes to that request: RulerCameraController:focusOn(position) and
		  InputModeController:select("citizen", id), so FORGE-03's card opens with Talk, as a tap on the
		  citizen would.
		- Cycle: F (keyboard, Windows and Mac) or DPadRight (gamepad) goes to the next open request,
		  oldest first, wrapping; Shift+F or DPadLeft to the previous one. Listened to through
		  UserInputService (never bound, so nothing is sunk); a key a GUI handled (typing) does nothing.
		- Only in explore mode (InputModeController:accepts("explore")) with the aerial view
		  (RulerCameraController.mode "overview": walking, a focus would not move the view): while placing
		  or editing, walking, and during a conversation (ConversationController.opened .. closed), the
		  badges hide and the keys do nothing.

		CitizenBubbleIndicatorController:cycleRequests(step?: 1 | -1) -> number?   -- id gone to, or nil
		CitizenBubbleIndicatorController:focusRequest(entityId) -> boolean         -- a badge tap
		CitizenBubbleIndicatorController:count() -> number   -- open requests now (FORGE-03's 'citizens
		                                                      -- waiting' control can show it and call
		                                                      -- cycleRequests)
		CitizenBubbleIndicatorController:refresh()           -- re-place the badges (every POLL_SEC)
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Requests = require("@game/ReplicatedStorage/Game/Feedback/Requests")
local ScreenLayout = require("../UI/Layout")

local Def = {
	name = "CitizenBubbleIndicatorController",
	dependencies = {},
}

Def.POLL_SEC = 0.25
Def.SIZE = 44 -- px: the badge (a touch target)
Def.INSET = 40 -- px from an edge of the GUI's area to the badge's centre (the arrow's tip stays in)
Def.CLEAR = 8 -- px kept between a badge and FORGE-03's HUD (Def.insets)
-- px the arrow reaches past the disc's rim: a 17 px square turned 45° (half its diagonal, 12) with a 2 px
-- stroke (about 3 more at the corner). Def.insets keeps the tip clear of the HUD too.
Def.TIP = 15
Def.GAP = 52 -- px: badges closer than this share one
Def.MAX = 4 -- badges on screen at most
Def.HEIGHT = 3.2 -- studs above the rig's pivot: where its bubble sits (CitizenBubbleController.HEIGHT)
Def.NEXT_KEYS = table.freeze({ Enum.KeyCode.F, Enum.KeyCode.DPadRight })
Def.PREVIOUS_KEYS = table.freeze({ Enum.KeyCode.DPadLeft })
local rgb = Color3.fromRGB
Def.GOLD = rgb(242, 190, 60) -- CitizenBubbleController.BADGE["!"]: the same request colour
Def.INK = rgb(40, 32, 24)

local Controller = {}
Controller.__index = Controller

local function connect(target: any, signalName: string, handler: (...any) -> ()): any
	local signal = target and target[signalName]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:connect(handler)
	end)
	return if ok then connection else nil
end

-- opts (specs, renders): { playerGui = Instance, project = (Vector3) -> Vector3? (screen space, relative to
--   the GUI's area), viewport = Vector2 (that area's size), userInput = UserInputService double }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_playerGuiOverride = options.playerGui,
		_project = options.project,
		_viewportOverride = options.viewport,
		_userInputOverride = options.userInput,
		_connections = {},
		_badges = {} :: { any },
		_running = false,
		_talking = false,
		_last = nil :: number?,
		shown = {} :: { [number]: { [string]: any } }, -- badge index -> { entityId, count, position, angle }
	}, Controller)
end

-- Per-side insets (badge centre to the area's edge, px) and the top-left corner to avoid, from FORGE-03's
-- HUD layout on an area of `size` (UI/Layout.compute; its logical px times its scale). Plain INSET when
-- the layout cannot be computed.
function Def.insets(size: Vector2): (Requests.Insets, Vector2?)
	local ok, m = pcall(ScreenLayout.compute, size.X, size.Y)
	if not ok or type(m) ~= "table" then
		return { left = Def.INSET, right = Def.INSET, top = Def.INSET, bottom = Def.INSET }, nil
	end
	local s, reach, clear = m.scale, Def.SIZE / 2 + Def.TIP, Def.CLEAR
	local insets = {
		left = Def.INSET,
		right = math.max(Def.INSET, (m.rail.right + m.rail.button + clear) * s + reach),
		top = math.max(Def.INSET, (m.hud.y + m.hud.crest + clear) * s + reach),
		bottom = math.max(Def.INSET, (m.place.bottom + m.place.height + clear) * s + reach),
	}
	local strip = m.hud.reputation
	local corner = Vector2.new(
		(math.max(strip.x + strip.width, m.hud.pills.x) + clear) * s + reach,
		(m.hud.bottom + clear) * s + reach
	)
	return insets, corner
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	local registry = self._registry
	self._bubbles = registry:find("CitizenBubbleController")
	self._camera = registry:find("RulerCameraController")
	self._input = registry:find("InputModeController")
	local conversation = registry:find("ConversationController")
	if self._bubbles == nil or self._bubbles.requests == nil then
		self._env.log("info", "CitizenBubbleIndicatorController: no CitizenBubbleController; no request indicators")
		return
	end
	for _, item in
		{
			connect(self._input, "changed", function()
				self:refresh()
			end),
			connect(conversation, "opened", function()
				self._talking = true
				self:refresh()
			end),
			connect(conversation, "closed", function()
				self._talking = false
				self:refresh()
			end),
		}
	do
		table.insert(self._connections, item)
	end
	self:_bindKeys()
	self._gui = self:_buildGui()
	self._running = true
	local env = self._env
	env.spawn(function()
		while self._running do
			self:refresh()
			env.wait(Def.POLL_SEC)
		end
	end)
end

function Controller:destroy()
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			-- Forge Signal connections (input mode, conversation) have disconnect; Roblox's have Disconnect
			if type(connection) == "table" and connection.disconnect ~= nil then
				connection:disconnect()
			else
				connection:Disconnect()
			end
		end)
	end
	table.clear(self._connections)
	if self._gui ~= nil then
		pcall(function()
			self._gui:Destroy()
		end)
		self._gui = nil
	end
	table.clear(self._badges)
	table.clear(self.shown)
end

-- Open requests now, oldest first.
function Controller:_requests(): { Requests.Request }
	local ok, list = pcall(self._bubbles.requests, self._bubbles)
	return Requests.order(if ok and type(list) == "table" then list else {})
end

function Controller:count(): number
	if self._bubbles == nil then
		return 0
	end
	return #self:_requests()
end

-- Go to a request: the camera centres on the citizen and selects them (FORGE-03's card opens).
function Controller:focusRequest(entityId: any): boolean
	if not self:_active() then
		return false
	end
	for _, request in self:_requests() do
		if request.entityId == entityId then
			self._last = entityId
			local camera = self._camera
			if camera ~= nil and camera.focusOn ~= nil then
				pcall(camera.focusOn, camera, request.position)
			end
			local input = self._input
			if input ~= nil and input.select ~= nil then
				pcall(input.select, input, "citizen", entityId)
			end
			self:refresh()
			return true
		end
	end
	return false
end

-- The next (step 1) or previous (step -1) open request after the last one gone to; nil when none.
function Controller:cycleRequests(step: number?): number?
	if self._bubbles == nil or not self:_active() then
		return nil
	end
	local ids = {}
	for _, request in self:_requests() do
		table.insert(ids, request.entityId)
	end
	local id = Requests.nextAfter(ids, self._last, step)
	if id ~= nil and self:focusRequest(id) then
		return id
	end
	return nil
end

function Controller:refresh()
	local placed = {}
	if self._bubbles ~= nil and self:_active() then
		local origin, viewport = self:_area()
		if origin ~= nil and viewport ~= nil then
			local insets, corner = Def.insets(viewport)
			for _, request in self:_requests() do
				local point = self:_projectPoint(request.position + Vector3.new(0, Def.HEIGHT, 0), origin)
				if point ~= nil then
					local edge = Requests.edge(point, viewport, insets, corner)
					if not edge.onScreen and edge.position ~= nil and edge.angle ~= nil then
						table.insert(
							placed,
							{ entityId = request.entityId, position = edge.position, angle = edge.angle }
						)
					end
				end
			end
		end
	end
	local groups = Requests.group(placed, Def.GAP, Def.MAX)
	table.clear(self.shown)
	for index, group in groups do
		self.shown[index] =
			{ entityId = group.entityId, count = group.count, position = group.position, angle = group.angle }
		self:_paint(index, group)
	end
	for index = #groups + 1, #self._badges do
		self._badges[index].Visible = false
	end
end

-- ------------------------------------------------------------------ internals

function Controller:_active(): boolean
	if self._talking then
		return false
	end
	local camera = self._camera
	if camera ~= nil and camera.mode ~= nil and camera.mode ~= "overview" then
		return false
	end
	local input = self._input
	if input == nil then
		return true
	end
	if input.accepts ~= nil then
		local ok, accepted = pcall(input.accepts, input, "explore")
		return ok and accepted == true
	end
	return input.mode == nil or input.mode == "explore"
end

-- The badges' area: this ScreenGui's rectangle (its safe insets applied) in screen space.
function Controller:_area(): (Vector2?, Vector2?)
	if self._viewportOverride ~= nil then
		return Vector2.zero, self._viewportOverride
	end
	local ok, origin, size = pcall(function()
		return self._gui.AbsolutePosition, self._gui.AbsoluteSize
	end)
	if ok and typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
		return origin, size
	end
	return nil, nil
end

-- Camera:WorldToScreenPoint relative to the area (X, Y in pixels; Z = depth, <= 0 behind the camera).
function Controller:_projectPoint(position: Vector3, origin: Vector2): Vector3?
	if self._project ~= nil then
		return self._project(position)
	end
	local ok, point = pcall(function()
		return self._env.Workspace.CurrentCamera:WorldToScreenPoint(position)
	end)
	if not ok or typeof(point) ~= "Vector3" then
		return nil
	end
	return Vector3.new(point.X - origin.X, point.Y - origin.Y, point.Z)
end

function Controller:_bindKeys()
	local env = self._env
	local userInput = self._userInputOverride
	if userInput == nil then
		local ok, found = pcall(function()
			local uis = env.UserInputService
			local _ = uis.InputBegan -- the boot gate's unmocked guard errors here
			return uis
		end)
		userInput = if ok then found else nil
	end
	if userInput == nil then
		return
	end
	local ok, connection = pcall(function()
		return userInput.InputBegan:Connect(function(input, processed)
			if processed then
				return -- typing in a TextBox, or a GUI that took the key
			end
			local key = input.KeyCode
			local shift = false
			pcall(function()
				shift = userInput:IsKeyDown(Enum.KeyCode.LeftShift) or userInput:IsKeyDown(Enum.KeyCode.RightShift)
			end)
			if table.find(Def.PREVIOUS_KEYS, key) or (key == Enum.KeyCode.F and shift) then
				self:cycleRequests(-1)
			elseif table.find(Def.NEXT_KEYS, key) then
				self:cycleRequests(1)
			end
		end)
	end)
	if ok then
		table.insert(self._connections, connection)
	end
end

function Controller:_playerGui(): any
	if self._playerGuiOverride ~= nil then
		return self._playerGuiOverride
	end
	local ok, found = pcall(function()
		return self._env.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	return if ok then found else nil
end

function Controller:_buildGui(): any
	local env = self._env
	local gui = env.newInstance("ScreenGui")
	gui.Name = "ForgeRequestIndicators"
	gui.DisplayOrder = 5 -- under the HUD's panels and toasts
	pcall(function()
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.IgnoreGuiInset = false
	end)
	gui.Parent = self:_playerGui()
	return gui
end

function Controller:_badge(index: number): any
	local badge = self._badges[index]
	if badge ~= nil then
		return badge
	end
	local env = self._env
	-- a transparent button holding, bottom to top: the arrow (a diamond whose inner half the disc covers,
	-- so a gold tip shows outside the rim, towards the citizen), the disc with its "!" and the count
	badge = env.newInstance("TextButton")
	badge.Name = `Request{index}`
	badge.Size = UDim2.fromOffset(Def.SIZE, Def.SIZE)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.BackgroundTransparency = 1
	badge.AutoButtonColor = false
	badge.Text = ""
	local pivot = env.newInstance("Frame")
	pivot.Name = "Pointer"
	pivot.BackgroundTransparency = 1
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromOffset(Def.SIZE, Def.SIZE)
	pivot.ZIndex = 1
	pivot.Parent = badge
	local arrow = env.newInstance("Frame")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(1, 0.5) -- on the rim: the disc hides the inner half
	arrow.Size = UDim2.fromOffset(17, 17)
	arrow.Rotation = 45
	arrow.BackgroundColor3 = Def.GOLD
	arrow.ZIndex = 1
	arrow.Parent = pivot
	local edge = env.newInstance("UIStroke")
	edge.Thickness = 2
	edge.Color = Def.INK
	edge.Parent = arrow
	local disc = env.newInstance("TextLabel")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Def.GOLD
	disc.Text = "!"
	disc.Font = Enum.Font.GothamBlack
	disc.TextSize = 26
	disc.TextColor3 = Def.INK
	disc.ZIndex = 2
	disc.Parent = badge
	local round = env.newInstance("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	local ring = env.newInstance("UIStroke")
	ring.Thickness = 2
	ring.Color = Def.INK
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = disc
	local count = env.newInstance("TextLabel")
	count.Name = "Count"
	count.BackgroundColor3 = Def.INK
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.new(1, -4, 0, 4)
	count.Size = UDim2.fromOffset(20, 20)
	count.Font = Enum.Font.GothamBold
	count.TextSize = 13
	count.TextColor3 = rgb(255, 250, 240)
	count.Visible = false
	count.ZIndex = 3
	count.Parent = badge
	local countRound = env.newInstance("UICorner")
	countRound.CornerRadius = UDim.new(0.5, 0)
	countRound.Parent = count
	pcall(Create.connect, badge, "Activated", function()
		self:focusRequest(badge:GetAttribute("EntityId"))
	end)
	badge.Parent = self._gui
	self._badges[index] = badge
	return badge
end

function Controller:_paint(index: number, group: Requests.Group)
	local badge = self:_badge(index)
	badge:SetAttribute("EntityId", group.entityId)
	badge.Position = UDim2.fromOffset(math.floor(group.position.X + 0.5), math.floor(group.position.Y + 0.5))
	badge.Visible = true
	local pointer = badge:FindFirstChild("Pointer")
	if pointer ~= nil then
		pointer.Rotation = group.angle
	end
	local count = badge:FindFirstChild("Count")
	if count ~= nil then
		count.Visible = group.count > 1
		count.Text = tostring(group.count)
	end
end

return Def
