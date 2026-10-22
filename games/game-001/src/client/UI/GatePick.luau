--[[
	GatePick — the gate in the build menu (FL-0129c slice 2; FORGE-01's Build.PlaceGate, FL-0126 part 2 slice 2, #306;
	handoff 2026-10-22-forge-01-to-all-place-gate). Pure: which of my wall pieces the aim is on, and what
	turning it into the gate costs.

		GatePick.wallAt(rows, position, size?, margin?) -> row?
		    rows: KingdomStore:myBuildings(); the wall piece (type "wall", not destroyed, with a CFrame) whose rectangle
		    (size: BuildModel.footprint("wall", 1), default 32 × 8, along its local X and Z, plus `margin` studs) holds `position`; the
		    nearest centre when two overlap. A row without a CFrame cannot be picked.
		GatePick.gates(rows) -> number              standing gates among rows
		GatePick.cost(gate, wall, share) -> { net, refund }
		    gate, wall: level-1 price bags; share: the cancel refund (config Buildings.cancelRefund). refund[res] =
		    floor(wall[res] * share), as the server pays it; net[res] = max(0, gate[res] - refund[res]) for every
		    resource the gate costs: what the treasury must hold (the server checks balance + refund >= price).
]]

local GatePick = {}

GatePick.MARGIN = 2 -- studs around a piece that still pick it: a thin wall seen from above is easy to miss
GatePick.WALL = Vector2.new(32, 8) -- Kit.footprint("wall") when the caller passes none

function GatePick.wallAt(rows: { any }, position: Vector3, size: Vector2?, margin: number?): any
	local s = size or GatePick.WALL
	local m = margin or GatePick.MARGIN
	local best, bestDistance = nil, math.huge
	for _, row in rows do
		if row.type == "wall" and row.state ~= "destroyed" and typeof(row.cframe) == "CFrame" then
			local here = row.cframe:PointToObjectSpace(Vector3.new(position.X, row.cframe.Position.Y, position.Z))
			if math.abs(here.X) <= s.X / 2 + m and math.abs(here.Z) <= s.Y / 2 + m then
				local distance = here.X * here.X + here.Z * here.Z
				if distance < bestDistance then
					best, bestDistance = row, distance
				end
			end
		end
	end
	return best
end

function GatePick.gates(rows: { any }): number
	local n = 0
	for _, row in rows do
		if row.type == "gate" and row.state ~= "destroyed" then
			n += 1
		end
	end
	return n
end

function GatePick.cost(
	gate: { [string]: number },
	wall: { [string]: number },
	share: number
): { net: { [string]: number }, refund: { [string]: number } }
	local refund = {}
	for res, amount in wall do
		refund[res] = math.floor(amount * share)
	end
	local net = {}
	for res, amount in gate do
		net[res] = math.max(0, amount - (refund[res] or 0))
	end
	return { net = net, refund = refund }
end

return table.freeze(GatePick)
