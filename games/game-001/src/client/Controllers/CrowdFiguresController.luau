--!strict
--[[
	CrowdFiguresController (game-001, FORGE-04, FL-0074 part 2c; CONTRACTS G12.6; design crown-arena.md
	§3 and §7; FORGE-02's handoff 2026-10-18-forge-02-to-forge-01-04-fl0072-arena.md): the people in the
	Crown Arena's two stands. Client only: the server sends no crowd data.

	When
		- FeedbackCrowdController makes a CrowdDirector for a duel (Arena.State names both duellists at
		  intro or duel; or its Studio preview): the stands fill. A new director (a new pair) refills
		  them; no director (done, Results, Lobby) empties them.
		- Without FORGE-02's CrownArena model (tag CrownArena) on this client, nothing is built yet: the
		  place streams (Workspace.StreamingEnabled), so the arena may arrive after the director; every
		  step retries until it is there (FORGE-07 #237 M1), then the stands fill once.
		- The stands are built Def.BUILD_PER_STEP figures a step, both stands in turn, front rows first
		  (FORGE-00's B22 note: never 480 parts in one frame); a full arena takes 5 steps.
		- Arena.State is pushed only on a change, so start() also asks Arena.GetState once: a client
		  that joins or reloads mid-duel still gets each side's citizens (a push that came first wins).
	Who sits
		- Stand A holds side a's kingdom, stand B side b's (Kit.arena: Stand A at -Z, as the dress and
		  the intro camera). Figures: CrowdDirector.stands(citizensA, citizensB) (one per two citizens,
		  <= 60 a stand, <= 120 in all), then CrowdDirector.seated(figures, tier) of them sit (the tier's
		  fill: a hostile crowd leaves half its seats empty). Citizens come from Arena.State's duellist
		  `citizens` field when the server sends it; until then a stand counts as full (60 figures).
		- Seats fill from the centre outwards, the front row first (Def.order), so a thin crowd still
		  sits where the camera looks. The grid is FORGE-02's (Kit.ARENA.SEAT_ROWS, SEATS_PER_STAND);
		  a seat attachment the model lacks stays empty, with one warning. Figure i is
		  Kit.crowdFigure(kingdom colour, nil, variant) with FORGE-02's variant formula
		  (row * 5 + seat * 3) % Kit.CROWD_VARIANTS + 1, placed on its attachment StandX_Row<r>_Seat<s>
		  (feet on the plank, facing the ring) with WorldView.placeModel.
		- Figures are parented to Workspace.ForgeCrowdFigures (client-made, not under the arena model).
		- Low-end clients: with the effectsQuality setting "reduced" (FL-0103) each stand seats
		  Def.REDUCED_SHARE of its figures, rounded down (at most 60 in the arena, 240 parts), read when
		  the stands fill.
	How they move (FeedbackCrowdController.reacted)
		Def.MOTIONS maps each reaction kind to a motion of that reaction's stand for its seconds:
			hop    a share of the stand bobs up and down (roar, cheer, chant, rally, perk, flood ...)
			slump  the stand sinks a little (gasp, mutter, boo)
			turn   the stand turns its backs on the ring (turnBack: the strongest negative)
		Kinds with no motion (murmur, quiet, silence, calledOff, ...) leave the stand still. With reduced
		motion on (the in-game setting or the platform's: SettingsController:reducedMotion()), a hop is
		skipped (the stand stays still); a slump or a turn is one step, not an animation, so it still
		shows. Which figures hop is a pure function of the figure's index and the share, so a third of
		a stand is always the same third. Every motion ends with each figure back on its seat.
	API
		controller.figures                      -- { a: { Figure }, b: { Figure } }, Figure = { model, seat: CFrame, row, seat# }
		controller:refresh()                    -- follows the crowd controller's director (step calls it)
		controller:onReaction(reaction, kingdom?)
		controller:step(now?)                   -- refresh, then advance the motions
		Def.order(rows, seats) -> { { row, seat } }   Def.variant(row, seat) -> number
		Def.counts(citizens, tiers) -> { a: number, b: number }
	Engine access is guarded: no Workspace, CollectionService or arena model means no figures.
]]

local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local CrowdDirector = require("@game/ReplicatedStorage/Game/Feedback/CrowdDirector")
local Kingdoms = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")

local Controller = {}
Controller.__index = Controller

local Def = { name = "CrowdFiguresController", dependencies = { "FeedbackCrowdController" } }

Def.TAG = "CrownArena"
Def.FOLDER = "ForgeCrowdFigures"
Def.ROWS = Kit.ARENA.SEAT_ROWS -- FORGE-02's seat grid (G12.6), never a copy of it
Def.SEATS = math.floor(Kit.ARENA.SEATS_PER_STAND / Kit.ARENA.SEAT_ROWS) -- 18 a row: the royal gap skipped
Def.BUILD_PER_STEP = 24 -- figures built per step: 120 figures over 5 steps (a third of a second at 15 Hz)
Def.STEP_SEC = 1 / 15
Def.HOP_STUDS = 0.7
Def.HOP_HZ = 2.5
Def.SLUMP_STUDS = 0.35
Def.STANDS = table.freeze({ a = "A", b = "B" })
Def.REDUCED_SHARE = 0.5 -- the share of each stand seated with effectsQuality = "reduced"

-- reaction kind -> motion of that reaction's stand (Crowd.tiers' idle/good/bad words, the perk and
-- rally moments, the chant, and the four endings)
Def.MOTIONS = table.freeze({
	roar = table.freeze({ motion = "hop", share = 1, sec = 1.6 }),
	cheer = table.freeze({ motion = "hop", share = 0.6, sec = 1.2 }),
	chant = table.freeze({ motion = "hop", share = 0.8, sec = 2.4 }),
	rally = table.freeze({ motion = "hop", share = 1, sec = 2 }),
	perk = table.freeze({ motion = "hop", share = 0.5, sec = 1.2 }),
	mixed = table.freeze({ motion = "hop", share = 0.3, sec = 1 }),
	scattered = table.freeze({ motion = "hop", share = 0.15, sec = 0.8 }),
	flood = table.freeze({ motion = "hop", share = 1, sec = 6 }),
	thinCrowning = table.freeze({ motion = "hop", share = 0.4, sec = 4 }),
	salute = table.freeze({ motion = "hop", share = 0.25, sec = 3 }),
	gasp = table.freeze({ motion = "slump", share = 1, sec = 0.8 }),
	mutter = table.freeze({ motion = "slump", share = 0.5, sec = 1 }),
	boo = table.freeze({ motion = "slump", share = 1, sec = 1.4 }),
	turnBack = table.freeze({ motion = "turn", share = 1, sec = 3 }),
	empty = table.freeze({ motion = "turn", share = 0.5, sec = 4 }),
})

-- Seats in fill order: the front row first, each row from its centre outwards (left before right).
function Def.order(rows: number?, seats: number?): { { row: number, seat: number } }
	local nRows, nSeats = rows or Def.ROWS, seats or Def.SEATS
	local middle = (nSeats + 1) / 2
	local out = {}
	for row = 1, nRows do
		local list = {}
		for seat = 1, nSeats do
			table.insert(list, seat)
		end
		table.sort(list, function(x, y)
			local dx, dy = math.abs(x - middle), math.abs(y - middle)
			if dx ~= dy then
				return dx < dy
			end
			return x < y
		end)
		for _, seat in list do
			table.insert(out, { row = row, seat = seat })
		end
	end
	return out
end

-- FORGE-02's varied-crowd formula (every figure is deterministic from its three arguments).
function Def.variant(row: number, seat: number): number
	return (row * 5 + seat * 3) % Kit.CROWD_VARIANTS + 1
end

-- How many figures sit in each stand: the director's counts, then the tier's fill. A stand whose
-- citizens are unknown (nil) counts as full.
function Def.counts(citizens: { a: number?, b: number? }, tiers: { a: string?, b: string? }): { a: number, b: number }
	local full = Crowd.maxPerStand * Crowd.citizensPerFigure
	local a, b = CrowdDirector.stands(citizens.a or full, citizens.b or full, Crowd)
	return {
		a = CrowdDirector.seated(a, tiers.a, Crowd),
		b = CrowdDirector.seated(b, tiers.b, Crowd),
	}
end

-- Whether figure `index` of a stand moves for a motion with this share (the same figures each time).
function Def.moves(index: number, share: number): boolean
	if share >= 1 then
		return true
	end
	if share <= 0 then
		return false
	end
	-- spread the moving figures evenly: index i moves when its slot crosses a multiple of 1/share
	return math.floor(index * share) ~= math.floor((index - 1) * share)
end

local COLORS: { [string]: Color3 } = {}
for _, kingdom in Kingdoms.identities do
	if type(kingdom) == "table" and type(kingdom.id) == "string" and type(kingdom.color) == "table" then
		COLORS[kingdom.id] = Color3.fromRGB(kingdom.color[1], kingdom.color[2], kingdom.color[3])
	end
end
Def.COLORS = COLORS

-- opts (specs): { kit, workspace, model }
function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_opts = options,
		_kit = options.kit or Kit,
		_links = {},
		_connections = {},
		_director = nil :: any,
		_pending = false, -- a director waits for the arena model (streaming) or is still being built
		_plan = nil :: { any }?, -- the seats left to build for this director, in build order
		_warnedSeats = false,
		_arenaSeen = false,
		_destroyed = false,
		_citizens = {} :: { a: number?, b: number? },
		_motions = {} :: { [string]: any },
		_folder = nil :: any,
		figures = { a = {}, b = {} } :: { [string]: { any } },
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:start()
	local env = self._env
	table.insert(
		self._links,
		RemoteLink.on(env, "Arena.State", function(state)
			self._arenaSeen = true
			self:onArenaState(state)
		end)
	)
	-- Arena.State is pushed only on a change: a client that joins or reloads mid-duel asks once
	-- (FORGE-00's B22 verifier note); a push that came first is newer and wins.
	RemoteLink.request(env, "Arena.GetState", function(state)
		if not self._destroyed and not self._arenaSeen then
			self:onArenaState(state)
		end
	end)
	local crowd = self._registry:find("FeedbackCrowdController")
	if crowd ~= nil and crowd.reacted ~= nil then
		table.insert(
			self._connections,
			crowd.reacted:connect(function(reaction, kingdom)
				self:onReaction(reaction, kingdom)
			end)
		)
	end
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
	self._destroyed = true
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
end

-- Arena.State: remember each side's citizens when the server sends them (an additive field).
function Controller:onArenaState(state: any)
	if type(state) ~= "table" then
		return
	end
	for _, side in { "a", "b" } do
		local duellist = state[side]
		local citizens = if type(duellist) == "table" then duellist.citizens else nil
		self._citizens[side] = if type(citizens) == "number"
				and citizens == citizens
				and citizens >= 0
			then citizens
			else nil
	end
end

-- ------------------------------------------------------------------ seating

function Controller:_arena(): any
	if self._opts.model ~= nil then
		return self._opts.model
	end
	local ok, tagged = pcall(function()
		return self._env.CollectionService:GetTagged(Def.TAG)
	end)
	return if ok and type(tagged) == "table" then tagged[1] else nil
end

-- A client setting (SettingsController, optional): nil without one.
function Controller:_setting(key: string): any
	local settings = self._registry:find("SettingsController")
	if settings == nil or type(settings.get) ~= "function" then
		return nil
	end
	local ok, value = pcall(settings.get, settings, key)
	return if ok then value else nil
end

-- Reduced motion: SettingsController:reducedMotion() is the in-game toggle OR the platform's Reduce
-- Motion (GuiService.ReducedMotionEnabled), as the other controllers ask (FORGE-07 #237 M2); get() only
-- on a settings object without it.
function Controller:_reducedMotion(): boolean
	local settings = self._registry:find("SettingsController")
	if settings == nil then
		return false
	end
	local ok, reduced = pcall(function()
		return if type(settings.reducedMotion) == "function"
			then settings:reducedMotion()
			else settings:get("reducedMotion")
	end)
	return ok and reduced == true
end

function Controller:_workspace(): any
	return self._opts.workspace or self._env.Workspace
end

-- Follows the crowd controller: a new director fills the stands, none empties them.
function Controller:refresh()
	local crowd = self._registry:find("FeedbackCrowdController")
	local director = if crowd ~= nil then crowd.director else nil
	if director ~= self._director then
		self._director = director
		self:_clear()
		self._pending = director ~= nil and director.side ~= nil
	end
	if self._pending then
		self._pending = not self:_seat(director) -- retried each step until the arena has streamed in
	end
end

-- Builds the stands Def.BUILD_PER_STEP figures at a time (FORGE-00: never 480 parts in one frame);
-- false while the arena (or its Root) has not streamed in or figures are left, so refresh goes on.
function Controller:_seat(director: any): boolean
	if self._plan == nil then
		self._plan = self:_planSeats(director)
		if self._plan == nil then
			return false
		end
	end
	local plan = self._plan :: { any }
	local built = 0
	while #plan > 0 and built < Def.BUILD_PER_STEP do
		local spot = table.remove(plan, 1)
		built += 1
		local ok, figure = pcall(self._kit.crowdFigure, spot.color, nil, Def.variant(spot.row, spot.seatIndex))
		if ok and figure ~= nil then
			WorldView.placeModel(figure, spot.seat)
			figure.Name = `Stand{Def.STANDS[spot.side]}_{spot.index}`
			figure.Parent = self._folder
			table.insert(
				self.figures[spot.side],
				{ model = figure, seat = spot.seat, row = spot.row, seatIndex = spot.seatIndex }
			)
		end
	end
	return #plan == 0
end

-- The seats to fill, in build order: both stands alternate, each from its front row's centre out.
-- nil while the arena has not streamed in. A seat attachment the model lacks is skipped with one
-- warning per controller (Kit drift, not a silent gap).
function Controller:_planSeats(director: any): { any }?
	local model = self:_arena()
	local root = model and model:FindFirstChild("Root")
	local parent = self:_workspace()
	if root == nil or parent == nil then
		return nil
	end
	local sides = { a = director:side("a"), b = director:side("b") }
	local counts = Def.counts(self._citizens, { a = sides.a.tier, b = sides.b.tier })
	if self:_setting("effectsQuality") == "reduced" then
		counts.a = math.floor(counts.a * Def.REDUCED_SHARE)
		counts.b = math.floor(counts.b * Def.REDUCED_SHARE)
	end
	local folder = self._env.newInstance("Folder")
	folder.Name = Def.FOLDER
	folder.Parent = parent
	self._folder = folder
	local order = Def.order()
	local perSide = { a = {}, b = {} }
	for _, side in { "a", "b" } do
		local color = COLORS[sides[side].kingdom or ""]
		if color == nil then
			continue -- a kingdom the config lacks: an empty stand, never a wrong colour
		end
		for index = 1, math.min(counts[side], #order) do
			local spot = order[index]
			local name = `Stand{Def.STANDS[side]}_Row{spot.row}_Seat{spot.seat}`
			local attachment = root:FindFirstChild(name)
			if attachment == nil then
				if not self._warnedSeats then
					self._warnedSeats = true
					self._env.log(
						"warn",
						"CrowdFiguresController: a seat attachment is missing; that seat stays empty",
						{
							seat = name,
						}
					)
				end
				continue
			end
			table.insert(perSide[side], {
				side = side,
				index = index,
				row = spot.row,
				seatIndex = spot.seat,
				seat = root.CFrame * attachment.CFrame,
				color = color,
			})
		end
	end
	local plan = {}
	for i = 1, math.max(#perSide.a, #perSide.b) do
		for _, side in { "a", "b" } do
			if perSide[side][i] ~= nil then
				table.insert(plan, perSide[side][i])
			end
		end
	end
	return plan
end

function Controller:_clear()
	self._pending = false
	self._plan = nil
	table.clear(self._motions)
	self.figures = { a = {}, b = {} }
	if self._folder ~= nil then
		pcall(function()
			self._folder:Destroy()
		end)
		self._folder = nil
	end
end

-- ------------------------------------------------------------------ motion

function Controller:onReaction(reaction: any, _kingdom: any?)
	if type(reaction) ~= "table" or Def.STANDS[reaction.stand] == nil then
		return
	end
	self:refresh() -- the director may be new since the last step
	local spec = Def.MOTIONS[reaction.kind]
	if spec == nil or (spec.motion == "hop" and self:_reducedMotion()) then
		return
	end
	if self._motions[reaction.stand] ~= nil then
		self:_settle(reaction.stand) -- a new motion starts from the seats (the old share may differ)
	end
	self._motions[reaction.stand] = { spec = spec, started = self._env.clock() }
end

-- Every figure of a stand back on its seat.
function Controller:_settle(side: string)
	for _, figure in self.figures[side] or {} do
		WorldView.placeModel(figure.model, figure.seat)
	end
end

local function offsetFor(spec: any, index: number, t: number): CFrame
	if spec.motion == "hop" then
		local phase = (index % 7) / 7
		local lift = math.abs(math.sin(math.pi * (t * Def.HOP_HZ + phase))) * Def.HOP_STUDS
		return CFrame.new(0, lift, 0)
	elseif spec.motion == "slump" then
		return CFrame.new(0, -Def.SLUMP_STUDS, 0)
	elseif spec.motion == "turn" then
		return CFrame.Angles(0, math.pi, 0)
	end
	return CFrame.new()
end

function Controller:step(now: number?)
	self:refresh()
	local t = now or self._env.clock()
	for side, motion in self._motions do
		local elapsed = t - motion.started
		local over = elapsed >= motion.spec.sec
		for index, figure in self.figures[side] or {} do
			if Def.moves(index, motion.spec.share) then
				local cf = if over then figure.seat else figure.seat * offsetFor(motion.spec, index, elapsed)
				WorldView.placeModel(figure.model, cf)
			end
		end
		if over then
			self._motions[side] = nil
		end
	end
end

return Def
