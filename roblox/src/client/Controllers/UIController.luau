--!strict
--[[
	UIController (FORGE-03, client) — mounts the AI Kingdoms interface and connects it to gameplay.

	ScreenGuis (interfaces §9 DisplayOrder bands; ResetOnSpawn false):
		ForgeHUD      10  CoreUISafeInsets   kingdom badge, resource pills, menu rail, construction queue
		ForgeTopbar   11  TopbarSafeInsets   match timer in the free part of the Roblox top bar
		ForgeMenus    20  CoreUISafeInsets   Construction drawer, Kingdom panel
		ForgeModals   40  DeviceSafeInsets   large-spend confirmation
		ForgeNotices  70  CoreUISafeInsets   toast fallback (until FORGE-04's NotificationController)
	Each scaled ScreenGui holds a Root frame sized fromScale(1/s, 1/s) with a UIScale of s, so all
	layout is in logical pixels (UI/Layout).

	Data sources (all optional, found in start(); missing ones leave their part in a loading state):
		KingdomController (FORGE-01, proposed API)  .state, .changed, :build, :upgrade, :assignWorkers
		RemoteClient (FORGE-01 Core, via env.sharedModules("RemoteClient").Core)
		    Economy.Treasury / Economy.GetTreasury (FORGE-03), Gameplay.RoundState / GetRoundState (§4)
		NotificationController (FORGE-04)          :show(...) for toasts, else UI/ToastStack
	The HUD and menus stay disabled until the player has a kingdom or a treasury (lobby, games
	without kingdoms). The client never decides outcomes: Build sends Gameplay.Build; balances change only when the
	server's Economy.Treasury arrives, which also drives the pill deltas (visual confirmation).

	Methods (also the hooks specs and the snapshot tool use)
		ui:openMenu(id?)   "build" | "kingdom" | nil (toggle)      ui:selectCategory(id)
		ui:selectBuilding(id)   ui:back()   ui:requestBuild(detail, confirmed?)
		ui:panelTab(id)    ui:openUpgrade(uid)   ui:requestUpgrade(detail, confirmed?)
		ui:assignWorkers(uid, count)   ui:confirm()   ui:cancel()
		ui:setViewport(width, height)  the CoreUISafeInsets area size (headless; live measures it)
		ui:render()        ui.state   ui.hud   ui.buildMenu   ui.kingdomPanel   ui.guis
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Construction = require("@game/ReplicatedStorage/Forge/Economy/Construction")
local Currencies = require("@game/ReplicatedStorage/Forge/Economy/Currencies")
local BuildMenu = require("../UI/Kingdom/BuildMenu")
local BuildMenuModel = require("../UI/Kingdom/BuildMenuModel")
local Create = require("../UI/Create")
local Format = require("../UI/Format")
local KingdomHud = require("../UI/Kingdom/KingdomHud")
local KingdomPanel = require("../UI/Kingdom/KingdomPanel")
local KingdomPanelModel = require("../UI/Kingdom/KingdomPanelModel")
local Layout = require("../UI/Layout")
local Modal = require("../UI/Components/Modal")
local Motion = require("../UI/Motion")
local Text = require("../UI/Kingdom/Text")
local ToastStack = require("../UI/ToastStack")

local UIController = {}
UIController.__index = UIController

local Def = { name = "UIController", dependencies = {} }

UIController.TICK_SEC = 0.5
UIController.DONE_SEC = 1.6
UIController.DEFAULT_VIEWPORT = Vector2.new(1280, 662)
UIController.STORAGE_WARNING_SEC = 30

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_motion = Motion.new(env),
		catalog = Construction.default(),
		currencies = Currencies.default(),
		guis = {},
		state = {
			kingdom = nil,
			treasury = nil,
			round = nil,
			menu = nil,
			build = { category = "economy", selected = nil, phoneView = "list", pending = nil, done = nil },
			panel = { tab = "overview", upgradeUid = nil, pending = nil, done = nil },
			confirm = nil,
		},
		_viewport = nil :: Vector2?,
		_running = false,
		_lastStorageWarning = -math.huge,
	}, UIController)
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

function UIController:_findPlayerGui(): Instance?
	local player = self._env.Players.LocalPlayer
	if player == nil then
		return nil
	end
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
end

function UIController:mount(parent: Instance)
	local g = self.guis
	g.hud = screenGui("ForgeHUD", 10, Enum.ScreenInsets.CoreUISafeInsets)
	g.topbar = screenGui("ForgeTopbar", 11, Enum.ScreenInsets.TopbarSafeInsets)
	g.menus = screenGui("ForgeMenus", 20, Enum.ScreenInsets.CoreUISafeInsets)
	g.modals = screenGui("ForgeModals", 40, Enum.ScreenInsets.DeviceSafeInsets)
	g.notices = screenGui("ForgeNotices", 70, Enum.ScreenInsets.CoreUISafeInsets)
	self._roots = {}
	self._scales = {}
	for _, key in { "hud", "menus", "modals", "notices" } do
		self._roots[key], self._scales[key] = scaledRoot(g[key])
	end
	self._probe = Create("Frame", {
		Name = "SafeAreaProbe",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = g.hud,
	})
	self.hud = KingdomHud.new(self._roots.hud, g.topbar, self._motion)
	self.buildMenu = BuildMenu.new(self._roots.menus)
	self.kingdomPanel = KingdomPanel.new(self._roots.menus)
	self.toasts = ToastStack.new(self._roots.notices, self._motion)
	for _, key in { "hud", "topbar", "menus", "modals", "notices" } do
		g[key].Parent = parent
	end
	self._mounted = true
	pcall(function()
		self._probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:render()
		end)
	end)
