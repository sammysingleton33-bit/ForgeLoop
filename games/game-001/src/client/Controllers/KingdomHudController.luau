--!strict
--[[
	KingdomHudController (FORGE-03, game-001 client, FL-0059) — mounts the AI Kingdoms HUD and the
	Kingdom panel and keeps them in step with the server through the CONTRACTS G8 remotes.

	ScreenGuis (interfaces §9 DisplayOrder bands; ResetOnSpawn false):
		KingdomHUD      10  CoreUISafeInsets   crest, name plate, resource pills, rulers, rail, chips, placement bar
		KingdomTopbar   11  TopbarSafeInsets   phase and match clock in the free part of the Roblox top bar
		KingdomMenus    20  CoreUISafeInsets   Build drawer (BuildMenuController), Kingdom panel
		KingdomModals   40  None               large-spend confirmation (scrim covers the notch strips;
		                                       the panel is centred, clear of them)
		KingdomNotices  70  CoreUISafeInsets   toast fallback (until FORGE-04's NotificationController)
	Each scaled ScreenGui holds a Root frame sized fromScale(1/s, 1/s) with a UIScale of s, so all
	layout is in logical pixels (UI/Layout).

	Data (G8; the client never decides an outcome, values change only when the server says so):
		on start, for each area, the push is connected first and then the full state is requested:
		Kingdom.State + Kingdom.GetState, Match.State + Match.GetState, Treasury.Changed + Treasury.Get,
		Build.Buildings + Build.GetBuildings, and Treasury.GetCosts (config Costs until it answers).
		Treasury.Get is asked again whenever my kingdom changes (late join).
	Optional controllers (registry:find in start): NotificationController (toasts, else
	UI/ToastStack), OnboardingController (`report("ResourceInspected")` when a pill is tapped).
	The HUD and menus stay hidden until the player has a kingdom.

	API (also used by BuildMenuController, specs and the snapshot scenes)
		hud.store: UI/KingdomStore          hud.remotes: Core/RemoteClient client (nil before start)
		hud.rendered: Signal<(metrics)>     fired after every full render
		hud.menuChanged: Signal<(menu?)>    "build" | "kingdom" | nil
		hud:setMenu(id?)                    opens a menu (closes the other); the same id again closes it
		hud:setPlacing(on)                  hides the construction chips while the placement bar shows
		hud:notify({ title, body?, kind? })
		hud:metrics() -> Layout Metrics     hud.roots.{hud, menus, modals, notices}
		hud:panelTab(id)  hud:openUpgrade(buildingId)  hud:requestUpgrade(detail, confirmed?)
		hud:confirm()  hud:cancel()  hud:back()  hud:inspectResource(id)
		hud:setViewport(width, height)      the CoreUISafeInsets area size (headless; live measures it)
		hud:render()   hud.state   hud.view (UI/KingdomHud)   hud.panel (UI/KingdomPanel)   hud.guis
]]

local BuildModel = require("../UI/BuildModel")
local Buildings = require("../UI/Buildings")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local HudModel = require("../UI/HudModel")
local KingdomHud = require("../UI/KingdomHud")
local KingdomPanel = require("../UI/KingdomPanel")
local KingdomStore = require("../UI/KingdomStore")
local Layout = require("../UI/Layout")
local Modal = require("@game/ReplicatedStorage/Forge/UI/Components/Modal")
local Motion = require("@game/ReplicatedStorage/Forge/UI/Motion")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Text = require("../UI/Text")
local ToastStack = require("@game/ReplicatedStorage/Forge/UI/ToastStack")

local KingdomHudController = {}
KingdomHudController.__index = KingdomHudController

local Def = { name = "KingdomHudController", dependencies = {} }

KingdomHudController.TICK_SEC = 0.5
KingdomHudController.DONE_SEC = 1.6
KingdomHudController.DEFAULT_VIEWPORT = Vector2.new(1280, 662)

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_motion = Motion.new(env),
		store = KingdomStore.new(),
		remotes = nil :: any,
		rendered = Signal.new(),
		menuChanged = Signal.new(),
		guis = {},
		roots = {},
		state = {
			menu = nil :: string?,
			placing = false,
			panel = { tab = "overview", upgradeId = nil, pending = nil, done = nil },
			confirm = nil :: any,
		},
		_viewport = nil :: Vector2?,
		_mounted = false,
		_running = false,
		_mine = nil :: string?,
	}, KingdomHudController)
