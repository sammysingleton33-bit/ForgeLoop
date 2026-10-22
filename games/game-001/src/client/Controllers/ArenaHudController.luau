--!strict
--[[
	ArenaHudController (FORGE-03, game-001 client, FL-0073) — the Crown Arena's state on the client, and the duel HUD
	(design crown-arena.md §4-§5; CONTRACTS G12.4, G12.6).

	The feed (LoadoutController and ArenaIntroController read it):
		ArenaState                     from FORGE-01's DuelController, the client's one arena door (G12.6): seeded
		                               from getState() and followed through stateChanged (DuelController alone
		                               listens to Arena.State and asks Arena.GetState, once)
		duel events                    DuelController.events, one at a time
		Kingdom.Support / GetSupport   the local ruler's SupportView (asked again when the loadout stage starts)
	Until FORGE-01's ArenaService and SupportService land (FL-0070 / FL-0071) nothing is declared and nothing shows;
	the specs and scenes use tests/economy/doubles/ArenaDoubles.

	The HUD (UI/ArenaHud over UI/ArenaHudModel) shows in the "duel" stage, for the champions and for everyone
	watching. During the intro and the duel (and the loadout, for a champion) the kingdom HUD steps aside
	(KingdomHudController:setArenaFocus), so the crest and pills never sit under the duel strip.

	Depends on KingdomHudController (remotes, store, modal layer, layout) and DuelController (the arena feed).
	API (specs, scenes, LoadoutController, ArenaIntroController)
		arena.state (ArenaState?)   arena.support (SupportView?)   arena.track   arena.view
		arena.changed: Signal<(ArenaState?)>   arena.supportChanged: Signal<(SupportView?)>
		arena:setState(state)   arena:setSupport(view)   arena:onEvents(batch)   arena:fetchSupport()
		arena:lookup() -> { kingdom(id), name(userId) }   arena:userId()   arena:focus() -> boolean
		arena:inputKind() -> "keyboard" | "gamepad" | "touch"
		arena:crownToast(state) -> { kind, title, body }?   the toast the crowning shows (who takes the crown)
		ArenaHudController.POLL_SEC   .FOCUS   .HINT_SEC   .HINT_AGAIN_SEC   .INPUT
]]

local ArenaHud = require("../UI/ArenaHud")
local ArenaHudModel = require("../UI/ArenaHudModel")
local LoadoutModel = require("../UI/LoadoutModel")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Signature = require("../UI/Signature")

local ArenaHudController = {}
ArenaHudController.__index = ArenaHudController

local Def = { name = "ArenaHudController", dependencies = { "KingdomHudController", "DuelController" } }

ArenaHudController.POLL_SEC = 0.25 -- the clocks and a fired perk's glow
ArenaHudController.FOCUS = table.freeze({ intro = true, duel = true }) -- the kingdom HUD steps aside for everyone
ArenaHudController.DUEL = "DuelController"
ArenaHudController.INPUT = "InputModeArenaController" -- FORGE-04: controls() for the hint line
ArenaHudController.HINT_SEC = 10 -- the duel's quiet start
ArenaHudController.HINT_AGAIN_SEC = 5 -- after the input type changes

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = nil :: any,
		support = nil :: any,
		track = ArenaHudModel.new(),
		view = nil :: any,
		changed = Signal.new(),
		supportChanged = Signal.new(),
		_connections = {} :: { any },
		_focus = false,
	}, ArenaHudController)
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

function ArenaHudController:_listen(name: string, fn: (...any) -> ())
	local hud = self.hud
	if not hud:hasRemote(name) then
		return false
	end
	local ok, err = pcall(function()
		table.insert(self._connections, hud.remotes:on(name, fn))
	end)
	if not ok then
		self._env.log("warn", "ArenaHudController: cannot listen to " .. name, { error = tostring(err) })
	end
	return ok
end

