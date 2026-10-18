--!strict
--[[
	KingdomHudSpectateController (FORGE-03, game-001 client, FL-0129) — the spectate screen (D-053 (3):
	eliminated rulers spectate). It starts on either signal:
		FORGE-01's Match.Spectate(spectating, info?) (FL-0125; followed only once the server declares
		it, so today's main logs no missing remote): info = { reason = "eliminated" | "match_full",
		kingdomId?, by?, standing = { KingdomId } }; Match.Spectate(false) when seated again
		FORGE-04's RulerSpectateController.changed(active) (#183): the camera turns on by itself after
		our fall and off at Results / Lobby
	and shows UI/SpectateScreen: the fallen card (who took the keep, Stay / Leave), then the Watching
	panel listing the camera's targets() (battles first, then standing keeps); a tap selects one, Prev /
	Next cycle (the camera's own keys . , and R1 L1 do the same). The current row follows the camera's
	targetChanged. Leave asks first, then leaves the server (Players.LocalPlayer:Kick with a goodbye:
	Roblox has no client "leave" call). Without FORGE-04's controller the card still shows, the list is
	empty.

	Depends on KingdomHudController (remotes, store, menu layer, layout).
	API (specs and scenes)
		spectate:onSpectate(spectating, info?)   what a Match.Spectate push does
		spectate:stay()  spectate:leave()  spectate:confirmLeave()  spectate:cancelLeave()
		spectate:select(index)  spectate:cycle(step)
		spectate.spectating  spectate.info  spectate.state = { card, confirmLeave }  spectate.view
		KingdomHudSpectateController.EVENT = "Match.Spectate"   .POLL_SEC   .GOODBYE
]]

local SpectateModel = require("../UI/SpectateModel")
local SpectateScreen = require("../UI/SpectateScreen")

local KingdomHudSpectateController = {}
KingdomHudSpectateController.__index = KingdomHudSpectateController

local Def = { name = "KingdomHudSpectateController", dependencies = { "KingdomHudController" } }

KingdomHudSpectateController.EVENT = "Match.Spectate"
KingdomHudSpectateController.CAMERA = "RulerSpectateController"
KingdomHudSpectateController.POLL_SEC = 1 -- targets() is re-read this often while spectating
KingdomHudSpectateController.GOODBYE = "You left the match. Thanks for playing AI Kingdoms!"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		spectating = false,
		info = nil :: any,
		state = { card = false, confirmLeave = false },
		view = nil :: any,
		_current = nil :: any,
		_connections = {} :: { any },
	}, KingdomHudSpectateController)
end

local function disconnect(connection: any)
	pcall(function()
		if connection.disconnect then
			connection:disconnect()
		else
			connection:Disconnect()
		end
	end)
end

function KingdomHudSpectateController:_camera(): any
	return self._registry:find(KingdomHudSpectateController.CAMERA)
end

function KingdomHudSpectateController:start()
	local env = self._env
	local hud = self.hud
	-- (kept apart so a spec can prove the POLL_SEC re-read works on a quiet HUD too)
	self._renderedConnection = hud.rendered:connect(function(metrics)
		self:render(metrics)
	end)
	table.insert(self._connections, self._renderedConnection)
	local camera = self:_camera()
	if camera ~= nil then
		pcall(function()
			table.insert(
				self._connections,
				camera.changed:connect(function(active)
					if active and not self.spectating then
						self:onSpectate(true, self.info)
					elseif not active and self.spectating and not self._byServer then
						self:onSpectate(false)
					end
				end)
			)
			table.insert(
				self._connections,
				camera.targetChanged:connect(function(target)
					self._current = target
					self:render()
				end)
			)
		end)
	end
	if hud:hasRemote(KingdomHudSpectateController.EVENT) then
		env.spawn(function()
			local ok, err = pcall(function()
				local connection = hud.remotes:on(KingdomHudSpectateController.EVENT, function(spectating, info)
					self:onSpectate(spectating == true, info, true)
				end)
				if self._destroyed then
					connection:Disconnect()
				else
					table.insert(self._connections, connection)
				end
			end)
			if not ok then
				env.log(
					"warn",
					"KingdomHudSpectateController: cannot listen to " .. KingdomHudSpectateController.EVENT,
					{
						error = tostring(err),
					}
				)
			end
		end)
	end
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(KingdomHudSpectateController.POLL_SEC)
			if self._running and self.spectating then
				self:render()
			end
		end
	end)
