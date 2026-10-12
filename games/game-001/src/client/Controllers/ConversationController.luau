--!strict
--[[
	ConversationController (FORGE-03, game-001 client, FL-0088) — structured conversations with
	citizens (CONTRACTS G13.3, design/living-kingdom.md §2), end to end:
		1. Talk / Ask on the citizen card (CitizenCardController:onTalk) → `Kingdom.Converse(entityId)`
		   in a spawned thread. nil (nothing to say) → a notice "Nothing on their mind right now"; the
		   card stays. A payload → the panel opens (`hud:setMenu("conversation")`) with the speaker,
		   the question and the 2-4 answers, exactly as the server sent them.
		2. Picking an answer disables every answer at once (answer once: a double tap or a second
		   answer sends nothing) and calls `Kingdom.Choose(entityId, scenarioId, responseId)`.
		3. `(true, { reaction, effects })` → the reaction and the effect chips (text from the server,
		   icon and colour by `kind`), then Done. `(false, nil, reason)` → the reason as a sentence
		   (UI/CitizenText), then Close. nil (the call failed or was dropped) → the answers open again
		   with "Couldn't reach the server" (Choose is idempotent per showing on the server).
		4. Done / Close / the X close the panel. Selecting anything ("none", a building, a slot or
		   another citizen) closes it too; opening another menu replaces it.
	The client decides nothing: no question, answer, reaction or effect text lives in this code.

	Depends on KingdomHudController (remotes, drawer, layout, notices). Optional (registry:find in
	start): CitizenCardController (the Talk button and its busy state), InputModeController (.selected).

	API (specs and scenes)
		conversation:open(entityId)    ask Kingdom.Converse and show the panel
		conversation:choose(responseId)  conversation:done()  conversation:close()
		conversation.state = { entityId, phase ("asking" | "choosing" | "answered" | "refused"),
			conversation (UI/CitizenModel Conversation), picked?, outcome?, error? }?
		conversation.panel (UI/ConversationPanel)    ConversationController.MENU = "conversation"
]]

local CitizenModel = require("../UI/CitizenModel")
local CitizenText = require("../UI/CitizenText")
local ConversationPanel = require("../UI/ConversationPanel")
local HudModel = require("../UI/HudModel")

local ConversationController = {}
ConversationController.__index = ConversationController

local Def = { name = "ConversationController", dependencies = { "KingdomHudController" } }

ConversationController.MENU = "conversation"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = nil :: any,
		panel = nil :: any,
		_loading = nil :: number?,
		_token = 0,
		_connections = {},
	}, ConversationController)
end

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

function ConversationController:start()
	local hud = self.hud
	self._card = self._registry:find("CitizenCardController")
	if self._card and self._card.onTalk then
		self._removeTalk = self._card:onTalk(function(entityId)
			self:open(entityId)
		end)
	end
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	table.insert(
		self._connections,
		hud.menuChanged:connect(function(menu)
			if menu ~= ConversationController.MENU then
				-- Another panel took the drawer (or it closed): this conversation is over on screen.
				-- A Choose still in flight is applied by the server; its reply is ignored here.
				self.state = nil
			end
		end)
	)
	local inputMode = self._registry:find("InputModeController")
	local connection = connect(if inputMode then inputMode.selected else nil, function()
		self:_onSelected()
	end)
	if connection then
		table.insert(self._connections, connection)
	end
end

function ConversationController:destroy()
	for _, connection in self._connections do
		disconnect(connection)
	end
	self._connections = {}
	if self._removeTalk then
		self._removeTalk()
	end
	if self.panel then
		self.panel:destroy()
	end
end

function ConversationController:_onSelected()
	self._token += 1 -- a Converse still loading no longer opens anything
	self:_setLoading(nil)
	self:close()
end

function ConversationController:_setLoading(entityId: number?)
	self._loading = entityId
	local card = self._card
	if card and card.setTalkState then
		card:setTalkState(if entityId then "loading" else "idle")
	end
end

function ConversationController:_speakerFallback(entityId: number): any
	local card = self._card
	if card and card.entityId == entityId and card.model then
		return { name = card.model.name, occupation = card.view and card.view.occupation or nil }
	end
	return nil
end

function ConversationController:open(entityId: number)
	if self._loading ~= nil then
		return -- one Converse at a time (a double tap on Talk asks once)
	end
	local hud = self.hud
	self._token += 1
	local token = self._token
	self:_setLoading(entityId)
	self._env.spawn(function()
		local called, payload = pcall(function()
			return hud.remotes:invoke("Kingdom.Converse", entityId)
		end)
		if token ~= self._token then
			return
		end
		self:_setLoading(nil)
		local fallback = self:_speakerFallback(entityId)
		local conversation = if called then CitizenModel.conversation(payload, fallback) else nil
		if conversation == nil then
			hud:notify({
				kind = "info",
				title = if called then CitizenText.NOTHING else CitizenText.unreachable(),
				body = if called and fallback then fallback.name else nil,
			})
			return
		end
		self.state = {
			entityId = entityId,
			phase = "asking",
			conversation = conversation,
			picked = nil :: string?,
			outcome = nil :: any,
			error = nil :: string?,
		}
		if hud.state.menu ~= ConversationController.MENU then
			hud:setMenu(ConversationController.MENU)
		else
			hud:render()
		end
	end)
end

function ConversationController:choose(responseId: string)
	local s = self.state
	if s == nil or s.phase ~= "asking" then
		return -- answer once: everything after the first pick is ignored
	end
	local known = false
	for _, o in s.conversation.options do
		if o.id == responseId then
			known = true
		end
	end
	if not known then
		return
	end
	s.phase = "choosing"
	s.picked = responseId
	s.error = nil
	local hud = self.hud
	hud:render()
	self._env.spawn(function()
		local called, ok, result, reason = pcall(function()
			return hud.remotes:invoke("Kingdom.Choose", s.entityId, s.conversation.scenarioId, responseId)
		end)
		if self.state ~= s then
			return -- closed while waiting
		end
		local outcome = CitizenModel.outcome(called, ok, result, reason)
		if outcome.phase == "failed" then
			s.phase = "asking"
			s.picked = nil
			s.error = outcome.message
		else
			s.phase = outcome.phase
			s.outcome = outcome
		end
		hud:render()
	end)
end

function ConversationController:done()
	self:close()
end

function ConversationController:close()
	self.state = nil
	if self.hud.state.menu == ConversationController.MENU then
		self.hud:setMenu(nil)
	end
end

function ConversationController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.panel = self.panel or ConversationPanel.new(hud.roots.menus)
	if hud.state.menu ~= ConversationController.MENU or self.state == nil then
		self.panel:destroy()
		return
	end
	local kingdom = hud.store:mine()
	self.panel:render(self.state, metrics, {
		color = if kingdom then HudModel.color(kingdom) else nil,
		onPick = function(responseId)
			self:choose(responseId)
		end,
		onDone = function()
			self:done()
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