end

-- ------------------------------------------------------------------ lifecycle

function UIController:start()
	local env = self._env
	self._kingdom = self._registry:find("KingdomController")
	self._notifications = self._registry:find("NotificationController")
	self._rc = env.sharedModules("RemoteClient").Core
	local parent = self:_findPlayerGui()
	if parent == nil then
		env.log("warn", "UIController: no PlayerGui; the kingdom UI is not mounted", {})
		return
	end
	self:mount(parent)
	if self._kingdom then
		self.state.kingdom = self._kingdom.state
		self._kingdomConnection = self._kingdom.changed:connect(function(snapshot)
			self.state.kingdom = snapshot
			self:render()
		end)
	else
		env.log("warn", "UIController: no KingdomController yet; kingdom panels show a loading state", {})
	end
	local rc = self._rc
	if rc then
		pcall(function()
			rc.on("Economy.Treasury", function(snapshot, change)
				self:_onTreasury(snapshot, change)
			end)
		end)
		pcall(function()
			rc.on("Gameplay.RoundState", function(state, roundId, endsAt)
				self.state.round = { state = state, roundId = roundId, endsAt = endsAt }
				self:render()
			end)
		end)
		env.spawn(function()
			local ok, snapshot = pcall(rc.invoke, "Economy.GetTreasury")
			if ok then
				self:_onTreasury(snapshot, nil)
			end
		end)
		env.spawn(function()
			local ok, round = pcall(rc.invoke, "Gameplay.GetRoundState")
			if ok and type(round) == "table" and self.state.round == nil then
				self.state.round = { state = round.state, roundId = round.roundId, endsAt = round.endsAtServerTime }
				self:render()
			end
		end)
	else
		env.log("warn", "UIController: no RemoteClient yet (FORGE-01 Core/RemoteClient); treasury not live", {})
	end
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(UIController.TICK_SEC)
			if self._running then
				self:_tick()
			end
		end
	end)
	self:render()
end

function UIController:destroy()
	self._running = false
	if self._kingdomConnection then
		self._kingdomConnection:disconnect()
	end
	for _, gui in self.guis do
		gui:Destroy()
	end
end

-- ------------------------------------------------------------------ data

