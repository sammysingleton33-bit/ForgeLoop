--[[
	The composed start yard (FORGE-02 visual pass 1b; the owner's P0: "the world feels empty", "buildings look disconnected, not like a
	village"). The start camera (FL-0147: zoom 70, FOV 55, ahead 20, looking back across the yard at the keep) shows, in the bottom 40 % of
	its picture, the court, the lanes and flat grass. WorldPlan.yard composes that ground as a village centre, in the keep's frame:
	  * the avenue stays OPEN: the nav graph (Layout.nav) runs it along x = 0 from the keep door through the court to the yard node, and
	    from there diagonally to the store and the farm; nothing the yard places stands on those edges;
	  * a market cross and the well flank the keep door at the court's top corners (a symmetric pair), two market stalls with striped
	    canopies in the kingdom colour stand at its lower corners, a hedge row runs along each nav diagonal on the court's side (the V that
	    lines the approach to the store and the farm), and the farm's cart and a haystack stand in the open ground beside its diagonal.
	HEADLESS (Lune): placements, part counts and arithmetic, not a look; the renders are the evidence for the look.

	What this pins, in every kingdom (the composition is written once in the keep's frame and the four yards are rotated copies):
	  * the part budget (<= 70 parts a dressed kingdom: D-047) and what each new prop costs; only dressed kingdoms get a yard;
	  * NO Layout.nav edge passes within 2 studs of any piece's footprint (the footprint is the rectangle of the live Kit.prop bounds), and
	    nothing stands in the door's sightline: |x| < 4 from the keep door down the court. The nav rule is held for the yard AND for ALL
	    the kingdom dressing as the world places it (WorldPlan.props at full and at the shipped density: the yard, the hand-placed goods,
	    haystack and cart, the gate banners); the one exemption is the gate banners, which flank their gate on purpose (see GATE_REACH);
	  * every piece stands on legal ground by the footprint it draws (not by a circle): off the lanes, the roads (the avenue's court-covered
	    stretch apart), the slots, the buildings and the fields, clear of the focal pair's ring, overlapping no other piece, no tree, bush,
	    rock or flower stands on it, and every axial piece is inside the start camera's picture;
	  * it stands on FLAT ground: WorldPlan.groundHeight over the yard's rectangle (keep frame x -45..45, z -100..-25) is the ground level,
	    in every kingdom (the footprints, the hedge rows, the court and the specs' camera maths all assume it);
	  * it is axial: the focal pair, the stalls and the hedge rows mirror each other about the avenue's axis, the stalls face the focal
	    piece above them;
	  * it is deterministic, identical in every kingdom's own frame (the canopy and pennant colour apart), and WorldPlan.clear and the trim
	    leave it exactly where it is (its feature is "yard").
	Each measure has a MUTANT that must trip it: a prop dropped on the avenue, a hedge on a diagonal, a stall in the ring, a prop across
	the door's sightline, a cross on a lane, a hedge on a slot, a lopsided pair, a stall turned away, an overfull yard; for the widened
	nav rule also the dressing cart back where WorldPlan once planned it (clear() nudged it onto a nav edge), a banner away from a gate and
	a non-banner standing in a banner's place.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local StartView = require("./support/StartView")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local COLOUR = { crimson = "red", azure = "blue", emerald = "green", gold = "yellow" }
local ALL = { crimson = true, azure = true, emerald = true, gold = true }
local FULL = WorldPlan.FULL_DENSITY
local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }
local Y = WorldPlan.YARD

-- The ruler's start view, read from the controller (RulerCameraController.DEFAULTS.overview), for the picture test below. StartView.START
-- (support/StartView, #313) is this same table once #313 is on main: read that instead then.
local OVERVIEW = CameraDef.DEFAULTS.overview
local START = {
	zoom = OVERVIEW.startZoom,
	fov = OVERVIEW.fieldOfView,
	pitch = CameraDef.pitchFor(OVERVIEW.startZoom, OVERVIEW), -- degrees below the horizon
	ahead = OVERVIEW.startAhead,
	turn = OVERVIEW.startTurn, -- degrees from the throne's facing; 180 = looking back at the keep
}

local BUDGET = 70 -- parts a dressed kingdom's yard may cost (the brief; D-047)
local NAV_GAP = 2 -- studs between a nav edge and a piece's footprint (the coordinator's rule: a walker's reach is 3)
local GAP = 1 -- studs of open ground a piece keeps off a lane, a road, a slot or a building beyond what it draws (a field: 4)
local FIELD_GAP = 4
local ROAD_GAP = 0.5
local OVERLAP_GAP = 0.5 -- between two pieces
local RING_GAP = Y.ring -- between a focal piece and any other piece
local DOOR_HALF = 4 -- the keep door's sightline: studs either side of the avenue's axis, from the door down the court
local TOL = 1e-6
-- The gate banners (prop_banner_<colour>_01|02) are the ONE piece of kingdom dressing exempt from the nav rule (NAV_GAP): WorldPlan.plan
-- puts four of them at the keep-frame points (+-9, -96) and (+-9, -128), a pair either side of the gate node (0, -110), to flank the
-- gate on purpose (crimson's outer left one stands 1.2 studs from the nav edge that leaves the gate for the valley). WorldPlan.clear
-- leaves them exactly where the plan puts them. A piece is exempt only if BOTH hold: its assetId is a banner's AND it stands within
-- GATE_REACH studs of its own kingdom's gate node (the farthest banner is 20.1 studs from it), so a banner anywhere else, and a prop
-- of any other kind in a banner's place, is still held to NAV_GAP.
local GATE_REACH = 21
local GATE_AT = Vector3.new(0, 0, -110) -- the gate node, in the keep's frame (Layout: n.gate)

local function isYardId(id: string): boolean
	return string.find(id, "^prop_cross_") ~= nil
		or string.find(id, "^prop_stall_") ~= nil
		or string.find(id, "^prop_hedge_") ~= nil
end

-- ---- plane geometry on convex polygons ({ Vector2 } with X, Y = world x, z) and segments

local function side(o: Vector2, p: Vector2, q: Vector2): number
	return (p.X - o.X) * (q.Y - o.Y) - (p.Y - o.Y) * (q.X - o.X)
end

local function pointSeg(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
	return (p - (a + ab * t)).Magnitude
end

local function segSeg(a: Vector2, b: Vector2, c: Vector2, d: Vector2): number
	local d1, d2, d3, d4 = side(c, d, a), side(c, d, b), side(a, b, c), side(a, b, d)
	if ((d1 > 0) ~= (d2 > 0)) and ((d3 > 0) ~= (d4 > 0)) then
		return 0
	end
	return math.min(pointSeg(a, c, d), pointSeg(b, c, d), pointSeg(c, a, b), pointSeg(d, a, b))
end

local function inside(pt: Vector2, poly: { Vector2 }): boolean
	local sign: boolean? = nil
	for i = 1, #poly do
		local c = side(poly[i], poly[i % #poly + 1], pt)
		if c ~= 0 then
			if sign == nil then
				sign = c > 0
			elseif sign ~= (c > 0) then
				return false
			end
		end
	end
	return true
end

local function polySeg(poly: { Vector2 }, a: Vector2, b: Vector2): number
	if inside(a, poly) or inside(b, poly) then
		return 0
	end
	local best = math.huge
	for i = 1, #poly do
		best = math.min(best, segSeg(poly[i], poly[i % #poly + 1], a, b))
	end
	return best
end

local function polyPolyline(poly: { Vector2 }, pts: { Vector2 }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, polySeg(poly, pts[i], pts[i + 1]))
	end
	return best
end

local function polyPoly(p: { Vector2 }, q: { Vector2 }): number
	if inside(p[1], q) or inside(q[1], p) then
		return 0
	end
	local best = math.huge
	for i = 1, #p do
		for j = 1, #q do
			best = math.min(best, segSeg(p[i], p[i % #p + 1], q[j], q[j % #q + 1]))
		end
	end
	return best
end

local function rectPoly(cf: CFrame, lox: number, loz: number, hix: number, hiz: number): { Vector2 }
	local out = {}
	for _, c in { { lox, loz }, { hix, loz }, { hix, hiz }, { lox, hiz } } do
		local v = cf * Vector3.new(c[1], 0, c[2])
		table.insert(out, Vector2.new(v.X, v.Z))
	end
	return out
end

-- ---- the model's own measures (live Kit.prop, like PlotClearance.spec: a prop that grows fails here)

local function partsOf(id: string): number
	return Kit.partCount(Kit.prop(id))
end

local live: { [string]: { radius: number, lox: number, loz: number, hix: number, hiz: number } } = {}
-- the local XZ bounds of the visible parts (the footprint rectangle) and the farthest reach from the pivot
local function measure(id: string)
	local m = live[id]
	if m then
		return m
	end
	local model = Kit.prop(id)
	local pivot = model.PrimaryPart.CFrame * model.PrimaryPart.PivotOffset
	local lox, loz, hix, hiz, r = 1e9, 1e9, -1e9, -1e9, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local v = (rel * CFrame.new(sx * h.X, 0, sz * h.Z)).Position
					lox, loz = math.min(lox, v.X), math.min(loz, v.Z)
					hix, hiz = math.max(hix, v.X), math.max(hiz, v.Z)
					r = math.max(r, math.sqrt(v.X * v.X + v.Z * v.Z))
				end
			end
		end
	end
	m = { radius = r, lox = lox, loz = loz, hix = hix, hiz = hiz }
	live[id] = m
	return m
end

-- ---- a placement in the keep's frame

type Piece = { assetId: string, x: number, z: number, yaw: number, cframe: CFrame }

local function nearestKeep(cf: CFrame): string
	local best, bestD = "crimson", math.huge
	for _, k in KINGDOMS do
		local d = (Layout.plots[k].anchors.keep.Position - cf.Position).Magnitude
		if d < bestD then
			best, bestD = k, d
		end
	end
	return best
end

local function pieceOf(kingdom: string, p: any): Piece
	local rel = Layout.plots[kingdom].anchors.keep:ToObjectSpace(p.cframe)
	local look = rel.LookVector
	return {
		assetId = p.assetId,
		x = rel.Position.X,
		z = rel.Position.Z,
		yaw = math.atan2(-look.X, -look.Z),
		cframe = p.cframe,
	}
end

-- the yard pieces of a placement list for a kingdom, in the order WorldPlan.plan puts them (the rows' order)
local function yardOf(list: { any }, kingdom: string): { Piece }
	local out = {}
	for _, p in list do
		if p.feature == "yard" and nearestKeep(p.cframe) == kingdom then
			table.insert(out, pieceOf(kingdom, p))
		end
	end
	return out
end

-- ALL the kingdom dressing of a placement list for a kingdom: feature "dressing" (the gate banners, the hand-placed goods, haystack and
-- cart) and "yard", every one a Kit prop or farm piece (the natural kinds are other features), in the plan's order
local function dressingOf(list: { any }, kingdom: string): { Piece }
	local out = {}
	for _, p in list do
		if (p.feature == "dressing" or p.feature == "yard") and nearestKeep(p.cframe) == kingdom then
			table.insert(out, pieceOf(kingdom, p))
		end
	end
	return out
end

local function footprint(piece: Piece): { Vector2 }
	local m = measure(piece.assetId)
	return rectPoly(piece.cframe, m.lox, m.loz, m.hix, m.hiz)
end

local planAll = WorldPlan.plan(Layout, ALL)
local clearedAll = WorldPlan.clear(Layout, planAll)

local function sameCFrame(a: CFrame, b: CFrame): boolean
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > TOL then
			return false
		end
	end
	return true
end

-- ---- the world the pieces stand in: reserved ground (rebuilt from Layout and Kit.footprint the way PlotClearance.spec does), the nav

local reservedList: { { poly: { Vector2 }, label: string, field: boolean } }? = nil
local function reserved()
	if reservedList then
		return reservedList
	end
	local out = {}
	local function add(cf: CFrame, half: Vector2, label: string, field: boolean)
		table.insert(out, { poly = rectPoly(cf, -half.X, -half.Y, half.X, half.Y), label = label, field = field })
	end
	for i, field in Layout.features.fields do
		add(
			CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0),
			field.size / 2,
			`field {i}`,
			true
		)
	end
	for _, k in KINGDOMS do
		local plot = Layout.plots[k]
		for name, anchor in plot.anchors do
			add(anchor, Kit.footprint(name, 99) / 2, `{k} {name}`, false)
		end
		for _, slot in plot.buildSlots do
			add(
				CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0),
				Layout.slotSizes[slot.size] / 2,
				slot.id,
				false
			)
		end
	end
	reservedList = out
	return out
end

-- Layout.nav as segments (x, z)
local navSegments: { { a: Vector2, b: Vector2, label: string } } = {}
for i, e in Layout.nav.edges do
	local a, b = Layout.nav.nodes[e[1]], Layout.nav.nodes[e[2]]
	table.insert(
		navSegments,
		{ a = Vector2.new(a.X, a.Z), b = Vector2.new(b.X, b.Z), label = `nav edge {i} ({e[1]}-{e[2]})` }
	)
end

-- the court (WorldGround.worn): the keep-frame rectangle of its kerb, 22 x 26 centred at Y.court
local COURT_HALF = Vector2.new(11, 13)

local function courtPoly(kingdom: string): { Vector2 }
	local keep = Layout.plots[kingdom].anchors.keep
	return rectPoly(
		keep * CFrame.new(Y.court.X, 0, Y.court.Y),
		-COURT_HALF.X,
		-COURT_HALF.Y,
		COURT_HALF.X,
		COURT_HALF.Y
	)
end

-- the door's sightline: the strip |x| < DOOR_HALF from the door (z = -23) down to the court's far edge
local function doorStrip(kingdom: string): { Vector2 }
	local keep = Layout.plots[kingdom].anchors.keep
	return rectPoly(keep, -DOOR_HALF, Y.court.Y - COURT_HALF.Y, DOOR_HALF, Y.door.Y)
end

local function isFocal(piece: Piece): boolean
	return string.find(piece.assetId, "^prop_cross_") ~= nil or string.find(piece.assetId, "^prop_well_") ~= nil
end

-- ---- the rules (each returns its problems; empty = fine)

-- no nav edge within NAV_GAP of a footprint
local function navProblems(kingdom: string, pieces: { Piece }): { string }
	local bad = {}
	for _, piece in pieces do
		local poly = footprint(piece)
		for _, seg in navSegments do
			local d = polySeg(poly, seg.a, seg.b)
			if d < NAV_GAP then
				table.insert(
					bad,
					`{kingdom} {piece.assetId} at ({math.floor(piece.x + 0.5)}, {math.floor(piece.z + 0.5)}): {string.format(
						"%.2f",
						d
					)} studs from {seg.label}`
				)
			end
		end
	end
	return bad
end

-- the kingdom's gate node: the nav node at the keep-frame point GATE_AT (found in Layout.nav, not assumed)
local function gateNode(kingdom: string): Vector3
	local at = Layout.plots[kingdom].anchors.keep:PointToWorldSpace(GATE_AT)
	local best, bestD = Vector3.zero, math.huge
	for _, node in Layout.nav.nodes do
		local d = (Vector3.new(node.X, 0, node.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
		if d < bestD then
			best, bestD = node, d
		end
	end
	assert(bestD < 0.5, `{kingdom}: no nav node at the gate point`)
	return best
end

-- the exemption: a gate banner (by assetId) standing within GATE_REACH of its kingdom's gate node (the keep-frame distance)
local function isGateBanner(kingdom: string, piece: Piece): boolean
	if string.find(piece.assetId, "^prop_banner_%a+_0[12]$") == nil then
		return false
	end
	local gate = gateNode(kingdom)
	local at = piece.cframe.Position
	return (Vector3.new(at.X, 0, at.Z) - Vector3.new(gate.X, 0, gate.Z)).Magnitude <= GATE_REACH
end

-- no nav edge within NAV_GAP of ANY kingdom dressing but the gate banners
local function dressingNavProblems(kingdom: string, pieces: { Piece }): { string }
	local held = {}
	for _, piece in pieces do
		if not isGateBanner(kingdom, piece) then
			table.insert(held, piece)
		end
	end
	return navProblems(kingdom, held)
end

-- legal ground by the footprint: lanes, roads, slots, buildings, fields
local function legalityProblems(kingdom: string, pieces: { Piece }): { string }
	local court = courtPoly(kingdom)
	local bad = {}
	local function say(piece: Piece, what: string)
		table.insert(
			bad,
			`{kingdom} {piece.assetId} at ({math.floor(piece.x + 0.5)}, {math.floor(piece.z + 0.5)}): {what}`
		)
	end
	for _, piece in pieces do
		local poly = footprint(piece)
		for _, rect in reserved() do
			if polyPoly(poly, rect.poly) < (if rect.field then FIELD_GAP else GAP) then
				say(piece, `on {rect.label}`)
			end
		end
		for i, lane in Layout.features.paths do
			if polyPolyline(poly, lane.points :: any) < lane.width / 2 + GAP then
				say(piece, `on lane {i} ({lane.name})`)
			end
		end
		for i, road in Layout.features.roads do
			-- the avenue begins inside the court: the court is laid over its first stretch, and the nav rules (navProblems, the door's
			-- sightline) are what keep its walkway open
			local first = road.points[1]
			if
				not inside(Vector2.new(first.X, first.Y), court)
				and polyPolyline(poly, road.points) < road.width / 2 + ROAD_GAP
			then
				say(piece, `on road {i}`)
			end
		end
	end
	return bad
end

-- the door's sightline, the focal pair's ring and the overlap of pieces, for ONE kingdom's pieces
local function openGroundProblems(kingdom: string, pieces: { Piece }): { string }
	local bad = {}
	local strip = doorStrip(kingdom)
	for i, piece in pieces do
		local poly = footprint(piece)
		if polyPoly(poly, strip) < 0.01 then
			table.insert(bad, `{kingdom} {piece.assetId} at ({piece.x}, {piece.z}) stands in the door's sightline`)
		end
		for j = i + 1, #pieces do
			local other = pieces[j]
			local need = if isFocal(piece) or isFocal(other) then RING_GAP else OVERLAP_GAP
			if polyPoly(poly, footprint(other)) < need then
				table.insert(bad, `{kingdom} {piece.assetId} and {other.assetId} are closer than {need} studs`)
			end
		end
	end
	return bad
end

-- axial: rows (keep-frame { id, x, z, yaw, role }): the focal pieces face each other across the axis, the stalls and the hedges are
-- mirror images, every stall faces the focal piece above it
local function axialProblems(rows: { any }): { string }
	local bad = {}
	local function sides(role: string): ({ any }, { any })
		local right, left = {}, {}
		for _, row in rows do
			if row.role == role then
				table.insert(if row.x > 0 then right else left, row)
			end
		end
		return right, left
	end
	for _, role in { "focal", "stall", "hedge" } do
		local right, left = sides(role)
		if #right == 0 or #right ~= #left then
			table.insert(bad, `{role}: {#right} right of the axis and {#left} left of it`)
		else
			for i, a in right do
				local b = left[i]
				local sameId = a.id == b.id or role == "focal" -- the focal pair is a cross and a well
				local mirrored = math.abs(a.x + b.x) < TOL
					and math.abs(a.z - b.z) < TOL
					and math.abs(a.yaw + b.yaw) < TOL
				if not (sameId and mirrored) then
					table.insert(bad, `{role}: piece {i} is not the mirror image of its partner`)
				end
			end
		end
	end
	for _, row in rows do
		if row.role == "stall" then
			-- the front (-Z turned by yaw) must point at the focal piece on its side
			local target
			for _, other in rows do
				if other.role == "focal" and (other.x > 0) == (row.x > 0) then
					target = other
				end
			end
			if not target then
				table.insert(bad, "a stall has no focal piece to face")
			else
				local fx, fz = -math.sin(row.yaw), -math.cos(row.yaw)
				local tx, tz = target.x - row.x, target.z - row.z
				local len = math.sqrt(tx * tx + tz * tz)
				if (fx * tx + fz * tz) / len < math.cos(math.rad(2)) then
					table.insert(bad, "a stall does not face the focal piece above it")
				end
			end
		end
	end
	return bad
end

-- the yard's flat ground: WorldPlan.groundHeight sampled every YARD_STEP studs over the yard's rectangle in the keep's frame, and at the
-- middle of each yard row (the haystack stands at x = 46, a little outside the grid), against Layout.features.groundY
local YARD_X, YARD_Z, YARD_STEP = 45, { -100, -25 }, 5
local FLAT_TOL = 0.05
local FLAT_HINT = "The yard is composed on flat ground: its footprints, the hedge rows (one height for a whole 12-stud row), the court and the "
	.. "specs' camera maths assume a plane at groundY, while WorldPlan.yard only stands each piece at the ground height of its middle. "
	.. "If this fails, a hill or the river now reaches the yard: move it, or make the yard sit its pieces, rows and court on "
	.. "WorldPlan.groundHeight (and the footprint and camera maths with it)."

local function groundProblems(kingdom: string, height: (number, number) -> number): { string }
	local keep = Layout.plots[kingdom].anchors.keep
	local flat = Layout.features.groundY or 0
	local points: { Vector2 } = {}
	for x = -YARD_X, YARD_X, YARD_STEP do
		for z = YARD_Z[1], YARD_Z[2], YARD_STEP do
			table.insert(points, Vector2.new(x, z))
		end
	end
	for _, row in WorldPlan.yardRows(COLOUR[kingdom]) do
		table.insert(points, Vector2.new(row.x, row.z))
	end
	local bad = {}
	for _, at in points do
		local w = keep:PointToWorldSpace(Vector3.new(at.X, 0, at.Y))
		local h = height(w.X, w.Z)
		if math.abs(h - flat) > FLAT_TOL then
			table.insert(bad, `{kingdom} ground at keep-frame ({at.X}, {at.Y}) is {h}, not {flat}`)
		end
	end
	return bad
end

-- ... and the pieces stand on it (the height WorldPlan.yard gives each is that of its middle)
local function pieceHeightProblems(kingdom: string, pieces: { Piece }): { string }
	local flat = Layout.features.groundY or 0
	local bad = {}
	for _, piece in pieces do
		local y = piece.cframe.Position.Y
		if math.abs(y - flat) > FLAT_TOL then
			table.insert(bad, `{kingdom} {piece.assetId} stands at y = {y}, not {flat}`)
		end
	end
	return bad
end

local function groundHeightOf(x: number, z: number): number
	return WorldPlan.groundHeight(Layout, x, z)
end

-- a ground with a swell of `lift` studs under the keep-frame box x in [-45, 45], z in [-100, -25] (or the part of it with x >= fromX)
local function swelled(kingdom: string, lift: number, fromX: number?): (number, number) -> number
	local keep = Layout.plots[kingdom].anchors.keep
	return function(x: number, z: number): number
		local at = keep:PointToObjectSpace(Vector3.new(x, 0, z))
		local under = math.abs(at.X) <= YARD_X
			and at.X >= (fromX or -YARD_X)
			and at.Z >= YARD_Z[1]
			and at.Z <= YARD_Z[2]
		return groundHeightOf(x, z) + (if under then lift else 0)
	end
end

local function rowsOf(kingdom: string): { any }
	return WorldPlan.yardRows(COLOUR[kingdom])
end

local function budgetOf(ids: { string }): number
	local n = 0
	for _, id in ids do
		n += partsOf(id)
	end
	return n
end

local function idsOf(pieces: { Piece }): { string }
	local out = {}
	for _, p in pieces do
		table.insert(out, p.assetId)
	end
	return out
end

-- a copy of a kingdom's yard with one piece moved to (keep-frame x, z, yaw)
local function with(kingdom: string, pieces: { Piece }, index: number, x: number, z: number, yaw: number?): { Piece }
	local keep = Layout.plots[kingdom].anchors.keep
	local out = table.clone(pieces)
	local old = pieces[index]
	local p = keep:PointToWorldSpace(Vector3.new(x, 0, z))
	local y = yaw or old.yaw
	local keepYaw = math.atan2(-keep.LookVector.X, -keep.LookVector.Z)
	out[index] = {
		assetId = old.assetId,
		x = x,
		z = z,
		yaw = y,
		cframe = CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, keepYaw + y, 0),
	}
	return out
end

local function indexOf(rows: { any }, id: string, rightHand: boolean?): number
	for i, row in rows do
		if string.find(row.id, id, 1, true) and (rightHand == nil or (row.x > 0) == rightHand) then
			return i
		end
	end
	error(`no {id} row`)
end

describe("The composed start yard (FORGE-02 visual pass 1b)", function()
	it("is the focal pair, two stalls, four hedges and the farm's trade, in the dressed kingdoms only", function()
		local rows = rowsOf("crimson")
		expect(#rows).toBe(10) -- the cross, the well, 2 stalls, 4 hedges, a cart, a haystack
		for _, k in KINGDOMS do
			expect(#yardOf(planAll, k)).toBe(#rows)
		end
		-- a kingdom that is not dressed has none of it
		for _, only in KINGDOMS do
			local plan = WorldPlan.plan(Layout, { [only] = true })
			for _, k in KINGDOMS do
				local n = 0
				for _, p in plan do
					if p.feature == "yard" and nearestKeep(p.cframe) == k then
						n += 1
					end
				end
				expect(n).toBe(if k == only then #rows else 0)
			end
		end
		expect(#WorldPlan.yard(Layout, "azure")).toBe(#rows)
	end)

	it("costs at most 70 parts a dressed kingdom and its new props are as small as pinned", function()
		expect(partsOf("prop_cross_red_01")).toBe(8) -- 3 steps, a shaft, an arm, a pennant, a finial and the Root
		expect(partsOf("prop_stall_red_01")).toBe(9) -- counter, crate, back wall, 2 posts, canopy, 2 stripes and the Root
		expect(partsOf("prop_hedge_01")).toBe(5) -- 4 leafy balls and the Root (12 long)
		expect(partsOf("prop_hedge_02")).toBe(3) -- 2 balls and the Root (6.5 long)
		expect(partsOf("prop_well_01")).toBe(10) -- the existing well
		for _, k in KINGDOMS do
			local pieces = yardOf(planAll, k)
			local n = budgetOf(idsOf(pieces))
			expect(n).toBe(66) -- 8 + 10 + 2 x 9 + 2 x (5 + 3) + cart 10 + haystack 4
			expect(n).toBeLessThanOrEqual(BUDGET)
		end
		-- the stalls and crosses differ by colour alone
		expect(partsOf("prop_stall_blue_01")).toBe(partsOf("prop_stall_yellow_01"))
		expect(partsOf("prop_cross_blue_01")).toBe(partsOf("prop_cross_green_01"))
	end)

	it("MUTANT: more hedges than the budget allows is caught", function()
		local ids = idsOf(yardOf(planAll, "crimson"))
		for _ = 1, 4 do
			table.insert(ids, "prop_hedge_01")
		end
		expect(budgetOf(ids)).toBeGreaterThan(BUDGET)
	end)

	it("keeps every Layout.nav edge at least 2 studs from every piece's footprint, in all four kingdoms", function()
		-- the guard that the measure means something: the nav does run the avenue and the two diagonals through this ground
		for _, k in KINGDOMS do
			local keep = Layout.plots[k].anchors.keep
			local near = 0
			for _, seg in navSegments do
				local a, b =
					keep:PointToObjectSpace(Vector3.new(seg.a.X, 0, seg.a.Y)),
					keep:PointToObjectSpace(Vector3.new(seg.b.X, 0, seg.b.Y))
				if math.abs(a.X) < 70 and a.Z < -20 and a.Z > -70 or math.abs(b.X) < 70 and b.Z < -20 and b.Z > -70 then
					near += 1
				end
			end
			expect(near).toBeGreaterThanOrEqual(4) -- the avenue, the two diagonals and the cross street
		end
		for _, k in KINGDOMS do
			expect(table.concat(navProblems(k, yardOf(planAll, k)), "; ")).toBe("")
		end
	end)

	it(
		"keeps every compact piece's middle a footprint radius + 2 studs from every Layout.nav edge (hedge rows run 4.5 off a diagonal)",
		function()
			for _, k in KINGDOMS do
				local bad = {}
				for _, piece in yardOf(planAll, k) do
					if not string.find(piece.assetId, "^prop_hedge_") then
						local at = Vector2.new(piece.cframe.Position.X, piece.cframe.Position.Z)
						for _, seg in navSegments do
							if pointSeg(at, seg.a, seg.b) < measure(piece.assetId).radius + 2 then
								table.insert(bad, `{k} {piece.assetId} is within its radius + 2 of {seg.label}`)
							end
						end
					end
				end
				expect(table.concat(bad, "; ")).toBe("")
			end
		end
	)

	it(
		"MUTANT: a stall dropped on the avenue, a hedge on a diagonal and a crate on the cross street are caught by the nav measure",
		function()
			local rows = rowsOf("crimson")
			local pieces = yardOf(planAll, "crimson")
			for i, row in rows do
				expect(pieces[i].assetId).toBe(row.id) -- the pieces come back in the rows' order
			end
			local stall = indexOf(rows, "prop_stall_", true)
			local hedge = indexOf(rows, "prop_hedge_01", true)
			local hay = indexOf(rows, "farm_haystack", nil)
			expect(#navProblems("crimson", with("crimson", pieces, stall, 0, -45))).toBeGreaterThan(0) -- on the avenue
			local along = Vector2.new(math.cos(Y.vAngle), math.sin(Y.vAngle))
			expect(#navProblems("crimson", with("crimson", pieces, hedge, along.X * 26, Y.apex.Y + along.Y * 26))).toBeGreaterThan(
				0
			) -- on the farm diagonal
			expect(#navProblems("crimson", with("crimson", pieces, hay, 40, -62))).toBeGreaterThan(0) -- on the cross street
			-- the same pieces where the yard puts them: nothing
			expect(#navProblems("crimson", pieces)).toBe(0)
		end
	)

	it(
		"keeps every Layout.nav edge at least 2 studs from the footprint of ALL the kingdom dressing the world places, the gate banners apart",
		function()
			local lists = { full = WorldPlan.props(Layout, ALL, FULL), shipped = WorldPlan.props(Layout, ALL) }
			local needed = 0
			for name, list in lists do
				for _, k in KINGDOMS do
					local pieces = dressingOf(list, k)
					expect(#pieces).toBe(18) -- 4 gate banners, the 4 hand-placed (2 goods, a haystack, the cart) and the yard's 10
					local banners = {}
					for _, piece in pieces do
						if isGateBanner(k, piece) then
							table.insert(banners, piece)
						end
					end
					expect(#banners).toBe(4) -- only the four banners are exempt: the rest is held to NAV_GAP
					needed += #navProblems(k, banners)
					local bad = dressingNavProblems(k, pieces)
					if #bad > 0 then
						error(`{name} density: {table.concat(bad, "; ")}`)
					end
				end
			end
			-- the guard that the exemption means something: without it the rule would fail (a banner does stand within NAV_GAP of the
			-- edge that leaves its gate)
			expect(needed).toBeGreaterThan(0)
		end
	)

	it(
		"MUTANT: the dressing cart back where it was nudged onto a nav edge, a banner away from a gate and a non-banner in a banner's place are caught",
		function()
			local list = WorldPlan.props(Layout, ALL, FULL)
			local keep = Layout.plots.crimson.anchors.keep
			local pieces = dressingOf(list, "crimson")
			expect(#dressingNavProblems("crimson", pieces)).toBe(0) -- as placed: nothing
			local cart, banner, outer = 0, 0, 0
			for i, piece in pieces do
				if piece.assetId == "prop_cart_02" and piece.x < 0 then
					cart = i -- the hand-placed cart (the yard's stands at x = +38)
				elseif string.find(piece.assetId, "^prop_banner_") then
					banner = if banner == 0 then i else banner
					if #navProblems("crimson", { piece }) > 0 then
						outer = i -- the banner that stands within NAV_GAP of the gate's outgoing edge
					end
				end
			end
			expect(cart).toBeGreaterThan(0)
			expect(outer).toBeGreaterThan(0)
			expect(pieces[cart].x).toBeNear(-50, 0.01) -- WorldPlan.plan: keep frame (-50, 10), where clear() leaves it
			expect(pieces[cart].z).toBeNear(10, 0.01)
			-- the cart where the clearance once left it (it was planned at (-76, 2), nudged to about (-63, 1): 0.06 to 1.51 studs off nav edge 4)
			expect(#dressingNavProblems("crimson", with("crimson", pieces, cart, -63, 1))).toBeGreaterThan(0)
			-- the same, by the real route: a plan with the cart at (-76, 2), cleared by WorldPlan.clear
			local old = keep:PointToWorldSpace(Vector3.new(-76, 0, 2))
			local replanned = {}
			for _, p in WorldPlan.plan(Layout, ALL) do
				local q = p
				if
					p.feature == "dressing"
					and p.assetId == "prop_cart_02"
					and nearestKeep(p.cframe) == "crimson"
					and keep:PointToObjectSpace(p.cframe.Position).X < 0
				then
					q = {
						assetId = p.assetId,
						feature = p.feature,
						cframe = CFrame.new(old) * (p.cframe - p.cframe.Position),
					}
				end
				table.insert(replanned, q)
			end
			expect(#dressingNavProblems("crimson", dressingOf(WorldPlan.clear(Layout, replanned), "crimson"))).toBeGreaterThan(
				0
			)
			-- a banner away from a gate (here on the avenue, 65 studs from the gate node) is not exempt ...
			expect(isGateBanner("crimson", pieces[banner])).toBe(true)
			expect(isGateBanner("crimson", with("crimson", pieces, banner, 0, -45)[banner])).toBe(false)
			expect(#dressingNavProblems("crimson", with("crimson", pieces, banner, 0, -45))).toBeGreaterThan(0)
			-- ... and a banner is exempt at ITS OWN gate only: another kingdom's banner here is held to the rule
			local other = pieceOf("azure", { assetId = pieces[outer].assetId, cframe = pieces[outer].cframe })
			expect(isGateBanner("azure", other)).toBe(false)
			-- a prop of another kind where the banner stands (within reach of the gate, but not a banner) is not exempt either
			local swapped = table.clone(pieces)
			swapped[outer] = table.clone(pieces[outer])
			swapped[outer].assetId = "prop_goods_01"
			expect(isGateBanner("crimson", swapped[outer])).toBe(false)
			expect(#dressingNavProblems("crimson", swapped)).toBeGreaterThan(0)
		end
	)

	it(
		"stands on legal ground in every kingdom, off the door's sightline and the focal pair's ring, overlapping nothing",
		function()
			for _, k in KINGDOMS do
				local pieces = yardOf(planAll, k)
				expect(table.concat(legalityProblems(k, pieces), "; ")).toBe("")
				expect(table.concat(openGroundProblems(k, pieces), "; ")).toBe("")
			end
		end
	)

	it(
		"MUTANT: a cross on a lane, a stall in the focal ring, a crate across the sightline, a hedge on a slot and a hedge on a stall are caught",
		function()
			local rows = rowsOf("crimson")
			local pieces = yardOf(planAll, "crimson")
			local cross = indexOf(rows, "prop_cross_", nil)
			local stall = indexOf(rows, "prop_stall_", true)
			local hedge = indexOf(rows, "prop_hedge_01", true)
			local cart = indexOf(rows, "prop_cart_", nil)
			expect(#legalityProblems("crimson", with("crimson", pieces, cross, -22, -34))).toBeGreaterThan(0) -- on the store lane
			expect(#openGroundProblems("crimson", with("crimson", pieces, stall, 8, -38))).toBeGreaterThan(0) -- in the well's ring
			expect(#openGroundProblems("crimson", with("crimson", pieces, cart, 0, -36))).toBeGreaterThan(0) -- across the sightline
			expect(#legalityProblems("crimson", with("crimson", pieces, hedge, 20, -82))).toBeGreaterThan(0) -- on a build slot
			expect(#openGroundProblems("crimson", with("crimson", pieces, hedge, 8, -48))).toBeGreaterThan(0) -- against a stall
			expect(#legalityProblems("crimson", with("crimson", pieces, cart, 30, -60))).toBeGreaterThan(0) -- on the cross street
		end
	)

	it(
		"stands on flat ground in every kingdom: the ground height over the yard's rectangle is the ground level",
		function()
			for _, k in KINGDOMS do
				local bad = groundProblems(k, groundHeightOf)
				if #bad > 0 then
					error(`{#bad} points, e.g. {table.concat(bad, "; ", 1, math.min(#bad, 3))}. {FLAT_HINT}`)
				end
				local high = pieceHeightProblems(k, yardOf(planAll, k))
				if #high > 0 then
					error(`{table.concat(high, "; ")}. {FLAT_HINT}`)
				end
			end
		end
	)

	it(
		"MUTANT: a swell under the yard (the whole of it, a corner of it or a barely visible one) and a raised piece are caught",
		function()
			for _, k in KINGDOMS do
				expect(#groundProblems(k, swelled(k, 2))).toBeGreaterThan(0) -- the ground +2 inside the rectangle
				expect(#groundProblems(k, swelled(k, 2, 30))).toBeGreaterThan(0) -- under the cart's corner alone
				expect(#groundProblems(k, swelled(k, 0.1))).toBeGreaterThan(0) -- just over the tolerance
				expect(#groundProblems(k, swelled(k, 0.04))).toBe(0) -- under it: the tolerance is a tolerance, not a trip wire
				local pieces = table.clone(yardOf(planAll, k))
				expect(#pieceHeightProblems(k, pieces)).toBe(0)
				local raised = table.clone(pieces[1])
				raised.cframe = raised.cframe + Vector3.new(0, 2, 0)
				pieces[1] = raised
				expect(#pieceHeightProblems(k, pieces)).toBeGreaterThan(0)
			end
		end
	)

	it("keeps trees, bushes, rocks and flowers off every piece", function()
		for _, k in KINGDOMS do
			local polys = {}
			for _, piece in yardOf(planAll, k) do
				table.insert(polys, footprint(piece))
			end
			local bad = {}
			for _, p in clearedAll do
				if NATURAL[p.feature] and nearestKeep(p.cframe) == k then
					local at = Vector2.new(p.cframe.Position.X, p.cframe.Position.Z)
					for _, poly in polys do
						if polySeg(poly, at, at) < 1.5 then
							table.insert(bad, `{k} {p.assetId} at ({math.floor(at.X)}, {math.floor(at.Y)})`)
						end
					end
				end
			end
			expect(table.concat(bad, "; ")).toBe("")
		end
	end)

	it(
		"is axial: the focal pair, the stalls and the hedge rows mirror each other about the avenue, the stalls face the focal piece",
		function()
			for _, k in KINGDOMS do
				expect(table.concat(axialProblems(rowsOf(k)), "; ")).toBe("")
			end
		end
	)

	it(
		"MUTANT: a lopsided hedge, a stall turned away, a focal pair out of line and a mismatched hedge are caught",
		function()
			local good = rowsOf("crimson")
			local function mutated(change: ({ any }) -> ()): { any }
				local rows = {}
				for _, row in good do
					table.insert(rows, table.clone(row))
				end
				change(rows)
				return rows
			end
			expect(#axialProblems(mutated(function(rows)
				rows[indexOf(rows, "prop_hedge_01", true)].x += 1
			end))).toBeGreaterThan(0)
			expect(#axialProblems(mutated(function(rows)
				local i = indexOf(rows, "prop_stall_", false)
				rows[i].yaw += math.pi
			end))).toBeGreaterThan(0)
			expect(#axialProblems(mutated(function(rows)
				rows[indexOf(rows, "prop_cross_", nil)].z -= 3
			end))).toBeGreaterThan(0)
			expect(#axialProblems(mutated(function(rows)
				rows[indexOf(rows, "prop_hedge_01", false)].id = "prop_hedge_02"
			end))).toBeGreaterThan(0)
			expect(#axialProblems(mutated(function(rows)
				rows[indexOf(rows, "prop_well_", nil)].role = "flank"
			end))).toBeGreaterThan(0)
		end
	)

	it("is the same yard in every kingdom's own frame, the canopy and pennant colour apart", function()
		local crimson = yardOf(planAll, "crimson")
		for _, k in KINGDOMS do
			local pieces = yardOf(planAll, k)
			expect(#pieces).toBe(#crimson)
			local rows = rowsOf(k)
			for i, piece in pieces do
				local row = rows[i]
				expect(piece.assetId).toBe(row.id)
				expect(math.abs(piece.x - row.x)).toBeLessThan(1e-3)
				expect(math.abs(piece.z - row.z)).toBeLessThan(1e-3)
				local turn = (piece.yaw - row.yaw + math.pi) % (2 * math.pi) - math.pi
				expect(math.abs(turn)).toBeLessThan(1e-3)
				-- against crimson's: the same id but for the colour of the stall and the cross
				local a = (string.gsub(piece.assetId, "^(prop_%a+)_%a+_(%d+)$", "%1_*_%2"))
				local b = (string.gsub(crimson[i].assetId, "^(prop_%a+)_%a+_(%d+)$", "%1_*_%2"))
				expect(a).toBe(b)
				expect(math.abs(piece.x - crimson[i].x)).toBeLessThan(1e-3)
				expect(math.abs(piece.z - crimson[i].z)).toBeLessThan(1e-3)
			end
			-- the stalls and the cross wear their kingdom's colour (config/Kingdoms)
			local want
			for _, identity in KingdomsConfig.identities do
				if identity.id == k then
					want = Color3.fromRGB(identity.color[1], identity.color[2], identity.color[3])
				end
			end
			local stalls, crosses = 0, 0
			for _, piece in pieces do
				if string.find(piece.assetId, "^prop_stall_") then
					stalls += 1
					expect(Kit.prop(piece.assetId):FindFirstChild("Canopy").Color == want).toBe(true)
				elseif string.find(piece.assetId, "^prop_cross_") then
					crosses += 1
					expect(Kit.prop(piece.assetId):FindFirstChild("Pennant").Color == want).toBe(true)
				end
			end
			expect(stalls).toBe(2)
			expect(crosses).toBe(1)
		end
	end)

	it("is inside the start camera's picture, the axial pieces in its lower half", function()
		for _, k in KINGDOMS do
			-- the camera of the start view (the controller's: zoom 70, FOV 55, ahead 20, pitch 42.5, turn 180: looking back across the yard)
			local root = StartView.root(Kit, Layout, k)
			local focus = CameraDef.startFocus(root, START.ahead)
			local yaw = CameraDef.startYaw(root, START.turn) :: number
			local flat = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) -- the way the camera looks, on the ground
			local pitch = math.rad(START.pitch)
			local position = focus
				- flat * (START.zoom * math.cos(pitch))
				+ Vector3.new(0, START.zoom * math.sin(pitch), 0)
			local forward = flat * math.cos(pitch) + Vector3.new(0, -math.sin(pitch), 0)
			local right = flat:Cross(Vector3.yAxis)
			local up = right:Cross(forward)
			local ty = math.tan(math.rad(START.fov / 2))
			local tx = ty * 16 / 9
			local rows = rowsOf(k)
			for i, piece in yardOf(planAll, k) do
				local v = piece.cframe.Position + Vector3.new(0, 2, 0) - position
				local depth = v:Dot(forward)
				local sx, sy = v:Dot(right) / (depth * tx), v:Dot(up) / (depth * ty)
				local rowFrac = (sy + 1) / 2 -- 0 at the bottom of the picture .. 1 at the top
				expect(math.abs(sx)).toBeLessThan(1)
				expect(rowFrac).toBeGreaterThan(0.02)
				if rows[i].role ~= "flank" then
					expect(rowFrac).toBeLessThan(0.55) -- the axial composition fills the lower half, where the grass was bare
				end
			end
		end
	end)

	it("is deterministic and the same whichever other kingdoms are dressed", function()
		local a, b = WorldPlan.plan(Layout, ALL), WorldPlan.plan(Layout, ALL)
		for _, k in KINGDOMS do
			local ya, yb = yardOf(a, k), yardOf(b, k)
			expect(#ya).toBe(#yb)
			for i, p in ya do
				expect(sameCFrame(p.cframe, yb[i].cframe)).toBe(true)
			end
			local alone = yardOf(WorldPlan.plan(Layout, { [k] = true }), k)
			expect(#alone).toBe(#ya)
			for i, p in alone do
				expect(sameCFrame(p.cframe, ya[i].cframe)).toBe(true)
			end
			-- WorldPlan.yard is the same list
			local direct = WorldPlan.yard(Layout, k)
			expect(#direct).toBe(#ya)
			for i, p in direct do
				expect(sameCFrame(p.cframe, ya[i].cframe)).toBe(true)
			end
		end
	end)

	it("is left exactly where it is by WorldPlan.clear and by the density trim", function()
		local trimmed = WorldPlan.props(Layout, ALL)
		local untrimmed = WorldPlan.props(Layout, ALL, FULL)
		for _, k in KINGDOMS do
			local planned = yardOf(planAll, k)
			for _, after in { yardOf(clearedAll, k), yardOf(trimmed, k), yardOf(untrimmed, k) } do
				expect(#after).toBe(#planned)
				for i, p in planned do
					expect(after[i].assetId).toBe(p.assetId)
					expect(sameCFrame(p.cframe, after[i].cframe)).toBe(true)
				end
			end
		end
	end)

	-- The yard's new props (the cross, the stalls and the hedges) are part-built props that are NOT in the imported-mesh data
	-- (Kit/EnvMeshData): Kit.envMeshReady is false for them, so Kit.prop builds the part-built model whatever the asset source, and this
	-- fails if one of these ids is ever added to that data. (The yard's cart, haystack and well are older props; none of them is in the
	-- data today, which this spec does not pin.)
	it("never builds the new ids from the imported-mesh kit: part-built props, not in its data", function()
		for _, id in
			{
				"prop_cross_red_01",
				"prop_cross_blue_01",
				"prop_cross_green_01",
				"prop_cross_yellow_01",
				"prop_stall_red_01",
				"prop_stall_blue_01",
				"prop_stall_green_01",
				"prop_stall_yellow_01",
				"prop_hedge_01",
				"prop_hedge_02",
			}
		do
			expect(isYardId(id)).toBe(true)
			expect(Kit.envMeshReady(id)).toBe(false)
			expect(Kit.prop(id):GetAttribute("KitStandIn")).toBe(true)
		end
	end)
end)

describe(
	"The yard in the built world (WorldService, FORGE-00's decision of 2026-10-22: all four kingdoms dressed)",
	function()
		local function build(dressed: { [string]: boolean }?)
			local env = MockEnv.new({ seed = 1 })
			local svc = WorldDef.new(env, nil)
			svc.terrain = Terrain.recorder()
			if dressed then
				svc.dressed = dressed
			end
			svc:start()
			env.mock:advance(30)
			expect(svc.stats.error).toBeNil()
			return { props = svc.stats.props, parts = svc.stats.parts - svc.stats.arenaParts, svc = svc }
		end

		it("dresses all four kingdoms by default, so every one of them has its yard", function()
			local out = build(nil)
			for _, k in KINGDOMS do
				expect(out.svc.dressed[k]).toBe(true)
			end
			local crosses = 0
			for _, d in out.svc:getRoot():GetDescendants() do
				if d:IsA("Model") and string.find(d.Name, "^prop_cross_") then
					crosses += 1
				end
			end
			expect(crosses).toBe(4)
			out.svc:destroy()
		end)

		it(
			"costs 66 parts a kingdom: 6,280 world parts with crimson alone dressed, 6,720 with all four (arena apart)",
			function()
				-- the all-built ceiling (KitCeiling.spec): 26,086 with crimson alone, 26,526 with all four
				local crimson = build({ crimson = true })
				local all = build(nil)
				expect(crimson.parts).toBe(6280)
				expect(all.parts).toBe(6720)
				expect(all.props - crimson.props).toBe(54) -- 3 kingdoms x 18 dressing placements (4 banners, 4 hand-placed, 10 of the yard)
				crimson.svc:destroy()
				all.svc:destroy()
			end
		)
	end
)
