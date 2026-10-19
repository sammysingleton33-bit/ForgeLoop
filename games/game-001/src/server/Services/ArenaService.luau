--!strict
--[[
	ArenaService — the Crown Arena on the server (CONTRACTS G12.2/G12.4, design §2/§4/§5). Owner: FORGE-01.
	It is the shell around three pure modules: ArenaFlow (the stages), DuelRunner (the duel) and SupportService (who has
	earned what). It registers with MatchService as the arena host: when Endgame ends with two or more kingdoms standing the
	match calls `beginArena(qualifiers)`; when the crowning is over this service reports `arenaEnded(winnerKingdom)`, and
	a duel that ends in a draw, a cancel or a leaver with nobody left reports no winner, so Crown Points decide.

		ArenaService:state(): ArenaState             the public picture; { stage = "done" } when there is no arena
		ArenaService.stageChanged: Signal<(ArenaState)>
		Remotes (Arena/Remotes.luau):
			Arena.GetState() -> ArenaState       Arena.State(ArenaState) to everyone on every change
			Arena.Vote(candidate) -> boolean     Arena.Choose(weapon, armour, triggers) -> (ok, reason?)
			Arena.Action(action)                 quiet: anything outside a running duel by a champion is dropped
			Arena.Events({ event })              batched duel events, shares only (Arena/DuelRunner)

	Server-authoritative end to end: the sender of every call is the player (never an argument), votes and loadouts are
	validated by ArenaFlow against what the server itself built (the offers come from SupportService, the power of each
	perk from the offer, never from the client), every duellist's modifier list is checked against the caps by DuelRunner,
	`inRange` and `facing` come from where the characters stand on the server, and a player who leaves forfeits.

	The host answers beginArena with false unless config Arena `enabled` is true (it ships false until the client, the ring
	bounds and the Studio gate land), so the match goes to Crown Points exactly as with no host.
	Champions are placed on the marks of WorldLayout.arena (position, height, facing) at the start of the intro; a config
	`site` overrides it, and a fallback at the origin serves a world with neither. `site`, `placeAt` and `poseOf` can be
	replaced by specs.

	Clocks: every time handed to ArenaFlow and DuelRunner is `env.serverTimeNow()` seconds, because ArenaState.endsAt is
	compared by clients against the same clock. DuelRunner only ever steps forward (it clamps a backward or long jump to
	`maxCatchup`), so a server clock correction cannot rewind a duel.
	Dependencies: MatchService, RemoteService, SupportService, LeadershipService.
]]

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local ArenaFlow = require("@game/ReplicatedStorage/Game/Arena/ArenaFlow")
local DuelRunner = require("@game/ReplicatedStorage/Game/Arena/DuelRunner")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local ArenaService = {}
ArenaService.__index = ArenaService

-- Where the ring is when neither a config override nor WorldLayout.arena exists (a bare test world).
local FALLBACK_SITE = { x = 0, z = 0, separation = 8 }

local Def = {
	name = "ArenaService",
	dependencies = { "MatchService", "RemoteService", "SupportService", "LeadershipService" },
}

local IDLE_STATE = table.freeze({ stage = "done" })

function Def.new(env: any, registry: any)
	local self = setmetatable({}, ArenaService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._support = registry:get("SupportService")
	self._leadership = registry:get("LeadershipService")
	self.stageChanged = Signal.new()
	self._flow = nil :: any
	self._runner = nil :: any
	self._rev = -1
	self._placed = false
	self._running = false
	self._looping = false
	self._connections = {} :: { any }
	self._held = {} :: { [number]: any } -- userId -> { character, humanoid, walkSpeed } while a champion is held to the ring
	self.config = ArenaConfig -- specs may swap in a table of their own (short stages)
	self.placeAt = nil :: ((userId: number, x: number, z: number, toX: number, toZ: number) -> ())?
	return self
end

-- ---------------------------------------------------------------- the world
function ArenaService:_sim(): any
	return self._match.host.match.sim
end

function ArenaService:_now(): number
	return self._env.serverTimeNow()
end

-- Where a character stands and which way it faces, read on the server; nil when it has no body.
function ArenaService:poseOf(userId: number): { x: number, z: number, fx: number, fz: number }?
	local ok, pose = pcall(function()
		local player = self._env.Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			return nil
		end
		local position, look = root.CFrame.Position, root.CFrame.LookVector
		local length = math.sqrt(look.X * look.X + look.Z * look.Z)
		if length < 1e-6 then
			return { x = position.X, z = position.Z, fx = 0, fz = 0 }
		end
		return { x = position.X, z = position.Z, fx = look.X / length, fz = look.Z / length }
	end)
	return if ok then pose else nil
end

-- Puts a champion's character on the ring, facing the other.
function ArenaService:_place(userId: number, x: number, z: number, towardX: number, towardZ: number, height: number?)
	pcall(function()
		local player = self._env.Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			return
		end
		local y = height or root.CFrame.Position.Y
		character:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(towardX, y, towardZ)))
	end)