function UIController:_onTreasury(snapshot: any, change: any)
	if type(snapshot) ~= "table" then
		return
	end
	local current = self.state.treasury
	if current and current.kingdomId == snapshot.kingdomId and snapshot.version <= current.version then
		return
	end
	self.state.treasury = snapshot
	self:render()
	if change and change.delta and self.hud then
		self.hud:pulse(change.delta)
	end
	if change and change.overflow and next(change.overflow) ~= nil then
		local now = self._env.clock()
		if now - self._lastStorageWarning >= UIController.STORAGE_WARNING_SEC then
			self._lastStorageWarning = now
			local full = {}
			for _, entry in Bundle.ordered(change.overflow, self.currencies:ids()) do
				table.insert(full, self.currencies:require(entry.id).name)
			end
			self:_notify({
				kind = "warning",
				title = "Storage full",
				body = `Build a Storehouse to keep more {Format.list(full)}`,
			})
		end
	end
end

function UIController:_notify(spec: { title: string, body: string?, kind: string? })
	if self._notifications and self._notifications.show then
		self._notifications:show({ title = spec.title, body = spec.body, kind = spec.kind or "info", durationSec = 3.5 })
	elseif self.toasts then
		self.toasts:show(spec)
	end
end

-- ------------------------------------------------------------------ layout

function UIController:setViewport(width: number, height: number)
	self._viewport = Vector2.new(width, height)
	self:render()
end

function UIController:_safeArea(): Vector2
	if self._viewport then
		return self._viewport
	end
	local ok, size = pcall(function()
		return self._probe.AbsoluteSize
	end)
	if ok and typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
		return size
	end
	return UIController.DEFAULT_VIEWPORT
end

function UIController:metrics(): any
	local size = self:_safeArea()
	return Layout.compute(size.X, size.Y)
end

-- ------------------------------------------------------------------ actions

function UIController:openMenu(id: string?)
	if self.state.menu == id then
		id = nil
	end
	self.state.menu = id
	self.state.build.phoneView = "list"
	if id == "kingdom" and self.state.panel.tab == "upgrade" then
		self.state.panel.tab = "buildings"
	end
	self:render()
end

function UIController:selectCategory(id: string)
	self.state.build.category = id
	self.state.build.selected = nil
	self.state.build.phoneView = "list"
	self:render()
end

function UIController:selectBuilding(id: string)
	self.state.build.selected = id
	self.state.build.phoneView = "detail"
	self:render()
end

function UIController:back()
	if self.state.menu == "kingdom" then
		self.state.panel.tab = "buildings"
		self.state.panel.upgradeUid = nil
	else
		self.state.build.phoneView = "list"
	end
	self:render()
end

local function confirmRows(detail: any): { any }
	local rows = {}
	for _, c in detail.costs do
		table.insert(
			rows,
			{ icon = c.currency, label = c.name, value = Format.amount(c.amount), note = `of {Format.amount(c.have)}` }
		)
	end
	return rows
end

function UIController:_run(kind: "build" | "upgrade", detail: any)
	local env = self._env
	local slot = if kind == "build" then self.state.build else self.state.panel
	slot.pending = detail.id
	slot.pendingUid = detail.uid
	slot.done = nil
	self:render()
	env.spawn(function()
		local ok, result, reason = false, nil, nil
		if self._kingdom then
			local called, a, b = pcall(function()
				if kind == "build" then
					return self._kingdom:build(detail.id)
				end
				return self._kingdom:upgrade(detail.uid)
			end)
			if called then
				result, reason = a, b
				ok = result == true
			end
		end
		slot.pending = nil
		slot.pendingUid = nil
		if ok then
			slot.done = detail.id
			slot.doneUid = detail.uid
			local verb = if kind == "build" then "construction" else "upgrade"
			self:_notify({
				kind = "success",
				title = `{detail.name} {verb} started`,
				body = `Ready in {Format.clock(detail.buildSec)}`,
			})
			self._motion:after(UIController.DONE_SEC, function()
				if slot.done == detail.id then
					slot.done = nil
					slot.doneUid = nil
					self:render()
				end
			end)
		else
			self:_notify({
				kind = "error",
				title = if kind == "build" then "Couldn't start construction" else "Couldn't start the upgrade",
				body = Text.serverError(reason),
			})
		end
		self:render()
	end)
