--!strict
--[[
	ConversationController (FORGE-03, game-001 client, FL-0088) — structured conversations with
	citizens (CONTRACTS G13.3, design/living-kingdom.md §2), end to end:
		1. Talk / Ask on the citizen card (CitizenCardController:onTalk) → `Kingdom.Converse(entityId)`
		   in a spawned thread. No such remote on the server yet → "Conversations aren't available
		   yet" at once (no 10 s wait for a remote that will never replicate). nil (nothing to say) →
		   a notice "Nothing on their mind right now"; the card stays. A payload → the panel opens
		   (`hud:setMenu("conversation")`) with the speaker, the question and the 2-4 answers, exactly
		   as the server sent them, each with its cost and every risk (G13.3 `cost`, `risks`) shown
		   before the player chooses. An answer the treasury can't pay is disabled ("Need 20 Wood").
		2. An answer with a cost or a risk first opens the confirm step ("confirming": that answer
		   alone with its cost and every risk, Back / Choose; FORGE-05 B1 on #66); Choose (or an
		   answer with neither) disables every answer at once (answer once: a double tap or a second
		   answer sends nothing) and calls `Kingdom.Choose(entityId, scenarioId, responseId)`.
		   Choose ignores taps for CONFIRM_DELAY after the step opens, so the double tap that
		   opened it can't also confirm it. The
		   guard is per showing (`entityId:scenarioId`) and lives in the controller, not in the open
		   panel: closing and reopening the same question while Choose is in flight shows the pick as
		   waiting and sends nothing more.
		3. `(true, { reaction, effects })` → the reaction and the effect chips (text from the server,
		   icon and colour by `kind`), then Done. `(false, nil, reason)` → the reason as a sentence
		   (UI/CitizenText), then Close. nil (the call failed or was dropped) → the answers open again
		   with "Couldn't reach the server" (Choose is idempotent per showing on the server). A reply
		   for a showing that is no longer on screen is never dropped silently: it lands on the
		   reopened panel of the same showing, or else becomes a notice (speaker + reaction/reason).
		4. Done / Close / the X close the panel. Selecting anything ("none", a building, a slot or
		   another citizen) closes it too; opening another menu replaces it. Any menu change away
		   from the conversation also cancels a Converse still loading (its reply is ignored).
		5. While the player is still deciding ("asking" / "confirming"), the citizen is re-checked
		   every CHECK_SEC with `Sim.Inspect`; nil (gone, or no longer yours) closes the panel with a
		   notice. Never once the choice is sent or answered (FORGE-05 L1 on #66).
	The client decides nothing: no question, answer, reaction or effect text lives in this code.

	Depends on KingdomHudController (remotes, drawer, layout, notices). Optional (registry:find in
	start): CitizenCardController (the Talk button and its busy state), InputModeController (.selected),
	OnboardingController (`report("CitizenAnswered")` after an accepted Kingdom.Choose, FORGE-04 #45).

	API (specs and scenes)
		conversation:open(entityId)    ask Kingdom.Converse and show the panel
		conversation:choose(responseId)  conversation:confirm()  conversation:back()
		conversation:done()  conversation:close()
		conversation.state = { entityId, phase ("asking" | "confirming" | "choosing" | "answered" | "refused"),
			conversation (UI/CitizenModel Conversation), picked?, outcome?, error? }?
		conversation.inflight = { [CitizenModel.key(entityId, scenarioId)]: responseId }
		conversation.panel (UI/ConversationPanel)    ConversationController.MENU = "conversation"
		ConversationController.CHECK_SEC
]]

local CitizenModel = require("../UI/CitizenModel")
local CitizenText = require("../UI/CitizenText")
local ConversationPanel = require("../UI/ConversationPanel")
local HudModel = require("../UI/HudModel")
local Signature = require("../UI/Signature")

local ConversationController = {}
ConversationController.__index = ConversationController

local Def = { name = "ConversationController", dependencies = { "KingdomHudController" } }

ConversationController.MENU = "conversation"
ConversationController.CHECK_SEC = 4 -- the citizen card's refresh period (CitizenCardController)
ConversationController.CONFIRM_DELAY = 0.35 -- seconds Choose ignores taps after the confirm step opens
ConversationController.CONVERSE = "Kingdom.Converse"
ConversationController.CHOOSE = "Kingdom.Choose"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = nil :: any,
		panel = nil :: any,
		inflight = {} :: { [string]: string },
		_loading = nil :: number?,
		_token = 0,
		_connections = {},
		_running = false,
		_checking = false,
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
				-- Another panel took the drawer (or it closed): this conversation is over on screen,
				-- and a Converse still loading must not take the drawer back (FORGE-05 M2). A Choose
				-- in flight stays in `inflight`; its reply becomes a notice (or lands on a reopen).
				self._token += 1
				if self._loading ~= nil then
					self:_setLoading(nil)
				end
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
	-- The phone sheet covers the reputation strip and the toast corner: the HUD moves toasts above it.
	if hud.setSheet then
		hud:setSheet(ConversationController.MENU, true)
	end
	local env = self._env
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(ConversationController.CHECK_SEC)
			if self._running then
				self:_checkPresence()
			end
		end
	end)
end

function ConversationController:destroy()
	self._running = false
	self._destroyed = true
	self._token += 1 -- a Converse still loading never opens a menu after destroy (FORGE-05 L2)
	for _, connection in self._connections do
		disconnect(connection)
	end
	self._connections = {}
	if self._removeTalk then
		self._removeTalk()
		self._removeTalk = nil
	end
	if self.panel then
		self.panel:destroy()
	end
	-- Leave no menu pointing at a panel that no longer exists (FORGE-05 L6).
	self.state = nil
	local hud = self.hud
	if hud.state.menu == ConversationController.MENU then
		pcall(function()
			hud:setMenu(nil)
		end)
	end
end

-- The server has the remote (non-yielding). An older HUD without hasRemote: assume it does.
function ConversationController:_hasRemote(name: string): boolean
	local hud = self.hud
	return hud.hasRemote == nil or hud:hasRemote(name)
end

-- Before the choice is sent: the only phases a vanished citizen may close (FORGE-05 L1 on #66).
local function deciding(s: any): boolean
	return s.phase == "asking" or s.phase == "confirming"
end

-- Every CHECK_SEC while a conversation is open: is the citizen still there (and still ours)?
function ConversationController:_checkPresence()
	local s = self.state
	if s == nil or not deciding(s) or self._checking or not self:_hasRemote("Sim.Inspect") then
		return
	end
	local hud = self.hud
	self._checking = true
	self._env.spawn(function()
		local called, view = pcall(function()
			return hud.remotes:invoke("Sim.Inspect", s.entityId)
		end)
		self._checking = false
		if not called or view ~= nil or self.state ~= s or not deciding(s) then
			return -- unknown (no reply), still here, or the panel moved on
		end
		self:close()
		hud:notify({ kind = "info", title = CitizenText.GONE, body = s.conversation.speaker.name })
	end)
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
	if not self:_hasRemote(ConversationController.CONVERSE) then
		-- The server has no conversations yet (FORGE-05 L5): say so now instead of after 10 s.
		hud:notify({ kind = "info", title = CitizenText.UNAVAILABLE })
		return
	end
	self._token += 1
	local token = self._token
	self:_setLoading(entityId)
	self._env.spawn(function()
		local called, payload = pcall(function()
			return hud.remotes:invoke(ConversationController.CONVERSE, entityId)
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
		-- The same showing reopened while its Choose is still in flight: show the pick as waiting.
		local pending = self.inflight[CitizenModel.key(entityId, conversation.scenarioId)]
		self.state = {
			entityId = entityId,
			phase = if pending then "choosing" else "asking",
			conversation = conversation,
			picked = pending :: string?,
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

function ConversationController:_balances(): { [string]: number }?
	local store = self.hud.store
	return if store:hasTreasury() then store:balances() else nil
end

-- A Choose reply for a showing that is no longer on screen: the server has decided, say so.
function ConversationController:_notifyOutcome(speaker: any, outcome: any)
	local hud = self.hud
	if outcome.phase == "answered" then
		local first = outcome.effects[1]
		hud:notify({
			kind = "success",
			title = speaker.name,
			body = outcome.reaction or (if first then first.text else nil),
		})
	elseif outcome.phase == "refused" then
		hud:notify({ kind = "warning", title = speaker.name, body = outcome.message })
	else
		hud:notify({ kind = "error", title = outcome.message, body = speaker.name })
	end
end

-- FORGE-04's onboarding v2 step AnswerCitizen (#45): a Kingdom.Choose the server accepted, whether
-- or not its panel is still open. Until G9 has a CitizenAnswered event (FORGE-04 handoff
-- 2026-10-12-forge-04-to-forge-03-01-05-onboarding-v2-match30).
function ConversationController:_reportAnswered()
	local onboarding = self._registry:find("OnboardingController")
	if onboarding and onboarding.report then
		pcall(function()
			onboarding:report("CitizenAnswered")
		end)
	end
end

function ConversationController:choose(responseId: string, confirmed: boolean?)
	local s = self.state
	if s == nil then
		return
	end
	if confirmed then
		if s.phase ~= "confirming" or s.picked ~= responseId then
			return
		end
	elseif s.phase ~= "asking" then
		return -- answer once: everything after the first pick is ignored
	end
	local option = nil
	for _, o in s.conversation.options do
		if o.id == responseId then
			option = o
		end
	end
	if option == nil then
		return
	end
	-- No separate in-flight check here: `inflight` is the one guard, applied when a showing is put on
	-- screen (open() shows an in-flight showing as "choosing", and choose() only answers "asking").
	local key = CitizenModel.key(s.entityId, s.conversation.scenarioId)
	if CitizenModel.price(option, self:_balances()).need then
		return -- the treasury can't pay: the answer is disabled and says why (the server checks again)
	end
	local hud = self.hud
	if not self:_hasRemote(ConversationController.CHOOSE) then
		s.error = CitizenText.UNAVAILABLE
		hud:render()
		return
	end
	if not confirmed and CitizenModel.needsConfirm(option) then
		-- A cost or a risk: show it all, unscrolled, before anything is sent (FORGE-05 B1 on #66).
		s.phase = "confirming"
		s.picked = responseId
		s.error = nil
		self._confirmAt = self._env.clock()
		hud:render()
		return
	end
	self.inflight[key] = responseId
	s.phase = "choosing"
	s.picked = responseId
	s.error = nil
	hud:render()
	local entityId, scenarioId, speaker = s.entityId, s.conversation.scenarioId, s.conversation.speaker
	self._env.spawn(function()
		local called, ok, result, reason = pcall(function()
			return hud.remotes:invoke(ConversationController.CHOOSE, entityId, scenarioId, responseId)
		end)
		self.inflight[key] = nil
		if self._destroyed then
			return
		end
		local outcome = CitizenModel.outcome(called, ok, result, reason)
		if outcome.phase == "answered" then
			self:_reportAnswered()
		end
		-- The panel on screen now may be a reopen of the same showing (a new state table).
		local current = self.state
		if
			current == nil
			or current.entityId ~= entityId
			or current.conversation.scenarioId ~= scenarioId
			or current.phase ~= "choosing"
		then
			self:_notifyOutcome(speaker, outcome)
			return
		end
		if outcome.phase == "failed" then
			current.phase = "asking"
			current.picked = nil
			current.error = outcome.message
		else
			current.phase = outcome.phase
			current.picked = responseId
			current.outcome = outcome
		end
		hud:render()
	end)
end

-- The confirm step's Choose: sends the answer it shows (ignored right after the step opened).
function ConversationController:confirm()
	local s = self.state
	if s == nil or s.phase ~= "confirming" or s.picked == nil then
		return
	end
	if self._env.clock() - (self._confirmAt or 0) < ConversationController.CONFIRM_DELAY then
		return -- the double tap that opened the step must not also confirm it
	end
	self:choose(s.picked, true)
end

-- The confirm step's Back: the answers again, nothing sent.
function ConversationController:back()
	local s = self.state
	if s == nil or s.phase ~= "confirming" then
		return
	end
	s.phase = "asking"
	s.picked = nil
	self.hud:render()
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
		self._renderKey = nil
		return
	end
	local kingdom = hud.store:mine()
	local color = if kingdom then HudModel.color(kingdom) else nil
	-- Rebuild only when the conversation or the screen changed: a treasury push mid-question must
	-- not swap the answer buttons under the player's finger (FORGE-05 M1).
	local key = Signature.of({
		state = self.state,
		color = color,
		breakpoint = metrics.breakpoint,
		drawer = metrics.drawer,
		width = metrics.width,
		height = metrics.height,
	})
	local balances = self:_balances()
	if key == self._renderKey and self.panel.panel ~= nil then
		self.panel:patch(balances) -- what each answer costs against the new treasury, in place
		return
	end
	self._renderKey = key
	self.panel:render(self.state, metrics, {
		color = color,
		balances = balances,
		onPick = function(responseId)
			self:choose(responseId)
		end,
		onDone = function()
			self:done()
		end,
		onClose = function()
			self:close()
		end,
		onConfirm = function()
			self:confirm()
		end,
		onBack = function()
			self:back()
		end,
	})
end

return Def
