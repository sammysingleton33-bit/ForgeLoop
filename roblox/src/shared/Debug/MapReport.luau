--!strict
--[[
	Debug/MapReport — what the running server sees of the map contract (Config/Map), through
	CollectionService. Owned by FORGE-05.

	Main.server logs it at start, so a Studio run proves the map's tags and attributes survived the
	Rojo sync into a live DataModel (smoke test S4 in roblox/STUDIO_TEST_PLAN.md). The full headless
	map validation is roblox/scripts/check_place.luau; this is the light runtime counterpart.

		MapReport.summarize(env) -> Summary   -- pure: counts + problems, no logging
		MapReport.log(env) -> Summary          -- "map ready ..." (info) or "map problems ..." (warn)
]]

local Map = require("@game/ReplicatedStorage/Forge/Config/Map")

export type Summary = {
	ok: boolean,
	kingdoms: number,
	counts: { [string]: number }, -- by Map.TAGS key
	problems: { string },
}

local MapReport = {}

function MapReport.summarize(env: any): Summary
	local collection = env.CollectionService
	local problems: { string } = {}
	local counts: { [string]: number } = {}
	local tagged: { [string]: { any } } = {}
	for name, tag in Map.TAGS do
		tagged[name] = collection:GetTagged(tag)
		counts[name] = #tagged[name]
	end

	if counts.LobbySpawn ~= 1 then
		table.insert(problems, `{counts.LobbySpawn} {Map.TAGS.LobbySpawn} (expected 1)`)
	end
	if counts.PlayArea ~= 1 then
		table.insert(problems, `{counts.PlayArea} {Map.TAGS.PlayArea} (expected 1)`)
	end

	local kingdomSeen: { [string]: boolean } = {}
	for _, model in tagged.Kingdom do
		local id = model:GetAttribute(Map.ATTR.KingdomId)
		if type(id) == "string" then
			kingdomSeen[id] = true
		end
	end
	local kingdoms = 0
	for _, id in Map.KINGDOM_IDS do
		if kingdomSeen[id] then
			kingdoms += 1
		else
			table.insert(problems, `no {Map.TAGS.Kingdom} with KingdomId {id}`)
		end
	end

	for tagName, rule in Map.PER_KINGDOM do
		local perKingdom: { [string]: number } = {}
		for _, anchor in tagged[tagName] do
			local id = anchor:GetAttribute(Map.ATTR.KingdomId)
			if type(id) == "string" then
				perKingdom[id] = (perKingdom[id] or 0) + 1
			end
		end
		for _, id in Map.KINGDOM_IDS do
			local have = perKingdom[id] or 0
			local want: number = if type(rule) == "number" then rule else (rule :: any).min
			local bad = if type(rule) == "number" then have ~= want else have < want
			if bad then
				table.insert(problems, `kingdom {id}: {have} {Map.TAGS[tagName]} (expected {want})`)
			end
		end
	end

	return { ok = #problems == 0, kingdoms = kingdoms, counts = counts, problems = problems }
end

function MapReport.log(env: any): Summary
	local summary = MapReport.summarize(env)
	local fields = {
		version = Map.VERSION,
		kingdoms = summary.kingdoms,
		rulerSpawns = summary.counts.RulerSpawn,
		resourceNodes = summary.counts.ResourceNode,
		buildPlots = summary.counts.BuildPlot,
		lobbySpawn = summary.counts.LobbySpawn,
	}
	if summary.ok then
		env.log("info", "map ready", fields)
	else
		fields.problems = table.concat(summary.problems, "; ")
		env.log("warn", "map problems", fields)
	end
	return summary
end

return table.freeze(MapReport)
