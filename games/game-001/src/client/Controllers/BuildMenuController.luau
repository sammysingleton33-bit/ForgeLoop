--!strict
--[[
	BuildMenuController (FORGE-03, game-001 client, FL-0059) — the build menu and building
	placement, end to end:
		1. Build (HUD rail) opens the drawer: tabs Economy / Homes / Military, each building with its
		   cost against the treasury, its build time and footprint (UI/BuildModel).
		2. "Place <building>" closes the drawer and enters build mode: InputModeController:set("build")
		   (FORGE-04, G4.1) and a ghost of the `Kit.footprint` size in the world (UI/Ghost).
		3. Every new ghost spot is checked with `Build.CanPlace(type, position, rot)`, throttled
		   (UI/Placement.Checker, under the remote's 10/s): green = valid, red = the server's reason.
		4. Rotate turns it in 90° steps; Place calls `Build.Place(type, position, rot)`. The server
		   charges the treasury (Treasury.Changed → the pills float the spend) and the new building
		   arrives through Build.Buildings (a construction chip). A toast confirms; a refusal keeps
		   build mode open with the reason.
		5. Cancel (or leaving build mode elsewhere) removes the ghost and returns to "explore".
	No CFrame crosses the wire (G8): the server builds CFrame.new(position) * CFrame.Angles(0, rot·π/2, 0).

	Depends on KingdomHudController (store, remotes, menus, layout, notifications).
	Optional: InputModeController (FORGE-04). Live input: UI/PlacementInput (mouse, touch, R/Q keys).

	API (specs and the snapshot scenes drive these directly)
		build:selectCategory(id)  build:selectBuilding(type)  build:back()
		build:startPlacement(type)  build:aimAt(position: Vector3)  build:rotate()
		build:confirm()  build:cancel()
		build.state = { category, selected, phoneView }   build.placing = { type, rot, position?,
		    status ("pending" | "ok" | "bad"), reason?, busy, footprint, room? }?
		build.menu (UI/BuildMenu)  build.bar (UI/PlacementBar)  build.ghost (UI/Ghost)?
]]

local BuildModel = require("../UI/BuildModel")
local BuildMenu = require("../UI/BuildMenu")
local Buildings = require("../UI/Buildings")
local Ghost = require("../UI/Ghost")
local Placement = require("../UI/Placement")
local PlacementBar = require("../UI/PlacementBar")
local PlacementInput = require("../UI/PlacementInput")
local Text = require("../UI/Text")

local BuildMenuController = {}
BuildMenuController.__index = BuildMenuController

local Def = { name = "BuildMenuController", dependencies = { "KingdomHudController" } }

-- Used when Kit has no footprint for a type (never for the G2 types; a guard, not a rule).
BuildMenuController.FALLBACK_FOOTPRINT = Vector2.new(16, 16)

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { category = "economy", selected = nil :: string?, phoneView = "list" },
		placing = nil :: any,
		ghost = nil :: any,
	}, BuildMenuController)
end

function BuildMenuController:start()
	local env = self._env
	local hud = self.hud
	self._inputMode = self._registry:find("InputModeController")
	self._connections = {
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end),
		hud.menuChanged:connect(function(menu)
			if menu ~= nil and self.placing then
				self:cancel()
			end
			if menu == "build" then
				self.state.phoneView = "list"
			end
		end),
	}
	local modeSignal = self._inputMode and self._inputMode.changed
	if modeSignal then
		pcall(function()
			local function onMode(mode)
				if mode ~= "build" and self.placing and not self._leaving then
					self:cancel()
				end
			end
			table.insert(
				self._connections,
				if modeSignal.connect then modeSignal:connect(onMode) else modeSignal:Connect(onMode)
			)
		end)
	end
	self._checker = Placement.Checker.new({
		invoke = function(buildingType, position, rot)
			return hud.remotes:invoke("Build.CanPlace", buildingType, position, rot)
		end,
		onResult = function(key, ok, reason)
			self:_onVerdict(key, ok, reason)
		end,
		spawn = env.spawn,
		wait = env.wait,
		clock = env.clock,
	})
	self._disconnectInput = PlacementInput.connect(env, {
		active = function()
			return self.placing ~= nil
		end,
		aim = function(position)
			self:aimAt(position)
		end,
		rotate = function()
			self:rotate()
		end,
		confirm = function()
			self:confirm()
		end,
		cancel = function()
			self:cancel()
		end,
	}, function()
		return self:_exclude()
	end)
end

function BuildMenuController:destroy()
	if self.placing then
		self:cancel()
	end
	for _, connection in self._connections or {} do
		connection:disconnect()
	end
	if self._disconnectInput then
		self._disconnectInput()
	end
	if self.menu then
		self.menu:destroy()
	end
end

function BuildMenuController:_exclude(): { Instance }
	local list = {}
	if self.ghost then
		table.insert(list, self.ghost.folder)
	end
	local player = self._env.Players.LocalPlayer
	if player and player.Character then
		table.insert(list, player.Character)
	end
	return list
end

-- ------------------------------------------------------------------ menu

function BuildMenuController:selectCategory(id: string)
	self.state.category = id
	self.state.selected = nil
	self.state.phoneView = "list"
	self.hud:render()
end

function BuildMenuController:selectBuilding(buildingType: string)
	self.state.selected = buildingType
	self.state.phoneView = "detail"
	self.hud:render()
end

function BuildMenuController:back()
	self.state.phoneView = "list"
	self.hud:render()
end

-- ------------------------------------------------------------------ placement