end

function UIController:requestBuild(detail: any, confirmed: boolean?)
	if detail.cta.state ~= "ready" then
		return
	end
	if detail.needsConfirm and not confirmed then
		self.state.confirm = { kind = "build", detail = detail }
		self:render()
		return
	end
	self:_run("build", detail)
end

function UIController:panelTab(id: string)
	self.state.panel.tab = id
	self.state.panel.upgradeUid = nil
	self:render()
end

function UIController:openUpgrade(uid: string)
	self.state.panel.tab = "upgrade"
	self.state.panel.upgradeUid = uid
	self:render()
end

function UIController:requestUpgrade(detail: any, confirmed: boolean?)
	if detail.cta.state ~= "ready" then
		return
	end
	if detail.needsConfirm and not confirmed then
		self.state.confirm = { kind = "upgrade", detail = detail }
		self:render()
		return
	end
	self:_run("upgrade", detail)
end

function UIController:assignWorkers(uid: string, count: number)
	if self._kingdom == nil then
		return
	end
	self._env.spawn(function()
		local called, ok, reason = pcall(function()
			return self._kingdom:assignWorkers(uid, count)
		end)
		if not called or ok ~= true then
			self:_notify({
				kind = "error",
				title = "Couldn't change workers",
				body = Text.serverError(if called then reason else nil),
			})
		end
	end)
end

function UIController:confirm()
	local pending = self.state.confirm
	self.state.confirm = nil
	if pending then
		if pending.kind == "build" then
			self:requestBuild(pending.detail, true)
		else
			self:requestUpgrade(pending.detail, true)
		end
	end
	self:render()
end

function UIController:cancel()
	self.state.confirm = nil
	self:render()
end

-- ------------------------------------------------------------------ rendering

function UIController:_timer(): any
	local round = self.state.round
	if round == nil or round.endsAt == nil then
		return nil
	end
	local left = round.endsAt - self._env.serverTimeNow()
	if round.state == "Active" then
		return { text = Format.clock(left), label = "until the match ends" }
	elseif round.state == "Countdown" or round.state == "Intermission" then
		return { text = Format.clock(left), label = "until the match starts" }
	end
	return nil
end

function UIController:_input(): { [string]: any }
	local s = self.state
	return {
		catalog = self.catalog,
		currencies = self.currencies,
		kingdom = s.kingdom,
		treasury = s.treasury,
		category = s.build.category,
		selected = s.build.selected,
		pending = s.build.pending,
		done = s.build.done,
	}
end

