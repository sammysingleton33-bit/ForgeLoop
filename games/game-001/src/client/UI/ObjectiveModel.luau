--!strict
--[[
	UI/ObjectiveModel — the HUD objective tracker as data (FL-0060; pure, no instances). It only
	formats what ObjectiveService:list() sent (CONTRACTS G8, `Army.Objectives` / `Army.GetObjectives`);
	who owns an objective and how far a capture is, is the server's call.

	ObjectiveModel.normalize(list) -> { Objective }?     nil when `list` is not a table (a malformed
		push: keep what the server said before). Bad entries are dropped, never an error:
		Objective = { id: string, owner: KingdomId?, progress: { [KingdomId]: number (0..1) },
		              contested: boolean }    (`contested` is optional, read when the server sends it)
	ObjectiveModel.identity(store, kingdomId) -> { id, name, color, emblem, ai, mine }
		names, colours and AI flags from Kingdom.State; an unknown id gets its own name and tincture
	ObjectiveModel.row(objective, number?, store, maxBars?) -> Row
		Row = { id, number?, name, owner = { text, color?, mine, neutral }, bars: { Bar },
		        hidden (bars left out), status?, contested, height }
		Bar = { kingdom, label ("You" for mine), color, progress, text ("64%"), mine }
		Bars: every kingdom with progress > 0, except an owner holding it fully; mine first, then
		by progress. Colour is never the only signal: each bar has a name and a percentage.
	ObjectiveModel.focus(objectives, mineId?) -> index?   the one the collapsed tracker shows: one I am
		capturing, else one I don't hold, else the first
	ObjectiveModel.tracker(objectives, store, { expanded, maxHeight? }) -> Tracker
		Tracker = { visible, expanded, title?, rows: { Row & { y } }, more?, height, contentHeight, scroll }
		collapsed: the focus objective with at most COLLAPSED_BARS bars and "+N more"; expanded: all
	ObjectiveModel.allMine(objectives, mineId?) -> boolean   every objective is mine (and there is one)
	ObjectiveModel.target(objectives, store) -> { name, text }?   the army drawer's target line
	Geometry (logical px): PAD, HEAD, LINE, GAP, ROW_GAP, TITLE, MORE, MIN_HEIGHT (a 44 px touch target).
]]