end

-- ------------------------------------------------------------------ mounting

local function screenGui(name: string, order: number, insets: any): ScreenGui
	return Create("ScreenGui", {
		Name = name,
		DisplayOrder = order,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = insets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
end

local function scaledRoot(gui: Instance): (Frame, UIScale)
	local scale = Create("UIScale", { Scale = 1 })
	local root = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Scale = scale })
	return root, scale
end

-- Calls fn(playerGui) now when the PlayerGui exists, else from a spawned thread once it appears
-- (start() must not yield, interfaces §3). Gives up after 10 s with a warning.
function KingdomHudController:_withPlayerGui(fn: (Instance) -> ())
	local env = self._env
	local player = env.Players.LocalPlayer
	local found = if player then player:FindFirstChildOfClass("PlayerGui") else nil
	if found then
		fn(found)
		return
	end
	env.spawn(function()
		local waited = if player then player:WaitForChild("PlayerGui", 10) else nil
		if self._destroyed then
			return -- destroyed while waiting (FORGE-05 L6): mount nothing
		elseif waited then
			fn(waited)
		else
			env.log("warn", "KingdomHudController: no PlayerGui; the kingdom HUD is not mounted", {})
		end
	end)
end

function KingdomHudController:mount(parent: Instance)
	local g = self.guis
	g.hud = screenGui("KingdomHUD", 10, Enum.ScreenInsets.CoreUISafeInsets)
	g.topbar = screenGui("KingdomTopbar", 11, Enum.ScreenInsets.TopbarSafeInsets)
	g.menus = screenGui("KingdomMenus", 20, Enum.ScreenInsets.CoreUISafeInsets)
	g.modals = screenGui("KingdomModals", 40, Enum.ScreenInsets.None)
	g.notices = screenGui("KingdomNotices", 70, Enum.ScreenInsets.CoreUISafeInsets)
	g.modals.Enabled = true
	g.notices.Enabled = true
	self._scales = {}
	for _, key in { "hud", "menus", "modals", "notices" } do
		self.roots[key], self._scales[key] = scaledRoot(g[key])
	end
	self._probe = Create("Frame", {
		Name = "SafeAreaProbe",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = g.hud,
	})
	self.view = KingdomHud.new(self.roots.hud, g.topbar, self._motion)
	self.panel = KingdomPanel.new(self.roots.menus)
	self.toasts = ToastStack.new(self.roots.notices, self._motion)
	for _, key in { "hud", "topbar", "menus", "modals", "notices" } do
		g[key].Parent = parent
	end
	self._mounted = true
	pcall(function()
		self._probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:render()
		end)
	end)
	self:render()
end

-- ------------------------------------------------------------------ lifecycle

function KingdomHudController:start()
	local env = self._env
	local registry = self._registry
	self._notifications = registry:find("NotificationController")
	self._onboarding = registry:find("OnboardingController")
	self.remotes = RemoteClient.new(env)
	self._remoteConnections = {}
	self._storeConnection = self.store.changed:connect(function(what, deltas)
		self:_onStore(what, deltas)
	end)
	local store = self.store
	-- Push first, then the full state (G4 rule for Sim.GetEntities, applied to every area).
	self:_follow("Kingdom.State", "Kingdom.GetState", function(payload)
		store:applyKingdoms(payload)
	end)
	self:_follow("Match.State", "Match.GetState", function(phase, endsAt, startedAt)
		store:applyMatch(phase, endsAt, startedAt)
	end)
	self:_follow("Treasury.Changed", "Treasury.Get", function(totals, deltas)
		store:applyTreasury(totals, deltas)
	end)
	self:_follow("Build.Buildings", nil, function(list)
		store:applyBuildings(list, false)
	end)
	self:_fetch("Build.GetBuildings", function(list)
		store:applyBuildings(list, true)
	end)
	self:_fetch("Treasury.GetCosts", function(catalogue)
		store:applyCosts(catalogue)
	end)
	self:_withPlayerGui(function(parent)
		self:mount(parent)
	end)
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(KingdomHudController.TICK_SEC)
			if self._running then
				self:_tick()
			end
		end
	end)