end

function KingdomHudSpectateController:destroy()
	self._destroyed = true
	self._running = false
	for _, connection in self._connections do
		disconnect(connection)
	end
	self._connections = {}
	if self.view then
		self.view:destroy()
	end
end

-- Match.Spectate (byServer) or the camera turning on. The server's word wins: a camera that turns off
-- by itself does not end a spectate the server started (only Match.Spectate(false) does).
function KingdomHudSpectateController:onSpectate(spectating: boolean, info: any?, byServer: boolean?)
	if self._destroyed then
		return
	end
	if spectating then
		local first = not self.spectating
		self.spectating = true
		if type(info) == "table" then
			self.info = info
		end
		if byServer then
			self._byServer = true
		end
		if first then
			self.state = { card = true, confirmLeave = false }
			if self.hud.state.menu ~= nil then
				self.hud:setMenu(nil) -- a fallen kingdom has nothing to build or run
			end
			local camera = self:_camera()
			if camera ~= nil and camera.active ~= true and type(camera.setActive) == "function" then
				pcall(camera.setActive, camera, true)
			end
		end
	else
		self.spectating = false
		self.info = nil
		self._byServer = false
		self._current = nil
		self.state = { card = false, confirmLeave = false }
		local camera = self:_camera()
		if byServer and camera ~= nil and camera.active == true and type(camera.setActive) == "function" then
			pcall(camera.setActive, camera, false)
		end
	end
	self:render()
end

function KingdomHudSpectateController:stay()
	self.state = { card = false, confirmLeave = false }
	self:render()
end

function KingdomHudSpectateController:leave()
	self.state = { card = self.state.card, confirmLeave = true }
	self:render()
end

function KingdomHudSpectateController:cancelLeave()
	self.state = { card = self.state.card, confirmLeave = false }
	self:render()
end

function KingdomHudSpectateController:confirmLeave()
	local player = self._env.Players.LocalPlayer
	if player ~= nil then
		pcall(function()
			player:Kick(KingdomHudSpectateController.GOODBYE)
		end)
	end
end

function KingdomHudSpectateController:select(index: number)
	local camera = self:_camera()
	if camera == nil or type(camera.select) ~= "function" then
		return
	end
	local ok, target = pcall(camera.select, camera, index)
	if ok and target ~= nil then
		self._current = target
	end
	self:render()
end

function KingdomHudSpectateController:cycle(step: number)
	local camera = self:_camera()
	if camera == nil or type(camera.cycle) ~= "function" then
		return
	end
	local ok, target = pcall(camera.cycle, camera, if step < 0 then -1 else 1)
	if ok and target ~= nil then
		self._current = target
	end
	self:render()
end

function KingdomHudSpectateController:_targets(): { any }
	local camera = self:_camera()
	if camera == nil or type(camera.targets) ~= "function" then
		return {}
	end
	local ok, list = pcall(camera.targets, camera)
	return if ok and type(list) == "table" then list else {}
end

function KingdomHudSpectateController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.menus == nil then
		return -- not mounted yet (no PlayerGui)
	end
	self.view = self.view or SpectateScreen.new(hud.roots.menus)
	if not self.spectating then
		self.view:destroy()
		return
	end
	local m = metrics or hud:metrics()
	local model = SpectateModel.view(self.info, hud.store, self:_targets(), self._current)
	self.view:render(model, m, self.state, {
		onStay = function()
			self:stay()
		end,
		onLeave = function()
			self:leave()
		end,
		onConfirmLeave = function()
			self:confirmLeave()
		end,
		onCancelLeave = function()
			self:cancelLeave()
		end,
		onSelect = function(index)
			self:select(index)
		end,
		onCycle = function(step)
			self:cycle(step)
		end,
	})
end

return Def
