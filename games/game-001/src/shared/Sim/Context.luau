--!strict
--[[
	Sim/Context — the flat condition contexts of the content library (content/SPEC.md §4) built from a
	simulation (FL-0080, FL-0079). Pure: callers pass the simulation and whatever the simulation does not
	know (phase, ruler reputation, event flags). ContentQuery.evaluate reads them; absent flags are false
	and absent kingdom.count.<type> is 0, so only true flags are set.

	API
		Context.kingdom(sim, kingdomId, extra?): Ctx
			phase (extra.phase), kingdom.food/wood/stone/gold, kingdom.fed_ratio (kingdom.fedRatio, 1 when
			unknown), kingdom.housing_ratio (population / capacity; 0 capacity → 10), kingdom.happiness /
			stability / morale (kingdom.conditions), kingdom.population (citizens), kingdom.soldiers,
			kingdom.count.<type> for every G2 BuildingType (standing, at least level 1), kingdom.level.keep,
			event.<tag> = true for each tag in extra.events, and rep.<category> from extra.rep.
			extra.before = { buildingId, level }: the state just before that building reached `level` (it
			counts at level − 1: housing capacity and kingdom.count as they were), so a need condition such
			as "kingdom.housing_ratio > 0.9" judges the need the building answered, not the state it made.
		Context.citizen(sim, citizen, base?, extra?): Ctx
			A copy of `base` (a kingdom ctx) plus occupation, citizen.loyalty / mood / chemistry / hunger /
			obedience (extra.obedience), citizen.trait.<id>, citizen.memory.<tag> (G5 memory kinds and pinned
			content memories, citizen.pinned), citizen.has_family / has_friend / has_rival.
		Context.mood(citizen): number   -- 0..100 (well fed = high; the G5 / CitizenView mood)
]]

local Types = require("../Kingdom/Types")

export type Ctx = { [string]: any }

local Context = {}

function Context.mood(citizen: any): number
	return math.clamp(math.floor((1 - math.min(1, citizen.hunger or 0)) * 100 + 0.5), 0, 100)
end

function Context.kingdom(sim: any, kingdomId: string, extra: { [string]: any }?): Ctx
	local opts = extra or {}
	local k = sim.kingdoms[kingdomId]
	local ctx: Ctx = {}
	if k == nil then
		return ctx
	end
	ctx.phase = opts.phase
	for _, resource in { "food", "wood", "stone", "gold" } do
		ctx[`kingdom.{resource}`] = sim:balance(kingdomId, resource)
	end
	ctx["kingdom.fed_ratio"] = k.fedRatio or 1
	local population = #k.citizenIds
	ctx["kingdom.population"] = population
	ctx["kingdom.soldiers"] = #k.unitIds
	local capacity = k.popCap or 0
	local before = opts.before
	local was = nil :: any
	if before then
		was = sim.buildings[before.buildingId]
		if was then
			local levels = sim.catalog.buildings[was.kind].levels
			local now = levels[before.level]
			local previous = levels[before.level - 1]
			capacity -= ((now and now.popCap) or 0) - ((previous and previous.popCap) or 0)
		end
	end
	ctx["kingdom.housing_ratio"] = if capacity > 0 then math.min(10, (population + #k.unitIds) / capacity) else 10
	local conditions = k.conditions
	if conditions then
		ctx["kingdom.happiness"] = conditions.happiness
		ctx["kingdom.stability"] = conditions.stability
		ctx["kingdom.morale"] = conditions.morale
	end
	for _, kind in Types.BUILDING_TYPES do
		ctx[`kingdom.count.{kind}`] = 0
	end
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		local level = if b and b == was then (before :: any).level - 1 else (if b then b.level else 0)
		if b and not b.destroyed and level >= 1 then
			local key = `kingdom.count.{b.kind}`
			ctx[key] = (ctx[key] or 0) + 1
		end
	end
	local keep = sim.buildings[k.keepId]
	ctx["kingdom.level.keep"] = if keep and not keep.destroyed
		then (if keep == was then (before :: any).level - 1 else keep.level)
		else 0
	for _, tag in opts.events or {} do
		ctx[`event.{tag}`] = true
	end
	for category, value in opts.rep or {} do
		ctx[`rep.{category}`] = value
	end
	return ctx
end

function Context.citizen(sim: any, citizen: any, base: Ctx?, extra: { [string]: any }?): Ctx
	local ctx: Ctx = table.clone(base or {})
	local profile = citizen.profile
	ctx.occupation = if profile then profile.occupation else citizen.job
	ctx["citizen.loyalty"] = citizen.loyalty or 50
	ctx["citizen.mood"] = Context.mood(citizen)
	ctx["citizen.chemistry"] = citizen.chemistry or 0
	ctx["citizen.hunger"] = citizen.hunger or 0
	if extra and extra.obedience ~= nil then
		ctx["citizen.obedience"] = extra.obedience
	end
	if profile then
		for _, trait in profile.traits do
			ctx[`citizen.trait.{trait}`] = true
		end
		local function alive(ids: { number }): boolean
			for _, id in ids do
				if sim.citizens[id] then
					return true
				end
			end
			return false
		end
		if alive(profile.family) then
			ctx["citizen.has_family"] = true
		end
		if alive(profile.friends) then
			ctx["citizen.has_friend"] = true
		end
		if alive(profile.rivals) then
			ctx["citizen.has_rival"] = true
		end
	end
	for _, entry in citizen.memory or {} do
		ctx[`citizen.memory.{entry.kind}`] = true
	end
	for tag in citizen.pinned or {} do
		ctx[`citizen.memory.{tag}`] = true
	end
	return ctx
end

return Context