function UIController:render()
	if not self._mounted then
		return
	end
	local m = self:metrics()
	for _, key in { "hud", "menus", "modals", "notices" } do
		self._scales[key].Scale = m.scale
		self._roots[key].Size = UDim2.fromScale(1 / m.scale, 1 / m.scale)
	end
	local s = self.state
	local now = self._env.serverTimeNow()
	local overview = if s.kingdom
		then KingdomPanelModel.overview(s.kingdom, s.treasury, self.catalog, self.currencies)
		else nil
	local queue = if s.kingdom then KingdomPanelModel.queue(s.kingdom, self.catalog, now) else {}
	self.hud:render({
		kingdom = s.kingdom,
		treasury = s.treasury,
		overview = overview,
		queue = queue,
		timer = self:_timer(),
		menu = s.menu,
		onMenu = function(id)
			self:openMenu(id)
		end,
	}, m, self.currencies:ids("match"))

	if s.menu == "build" then
		local view = BuildMenuModel.build(self:_input())
		local justBuilt = view.detail and s.build.done == view.detail.id
		local progress = nil
		if justBuilt and s.kingdom then
			for _, item in queue do
				if item.buildingId == view.detail.id then
					progress = item
				end
			end
		end
		self.buildMenu:render(view, m, {
			phoneView = s.build.phoneView,
			paid = justBuilt,
			progress = progress,
			onCategory = function(id)
				self:selectCategory(id)
			end,
			onSelect = function(id)
				self:selectBuilding(id)
			end,
			onBack = function()
				self:back()
			end,
			onBuild = function(detail)
				self:requestBuild(detail)
			end,
			onClose = function()
				self:openMenu(nil)
			end,
		})
	else
		self.buildMenu:destroy()
	end

	if s.menu == "kingdom" and s.kingdom then
		local p = s.panel
		local upgrade = nil
		local upgradeUid = p.upgradeUid
		if p.tab == "upgrade" and upgradeUid then
			for _, b in s.kingdom.buildings do
				if b.uid == upgradeUid then
					local input = self:_input()
					input.pending = p.pending
					input.pendingUid = p.pendingUid
					input.done = p.done
					input.doneUid = p.doneUid
					upgrade = BuildMenuModel.detail(input, b.buildingId, upgradeUid)
				end
			end
		end
		self.kingdomPanel:render(
			{
				tab = if p.tab == "upgrade" and upgrade == nil then "buildings" else p.tab,
				overview = overview,
				buildings = KingdomPanelModel.buildings(s.kingdom, s.treasury, self.catalog, now),
				upgrade = upgrade,
				upgradePaid = upgrade ~= nil and p.done == upgrade.id,
			},
			m,
			{
				onTab = function(id)
					self:panelTab(id)
				end,
				onWorkers = function(uid, count)
					self:assignWorkers(uid, count)
				end,
				onUpgradeOpen = function(uid)
					self:openUpgrade(uid)
				end,
				onUpgrade = function(detail)
					self:requestUpgrade(detail)
				end,
				onBack = function()
					self:back()
				end,
				onClose = function()
					self:openMenu(nil)
				end,
			}
		)
	else
		self.kingdomPanel:destroy()
	end

	if self._modal then
		self._modal:destroy()
		self._modal = nil
	end
	if s.confirm then
		local d = s.confirm.detail
		local upgrade = s.confirm.kind == "upgrade"
		self._modal = Modal.new({
			title = if upgrade then `Upgrade {d.name}?` else `Build {d.name}?`,
			body = "This spends a large share of your treasury.",
			rows = confirmRows(d),
			confirmText = if upgrade then "Upgrade" else "Build",
			confirmIcon = "build",
			width = if m.breakpoint == "phone" then 340 else 400,
			onConfirm = function()
				self:confirm()
			end,
			onCancel = function()
				self:cancel()
			end,
		})
		self._modal.instance.Parent = self._roots.modals
	end

	local drawerOpen = s.menu ~= nil
	local free = Layout.freeArea(m, drawerOpen)
	local right = if drawerOpen then free.width - 10 else m.width - m.rail.right - m.rail.button - 12
	self.toasts:place(UDim2.fromOffset(right, Layout.toastTop(m, drawerOpen)), Vector2.new(1, 0), m.toast.width)
end

function UIController:_tick()
	if not self._mounted then
		return
	end
	local s = self.state
	local now = self._env.serverTimeNow()
	local m = self:metrics()
	if s.kingdom then
		self.hud:refreshQueue(KingdomPanelModel.queue(s.kingdom, self.catalog, now), m, s.menu ~= nil)
		if s.menu == "kingdom" then
			self.kingdomPanel:refreshProgress(KingdomPanelModel.buildings(s.kingdom, s.treasury, self.catalog, now))
		end
	end
	local timer = self:_timer()
	if timer then
		self.hud:render({
			kingdom = s.kingdom,
			treasury = s.treasury,
			overview = if s.kingdom
				then KingdomPanelModel.overview(s.kingdom, s.treasury, self.catalog, self.currencies)
				else nil,
			queue = if s.kingdom then KingdomPanelModel.queue(s.kingdom, self.catalog, now) else {},
			timer = timer,
			menu = s.menu,
			onMenu = function(id)
				self:openMenu(id)
			end,
		}, m, self.currencies:ids("match"))
	end
end

return Def
