--!strict
--[[
	Gameplay/Kingdom/Objectives — neutral capture points (CONTRACTS G8, VS-1 row 7: "capture the neutral
	Watchtower"). Installed into a Simulation as a system.

	Capture rules (G8)
		- Presence: a kingdom is present when at least one of its soldiers (alive units) or rulers
		  (sim.rulerPositions, set by the host from characters) stands within the objective's radius.
		- Exactly one kingdom present: its progress rises by dt / captureSeconds; every other kingdom's
		  progress falls at the same rate. Several kingdoms present: contested, nothing changes.
		  Nobody present: non-owner progress decays at half rate.
		- Progress reaching 1 captures the point: owner changes, progress resets to { [owner] = 1 },
		  the owner gains crownPoints and a territory region of `territoryRadius` around the point.
		- The owner earns `holdPointsPerMinute` Crown Points while it holds the point.
		- Recapture by another kingdom works the same way; the old owner loses the region.

	API
		Objectives.install(sim, definitions)
			definitions: { { id, x, z, radius = 18, captureSeconds = 20, crownPoints = 100,
			                 territoryRadius = 60, holdPointsPerMinute = 6 } }
		Objectives.list(sim): { { id, kind = "capture", x, z, radius, owner: KingdomId?,
		                          progress: { [KingdomId]: number }, contested: boolean } }   -- copies (G8 list)
		Objectives.presence(sim, objective): { KingdomId }   -- sorted, for specs and the HUD
	Simulation API used: sim.kingdomOrder/kingdoms/units/unitOrder, sim.rulerPositions, sim.rulerOf,
	sim:addCrownPoints(kingdomId, amount, reason), sim:claimRegion(kingdomId, regionId, x, z, radius, reason),
	sim:releaseRegion(regionId), sim:emit(name, payload).
	Events: ObjectiveProgress { objectiveId, kingdomId, progress } (each 10% step), ObjectiveCaptured
	{ objectiveId, kingdomId, previousOwner }.
]]

local Objectives = {}

local DEFAULTS = { radius = 18, captureSeconds = 20, crownPoints = 100, territoryRadius = 60, holdPointsPerMinute = 6 }

local function dist2(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

function Objectives.presence(sim: any, o: any): { string }
	local r2 = o.radius * o.radius
	local present: { [string]: boolean } = {}
	for _, uid in sim.unitOrder do
		local u = sim.units[uid]
		if u and u.alive and dist2(u.x, u.z, o.x, o.z) <= r2 then
			present[u.kingdomId] = true
		end
	end
	for userId, pos in sim.rulerPositions do
		local kid = sim.rulerOf[userId]
		if kid and sim.kingdoms[kid] and sim.kingdoms[kid].alive and dist2(pos.x, pos.z, o.x, o.z) <= r2 then
			present[kid] = true
		end
	end
	local out = {}
	for _, kid in sim.kingdomOrder do
		if present[kid] then
			table.insert(out, kid)
		end
	end
	return out
end

local function step(sim: any, dt: number)
	for _, o in sim.objectives.list do
		local present = Objectives.presence(sim, o)
		o.contested = #present > 1
		local rate = dt / o.captureSeconds
		if #present == 1 then
			local kid = present[1]
			if o.owner == kid then
				-- the owner standing on its point wears down any challenger's progress
				for other, value in o.progress do
					if other ~= kid then
						o.progress[other] = math.max(0, value - rate)
					end
				end
			else
				local before = o.progress[kid] or 0
				for other, value in o.progress do
					if other ~= kid then
						o.progress[other] = math.max(0, value - rate)
					end
				end
				local after = math.min(1, before + rate)
				o.progress[kid] = after
				if math.floor(after * 10) > math.floor(before * 10) and after < 1 then
					sim:emit("ObjectiveProgress", { objectiveId = o.id, kingdomId = kid, progress = after })
				end
				if after >= 1 then
					local previous = o.owner
					if previous then
						sim:releaseRegion("objective:" .. o.id)
					end
					o.owner = kid
					o.progress = { [kid] = 1 }
					o.heldSeconds = 0
					sim:claimRegion(kid, "objective:" .. o.id, o.x, o.z, o.territoryRadius, "objective")
					sim:addCrownPoints(kid, o.crownPoints, "objective:" .. o.id)
					sim:emit("ObjectiveCaptured", { objectiveId = o.id, kingdomId = kid, previousOwner = previous })
				end
			end
		elseif #present == 0 then
			for kid, value in o.progress do
				if kid ~= o.owner then
					o.progress[kid] = math.max(0, value - rate / 2)
				end
			end
		end
		-- the owner earns points for holding the point (whole points only, exactly once each)
		if o.owner and sim.kingdoms[o.owner].alive then
			o.heldSeconds = (o.heldSeconds or 0) + dt
			local perPoint = 60 / o.holdPointsPerMinute
			while o.heldSeconds >= perPoint do
				o.heldSeconds -= perPoint
				sim:addCrownPoints(o.owner, 1, "hold:" .. o.id)
			end
		end
	end
end

function Objectives.install(sim: any, definitions: { { [string]: any } })
	assert(sim.objectives == nil, "Objectives.install: already installed")
	local list = {}
	local seen = {}
	for i, def in definitions do
		assert(type(def.id) == "string" and not seen[def.id], `Objectives: definition {i} needs a unique id`)
		assert(type(def.x) == "number" and type(def.z) == "number", `Objectives: '{def.id}' needs x and z`)
		seen[def.id] = true
		local o = {
			id = def.id,
			kind = "capture",
			x = def.x,
			z = def.z,
			radius = def.radius or DEFAULTS.radius,
			captureSeconds = def.captureSeconds or DEFAULTS.captureSeconds,
			crownPoints = def.crownPoints or DEFAULTS.crownPoints,
			territoryRadius = def.territoryRadius or DEFAULTS.territoryRadius,
			holdPointsPerMinute = def.holdPointsPerMinute or DEFAULTS.holdPointsPerMinute,
			owner = nil :: string?,
			progress = {} :: { [string]: number },
			contested = false,
			heldSeconds = 0,
		}
		assert(o.radius > 0 and o.captureSeconds > 0 and o.holdPointsPerMinute > 0, `Objectives: '{o.id}' bad numbers`)
		table.insert(list, o)
	end
	sim.objectives = { list = list }
	sim:addSystem({
		afterCitizens = function(s: any, dt: number)
			step(s, dt)
		end,
	})
end

function Objectives.list(sim: any): { any }
	local out = {}
	for _, o in (sim.objectives and sim.objectives.list) or {} do
		table.insert(out, {
			id = o.id,
			kind = o.kind,
			x = o.x,
			z = o.z,
			radius = o.radius,
			owner = o.owner,
			progress = table.clone(o.progress),
			contested = o.contested,
		})
	end
	return out
end

return Objectives
