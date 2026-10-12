--!strict
--[[
	Sim/Interest — per-player interest management for entity snapshots (CONTRACTS G4).

	Entities near the viewer go out every snapshot tick; distant ones are spread over `farEvery`
	ticks (each entity on the tick where (id + tick) % farEvery == 0), so every entity still updates
	regularly while bandwidth stays bounded. Entities in `always` (e.g. the viewer's own soldiers
	under command) are always included. Pure and deterministic.

	API
		Interest.select(entities, viewer, tick, options?): { entity }
			entities  array of { id: number, x: number, z: number, ... } (any extra fields kept)
			viewer    { x: number, z: number }? -- nil (no character yet): everything counts as far
			options   { nearRadius = 200, farEvery = 5, always = { [id] = true }? }
		Interest.bytesPerSecond(nearCount, farCount, ticksPerSecond, options?): number
			-- the snapshot budget estimate logged by the host (22 bytes/entity + 15/chunk header)
]]

local Interest = {}

Interest.DEFAULT_NEAR = 200
Interest.DEFAULT_FAR_EVERY = 5

function Interest.select(
	entities: { any },
	viewer: { x: number, z: number }?,
	tick: number,
	options: { [string]: any }?
): { any }
	local opts = options or {}
	local near = opts.nearRadius or Interest.DEFAULT_NEAR
	local farEvery = math.max(1, opts.farEvery or Interest.DEFAULT_FAR_EVERY)
	local always = opts.always
	local nearSq = near * near
	local out = {}
	for _, e in entities do
		local include = false
		if always and always[e.id] then
			include = true
		elseif viewer then
			local dx, dz = e.x - viewer.x, e.z - viewer.z
			include = dx * dx + dz * dz <= nearSq
		end
		if not include then
			include = (e.id + tick) % farEvery == 0
		end
		if include then
			table.insert(out, e)
		end
	end
	return out
end

function Interest.bytesPerSecond(
	nearCount: number,
	farCount: number,
	ticksPerSecond: number,
	options: { [string]: any }?
): number
	local opts = options or {}
	local farEvery = math.max(1, opts.farEvery or Interest.DEFAULT_FAR_EVERY)
	local perTick = nearCount + farCount / farEvery
	local chunks = math.max(1, math.ceil(perTick / 40))
	return (perTick * 22 + chunks * 15) * ticksPerSecond
end

return Interest