end

-- Connects `push` (a serverEvent), then asks `get` (a function) and feeds the reply to the same
-- handler, in one spawned thread per area: both may wait for the remote to replicate.
function KingdomHudController:_follow(push: string, get: string?, handler: (...any) -> ())
	local env = self._env
	env.spawn(function()
		local ok, err = pcall(function()
			local connection = self.remotes:on(push, handler)
			if self._destroyed then
				connection:Disconnect()
			else
				table.insert(self._remoteConnections, connection)
			end
		end)
		if not ok then
			env.log("warn", "KingdomHudController: cannot listen to " .. push, { error = tostring(err) })
		end
		if get then
			self:_fetchNow(get, handler)
		end
	end)
end

function KingdomHudController:_fetchNow(name: string, handler: (...any) -> ())
	local result = table.pack(pcall(function()
		return self.remotes:invoke(name)
	end))
	if result[1] then
		handler(table.unpack(result, 2, result.n))
	else
		self._env.log("warn", "KingdomHudController: " .. name .. " failed", { error = tostring(result[2]) })
	end
end

function KingdomHudController:_fetch(name: string, handler: (...any) -> ())
	self._env.spawn(function()
		self:_fetchNow(name, handler)
	end)
end

function KingdomHudController:destroy()
	self._running = false
	self._destroyed = true
	if self._storeConnection then
		self._storeConnection:disconnect()
	end
	-- Pushes stop here: the store no longer follows the server (FORGE-05 L5).
	for _, connection in self._remoteConnections or {} do
		pcall(function()
			connection:Disconnect()
		end)
	end
	self._remoteConnections = {}
	for _, gui in self.guis do
		gui:Destroy()
	end
	self._mounted = false
end

-- ------------------------------------------------------------------ data

function KingdomHudController:_onStore(what: string, deltas: any)
	if what == "kingdoms" then
		local kingdom = self.store:mine()
		local mine = if kingdom then kingdom.id else nil
		if mine ~= self._mine then
			self._mine = mine
			if mine ~= nil then
				-- A late join: the treasury of the new kingdom was never pushed to this client.
				self:_fetch("Treasury.Get", function(totals)
					self.store:applyTreasury(totals)
				end)
			end
		end
	end
	self:render()
	if what == "treasury" and deltas and self.view then
		self.view:pulse(deltas)
	end
end

function KingdomHudController:notify(spec: { title: string, body: string?, kind: string? })
	if self._notifications and self._notifications.show then
		local ok = pcall(function()
			self._notifications:show({
				title = spec.title,
				body = spec.body,
				kind = spec.kind or "info",
				durationSec = 3.5,
			})
		end)
		if ok then
			return
		end
	end
	if self.toasts then
		self.toasts:show(spec)
	end
end

function KingdomHudController:inspectResource(id: string)
	local def = Resources.defs[id]
	if def == nil then
		return
	end
	if self._onboarding and self._onboarding.report then
		pcall(function()
			self._onboarding:report("ResourceInspected")
		end)
	end
	local have = self.store:balances()[id]
	self:notify({
		kind = "info",
		title = if have then `{def.name}: {Format.amount(have)}` else def.name,
		body = def.description,
	})
end

-- ------------------------------------------------------------------ layout

function KingdomHudController:setViewport(width: number, height: number)
	self._viewport = Vector2.new(width, height)
	self:render()
end

function KingdomHudController:_safeArea(): Vector2
	if self._viewport then
		return self._viewport
	end
	local ok, size = pcall(function()
		return self._probe.AbsoluteSize
	end)
	if ok and typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
		return size
	end
	return KingdomHudController.DEFAULT_VIEWPORT
end

function KingdomHudController:metrics(): any
	local size = self:_safeArea()
	-- The reputation strip's room only while it shows (ReputationPanelController sets the flag).
	return Layout.compute(size.X, size.Y, { reputation = self.state.reputation == true })
