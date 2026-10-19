--!strict
--[[
	FeedbackCrowdController (game-001, FORGE-04, FL-0074 part 2a; CONTRACTS G12.4 / G12.6 DRAFT; design
	crown-arena.md §7): the Crown Arena crowd you hear and read. It feeds Feedback/CrowdDirector from
	DuelController's arena state and the Arena.Events remote, and presents what it returns: the crowd's
	sound (ducked under the announcer and perk stingers) and a subtitle for every reaction
	(accessibility, §7: no crowd sound without text). The stands' figures (CrowdFiguresController, on
	FORGE-02's Kit.arena seats with Kit.crowdFigure, FL-0072) listen to `reacted`.

	When
		- A director is made when the arena state first names both duellists (a and b) at the intro or
		  duel stage; a different pair starts a new one. The state comes from FORGE-01's DuelController
		  (a dependency; stateChanged and getState: it asks Arena.GetState once, so a client that
		  joins or reloads mid-duel still gets its crowd). This controller never asks itself. Tiers,
		  kingdoms and ruler names come from the state (an AI duellist has no name to chant, so its
		  stand uses a line without one).
		- Arena.Events (batched) feed it during the duel; events with no director are dropped.
		- Crowning ends it: finish(the winner's side), or finish(nil) when `winner` names nobody. The
		  director plays its ending once, so an `ended` event and the crowning never both play one.
		- done, Results and Lobby drop the director and clear the subtitles.
		- Every announcer moment (AnnouncerController.moment) ducks the crowd for Crowd.duck.announcerSec.
	Presenting a reaction
		- Sound: AudioController:play(sound, { volume = director:volume(now) }), a factor on the sound's
		  own volume. Every crowd sound is "needed" (silent until the owner picks them).
		- Subtitle: one box per stand in a ScreenGui `ForgeCrowdCaptions` under PlayerGui, made on the
		  first subtitle: "<Kingdom>: <caption>" with the kingdom's short name ("Emerald", not "Emerald
		  Kingdom"), shown CAPTION_SEC; a priority line (a perk, the ending) shows PRIORITY_SEC and is not
		  replaced by a lesser line meanwhile. RichText is off, so a display name inside a chant is shown
		  as typed. Each box holds two wrapped lines (Def.LINE.height), and every caption, with the
		  longest kingdom name and a 20-character ruler name, stays within Def.LINE.maxChars, about two
		  lines in the narrowest layout (387 px on a 667x375 phone at ~9.5 px a character; an estimate
		  until E17: FORGE-07's #199 M1, the 28 px one-line box cut the longest lines off).
		- Where: bottom-centre, stacked upwards from y 0.86 (0.7 wide; FORGE-03 keeps y 0.72–0.86 clear
		  of the arena HUD, which sits at the top). While the champion's duel touch buttons show
		  (InputModeArenaController:touchArea), the boxes move left of the buttons (all buttons are right
		  of that edge) and sit just above Roblox's thumbstick (Def.LINE.thumbClear), well below the top
		  HUD (FORGE-03 on #199: on a 667x375 phone the centred lines covered the buttons).
		- reacted: Signal<(reaction, kingdomId?)>, for the stand figures (CrowdFiguresController) and
		  FORGE-03's HUD.
	Studio preview (E17): in Studio only, the local player's attribute ForgeCrowdPreview = "tierA,tierB"
	(for example "adoring,hostile") plays Def.PREVIEW, a short scripted duel, through the same path,
	one step every PREVIEW_STEP_SEC; any other value stops it. Outside Studio it does nothing.

	API
		controller.director                      -- the duel's CrowdDirector, nil outside a duel
		controller.reacted: Signal<(reaction, kingdomId?)>
		controller:onArenaState(state) / :onEvents(batch) / :onPhase(phase) / :onAnnouncer()
		controller:captions() -> { string }      -- the lines shown now
		controller:step(now?)                    -- expires subtitles and advances the preview
		controller:preview(spec) -> boolean      -- Studio only
	Engine access is guarded: without PlayerGui, AudioController or the remotes it does nothing.
]]

local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local CrowdDirector = require("@game/ReplicatedStorage/Game/Feedback/CrowdDirector")
local Kingdoms = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Controller = {}
Controller.__index = Controller

local Def = { name = "FeedbackCrowdController", dependencies = { "DuelController" } }

Def.CAPTION_SEC = 2.5
Def.PRIORITY_SEC = 4
Def.STEP_SEC = 0.25
Def.GUI_NAME = "ForgeCrowdCaptions"
-- px: a box holds two lines at textSize; thumbClear = how far above the bottom the duel layout starts
-- (Roblox's thumbstick reaches about 140 px up on a phone; tablets have more room). DRAFT until E17.
Def.LINE = table.freeze({
	height = 44,
	step = 48,
	edge = 16,
	clear = 8,
	textSize = 18,
	maxChars = 80,
	thumbClear = table.freeze({ small = 148, large = 220 }),
})
Def.SMALL_TOUCH_LEFT = 300 -- touchArea().left below this is the phone layout
Def.DUEL_STAGES = table.freeze({ intro = true, duel = true })
Def.END_PHASES = table.freeze({ Results = true, Lobby = true })
Def.PREVIEW_ATTRIBUTE = "ForgeCrowdPreview"
Def.PREVIEW_STEP_SEC = 3.5
-- a short duel for the Studio preview: every kind of moment once, then the ending. The data is
-- DuelService's Arena.Events relay (shares only; see Feedback/CrowdDirector).
Def.PREVIEW = table.freeze({
	{ kind = "heavyWindup", side = "a" },
	{ kind = "hit", side = "a", data = { heavy = true, damageShare = 0.2, hpShare = 0.8 } },
	{ kind = "parry", side = "b" },
	{
		kind = "triggerFired",
		side = "a",
		data = { source = "perk:reforge", trigger = "reforge", citizenName = "Mara" },
	},
	{ kind = "hit", side = "b", data = { damageShare = 0.3, hpShare = 0.15 } },
	{ kind = "hype", side = "a" },
	{ kind = "hit", side = "a", data = { damageShare = 0.7, hpShare = 0.1 } },
	{ kind = "ended", side = "a", data = { reason = "ko" } },
})

local NAMES: { [string]: string } = {}
for _, identity in Kingdoms.identities do
	NAMES[identity.id] = (string.gsub(identity.name, "%s+Kingdom$", "")) -- "Emerald Kingdom" -> "Emerald"
end

-- The short name a subtitle starts with ("Emerald"), or the id for a kingdom the config lacks.
function Def.kingdomName(kingdom: string): string
	return NAMES[kingdom] or kingdom
end

-- opts (specs): { playerGui, userNames: { [userId]: string }, studio: boolean?, player }
function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_opts = options,
		_links = {},
		_connections = {},
		_pair = nil :: string?,
		_kingdoms = {} :: { [string]: string? },
		_lines = {} :: { [string]: { text: string, ends: number, priority: boolean } },
		_gui = nil :: any,
		_preview = nil :: any,
		_previewOwned = false, -- the director was made by the preview, not by a duel
		director = nil :: any,
		reacted = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

-- The arena state comes from FORGE-01's DuelController, the client's one door to the arena (G12.6;
-- FORGE-00's ruling on FORGE-07's #256 M1): it asks Arena.GetState once and fires stateChanged for
-- the reply and every push, so this controller never asks itself (the remote allows a burst of 3
-- asks, then 1 a second). getState() at start seeds a client that joins or reloads mid-duel. The
-- Loader errors at load without the dependency, so there is no fallback here.
function Controller:_followDuel()
	local duel = self._registry:find("DuelController")
	table.insert(
		self._connections,
		duel.stateChanged:connect(function(state)
			self:onArenaState(state)
		end)
	)
	local ok, state = pcall(duel.getState, duel)
	if ok and state ~= nil then
		self:onArenaState(state)
	end
end

function Controller:start()
	local env = self._env
	self:_followDuel()
	table.insert(
		self._links,
		RemoteLink.on(env, "Arena.Events", function(batch)
			self:onEvents(batch)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(env, "Match.State", function(phase)
			self:onPhase(phase)
		end)
	)
	local announcer = self._registry:find("AnnouncerController")
	if announcer ~= nil and announcer.moment ~= nil then
		table.insert(
			self._connections,
			announcer.moment:connect(function()
				self:onAnnouncer()
			end)
		)
	end
	self:_watchPreview()
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(Def.STEP_SEC)
			if self._running then
				self:step()
			end
		end
	end)
end

function Controller:destroy()
	self._running = false
	for _, link in self._links do
		pcall(function()
			link:disconnect()
		end)
	end
	table.clear(self._links)
	for _, connection in self._connections do
		pcall(function()
			if connection.disconnect then
				connection:disconnect()
			else
				connection:Disconnect()
			end
		end)
	end
	table.clear(self._connections)
	self:_clear()
	self.reacted:disconnectAll()
end

-- ------------------------------------------------------------------ arena state

function Controller:_name(duellist: any): string?
	if type(duellist) ~= "table" or duellist.isAI == true or type(duellist.userId) ~= "number" then
		return nil
	end
	local names = self._opts.userNames
	if names ~= nil then
		return names[duellist.userId]
	end
	local ok, name = pcall(function()
		local player = self._env.Players:GetPlayerByUserId(duellist.userId)
		return player and player.DisplayName
	end)
	return if ok and type(name) == "string" and name ~= "" then name else nil
end

function Controller:_setup(state: any)
	local a, b = state.a, state.b
	self.director = CrowdDirector.new(Crowd, {
		a = { tier = a.tier, kingdom = a.kingdom, rulerName = self:_name(a) },
		b = { tier = b.tier, kingdom = b.kingdom, rulerName = self:_name(b) },
	})
	self._kingdoms = { a = a.kingdom, b = b.kingdom }
end

function Controller:onArenaState(state: any)
	if type(state) ~= "table" then
		return
	end
	local stage = state.stage
	local a, b = state.a, state.b
	if Def.DUEL_STAGES[stage] and type(a) == "table" and type(b) == "table" then
		local pair = `{tostring(a.userId)}:{tostring(b.userId)}`
		if pair ~= self._pair then
			self._pair = pair
			self._preview = nil -- a real duel takes over from the Studio preview
			self._previewOwned = false
			self:_setup(state)
		end
	elseif stage == "crowning" then
		local director = self.director
		if director ~= nil then
			local winner = nil
			for _, side in { "a", "b" } do
				local duellist = state[side]
				if type(duellist) == "table" and state.winner ~= nil and duellist.userId == state.winner then
					winner = side
				end
			end
			self:_present(director:finish(winner, self._env.clock()))
		end
	elseif stage == "done" then
		self:_end()
	end
end

function Controller:onEvents(batch: any)
	local director = self.director
	if director == nil or type(batch) ~= "table" then
		return
	end
	local now = self._env.clock()
	for _, event in batch do
		self:_present(director:onEvent(event, now))
	end
end

function Controller:onPhase(phase: any)
	if type(phase) == "string" and Def.END_PHASES[phase] then
		self:_end()
	end
end

function Controller:onAnnouncer()
	local director = self.director
	if director ~= nil then
		director:duck(self._env.clock(), Crowd.duck.announcerSec)
	end
end

function Controller:_end()
	self.director = nil
	self._pair = nil
	self._preview = nil
	self._previewOwned = false
	self:_clear()
end

-- ------------------------------------------------------------------ presenting

function Controller:_present(reactions: { any })
	local now = self._env.clock()
	for _, reaction in reactions do
		local kingdom = self._kingdoms[reaction.stand]
		if reaction.sound ~= nil then
			local audio = self._registry:find("AudioController")
			if audio ~= nil and audio.play ~= nil then
				local director = self.director
				local volume = if director ~= nil then director:volume(now) else 1
				pcall(audio.play, audio, reaction.sound, { volume = volume })
			end
		end
		if type(reaction.caption) == "string" and reaction.caption ~= "" then
			local name = if kingdom ~= nil then NAMES[kingdom] or kingdom else nil
			local text = if name ~= nil then `{name}: {reaction.caption}` else reaction.caption
			self:_caption(reaction.stand, text, reaction.priority == true, now)
		end
		self.reacted:fire(reaction, kingdom)
	end
end

function Controller:_caption(stand: string, text: string, priority: boolean, now: number)
	local current = self._lines[stand]
	if current ~= nil and current.priority and not priority and now < current.ends then
		return -- a perk or the ending keeps its line
	end
	self._lines[stand] = {
		text = text,
		priority = priority,
		ends = now + (if priority then Def.PRIORITY_SEC else Def.CAPTION_SEC),
	}
	self:_render()
end

function Controller:captions(): { string }
	local out = {}
	for _, stand in { "a", "b" } do
		local line = self._lines[stand]
		if line ~= nil then
			table.insert(out, line.text)
		end
	end
	return out
end

function Controller:step(now: number?)
	local clock = now or self._env.clock()
	local changed = false
	for stand, line in self._lines do
		if clock >= line.ends then
			self._lines[stand] = nil
			changed = true
		end
	end
	if changed then
		self:_render()
	end
	local preview = self._preview
	if preview ~= nil and clock >= preview.next then
		preview.next = clock + Def.PREVIEW_STEP_SEC
		preview.index += 1
		local event = Def.PREVIEW[preview.index]
		if event == nil then
			self._preview = nil
		elseif self.director ~= nil then
			self:_present(self.director:onEvent(event, clock))
		end
	end
end

function Controller:_playerGui(): any
	if self._opts.playerGui ~= nil then
		return self._opts.playerGui
	end
	local ok, found = pcall(function()
		return self._env.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	return if ok then found else nil
end

function Controller:_render()
	local gui = self._gui
	if gui == nil then
		local parent = self:_playerGui()
		if parent == nil then
			return
		end
		local env = self._env
		local ok, made = pcall(function()
			local screen = env.newInstance("ScreenGui")
			screen.Name = Def.GUI_NAME
			screen.ResetOnSpawn = false
			screen.DisplayOrder = 4
			for _, stand in { "a", "b" } do
				local label = env.newInstance("TextLabel")
				label.Name = `Caption_{stand}`
				label.BackgroundColor3 = Color3.fromRGB(16, 14, 20)
				label.BackgroundTransparency = 0.35
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextSize = Def.LINE.textSize
				label.Font = Enum.Font.GothamMedium
				label.TextWrapped = true
				label.RichText = false
				label.Text = ""
				label.Visible = false
				label.Parent = screen
			end
			screen.Parent = parent
			return screen
		end)
		if not ok then
			return
		end
		gui = made
		self._gui = gui
	end
	local area = self:_touchArea()
	local rule = Def.LINE
	pcall(function()
		for index, stand in { "a", "b" } do
			local label = gui:FindFirstChild(`Caption_{stand}`)
			local line = self._lines[stand]
			if label ~= nil then
				if area ~= nil then -- left of the duel buttons, above the thumbstick, stacking upwards
					local bottom = if area.left < Def.SMALL_TOUCH_LEFT
						then rule.thumbClear.small
						else rule.thumbClear.large
					label.AnchorPoint = Vector2.new(0, 1)
					label.Position = UDim2.new(0, rule.edge, 1, -bottom - (index - 1) * rule.step)
					label.Size = UDim2.new(1, -(area.left + rule.clear + rule.edge), 0, rule.height)
				else
					label.AnchorPoint = Vector2.new(0.5, 1)
					label.Position = UDim2.new(0.5, 0, 0.86, -(index - 1) * rule.step)
					label.Size = UDim2.new(0.7, 0, 0, rule.height)
				end
				label.Text = if line ~= nil then line.text else ""
				label.Visible = line ~= nil
			end
		end
	end)
end

-- The duel's touch buttons on screen (InputModeArenaController:touchArea: px from the bottom-right).
function Controller:_touchArea(): { left: number, top: number }?
	local arena = self._registry:find("InputModeArenaController")
	if arena == nil or arena.touchArea == nil then
		return nil
	end
	local ok, area = pcall(arena.touchArea, arena)
	if ok and type(area) == "table" and type(area.left) == "number" and type(area.top) == "number" then
		return area
	end
	return nil
end

function Controller:_clear()
	table.clear(self._lines)
	local gui = self._gui
	self._gui = nil
	if gui ~= nil then
		pcall(function()
			gui:Destroy()
		end)
	end
end

-- ------------------------------------------------------------------ Studio preview

function Controller:_isStudio(): boolean
	if self._opts.studio ~= nil then
		return self._opts.studio == true
	end
	local ok, studio = pcall(function()
		return self._env.RunService:IsStudio()
	end)
	return ok and studio == true
end

function Controller:_watchPreview()
	if not self:_isStudio() then
		return
	end
	pcall(function()
		local player = self._opts.player or self._env.Players.LocalPlayer
		local function read()
			self:preview(player:GetAttribute(Def.PREVIEW_ATTRIBUTE))
		end
		table.insert(self._connections, player:GetAttributeChangedSignal(Def.PREVIEW_ATTRIBUTE):Connect(read))
		read()
	end)
end

-- "tierA,tierB" starts the scripted duel with those tiers; anything else stops a running preview.
function Controller:preview(spec: any): boolean
	if not self:_isStudio() then
		return false
	end
	local tierA, tierB = nil, nil
	if type(spec) == "string" then
		tierA, tierB = string.match(spec, "^%s*(%a+)%s*,%s*(%a+)%s*$")
	end
	if tierA == nil then -- stop
		if self._previewOwned then
			self:_end()
		end
		return true
	end
	if self._pair ~= nil then
		return false -- a real duel is never interrupted by the preview
	end
	local now = self._env.clock()
	self.director = CrowdDirector.new(Crowd, {
		a = { tier = tierA, kingdom = "crimson", rulerName = "Preview" },
		b = { tier = tierB, kingdom = "azure" },
	})
	self._kingdoms = { a = "crimson", b = "azure" }
	self._previewOwned = true
	self._preview = { index = 0, next = now }
	self:step(now)
	return true
end

return Def
