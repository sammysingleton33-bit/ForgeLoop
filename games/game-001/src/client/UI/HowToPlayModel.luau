--!strict
--[[
	UI/HowToPlayModel — "How to play": the whole D-053 match in six short cards (FL-0138; launch-ready "a new player can
	understand how to play"). Pure; no instances. UI/HowToPlay draws it, HowToPlayController opens it.

		HowToPlayModel.cards(cfg?) -> { Card }   six cards, in match order
			Card = { id, title, icon, picture (an icon name drawn large), body (plain words, < WORD_LIMIT words) }
			cfg = { pacing, match, caps, arena } (defaults: config Pacing, config Match, Arena/Caps, config Arena), so
			every number is the game's own: the phase lengths of Match.mode from Pacing (else Match.durations), the
			arena's length from Pacing.arena (else config Arena's stage seconds),
			the newcomer lock and the support caps. Nothing here is bought or sold (D-053: no monetization).
		HowToPlayModel.phases(cfg?) -> string   "Founding 8 min, Expansion 12 min, Conflict 15 min, Endgame 10 min"
		HowToPlayModel.words(s) -> number        the word count a spec checks
		HowToPlayModel.view(cards, index) -> { card, index, count, first, last, step "2 of 6", dots }
	The texts are UI copy (FORGE-03), not content-library lines. They name no alliances or betrayal (VS-3) and do not
	repeat FORGE-04's in-match tips (FL-0137) word for word: the cards explain the rules, the tips point at buttons.
]]

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local Caps = require("@game/ReplicatedStorage/Game/Arena/Caps")
local Match = require("@game/ReplicatedStorage/Forge/Config/Match")
local Pacing = require("@game/ReplicatedStorage/Forge/Config/Pacing")

local HowToPlayModel = {}

HowToPlayModel.WORD_LIMIT = 60
HowToPlayModel.PHASES = table.freeze({ "Founding", "Expansion", "Conflict", "Endgame" })

local function defaults(cfg: any?): any
	local c = cfg or {}
	return {
		pacing = c.pacing or Pacing,
		match = c.match or Match,
		caps = c.caps or Caps.NUMBERS,
		arena = c.arena or ArenaConfig,
	}
end

local function durations(c: any): { [string]: number }
	local mode = c.match.mode or "match"
	local fromPacing = c.pacing.modes and c.pacing.modes[mode]
	return fromPacing or (c.match.durations and c.match.durations[mode]) or {}
end

local function minutes(seconds: number?): string?
	if type(seconds) ~= "number" or seconds ~= seconds or seconds == math.huge or seconds <= 0 then
		return nil
	end
	local m = math.max(1, math.floor(seconds / 60 + 0.5))
	return `{m} min`
end

function HowToPlayModel.phases(cfg: any?): string
	local d = durations(defaults(cfg))
	local parts = {}
	for _, phase in HowToPlayModel.PHASES do
		local m = minutes(d[phase])
		table.insert(parts, if m then `{phase} {m}` else phase)
	end
	return table.concat(parts, ", ")
end

-- The arena's length: Pacing.arena (FORGE-04, one source per FORGE-00: config Arena's stage seconds plus the
-- expected duel), else config Arena's own stages (FORGE-01: vote, loadout, intro, the duel's safety clock, crowning).
HowToPlayModel.ARENA_STAGES =
	table.freeze({ "voteSeconds", "loadoutSeconds", "introSeconds", "duelMaxSeconds", "crowningSeconds" })

local function arenaMinutes(c: any): string
	local total = 0
	for _, s in c.pacing.arena or {} do
		total += s
	end
	if total <= 0 then
		for _, key in HowToPlayModel.ARENA_STAGES do
			local s = c.arena[key]
			if type(s) == "number" then
				total += s
			end
		end
	end
	return minutes(total) or "a few min"
end

local function percent(f: number): string
	return `{math.floor(f * 100 + 0.5)}%`
end

function HowToPlayModel.words(s: string): number
	local n = 0
	for _ in string.gmatch(s, "%S+") do
		n += 1
	end
	return n
end

function HowToPlayModel.cards(cfg: any?): { any }
	local c = defaults(cfg)
	local lock = (c.match.rulers and c.match.rulers.newcomerLockSeconds) or 120
	local caps = c.caps
	local voteSeconds = if type(c.arena.voteSeconds) == "number" then c.arena.voteSeconds else 10
	return {
		{
			id = "match",
			title = "The match",
			icon = "timer",
			picture = "timer",
			body = `Four kingdoms race through four phases: {HowToPlayModel.phases(c)}. The bar at the top shows the phase and the time left. Then the Crown Arena (about {arenaMinutes(
				c
			)}) decides the winner, and Results show how you ruled.`,
		},
		{
			id = "crown",
			title = "Crown Points",
			icon = "crest",
			picture = "laurel",
			body = "Earn Crown Points with buildings, objectives, enemy units defeated and rival keeps taken. Your total sits by your crest; the Kingdom menu shows every kingdom's standing. When Endgame ends, the two kingdoms with the most Crown Points meet in the Crown Arena.",
		},
		{
			id = "kingdom",
			title = "Build and lead",
			icon = "build",
			picture = "citizens",
			body = "Your citizens farm, gather and build. Set their jobs in the Kingdom menu, keep food ahead of hunger and build what your town needs. Answer citizens when they ask: every choice moves your six reputation values and how loyal they feel.",
		},
		{
			id = "war",
			title = "War, peace and sieges",
			icon = "army",
			picture = "gate",
			body = `War opens in Conflict. Your longest-seated ruler declares war or agrees peace; anyone may propose peace. Rulers who join mid-match wait {lock} seconds first. Rams break gates and damage keeps, so keep soldiers near home and answer a raid fast.`,
		},
		{
			id = "arena",
			title = "The Crown Arena",
			icon = "trigger_crowdRally",
			picture = "rep_courage",
			body = `The top two kingdoms send one champion each; co-rulers vote for theirs in {voteSeconds} seconds (a tie goes to the higher leadership). Pick a weapon, armour and perks from loyal citizens. Support gives a small blessing (at most +{percent(
				caps.passivePerStat
			)}) and up to {caps.maxTriggers} short perks, and never weakens you. Skill decides the duel, and nothing can be bought.`,
		},
		{
			id = "fall",
			title = "Falling and watching",
			icon = "keep",
			picture = "crest",
			body = "If your keep falls, your kingdom is out, but you are not: watch the rest of the match from any kingdom and see the duel at the end. Take every rival keep before Endgame ends and you win at once, with no duel.",
		},
	}
end

function HowToPlayModel.view(cards: { any }, index: number): any
	local count = #cards
	local i = math.clamp(math.floor(index), 1, math.max(1, count))
	local dots = {}
	for k = 1, count do
		dots[k] = k == i
	end
	return {
		card = cards[i],
		index = i,
		count = count,
		first = i == 1,
		last = i == count,
		step = `{i} of {count}`,
		dots = dots,
	}
end

return table.freeze(HowToPlayModel)