end

local function characterOf(env: any, userId: number): any?
	local player = env.Players:GetPlayerByUserId(userId)
	return if player then player.Character else nil
end

local function humanoidOf(character: any): any?
	local ok, humanoid = pcall(function()
		return character:FindFirstChildOfClass("Humanoid")
	end)
	return if ok then humanoid else nil
end

-- Where each side stands, and the ring around them: { a = mark, b = mark, ring = { x, z, radius, height? } } with a mark
-- { x, z, toX, toZ, height? }. The venue's own marks when there is no `site` override (position, height and facing).
function ArenaService:_layout(): any
	local site = self.config.site
	local venue = if site == nil then WorldLayout.arena else nil
	if venue then
		local from, to = venue.spawnA.Position, venue.spawnB.Position
		local centre = venue.cframe.Position
		return {
			a = { x = from.X, z = from.Z, toX = to.X, toZ = to.Z, height = from.Y },
			b = { x = to.X, z = to.Z, toX = from.X, toZ = from.Z, height = to.Y },
			ring = { x = centre.X, z = centre.Z, radius = venue.duelRadius, height = from.Y },
		}
	end
	site = site or FALLBACK_SITE
	local half = site.separation / 2
	return {
		a = { x = site.x - half, z = site.z, toX = site.x + half, toZ = site.z },
		b = { x = site.x + half, z = site.z, toX = site.x - half, toZ = site.z },
		ring = { x = site.x, z = site.z, radius = self.config.ring.fallbackRadius },
	}
end

function ArenaService:_placer(): (number, number, number, number, number, number?) -> ()
	return self.placeAt
		or function(userId: number, x: number, z: number, toX: number, toZ: number, height: number?)
			self:_place(userId, x, z, toX, toZ, height)
		end
end

function ArenaService:_placeChampions()
	local place = self:_placer()
	local layout = self:_layout()
	for _, side in { "a", "b" } do
		local champion = self._flow:champion(side)
		if champion and not champion.isAI then
			local mark = layout[side]
			place(champion.userId, mark.x, mark.z, mark.toX, mark.toZ, mark.height)
			local character = characterOf(self._env, champion.userId)
			if character ~= nil then
				self:_hold(champion.userId, character) -- from here on they are held to the ring
			end
		end
	end
end

-- ---------------------------------------------------------------- keeping the champions in the ring
-- Fixes WalkSpeed for the duel (remembering the old one) on a champion's current character.
function ArenaService:_hold(userId: number, character: any)
	local held = self._held[userId]
	local humanoid = humanoidOf(character)
	local original = if held and held.humanoid == humanoid then held.walkSpeed else nil
	if humanoid ~= nil then
		pcall(function()
			original = original or humanoid.WalkSpeed
			humanoid.WalkSpeed = self.config.ring.walkSpeed
		end)
	end
	self._held[userId] = { character = character, humanoid = humanoid, walkSpeed = original }
end

-- Gives every champion's WalkSpeed back.
function ArenaService:_releaseAll()
	for _, held in self._held do
		if held.humanoid ~= nil and held.walkSpeed ~= nil then
			pcall(function()
				held.humanoid.WalkSpeed = held.walkSpeed
			end)
		end
	end
	table.clear(self._held)
end