local ArmyText = require("./ArmyText")
local HudModel = require("./HudModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ObjectiveModel = {}

ObjectiveModel.PAD = 6
ObjectiveModel.HEAD = 20
ObjectiveModel.LINE = 14
ObjectiveModel.GAP = 4
ObjectiveModel.ROW_GAP = 9
ObjectiveModel.TITLE = 16
ObjectiveModel.MORE = 12
ObjectiveModel.MIN_HEIGHT = 44
ObjectiveModel.COLLAPSED_BARS = 2
ObjectiveModel.MAX_OBJECTIVES = 16

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function ObjectiveModel.normalize(list: any): { any }?
	if type(list) ~= "table" then
		return nil
	end
	local out = {}
	for _, o in list do
		if #out >= ObjectiveModel.MAX_OBJECTIVES then
			break
		end
		if type(o) == "table" and type(o.id) == "string" and #o.id > 0 and #o.id <= 64 then
			local progress = {}
			if type(o.progress) == "table" then
				for kingdom, value in o.progress do
					if type(kingdom) == "string" and finite(value) then
						progress[kingdom] = math.clamp(value, 0, 1)
					end
				end
			end
			table.insert(out, {
				id = o.id,
				owner = if type(o.owner) == "string" then o.owner else nil,
				progress = progress,
				contested = o.contested == true,
			})
		end
	end
	return out
end

local function mineId(store: any): string?
	local mine = store:mine()
	return if mine then mine.id else nil
end

function ObjectiveModel.identity(store: any, kingdomId: string): { [string]: any }
	local kingdom = nil
	for _, k in store:kingdoms() do
		if k.id == kingdomId then
			kingdom = k
		end
	end
	return {
		id = kingdomId,
		name = if kingdom and type(kingdom.name) == "string" then kingdom.name else ArmyText.objectiveName(kingdomId),
		color = if kingdom then HudModel.color(kingdom) else Theme.tincture(kingdomId),
		emblem = HudModel.EMBLEMS[kingdomId] or "crest",
		ai = kingdom ~= nil and kingdom.isAI == true,
		mine = kingdomId == mineId(store),
	}
end

local function percent(progress: number): string
	return `{if progress > 0 then math.max(1, math.floor(progress * 100)) else 0}%`
end

local function bars(o: any, mine: string?): { any }
	local out = {}
	for kingdom, value in o.progress do
		if value > 0 and not (kingdom == o.owner and value >= 1) then
			table.insert(out, { kingdom = kingdom, progress = value, mine = kingdom == mine })
		end
	end
	table.sort(out, function(a, b)
		if a.mine ~= b.mine then
			return a.mine
		elseif a.progress ~= b.progress then
			return a.progress > b.progress
		end
		return a.kingdom < b.kingdom
	end)
	return out
end

function ObjectiveModel.rowHeight(lines: number): number
	local n = math.max(1, lines)
	return ObjectiveModel.HEAD + ObjectiveModel.GAP + n * ObjectiveModel.LINE + (n - 1) * ObjectiveModel.GAP
end

function ObjectiveModel.row(o: any, number: number?, store: any, maxBars: number?): { [string]: any }
	local mine = mineId(store)
	local all = bars(o, mine)
	local shown = {}
	for i, b in all do
		if maxBars == nil or i <= maxBars then
			local who = ObjectiveModel.identity(store, b.kingdom)
			table.insert(shown, {
				kingdom = b.kingdom,
				label = if b.mine then ArmyText.YOU else who.name,
				color = who.color,
				progress = b.progress,
				text = percent(b.progress),
				mine = b.mine,
			})
		end
	end
	local owner
	if o.owner == nil then
		owner = { text = ArmyText.NEUTRAL, neutral = true, mine = false }
	else
		local who = ObjectiveModel.identity(store, o.owner)
		owner = {
			text = if who.mine then ArmyText.YOURS else who.name,
			color = who.color,
			mine = who.mine,
			neutral = false,
		}
	end
	local status = nil
	if #shown == 0 then
		status = if o.owner == nil
			then ArmyText.STATUS_NEUTRAL
			elseif owner.mine then ArmyText.STATUS_MINE
			else ArmyText.STATUS_FOREIGN
	end
	local lines = math.max(1, #shown) + (if o.contested then 1 else 0)
	return {
		id = o.id,
		number = number,
		name = ArmyText.objectiveName(o.id),
		owner = owner,
		bars = shown,
		hidden = #all - #shown,
		status = status,
		contested = o.contested == true,
		height = ObjectiveModel.rowHeight(lines),
	}
end

local function mineProgress(o: any, mine: string?): number
	return if mine then o.progress[mine] or 0 else 0
end

function ObjectiveModel.focus(objectives: { any }, mine: string?): number?
	if #objectives == 0 then
		return nil
	end
	local best, bestRank = 1, math.huge
	for i, o in objectives do
		local rank = if o.owner ~= mine and mineProgress(o, mine) > 0 then 1 elseif o.owner ~= mine then 2 else 3
		if rank < bestRank then
			best, bestRank = i, rank
		end
	end
	return best
end

function ObjectiveModel.allMine(objectives: { any }, mine: string?): boolean
	if mine == nil or #objectives == 0 then
		return false
	end
	for _, o in objectives do
		if o.owner ~= mine then
			return false
		end
	end
	return true
end

function ObjectiveModel.tracker(
	objectives: { any }?,
	store: any,
	opts: { expanded: boolean?, maxHeight: number? }?
): { [string]: any }
	local list = objectives or {}
	local expanded = opts ~= nil and opts.expanded == true
	local P = ObjectiveModel
	if #list == 0 then
		return { visible = false, expanded = expanded, rows = {}, height = 0, contentHeight = 0, scroll = false }
	end
	local numbered = #list > 1
	local rows = {}
	local more = 0
	local y = P.PAD
	local title = nil
	if expanded then
		title = { text = ArmyText.OBJECTIVES, hint = `{#list} · {ArmyText.TAP_TO_CLOSE}` }
		y += P.TITLE + P.GAP + 2
		for i, o in list do
			local row = ObjectiveModel.row(o, if numbered then i else nil, store, nil)
			row.y = y
			y += row.height + P.ROW_GAP
			table.insert(rows, row)
		end
		y -= P.ROW_GAP
	else
		local index = ObjectiveModel.focus(list, mineId(store)) :: number
		local row = ObjectiveModel.row(list[index], if numbered then index else nil, store, P.COLLAPSED_BARS)
		row.y = y
		y += row.height
		table.insert(rows, row)
		more = (#list - 1) + row.hidden
		if more > 0 then
			y += P.GAP + P.MORE
		end
	end
	local content = math.max(P.MIN_HEIGHT, y + P.PAD)
	local maxHeight = if opts and opts.maxHeight then math.max(P.MIN_HEIGHT, opts.maxHeight) else math.huge
	return {
		visible = true,
		expanded = expanded,
		title = title,
		rows = rows,
		more = if more > 0 then `+{more} more` else nil,
		height = math.min(content, maxHeight),
		contentHeight = content,
		scroll = content > maxHeight,
	}
end

function ObjectiveModel.target(objectives: { any }?, store: any): { name: string, text: string }?
	local list = objectives or {}
	local mine = mineId(store)
	local index = ObjectiveModel.focus(list, mine)
	if index == nil then
		return nil
	end
	local o = list[index]
	local row = ObjectiveModel.row(o, nil, store, nil)
	local text = row.owner.text
	local mineValue = mineProgress(o, mine)
	if o.owner ~= mine and mineValue > 0 then
		text ..= ` · {string.lower(ArmyText.YOU)} {percent(mineValue)}`
	end
	return { name = row.name, text = text }
end

return table.freeze(ObjectiveModel)
