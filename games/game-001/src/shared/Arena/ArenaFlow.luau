--!strict
--[[
	Arena/ArenaFlow — the Crown Arena's stage flow as a pure state machine (CONTRACTS G12.1/G12.4, design §2/§4).
	Owner: FORGE-01. No Roblox API, no clock (the caller passes `now`), no randomness: the same setup and calls give the
	same arena, so the specs run whole arenas headless. ArenaService owns one Flow per match and feeds it the world.

	Stages: vote -> loadout -> intro -> duel -> crowning -> done. A stage that has nothing to decide is skipped: no vote
	when every qualified kingdom has at most one candidate, no loadout when both champions are AI. One qualifier is last
	keep standing: a coronation, straight to the crowning with no duel.

		ArenaFlow.new(setup, now, config?) -> Flow
			setup.qualifiers   { KingdomId }: 1 (coronation) or 2, side "a" first (the better Crown Points)
			setup.rulersOf     (KingdomId) -> { userId }       the human rulers seated there
			setup.leadership   (userId, KingdomId) -> number   valour + conduct, the tie-break for a champion
			setup.citizens     (KingdomId) -> number?          optional: the kingdom's living citizens, read once per
			                   champion when the arena starts and shown as Duellist.citizens
			setup.support      (userId?, KingdomId) -> Support the champion's support: { score, tier, offers, slots,
			                   reasons }; userId nil for an AI kingdom (SupportService turns samples into this)
		Flow:state() -> ArenaState        the public picture (same table shape as Types.ArenaState); `rev` changes with it
		Flow:champion(side) -> Champion?  { userId, kingdom, isAI, offers, slots, weapon, armour, triggers }
		Flow:vote(userId, candidate) -> (ok, reason?)
			vote stage only; the voter is a seated human ruler of a qualified kingdom, the candidate one of that
			kingdom's rulers; the latest vote counts; closes the stage early when every ruler has voted
		Flow:choose(userId, weapon, armour, triggers) -> (ok, reason?)
			loadout stage only; the champion only; weapon and armour from Duel config, triggers distinct, a subset of
			the champion's own offers, at most min(slots, 3); the latest choice counts
		Flow:step(now) -> boolean         advances every stage whose time is up; true when the state changed
		Flow:endDuel(result, now) -> boolean  result "a" | "b" | "draw"; duel stage only; starts the crowning
		Flow:forfeit(userId, now) -> boolean  a champion leaves before the crowning: the other side wins, both gone =
			draw; a ruler leaving during the vote just drops out (no human ruler left = AI champion)
		Flow:cancel(reason) -> boolean    the arena is called off: stage done, no winner
		Flow:winnerKingdom() -> KingdomId? the kingdom that won the match, once the crowning has begun; nil = Crown Points
		Flow:result() -> { kind, reason }? how it ended: "duel" | "coronation" | "forfeit" | "draw" | "cancelled"

	Champion rule (design §2): the most votes; a tie or no votes goes to the higher leadership, then the lower userId.
	An AI champion has isAI = true and a userId no player can have (ArenaFlow.AI_USER_ID: -1000000001 for side a,
	-1000000002 for side b). Default loadout for a human who
	never chooses: config Arena default weapon and armour, and the offered perks in order up to their slots.
]]

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local DuelConfig = require("@game/ReplicatedStorage/Forge/Config/Duel")
local Caps = require("./Caps")
local Types = require("./Types")

type ArenaState = Types.ArenaState
type Duellist = Types.Duellist
type TriggerOffer = Types.TriggerOffer

export type Support = {
	score: number,
	tier: Types.SupportTier,
	offers: { TriggerOffer },
	slots: number,
	reasons: { string },
}

local ArenaFlow = {}
ArenaFlow.__index = ArenaFlow

-- An AI champion's userId: a value no player can have (Studio test players take small negative ids), so a client's
-- "winner == me" test and the world's position lookup can never mistake an AI for a person.
ArenaFlow.AI_USER_ID = table.freeze({ a = -1000000001, b = -1000000002 })

local function sortedCopy(list: { number }): { number }
	local out = table.clone(list)
	table.sort(out)
	return out
end

local function contains(list: { number }, value: number): boolean
	return table.find(list, value) ~= nil
end

