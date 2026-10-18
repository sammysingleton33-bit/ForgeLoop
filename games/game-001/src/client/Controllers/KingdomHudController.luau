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
		KingdomNotices  70  CoreUISafeInsets   toast fallback (without FORGE-04's NotificationController;
		                                       with it, its stack is placed in the same spot, in screen px)
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
		hud:setBackStep(menu, step?)        the back key (gamepad B, Backspace; InputModeController:onBack,
		                                    #130) while that menu is open: step() -> true when it stepped
		                                    back inside the panel, else the drawer closes
		hud:backPressed() -> boolean        what one back press does (true when a drawer took it)
		hud:setPlacing(on)                  hides the construction chips while the placement bar shows
		hud:addRailItem({ id, icon, label, target?, order? })   a rail button for another controller's
		                                    menu (ArmyPanelController: "army"); it calls hud:setMenu(id)
		hud:removeRailItem(id)              undoes it (the owner's destroy)
		hud:setStackBottom(y?)              the bottom of a widget hung under the top-left stack (the
		                                    objective tracker): phone toasts with an open drawer start below it
		hud:notify({ title, body?, kind? })
		hud:hasRemote(name) -> boolean      the server declared this remote (ReplicatedStorage
		                                    .ForgeRemotes.<Area>.<Action> exists; never yields)
		hud:setSheet(menu, on?)             this menu is a wide sheet on phones (the conversation):
		hud:sheetOpen(metrics?) -> boolean  while one is open on a phone, toasts sit above it (one
		                                    at a time) and the reputation strip is under it
		hud:metrics() -> Layout Metrics     hud.roots.{backdrop, hud, menus, modals, notices}
		                                    backdrop: the whole device (ScreenInsets None, not clipped
		                                    to the safe area), just under the menus: the cinematic
		                                    conversation's dim band (FL-0099) reaches past a notch
		hud:panelTab(id)  hud:openUpgrade(buildingId)  hud:requestUpgrade(detail, confirmed?)
		hud:confirm()  hud:cancel()  hud:back()  hud:inspectResource(id)
		hud:changeJob(jobId, delta)         Kingdom panel "Jobs" (FL-0065): asks Kingdom.SetJobQuota for
		                                    the job's count + delta; one request per job at a time
		hud:setViewport(width, height)      the CoreUISafeInsets area size (headless; live measures it)
		hud:render()   hud.state   hud.view (UI/KingdomHud)   hud.panel (UI/KingdomPanel)   hud.guis
]]

