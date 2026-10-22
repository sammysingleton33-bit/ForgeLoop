--[[
	The composed start yard (FORGE-02 visual pass 1b; the owner's P0: "the world feels empty", "buildings look disconnected, not like a
	village"). The start camera (FL-0147: zoom 70, FOV 55, ahead 20, looking back across the yard at the keep) shows, in the bottom 40 % of
	its picture, the court, the lanes and flat grass. WorldPlan.yard composes that ground as a village centre: a market cross at the
	court's centre, two market stalls turned to the cross with a canopy in the kingdom colour, a hedge either side of the avenue mouth,
	a cart and a haystack on the farm's side and crates on the store's side.
	HEADLESS (Lune): placements, part counts and arithmetic, not a look; the renders are the evidence for the look.

	What this pins, in every kingdom (the composition is written once in the keep's frame and the four yards are rotated copies):
	  * the part budget (<= 70 parts a dressed kingdom: D-047), what each new prop costs, and that only dressed kingdoms get a yard;
	  * every piece stands on legal ground: off the lanes, roads, slots, buildings and fields by what it draws (the live Kit.prop bounds);
	    the cross alone stands on the avenue road, at the court's middle, where the avenue ends; nothing in the cross's walking ring or
	    on the keep door's sightline; no two pieces overlap; every axial piece is inside the start camera's picture;
	  * it is axial: the stalls and the hedges mirror each other about the avenue's axis and the stalls face the cross;
	  * it is deterministic, identical in every kingdom in the kingdom's own frame (only the canopy colour differs), and WorldPlan.clear
	    and the shipped density trim remove or move none of it.
	Each measure has a MUTANT (the cross on a lane, a stall in the ring, a lopsided hedge, an overfull yard, a stall turned away, a prop
	across the door's sightline) that must trip it.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local StartView = require("./support/StartView")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local COLOUR = { crimson = "red", azure = "blue", emerald = "green", gold = "yellow" }
local ALL = { crimson = true, azure = true, emerald = true, gold = true }
local FULL = WorldPlan.FULL_DENSITY
local Y = WorldPlan.YARD

local BUDGET = 70 -- parts a dressed kingdom's yard may cost (the brief: replaces the stopgap's 56, D-047)
local GAP = 1 -- studs of open ground a piece keeps off a lane, a road, a slot or a building beyond what it draws (a field: 4)
local FIELD_GAP = 4
local DOOR_HALF = 4 -- the keep door's sightline: studs either side of the avenue's axis, from the door to the cross
local TOL = 1e-6

local function isYardId(id: string): boolean
	return string.find(id, "^prop_cross_") ~= nil
		or string.find(id, "^prop_stall_") ~= nil
		or string.find(id, "^prop_hedge_") ~= nil
end

-- ---- the model's own measures (live Kit.prop, like PlotClearance.spec: a prop that grows fails here)

local function partsOf(id: string): number
	return Kit.partCount(Kit.prop(id))
end

local live: { [string]: { radius: number, lo: Vector3, hi: Vector3 } } = {}
-- radius: farthest reach of a visible part from the pivot on the ground plane; lo/hi: the local XZ bounds of the visible parts
local function measure(id: string)
	local m = live[id]
	if m then
		return m
	end
	local model = Kit.prop(id)
	local pivot = model.PrimaryPart.CFrame * model.PrimaryPart.PivotOffset
	local lo, hi, r = Vector3.new(1e9, 0, 1e9), Vector3.new(-1e9, 0, -1e9), 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local v = (rel * CFrame.new(sx * h.X, 0, sz * h.Z)).Position
					lo = Vector3.new(math.min(lo.X, v.X), 0, math.min(lo.Z, v.Z))
					hi = Vector3.new(math.max(hi.X, v.X), 0, math.max(hi.Z, v.Z))
					r = math.max(r, math.sqrt(v.X * v.X + v.Z * v.Z))
				end
			end
		end
	end
	m = { radius = r, lo = lo, hi = hi }
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

-- the yard placements WorldPlan.plan(ALL) holds for a kingdom (the pieces of the new ids and the hand-placed trade beside them)
local function yardOf(list: { any }, kingdom: string): { Piece }
	local keep = Layout.plots[kingdom].anchors.keep
	local rows = WorldPlan.yardRows(COLOUR[kingdom])
	local out = {}
	for _, p in list do
		if p.feature == "dressing" and nearestKeep(p.cframe) == kingdom then
			for _, row in rows do
				if row.id == p.assetId then
					local lp = keep:PointToObjectSpace(p.cframe.Position)
					if math.abs(lp.X - row.x) < 1 and math.abs(lp.Z - row.z) < 1 then
						table.insert(out, pieceOf(kingdom, p))
						break
					end
				end
			end
		end
	end
	return out
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

-- ---- reserved ground, rebuilt from Layout and Kit.footprint the way PlotClearance.spec does (zones are where the yard stands)

local function rectDistance(cf: CFrame, half: Vector2, x: number, z: number): number
	local p = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
	local dx, dz = math.max(0, math.abs(p.X) - half.X), math.max(0, math.abs(p.Z) - half.Y)
	return math.sqrt(dx * dx + dz * dz)
end

local reservedList: { { cf: CFrame, half: Vector2, label: string, field: boolean } }? = nil
local function reserved()
	if reservedList then
		return reservedList
	end
	local out = {}
	for i, field in Layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		table.insert(out, { cf = cf, half = field.size / 2, label = `field {i}`, field = true })
	end
	for _, k in KINGDOMS do
		local plot = Layout.plots[k]
		for name, anchor in plot.anchors do
			table.insert(out, { cf = anchor, half = Kit.footprint(name, 99) / 2, label = `{k} {name}`, field = false })
		end
		for _, slot in plot.buildSlots do
			local cf = CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
			table.insert(out, { cf = cf, half = Layout.slotSizes[slot.size] / 2, label = slot.id, field = false })
		end
	end
	reservedList = out
	return out
end

-- the court (WorldGround.worn): the keep-frame rectangle of its kerb, 22 x 26 centred at (0, -39)
local COURT_HALF = Vector2.new(11, 13)

-- the problems of the pieces of ONE kingdom's yard (empty = legal). `pieces` come from yardOf or a mutant.
local function legalityProblems(kingdom: string, pieces: { Piece }): { string }
	local keep = Layout.plots[kingdom].anchors.keep
	local court = keep * CFrame.new(Y.cross.X, 0, Y.cross.Y)
	local bad = {}
	local function say(piece: Piece, what: string)
		table.insert(
			bad,
			`{kingdom} {piece.assetId} at ({math.floor(piece.x + 0.5)}, {math.floor(piece.z + 0.5)}): {what}`
		)
	end
	for _, piece in pieces do
		local r = measure(piece.assetId).radius
		local isCross = string.find(piece.assetId, "^prop_cross_") ~= nil
		local at = piece.cframe.Position
		for _, rect in reserved() do
			local gap = if rect.field then FIELD_GAP else GAP
			if rectDistance(rect.cf, rect.half, at.X, at.Z) < r + gap then
				say(piece, `on {rect.label}`)
			end
		end
		-- a lane or a road that begins inside the court (the keep's door lane, the avenue) is laid under it and ends at the cross: the
		-- cross is the one piece that stands on those
		local function underCourt(points: { Vector2 }): boolean
			return isCross and rectDistance(court, COURT_HALF, points[1].X, points[1].Y) < 0.01
		end
		for i, lane in Layout.features.paths do
			if
				not underCourt(lane.points)
				and WorldPlan.distToPolyline(at.X, at.Z, lane.points) < lane.width / 2 + r + GAP
			then
				say(piece, `on lane {i} ({lane.name})`)
			end
		end
		for i, road in Layout.features.roads do
			if
				not underCourt(road.points)
				and WorldPlan.distToPolyline(at.X, at.Z, road.points) < road.width / 2 + r + GAP
			then
				say(piece, `on road {i}`)
			end
		end
		if isCross and math.sqrt((at.X - court.Position.X) ^ 2 + (at.Z - court.Position.Z) ^ 2) > 0.5 then
			say(piece, "is not at the middle of the court")
		end
	end
	return bad
end

-- the cross's walking ring and the door's sightline, for ONE kingdom's pieces
local function openGroundProblems(kingdom: string, pieces: { Piece }): { string }
	local bad = {}
	local cross
	for _, piece in pieces do
		if string.find(piece.assetId, "^prop_cross_") then
			cross = piece
		end
	end
	for _, piece in pieces do
		if piece ~= cross then
			local r = measure(piece.assetId).radius
			if cross then
				local d = math.sqrt((piece.x - cross.x) ^ 2 + (piece.z - cross.z) ^ 2)
				if d < measure(cross.assetId).radius + Y.ring + r then
					table.insert(bad, `{kingdom} {piece.assetId} at ({piece.x}, {piece.z}) stands in the cross's ring`)
				end
			end
			-- the sightline: the strip |x| < DOOR_HALF from the door (z = -23) to the cross's near edge, as a rectangle the piece's circle
			-- must not reach
			local zLow = (if cross then cross.z + measure(cross.assetId).radius else -34)
			local dx = math.max(0, math.abs(piece.x) - DOOR_HALF)
			local dz = math.max(0, zLow - piece.z, piece.z - Y.door.Y)
			if math.sqrt(dx * dx + dz * dz) < r then
				table.insert(
					bad,
					`{kingdom} {piece.assetId} at ({piece.x}, {piece.z}) stands across the door's sightline`
				)
			end
		end
	end
	return bad
end

-- local XZ footprints of two pieces overlap (oriented rectangles, SAT), with `gap` studs between them still counted as overlap
local function corners(piece: Piece): { Vector2 }
	local m = measure(piece.assetId)
	local out = {}
	for _, sx in { m.lo.X, m.hi.X } do
		for _, sz in { m.lo.Z, m.hi.Z } do
			local v = piece.cframe * Vector3.new(sx, 0, sz)
			table.insert(out, Vector2.new(v.X, v.Z))
		end
	end
	return out
end

local function overlap(a: Piece, b: Piece, gap: number): boolean
	local ca, cb = corners(a), corners(b)
	for _, piece in { a, b } do
		local look, right = piece.cframe.LookVector, piece.cframe.RightVector
		for _, axis in { Vector2.new(look.X, look.Z), Vector2.new(right.X, right.Z) } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in ca do
				aMin, aMax = math.min(aMin, c:Dot(axis)), math.max(aMax, c:Dot(axis))
			end
			for _, c in cb do
				bMin, bMax = math.min(bMin, c:Dot(axis)), math.max(bMax, c:Dot(axis))
			end
			if aMax + gap < bMin or bMax + gap < aMin then
				return false
			end
		end
	end
	return true
end

local function overlapProblems(kingdom: string, pieces: { Piece }): { string }
	local bad = {}
	for i = 1, #pieces do
		for j = i + 1, #pieces do
			if overlap(pieces[i], pieces[j], 0.5) then
				table.insert(bad, `{kingdom} {pieces[i].assetId} and {pieces[j].assetId} overlap`)
			end
		end
	end
	return bad
end

-- axial: rows (keep-frame { id, x, z, yaw, role }) whose stalls and hedges are mirror images about x = 0, whose cross is on it and whose
-- stalls face the cross
local function axialProblems(rows: { any }): { string }
	local bad = {}
	for _, role in { "stall", "hedge" } do
		local right, left = {}, {}
		for _, row in rows do
			if row.role == role then
				table.insert(if row.x > 0 then right else left, row)
			end
		end
		if #right ~= 1 or #left ~= 1 then
			table.insert(bad, `{role}: {#right} right of the axis and {#left} left of it, want one each`)
		else
			local a, b = right[1], left[1]
			if
				a.id ~= b.id
				or math.abs(a.x + b.x) > TOL
				or math.abs(a.z - b.z) > TOL
				or math.abs(a.yaw + b.yaw) > TOL
			then
				table.insert(bad, `{role}: the two sides are not mirror images`)
			end
		end
	end
	for _, row in rows do
		if row.role == "cross" and math.abs(row.x) > TOL then
			table.insert(bad, "the cross is off the axis")
		elseif row.role == "stall" then
			-- the front (-Z turned by yaw) must point at the cross
			local fx, fz = -math.sin(row.yaw), -math.cos(row.yaw)
			local tx, tz = Y.cross.X - row.x, Y.cross.Y - row.z
			local len = math.sqrt(tx * tx + tz * tz)
			if (fx * tx + fz * tz) / len < math.cos(math.rad(2)) then
				table.insert(bad, "a stall does not face the cross")
			end
		end
	end
	return bad
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

-- a copy of a kingdom's yard with one piece replaced by (id, local x, z, yaw)
local function with(kingdom: string, pieces: { Piece }, index: number, x: number, z: number, yaw: number?): { Piece }
	local keep = Layout.plots[kingdom].anchors.keep
	local out = table.clone(pieces)
	local old = pieces[index]
	local p = keep:PointToWorldSpace(Vector3.new(x, 0, z))
	local y = yaw or old.yaw
	out[index] = {
		assetId = old.assetId,
		x = x,
		z = z,
		yaw = y,
		cframe = CFrame.new(p.X, p.Y, p.Z)
			* CFrame.Angles(0, math.atan2(-keep.LookVector.X, -keep.LookVector.Z) + y, 0),
	}
	return out
end

local function indexOfRole(rows: { any }, role: string, side: number): number
	for i, row in rows do
		if row.role == role and (side == 0 or (row.x > 0) == (side > 0)) then
			return i
		end
	end
	error(`no {role} row`)
end

describe("The composed start yard (FORGE-02 visual pass 1b)", function()
	it("is the new props and the trade beside the lanes, in the dressed kingdoms only", function()
		local rows = rowsOf("crimson")
		expect(#rows).toBe(9) -- the cross, 2 stalls, 2 hedges, a cart, a haystack, 2 crates
		for _, k in KINGDOMS do
			expect(#yardOf(planAll, k)).toBe(#rows)
		end
		-- a kingdom that is not dressed has none of it
		for _, only in KINGDOMS do
			local plan = WorldPlan.plan(Layout, { [only] = true })
			for _, k in KINGDOMS do
				local n = 0
				for _, p in plan do
					if p.feature == "dressing" and isYardId(p.assetId) and nearestKeep(p.cframe) == k then
						n += 1
					end
				end
				expect(n).toBe(if k == only then 5 else 0) -- the cross, 2 stalls, 2 hedges
			end
		end
		expect(#WorldPlan.yard(Layout, "azure")).toBe(#rows)
	end)

	it("costs at most 70 parts a dressed kingdom and its new props are as small as pinned", function()
		expect(partsOf("prop_cross_red_01")).toBe(8) -- 3 steps, a shaft, an arm, a pennant, a finial and the Root
		expect(partsOf("prop_stall_red_01")).toBe(9) -- counter, crate, back wall, 2 posts, canopy, 2 stripes and the Root
		expect(partsOf("prop_hedge_01")).toBe(5) -- 4 leafy balls and the Root (12 long)
		expect(partsOf("prop_hedge_02")).toBe(3) -- 2 balls and the Root (6.5 long)
		for _, k in KINGDOMS do
			local pieces = yardOf(planAll, k)
			local n = budgetOf(idsOf(pieces))
			expect(n).toBe(66) -- 8 + 2 x 9 + 2 x 5 + cart 10 + haystack 4 + 2 x 8 crates
			expect(n).toBeLessThanOrEqual(BUDGET)
		end
		-- the stalls differ by colour alone
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

	it(
		"stands on legal ground in every kingdom, off the court's ring and the door's sightline, overlapping nothing",
		function()
			for _, k in KINGDOMS do
				local pieces = yardOf(planAll, k)
				expect(table.concat(legalityProblems(k, pieces), "; ")).toBe("")
				expect(table.concat(openGroundProblems(k, pieces), "; ")).toBe("")
				expect(table.concat(overlapProblems(k, pieces), "; ")).toBe("")
			end
		end
	)

	it(
		"MUTANT: the cross on a lane, a stall in the cross's ring, a crate across the door's sightline and a hedge on a slot are caught",
		function()
			local rows = rowsOf("crimson")
			local pieces = yardOf(planAll, "crimson")
			-- the pieces come back in the rows' order
			for i, row in rows do
				expect(pieces[i].assetId).toBe(row.id)
			end
			local cross = indexOfRole(rows, "cross", 0)
			local stall = indexOfRole(rows, "stall", 1)
			local hedge = indexOfRole(rows, "hedge", 1)
			expect(#legalityProblems("crimson", with("crimson", pieces, cross, 20, -35))).toBeGreaterThan(0) -- on the farm lane
			expect(#legalityProblems("crimson", with("crimson", pieces, cross, 0, -50))).toBeGreaterThan(0) -- off the court's middle
			expect(#openGroundProblems("crimson", with("crimson", pieces, stall, 7, -44))).toBeGreaterThan(0) -- in the ring
			local crate = indexOfRole(rows, "flank", -1)
			expect(#openGroundProblems("crimson", with("crimson", pieces, crate, 0, -28))).toBeGreaterThan(0) -- across the sightline
			expect(#legalityProblems("crimson", with("crimson", pieces, hedge, 20, -82))).toBeGreaterThan(0) -- on a build slot
			expect(#overlapProblems("crimson", with("crimson", pieces, hedge, 14, -48))).toBeGreaterThan(0) -- against a stall
		end
	)

	it("is axial: the stalls and the hedges mirror each other about the avenue, the stalls face the cross", function()
		for _, k in KINGDOMS do
			expect(table.concat(axialProblems(rowsOf(k)), "; ")).toBe("")
		end
		-- and the placements in the world are those rows turned with the keep (checked per kingdom below)
	end)

	it("MUTANT: a lopsided hedge, a stall turned away and an off-axis cross are caught", function()
		local good = rowsOf("crimson")
		local function mutated(change: (any) -> ()): { any }
			local rows = {}
			for _, row in good do
				table.insert(rows, table.clone(row))
			end
			change(rows)
			return rows
		end
		expect(#axialProblems(mutated(function(rows)
			rows[indexOfRole(rows, "hedge", 1)].x += 1
		end))).toBeGreaterThan(0)
		expect(#axialProblems(mutated(function(rows)
			rows[indexOfRole(rows, "stall", -1)].yaw = rows[indexOfRole(rows, "stall", -1)].yaw + math.pi
		end))).toBeGreaterThan(0)
		expect(#axialProblems(mutated(function(rows)
			rows[indexOfRole(rows, "cross", 0)].x = 3
		end))).toBeGreaterThan(0)
		expect(#axialProblems(mutated(function(rows)
			rows[indexOfRole(rows, "hedge", -1)].id = "prop_hedge_02"
		end))).toBeGreaterThan(0)
	end)

	it("is the same yard in every kingdom's own frame, the canopy colour apart", function()
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
				-- against crimson's: the same id but for the stall's colour
				local a = (string.gsub(piece.assetId, "^(prop_%a+)_%a+_(%d+)$", "%1_*_%2"))
				local b = (string.gsub(crimson[i].assetId, "^(prop_%a+)_%a+_(%d+)$", "%1_*_%2"))
				expect(a).toBe(b)
				expect(math.abs(piece.x - crimson[i].x)).toBeLessThan(1e-3)
				expect(math.abs(piece.z - crimson[i].z)).toBeLessThan(1e-3)
			end
			-- the stalls wear their kingdom's colour (config/Kingdoms)
			local want
			for _, identity in KingdomsConfig.identities do
				if identity.id == k then
					want = Color3.fromRGB(identity.color[1], identity.color[2], identity.color[3])
				end
			end
			local stalls = 0
			for _, piece in pieces do
				if string.find(piece.assetId, "^prop_stall_") then
					stalls += 1
					local canopy = Kit.prop(piece.assetId):FindFirstChild("Canopy")
					expect(canopy.Color == want).toBe(true)
				end
			end
			expect(stalls).toBe(2)
		end
	end)

	it(
		"is inside the start camera's picture, the focus below the keep door and the whole of it in the lower part",
		function()
			for _, k in KINGDOMS do
				-- the camera of the start view (zoom 70, FOV 55, ahead 20, pitch 42.5, looking back across the yard)
				local root = StartView.root(Kit, Layout, k)
				local look = root.LookVector
				local facing = Vector3.new(look.X, 0, look.Z).Unit
				local focus = root.Position + facing * 20
				local flat = -facing
				local pitch = math.rad(42.5)
				local position = focus - flat * (70 * math.cos(pitch)) + Vector3.new(0, 70 * math.sin(pitch), 0)
				local forward = flat * math.cos(pitch) + Vector3.new(0, -math.sin(pitch), 0)
				local right = flat:Cross(Vector3.yAxis)
				local up = right:Cross(forward)
				local ty = math.tan(math.rad(55 / 2))
				local tx = ty * 16 / 9
				for _, piece in yardOf(planAll, k) do
					local role = if string.find(piece.assetId, "^prop_cross_")
						then "cross"
						elseif string.find(piece.assetId, "^prop_stall_") then "stall"
						elseif string.find(piece.assetId, "^prop_hedge_") then "hedge"
						else "flank"
					local v = piece.cframe.Position + Vector3.new(0, 2, 0) - position
					local depth = v:Dot(forward)
					local sx, sy = v:Dot(right) / (depth * tx), v:Dot(up) / (depth * ty)
					local rowFrac = (sy + 1) / 2 -- 0 at the bottom of the picture .. 1 at the top
					expect(math.abs(sx)).toBeLessThan(1)
					expect(rowFrac).toBeGreaterThan(0.02)
					if role ~= "flank" then
						expect(rowFrac).toBeLessThan(0.55) -- the axial composition fills the bottom half, where the grass was bare
					end
				end
			end
		end
	)

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

	it("is left exactly where it is by WorldPlan.clear and by the shipped density trim", function()
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

	it("MUTANT: a stall dropped on a lane is moved by the clearance (so the check above would see it)", function()
		local lane
		for _, l in Layout.features.paths do
			if l.kingdom == "crimson" and l.name == "farm" then
				lane = l
			end
		end
		local mid = (lane.points[1] + lane.points[2]) / 2
		local stall = {
			assetId = "prop_stall_red_01",
			cframe = CFrame.new(mid.X, 0, mid.Y),
			feature = "dressing",
		}
		local out = WorldPlan.clear(Layout, { stall })
		expect(#out).toBe(1)
		expect((out[1].cframe.Position - stall.cframe.Position).Magnitude).toBeGreaterThan(0.5)
	end)

	it("never builds the new ids from the imported-mesh kit: they are part-built whatever the asset source", function()
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
			local out = { props = svc.stats.props, parts = svc.stats.parts - svc.stats.arenaParts, svc = svc }
			return out
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
				expect(all.props - crimson.props).toBe(51) -- 3 kingdoms x 17 dressing placements (4 banners, 4 hand-placed, 9 of the yard)
				crimson.svc:destroy()
				all.svc:destroy()
			end
		)
	end
)
