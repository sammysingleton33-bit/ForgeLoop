--!strict
--[[
	UI/RecapModel — the leadership recap at the end of a match (FL-0129, BRIEF §2 "Results with the
	leadership recap"). Pure; no instances. UI/LeadershipRecap draws it.

	The server sends only the latest reputation (values + the latest 30 history entries) and today's
	population, so the client keeps what it saw during the match:
		RecapModel.new() -> Track
		RecapModel.observe(track, match, rep, population)
			match       KingdomStore.match ({ phase, startedAt })
			rep         UI/ReputationModel Data ({ known, values, history (newest first) }) or nil
			population  KingdomStore:population() ({ total }) or nil
			A new match (another startedAt, or Founding after Results/Lobby) starts the track over. The first
			values and citizen count seen in an active phase are the start; the latest are the end; every
			history entry seen is kept once (keyed by t, category and text), so decisions older than the
			latest 30 still count.
		RecapModel.build(track) -> Recap?   nil until reputation was seen this match
			Recap = { values: { { id, name, icon, color, start, finish, delta, deltaText } } (six, fixed
			          order), decisions: { { text, name, icon, color, delta, deltaText, positive } } (the
			          RecapModel.DECISIONS with the biggest effect, biggest first), citizens: { start, finish,
			          change, text }? }
]]

local ReputationText = require("./ReputationText")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local RecapModel = {}

RecapModel.ORDER = table.freeze({ "compassion", "honor", "competence", "courage", "authority", "fear" })
RecapModel.DECISIONS = 3
local ACTIVE = table.freeze({ Founding = true, Expansion = true, Conflict = true, Endgame = true })

function RecapModel.new(): any
	return { key = nil, start = nil, finish = nil, citizens = nil, entries = {}, seen = {} }
end

local function signed(n: number): string
	local rounded = math.floor(n + 0.5)
	if rounded > 0 then
		return `+{rounded}`
	end
	return tostring(rounded)
end

local function reset(track: any, key: any)
	track.key = key
	track.start = nil
	track.finish = nil
	track.citizens = nil
	track.entries = {}
	track.seen = {}
end

function RecapModel.observe(track: any, match: any, rep: any, population: any)
	local phase = if type(match) == "table" then match.phase else nil
	local key = if type(match) == "table" then match.startedAt else nil
	if phase == "Lobby" then
		-- the next Founding is a new match even if the server reuses startedAt
		track.lobby = true
		return
	end
	if key ~= track.key or (track.lobby and phase == "Founding") then
		reset(track, key)
		track.lobby = false
		-- history already on screen belongs to the last match (the client's copy can lag the server's new
		-- round): it is marked seen, never counted for this one
		for _, e in if type(rep) == "table" and type(rep.history) == "table" then rep.history else {} do
			if type(e) == "table" then
				track.seen[`{e.t}|{e.category}|{e.text}`] = true
			end
		end
	end
	local active = phase ~= nil and ACTIVE[phase] == true
	if type(rep) == "table" and rep.known and type(rep.values) == "table" then
		if track.start == nil and active then
			track.start = table.clone(rep.values)
		end
		if track.start ~= nil then
			track.finish = table.clone(rep.values)
		end
		for _, e in if type(rep.history) == "table" then rep.history else {} do
			if type(e) == "table" and type(e.delta) == "number" then
				local id = `{e.t}|{e.category}|{e.text}`
				if not track.seen[id] then
					track.seen[id] = true
					table.insert(track.entries, e)
				end
			end
		end
	end
	local total = if type(population) == "table" and type(population.total) == "number" then population.total else nil
	if total ~= nil then
		if track.citizens == nil and active then
			track.citizens = { start = total, finish = total }
		elseif track.citizens ~= nil then
			track.citizens.finish = total
		end
	end
end

local function category(id: string): any
	return ReputationText.CATEGORIES[id]
end

function RecapModel.build(track: any): any
	if track.start == nil or track.finish == nil then
		return nil
	end
	local values = {}
	for _, id in RecapModel.ORDER do
		local c = category(id)
		local s = track.start[id]
		local f = track.finish[id]
		if c and type(s) == "number" and type(f) == "number" then
			table.insert(values, {
				id = id,
				name = c.name,
				icon = c.icon,
				color = Theme.color(c.color),
				start = math.floor(s + 0.5),
				finish = math.floor(f + 0.5),
				delta = f - s,
				deltaText = signed(f - s),
			})
		end
	end
	local decisions = {}
	for _, e in track.entries do
		local c = category(e.category)
		if c and type(e.text) == "string" and e.text ~= "" and e.delta ~= 0 then
			table.insert(decisions, {
				text = e.text,
				name = c.name,
				icon = c.icon,
				color = Theme.color(c.color),
				delta = e.delta,
				deltaText = signed(e.delta),
				positive = e.delta > 0,
				t = e.t,
			})
		end
	end
	table.sort(decisions, function(a, b)
		if math.abs(a.delta) ~= math.abs(b.delta) then
			return math.abs(a.delta) > math.abs(b.delta)
		end
		return (a.t or 0) < (b.t or 0)
	end)
	while #decisions > RecapModel.DECISIONS do
		table.remove(decisions)
	end
	local citizens = nil
	if track.citizens then
		local change = track.citizens.finish - track.citizens.start
		citizens = {
			start = track.citizens.start,
			finish = track.citizens.finish,
			change = change,
			text = if change > 0
				then `{change} more citizens than at the start`
				elseif change < 0 then `{-change} fewer citizens than at the start`
				else "As many citizens as at the start",
		}
	end
	return { values = values, decisions = decisions, citizens = citizens }
end

return table.freeze(RecapModel)
