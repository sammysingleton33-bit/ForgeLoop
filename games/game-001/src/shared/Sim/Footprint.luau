--!strict
--[[
	Sim/Footprint — placement shapes on the XZ plane and the overlap tests Simulation:canPlace uses
	(CONTRACTS G6, G13.5; FORGE-05 finding M2). Pure maths: no requires, no Roblox APIs.

	A building places as an oriented rectangle: its Kit footprint at its largest level (Catalog `placeSize`,
	so an upgrade never grows into a neighbour), centred on the building and turned by its yaw
	(CFrame.Angles(0, yaw, 0): local X = width = size.X, local Z = depth = size.Y). A type without a Kit
	footprint places as its `footprint` circle. Resource nodes are circles.

	API
		Footprint.rect(size: Vector2, x, z, yaw): Shape       -- oriented rectangle
		Footprint.circle(x, z, radius): Shape
		Footprint.overlaps(a, b, gap): boolean                 -- true when less than `gap` studs of free
		                                                          ground would lie between a and b
		Footprint.overlapsCircle(a, x, z, radius, gap): boolean   -- a against a circle (a resource node)
	Rules: two rectangles use a separating-axis test on their four edge normals, each projection widened
	by `gap` (exact for parallel edges, conservative at rotated corners); a rectangle and a circle compare
	the circle centre's distance to the rectangle; two circles compare centre distance. Touching at
	exactly `gap` is not an overlap.
]]

export type Shape = {
	x: number,
	z: number,
	radius: number?, -- set for a circle
	hx: number, -- half width along the local X axis (rectangle; 0 for a circle)
	hz: number, -- half depth along the local Z axis
	ux: number, -- local X axis on the XZ plane: (ux, uz); local Z axis: (-uz, ux)
	uz: number,
	gap: number?, -- a no-build area: the free ground a placement keeps from it (sim.noBuild; none = touching is fine)
}

local EPSILON = 1e-6

local Footprint = {}

function Footprint.rect(size: Vector2, x: number, z: number, yaw: number): Shape
	-- CFrame.Angles(0, yaw, 0): RightVector = (cos, 0, -sin), ZVector = (sin, 0, cos)
	return { x = x, z = z, hx = size.X / 2, hz = size.Y / 2, ux = math.cos(yaw), uz = -math.sin(yaw) }
end

function Footprint.circle(x: number, z: number, radius: number): Shape
	return { x = x, z = z, radius = radius, hx = 0, hz = 0, ux = 1, uz = 0 }
end

-- half the rectangle's extent along the unit axis (ax, az)
local function reach(s: Shape, ax: number, az: number): number
	-- local Z axis = (-uz, ux)
	return s.hx * math.abs(ax * s.ux + az * s.uz) + s.hz * math.abs(-ax * s.uz + az * s.ux)
end

-- (ax, az) separates a and b, with `gap` to spare; (dx, dz) = b - a
local function separates(a: Shape, b: Shape, dx: number, dz: number, ax: number, az: number, gap: number): boolean
	return math.abs(dx * ax + dz * az) >= reach(a, ax, az) + reach(b, ax, az) + gap - EPSILON
end

local function rectsOverlap(a: Shape, b: Shape, gap: number): boolean
	local dx, dz = b.x - a.x, b.z - a.z
	return not (
		separates(a, b, dx, dz, a.ux, a.uz, gap)
		or separates(a, b, dx, dz, -a.uz, a.ux, gap)
		or separates(a, b, dx, dz, b.ux, b.uz, gap)
		or separates(a, b, dx, dz, -b.uz, b.ux, gap)
	)
end

function Footprint.overlapsCircle(a: Shape, x: number, z: number, radius: number, gap: number): boolean
	local dx, dz = x - a.x, z - a.z
	if a.radius ~= nil then
		return math.sqrt(dx * dx + dz * dz) < a.radius + radius + gap - EPSILON
	end
	-- the circle centre in the rectangle's frame, then its distance to the nearest point of the rectangle
	local lx, lz = dx * a.ux + dz * a.uz, -dx * a.uz + dz * a.ux
	local ox = math.max(math.abs(lx) - a.hx, 0)
	local oz = math.max(math.abs(lz) - a.hz, 0)
	return math.sqrt(ox * ox + oz * oz) < radius + gap - EPSILON
end

function Footprint.overlaps(a: Shape, b: Shape, gap: number): boolean
	if b.radius ~= nil then
		return Footprint.overlapsCircle(a, b.x, b.z, b.radius, gap)
	elseif a.radius ~= nil then
		return Footprint.overlapsCircle(b, a.x, a.z, a.radius, gap)
	end
	return rectsOverlap(a, b, gap)
end

return table.freeze(Footprint)