end

-- ------------------------------------------------------------------ menus and actions

function KingdomHudController:setMenu(id: string?)
	if self.state.menu == id then
		id = nil
	end
	self.state.menu = id
	if id == "kingdom" then
		self.state.panel.tab = "overview"
		self.state.panel.upgradeId = nil
	end
	self.menuChanged:fire(id)
	self:render()
end

function KingdomHudController:setPlacing(on: boolean)
	self.state.placing = on
	self:render()
end

function KingdomHudController:panelTab(id: string)
	self.state.panel.tab = id
	self.state.panel.upgradeId = nil
	self:render()
end

function KingdomHudController:openUpgrade(buildingId: number)
	self.state.panel.tab = "upgrade"
	self.state.panel.upgradeId = buildingId
	self.state.panel.done = nil
	self:render()
end

function KingdomHudController:back()
	self.state.panel.tab = "buildings"
	self.state.panel.upgradeId = nil
	self:render()
end

function KingdomHudController:_building(id: number?): any
	if id == nil then
		return nil
	end
	for _, building in self.store:myBuildings() do
		if building.id == id then
			return building
		end
	end
	return nil
end

function KingdomHudController:requestUpgrade(detail: any, confirmed: boolean?)
	if detail.cta.state ~= "ready" or self.state.panel.pending ~= nil then
		return
	end
	if detail.needsConfirm and not confirmed then
		self.state.confirm = detail
		self:render()
		return
	end
	local env = self._env
	local panel = self.state.panel
	panel.pending = detail.buildingId
	panel.done = nil
	self:render()
	env.spawn(function()
		local called, ok, reason = pcall(function()
			return self.remotes:invoke("Build.Upgrade", detail.buildingId)
		end)
		panel.pending = nil
		if called and ok == true then
			panel.done = detail.buildingId
			self:notify({
				kind = "success",
				title = `{detail.name} upgrade started`,
				body = "Builders are on their way",
			})
			self._motion:after(KingdomHudController.DONE_SEC, function()
				if panel.done == detail.buildingId then
					panel.done = nil
					self:render()
				end
			end)
		else
			self:notify({
				kind = "error",
				title = "Couldn't start the upgrade",
				body = Text.reason(if called then reason else nil),
			})
		end
		self:render()
	end)
end

function KingdomHudController:confirm()
	local pending = self.state.confirm
	self.state.confirm = nil
	if pending then
		self:requestUpgrade(pending, true)
	end
	self:render()
end

function KingdomHudController:cancel()
	self.state.confirm = nil
	self:render()
end

-- ------------------------------------------------------------------ rendering

function KingdomHudController:_nameOf(userId: number): string?
	local ok, name = pcall(function()
		local player = self._env.Players:GetPlayerByUserId(userId)
		return if player then player.DisplayName or player.Name else nil
	end)
	return if ok then name else nil
end

function KingdomHudController:_localUserId(): number?
	local player = self._env.Players.LocalPlayer
	return if player then player.UserId else nil
end

function KingdomHudController:_panelModel(): any
	local store = self.store
	local p = self.state.panel
	local rows = {}
	for _, building in store:myBuildings() do
		local info = Buildings.get(building.type)
		table.insert(rows, {
			id = building.id,
			type = building.type,
			name = Buildings.name(building.type),
			icon = if info then info.icon else "build",
			category = if info then info.category else "economy",
			level = building.level,
			state = building.state,
			progress = if type(building.progress) == "number" then math.clamp(building.progress, 0, 1) else 0,
			canUpgrade = building.state == "complete" and store:buildingCost(building.type, building.level + 1) ~= nil,
		})
	end
	local upgrade = nil
	local target = self:_building(p.upgradeId)
	if p.tab == "upgrade" and target then
		upgrade = BuildModel.upgradeDetail(store, target, {
			pending = p.pending == target.id,
			done = p.done == target.id,
		})
	end
	return {
		tab = if p.tab == "upgrade" and upgrade == nil then "buildings" else p.tab,
		banner = HudModel.banner(store),
		members = HudModel.members(store, function(userId)
			return self:_nameOf(userId)
		end, self:_localUserId()),
		standings = HudModel.standings(store),
		buildings = rows,
		upgrade = upgrade,
	}
