--!strict
--[[
	SettingsPanelController (FORGE-04, client, FL-0103): the player's settings panel — volumes per
	audio group, reduced motion, camera shake, effects quality, hints, citizen chatter and
	notifications (Experience/SettingsModel), drawn with FORGE-03's kit (Experience/SettingsPanel).
	Every change goes through SettingsController:set (the server keeps it for the session, FL-0024);
	the panel redraws from SettingsController.changed, so it always shows what is in force.

		panel:open()  panel:close()  panel:toggle()  panel.isOpen
		panel:change(key, action) -> boolean    SettingsModel.next, then SettingsController:set
		panel:render(metrics?)                  draws (or patches) the panel when open
		panel.view (Experience/SettingsPanel)   SettingsPanelController.MENU = "settings"

	Host: the first controller in Def.HOSTS that the registry has (registry:find in start). A game
	HUD that offers menus — addRailItem, setMenu, menuChanged, rendered(metrics), metrics() with a
	`drawer` rect, roots.menus — gets a rail button "Settings" (RAIL) and the panel opens in its
	drawer as the menu "settings"; opening another menu closes it. game-001: KingdomHudController
	(FORGE-03). Without a host the panel has its own ScreenGui "ForgeSettings" (DisplayOrder 30, the
	menus band of interfaces §9), centred, at most WIDTH px wide; open() shows it.
]]

local SettingsModel = require("@game/ReplicatedStorage/Forge/Experience/SettingsModel")
local SettingsPanel = require("@game/ReplicatedStorage/Forge/Experience/SettingsPanel")

local Controller = {}
Controller.__index = Controller

local Def = { name = "SettingsPanelController", dependencies = { "SettingsController" } }

Controller.MENU = "settings"
Def.HOSTS = table.freeze({ "KingdomHudController" })
Def.RAIL =
	table.freeze({ id = "settings", icon = "settings", label = "Settings", target = "HUD.SettingsButton", order = 9 })
Def.DISPLAY_ORDER = 30
Def.WIDTH = 420
Def.MARGIN = 16

local function connect(signal: any, handler: (...any) -> ()): any
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		if type(signal) == "table" and type(signal.connect) == "function" then
			return signal:connect(handler)
		end
		return signal:Connect(handler)
	end)
	return if ok then connection else nil
end

-- options.playerGui: where the hostless ScreenGui goes (specs; live: the local player's PlayerGui)
function Def.create(env: any, registry: any, options: { [string]: any }?)
	return setmetatable({
		_env = env,
		_playerGui = options and options.playerGui,
		_registry = registry,
		_settings = registry:get("SettingsController"),
		_connections = {} :: { any },
		isOpen = false,
		view = nil :: any,
		host = nil :: any,
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:start()
	local registry = self._registry
	for _, name in Def.HOSTS do
		local host = registry:find(name)
		if host and host.addRailItem and host.setMenu then
			self.host = host
			break
		end
	end
	local host = self.host
	for _, connection in
		{
			connect(self._settings.changed, function()
				if self.isOpen then
					self:render()
				end
			end),
			connect(host and host.menuChanged, function(menu)
				local open = menu == Controller.MENU
				if open ~= self.isOpen then
					self.isOpen = open
					self:render()
				end
			end),
			connect(host and host.rendered, function(metrics)
				if self.isOpen then
					self:render(metrics)
				end
			end),
		}
	do
		table.insert(self._connections, connection)
	end
	if host then
		pcall(host.addRailItem, host, Def.RAIL)
	end
end

function Controller:destroy()
	for _, connection in self._connections do
		pcall(function()
			if connection.Disconnect then
				connection:Disconnect()
			else
				connection:disconnect()
			end
		end)
	end
	table.clear(self._connections)
	if self.host and self.host.removeRailItem then
		pcall(self.host.removeRailItem, self.host, Def.RAIL.id)
	end
	if self.view then
		self.view:destroy()
		self.view = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self.isOpen = false
end

function Controller:open()
	if self.isOpen then
		return
	end
	if self.host then
		self.host:setMenu(Controller.MENU) -- menuChanged opens it
	else
		self.isOpen = true
		self:render()
	end
end

function Controller:close()
	if not self.isOpen then
		return
	end
	if self.host then
		self.host:setMenu(nil)
	else
		self.isOpen = false
		self:render()
	end
end

function Controller:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

function Controller:change(key: string, action: string): boolean
	local nextValue = SettingsModel.next(key, self._settings:get(key), action)
	if nextValue == nil then
		return false
	end
	return self._settings:set(key, nextValue) == true
end

function Controller:_sections(): { { [string]: any } }
	local settings = self._settings
	local values = {}
	for _, section in SettingsModel.SECTIONS do
		for _, key in section.keys do
			values[key] = settings:get(key)
		end
	end
	local platform = false
	pcall(function()
		platform = self._env.GuiService.ReducedMotionEnabled == true
	end)
	return SettingsModel.sections(values, { platformReducedMotion = platform })
end

-- Own ScreenGui (no host): created on first open.
function Controller:_ownParent(): (any, { [string]: any }?)
	if self._gui == nil then
		local ok, playerGui = pcall(function()
			if self._playerGui then
				return self._playerGui
			end
			local player = self._env.Players.LocalPlayer
			return if player then player:FindFirstChildOfClass("PlayerGui") else nil
		end)
		if not ok or playerGui == nil then
			return nil, nil
		end
		local gui = self._env.newInstance("ScreenGui")
		gui.Name = "ForgeSettings"
		gui.DisplayOrder = Def.DISPLAY_ORDER
		gui.ResetOnSpawn = false
		pcall(function()
			gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		end)
		gui.Parent = playerGui
		self._gui = gui
	end
	local size = Vector2.new(800, 600)
	pcall(function()
		local measured = self._gui.AbsoluteSize
		if measured.X > 0 and measured.Y > 0 then
			size = measured
		end
	end)
	local width = math.min(Def.WIDTH, size.X - 2 * Def.MARGIN)
	local height = size.Y - 2 * Def.MARGIN
	return self._gui,
		{
			x = math.floor((size.X - width) / 2),
			y = Def.MARGIN,
			width = width,
			height = height,
			compact = size.X < 600 or size.Y < 500,
		}
end

function Controller:render(metrics: any?)
	if not self.isOpen then
		if self.view then
			self.view:destroy()
			self.view = nil
		end
		if self._gui then
			self._gui.Enabled = false
		end
		return
	end
	local parent, frame
	local host = self.host
	if host then
		local m = metrics
		if m == nil and host.metrics then
			local ok, measured = pcall(host.metrics, host)
			m = if ok then measured else nil
		end
		local drawer = m and m.drawer
		local roots = host.roots
		if drawer == nil or roots == nil or roots.menus == nil then
			return
		end
		parent = roots.menus
		frame = {
			x = drawer.x,
			y = drawer.y,
			width = drawer.width,
			height = drawer.height,
			compact = m.breakpoint == "phone",
		}
	else
		parent, frame = self:_ownParent()
		if parent == nil then
			return
		end
		self._gui.Enabled = true
	end
	if self.view == nil or self.view._parent ~= parent then
		if self.view then
			self.view:destroy()
		end
		self.view = SettingsPanel.new(parent)
	end
	self.view:render(self:_sections(), frame :: any, {
		onChange = function(key, action)
			self:change(key, action)
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