-- Once a tick, from the intro to the end of the duel: a champion whose character is new (a reset) goes back to their
-- mark with the fixed WalkSpeed; one beyond the ring's radius plus the margin is put back at the edge.
function ArenaService:_guard()
	local flow = self._flow
	local layout = self:_layout()
	local place = self:_placer()
	local ring = layout.ring
	local limit = ring.radius + self.config.ring.margin
	for _, side in { "a", "b" } do
		local champion = flow:champion(side)
		if champion == nil or champion.isAI or champion.gone then
			continue
		end
		local character = characterOf(self._env, champion.userId)
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character == nil or root == nil then
			continue -- no body to place; the runner's pose-loss pause covers it
		end
		local held = self._held[champion.userId]
		if held == nil or held.character ~= character then
			local mark = layout[side]
			place(champion.userId, mark.x, mark.z, mark.toX, mark.toZ, mark.height)
			self:_hold(champion.userId, character)
			continue
		end
		local position = root.CFrame.Position
		local dx, dz = position.X - ring.x, position.Z - ring.z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance > limit then
			local scale = ring.radius / distance
			place(champion.userId, ring.x + dx * scale, ring.z + dz * scale, ring.x, ring.z, ring.height)
		end
	end
end

-- ---------------------------------------------------------------- the arena
function ArenaService:state(): any
	if self._flow == nil then
		return IDLE_STATE
	end
	return self._flow:state()
end

function ArenaService:_publish()
	local flow = self._flow
	if flow == nil then
		return
	end
	local rev = flow:rev()
	if rev == self._rev then
		return
	end
	self._rev = rev
	local state = flow:state()
	self._remotes:fireAll("Arena.State", state)
	self.stageChanged:fire(state)
end

function ArenaService:_neutralSupport(): any
	return { score = 50, tier = "divided", offers = {}, slots = 0, reasons = {} }
end

function ArenaService:_begin(qualifiers: { string }): boolean
	if self._flow ~= nil then
		return false
	end
	local sim = self:_sim()
	local leadership = self._leadership
	local support = self._support
	leadership:closeOut() -- the last phase (Endgame) is credited before the arena reads the ledger
	local ok, flow = pcall(ArenaFlow.new, {
		qualifiers = qualifiers,
		rulersOf = function(kingdom: string): { number }
			local k = sim.kingdoms[kingdom]
			return if k then table.clone(k.rulers) else {}
		end,
		citizens = function(kingdom: string): number
			local k = sim.kingdoms[kingdom]
			local living = 0
			for _, id in if k then k.citizenIds else {} do
				local citizen = sim.citizens[id]
				if citizen and citizen.alive ~= false then
					living += 1
				end
			end
			return living
		end,
		leadership = function(userId: number, kingdom: string): number
			return leadership:leadership(kingdom, userId)
		end,
		support = function(userId: number?, kingdom: string): any
			return support:forChampion(userId, kingdom) or self:_neutralSupport()
		end,
	}, self:_now(), self.config)
	if not ok then
		self._env.log("error", "ArenaService: the arena could not begin", { error = tostring(flow) })
		return false
	end
	self._flow = flow
	self._runner = nil
	self._rev = -1
	self._placed = false
	self:_publish()
	self:_ensureLoop()
	return true
end

function ArenaService:_cancel(reason: string)
	local flow = self._flow
	if flow == nil then
		return
	end
	flow:cancel(reason)
	self:_publish()
	self:_releaseAll()
	self._flow, self._runner = nil, nil
	self._remotes:fireAll("Arena.State", IDLE_STATE)
end

-- The modifiers a champion takes into the duel: the tier's blessing and the chosen perks, each at the power its offer
-- carries (the server's own, never the client's).
function ArenaService:_modifiers(champion: any): { any }
	local picks = {}
	for _, trigger in champion.triggers do
		for _, offer in champion.support.offers do
			if offer.trigger == trigger then
				table.insert(picks, { trigger = trigger, power = offer.power })
			end
		end
	end
	local ok, modifiers = pcall(SupportModel.modifiers, champion.support.tier, picks)
	if not ok then
		self._env.log("warn", "ArenaService: support modifiers refused", { error = tostring(modifiers) })
		return {}
	end
	return modifiers
end

function ArenaService:_startDuel()
	local flow = self._flow
	local state = flow:state()
	local function setup(side: string): any
		local champion = flow:champion(side)
		local duellist = state[side]
		return {
			userId = champion.userId,
			isAI = champion.isAI,
			weapon = champion.weapon,
			armour = champion.armour,
			modifiers = self:_modifiers(champion),
			skill = self.config.ai.skill,
			triggerCitizens = duellist and duellist.triggerCitizens,
		}
	end
	self._runner = DuelRunner.new({
		a = setup("a"),
		b = setup("b"),
		seed = (math.floor(self:_now() * 1000) % 2147483646) + 1,
		pose = function(userId: number)
			return self:poseOf(userId)
		end,
		log = function(level: string, message: string, fields: any)
			self._env.log(level, message, fields)
		end,
	}, self.config)
	self._runner:step(self:_now()) -- starts its clock
