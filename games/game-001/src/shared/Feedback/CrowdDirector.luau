--!strict
--[[
	Feedback/CrowdDirector (game-001, FORGE-04, FL-0074 part 1; CONTRACTS G12 DRAFT; design
	crown-arena.md §3 tier table and §7): what the two arena stands do, and when. Pure and
	deterministic: no Roblox API, time is passed in. The client crowd controller (part 2, after
	FORGE-01's FL-0071 and FORGE-02's FL-0072) plays what it returns; the server sends no crowd data.

		CrowdDirector.figures(citizens, config) -> number      -- one per citizensPerFigure, <= maxPerStand
		CrowdDirector.stands(citizensA, citizensB, config) -> (a, b)   -- both, total <= maxTotal
		CrowdDirector.seated(figures, tier, config) -> number  -- how many stay in their seats (tier fill)
		CrowdDirector.ending(won, tier, config) -> "flood" | "thinCrowning" | "salute" | "empty"
		CrowdDirector.chant(kingdom, index, rulerName, config) -> string   -- a pre-written line
		local director = CrowdDirector.new(config, { a = { tier, kingdom }, b = { tier, kingdom } })
		director:onEvent(event, now) -> { Reaction }           -- an Arena.Events entry (G12.4)
		director:idle(stand) -> Reaction                       -- between moments
		director:finish(winner?, now) -> { Reaction }          -- both stands' endings; always plays;
		                                                       -- nil = no winner: both stands go quiet
		director:duck(now, seconds)  /  director:volume(now) -> number   -- under the announcer
		Reaction = { stand: "a" | "b", kind: string, major: boolean, priority: boolean,
		             sound: string?, caption: string?, data: { [string]: any }? }

	Events (Arena.Events kinds; `side` is the champion the event is about):
		hit          side landed it. Major when data.heavy or data.damage >= moments.bigHit (a share of
		             max HP), else minor (only the hitter's stand reacts). data.hp, the target's HP share
		             after the hit, drives near-death and comeback.
		parry        side parried: major.
		stagger      side is staggered: major, bad for side.
		staminaOut   side ran out of stamina: minor, bad for side.
		heavyWindup  side winds up a heavy: minor murmur in side's stand.
		triggerFired side's perk fired (data.trigger, data.citizenName): a priority perk moment in side's
		             stand ("rally" for crowdRally); it ducks the crowd for duck.perkSec.
		hype         data.full: side's stand chants when its tier chants (a major).
		ended        side won: the same as finish(side). No side (no winner: a disconnect, the Crown
		             Points fallback) is finish(nil): both stands go quiet and the crowd stops.
		A major reaction has both stands react: side's stand by its tier's good (or bad), the other
		stand by the opposite. Derived majors: near-death (a champion's HP share first falls below
		moments.nearDeath: bad for them) and comeback (a champion who trailed by moments.comeback or
		more takes the lead: good for them).
	Rationing: at most one major every majorGapSec for both stands together; a major arriving sooner
	is dropped, not queued (the moment has passed). Minor reactions: one per stand every minorGapSec.
	Perk moments and the ending always play, and they restart the major gap.
	Unknown kinds, sides or tiers are ignored (a tier the config lacks counts as "divided").
]]

local CrowdDirector = {}

export type Stand = "a" | "b"
export type Reaction = {
	stand: Stand,
	kind: string,
	major: boolean,
	priority: boolean,
	sound: string?,
	caption: string?,
	data: { [string]: any }?,
}

local SIDES = { a = "b", b = "a" }

local function count(value: any): number
	return if type(value) == "number" and value > 0 then value else 0 -- NaN > 0 is false
end

function CrowdDirector.figures(citizens: any, config: any): number
	local n = math.floor(count(citizens))
	return math.min(math.ceil(n / config.citizensPerFigure), config.maxPerStand)
end

function CrowdDirector.stands(citizensA: any, citizensB: any, config: any): (number, number)
	local a = CrowdDirector.figures(citizensA, config)
	local b = CrowdDirector.figures(citizensB, config)
	local over = a + b - config.maxTotal
	if over > 0 then -- only reachable when maxTotal < 2 * maxPerStand: trim the bigger stand first
		local trimA = math.min(over, math.max(0, a - b))
		a -= trimA
		over -= trimA
		local trimB = math.min(over, math.max(0, b - a))
		b -= trimB
		over -= trimB
		a -= math.ceil(over / 2)
		b -= math.floor(over / 2)
	end
	return a, b
end

local function tierOf(tier: any, config: any): any
	return config.tiers[tier] or config.tiers.divided
end

function CrowdDirector.seated(figures: number, tier: any, config: any): number
	return math.floor(figures * tierOf(tier, config).fill + 0.5)
end

function CrowdDirector.ending(won: boolean, tier: any, config: any): string
	local high = config.highSupport[tier] == true
	if won then
		return if high then "flood" else "thinCrowning"
	end
	return if high then "salute" else "empty"
end

function CrowdDirector.chant(kingdom: any, index: number, rulerName: any, config: any): string
	local lines = config.chants[kingdom] or config.chants.any
	local line = lines[((index - 1) % #lines) + 1]
	local name = if type(rulerName) == "string" and rulerName ~= "" then rulerName else nil
	if name == nil then
		if string.find(line, "{ruler}", 1, true) then
			line = config.chants.any[1] -- no name to chant: a line without one
		end
		return line
	end
	return (string.gsub(line, "{ruler}", function()
		return name
	end))
end

local Director = {}
Director.__index = Director

function CrowdDirector.new(config: any, setup: any)
	local sides = {}
	for _, stand in { "a", "b" } do
		local side = if type(setup) == "table" and type(setup[stand]) == "table" then setup[stand] else {}
		sides[stand] = {
			tier = if config.tiers[side.tier] then side.tier else "divided",
			kingdom = side.kingdom,
			rulerName = side.rulerName,
			chants = 0,
		}
	end
	return setmetatable({
		_config = config,
		_sides = sides,
		_hp = { a = 1, b = 1 },
		_trailed = { a = false, b = false },
		_nearDeath = { a = false, b = false },
		_lastMajor = -math.huge,
		_lastMinor = { a = -math.huge, b = -math.huge },
		_duckUntil = -math.huge,
		_ended = false,
	}, Director)
end

function Director:_reaction(stand: Stand, kind: string, major: boolean, priority: boolean, data: any?): Reaction
	local entry = self._config.reactions[kind] or {}
	local caption = entry.caption
	if kind == "chant" then
		local side = self._sides[stand]
		side.chants += 1
		caption = CrowdDirector.chant(side.kingdom, side.chants, side.rulerName, self._config)
	elseif caption ~= nil and type(data) == "table" then
		caption = string.gsub(caption, "{(%w+)}", function(key)
			local value = data[key]
			return if type(value) == "string" then value else nil
		end)
	end
	return {
		stand = stand,
		kind = kind,
		major = major,
		priority = priority,
		sound = entry.sound,
		caption = caption,
		data = data,
	}
end

-- Both stands react to a moment that is good (or bad) for `stand`'s champion.
function Director:_both(stand: Stand, good: boolean, priority: boolean): { Reaction }
	local other = SIDES[stand] :: Stand
	local mine = tierOf(self._sides[stand].tier, self._config)
	local theirs = tierOf(self._sides[other].tier, self._config)
	return {
		self:_reaction(stand, if good then mine.good else mine.bad, true, priority),
		self:_reaction(other, if good then theirs.bad else theirs.good, true, priority),
	}
end

function Director:_major(now: number, stand: Stand, good: boolean): { Reaction }
	if now - self._lastMajor < self._config.majorGapSec then
		return {}
	end
	self._lastMajor = now
	return self:_both(stand, good, false)
end

function Director:_minor(now: number, stand: Stand, kind: string): { Reaction }
	if now - self._lastMinor[stand] < self._config.minorGapSec then
		return {}
	end
	self._lastMinor[stand] = now
	return { self:_reaction(stand, kind, false, false) }
end

-- Near-death and comeback from the target's HP share after a hit.
function Director:_track(target: Stand, hp: any): (string?, Stand?)
	if type(hp) ~= "number" or hp ~= hp then
		return nil, nil
	end
	self._hp[target] = math.clamp(hp, 0, 1)
	local moments = self._config.moments
	local hitter = SIDES[target] :: Stand
	for _, stand in { "a", "b" } :: { Stand } do
		if self._hp[SIDES[stand]] - self._hp[stand] >= moments.comeback then
			self._trailed[stand] = true
		end
	end
	if self._trailed[hitter] and self._hp[hitter] > self._hp[target] then
		self._trailed[hitter] = false
		return "comeback", hitter
	end
	if not self._nearDeath[target] and self._hp[target] > 0 and self._hp[target] < moments.nearDeath then
		self._nearDeath[target] = true
		return "nearDeath", target
	end
	return nil, nil
end

function Director:onEvent(event: any, now: number): { Reaction }
	if self._ended or type(event) ~= "table" then
		return {}
	end
	if event.kind == "ended" and event.side == nil then
		return self:finish(nil, now) -- no winner
	end
	if SIDES[event.side] == nil then
		return {}
	end
	local side = event.side :: Stand
	local data = if type(event.data) == "table" then event.data else {}
	local kind = event.kind
	local config = self._config
	if kind == "hit" then
		local moment, who = self:_track(SIDES[side] :: Stand, data.hp)
		if moment == "comeback" and who ~= nil then
			return self:_major(now, who, true)
		elseif moment == "nearDeath" and who ~= nil then
			return self:_major(now, who, false)
		end
		if data.heavy == true or count(data.damage) >= config.moments.bigHit then
			return self:_major(now, side, true)
		end
		return self:_minor(now, side, tierOf(self._sides[side].tier, config).good)
	elseif kind == "parry" then
		return self:_major(now, side, true)
	elseif kind == "stagger" then
		return self:_major(now, side, false)
	elseif kind == "staminaOut" then
		return self:_minor(now, side, tierOf(self._sides[side].tier, config).bad)
	elseif kind == "heavyWindup" then
		return self:_minor(now, side, "murmur")
	elseif kind == "triggerFired" then
		self._lastMajor = now
		self:duck(now, config.duck.perkSec)
		local rally = data.trigger == "crowdRally"
		return {
			self:_reaction(side, if rally then "rally" else "perk", true, true, {
				trigger = data.triggerName or data.trigger,
				citizen = data.citizenName or "A citizen",
			}),
		}
	elseif kind == "hype" then
		if data.full ~= true or not tierOf(self._sides[side].tier, config).chants then
			return {}
		end
		if now - self._lastMajor < config.majorGapSec then
			return {}
		end
		self._lastMajor = now
		return { self:_reaction(side, "chant", true, false) }
	elseif kind == "ended" then
		return self:finish(side, now)
	end
	return {}
end

function Director:idle(stand: Stand): Reaction?
	local side = self._sides[stand]
	if side == nil then
		return nil
	end
	return self:_reaction(stand, tierOf(side.tier, self._config).idle, false, false)
end

-- The ending (design §7): win or loss x high or low support, for both stands. Plays once.
function Director:finish(winner: any, now: number): { Reaction }
	if self._ended or (winner ~= nil and SIDES[winner] == nil) then
		return {}
	end
	self._ended = true
	self._lastMajor = now
	if winner == nil then -- no winner (FORGE-07's #193 L1): a neutral close, then nothing more
		return { self:_reaction("a", "quiet", true, true), self:_reaction("b", "quiet", true, true) }
	end
	local out = {}
	for _, stand in { "a", "b" } :: { Stand } do
		local ending = CrowdDirector.ending(stand == winner, self._sides[stand].tier, self._config)
		local entry = self._config.endings[ending]
		table.insert(out, {
			stand = stand,
			kind = ending,
			major = true,
			priority = true,
			sound = entry.sound,
			caption = entry.caption,
		})
	end
	return out
end

function Director:duck(now: number, seconds: any)
	if type(seconds) == "number" and seconds > 0 then -- NaN > 0 is false
		self._duckUntil = math.max(self._duckUntil, now + math.min(seconds, 30))
	end
end

function Director:volume(now: number): number
	return if now < self._duckUntil then self._config.duck.volume else 1
end

return table.freeze(CrowdDirector)