local BuildModel = require("../UI/BuildModel")
local DiplomacyModel = require("../UI/DiplomacyModel")
local Buildings = require("../UI/Buildings")
local JobModel = require("../UI/JobModel")
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
-- War and peace (FL-0129; the remote is FORGE-01's, proposed in the Crownfall handoff): the Kingdom panel's
-- Rivals tab shows only while the server serves it.
KingdomHudController.DIPLOMACY = "Kingdom.Diplomacy"
-- D-054 (2): the senior ruler hears a co-ruler's ask for war (FORGE-01's final contract, 2026-10-18)
KingdomHudController.WAR_ASK = "Kingdom.WarAsk"
-- "Raid" on the rail while enemies are in our lands (FORGE-04's FeedbackWarController.alert(), #183):
-- a tap sends the aerial camera there (goToAlert). Keys have G / D-pad up; on a phone this is the way.
KingdomHudController.RAID_RAIL = table.freeze({
	id = "raid",
	icon = "warning",
	label = "Raid",
	order = 45, -- after the built-in menus and Army, before Waiting
})
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
			panel = {
				tab = "overview",
				upgradeId = nil,
				pending = nil,
				done = nil,
				jobs = { pending = {}, quota = {}, at = {} }, -- FL-0065: in flight / acknowledged (JobModel state)
				confirmWar = nil :: string?, -- FL-0129: the rival a Declare war waits to be confirmed against
				diplomacyPending = {} :: { [string]: boolean }, -- rivals with a diplomacy request in flight
			},
			confirm = nil :: any,
		},
		_viewport = nil :: Vector2?,
		_railItems = {} :: { any },
		_railBadges = {} :: { [string]: number },
		_stackBottom = nil :: number?,
		_sheets = {} :: { [string]: boolean },
		_backSteps = {} :: { [string]: () -> boolean },
		_releaseBack = nil :: (() -> ())?,
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
	g.backdrop = screenGui("KingdomBackdrop", 19, Enum.ScreenInsets.None)
	g.backdrop.ClipToDeviceSafeArea = false
	g.hud = screenGui("KingdomHUD", 10, Enum.ScreenInsets.CoreUISafeInsets)
	g.topbar = screenGui("KingdomTopbar", 11, Enum.ScreenInsets.TopbarSafeInsets)
	g.menus = screenGui("KingdomMenus", 20, Enum.ScreenInsets.CoreUISafeInsets)
	g.modals = screenGui("KingdomModals", 40, Enum.ScreenInsets.None)
	g.notices = screenGui("KingdomNotices", 70, Enum.ScreenInsets.CoreUISafeInsets)
	g.modals.Enabled = true
	g.notices.Enabled = true
	self._scales = {}
	for _, key in { "backdrop", "hud", "menus", "modals", "notices" } do
		self.roots[key], self._scales[key] = scaledRoot(g[key])
	end
	self._probe = Create("Frame", {
		Name = "SafeAreaProbe",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = g.hud,
	})
	self.view = KingdomHud.new(self.roots.hud, g.topbar, self._motion)
	for _, item in self._railItems do
		self.view:addMenu(item)
	end
	for id, count in self._railBadges do
		self.view:setRailBadge(id, count)
	end
	self.panel = KingdomPanel.new(self.roots.menus)
	self.toasts = ToastStack.new(self.roots.notices, self._motion)
	for _, key in { "backdrop", "hud", "topbar", "menus", "modals", "notices" } do
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
	-- the kingdom panel's building detail goes back to the Buildings tab first
	self:setBackStep("kingdom", function()
		if self.state.panel.upgradeId == nil then
			return false
		end
		self:back()
		return true
	end)
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
	-- My kingdom's population (G13.2, approved by FORGE-00; FORGE-01 declares it): the job panel
	-- and the army panel read it from the store.
	self:_follow("Kingdom.Population", "Kingdom.GetPopulation", function(payload)
		store:applyPopulation(payload)
	end)
	self:_follow("Build.Buildings", nil, function(list)
		store:applyBuildings(list, false)
	end)
	self:_followWarAsk()
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
	if self._releaseBack ~= nil then
		pcall(self._releaseBack)
		self._releaseBack = nil
	end
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
	if what == "population" then
		self:_settleJobs(nil)
	end
	if what == "diplomacy" or what == "kingdoms" then
		self:_onDiplomacy()
	end
	if what == "kingdoms" then
		local kingdom = self.store:mine()
		local mine = if kingdom then kingdom.id else nil
		if mine ~= self._mine then
			self._mine = mine
			-- Another kingdom's people: drop the old counts and quotas (FORGE-05 M2 on #55).
			self.store:clearPopulation()
			self.state.panel.jobs = { pending = {}, quota = {}, at = {} }
			if mine ~= nil then
				-- A late join: the treasury of the new kingdom was never pushed to this client.
				self:_fetch("Treasury.Get", function(totals)
					self.store:applyTreasury(totals)
				end)
				self:_fetch("Kingdom.GetPopulation", function(payload)
					self.store:applyPopulation(payload)
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
	if self._destroyed then
		return -- a reply that arrives after destroy has no screen to speak on (FORGE-05, #48 review)
	end
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

-- Non-yielding: RemoteClient:invoke waits up to 10 s for a remote to replicate, which for a remote
-- the server never declared means a 10 s wait before "Couldn't reach the server" (FORGE-05 L5).
-- RemoteService creates every declared remote at server start, before any player can tap.
function KingdomHudController:hasRemote(name: string): boolean
	local area, action = string.match(name, "^([%w_]+)%.([%w_]+)$")
	if area == nil or action == nil then
		return false
	end
	local ok, found = pcall(function()
		local root = self._env.ReplicatedStorage:FindFirstChild("ForgeRemotes") -- Core/RemoteClient ROOT
		local folder = if root then root:FindFirstChild(area) else nil
		return folder ~= nil and folder:FindFirstChild(action) ~= nil
	end)
	return ok and found == true
end

function KingdomHudController:setSheet(menu: string, on: boolean?)
	self._sheets[menu] = if on == false then nil else true
end

function KingdomHudController:sheetOpen(metrics: any?): boolean
	local menu = self.state.menu
	if menu == nil or self._sheets[menu] ~= true then
		return false
	end
	local m = metrics or self:metrics()
	return m.breakpoint == "phone"
end

-- FORGE-04's NotificationController shows the toasts when it is present (notify above), so it goes
-- where the fallback stack goes: under the pills beside an open phone drawer, else left of the rail
-- (FORGE-05 M1 on #33: unplaced, its top-right stack covered the rail and the drawer's Close on
-- phones). Its ScreenGui has no UIScale, so logical px are multiplied by the layout scale. place()
-- rebuilds its cards: it is called only when the placement changes, not on every push.
function KingdomHudController:_placeNotifications(right: number, top: number, width: number, scale: number)
	local notifications = self._notifications
	if notifications == nil or notifications.place == nil then
		return
	end
	local x, y, w = math.floor(right * scale + 0.5), math.floor(top * scale + 0.5), math.floor(width * scale + 0.5)
	local key = `{x}|{y}|{w}`
	if key == self._notificationsAt then
		return
	end
	self._notificationsAt = key
	pcall(function()
		notifications:place(UDim2.fromOffset(x, y), Vector2.new(1, 0), w)
	end)
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
	self:_syncBack()
	if id == "kingdom" then
		self.state.panel.tab = "overview"
		self.state.panel.upgradeId = nil
	end
	self.menuChanged:fire(id)
	self:render()
end

-- The back key (FORGE-04's InputModeController:onBack, #130: gamepad B, Backspace). One handler is
-- registered while any drawer is open and released when it closes. A press first asks the open
-- menu's step (registered by its controller: a phone detail goes back to its list, a conversation's
-- confirm back to its question); a step that returns true took it. Otherwise the drawer closes, the
-- same as its Close button. One press, one step.
function KingdomHudController:setBackStep(menu: string, step: (() -> boolean)?)
	self._backSteps[menu] = step
end

function KingdomHudController:backPressed(): boolean
	local menu = self.state.menu
	if menu == nil then
		return false
	end
	local step = self._backSteps[menu]
	if step ~= nil then
		local ok, took = pcall(step)
		if ok and took == true then
			return true
		end
	end
	self:setMenu(nil)
	return true
end

function KingdomHudController:_syncBack()
	if self.state.menu ~= nil and self._releaseBack == nil and not self._destroyed then
		local input = self._registry:find("InputModeController")
		if input ~= nil and input.onBack ~= nil then
			self._releaseBack = input:onBack(function()
				return self:backPressed()
			end)
		end
	elseif self.state.menu == nil and self._releaseBack ~= nil then
		local release = self._releaseBack
		self._releaseBack = nil
		pcall(release)
	end
end

-- Undoes addRailItem (a controller that is destroyed takes its rail button with it).
function KingdomHudController:removeRailItem(id: string)
	for i, item in self._railItems do
		if item.id == id then
			table.remove(self._railItems, i)
			break
		end
	end
	if self.view and not self._destroyed then
		self.view:removeMenu(id)
		self:render()
	end
end

function KingdomHudController:addRailItem(item: {
	id: string,
	icon: string,
	label: string,
	target: string?,
	order: number?,
	hideEmpty: boolean?,
	onActivated: (() -> ())?,
})
	table.insert(self._railItems, item)
	if self.view then
		self.view:addMenu(item)
		self:render()
	end
end

-- A count bubble on a rail button (UI/KingdomHud:setRailBadge); patched in place, no render.
function KingdomHudController:setRailBadge(id: string, count: number?)
	self._railBadges[id] = count
	if self.view then
		self.view:setRailBadge(id, count)
	end
end

-- A rail tap: an item with its own action (onActivated) runs it; any other opens or closes its menu.
function KingdomHudController:railTapped(id: string)
	for _, item in self._railItems do
		if item.id == id and item.onActivated ~= nil then
			item.onActivated()
			return
		end
	end
	self:setMenu(id)
end

-- Only the toasts move (no full render): the tracker calls this from its own render.
function KingdomHudController:setStackBottom(y: number?)
	if y == self._stackBottom then
		return
	end
	self._stackBottom = y
	if self._mounted then
		self:_placeToasts(self:metrics())
	end
end

function KingdomHudController:_placeToasts(m: any)
	if self:sheetOpen(m) then
		-- A phone sheet covers the usual toast corner (FORGE-05 L4): in the band between the pills and
		-- the sheet's right edge, above the sheet; one at a time in the fallback stack
		-- (NotificationController's place() has no limit: it keeps its own queue of three).
		local band = Layout.sheetToast(m)
		self.toasts:place(UDim2.fromOffset(band.right, band.y), Vector2.new(1, 0), band.width, 1)
		self:_placeNotifications(band.right, band.y, band.width, m.scale)
		return
	end
	local drawerOpen = self.state.menu ~= nil
	local free = Layout.freeArea(m, drawerOpen)
	local right = if drawerOpen and m.breakpoint == "phone"
		then free.width - 10
		else m.width - m.rail.right - m.rail.button - 12
	local top = Layout.toastTop(m, drawerOpen, self._stackBottom)
	self.toasts:place(UDim2.fromOffset(right, top), Vector2.new(1, 0), m.toast.width)
	-- FORGE-04's stack goes to the same spot, in screen px (#74)
	self:_placeNotifications(right, top, m.toast.width, m.scale)
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

-- Forgets acknowledged quotas the server's payload now shows (FORGE-05 on #65, measured with #61).
-- Runs when a population push arrives, never against the payload already held when the ack came:
-- that one may be from before the request. `expired` (an ack ACK_HOLD_SEC old, from changeJob's
-- timer) yields to the server's quota too, so a co-ruler's later change wins. Without `quotas` in
-- the payload the ack is the best target known, so it stays.
function KingdomHudController:_settleJobs(expired: string?)
	local jobs = self.state.panel.jobs
	local population = self.store:population()
	local quotas = if population then population.quotas else nil
	if quotas == nil then
		return
	end
	for job, target in jobs.quota do
		if job == expired or quotas[job] == target then
			jobs.quota[job] = nil
			jobs.at[job] = nil
		end
	end
end

-- FL-0065: one more or one fewer worker in a job. The count is the server's (Kingdom.Population);
-- the request sets the job's quota to its newest target ± 1 (JobModel.target) and the server fills
-- it from the free (hauler) pool. The count changes here only when its push arrives.
-- ------------------------------------------------------------------ war and peace (FL-0129)

-- The Rivals view for this moment, or nil when the server has no diplomacy remote.
function KingdomHudController:_rivals(): any
	if not self:hasRemote(KingdomHudController.DIPLOMACY) then
		return nil
	end
	local store = self.store
	local phase = if store.match then store.match.phase else nil
	return DiplomacyModel.view(store, store:diplomacy(), phase, self._env.serverTimeNow(), {
		userId = self:_localUserId(),
		nameOf = function(userId: number): string?
			return self:_nameOf(userId)
		end,
	})
end

-- Diplomacy changed: the Kingdom rail button counts the peace offers waiting for my answer, and each new
-- offer is said once ("Azure proposes peace").
-- The Raid rail button follows FORGE-04's alert(): shown while a raid lasts, gone after (polled each tick;
-- absent controller or a failing call = no button).
function KingdomHudController:_syncRaid()
	local war = self._registry:find("FeedbackWarController")
	local raid = false
	if war ~= nil and type(war.alert) == "function" then
		local ok, alert = pcall(war.alert, war)
		raid = ok and alert ~= nil
	end
	if raid == (self._raidShown == true) then
		return
	end
	self._raidShown = raid
	if not raid then
		self:removeRailItem(KingdomHudController.RAID_RAIL.id)
		return
	end
	local item = table.clone(KingdomHudController.RAID_RAIL)
	item.onActivated = function()
		local current = self._registry:find("FeedbackWarController")
		if current ~= nil and type(current.goToAlert) == "function" then
			pcall(current.goToAlert, current)
		end
	end
	self:addRailItem(item)
end

-- Listens to Kingdom.WarAsk once the server declares it (now or when the diplomacy state first arrives;
-- never before, so today's main logs no missing remote).
function KingdomHudController:_followWarAsk()
	if self._warAskFollowed or not self:hasRemote(KingdomHudController.WAR_ASK) then
		return
	end
	self._warAskFollowed = true
	self:_follow(KingdomHudController.WAR_ASK, nil, function(_userId, requesterName, target)
		self:_onWarAsk(requesterName, target)
	end)
end

-- A co-ruler asks me, the senior ruler, to declare war: said once, with where to answer.
function KingdomHudController:_onWarAsk(requesterName: any, target: any)
	if self._destroyed then
		return
	end
	local who = if type(requesterName) == "string" and requesterName ~= "" then requesterName else "A ruler"
	local kingdom = if type(target) == "string" then self.store:kingdom(target) else nil
	if kingdom == nil then
		return
	end
	local name = if type(kingdom.name) == "string" then kingdom.name else target
	self:notify({
		kind = "warning",
		title = `{who} asks for war on {name}`,
		body = "Open Kingdom → Rivals to decide",
	})
end

function KingdomHudController:_onDiplomacy()
	self:_followWarAsk()
	local view = self:_rivals()
	self:setRailBadge("kingdom", if view and view.incoming > 0 then view.incoming else nil)
	if view == nil then
		return
	end
	local seen = self._offersSeen or {}
	local now = {}
	for _, row in view.rows do
		for _, action in row.actions do
			if action.id == "acceptPeace" then
				now[row.id] = true
				if not seen[row.id] then
					self:notify({
						kind = "info",
						title = `{row.name} proposes peace`,
						-- D-054: a co-ruler sees the offer, but the senior ruler answers it
						body = if view.senior then `{view.senior} decides` else "Open Kingdom → Rivals to answer",
					})
				end
			end
		end
	end
	self._offersSeen = now
end

-- A Rivals button: Declare war asks first (it changes the match); the others go to the server at once.
function KingdomHudController:diplomacyAction(kingdomId: string, action: string)
	if action == "declareWar" then
		self.state.panel.confirmWar = kingdomId
		self:render()
		return
	end
	self:_diplomacy(action, kingdomId)
end

function KingdomHudController:confirmWar(kingdomId: string)
	self.state.panel.confirmWar = nil
	self:_diplomacy("declareWar", kingdomId)
end

function KingdomHudController:cancelWar()
	self.state.panel.confirmWar = nil
	self:render()
end

-- What a successful request did. War is told from the server's answer, never from the client's copy
-- of who is senior (D-054: seniority can move while the panel is open; FORGE-07 M1 on #180):
-- "declared" = war is declared, "asked" = the senior ruler was asked; anything else stays neutral.
local WAR_DONE = table.freeze({
	declared = function(name: string): string
		return `War declared on {name}`
	end,
	asked = function(name: string): string
		return `Asked your senior ruler for war on {name}`
	end,
})

local DIPLOMACY_DONE = table.freeze({
	declareWar = function(name: string): string
		return `War request sent: {name}`
	end,
	proposePeace = function(name: string): string
		return `Peace offered to {name}`
	end,
	acceptPeace = function(name: string): string
		return `Peace with {name}`
	end,
})

function KingdomHudController:_diplomacy(action: string, kingdomId: string)
	local p = self.state.panel
	if p.diplomacyPending[kingdomId] then
		return -- one request per rival at a time
	end
	local kingdom = self.store:kingdom(kingdomId)
	local name = if kingdom and type(kingdom.name) == "string" then kingdom.name else kingdomId
	p.diplomacyPending[kingdomId] = true
	self:render()
	self._env.spawn(function()
		local called, ok, reason = pcall(function()
			return self.remotes:invoke(KingdomHudController.DIPLOMACY, action, kingdomId)
		end)
		p.diplomacyPending[kingdomId] = nil
		if self._destroyed then
			return
		end
		if called and ok == true then
			local war = if action == "declareWar" and type(reason) == "string" then WAR_DONE[reason] else nil
			local done = war or DIPLOMACY_DONE[action]
			local title = if done then done(name) else name
			self:notify({ kind = "success", title = title })
		else
			self:notify({
				kind = "warning",
				title = Text.reason(if called then reason else nil),
				body = name,
			})
		end
		self:render()
	end)
end

function KingdomHudController:changeJob(jobId: string, delta: number)
	local jobs = self.state.panel.jobs
	local population = self.store:population()
	if population == nil or not JobModel.isJob(jobId) or jobs.pending[jobId] ~= nil then
		return
	end
	-- Step from the job's newest target, not the count (FORGE-05 M1 on #55), and keep adds within
	-- the free citizens not yet promised to another job.
	local base = JobModel.target(population, jobs, jobId)
	local target
	if delta > 0 then
		target = base + 1
		if target > JobModel.MAX_QUOTA or JobModel.freeLeft(population, jobs) <= 0 then
			return
		end
	else
		-- above the remote's 50 (a server-set quota), − brings it to 50 (L7)
		target = math.min(base - 1, JobModel.MAX_QUOTA)
		if target < 0 then
			return
		end
	end
	local env = self._env
	local kingdom = self._mine
	jobs.pending[jobId] = target
	self:render()
	env.spawn(function()
		local called, ok, reason = pcall(function()
			return self.remotes:invoke("Kingdom.SetJobQuota", jobId, target)
		end)
		if self.state.panel.jobs ~= jobs or self._mine ~= kingdom then
			return -- the kingdom changed meanwhile: this answer belongs to the old one
		end
		jobs.pending[jobId] = nil
		if called and ok == true then
			local stamp = env.clock()
			jobs.quota[jobId] = target
			jobs.at[jobId] = stamp
			self._motion:after(JobModel.ACK_HOLD_SEC, function()
				if self.state.panel.jobs == jobs and jobs.at[jobId] == stamp then
					self:_settleJobs(jobId) -- no push showed it in time: the server's quota wins
					self:render()
				end
			end)
		else
			self:notify({
				kind = "error",
				title = "Couldn't change jobs",
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
	local rivals = self:_rivals()
	local tabs = table.clone(KingdomPanel.TABS)
	if rivals then
		table.insert(tabs, KingdomPanel.RIVALS_TAB)
	elseif p.tab == "rivals" then
		p.tab = "overview" -- the server stopped serving diplomacy
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
		jobs = if p.tab == "jobs" then JobModel.view(store:population(), p.jobs) else nil,
		tabs = if rivals then tabs else nil,
		rivals = if p.tab == "rivals" then rivals else nil,
		confirm = p.confirmWar,
	}
end

function KingdomHudController:render()
	if not self._mounted then
		return
	end
	local m = self:metrics()
	for _, key in { "backdrop", "hud", "menus", "modals", "notices" } do
		self._scales[key].Scale = m.scale
		self.roots[key].Size = UDim2.fromScale(1 / m.scale, 1 / m.scale)
	end
	local store = self.store
	local s = self.state
	local banner = HudModel.banner(store)
	local active = banner ~= nil
	self.guis.hud.Enabled = active
	-- The phase bar stays for a ruler without a kingdom while a match runs: a fallen ruler who stays
	-- to watch still sees the phase and time left (FL-0129; FORGE-07 L3 on #185). Its pill exists once
	-- the HUD was built for this player's kingdom; refreshTimer keeps it current every tick.
	self.guis.topbar.Enabled = active or (store.match ~= nil and store.match.phase ~= nil)
	self.guis.menus.Enabled = active
	self.guis.backdrop.Enabled = active
	if not active and s.menu ~= nil then
		s.menu = nil
		self:_syncBack() -- the back key's handler goes with the drawer (FORGE-07 L1 on #162)
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
				self:railTapped(id)
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
			onJob = function(jobId, delta)
				self:changeJob(jobId, delta)
			end,
			onDiplomacy = function(kingdomId, action)
				self:diplomacyAction(kingdomId, action)
			end,
			onConfirmWar = function(kingdomId)
				self:confirmWar(kingdomId)
			end,
			onCancelWar = function()
				self:cancelWar()
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
			local name = s.confirm.name
			s.confirm = nil
			self:notify({ kind = "info", title = `{name} changed`, body = "Check its new level and price" })
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

	self:_placeToasts(m)
	self.rendered:fire(m)
end

function KingdomHudController:_tick()
	if not self._mounted or self.view == nil then
		return
	end
	self.view:refreshTimer(HudModel.timer(self.store.match, self._env.serverTimeNow()), self:metrics())
	-- the Rivals tab's countdowns (offers, truces, grace) tick: patched in place by RivalsList.paint
	if self.state.menu == "kingdom" and self.state.panel.tab == "rivals" then
		self:render()
	end
	self:_syncRaid()
	-- an offer of peace runs out without a push: the Kingdom bubble follows the clock (FORGE-07 L2 on #180)
	if self.store:diplomacy() ~= nil then
		local view = self:_rivals()
		local count = if view and view.incoming > 0 then view.incoming else nil
		if count ~= self._railBadges.kingdom then
			self:setRailBadge("kingdom", count)
		end
	end
end

return Def
