--!strict
--[[
	CitizenCardController (FORGE-03, game-001 client, FL-0088) — the citizen card v2 (CONTRACTS G13.2):
	select one of your citizens and the drawer shows who they are, how they see you, what they are
	doing, their traits, family, friends and rivals, what they remember, and Talk / Ask.

	Selection (G13.6): `InputModeController.selected:(kind, id)` (FORGE-04; a framework Signal with
	:connect or an RBXScriptSignal with :Connect). kind "citizen" → `Sim.Inspect(id)` in a spawned
	thread, then the card opens in the drawer (`hud:setMenu("citizen")`); any other kind ("none",
	"building", "slot") closes the card if it is open. Only the newest request counts: a slow reply for
	a citizen tapped earlier never replaces the card of the one tapped last. Sim.Inspect returns nil
	for someone else's citizen (or one that is gone): a short notice, no card. While the card is open
	it is refreshed every REFRESH_SEC (intent, mood and requests change as the citizen lives); when
	the refresh returns nil the card closes.

	Talk / Ask: shown when a handler is registered (ConversationController does in its start()).
	Talk (primary) when the citizen has a request (`hasRequest`), Ask (secondary) otherwise.

	Depends on KingdomHudController (remotes, drawer, layout, notices). Optional: InputModeController.
	Never decodes Sim.* events (only EntityController does, G4); Sim.Inspect is a function call.

	API (specs, scenes and ConversationController)
		card:open(entityId)            inspect and show (the selection path calls this)
		card:close()                   closes the card if it is open
		card:onTalk(fn(entityId)) -> () -> ()    the Talk/Ask handler; returns its remover
		card:setTalkState("idle" | "loading")    Talk shows a busy state while a conversation loads
		card.entityId  card.view (the last CitizenView)  card.model (UI/CitizenModel Card)
		card.card (UI/CitizenCard)     CitizenCardController.MENU = "citizen"
		CitizenCardController.REFRESH_SEC
]]

local CitizenCard = require("../UI/CitizenCard")
local CitizenModel = require("../UI/CitizenModel")
local CitizenText = require("../UI/CitizenText")
local HudModel = require("../UI/HudModel")

local CitizenCardController = {}
CitizenCardController.__index = CitizenCardController

local Def = { name = "CitizenCardController", dependencies = { "KingdomHudController" } }

CitizenCardController.MENU = "citizen"
CitizenCardController.REFRESH_SEC = 4

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		entityId = nil :: number?,
		view = nil :: any,
		model = nil :: any,
		talkState = "idle",
		card = nil :: any,
		_token = 0, -- the newest open() request
		_refreshToken = 0, -- the newest refresh; an open() also invalidates refreshes
		_pending = nil :: number?,
		_talk = nil :: ((number) -> ())?,
		_connections = {},
		_running = false,
	}, CitizenCardController)
end

-- Framework Signal (:connect -> :disconnect) or RBXScriptSignal (:Connect -> :Disconnect).
local function connect(signal: any, fn: (...any) -> ()): any
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		if type(signal) == "table" and type(signal.connect) == "function" then
			return signal:connect(fn)
		end
		return signal:Connect(fn)
	end)
	return if ok then connection else nil
end

local function disconnect(connection: any)
	if connection == nil then
		return
	end
	pcall(function()
		if type(connection.disconnect) == "function" then
			connection:disconnect()
		else
			connection:Disconnect()
		end
	end)
end

CitizenCardController.connect = connect
CitizenCardController.disconnect = disconnect

function CitizenCardController:start()
	local env = self._env
	local hud = self.hud
	self._inputMode = self._registry:find("InputModeController")
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	local selected = if self._inputMode then self._inputMode.selected else nil
	local connection = connect(selected, function(kind, id)
		self:_onSelected(kind, id)
	end)
	if connection then
		table.insert(self._connections, connection)
	end
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(CitizenCardController.REFRESH_SEC)
			if self._running and self:isOpen() and self._pending == nil then
				self:_inspect(self.entityId :: number, true)
			end
		end
	end)
end

function CitizenCardController:destroy()
	self._running = false
	for _, connection in self._connections do
		disconnect(connection)
	end
	self._connections = {}
	if self.card then
		self.card:destroy()
	end
end

function CitizenCardController:isOpen(): boolean
	return self.hud.state.menu == CitizenCardController.MENU and self.model ~= nil
end

function CitizenCardController:_onSelected(kind: any, id: any)
	if kind == "citizen" and type(id) == "number" then
		self:open(id)
	else
		self._token += 1 -- a pending inspect for an earlier tap no longer opens anything
		self._pending = nil
		self:close()
	end
end

function CitizenCardController:open(entityId: number)
	self:_inspect(entityId, false)
end

function CitizenCardController:close()
	if self.hud.state.menu == CitizenCardController.MENU then
		self.hud:setMenu(nil)
	end
end

-- Sim.Inspect in a spawned thread (start() and selection handlers never yield). `refresh` = the
-- periodic update of the open card: quiet on failure, closes the card when the citizen is gone.
function CitizenCardController:_inspect(entityId: number, refresh: boolean)
	local hud = self.hud
	self._refreshToken += 1
	local refreshToken = self._refreshToken
	local token = self._token
	if not refresh then
		self._token += 1
		token = self._token
		self._pending = entityId
	end
	self._env.spawn(function()
		local called, view = pcall(function()
			return hud.remotes:invoke("Sim.Inspect", entityId)
		end)
		if token ~= self._token or (refresh and refreshToken ~= self._refreshToken) then
			return -- a newer selection (or refresh) owns the card
		end
		if not refresh then
			self._pending = nil
		end
		local model = if called then CitizenModel.card(view) else nil
		if model == nil then
			if refresh then
				if called and self.entityId == entityId then
					self:close()
				end
			else
				hud:notify({
					kind = "info",
					title = if called then CitizenText.CANT_INSPECT else CitizenText.unreachable(),
					body = if called then "Only citizens of your kingdom answer to you." else nil,
				})
			end
			return
		end
		if refresh and (self.entityId ~= entityId or not self:isOpen()) then
			return
		end
		if self.entityId ~= entityId then
			self.talkState = "idle"
		end
		self.entityId = entityId
		self.view = view
		self.model = model
		if hud.state.menu ~= CitizenCardController.MENU then
			hud:setMenu(CitizenCardController.MENU)
		else
			hud:render()
		end
	end)
end

function CitizenCardController:onTalk(fn: (number) -> ()): () -> ()
	self._talk = fn
	return function()
		if self._talk == fn then
			self._talk = nil
		end
	end
end

function CitizenCardController:setTalkState(state: string)
	self.talkState = state
	if self:isOpen() then
		self.hud:render()
	end
end

function CitizenCardController:_kingdomColor(): Color3?
	local kingdom = self.hud.store:mine()
	return if kingdom then HudModel.color(kingdom) else nil
end

function CitizenCardController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.card = self.card or CitizenCard.new(hud.roots.menus)
	if not self:isOpen() then
		self.card:destroy()
		return
	end
	local entityId = self.entityId
	self.card:render(self.model, metrics, {
		color = self:_kingdomColor(),
		talk = { visible = self._talk ~= nil, state = self.talkState },
		onTalk = function()
			local talk = self._talk
			if talk and entityId and self.talkState ~= "loading" then
				talk(entityId)
			end
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
