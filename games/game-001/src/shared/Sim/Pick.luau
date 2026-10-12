--!strict
--[[
	Sim/Pick — screen-space picking maths for EntityController:pick (CONTRACTS G4.1). Pure: the
	camera projection is passed in, so specs use a fake one.

	API
		Pick.nearest(candidates, screenPos, project, maxPixels): number?
			candidates  { { id: number, position: Vector3 } }   -- world points to test (e.g. body centres)
			screenPos   Vector2                                 -- the tap/click, in the projection's space
			project     (Vector3) -> (Vector2?, number?)        -- screen point and depth; nil when the
			                                                       point is behind the camera or off screen
			maxPixels   number                                  -- farther than this from screenPos never picks
		Returns the id whose projected point is nearest to screenPos (ties: the one nearer the camera,
		then the lower id), or nil when none is within maxPixels.
]]

export type Candidate = { id: number, position: Vector3 }

local Pick = {}

function Pick.nearest(
	candidates: { Candidate },
	screenPos: Vector2,
	project: (Vector3) -> (Vector2?, number?),
	maxPixels: number
): number?
	local bestId, bestDistance, bestDepth = nil, math.huge, math.huge
	for _, candidate in candidates do
		local point, depth = project(candidate.position)
		if point ~= nil then
			local distance = (point - screenPos).Magnitude
			local d = depth or 0
			if distance <= maxPixels then
				local better = distance < bestDistance
					or (
						distance == bestDistance
						and (d < bestDepth or (d == bestDepth and candidate.id < (bestId :: any)))
					)
				if better then
					bestId, bestDistance, bestDepth = candidate.id, distance, d
				end
			end
		end
	end
	return bestId
end

return table.freeze(Pick)
