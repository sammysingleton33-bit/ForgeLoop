--!strict
--[[
	Arena/DuelRunner — one Crown Arena duel as the server runs it (CONTRACTS G12.2/G12.4). Owner: FORGE-01. Pure: no Roblox
	API, no clock of its own (the caller passes `now`), no randomness beyond the seed. DuelService/ArenaService wire it to
	the remotes and the world; the specs run whole duels through it headless.

	It owns what the pure DuelModel deliberately does not: checking the support modifiers against the caps, deriving
	`inRange` and `facing` from where the duellists really stand, rate-limiting and validating the champions' actions,
	releasing a block a client never ends, an AI hand for AI champions, forfeits, and turning DuelModel's events into the
	shares-only `Arena.Events` payload.

		DuelRunner.new(setup, config?) -> Runner
			setup.a, setup.b  { userId, isAI, weapon, armour, modifiers?, skill?, triggerCitizens? }
			setup.seed        number
			setup.pose        (userId) -> { x, z, fx, fz }?   where a duellist stands and which way they face
			                  (fx, fz a unit vector); nil = unknown. Without `pose`, or when an AI duellist has none,
			                  the duel is virtual: always in range and facing. A human with no pose pauses the duel
			                  (config Arena `poseGraceSeconds`), then forfeits.
			setup.log         (level, message, fields)?
		Runner:act(userId, action, now) -> (ok, reason?)
			a champion's action: refused quietly (false + a reason, never an error) when the duel has not started
			or has ended, the sender is not a human champion, the action is not a DuelAction, or the champion is
			over the rate limit (burst 8, 12 per second). At most one action per champion is held for the next step.
		Runner:step(now) -> { RelayEvent }
			advances the duel by the real time since the last step in fixed ticks (at most maxCatchup seconds at a
			time); returns the events for Arena.Events. The first call starts the clock.
		Runner:forfeit(userId, now) -> {}
			the champion leaves: the other side wins, unless that side leaves within Arena.simultaneousSeconds of
			it, which makes it a draw. Nothing is decided inside that window: the duel stands still, `finished()` stays
			false and the one `ended` event (forfeit, side b/a/draw) comes from the first `step` after it.
		Runner:finished() -> boolean       Runner:result() -> ("a" | "b" | "draw", reason)?
		Runner:snapshot() -> the public picture (DuelModel.snapshot)
		RelayEvent = { t, kind, side, data? }, shares only, nothing about the opponent that a spectator cannot see:
			hit          side = the hitter   { damageShare, hpShare (the target's), heavy }
			heavyWindup  side = the attacker { impactIn (seconds), warned }
			parry, stagger, staminaOut, hype   side as DuelModel sends it, no data
			triggerFired side = who it helps { trigger = TriggerId, citizenName? }
			ended        side = "a" | "b" | "draw"   { reason = "ko" | "timeCap" | "hardCap" | "draw" | "forfeit" }
			snapshot     side = "a"          the public picture every `snapshotEvery` duel seconds
		`miss` and `dodged` stay inside (the contract's list for Arena.Events leaves them out).

	Support: each duellist's modifier list goes through Caps.check as a whole. A refusal is logged and the perks are
	dropped, keeping only the tier's own blessing if that passes; the duel never runs with a list the caps refuse.
]]

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local Caps = require("./Caps")
local DuelAI = require("./DuelAI")
local DuelModel = require("./DuelModel")
local Types = require("./Types")

type DuelEvent = Types.DuelEvent

local ACTIONS: { [string]: boolean } =
	{ light = true, heavy = true, block = true, blockEnd = true, parry = true, dodge = true }

local DuelRunner = {}
DuelRunner.__index = DuelRunner

local function noop() end

-- Where a duellist's modifiers stand against the caps: the whole list, else only the tier's blessing, else nothing.
local function vetted(modifiers: { Types.Modifier }?, who: string, log: any): { Types.Modifier }
	local list = modifiers or {}
	local ok, reason = Caps.check(list)
	if ok then
		return list
	end
	log("warn", "DuelRunner: support refused by the caps, perks dropped", { who = who, reason = reason })
	local blessing = {}
	for _, modifier in list do
		if type(modifier) == "table" and modifier.kind == "passive" and not modifier.slot then
			table.insert(blessing, modifier)
		end
	end
	if Caps.check(blessing) then
		return blessing
	end
	return {}
end

local function triggerOf(source: string): string
	return (string.gsub(source, "^perk:", ""))
end

function DuelRunner.new(setup: any, config: any?): any
	local cfg = config or ArenaConfig
	assert(
		type(setup) == "table" and type(setup.a) == "table" and type(setup.b) == "table",
		"DuelRunner.new: sides a and b"
	)
	local self = setmetatable({}, DuelRunner)
	self._cfg = cfg
	self._log = setup.log or noop
	self._pose = setup.pose
	self._sides = { a = setup.a, b = setup.b }
	self._model = DuelModel.new(
		nil,
		{ weapon = setup.a.weapon, armour = setup.a.armour, modifiers = vetted(setup.a.modifiers, "a", self._log) },
		{ weapon = setup.b.weapon, armour = setup.b.armour, modifiers = vetted(setup.b.modifiers, "b", self._log) },
		setup.seed or 1
	)
	self._ai = {} :: { [string]: any }
	for _, side in { "a", "b" } do
		local s = self._sides[side]
		if s.isAI then
			self._ai[side] = DuelAI.new(side, s.skill or 0.5, (setup.seed or 1) * 31 + (if side == "a" then 1 else 2))
		end
	end
	self._pending = {} :: { [string]: string }
	self._bucket = {} :: { [string]: { tokens: number, at: number } }
	self._blockSince = {} :: { [string]: number }
	self._last = nil :: number?
	self._acc = 0
	self._nextSnapshot = 0
	self._started = false
	self._pending_forfeit = nil :: { winner: string, at: number }?
	self._poseLostFor = { a = 0, b = 0 }
	self._poseLostTotal = { a = 0, b = 0 }
	self._result = nil :: { side: string, reason: string }?
	return self
end

-- ---------------------------------------------------------------- queries
function DuelRunner:finished(): boolean
	return self._result ~= nil
end

function DuelRunner:result(): (string?, string?)
	local result = self._result
	if result == nil then
		return nil, nil
	end
	return result.side, result.reason
end

function DuelRunner:snapshot(): { [string]: any }
	return DuelModel.snapshot(self._model)
end

-- ---------------------------------------------------------------- input
function DuelRunner:_sideOf(userId: number): string?
	for _, side in { "a", "b" } do
		local s = self._sides[side]
		if not s.isAI and s.userId == userId then
			return side
		end
	end
	return nil
end

function DuelRunner:act(userId: number, action: string, now: number): (boolean, string?)
	if not self._started or self._result ~= nil then
		return false, "no_duel"
	end
	local side = if type(userId) == "number" then self:_sideOf(userId) else nil
	if side == nil then
		return false, "not_champion"
	end
	if type(action) ~= "string" or not ACTIONS[action] then
		return false, "bad_action"
	end
	local rate = self._cfg.rate
	local bucket = self._bucket[side]
	if bucket == nil then
		bucket = { tokens = rate.burst, at = now }
		self._bucket[side] = bucket
	end
	bucket.tokens = math.min(rate.burst, bucket.tokens + math.max(0, now - bucket.at) * rate.perSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false, "rate_limited"
	end
	bucket.tokens -= 1
	self._pending[side] = action
	return true, nil
end

-- ---------------------------------------------------------------- the world
-- inRange and facing for the duellist on `side`, from where the pose provider says both stand.
function DuelRunner:_geometry(side: string): (boolean, boolean)
	local pose = self._pose
	if pose == nil then
		return true, true
	end
	local other = if side == "a" then "b" else "a"
	local mine, theirs = pose(self._sides[side].userId), pose(self._sides[other].userId)
	if mine == nil or theirs == nil then
		-- an AI has no body to measure: that part of the duel is virtual (a human without a pose never gets here:
		-- _poseLost pauses the duel)
		return true, true
	end
	local dx, dz = theirs.x - mine.x, theirs.z - mine.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local inRange = distance <= self._cfg.reach
	local facing = false
	if distance > 1e-6 then
		-- the provider's vector is not trusted to be unit length (a pitched look vector is shorter); zero = not facing
		local length = math.sqrt(mine.fx * mine.fx + mine.fz * mine.fz)
		facing = length > 1e-6 and (mine.fx * dx + mine.fz * dz) / (distance * length) >= self._cfg.facingMinDot
	else
		facing = true
	end
	return inRange, facing
end

-- ---------------------------------------------------------------- time
local function relay(model: any, citizens: { [string]: any }, event: DuelEvent, out: { any })
	local data = event.data
	local kind = event.kind
	if kind == "hit" and data then
		table.insert(out, {
			t = event.t,
			kind = "hit",
			side = event.side,
			data = {
				damageShare = data.damage / model.config.maxHp,
				hpShare = data.targetHpShare,
				heavy = data.heavy == true,
			},
		})
	elseif kind == "heavyWindup" and data then
		table.insert(out, {
			t = event.t,
			kind = kind,
			side = event.side,
			data = { impactIn = math.max(0, data.impactAt - event.t), warned = data.warned or 0 },
		})
	elseif kind == "triggerFired" and data then
		local trigger = triggerOf(data.source)
		local citizen = (citizens[event.side] or {})[trigger]
		table.insert(out, {
			t = event.t,
			kind = kind,
			side = event.side,
			data = { trigger = trigger, citizenName = if citizen then citizen.name else nil },
		})
	elseif kind == "parry" or kind == "stagger" or kind == "staminaOut" or kind == "hype" then
		table.insert(out, { t = event.t, kind = kind, side = event.side })
	elseif kind == "ended" and data then
		table.insert(out, { t = event.t, kind = kind, side = event.side, data = { reason = data.reason } })
	end
	-- miss and dodged stay inside
end

-- The snapshot event carries shares only (no raw hp or stamina), like every other event of the relay.
function DuelRunner:_publicSnapshot(): any
	local snapshot = DuelModel.snapshot(self._model)
	local function side(view: any): any
		return {
			hpShare = view.hpShare,
			staminaShare = math.clamp(view.staminaShare, 0, 1),
			state = view.state,
			hype = view.hype,
			weapon = view.weapon,
			armour = view.armour,
		}
	end
	return { t = snapshot.t, suddenDeath = snapshot.suddenDeath, a = side(snapshot.a), b = side(snapshot.b) }
end

function DuelRunner:_tick(out: { any })
	local model = self._model
	local cfg = self._cfg
	local snapshot = DuelModel.snapshot(model)
	local inputs: { [string]: any } = {}
	for _, side in { "a", "b" } do
		local action = self._pending[side]
		self._pending[side] = nil
		local ai = self._ai[side]
		if action == nil and ai then
			action = ai:decide(snapshot)
		end
		-- a block the client never ends is ended here
		if snapshot[side].state == "block" then
			local since = self._blockSince[side] or model.t
			self._blockSince[side] = since
			if action == nil and model.t - since >= cfg.blockMaxSeconds then
				action = "blockEnd"
			end
		else
			self._blockSince[side] = nil
		end
		local inRange, facing = self:_geometry(side)
		inputs[side] = { action = action, inRange = inRange, facing = facing }
	end
	local events = DuelModel.step(model, inputs, cfg.tick)
	for _, ai in self._ai do
		ai:observe(events)
	end
	local citizens = { a = self._sides.a.triggerCitizens or {}, b = self._sides.b.triggerCitizens or {} }
	for _, event in events do
		relay(model, citizens, event, out)
	end
	if model.t >= self._nextSnapshot and not model.ended then
		self._nextSnapshot = model.t + cfg.snapshotEvery
		table.insert(out, { t = model.t, kind = "snapshot", side = "a", data = self:_publicSnapshot() })
	end
	if model.ended and self._result == nil then
		local winner = if model.winner == "a" or model.winner == "b" then model.winner else "draw"
		self._result = { side = winner, reason = model.reason or "draw" }
	end
end

-- A human champion the pose provider cannot find (a reset, a respawn gap) pauses the duel instead of becoming a target
-- nobody can hit; after `poseGraceSeconds` without a pose (or twice that over the whole duel) that champion forfeits. True while the duel is paused.
function DuelRunner:_poseLost(elapsed: number, now: number, out: { any }): boolean
	if self._pose == nil then
		return false
	end
	local paused = false
	for _, side in { "a", "b" } do
		local duellist = self._sides[side]
		if duellist.isAI or duellist.gone then
			continue
		end
		if self._pose(duellist.userId) == nil then
			paused = true
			self._poseLostFor[side] += elapsed
			self._poseLostTotal[side] += elapsed
		else
			self._poseLostFor[side] = 0
		end
	end
	if not paused then
		return false
	end
	for _, side in { "a", "b" } do
		-- one run of missing poses, or the sum of many short ones (a respawn loop), spends the budget
		if
			self._poseLostFor[side] >= self._cfg.poseGraceSeconds
			or self._poseLostTotal[side] >= 2 * self._cfg.poseGraceSeconds
		then
			self:forfeit(self._sides[side].userId, now)
		end
	end
	return true
end

function DuelRunner:step(now: number): { any }
	local out: { any } = {}
	if self._result ~= nil then
		return out
	end
	if not self._started then
		self._started = true
		self._last = now
		return out
	end
	local pending = self._pending_forfeit
	if pending then
		-- the duel stands still while a forfeit settles; `finished()` and the one `ended` event wait out the window so
		-- a leave by the other champion in the same moment can still make it a draw
		if now - pending.at > self._cfg.simultaneousSeconds then
			self._result = { side = pending.winner, reason = "forfeit" }
			table.insert(
				out,
				{ t = self._model.t, kind = "ended", side = pending.winner, data = { reason = "forfeit" } }
			)
		end
		return out
	end
	local elapsed = math.min(math.max(0, now - (self._last :: number)), self._cfg.maxCatchup)
	self._last = now
	if self:_poseLost(elapsed, now, out) then
		return out
	end
	self._acc += elapsed
	local tick = self._cfg.tick
	while self._acc >= tick - 1e-9 and self._result == nil do
		self._acc -= tick
		self:_tick(out)
	end
	return out
end

function DuelRunner:forfeit(userId: number, now: number): { any }
	local out: { any } = {}
	local side = if type(userId) == "number" then self:_sideOf(userId) else nil
	if side == nil or self._result ~= nil then
		return out
	end
	local pending = self._pending_forfeit
	if pending then
		-- the winner leaving within the same moment as the loser: nobody outlasted the other
		if pending.winner == side and now - pending.at <= self._cfg.simultaneousSeconds then
			self._sides[side].gone = true
			pending.winner = "draw"
		end
		return out
	end
	self._sides[side].gone = true
	self._pending_forfeit = { winner = if side == "a" then "b" else "a", at = now }
	return out
end

return DuelRunner