-- The perks offered, in order, up to the slots (and the contract's 3).
local function defaultTriggers(offers: { TriggerOffer }, slots: number): { string }
	local out: { string } = {}
	for _, offer in offers do
		if #out >= math.min(slots, Caps.NUMBERS.maxTriggers) then
			break
		end
		table.insert(out, offer.trigger)
	end
	return out
end

local function newChampion(side: string, kingdom: string, userId: number?, support: Support, config: any): any
	local isAI = userId == nil
	return {
		side = side,
		kingdom = kingdom,
		userId = if userId then userId else ArenaFlow.AI_USER_ID[side],
		isAI = isAI,
		support = support,
		weapon = if isAI then config.ai.weapon else config.defaultWeapon,
		armour = if isAI then config.ai.armour else config.defaultArmour,
		triggers = defaultTriggers(support.offers, support.slots),
		chosen = false,
		gone = false,
	}
end

function ArenaFlow.new(setup: any, now: number, config: any?): any
	local cfg = config or ArenaConfig
	assert(type(setup) == "table", "ArenaFlow.new: setup required")
	local qualifiers = setup.qualifiers
	assert(type(qualifiers) == "table" and (#qualifiers == 1 or #qualifiers == 2), "ArenaFlow.new: 1 or 2 qualifiers")
	local self = setmetatable({}, ArenaFlow)
	self._cfg = cfg
	self._setup = setup
	self._rev = 0
	self._stage = "vote"
	self._endsAt = nil :: number?
	self._sides = { "a", "b" }
	self._kingdoms = {} :: { [string]: string } -- side -> kingdom
	self._candidates = {} :: { [string]: { number } } -- side -> seated human rulers (sorted)
	self._votes = {} :: { [number]: number } -- voter -> candidate
	self._champions = {} :: { [string]: any }
	self._winnerSide = nil :: string?
	self._winnerKingdom = nil :: string?
	self._winnerUser = nil :: number?
	self._crownedAt = nil :: number?
	self._coronation = nil :: string?
	self._result = nil :: { kind: string, reason: string? }?
	self._duelEndsAt = nil :: number?
	for index, kingdom in qualifiers do
		local side = self._sides[index]
		self._kingdoms[side] = kingdom
		self._candidates[side] = sortedCopy(setup.rulersOf(kingdom))
	end
	if #qualifiers == 1 then
		self:_crown(nil, qualifiers[1], nil, { kind = "coronation" }, now)
		return self
	end
	if self:_needsVote() then
		self._stage = "vote"
		self._endsAt = now + cfg.voteSeconds
	else
		self:_pickChampions()
		self:_afterChampions(now)
	end
	return self
end

function ArenaFlow:_needsVote(): boolean
	for _, side in self._sides do
		if self._kingdoms[side] and #self._candidates[side] > 1 then
			return true
		end
	end
	return false
end

-- Each side's champion: the vote, else leadership, else the lowest userId; an AI when no human ruler is seated.
function ArenaFlow:_pickChampions()
	for _, side in self._sides do
		local kingdom = self._kingdoms[side]
		if kingdom == nil then
			continue
		end
		local candidates = self._candidates[side]
		local userId: number? = nil
		if #candidates > 0 then
			local tally: { [number]: number } = {}
			for voter, candidate in self._votes do
				if contains(candidates, voter) and contains(candidates, candidate) then
					tally[candidate] = (tally[candidate] or 0) + 1
				end
			end
			local best: number? = nil
			for _, candidate in candidates do -- sorted: the lowest userId wins a full tie
				local better = best == nil
				if not better then
					local votes, bestVotes = tally[candidate] or 0, tally[best :: number] or 0
					if votes ~= bestVotes then
						better = votes > bestVotes
					else
						better = self._setup.leadership(candidate, kingdom)
							> self._setup.leadership(best :: number, kingdom)
					end
				end
				if better then
					best = candidate
				end
			end
			userId = best
		end
		local support = self._setup.support(userId, kingdom)
		local champion = newChampion(side, kingdom, userId, support, self._cfg)
		local citizens = if self._setup.citizens then self._setup.citizens(kingdom) else nil
		champion.citizens = if type(citizens) == "number" and citizens == citizens
			then math.max(0, math.floor(citizens))
			else nil
		self._champions[side] = champion
	end
end

function ArenaFlow:_afterChampions(now: number)
	local anyHuman = false
	for _, champion in self._champions do
		anyHuman = anyHuman or not champion.isAI
	end
	if anyHuman then
		self._stage = "loadout"
		self._endsAt = now + self._cfg.loadoutSeconds
	else
		self:_startIntro(now)
	end
	self._rev += 1
end

function ArenaFlow:_startIntro(now: number)
	self._stage = "intro"
	self._endsAt = now + self._cfg.introSeconds
end

function ArenaFlow:_crown(
	side: string?,
	kingdom: string?,
	userId: number?,
	result: { kind: string, reason: string? },
	now: number
)
	self._stage = "crowning"
	self._endsAt = now + self._cfg.crowningSeconds
	self._winnerSide = side
	self._winnerKingdom = kingdom
	self._winnerUser = userId
	self._crownedAt = now
	self._coronation = if result.kind == "coronation" then kingdom else nil
	self._result = result
	self._rev += 1
end

function ArenaFlow:_championOf(userId: number): any?
	for _, champion in self._champions do
		if champion.userId == userId and not champion.isAI then
			return champion
		end
	end
	return nil
end

-- ---------------------------------------------------------------- queries
local function duellist(champion: any): Duellist
	local citizens: { [string]: { name: string, role: string } } = {}
	for _, offer in champion.support.offers do
		if table.find(champion.triggers, offer.trigger) and offer.citizenName and offer.role then
			citizens[offer.trigger] = { name = offer.citizenName, role = offer.role }
		end
	end
	return {
		userId = champion.userId,
		kingdom = champion.kingdom,
		isAI = champion.isAI,
		tier = champion.support.tier,
		score = champion.support.score,
		weapon = champion.weapon,
		armour = champion.armour,
		triggers = table.clone(champion.triggers) :: any,
		reasons = table.clone(champion.support.reasons),
		triggerCitizens = if next(citizens) then citizens else nil,
		citizens = champion.citizens,
	}
end

function ArenaFlow:state(): ArenaState
	local a, b = self._champions.a, self._champions.b
	return {
		stage = self._stage :: any,
		endsAt = self._endsAt,
		a = if a then duellist(a) else nil,
		b = if b then duellist(b) else nil,
		coronation = self._coronation,
		winner = self._winnerUser,
	}
end

function ArenaFlow:rev(): number
	return self._rev
end

function ArenaFlow:stage(): string
	return self._stage
end

function ArenaFlow:champion(side: string): any?
	return self._champions[side]
end

function ArenaFlow:candidates(side: string): { number }
	return table.clone(self._candidates[side] or {})
end

function ArenaFlow:kingdom(side: string): string?
	return self._kingdoms[side]
end

function ArenaFlow:winnerKingdom(): string?
	return self._winnerKingdom
end

function ArenaFlow:result(): { kind: string, reason: string? }?
	return self._result
end

-- ---------------------------------------------------------------- inputs
function ArenaFlow:vote(userId: number, candidate: number): (boolean, string?)
	if self._stage ~= "vote" then
		return false, "not_vote_stage"
	end
	if type(userId) ~= "number" or type(candidate) ~= "number" or candidate ~= candidate then
		return false, "bad_arguments"
	end
	for _, side in self._sides do
		local candidates = self._candidates[side]
		if candidates and contains(candidates, userId) then
			if not contains(candidates, candidate) then
				return false, "not_a_candidate"
			end
			self._votes[userId] = candidate
			self._rev += 1
			return true, nil
		end
	end
	return false, "not_a_voter"
end

function ArenaFlow:choose(userId: number, weapon: string, armour: string, triggers: { string }): (boolean, string?)
	if self._stage ~= "loadout" then
		return false, "not_loadout_stage"
	end
	local champion = if type(userId) == "number" then self:_championOf(userId) else nil
	if champion == nil then
		return false, "not_champion"
	end
	if type(weapon) ~= "string" or DuelConfig.weapons[weapon] == nil then
		return false, "bad_weapon"
	end
	if type(armour) ~= "string" or DuelConfig.armour[armour] == nil then
		return false, "bad_armour"
	end
	if type(triggers) ~= "table" then
		return false, "bad_arguments"
	end
	local count = 0
	for _ in triggers do
		count += 1
	end
	if count ~= #triggers then -- a dictionary or sparse table is not a list
		return false, "bad_arguments"
	end
	local limit = math.min(champion.support.slots, Caps.NUMBERS.maxTriggers)
	if count > limit then
		return false, "too_many"
	end
	local seen: { [string]: boolean } = {}
	local chosen: { string } = {}
	for _, trigger in triggers do
		if type(trigger) ~= "string" then
			return false, "bad_arguments"
		end
		if seen[trigger] then
			return false, "duplicate"
		end
		seen[trigger] = true
		local offered = false
		for _, offer in champion.support.offers do
			offered = offered or offer.trigger == trigger
		end
		if not offered then
			return false, "not_offered"
		end
		table.insert(chosen, trigger)
	end
	champion.weapon = weapon
	champion.armour = armour
	champion.triggers = chosen
	champion.chosen = true
	self._rev += 1
	return true, nil
end

-- ---------------------------------------------------------------- time
function ArenaFlow:step(now: number): boolean
	local changed = false
	while self._endsAt ~= nil and now >= self._endsAt and self._stage ~= "done" do
		local at = self._endsAt :: number
		if self._stage == "vote" then
			self:_pickChampions()
			self:_afterChampions(at)
		elseif self._stage == "loadout" then
			self:_startIntro(at)
			self._rev += 1
		elseif self._stage == "intro" then
			self._stage = "duel"
			self._endsAt = at + self._cfg.duelMaxSeconds
			self._rev += 1
		elseif self._stage == "duel" then
			self:_crown(nil, nil, nil, { kind = "draw", reason = "duel_clock" }, at)
		elseif self._stage == "crowning" then
			self._stage = "done"
			self._endsAt = nil
			self._rev += 1
		end
		changed = true
	end
	if self._stage == "vote" and self:_allVoted() then
		self:_pickChampions()
		self:_afterChampions(now)
		changed = true
	end
	return changed
end

function ArenaFlow:_allVoted(): boolean
	for _, side in self._sides do
		local candidates = self._candidates[side] or {}
		if #candidates > 1 then -- a kingdom with one ruler has nothing to vote on
			for _, voter in candidates do
				if self._votes[voter] == nil then
					return false
				end
			end
		end
	end
	return true
end

-- The duel is over (`now` is the clock the crowning counts from).
function ArenaFlow:endDuel(result: string, now: number): boolean
	if self._stage ~= "duel" then
		return false
	end
	if result == "a" or result == "b" then
		local champion = self._champions[result]
		self:_crown(result, champion.kingdom, champion.userId, { kind = "duel" }, now)
	else
		self:_crown(nil, nil, nil, { kind = "draw", reason = "duel" }, now)
	end
	return true
end

function ArenaFlow:forfeit(userId: number, now: number): boolean
	if self._stage == "crowning" and self._result and self._result.kind == "forfeit" and userId == self._winnerUser then
		-- the second champion left within the same moment: nobody outlasted the other
		local champion = self:_championOf(userId) -- a human champion only: an AI's id is not a leaver
		if champion and now - (self._crownedAt :: number) <= self._cfg.simultaneousSeconds then
			champion.gone = true
			self:_crown(nil, nil, nil, { kind = "draw", reason = "both_left" }, self._crownedAt :: number)
			return true
		end
		return false
	end
	if self._stage == "crowning" or self._stage == "done" then
		return false
	end
	if self._stage == "vote" then
		local changed = false
		for _, side in self._sides do
			local candidates = self._candidates[side]
			local index = if candidates then table.find(candidates, userId) else nil
			if index then
				table.remove(candidates, index)
				changed = true
			end
		end
		self._votes[userId] = nil
		for voter, candidate in self._votes do
			if candidate == userId then
				self._votes[voter] = nil
			end
		end
		if changed then
			self._rev += 1
		end
		return changed
	end
	local champion = self:_championOf(userId)
	if champion == nil then
		return false
	end
	champion.gone = true
	local other = self._champions[if champion.side == "a" then "b" else "a"]
	if other ~= nil and not other.gone then
		self:_crown(other.side, other.kingdom, other.userId, { kind = "forfeit", reason = "left" }, now)
	else
		self:_crown(nil, nil, nil, { kind = "draw", reason = "both_left" }, now)
	end
	return true
end

function ArenaFlow:cancel(reason: string): boolean
	if self._stage == "done" then
		return false
	end
	self._stage = "done"
	self._endsAt = nil
	self._winnerSide, self._winnerKingdom, self._winnerUser, self._coronation = nil, nil, nil, nil
	self._result = { kind = "cancelled", reason = reason }
	self._rev += 1
	return true
end

return ArenaFlow
