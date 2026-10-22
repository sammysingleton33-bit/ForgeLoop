--!strict
--[[
	UI/WallLine — a straight wall drawn between two ends (FL-0129c; FORGE-01's Build.PlaceLine, FL-0126 part 2
	slice 1, handoff 2026-10-22-forge-01-to-all-place-line). Pure: no instances. BuildMenuController draws the ghosts
	and sends Build.PlaceLine("wall", from, to); the server decides.

	The pieces follow the server's rule (Simulation:placeLine), so the ghosts stand where the walls will:
	  - both ends snap to `grid` studs (config Buildings.lineGrid, 4); y is the first end's;
	  - the snapped length gives round(length / segment) pieces (the Kit wall piece's long side, 32 studs), at
	    least one; fewer than `grid` studs is "too_short", more than `max` pieces (config Buildings.maxLineSegments,
	    12) is "too_long";
	  - piece i stands at (i - 0.5) * segment from the first end along the line, facing along it:
	    yaw = atan2(-dz, dx) (Footprint.rect: the long side runs (cos yaw, -sin yaw)), so CFrame.Angles(0, yaw, 0).
	The line can end short of, or past, the second end by up to half a piece (whole pieces only).
	What the client cannot know: whether each piece is clear of buildings, nodes, zones and territory edges.
	Build.CanPlace takes quarter turns only, so the pieces are not checked one by one; the server's all-or-nothing
	answer on Build wall is the verdict.

	WallLine.plan(from: Vector3, to: Vector3, options?) -> Plan
		options = { grid, segment, max }   (defaults: config Buildings, WallLine.SEGMENT)
		Plan = { from: Vector3, to: Vector3 (snapped), length, count, yaw, reason: ("too_short" | "too_long")?,
		         pieces: { { position: Vector3, cframe: CFrame } } }   (no pieces when reason is set)
	WallLine.cost(perPiece: { [currency]: number }, count) -> { [currency]: number }
]]

local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")

local WallLine = {}

WallLine.SEGMENT = 32 -- the Kit wall piece's long side (Kit.footprint("wall") is 32 × 8)
WallLine.GRID = (BuildingsConfig :: any).lineGrid or 4
WallLine.MAX = (BuildingsConfig :: any).maxLineSegments or 12

local function snap(v: number, grid: number): number
	return math.floor(v / grid + 0.5) * grid
end

function WallLine.plan(from: Vector3, to: Vector3, options: { [string]: number }?): any
	local o = options or {}
	local grid = o.grid or WallLine.GRID
	local segment = o.segment or WallLine.SEGMENT
	local max = o.max or WallLine.MAX
	local fx, fz, tx, tz = snap(from.X, grid), snap(from.Z, grid), snap(to.X, grid), snap(to.Z, grid)
	local dx, dz = tx - fx, tz - fz
	local length = math.sqrt(dx * dx + dz * dz)
	local count = math.max(1, math.floor(length / segment + 0.5))
	local plan = {
		from = Vector3.new(fx, from.Y, fz),
		to = Vector3.new(tx, from.Y, tz),
		length = length,
		count = count,
		yaw = 0,
		reason = nil :: string?,
		pieces = {},
	}
	if length < grid then
		plan.reason = "too_short"
		return plan
	end
	if count > max then
		plan.reason = "too_long"
		return plan
	end
	local ux, uz = dx / length, dz / length
	plan.yaw = math.atan2(-uz, ux)
	for i = 1, count do
		local at = (i - 0.5) * segment
		local position = Vector3.new(fx + ux * at, from.Y, fz + uz * at)
		table.insert(
			plan.pieces,
			{ position = position, cframe = CFrame.new(position) * CFrame.Angles(0, plan.yaw, 0) }
		)
	end
	return plan
end

function WallLine.cost(perPiece: { [string]: number }, count: number): { [string]: number }
	local total = {}
	for currency, amount in perPiece do
		total[currency] = amount * count
	end
	return total
end

return table.freeze(WallLine)