function ArenaHudController:start()
	local env = self._env
	table.insert(
		self._connections,
		self.hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	self:_listen("Kingdom.Support", function(view)
		self:setSupport(view)
	end)
	-- the arena feed: FORGE-01's DuelController (G12.6), the client's one door to Arena.State / GetState / Events
	local duel = self._registry:get(ArenaHudController.DUEL)
	local ok, err = pcall(function()
		table.insert(
			self._connections,
			duel.stateChanged:connect(function(state)
				self:setState(state)
			end)
		)
		table.insert(
			self._connections,
			duel.events:connect(function(event)
				self:onEvents({ event })
			end)
		)
	end)
	if not ok then
		env.log("warn", "ArenaHudController: cannot follow DuelController", { error = tostring(err) })
	end
	local seeded = duel:getState()
	if type(seeded) == "table" then
		self:setState(seeded)
	end
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(ArenaHudController.POLL_SEC)
			if self._running and self.state ~= nil and self.state.stage == "duel" then
				self:render()
			end
		end
	end)
end

function ArenaHudController:destroy()
	self._destroyed = true
	self._running = false
	for _, connection in self._connections do
		disconnect(connection)
	end
	self._connections = {}
	if self.view then
		self.view:destroy()
	end
	if self._focus and type(self.hud.setArenaFocus) == "function" then
		self.hud:setArenaFocus(false)
	end
end

function ArenaHudController:userId(): number?
	local ok, id = pcall(function()
		return self._env.Players.LocalPlayer.UserId
	end)
	return if ok then id else nil
end

function ArenaHudController:lookup(): any
	local hud = self.hud
	return {
		kingdom = function(id)
			return hud.store:kingdom(id)
		end,
		name = function(userId)
			return hud:_nameOf(userId)
		end,
	}
end

function ArenaHudController:fetchSupport()
	if not self.hud:hasRemote("Kingdom.GetSupport") then
		return
	end
	self._env.spawn(function()
		local ok, view = pcall(function()
			return self.hud.remotes:invoke("Kingdom.GetSupport")
		end)
		if ok and not self._destroyed then
			self:setSupport(if type(view) == "table" then view else nil)
		end
	end)
end

function ArenaHudController:setState(state: any)
	if self._destroyed then
		return
	end
	local before = if self.state then self.state.stage else nil
	self.state = if type(state) == "table" then state else nil
	local stage = if self.state then self.state.stage else nil
	if stage == "loadout" and before ~= "loadout" then
		self:fetchSupport() -- the offers and slots as they stand when the pick starts
	end
	if type(self.hud.setArenaState) == "function" then
		self.hud:setArenaState(self.state) -- the phase pill names the arena's stage
	end
	if stage == "crowning" and before ~= "crowning" then
		self:_announceCrown()
	end
	self.changed:fire(self.state)
	self:render()
end

-- The crowning (D-059 arena pass): its 15 s showed no word of who won until Results. One toast names the
-- kingdom that takes the crown, the winner's own kingdom in the achievement accent. A draw names nobody (FORGE-04's
-- match-end line says it).
function ArenaHudController:crownToast(state: any): any?
	if type(state) ~= "table" then
		return nil
	end
	local kingdomId = state.coronation
	local byDuel = false
	if kingdomId == nil and type(state.winner) == "number" then
		for _, key in { "a", "b" } do
			local d = state[key]
			if type(d) == "table" and d.userId == state.winner then
				kingdomId, byDuel = d.kingdom, true
			end
		end
	end
	if kingdomId == nil then
		return nil
	end
	local kingdom = self.hud.store:kingdom(kingdomId)
	local name = if kingdom and kingdom.name then kingdom.name else tostring(kingdomId)
	local mine = self.hud.store:mine()
	local ours = mine ~= nil and mine.id == kingdomId
	return {
		kind = if ours then "achievement" else "info",
		title = `{name} takes the crown`,
		body = if not byDuel
			then "Crowned without a duel"
			elseif ours then "Your champion won the duel"
			else "Their champion won the duel",
	}
end

function ArenaHudController:_announceCrown()
	local toast = self:crownToast(self.state)
	if toast and type(self.hud.notify) == "function" then
		self.hud:notify(toast)
	end
