--!strict
--[[
	UI/SpectateModel — what the spectate screen says (FL-0129, Operation Crownfall, D-053 (3): eliminated
	rulers spectate). Pure; no instances. UI/SpectateScreen draws it.

	Inputs
		info     FORGE-01's Match.Spectate info (FL-0125): { reason = "eliminated" | "match_full",
		         kingdomId?, by?, standing = { KingdomId } }, or nil when only the camera knows (FORGE-04's
		         RulerSpectateController turned on by itself after our fall)
		store    UI/KingdomStore (names, colours)
		targets  FORGE-04's RulerSpectateController:targets(): battles first, then standing keeps;
		         { kind = "battle" | "keep", position, kingdom?, kingdomName?, count? }
		current  the target the camera is on (targetChanged / select), or nil

		SpectateModel.view(info, store, targets, current) -> View
			View = { reason, title, subtitle, standing: string?, rows: { Row }, current: number? }
			Row  = { index, kind, label, detail: string?, color: Color3, emblem: string, selected }
		SpectateModel.same(a, b) -> boolean   two targets are the same place (kind, kingdom, position)
]]

local HudModel = require("./HudModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SpectateModel = {}

local function kingdomOf(store: any, id: any): any
	if type(id) ~= "string" then
		return nil
	end
	for _, k in store:kingdoms() do
		if k.id == id then
			return k
		end
	end
	return nil
end

local function nameOf(store: any, id: any): string?
	local k = kingdomOf(store, id)
	if k and type(k.name) == "string" then
		return k.name
	end
	return nil
end

function SpectateModel.same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	if a.kind ~= b.kind or a.kingdom ~= b.kingdom then
		return false
	end
	if typeof(a.position) == "Vector3" and typeof(b.position) == "Vector3" then
		return (a.position - b.position).Magnitude < 0.5
	end
	return a.position == b.position
end

local function row(store: any, target: any, index: number, current: any): any
	local kingdom = kingdomOf(store, target.kingdom)
	local name = if type(target.kingdomName) == "string" then target.kingdomName else nameOf(store, target.kingdom)
	local battle = target.kind == "battle"
	local count = if type(target.count) == "number" and target.count > 0 then target.count else nil
	return {
		index = index,
		kind = if battle then "battle" else "keep",
		label = if battle then `Battle · {name or "open field"}` else (name or "A keep"),
		detail = if battle then (if count then `{count} fighting` else "Fighting now") else "Keep",
		color = if kingdom then HudModel.color(kingdom) else Theme.color("textMuted"),
		emblem = if battle then "army" elseif kingdom then (HudModel.EMBLEMS[kingdom.id] or "crest") else "keep",
		selected = current ~= nil and SpectateModel.same(target, current),
	}
end

function SpectateModel.view(info: any, store: any, targets: { any }?, current: any): any
	local reason = if type(info) == "table" and info.reason == "match_full" then "match_full" else "eliminated"
	local title, subtitle
	if reason == "match_full" then
		title = "This match is full"
		subtitle = "Watch now. You can rule in the next match"
	else
		local fallen = if type(info) == "table" then nameOf(store, info.kingdomId) else nil
		local by = if type(info) == "table" then nameOf(store, info.by) else nil
		title = if fallen then `{fallen} has fallen` else "Your kingdom has fallen"
		subtitle = if by then `{by} took your keep` else "Your keep was taken"
	end
	local standing = nil
	if type(info) == "table" and type(info.standing) == "table" then
		local n = #info.standing
		standing = if n == 1 then "1 kingdom still stands" else `{n} kingdoms still stand`
	end
	local rows, at = {}, nil
	for i, target in targets or {} do
		if type(target) == "table" then
			local r = row(store, target, i, current)
			table.insert(rows, r)
			if r.selected then
				at = i
			end
		end
	end
	return {
		reason = reason,
		title = title,
		subtitle = subtitle,
		standing = standing,
		rows = rows,
		current = at,
	}
end

return table.freeze(SpectateModel)