function BuildMenuController:_setMode(mode: string)
	local input = self._inputMode
	if input and input.set then
		self._leaving = mode ~= "build"
		pcall(function()
			input:set(mode)
		end)
		self._leaving = false
	end
end

function BuildMenuController:startPlacement(buildingType: string)
	local detail = BuildModel.placeDetail(self.hud.store, buildingType)
	if detail == nil or detail.cta.state ~= "ready" then
		return
	end
	if self.placing then
		self:cancel()
	end
	self.placing = {
		type = buildingType,
		name = detail.name,
		rot = 0,
		position = nil :: Vector3?,
		key = nil :: string?,
		status = "pending",
		reason = nil :: string?,
		busy = false,
		footprint = detail.footprint or BuildMenuController.FALLBACK_FOOTPRINT,
		room = detail.room, -- largest level + gap: what the server keeps free (#62)
	}
	self.ghost = Ghost.new(self._env)
	if self.hud.state.menu == "build" then
		self.hud:setMenu(nil)
	end
	self:_setMode("build")
	self.hud:setPlacing(true)
	PlacementInput.aimAtScreenCentre(self._env, function(position)
		self:aimAt(position)
	end, function()
		return self:_exclude()
	end)
end

function BuildMenuController:_refreshGhost()
	local p = self.placing
	if p == nil or p.position == nil or self.ghost == nil then
		return
	end
	self.ghost:show(p.footprint, Placement.cframe(p.position, p.rot), p.room)
	self.ghost:tint(p.status)
end

function BuildMenuController:aimAt(position: Vector3)
	local p = self.placing
	if p == nil or p.busy then
		return
	end
	local snapped = Placement.snap(position)
	local key = Placement.key(p.type, snapped, p.rot)
	if key == p.key then
		return
	end
	p.position = snapped
	p.key = key
	p.status = "pending"
	p.reason = nil
	self:_refreshGhost()
	self._checker:request(p.type, snapped, p.rot)
	self.hud:render()
end

function BuildMenuController:rotate()
	local p = self.placing
	if p == nil or p.busy then
		return
	end
	p.rot = Placement.nextRotation(p.rot)
	local position = p.position
	p.key = nil
	if position then
		self:aimAt(position)
	else
		self.hud:render()
	end
end

function BuildMenuController:_onVerdict(key: string, ok: boolean, reason: string?)
	local p = self.placing
	if p == nil or p.key ~= key then
		return -- a reply for a spot the ghost already left
	end
	p.status = if ok then "ok" else "bad"
	p.reason = if ok then nil else Text.reason(reason)
	self:_refreshGhost()
	self.hud:render()
end

function BuildMenuController:confirm()
	local p = self.placing
	if p == nil or p.busy or p.status ~= "ok" or p.position == nil then
		return
	end
	p.busy = true
	self.hud:render()
	local hud = self.hud
	self._env.spawn(function()
		local called, buildingId, reason = pcall(function()
			return hud.remotes:invoke("Build.Place", p.type, p.position, p.rot)
		end)
		if self.placing ~= p then
			return -- cancelled while waiting
		end
		p.busy = false
		if called and type(buildingId) == "number" then
			hud:notify({ kind = "success", title = `{p.name} placed`, body = "Builders are on their way" })
			self:_stop()
		else
			local text = Text.reason(if called then reason else nil)
			p.status = "bad"
			p.reason = text
			self:_refreshGhost()
			hud:notify({ kind = "error", title = `Couldn't place the {p.name}`, body = text })
			hud:render()
		end
	end)
end

function BuildMenuController:cancel()
	if self.placing then
		self:_stop()
	end
end

function BuildMenuController:_stop()
	self._checker:cancel()
	if self.ghost then
		self.ghost:destroy()
		self.ghost = nil
	end
	self.placing = nil
	self:_setMode("explore")
	self.hud:setPlacing(false)
end

-- ------------------------------------------------------------------ rendering

function BuildMenuController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.menu = self.menu or BuildMenu.new(hud.roots.menus)
	self.bar = self.bar or PlacementBar.new(hud.roots.hud)
	if hud.state.menu == "build" then
		local view = BuildModel.menu(hud.store, { category = self.state.category, selected = self.state.selected })
		self.menu:render(view, metrics, {
			phoneView = self.state.phoneView,
			onCategory = function(id)
				self:selectCategory(id)
			end,
			onSelect = function(buildingType)
				self:selectBuilding(buildingType)
			end,
			onBack = function()
				self:back()
			end,
			onPlace = function(detail)
				self:startPlacement(detail.type)
			end,
			onClose = function()
				hud:setMenu(nil)
			end,
		})
	else
		self.menu:destroy()
	end
	local p = self.placing
	if p and hud.guis.hud and hud.guis.hud.Enabled then
		local info = Buildings.get(p.type)
		local detail = BuildModel.placeDetail(hud.store, p.type)
		local costs = {}
		for _, c in if detail then detail.costs else {} do
			table.insert(costs, { currency = c.currency, amount = c.amount, short = c.short })
		end
		self.bar:render(
			{
				name = p.name,
				icon = if info then info.icon else "build",
				category = if info then info.category else "economy",
				costs = costs,
				status = p.status,
				reason = p.reason,
				busy = p.busy,
			},
			metrics,
			{
				onRotate = function()
					self:rotate()
				end,
				onCancel = function()
					self:cancel()
				end,
				onPlace = function()
					self:confirm()
				end,
			}
		)
	else
		self.bar:destroy()
	end
end

return Def
