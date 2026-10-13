--!strict
--[[
	UI/ReputationModel — what the reputation strip and screen show, as data (pure, no instances).

	Input: the CONTRACTS G13.4 payload of `Kingdom.GetReputation` (and, assumed, of the
	`Kingdom.Reputation` push — handoff 2026-10-12-forge-03-to-forge-01-reputation-ui):
		{ values: { [Category]: number }, history: { { t, category, delta, text, source } } (latest 30),
		  kingdom: { happiness, stability, morale } }
	`t` is read as serverTimeNow seconds (workspace:GetServerTimeNow(), the clock of G3 `endsAt`).
	Payloads are checked loosely: a malformed field is dropped, never thrown on (a bad push must
	never break the HUD). The client decides nothing; it shows what the server sent.

		ReputationModel.empty() -> Data            nothing known yet (before the first reply)
		ReputationModel.normalize(payload?) -> Data
			Data = { known: boolean, values: { [id]: number }, history: { Entry } (newest first),
			         kingdom: { [conditionId]: number } }
			Entry = { t, category, delta, text, source?, order (position in the payload) }
		ReputationModel.value(v) -> number?        clamped 0..100 and rounded; nil if not a number
		ReputationModel.signed(delta) -> string    "+4", "−5" (true minus), "+1.5", "0"
		ReputationModel.ago(t, now) -> string      "just now" (< 10 s, or a time in the future),
		                                           "45 s ago", "2 min ago", "3 h ago"
		ReputationModel.band(v) -> string          "Low" (< 34) | "Medium" (< 67) | "High"
		                                           (presentation words, not game thresholds)
		ReputationModel.deltas(before?, after) -> { [id]: number }   per category, changed values only
		ReputationModel.strip(data, provider?) -> { Item }    six, in display order
			Item = { id, name, icon, color, value: number?, label: string ("62"; "…" while unknown) }
		ReputationModel.categories(data, now, provider?) -> { Row }   six, in display order
			Row = Item + { band: string?, description: string?, affects: string?, recent: { HistoryRow } }
		ReputationModel.history(data, now, limit?) -> { HistoryRow }   newest first
			HistoryRow = { t, category, name, icon, color, delta, deltaText, positive: boolean,
			               text, ago }
		ReputationModel.conditions(data) -> { { id, name, icon, value: number?, label, band: string? } }
]]

local ReputationText = require("./ReputationText")

local ReputationModel = {}

ReputationModel.MAX = 100
ReputationModel.RECENT = 3 -- changes listed under a category in its detail
ReputationModel.HISTORY_LIMIT = 30 -- rows on the History tab (the contract shows the latest 30; R44-2)

export type Entry = { t: number, category: string, delta: number, text: string, source: string?, order: number }
export type Data = {
	known: boolean,
	values: { [string]: number },
	history: { Entry },
	kingdom: { [string]: number },
}

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function ReputationModel.value(v: any): number?
	if not isNumber(v) then
		return nil
	end
	return math.floor(math.clamp(v, 0, ReputationModel.MAX) + 0.5)
end

function ReputationModel.signed(delta: number): string
	local a = math.floor(math.abs(delta) * 10 + 0.5) / 10
	if a == 0 then
		return "0"
	end
	local text = if a == math.floor(a) then tostring(math.floor(a)) else string.format("%.1f", a)
	return (if delta > 0 then "+" else "−") .. text
end

function ReputationModel.ago(t: number, now: number): string
	local s = now - t
	if s < 10 then
		return "just now"
	elseif s < 60 then
		return `{math.floor(s)} s ago`
	elseif s < 3600 then
		return `{math.floor(s / 60)} min ago`
	end
	return `{math.floor(s / 3600)} h ago`
end

function ReputationModel.band(v: number): string
	if v < 34 then
		return "Low"
	elseif v < 67 then
		return "Medium"
	end
	return "High"
end

function ReputationModel.empty(): Data
	return { known = false, values = {}, history = {}, kingdom = {} }
end

