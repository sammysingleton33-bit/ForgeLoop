--!strict
--[[
	Sim/Nav — navigation over the world Layout's path graph (CONTRACTS G10.1 `Layout.nav`, D-023: no
	PathfindingService, no tags). Pure and deterministic.

	Long trips follow the roads and bridges: an entity heading further than `directRange` studs walks to
	the graph node nearest to it, along the shortest node path (A*, cost = distance), then from the node
	nearest the goal straight to the goal. Shorter trips (work inside a kingdom's plot) go straight.
	Routes are cached per (from node, to node).

	API
		Nav.new(graph: { nodes: { Vector3 }, edges: { { number } } }, options?): Nav
			options: { directRange = 150, reachRadius = 3 }
		nav:nearest(x, z): number?                      -- node index
		nav:route(fromNode, toNode): { number }?        -- node indices, both ends included; nil if unreachable
		nav:plan(x, z, tx, tz): { { x: number, z: number } }   -- waypoints ending at the goal
		Nav.waypoint(sim, entity, tx, tz): (number, number)    -- where `entity` should head now on its way
		                                                    to (tx, tz); keeps its route on entity._route.
		                                                    Without sim.nav: the goal itself.
]]

local Nav = {}
Nav.__index = Nav

Nav.DIRECT_RANGE = 150
Nav.REACH = 3

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

function Nav.new(graph: any, options: { [string]: any }?)
	local opts = options or {}
	assert(type(graph) == "table" and type(graph.nodes) == "table", "Nav.new: graph.nodes required")
	local self = setmetatable({}, Nav)
	self.directRange = opts.directRange or Nav.DIRECT_RANGE
	self.reach = opts.reachRadius or Nav.REACH
	self._x = {} :: { number }
	self._z = {} :: { number }
	self._links = {} :: { { { to: number, cost: number } } }
	for i, p in graph.nodes do
		self._x[i], self._z[i] = p.X, p.Z
		self._links[i] = {}
	end
	for _, edge in graph.edges or {} do
		local a, b = edge[1], edge[2]
		assert(self._x[a] ~= nil and self._x[b] ~= nil, `Nav.new: edge \{{a}, {b}\} names a missing node`)
		local cost = dist(self._x[a], self._z[a], self._x[b], self._z[b])
		table.insert(self._links[a], { to = b, cost = cost })
		table.insert(self._links[b], { to = a, cost = cost })
	end
	self._cache = {} :: { [string]: { number } | false }
	return self
end

function Nav:nearest(x: number, z: number): number?
	local best, bestD = nil, math.huge
	for i, nx in self._x do
		local d = dist(x, z, nx, self._z[i])
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- A* over the node graph (straight-line heuristic, admissible). Ties break by node index, so the
-- result is deterministic.
function Nav:route(from: number, to: number): { number }?
	local key = `{from}>{to}`
	local cached = self._cache[key]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local open = { from }
	local came: { [number]: number } = {}
	local g: { [number]: number } = { [from] = 0 }
	local closed: { [number]: boolean } = {}
	local tx, tz = self._x[to], self._z[to]
	local result: { number }? = nil
	while #open > 0 do
		local bestIndex, bestF = 1, math.huge
		for i, node in open do
			local f = g[node] + dist(self._x[node], self._z[node], tx, tz)
			if f < bestF or (f == bestF and node < open[bestIndex]) then
				bestIndex, bestF = i, f
			end
		end
		local current = table.remove(open, bestIndex) :: number
		if current == to then
			local path = { current }
			while came[path[1]] do
				table.insert(path, 1, came[path[1]])
			end
			result = path
			break
		end
		closed[current] = true
		for _, link in self._links[current] do
			if not closed[link.to] then
				local cost = g[current] + link.cost
				if g[link.to] == nil or cost < g[link.to] then
					if g[link.to] == nil then
						table.insert(open, link.to)
					end
					g[link.to] = cost
					came[link.to] = current
				end
			end
		end
	end
	self._cache[key] = result or false
	return result
end

function Nav:plan(x: number, z: number, tx: number, tz: number): { { x: number, z: number } }
	local goal = { x = tx, z = tz }
	if dist(x, z, tx, tz) <= self.directRange then
		return { goal }
	end
	local from, to = self:nearest(x, z), self:nearest(tx, tz)
	if from == nil or to == nil or from == to then
		return { goal }
	end
	local nodes = self:route(from, to)
	if nodes == nil then
		return { goal }
	end
	local points = {}
	for _, node in nodes do
		table.insert(points, { x = self._x[node], z = self._z[node] })
	end
	-- skip leading nodes that lie behind the entity (it is already past them towards the next one)
	while
		#points >= 2
		and dist(x, z, points[2].x, points[2].z) < dist(points[1].x, points[1].z, points[2].x, points[2].z)
	do
		table.remove(points, 1)
	end
	-- likewise the last node, when the goal is closer to the one before it
	while
		#points >= 2
		and dist(tx, tz, points[#points - 1].x, points[#points - 1].z)
			< dist(points[#points].x, points[#points].z, points[#points - 1].x, points[#points - 1].z)
	do
		table.remove(points)
	end
	table.insert(points, goal)
	return points
end

function Nav.waypoint(sim: any, e: any, tx: number, tz: number): (number, number)
	local nav = sim.nav
	if nav == nil then
		return tx, tz
	end
	local route = e._route
	if route == nil or math.abs(route.tx - tx) > 1 or math.abs(route.tz - tz) > 1 then
		route = { tx = tx, tz = tz, points = nav:plan(e.x, e.z, tx, tz), index = 1 }
		e._route = route
	end
	local points = route.points
	while route.index < #points do
		local p = points[route.index]
		if dist(e.x, e.z, p.x, p.z) > nav.reach then
			break
		end
		route.index += 1
	end
	local p = points[route.index]
	return p.x, p.z
end

return Nav