end

function KingdomHudController:render()
	if not self._mounted then
		return
	end
	local m = self:metrics()
	for _, key in { "hud", "menus", "modals", "notices" } do
		self._scales[key].Scale = m.scale
		self.roots[key].Size = UDim2.fromScale(1 / m.scale, 1 / m.scale)
	end
	local store = self.store
	local s = self.state
	local banner = HudModel.banner(store)
	local active = banner ~= nil
	self.guis.hud.Enabled = active
	self.guis.topbar.Enabled = active
	self.guis.menus.Enabled = active
	if not active and s.menu ~= nil then
		s.menu = nil
		self.menuChanged:fire(nil)
	end
	if active then
		self.view:render({
			banner = banner,
			members = HudModel.members(store, function(userId)
				return self:_nameOf(userId)
			end, self:_localUserId()),
			balances = if store:hasTreasury() then store:balances() else nil,
			timer = HudModel.timer(store.match, self._env.serverTimeNow()),
			queue = HudModel.queue(store),
			menu = s.menu,
			hideQueue = s.placing,
			onMenu = function(id)
				self:setMenu(id)
			end,
			onPill = function(id)
				self:inspectResource(id)
			end,
		}, m)
	end

	if s.menu == "kingdom" and active then
		self.panel:render(self:_panelModel(), m, {
			onTab = function(id)
				self:panelTab(id)
			end,
			onUpgradeOpen = function(id)
				self:openUpgrade(id)
			end,
			onUpgrade = function(detail)
				self:requestUpgrade(detail)
			end,
			onBack = function()
				self:back()
			end,
			onClose = function()
				self:setMenu(nil)
			end,
		})
	else
		self.panel:destroy()
	end

	-- The confirm dialog belongs to one request: pushes while it is open leave it alone
	-- (FORGE-05 M1). It shows the costs as they were when the player asked; the server checks
	-- the treasury again on Build.Upgrade.
	-- The building changed under the dialog (a co-ruler upgraded it, or it is no longer complete):
	-- the question no longer holds, so close it; the panel shows the new level and price.
	if s.confirm then
		local target = self:_building(s.confirm.buildingId)
		if target == nil or target.level + 1 ~= s.confirm.level or target.state ~= "complete" then
			s.confirm = nil
		end
	end
	-- Rebuilt for a new breakpoint too: its width follows the screen (400 px does not fit a phone).
	if self._modal and (self._modalFor ~= s.confirm or self._modalBreakpoint ~= m.breakpoint) then
		self._modal:destroy()
		self._modal = nil
		self._modalFor = nil
	end
	if s.confirm and self._modal == nil then
		local d = s.confirm
		local rows = {}
		for _, c in d.costs do
			table.insert(rows, {
				icon = c.currency,
				label = c.name,
				value = Format.amount(c.amount),
				note = `of {Format.amount(c.have)}`,
			})
		end
		self._modal = Modal.new({
			title = `Upgrade {d.name}?`,
			body = "This spends a large share of your treasury.",
			rows = rows,
			confirmText = "Upgrade",
			confirmIcon = "build",
			width = if m.breakpoint == "phone" then 340 else 400,
			onConfirm = function()
				self:confirm()
			end,
			onCancel = function()
				self:cancel()
			end,
		})
		self._modal.instance.Parent = self.roots.modals
		self._modalFor = s.confirm
		self._modalBreakpoint = m.breakpoint
	end

	local drawerOpen = s.menu ~= nil
	local free = Layout.freeArea(m, drawerOpen)
	local right = if drawerOpen and m.breakpoint == "phone"
		then free.width - 10
		else m.width - m.rail.right - m.rail.button - 12
	self.toasts:place(UDim2.fromOffset(right, Layout.toastTop(m, drawerOpen)), Vector2.new(1, 0), m.toast.width)
	self.rendered:fire(m)
end

function KingdomHudController:_tick()
	if not self._mounted or self.view == nil then
		return
	end
	self.view:refreshTimer(HudModel.timer(self.store.match, self._env.serverTimeNow()), self:metrics())
end

return Def