end

function ArenaService:_relay(events: { any })
	if #events > 0 then
		self._remotes:fireAll("Arena.Events", events)
	end
end

function ArenaService:_finish()
	local flow = self._flow
	local winner = flow:winnerKingdom()
	self:_publish()
	self:_releaseAll()
	self._flow, self._runner = nil, nil
	self._remotes:fireAll("Arena.State", IDLE_STATE)
	self._match:arenaEnded(winner)
end

function ArenaService:step()
	local flow = self._flow
	if flow == nil then
		return
	end
	local now = self:_now()
	flow:step(now)
	local stage = flow:stage()
	if stage == "intro" and not self._placed then
		self._placed = true
		self:_placeChampions()
	end
	if stage == "intro" or stage == "duel" then
		self:_guard()
	elseif next(self._held) ~= nil then
		self:_releaseAll() -- the duel is over (or called off): WalkSpeed goes back
	end
	if stage == "duel" then
		if self._runner == nil then
			self:_startDuel()
		end
		self:_relay(self._runner:step(now))
		if self._runner:finished() then
			local side = self._runner:result()
			self._runner = nil
			flow:endDuel(side or "draw", now)
		end
	elseif self._runner ~= nil then
		self._runner = nil -- the arena moved on (a forfeit, a cancel): no duel to step
	end
	self:_publish()
	if flow:stage() == "done" then
		self:_finish()
	end
end

function ArenaService:_ensureLoop()
	if self._looping then
		return
	end
	self._looping = true
	self._env.spawn(function()
		while self._running and self._flow ~= nil do
			self._env.wait(self.config.tick)
			if self._running and self._flow ~= nil then
				local ok, err = pcall(self.step, self)
				if not ok then
					self._env.log("error", "ArenaService: step failed", { error = tostring(err) })
				end
			end
		end
		self._looping = false
	end)
end

-- A player who leaves forfeits: before the duel through the flow, in it through the runner.
function ArenaService:_left(userId: number)
	local flow = self._flow
	if flow == nil then
		return
	end
	local now = self:_now()
	if self._runner ~= nil and flow:stage() == "duel" then
		self:_relay(self._runner:forfeit(userId, now))
		if self._runner:finished() then
			local side = self._runner:result()
			self._runner = nil
			flow:endDuel(side or "draw", now)
		end
	else
		flow:forfeit(userId, now)
	end
	self:_publish()
	if flow:stage() == "done" then
		self:_finish()
	end
end

-- ---------------------------------------------------------------- lifecycle
function ArenaService:start()
	self._running = true
	self._match:registerArena({
		beginArena = function(qualifiers: { string }): boolean
			if not self.config.enabled then
				return false -- not switched on yet: the match settles on Crown Points at once
			end
			return self:_begin(qualifiers)
		end,
		cancelArena = function(reason: string)
			self:_cancel(reason)
		end,
	})
	self._remotes:handle("Arena.GetState", function(): any
		return self:state()
	end)
	self._remotes:handle("Arena.Vote", function(player: any, candidate: number): boolean
		local flow = self._flow
		if flow == nil then
			return false
		end
		local ok = flow:vote(player.UserId, candidate)
		self:_publish()
		return ok
	end)
	self._remotes:handle("Arena.Choose", function(player: any, weapon: string, armour: string, triggers: { string })
		local flow = self._flow
		if flow == nil then
			return false, "no_arena"
		end
		local ok, reason = flow:choose(player.UserId, weapon, armour, triggers)
		self:_publish()
		return ok, reason
	end)
	self._remotes:handle("Arena.Action", function(player: any, action: string)
		local runner = self._runner
		if runner ~= nil then
			runner:act(player.UserId, action, self:_now()) -- refused quietly: no reply, no error
		end
	end)
	table.insert(
		self._connections,
		self._env.Players.PlayerRemoving:Connect(function(player: any)
			local ok, err = pcall(self._left, self, player.UserId)
			if not ok then
				self._env.log("error", "ArenaService: leaving player failed", { error = tostring(err) })
			end
		end)
	)
end

function ArenaService:destroy()
	self._running = false
	self:_releaseAll()
	self.stageChanged:disconnectAll()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return Def
