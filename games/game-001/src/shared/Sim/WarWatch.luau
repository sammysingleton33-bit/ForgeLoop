--!strict
--[[
	Sim/WarWatch — when a kingdom is besieged or raided, and when that stops (FL-0134, G9 SiegeChanged / RaidChanged).

	The simulation emits one event per start and one per end, so every listener (the host's G9 events, announcer,
	conversations) hears each moment exactly once:
		SiegeChanged { kingdomId, on, byKingdomIds, buildingId }
			start: the first enemy damage to that kingdom's keep after a quiet spell; end: no keep damage for
			siegeQuietSeconds (20 s).
		RaidChanged { kingdomId, on, byKingdomIds, count, position = { x, z } }
			start: `kingdom.threats` goes from empty to non-empty; end: empty for raidQuietSeconds (10 s).
			`position` is the threats' centroid when it starts (and on the end event, where they were last seen).
	A kingdom that falls ends nothing (KingdomEliminated says it); its watch state is dropped without an event.
	Military calls keepHit for every enemy hit on a building; the system runs after the citizens, once per tick.
]]

local WarWatch = {}

-- seconds of quiet that end a siege / a raid; `catalog.tuning.alerts` may override them (specs do)
local DEFAULTS = { siegeQuietSeconds = 20, raidQuietSeconds = 10 }

local function setting(sim: any, key: string): number
	local alerts = sim.catalog.tuning.alerts
	local value = if alerts then alerts[key] else nil
	return if type(value) == "number" then value else DEFAULTS[key]
end

local function watchOf(sim: any, kingdomId: string): any
	local watch = sim.warWatch
	if watch == nil then
		watch = {}
		sim.warWatch = watch
	end
	local state = watch[kingdomId]
	if state == nil then
		state = { siege = nil, raid = nil }
		watch[kingdomId] = state
	end
	return state
end

local function sortedKeys(set: { [string]: boolean }): { string }
	local out = {}
	for id in set do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

-- An enemy unit of `attackerId` damaged building `building` (any building; only a keep is a siege).
function WarWatch.keepHit(sim: any, building: any, attackerId: string)
	if building.kind ~= "keep" or building.kingdomId == attackerId then
		return
	end
	local state = watchOf(sim, building.kingdomId)
	local siege = state.siege
	if siege == nil then
		siege = { by = {} :: { [string]: boolean }, buildingId = building.id, lastHit = sim.time }
		state.siege = siege
		siege.by[attackerId] = true
		sim:emit("SiegeChanged", {
			kingdomId = building.kingdomId,
			on = true,
			byKingdomIds = sortedKeys(siege.by),
			buildingId = building.id,
		})
		return
	end
	siege.lastHit = sim.time
	siege.by[attackerId] = true
end

local function centroid(sim: any, threats: { any }): { x: number, z: number }
	local x, z = 0, 0
	for _, t in threats do
		x += t.x
		z += t.z
	end
	return { x = x / #threats, z = z / #threats }
end

local function attackers(sim: any, threats: { any }): { string }
	local set = {}
	for _, t in threats do
		local u = sim.units[t.id]
		if u then
			set[u.kingdomId] = true
		end
	end
	return sortedKeys(set)
end

local function step(sim: any)
	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		local state = if sim.warWatch then sim.warWatch[kid] else nil
		if not kingdom.alive then
			if state then
				sim.warWatch[kid] = nil -- a fallen kingdom ends nothing (KingdomEliminated says it)
			end
			continue
		end
		-- siege end: the keep has not been hit for a while
		if state and state.siege and sim.time - state.siege.lastHit >= setting(sim, "siegeQuietSeconds") then
			local siege = state.siege
			state.siege = nil
			sim:emit("SiegeChanged", {
				kingdomId = kid,
				on = false,
				byKingdomIds = sortedKeys(siege.by),
				buildingId = siege.buildingId,
			})
		end
		-- raid start / end from the threats Military refreshed this tick
		local threats = kingdom.threats
		if #threats > 0 then
			state = watchOf(sim, kid)
			local raid = state.raid
			if raid == nil then
				raid = { lastSeen = sim.time, position = centroid(sim, threats), by = attackers(sim, threats) }
				state.raid = raid
				sim:emit("RaidChanged", {
					kingdomId = kid,
					on = true,
					byKingdomIds = raid.by,
					count = #threats,
					position = raid.position,
				})
			else
				raid.lastSeen = sim.time
				raid.position = centroid(sim, threats)
				raid.by = attackers(sim, threats)
				raid.count = #threats
			end
		elseif state and state.raid and sim.time - state.raid.lastSeen >= setting(sim, "raidQuietSeconds") then
			local raid = state.raid
			state.raid = nil
			sim:emit("RaidChanged", {
				kingdomId = kid,
				on = false,
				byKingdomIds = raid.by,
				count = raid.count or 0,
				position = raid.position,
			})
		end
	end
end

function WarWatch.install(sim: any)
	sim:addSystem({
		afterCitizens = function(s: any, _dt: number)
			step(s)
		end,
	})
end

return WarWatch
