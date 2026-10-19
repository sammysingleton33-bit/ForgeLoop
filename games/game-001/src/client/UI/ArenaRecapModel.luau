--!strict
--[[
	UI/ArenaRecapModel — the arena and support half of the leadership recap at Results (FL-0073; design crown-arena.md
	§7 "Emotional payoff", §8 "Leadership recap: the five moments that most raised or lowered support, the perks that
	fired, and how the crowd reacted"). Pure; no instances. UI/LeadershipRecap draws it on its "Arena & support" page.

	The server sends only the latest SupportView (moments are its latest few) and the live ArenaState, so the client
	keeps what it saw during the match:
		ArenaRecapModel.new() -> Track
		ArenaRecapModel.observe(track, matchKey, support, arena, duel, mine)
			matchKey  KingdomStore.match.startedAt (a new key starts the track over)
			support   SupportView? (ArenaHudController.support): every moment seen is kept once (t, act, text)
			arena     ArenaState? (ArenaHudController.state)   duel  ArenaHudModel Track? (ArenaHudController.track)
			mine      my KingdomId?
			"none" when no duellist pair was ever announced (the match ended by conquest or Crown Points), "absent" when
			the arena was held without my kingdom.
			While my kingdom has a duellist (a or b): that side, its tier and its chosen triggers are kept (from the
			loadout on, as sent, an emptied list included), and the
			triggers the duel reports fired. The result is kept from `duel.ended.winner` ("a" | "b" | "draw") or, failing
			that, ArenaState.winner (a userId) at stage crowning / done.
		ArenaRecapModel.build(track) -> Recap?   nil until a SupportView or my kingdom's duel was seen this match
			Recap = {
				moments: { { text, component, delta, deltaText, positive } }  the MOMENTS with the biggest |delta|,
				         biggest first (ties: the later first); noMoments: string? when there are none
				perks: { { id, name, icon, fired: boolean } }   my champion's chosen triggers, in pick order
				perksText: string   "2 of 3 perks fired" | "No perks were chosen" | "Your kingdom had no champion"
				crowd: { id: "crowned" | "quiet" | "saluted" | "emptied" | "draw" | "absent" | "none" | "pending", title, text,
				         tone: "up" | "down" | "neutral" }
				tier: { name, color }?   my champion's support tier at the duel
			}
		Moments are "the biggest of what the client saw": deduped on (t, act, text), so two identical moments at the same
		second count once, and a burst of more moments than one SupportView carries between two pushes is not all seen
		(FORGE-07 L3 on #229; a server moment id would make both exact).
		The crowd lines follow design §7 (win/loss × high/low support; high = Adoring or Loyal). They describe what the
		crowd does in FORGE-04's arena; the words are UI labels, not content.
]]

local ArenaText = require("./ArenaText")
local SupportMeterModel = require("./SupportMeterModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaRecapModel = {}

ArenaRecapModel.MOMENTS = 5
ArenaRecapModel.HIGH = table.freeze({ adoring = true, loyal = true })

ArenaRecapModel.CROWD = table.freeze({
	crowned = table.freeze({
		title = "Crowned by your people",
		text = "Your stand flooded the arena and crowned you.",
		tone = "up",
	}),
	quiet = table.freeze({
		title = "A quiet crowning",
		text = "You won, but few came down to cheer.",
		tone = "neutral",
	}),
	saluted = table.freeze({
		title = "Saluted in defeat",
		text = "Your stand still rose for you: “They fought for us.”",
		tone = "neutral",
	}),
	emptied = table.freeze({
		title = "The stand emptied",
		text = "Your people left before the end.",
		tone = "down",
	}),
	draw = table.freeze({
		title = "No victor",
		text = "The duel ended without a winner; the crowds went home.",
		tone = "neutral",
	}),
	none = table.freeze({
		title = "No arena this match",
		text = "The match was decided before the Crown Arena, by conquest or by Crown Points.",
		tone = "neutral",
	}),
	absent = table.freeze({
		title = "Not in the arena",
		text = "Your kingdom sent no champion this match.",
		tone = "neutral",
	}),
	pending = table.freeze({
		title = "The duel did not finish",
		text = "The match ended before the duel was decided.",
		tone = "neutral",
	}),
})

local function reset(track: any, key: any)
	track.key = key
	track.seen = {}
	track.moments = {}
	track.supportSeen = false
	track.pairSeen = false -- a duellist pair was announced (ArenaState a or b): the arena was held this match
	track.side = nil
	track.tier = nil
	track.triggers = {}
	track.fired = {}
	track.result = nil
	track.userIds = {}
end

function ArenaRecapModel.new(): any
	local track = {}
	reset(track, nil)
	return track
end

function ArenaRecapModel.observe(track: any, matchKey: any, support: any, arena: any, duel: any, mine: string?)
	if matchKey ~= track.key then
		reset(track, matchKey)
	end
	if type(support) == "table" then
		track.supportSeen = true
		for _, m in if type(support.moments) == "table" then support.moments else {} do
			if type(m) == "table" and type(m.text) == "string" and m.text ~= "" and type(m.delta) == "number" then
				local id = `{m.t}|{m.act}|{m.text}`
				if not track.seen[id] then
					track.seen[id] = true
					table.insert(track.moments, m)
				end
			end
		end
	end
	if type(arena) ~= "table" or mine == nil then
		return
	end
	local stage = arena.stage
	-- the champion's picks as sent from the loadout on (an emptied list included; FORGE-07 L1 on #229)
	local picked = stage == "loadout" or stage == "intro" or stage == "duel" or stage == "crowning" or stage == "done"
	for _, id in { "a", "b" } do
		local d = arena[id]
		if type(d) == "table" then
			track.pairSeen = true
			track.userIds[id] = d.userId
			if d.kingdom == mine then
				track.side = id
				track.tier = if type(d.tier) == "string" then d.tier else track.tier
				if type(d.triggers) == "table" and (picked or #d.triggers > 0) then
					track.triggers = table.clone(d.triggers)
				end
			end
		end
	end
	local side = track.side
	if side and type(duel) == "table" and type(duel[side]) == "table" and type(duel[side].fired) == "table" then
		for id in duel[side].fired do
			track.fired[id] = true
		end
	end
	if type(duel) == "table" and type(duel.ended) == "table" then
		local w = duel.ended.winner
		if w == "a" or w == "b" or w == "draw" then
			track.result = w
		end
	end
	if
		track.result == nil
		and (arena.stage == "crowning" or arena.stage == "done")
		and type(arena.winner) == "number"
	then
		for id, userId in track.userIds do
			if userId == arena.winner then
				track.result = id
			end
		end
	end
end

local function signed(n: number): string
	local r = if n < 0 then -math.floor(-n + 0.5) else math.floor(n + 0.5)
	return if r > 0 then `+{r}` elseif r < 0 then `−{-r}` else "0"
end

local function crowdId(track: any): string
	if not track.pairSeen then
		return "none" -- no duel was announced: the match ended by conquest or Crown Points (FORGE-07 M1 on #229)
	elseif track.side == nil then
		return "absent"
	elseif track.result == nil then
		return "pending"
	elseif track.result == "draw" then
		return "draw"
	end
	local won = track.result == track.side
	local high = ArenaRecapModel.HIGH[track.tier or ""] == true
	if won then
		return if high then "crowned" else "quiet"
	end
	return if high then "saluted" else "emptied"
end

function ArenaRecapModel.build(track: any): any
	if not track.supportSeen and track.side == nil then
		return nil
	end
	local list = table.clone(track.moments)
	table.sort(list, function(a, b)
		local da, db = math.abs(a.delta), math.abs(b.delta)
		if da ~= db then
			return da > db
		end
		return (a.t or 0) > (b.t or 0)
	end)
	local moments = {}
	for _, m in list do
		if #moments >= ArenaRecapModel.MOMENTS then
			break
		end
		if m.delta ~= 0 then
			local info = SupportMeterModel.COMPONENTS[m.component]
			table.insert(moments, {
				text = m.text,
				component = if info then info.name else tostring(m.component or ""),
				delta = m.delta,
				deltaText = signed(m.delta),
				positive = m.delta > 0,
			})
		end
	end
	local perks, firedCount = {}, 0
	for _, id in track.triggers do
		local info = ArenaText.trigger(id)
		local fired = track.fired[id] == true
		if fired then
			firedCount += 1
		end
		table.insert(perks, { id = id, name = info.name, icon = info.icon, fired = fired })
	end
	local perksText = if not track.pairSeen
		then "No duel this match"
		elseif track.side == nil then "Your kingdom had no champion"
		elseif #perks == 0 then "No perks were chosen"
		else `{firedCount} of {#perks} perk{if #perks == 1 then "" else "s"} fired`
	local id = crowdId(track)
	local crowd = ArenaRecapModel.CROWD[id]
	local tierInfo = if track.tier then ArenaText.tier(track.tier) else nil
	return {
		moments = moments,
		noMoments = if #moments == 0 then "No moments moved your support" else nil,
		perks = perks,
		perksText = perksText,
		crowd = { id = id, title = crowd.title, text = crowd.text, tone = crowd.tone },
		tier = if tierInfo then { name = tierInfo.name, color = Theme.color(tierInfo.color) } else nil,
	}
end

return table.freeze(ArenaRecapModel)