function ReputationModel.normalize(payload: any): Data
	local data = ReputationModel.empty()
	if type(payload) ~= "table" then
		return data
	end
	data.known = true
	if type(payload.values) == "table" then
		for _, id in ReputationText.IDS do
			local v = ReputationModel.value(payload.values[id])
			if v ~= nil then
				data.values[id] = v
			end
		end
	end
	if type(payload.kingdom) == "table" then
		for _, c in ReputationText.CONDITIONS do
			local v = ReputationModel.value(payload.kingdom[c.id])
			if v ~= nil then
				data.kingdom[c.id] = v
			end
		end
	end
	if type(payload.history) == "table" then
		for i, e in payload.history do
			if
				type(i) == "number"
				and type(e) == "table"
				and isNumber(e.t)
				and isNumber(e.delta)
				and ReputationText.isCategory(e.category)
			then
				table.insert(data.history, {
					t = e.t,
					category = e.category,
					delta = e.delta,
					text = if type(e.text) == "string" then e.text else "",
					source = if type(e.source) == "string" then e.source else nil,
					order = i,
				})
			end
		end
		-- Newest first. Equal times (one decision touching several categories): the later list
		-- position first, as the server appends in order.
		table.sort(data.history, function(a, b)
			if a.t ~= b.t then
				return a.t > b.t
			end
			return a.order > b.order
		end)
	end
	return data
end

function ReputationModel.deltas(before: Data?, after: Data): { [string]: number }
	local out = {}
	if before == nil or not before.known then
		return out
	end
	for _, id in ReputationText.IDS do
		local a, b = before.values[id], after.values[id]
		if a ~= nil and b ~= nil and a ~= b then
			out[id] = b - a
		end
	end
	return out
end

local function item(data: Data, id: string, provider: ReputationText.Provider?): { [string]: any }
	local c = ReputationText.CATEGORIES[id]
	local text = if provider then provider(id) else nil
	local value = data.values[id]
	return {
		id = id,
		name = if text and text.name then text.name else c.name,
		icon = c.icon,
		color = c.color,
		value = value,
		label = if value ~= nil then tostring(value) else "…",
	}
end

function ReputationModel.strip(data: Data, provider: ReputationText.Provider?): { { [string]: any } }
	local out = {}
	for _, id in ReputationText.IDS do
		table.insert(out, item(data, id, provider))
	end
	return out
end

local function historyRow(e: Entry, now: number): { [string]: any }
	local c = ReputationText.CATEGORIES[e.category]
	return {
		t = e.t,
		category = e.category,
		name = c.name,
		icon = c.icon,
		color = c.color,
		delta = e.delta,
		deltaText = ReputationModel.signed(e.delta),
		positive = e.delta >= 0,
		text = e.text,
		ago = ReputationModel.ago(e.t, now),
	}
end

function ReputationModel.history(data: Data, now: number, limit: number?): { { [string]: any } }
	local out = {}
	for _, e in data.history do
		if limit and #out >= limit then
			break
		end
		table.insert(out, historyRow(e, now))
	end
	return out
end

function ReputationModel.categories(data: Data, now: number, provider: ReputationText.Provider?): { { [string]: any } }
	local out = {}
	for _, id in ReputationText.IDS do
		local row = item(data, id, provider)
		local text = if provider then provider(id) else nil
		row.description = if text then text.description else nil
		row.affects = if text then text.affects else nil
		row.band = if row.value ~= nil then ReputationModel.band(row.value) else nil
		row.recent = {}
		for _, e in data.history do
			if e.category == id then
				table.insert(row.recent, historyRow(e, now))
				if #row.recent >= ReputationModel.RECENT then
					break
				end
			end
		end
		table.insert(out, row)
	end
	return out
end

function ReputationModel.conditions(data: Data): { { [string]: any } }
	local out = {}
	for _, c in ReputationText.CONDITIONS do
		local value = data.kingdom[c.id]
		table.insert(out, {
			id = c.id,
			name = c.name,
			icon = c.icon,
			value = value,
			label = if value ~= nil then tostring(value) else "…",
			band = if value ~= nil then ReputationModel.band(value) else nil,
		})
	end
	return out
end

return table.freeze(ReputationModel)