end

function ArenaHudController:setSupport(view: any)
	if self._destroyed then
		return
	end
	self.support = if type(view) == "table" then view else nil
	self.supportChanged:fire(self.support)
end

function ArenaHudController:onEvents(batch: any)
	if self._destroyed or type(batch) ~= "table" then
		return
	end
	local now = self._env.serverTimeNow()
	for _, event in batch do
		ArenaHudModel.apply(self.track, event, now)
	end
	self:render()
end

-- The kingdom HUD steps aside during the intro and the duel, and for a champion during the loadout.
function ArenaHudController:focus(): boolean
	local stage = if self.state then self.state.stage else nil
	if stage == nil then
		return false
	end
	if ArenaHudController.FOCUS[stage] then
		return true
	end
	return stage == "loadout" and LoadoutModel.side(self.state, self:userId()) ~= nil
end

-- The input in use: "gamepad", "touch" or "keyboard" (UserInputService's last input type; keyboard when unknown).
function ArenaHudController:inputKind(): string
	local ok, kind = pcall(function()
		local name = tostring(self._env.UserInputService:GetLastInputType())
		if string.find(name, "Gamepad") then
			return "gamepad"
		elseif string.find(name, "Touch") then
			return "touch"
		end
		return "keyboard"
	end)
	return if ok then kind else "keyboard"
end

-- The control hints (FORGE-04, 2026-10-19): the duel's first HINT_SEC, and HINT_AGAIN_SEC after the input type
-- changes; keyboard and gamepad only.
function ArenaHudController:_hints(now: number): string?
	local st = self.state
	local duel = `{st.a and st.a.userId}|{st.b and st.b.userId}`
	local kind = self:inputKind()
	if duel ~= self._hintDuel then
		self._hintDuel = duel
		self._hintUntil = now + ArenaHudController.HINT_SEC
	elseif self._inputKind ~= nil and kind ~= self._inputKind then
		self._hintUntil = math.max(self._hintUntil or 0, now + ArenaHudController.HINT_AGAIN_SEC)
	end
	self._inputKind = kind
	if now >= (self._hintUntil or 0) then
		return nil
	end
	-- a touch phone shows FORGE-04's labelled duel buttons whatever the last input (a phone with a pad), and its
	-- captions sit just under the strip there (y 135 on 667 × 375): no hint line on it. A touchscreen laptop or
	-- tablet keeps the line (its captions start at y 0.86; FORGE-07 L4 on #214).
	local touch = false
	pcall(function()
		touch = self._env.UserInputService.TouchEnabled == true
	end)
	if touch and self.hud:metrics().breakpoint == "phone" then
		return nil
	end
	local input = self._registry:find(ArenaHudController.INPUT)
	local ok, controls = pcall(function()
		return input:controls()
	end)
	return ArenaHudModel.hints(if ok then controls else nil, kind)
end

function ArenaHudController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	local focus = self:focus()
	if focus ~= self._focus and type(hud.setArenaFocus) == "function" then
		self._focus = focus
		hud:setArenaFocus(focus) -- re-renders the HUD, which calls back here through rendered
		return
	end
	self.view = self.view or ArenaHud.new(hud.roots.modals)
	local now = self._env.serverTimeNow()
	local model = ArenaHudModel.view(self.track, self.state, self:lookup(), self:userId(), now)
	if model == nil then
		self.view:destroy()
		self._key = nil
		return
	end
	if model.mine then
		model.hints = self:_hints(now)
	end
	-- rebuild only when the structure changes; the bars and the clock move in place (5 Hz snapshots, 4 Hz poll)
	local m = metrics or hud:metrics()
	local key = Signature.of({
		s = ArenaHudModel.structure(model),
		breakpoint = m.breakpoint,
		width = m.width,
		height = m.height,
	})
	if key == self._key and self.view.instance ~= nil then
		self.view:update(model)
		return
	end
	self._key = key
	self.view:render(model, m)
end

return Def
