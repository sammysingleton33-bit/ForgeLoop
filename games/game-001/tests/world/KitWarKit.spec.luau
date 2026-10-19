--[[
	The war kit's structures (FL-0128, FORGE-02, Operation Crownfall): walls and gates at three levels, the war-ready
	watchtower and the battering ram. Everything is part-built (D-026) and kingdom-tinted. This spec pins:

	  1. levels    wall L1-3 and gate L1-3: distinct (level-specific parts, rising height), within their per-level part
	               caps (wall 30/45/60, gate 90/120/150) for every kingdom, footprints unchanged (32x8, 32x12), the Door
	               (and the gate's Rally) attachments where they were;
	  1b. wallL3   the L3 wall has its OWN outline (end piers and a pedestal brazier above the L2 crenellation, buttresses
	               up the front that reach the walkway, fuller banners between them) and the brazier sits on a plinth that
	               rests on the walkway, never in a gap of the crenellation;
	  1c. gateShape the lintel reaches the tower tops (no saddle), the voussoirs lie flush on the lintel face (nothing floats
	               in front of the facade), a recessed tympanum fills the arch above the closed leaves at every level (no sky
	               shows through, at L3 behind the portcullis), the passage floor is a MID tone (luminance 0.25 to 0.6, never
	               near-black) at least 0.15 from the wall of every kingdom;
	  1d. palisade the L1 palisade is the same dark timber in all four kingdoms (the banner carries the kingdom);
	  2. gatePose  Kit.setGateOpen moves leaves and portcullis by CFrame alone: no part added or removed, exactly the
	               movable parts move, the round trip is exact, a moved and turned gate still opens, BOTH open leaves stand
	               swung into the passage (face to the front, middle clear, outside the towers), the closed ones span it,
	               the portcullis lifts clear of the opening (hidden in the lintel), the recolour keeps the pose;
	  3. tower     watchtower L2 is war-ready (hoarding galleries, braziers, more merlons, slits) within its cap;
	  4. ram       Kit.siege("ram"): at most 45 parts, the character rig conventions (Root anchored and invisible, feet
	               at y = 0, front -Z, every other part welded, Massless, non-colliding) and ONE Motor6D "Log" that
	               Kit.siegePose drives (clamped, monotone, exactly Siege.THRUST_TRAVEL forward at 1); the LOG is the
	               silhouette (long, thick, pale, an iron WEDGE head, projecting well past a low roof, visible from the
	               side at thrust 0), the kingdom colour on the roof only;
	  5. mutants   the key rules above are caught when broken.
	The soldier unit kinds are pinned by KitUnitKinds.spec, the damage states by KitDamage.spec, and the all-built part
	ceiling (D-047) by the world spec; footprints and placement of every other building are in KitBuildings.spec.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Buildings = require("@game/ReplicatedStorage/Game/Kit/Buildings")
local Siege = require("@game/ReplicatedStorage/Game/Kit/Siege")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local HUES = { "crimson", "azure", "emerald", "gold" }
local EMBLEMS = { crimson = "crown", azure = "star", emerald = "oak", gold = "sun" }

-- ------------------------------------------------------------------ helpers

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function count(model: Instance): number
	return #parts(model)
end

local function hist(model: Instance): { [string]: number }
	local h: { [string]: number } = {}
	for _, p in parts(model) do
		h[p.Name] = (h[p.Name] or 0) + 1
	end
	return h
end

-- half extents of a part's world-axis-aligned box

local function halfExtents(p: BasePart): Vector3
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		(math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
	)
end

local function topOf(model: Instance, skipDamage: boolean?): number
	local top = -math.huge
	for _, p in parts(model) do
		if p.Transparency < 1 and not (skipDamage and p:GetAttribute("KitDamage") == true) then
			top = math.max(top, p.CFrame.Position.Y + halfExtents(p).Y)
		end
	end
	return top
end

local function r3(n: number): string
	local v = math.floor(n * 1000 + 0.5) / 1000
	return if v == 0 then "0" else tostring(v)
end

-- every part as one line (name, class, shape, size, cframe, colour, material, transparency), sorted

local function signature(model: Instance, withCFrame: boolean?): string
	local rows = {}
	for _, p in parts(model) do
		local shape = if p:IsA("Part") then (p :: Part).Shape.Name else p.ClassName
		local s = p.Size
		local cf = ""
		if withCFrame ~= false then
			local comps = { p.CFrame:GetComponents() }
			for i, v in comps do
				comps[i] = r3(v)
			end
			cf = table.concat(comps, ",")
		end
		table.insert(
			rows,
			`{p.Name}|{p.ClassName}|{shape}|{r3(s.X)},{r3(s.Y)},{r3(s.Z)}|{cf}|{p.Color:ToHex()}|{p.Material.Name}|{r3(
				p.Transparency
			)}`
		)
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

local function attachments(model: Model): { [string]: Vector3 }
	local out = {}
	for _, a in (model.PrimaryPart :: BasePart):GetChildren() do
		if a:IsA("Attachment") then
			out[a.Name] = (a :: Attachment).CFrame.Position
		end
	end
	return out
end

local function rel(model: Model, p: BasePart): CFrame
	return (model.PrimaryPart :: BasePart).CFrame:ToObjectSpace(p.CFrame)
end

local function localCFrames(model: Model): { [BasePart]: CFrame }
	local out = {}
	for _, p in parts(model) do
		out[p] = rel(model, p)
	end
	return out
end

local function cfDistance(a: CFrame, b: CFrame): number
	local worst = (a.Position - b.Position).Magnitude
	for _, pair in { { a.RightVector, b.RightVector }, { a.UpVector, b.UpVector }, { a.LookVector, b.LookVector } } do
		worst = math.max(worst, (pair[1] - pair[2]).Magnitude)
	end
	return worst
end

local function motors(model: Instance): { Motor6D }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(out, d)
		end
	end
	return out
end

local function noYield<R>(fn: () -> R): R
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "Kit yielded")
	return result
end

type Check = () -> { string }
local CHECKS: { [string]: Check } = {}

-- ------------------------------------------------------------------ 1. wall and gate levels

local function need(
	out: { string },
	tag: string,
	hs: { [string]: number },
	name: string,
	test: (number) -> boolean,
	why: string
)
	if not test(hs[name] or 0) then
		table.insert(out, `{tag}: {name} x{hs[name] or 0} ({why})`)
	end
end

local function exactly(n: number): (number) -> boolean
	return function(v)
		return v == n
	end
end
local function atLeast(n: number): (number) -> boolean
	return function(v)
		return v >= n
	end
end
local NONE = exactly(0)

CHECKS.levels = function()
	local out: { string } = {}
	local caps = Buildings.PART_BUDGET_BY_LEVEL
	if table.concat(caps.wall, ",") ~= "30,45,60" or table.concat(caps.gate, ",") ~= "90,120,150" then
		table.insert(out, "the per-level budget table is not wall 30/45/60, gate 90/120/150")
	end
	local rise = { wall = { 0, 4, 3 }, gate = { 0, 1.5, 1.5 } } -- the model's top must rise at least this much per level
	for _, bt in { "wall", "gate" } do
		local want = if bt == "wall" then Vector2.new(32, 8) else Vector2.new(32, 12)
		for _, hue in HUES do
			local prev, prevTop = 0, 0
			for lv = 1, 3 do
				local tag = `{bt} L{lv} {hue}`
				local m = Kit.build(bt, lv, "complete", CANON[hue])
				local n, top = count(m), topOf(m)
				if n > caps[bt][lv] then
					table.insert(out, `{tag}: {n} parts, over the cap {caps[bt][lv]}`)
				end
				if lv > 1 and n <= prev then
					table.insert(out, `{tag}: {n} parts, not more than level {lv - 1} ({prev})`)
				end
				if lv > 1 and top < prevTop + rise[bt][lv] - 0.01 then
					table.insert(
						out,
						`{tag}: top {r3(top)} does not rise {rise[bt][lv]} over level {lv - 1} ({r3(prevTop)})`
					)
				end
				prev, prevTop = n, top
				if Kit.footprint(bt, lv) ~= want then
					table.insert(out, `{tag}: footprint {Kit.footprint(bt, lv)} changed (pinned {want})`)
				end
				local hs = hist(m)
				if bt == "wall" then
					if lv == 1 then
						need(out, tag, hs, "Palisade", atLeast(10), "a timber palisade")
						for _, absent in { "Merlon", "Curtain", "Buttress", "BrazierBowl", "EndPier", "BrazierPlinth" } do
							need(out, tag, hs, absent, NONE, "stone parts belong to L2+")
						end
					else
						need(out, tag, hs, "Palisade", NONE, "stone from L2")
						need(out, tag, hs, "Curtain", exactly(1), "the stone curtain")
						need(out, tag, hs, "Merlon", atLeast(12), "crenellations")
						need(
							out,
							tag,
							hs,
							"Buttress",
							exactly(if lv == 3 then 6 else 0),
							"two stepped buttresses of three courses at L3 only"
						)
						need(out, tag, hs, "EndPier", exactly(if lv == 3 then 2 else 0), "two end piers at L3 only")
						need(out, tag, hs, "PierCap", exactly(if lv == 3 then 2 else 0), "their caps at L3 only")
						need(
							out,
							tag,
							hs,
							"BrazierPlinth",
							exactly(if lv == 3 then 1 else 0),
							"the brazier's plinth at L3 only"
						)
						need(
							out,
							tag,
							hs,
							"BrazierBowl",
							exactly(if lv == 3 then 1 else 0),
							"a walkway brazier at L3 only"
						)
						need(out, tag, hs, "Banner", exactly(if lv == 3 then 2 else 1), "banners")
					end
				else
					need(out, tag, hs, "GateLeaf", exactly(2), "two leaves")
					need(out, tag, hs, "GateTower", exactly(2), "two towers")
					need(out, tag, hs, "Lintel", exactly(1), "the arch")
					need(out, tag, hs, "Tympanum", exactly(1), "the door head fills the arch at every level")
					need(out, tag, hs, "LeafBand", exactly(if lv >= 2 then 4 else 0), "iron bands from L2")
					need(out, tag, hs, "Banner", exactly(if lv >= 2 then 2 else 0), "tower banners from L2")
					need(out, tag, hs, "PortcullisBar", exactly(if lv == 3 then 6 else 0), "a portcullis at L3")
					need(out, tag, hs, "Portcullis", exactly(if lv == 3 then 1 else 0), "its cross bar at L3")
					need(
						out,
						tag,
						hs,
						"BrazierBowl",
						exactly(if lv == 3 then 2 else 0),
						"two braziers at the foot at L3"
					)
				end
				-- attachment conventions
				local at = attachments(m)
				local door = at.Door
				if
					door == nil
					or (Vector3.new(door.X, 0, door.Z) - Vector3.new(0, 0, -want.Y / 2 - 2)).Magnitude > 0.01
				then
					table.insert(out, `{tag}: Door attachment {door} (want x 0, z {-want.Y / 2 - 2})`)
				end
				if bt == "gate" then
					local rally = at.Rally
					if
						rally == nil
						or (Vector3.new(rally.X, 0, rally.Z) - Vector3.new(0, 0, want.Y / 2 + 4)).Magnitude > 0.01
					then
						table.insert(out, `{tag}: Rally attachment {rally}`)
					end
				end
			end
		end
	end
	return out
end

-- ------------------------------------------------------------------ 1b. the L3 wall's own outline

-- the front silhouette: for each 1-stud column of x, the highest point of any visible part there
local function profile(model: Model): { [number]: number }
	local out: { [number]: number } = {}
	for col = -16, 15 do
		local top = 0
		for _, p in parts(model) do
			if p.Transparency < 1 then
				local e, x = halfExtents(p), p.CFrame.Position.X
				if x - e.X < col + 1 - 0.01 and x + e.X > col + 0.01 then
					top = math.max(top, p.CFrame.Position.Y + e.Y)
				end
			end
		end
		out[col] = top
	end
	return out
end

local function named(model: Instance, name: string): { BasePart }
	local out = {}
	for _, p in parts(model) do
		if p.Name == name then
			table.insert(out, p)
		end
	end
	return out
end

local function boxOverlap(a: BasePart, b: BasePart, slack: number): boolean
	local ea, eb = halfExtents(a), halfExtents(b)
	local pa, pb = a.CFrame.Position, b.CFrame.Position
	return math.abs(pa.X - pb.X) < ea.X + eb.X - slack
		and math.abs(pa.Y - pb.Y) < ea.Y + eb.Y - slack
		and math.abs(pa.Z - pb.Z) < ea.Z + eb.Z - slack
end

CHECKS.wallL3 = function()
	local out: { string } = {}
	for _, hue in HUES do
		local tag = `wall L3 {hue}`
		local w2, w3 = Kit.build("wall", 2, "complete", CANON[hue]), Kit.build("wall", 3, "complete", CANON[hue])
		-- an outline of its own, readable at distance: columns that differ from L2 by a clear height
		local p2, p3 = profile(w2), profile(w3)
		local differ, endsTaller, midTaller = 0, 0, 0
		for col = -16, 15 do
			if math.abs(p3[col] - p2[col]) >= 1.5 then
				differ += 1
			end
			if math.abs(col + 0.5) >= 11.5 and p3[col] - p2[col] >= 1.0 then
				endsTaller += 1
			end
			if math.abs(col + 0.5) <= 2.5 and p3[col] - p2[col] >= 3 then
				midTaller += 1
			end
		end
		if differ < 12 then
			table.insert(out, `{tag}: only {differ} of 32 columns differ from the L2 outline by 1.5 (want 12)`)
		end
		if endsTaller < 6 then
			table.insert(out, `{tag}: the ends are taller than L2 in only {endsTaller} columns (want 6: two piers)`)
		end
		if midTaller < 2 then
			table.insert(
				out,
				`{tag}: the middle is taller than L2 by 3 in only {midTaller} columns (want 2: the brazier)`
			)
		end
		-- the brazier sits on its plinth and the plinth on the walkway: never in a gap of the crenellation
		local walkway, plinth, bowl =
			named(w3, "Walkway")[1], named(w3, "BrazierPlinth")[1], named(w3, "BrazierBowl")[1]
		if walkway and plinth and bowl then
			local walkTop = walkway.CFrame.Position.Y + halfExtents(walkway).Y
			local pe, be = halfExtents(plinth), halfExtents(bowl)
			local plinthBottom, plinthTop = plinth.CFrame.Position.Y - pe.Y, plinth.CFrame.Position.Y + pe.Y
			if math.abs(plinthBottom - walkTop) > 0.05 then
				table.insert(
					out,
					`{tag}: the plinth is not on the walkway (bottom {r3(plinthBottom)}, walkway {r3(walkTop)})`
				)
			end
			if bowl.CFrame.Position.Y - be.Y < plinthTop - 0.05 then
				table.insert(
					out,
					`{tag}: the brazier bowl sinks into its plinth (bottom {r3(bowl.CFrame.Position.Y - be.Y)})`
				)
			end
			local legBottom = math.huge
			for _, leg in named(w3, "BrazierLeg") do
				legBottom = math.min(legBottom, leg.CFrame.Position.Y - halfExtents(leg).Y)
			end
			if legBottom < plinthTop - 0.05 or legBottom > plinthTop + 0.1 then
				table.insert(
					out,
					`{tag}: the brazier legs do not stand on the plinth top (bottom {r3(legBottom)}, plinth top {r3(
						plinthTop
					)})`
				)
			end
			local dx = math.abs(bowl.CFrame.Position.X - plinth.CFrame.Position.X)
			local dz = math.abs(bowl.CFrame.Position.Z - plinth.CFrame.Position.Z)
			if dx > 0.3 or dz > 0.3 or be.X > pe.X + 0.01 or be.Z > pe.Z + 0.01 then
				table.insert(out, `{tag}: the brazier is not centred on its plinth (off {r3(dx)}, {r3(dz)})`)
			end
			if pe.X < 1.5 or pe.Z < 1.5 then
				table.insert(out, `{tag}: the plinth is only {r3(pe.X * 2)} x {r3(pe.Z * 2)} (a flat seat of 3+)`)
			end
			for _, merlon in named(w3, "Merlon") do
				if boxOverlap(merlon, plinth, 0.05) or boxOverlap(merlon, bowl, 0.05) then
					table.insert(out, `{tag}: a merlon overlaps the brazier's seat`)
					break
				end
			end
		else
			table.insert(out, `{tag}: no Walkway, BrazierPlinth and BrazierBowl to check the seat`)
		end
		-- buttress piers: project from the front face and reach the walkway; the end piers stand a tier above it
		local curtain = named(w3, "Curtain")[1]
		if curtain and walkway then
			local frontZ = curtain.CFrame.Position.Z - halfExtents(curtain).Z
			local walkTop = walkway.CFrame.Position.Y + halfExtents(walkway).Y
			-- two stepped buttresses (one beside each end pier), three courses each: every course narrower and shallower than the one
			-- below, the largest projecting 1.5 or more, the top course tucked under the walkway's lip; never a flat upright plank
			for _, sx in { -1, 1 } do
				local steps: { BasePart } = {}
				for _, b in named(w3, "Buttress") do
					if (b.CFrame.Position.X < 0) == (sx < 0) then
						table.insert(steps, b)
					end
				end
				table.sort(steps, function(p, q)
					return p.CFrame.Position.Y < q.CFrame.Position.Y
				end)
				if #steps ~= 3 then
					table.insert(out, `{tag}: {#steps} buttress courses on one side (want 3)`)
				else
					for i = 1, 3 do
						local b = steps[i]
						local e = halfExtents(b)
						local face = b.CFrame.Position.Z - e.Z
						if i == 1 and face > frontZ - 1.5 then
							table.insert(out, `{tag}: the buttress projects only {r3(frontZ - face)} (want 1.5)`)
						end
						if i > 1 then
							local below = steps[i - 1]
							if b.Size.X >= below.Size.X - 0.2 or b.Size.Z >= below.Size.Z - 0.2 then
								table.insert(
									out,
									`{tag}: buttress course {i} ({r3(b.Size.X)} x {r3(b.Size.Z)}) is not narrower and shallower than the one below ({r3(
										below.Size.X
									)} x {r3(below.Size.Z)})`
								)
							end
						end
						if b.Size.X < 2.4 or b.Size.Y > 9 then
							table.insert(
								out,
								`{tag}: a buttress course is {r3(b.Size.X)} wide and {r3(b.Size.Y)} tall (a plank, not a pier)`
							)
						end
					end
					local top = steps[3].CFrame.Position.Y + halfExtents(steps[3]).Y
					if top < walkTop - 1.2 then
						table.insert(
							out,
							`{tag}: a buttress stops {r3(walkTop - top)} short of the walkway's underside`
						)
					end
				end
			end
			for _, pier in named(w3, "EndPier") do
				local e = halfExtents(pier)
				if pier.CFrame.Position.Y + e.Y < walkTop + 3.5 then
					table.insert(
						out,
						`{tag}: an end pier rises only {r3(pier.CFrame.Position.Y + e.Y - walkTop)} over the walkway (want 3.5)`
					)
				end
			end
		end
		-- fuller banners: two, wider than the L2 banner, hanging between the buttresses (not across one)
		local bannersL2 = named(w2, "Banner")
		local wide2 = if bannersL2[1] then bannersL2[1].Size.X else 0
		local banners = named(w3, "Banner")
		for _, b in banners do
			if b.Size.X < wide2 + 0.3 then
				table.insert(out, `{tag}: a banner is {r3(b.Size.X)} wide, not fuller than L2's {r3(wide2)}`)
			end
			for _, bt in named(w3, "Buttress") do
				if boxOverlap(b, bt, 0.05) then
					table.insert(out, `{tag}: a banner hangs across a buttress`)
					break
				end
			end
		end
		-- the L3 crenellation stays between the end piers (no merlon inside a pier)
		for _, merlon in named(w3, "Merlon") do
			for _, pier in named(w3, "EndPier") do
				if boxOverlap(merlon, pier, 0.05) then
					table.insert(out, `{tag}: a merlon is inside an end pier`)
					break
				end
			end
		end
	end
	return out
end

-- ------------------------------------------------------------------ 1c. the gate's lintel, voussoirs and floor

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

CHECKS.gateShape = function()
	local out: { string } = {}
	for _, hue in HUES do
		for lv = 1, 3 do
			local tag = `gate L{lv} {hue}`
			local m = Kit.build("gate", lv, "complete", CANON[hue])
			local lintel, tower = named(m, "Lintel")[1], named(m, "GateTower")[1]
			if lintel == nil or tower == nil then
				table.insert(out, `{tag}: no Lintel or GateTower`)
				continue
			end
			local lintelTop = lintel.CFrame.Position.Y + halfExtents(lintel).Y
			local towerTop = tower.CFrame.Position.Y + halfExtents(tower).Y
			if lintelTop < towerTop - 0.01 then
				table.insert(
					out,
					`{tag}: the span tops out at {r3(lintelTop)}, below the tower bodies ({r3(towerTop)}): a saddle`
				)
			end
			-- the voussoirs lie flush on the lintel face (their back against it), nothing floats in front of the facade
			local frontZ = lintel.CFrame.Position.Z - halfExtents(lintel).Z
			local stones = 0
			for _, p in parts(m) do
				if p.Name == "Voussoir" or p.Name == "Keystone" then
					stones += 1
					local e = halfExtents(p)
					local back = p.CFrame.Position.Z + e.Z
					if math.abs(back - frontZ) > 0.12 then
						table.insert(out, `{tag}: a {p.Name} floats {r3(frontZ - back)} off the lintel face`)
						break
					end
					if frontZ - (p.CFrame.Position.Z - e.Z) > 0.9 then
						table.insert(
							out,
							`{tag}: a {p.Name} stands {r3(frontZ - (p.CFrame.Position.Z - e.Z))} proud of the facade`
						)
						break
					end
				end
			end
			if stones ~= 8 then
				table.insert(out, `{tag}: {stones} arch stones (want 8: 3 voussoirs and a keystone each side)`)
			end
			-- the passage floor is a MID tone (never near-black: a void at 170 studs; never white), clearly different in value from
			-- the wall, and the leaves are light enough to read against the stone when open
			local road = named(m, "GateRoad")[1]
			if
				road == nil
				or luminance(road.Color) < 0.25
				or luminance(road.Color) > 0.6
				or math.abs(luminance(road.Color) - luminance(tower.Color)) < 0.15
			then
				table.insert(
					out,
					`{tag}: the passage floor ({road and r3(luminance(road.Color))}) is not a mid tone (0.25 to 0.6) at least 0.15 from the wall ({r3(
						luminance(tower.Color)
					)})`
				)
			end
			-- closed, every level shows no sky: every point of the arch above the floor lies behind a leaf or the door head (at L3
			-- the door head stands behind the portcullis bars)
			do
				local holes = 0
				for xi = -13, 13 do
					local x = xi * 0.5
					local archTop = 9 + 6 * (1 - math.abs(x) / 7) - (m.PrimaryPart :: BasePart).CFrame.Y - 0.3
					local y = 0.4
					while y < archTop do
						local covered = false
						for _, q in parts(m) do
							if q:IsA("Part") and q.Transparency < 1 and q.Name ~= "GateRoad" and q.Name ~= "Root" then
								local cf = rel(m, q)
								if math.abs(q.CFrame.UpVector.Y) > 0.99 and math.abs(q.CFrame.LookVector.Z) > 0.99 then
									if
										math.abs(x - cf.X) <= q.Size.X / 2 + 0.1
										and math.abs(y - cf.Y) <= q.Size.Y / 2
									then
										covered = true
										break
									end
								end
							end
						end
						if not covered then
							holes += 1
						end
						y += 0.5
					end
				end
				if holes > 0 then
					table.insert(
						out,
						`{tag}: {holes} sample points of the closed arch show through (a hole above the leaves)`
					)
				end
			end
			local leaf = named(m, "GateLeaf")[1]
			if leaf and luminance(leaf.Color) < 0.3 then
				table.insert(out, `{tag}: the leaves are dark ({r3(luminance(leaf.Color))})`)
			end
		end
	end
	return out
end

-- ------------------------------------------------------------------ 1d. the L1 palisade is the same dark timber everywhere

CHECKS.palisade = function()
	local out: { string } = {}
	local ref: { string } = {}
	for hi, hue in HUES do
		local wall = Kit.build("wall", 1, "complete", CANON[hue])
		local colors: { string } = {}
		for _, p in named(wall, "Palisade") do
			local c = p.Color
			if luminance(c) > 0.3 or not (c.R > c.G and c.G > c.B) then
				table.insert(out, `wall L1 {hue}: a palisade log is not dark brown (luminance {r3(luminance(c))})`)
				break
			end
			table.insert(colors, c:ToHex())
		end
		table.sort(colors)
		if hi == 1 then
			ref = colors
		elseif table.concat(colors, ",") ~= table.concat(ref, ",") then
			table.insert(
				out,
				`wall L1 {hue}: the palisade logs are not the colours of Emberhold's (the style re-skinned them)`
			)
		end
		if #colors < 10 then
			table.insert(out, `wall L1 {hue}: only {#colors} palisade logs`)
		end
	end
	return out
end

-- ------------------------------------------------------------------ 2. gate poses

local MOVABLE_NAMES = {
	{ "GateLeaf" },
	{ "GateLeaf", "LeafBand" },
	{ "GateLeaf", "LeafBand", "PortcullisBar", "Portcullis" },
}

local function insideFootprint(model: Model, fp: Vector2): string?
	local root = model.PrimaryPart :: BasePart
	for _, p in parts(model) do
		local cf = root.CFrame:ToObjectSpace(p.CFrame)
		local e = halfExtents(p) -- local axes are the world axes while the root is unrotated
		if
			math.abs(cf.X) + e.X > fp.X / 2 + 0.05
			or cf.Z + e.Z > fp.Y / 2 + 0.05
			or cf.Z - e.Z < -fp.Y / 2 - 2
			or cf.Y - e.Y < -0.3
		then
			return `{p.Name} at {cf.Position}`
		end
	end
	return nil
end

-- The name of the first part standing in front of (toward -Z of) any of nine points on a leaf's front face, or nil: the
-- face is seen from the front. Boxes are the world-axis boxes of the parts (conservative for turned ones).
local function visibleBlocker(model: Model, leaf: BasePart): string?
	local root = model.PrimaryPart :: BasePart
	for _, u in { 0.25, 0.5, 0.75 } do
		for _, v in { 0.2, 0.5, 0.8 } do
			local world = leaf.CFrame
				* CFrame.new((u - 0.5) * leaf.Size.X, (v - 0.5) * leaf.Size.Y, -leaf.Size.Z / 2 - 0.02)
			local o = root.CFrame:ToObjectSpace(world).Position
			for _, q in parts(model) do
				if q ~= leaf and q.Transparency < 1 and q.Name ~= "LeafBand" then
					local c, e = rel(model, q).Position, halfExtents(q)
					if math.abs(o.X - c.X) < e.X and math.abs(o.Y - c.Y) < e.Y and c.Z - e.Z < o.Z - 0.02 then
						return q.Name
					end
				end
			end
		end
	end
	return nil
end

CHECKS.gatePose = function()
	local out: { string } = {}
	local turn = CFrame.new(120, 3, -45) * CFrame.Angles(0, 1.1, 0)
	for _, hue in { "crimson", "emerald" } do
		for lv = 1, 3 do
			local tag = `gate L{lv} {hue}`
			local m = Kit.build("gate", lv, "complete", CANON[hue])
			local fp = Kit.footprint("gate", lv)
			if m:GetAttribute("KitGateOpen") ~= false then
				table.insert(out, `{tag}: KitGateOpen is {m:GetAttribute("KitGateOpen")} as built (want false)`)
			end
			local n0, h0, closed = count(m), hist(m), localCFrames(m)
			local closedSig = signature(m)
			Kit.setGateOpen(m, true)
			if m:GetAttribute("KitGateOpen") ~= true then
				table.insert(out, `{tag}: KitGateOpen not true after opening`)
			end
			if count(m) ~= n0 then
				table.insert(out, `{tag}: opening changed the part count {n0} -> {count(m)}`)
			end
			local h1 = hist(m)
			for k, v in h0 do
				if h1[k] ~= v then
					table.insert(out, `{tag}: opening changed {k} x{v} -> x{h1[k]}`)
				end
			end
			-- exactly the movable parts move
			local movedNames: { [string]: number } = {}
			for p, was in closed do
				local moved = cfDistance(rel(m, p), was) > 1e-3
				local movable = typeof(p:GetAttribute("KitGateOpenCF")) == "CFrame"
				if moved ~= movable then
					table.insert(out, `{tag}: {p.Name} {if moved then "moved" else "stayed"} but movable={movable}`)
				end
				if moved then
					movedNames[p.Name] = (movedNames[p.Name] or 0) + 1
				end
			end
			for _, name in MOVABLE_NAMES[lv] do
				if (movedNames[name] or 0) == 0 then
					table.insert(out, `{tag}: no {name} moves when the gate opens`)
				end
			end
			for name in movedNames do
				if not table.find(MOVABLE_NAMES[lv], name) then
					table.insert(out, `{tag}: {name} moves but is not a leaf, band or portcullis part`)
				end
			end
			-- the passage (the towers' inner faces at x = +-7): closed, the leaves span it; open, BOTH leaves stand swung into it,
			-- face to the front (not edge-on), the middle clear, nothing in front of them, and they stay out of the towers
			local leafClosed = {}
			local sides = { [-1] = 0, [1] = 0 }
			local reach = {}
			for p, was in closed do
				if p.Name == "GateLeaf" then
					table.insert(leafClosed, (was :: CFrame).Position)
					local e = halfExtents(p)
					local x = rel(m, p).X
					sides[if x < 0 then -1 else 1] += 1
					table.insert(reach, math.abs(x))
					if math.abs(x) - e.X < 3.0 then
						table.insert(
							out,
							`{tag}: an open leaf still reaches into the middle of the passage (inner edge {r3(
								math.abs(x) - e.X
							)} < 3)`
						)
					end
					if math.abs(x) + e.X > 7.5 then
						table.insert(out, `{tag}: an open leaf pokes {r3(math.abs(x) + e.X - 7)} into the tower`)
					end
					if e.X * 2 < 2.0 then
						table.insert(
							out,
							`{tag}: an open leaf is only {r3(e.X * 2)} studs across from the front (edge-on): it must show its face`
						)
					end
					local normal =
						math.abs((m.PrimaryPart :: BasePart).CFrame:VectorToObjectSpace(p.CFrame.LookVector).Z)
					if normal < 0.3 or normal > 0.75 then
						table.insert(
							out,
							`{tag}: an open leaf's face points {r3(normal)} to the front (want 0.3..0.75: swung, not edge-on, not still closed)`
						)
					end
					-- nothing stands in front of the leaf's face (rays along -Z from nine points of the leaf, at 20/50/80 %)
					local blocked = visibleBlocker(m, p)
					if blocked then
						table.insert(out, `{tag}: an open leaf is hidden behind {blocked}`)
					end
				end
			end
			if sides[-1] ~= 1 or sides[1] ~= 1 then
				table.insert(out, `{tag}: want one open leaf each side, got {sides[-1]} left and {sides[1]} right`)
			end
			if #reach == 2 and math.abs(reach[1] - reach[2]) > 0.05 then
				table.insert(
					out,
					`{tag}: the open leaves are not mirrored ({r3(reach[1])} and {r3(reach[2])} from the centre)`
				)
			end
			local xs = {}
			for _, c in leafClosed do
				table.insert(xs, c.X)
			end
			table.sort(xs)
			if #xs == 2 and not (xs[1] < -2.5 and xs[2] > 2.5) then
				table.insert(out, `{tag}: closed leaves are not either side of the centre ({xs[1]}, {xs[2]})`)
			end
			if lv == 3 then
				local lintel = named(m, "Lintel")[1]
				local leafTop = 0
				for p, was in closed do
					if p.Name == "GateLeaf" then
						leafTop = math.max(leafTop, (was :: CFrame).Y + p.Size.Y / 2)
					end
				end
				for p, was in closed do
					if p.Name == "PortcullisBar" or p.Name == "Portcullis" then
						local e = halfExtents(p)
						local at = rel(m, p)
						if p.Name == "PortcullisBar" and math.abs(at.Y - (was :: CFrame).Y - 7) > 1e-3 then
							table.insert(out, `{tag}: a portcullis bar rises {r3(at.Y - (was :: CFrame).Y)} (want 7)`)
						end
						-- raised clear of the opening: inside the lintel block above the arch
						if lintel then
							local le = halfExtents(lintel)
							local lc = rel(m, lintel)
							if at.Y - e.Y < lc.Y - le.Y - 0.01 then
								table.insert(
									out,
									`{tag}: a raised {p.Name} hangs down to y {r3(at.Y - e.Y)} in the opening (the lintel starts at {r3(
										lc.Y - le.Y
									)})`
								)
							end
							if
								at.Y + e.Y > lc.Y + le.Y + 0.01
								or math.abs(at.Z - lc.Z) + e.Z > le.Z
								or math.abs(at.X) + e.X > le.X
							then
								table.insert(out, `{tag}: a raised {p.Name} sticks out of the lintel`)
							end
						end
						-- closed, it hangs in the arch above the leaves
						if (was :: CFrame).Y - e.Y < leafTop - 0.01 then
							table.insert(
								out,
								`{tag}: a closed {p.Name} reaches below the leaves' tops ({r3((was :: CFrame).Y - e.Y)} < {r3(
									leafTop
								)})`
							)
						end
					end
				end
			end
			if insideFootprint(m, fp) then
				table.insert(out, `{tag}: open, {insideFootprint(m, fp)} is outside the footprint`)
			end
			-- idempotent, and the round trip is exact
			Kit.setGateOpen(m, true)
			local openSig = signature(m)
			Kit.setGateOpen(m, false)
			if signature(m) ~= closedSig or m:GetAttribute("KitGateOpen") ~= false then
				table.insert(out, `{tag}: closing again does not restore the model exactly`)
			end
			Kit.setGateOpen(m, true)
			if signature(m) ~= openSig then
				table.insert(out, `{tag}: opening twice is not the same as once`)
			end
			-- a moved and turned gate opens the same way (poses are relative to the Root)
			local m2 = Kit.build("gate", lv, "complete", CANON[hue])
			for _, p in parts(m2) do
				p.CFrame = turn * p.CFrame
			end
			Kit.setGateOpen(m2, true)
			local openParts, turnedParts = parts(m), parts(m2)
			for i, p in openParts do
				if turnedParts[i] == nil or cfDistance(turnedParts[i].CFrame, turn * p.CFrame) > 0.01 then
					table.insert(out, `{tag}: turned gate, {p.Name} opens to the wrong place`)
					break
				end
			end
			-- recolouring an open gate keeps the pose and is the same as building it in the new colour
			local c0 = CANON[hue]
			local newColor = Color3.new(c0.R * 0.85, c0.G * 0.85, c0.B * 0.85)
			Kit.setKingdomColor(m, newColor)
			local fresh = Kit.build("gate", lv, "complete", newColor)
			Kit.setGateOpen(fresh, true)
			if signature(m) ~= signature(fresh) then
				table.insert(out, `{tag}: an open gate recoloured is not the same as one built in the new colour`)
			end
			if signature(m) == openSig then
				table.insert(out, `{tag}: recolouring changed nothing`)
			end
		end
	end
	-- a gate under construction and a keep have no gate attribute: opening them does nothing, quietly
	local stage = Kit.build("gate", 1, 1, CANON.crimson)
	local keep = Kit.build("keep", 1, "complete", CANON.crimson)
	for _, other in { stage, keep } do
		local sig = signature(other)
		Kit.setGateOpen(other, true)
		if signature(other) ~= sig or other:GetAttribute("KitGateOpen") ~= nil then
			table.insert(out, `{other.Name}: setGateOpen touched a model that is not a finished gate`)
		end
	end
	return out
end

-- ------------------------------------------------------------------ 3. watchtower L2

-- How far up the tower's axis a continuous run of parts goes from the platform (the Gallery's top) before a gap: the cap must
-- stand ON the platform (a cone floating over a flattened parapet showed a dark ring), however many merlons are gone.
local function axisReach(model: Model): (number, number)
	local gallery = named(model, "Gallery")[1]
	if gallery == nil then
		return 0, 0
	end
	local top = gallery.CFrame.Position.Y + halfExtents(gallery).Y
	local runs: { { number } } = {}
	for _, p in parts(model) do
		if p.Transparency < 1 and p.Name ~= "Merlon" then
			local e, c = halfExtents(p), p.CFrame.Position
			if math.abs(c.X) <= e.X and math.abs(c.Z) <= e.Z then
				table.insert(runs, { c.Y - e.Y, c.Y + e.Y })
			end
		end
	end
	table.sort(runs, function(a, b)
		return a[1] < b[1]
	end)
	local reach = top
	for _, run in runs do
		if run[1] <= reach + 0.05 then
			reach = math.max(reach, run[2])
		end
	end
	return reach - top, top
end

CHECKS.tower = function()
	local out: { string } = {}
	local cap = Buildings.PART_BUDGET.watchtower
	if cap ~= 130 then
		table.insert(out, `the watchtower cap is {cap}, not 130`)
	end
	for _, hue in HUES do
		local a = Kit.build("watchtower", 1, "complete", CANON[hue])
		local b = Kit.build("watchtower", 2, "complete", CANON[hue])
		local tag = `watchtower L2 {hue}`
		local ha, hb = hist(a), hist(b)
		if count(b) > 130 then
			table.insert(out, `{tag}: {count(b)} parts, over the cap 130`)
		end
		need(out, tag, hb, "WarGallery", exactly(4), "hoarding galleries")
		need(out, tag, hb, "BrazierBowl", exactly(2), "two braziers at the door")
		need(out, tag, hb, "Banner", atLeast(1), "the kingdom banner")
		local emblem = false
		for _, p in parts(b) do
			emblem = emblem or p:GetAttribute("KitEmblem") ~= nil
		end
		if not emblem then
			table.insert(out, `{tag}: no kingdom emblem`)
		end
		need(out, tag, hb, "Window", NONE, "arched windows become slits")
		need(out, tag, hb, "ArrowSlit", atLeast((ha.ArrowSlit or 0) + 2), "more arrow slits than L1")
		need(out, `watchtower L1 {hue}`, ha, "WarGallery", NONE, "L1 is not war-ready")
		need(out, `watchtower L1 {hue}`, ha, "BrazierBowl", NONE, "L1 has no braziers")
		if (ha.Merlon or 0) > 0 and (hb.Merlon or 0) < (ha.Merlon or 0) + 6 then
			table.insert(out, `{tag}: {hb.Merlon or 0} merlons, not more than L1 ({ha.Merlon})`)
		end
		for lv, tower in { a, b } do
			local reach = axisReach(tower)
			if reach < 3 then
				table.insert(
					out,
					`watchtower L{lv} {hue}: the cap does not stand on the platform (the parts on the tower axis run only {r3(
						reach
					)} up from it)`
				)
			end
		end
		local sides = {}
		for _, p in parts(b) do
			if p.Name == "BrazierBowl" then
				table.insert(sides, p.CFrame.Position.X)
			end
		end
		if #sides == 2 and sides[1] * sides[2] >= 0 then
			table.insert(out, `{tag}: both braziers are on one side of the door`)
		end
		if topOf(b) < topOf(a) - 0.01 then
			table.insert(out, `{tag}: L2 is lower than L1`)
		end
	end
	return out
end

-- ------------------------------------------------------------------ 4. ram

-- Motor6D.Transform; the headless mock has no default before the first write, the engine's is the identity
local function transformOf(joint: Motor6D): CFrame
	local ok, t = pcall(function()
		return joint.Transform
	end)
	return if ok then t else CFrame.new()
end

local function jointByName(model: Instance, name: string): Motor6D?
	for _, m in motors(model) do
		if m.Name == name then
			return m
		end
	end
	return nil
end

-- Forward kinematics as the engine does it: Part1 = Part0 * C0 * Transform * C1:Inverse(); welds follow.
local function posed(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
	local root = rig.PrimaryPart :: BasePart
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local list = motors(rig)
	local moved = true
	while moved do
		moved = false
		for _, m in list do
			local p0, p1 = m.Part0 :: BasePart, m.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * (joints[m.Name] or CFrame.new()) * m.C1:Inverse()
				moved = true
			end
		end
	end
	for _ = 1, 3 do -- welds chain (a part welded to a welded part)
		for _, d in rig:GetDescendants() do
			if d:IsA("Weld") and world[d.Part0 :: BasePart] and not world[d.Part1 :: BasePart] then
				world[d.Part1 :: BasePart] = world[d.Part0 :: BasePart] * d.C0 * d.C1:Inverse()
			end
		end
	end
	return world
end

local function ramViolations(): { string }
	local out: { string } = {}
	for _, hue in HUES do
		local tag = `ram {hue}`
		local m = Kit.siege("ram", CANON[hue])
		local root = m.PrimaryPart :: BasePart
		local n = count(m)
		if n > 45 or Siege.MAX_PARTS ~= 45 then
			table.insert(out, `{tag}: {n} parts (cap 45, Siege.MAX_PARTS {Siege.MAX_PARTS})`)
		end
		if Kit.partCount(m) ~= n then
			table.insert(out, `{tag}: Kit.partCount disagrees`)
		end
		if root.Name ~= "Root" or not root.Anchored or root.Transparency ~= 1 then
			table.insert(out, `{tag}: the Root must be anchored and invisible`)
		end
		local pivot = (root.CFrame * root.PivotOffset).Position
		if math.abs(pivot.Y) > 0.01 or math.abs(root.CFrame.Position.Y - 0.1) > 0.01 then
			table.insert(
				out,
				`{tag}: the pivot is not at the feet (pivot y {r3(pivot.Y)}, Root y {r3(root.CFrame.Position.Y)})`
			)
		end
		local low, minZ, maxZ = math.huge, math.huge, -math.huge
		for _, p in parts(m) do
			if p ~= root then
				local e = halfExtents(p)
				low = math.min(low, p.CFrame.Position.Y - e.Y)
				minZ = math.min(minZ, p.CFrame.Position.Z - e.Z)
				maxZ = math.max(maxZ, p.CFrame.Position.Z + e.Z)
			end
		end
		if low < -0.05 or low > 0.1 then
			table.insert(out, `{tag}: the lowest part is at y {r3(low)} (feet at 0)`)
		end
		if minZ > -maxZ - 0.3 then
			table.insert(out, `{tag}: the log does not project out of the front (-Z): z range {r3(minZ)}..{r3(maxZ)}`)
		end
		-- the rig: one Motor6D named Log, everything else rigid
		local list = motors(m)
		if
			#list ~= 1
			or list[1].Name ~= "Log"
			or list[1].Part0 ~= root
			or (list[1].Part1 :: BasePart).Name ~= "Log"
		then
			table.insert(out, `{tag}: want exactly one Motor6D "Log" (Root -> Log), found {#list}`)
		end
		local log = m:FindFirstChild("Log") :: BasePart?
		for _, p in parts(m) do
			if p ~= root then
				if p.Anchored or not p.Massless or p.CanCollide then
					table.insert(out, `{tag}: {p.Name} must be unanchored, Massless and non-colliding`)
				end
				if p ~= log then
					local w = p:FindFirstChildOfClass("Weld")
					if w == nil or (w.Part0 ~= root and w.Part0 ~= log) or w.Part1 ~= p then
						table.insert(out, `{tag}: {p.Name} is not welded to the Root or the Log`)
					end
				end
			end
		end
		if m:GetAttribute("KitKind") ~= "siege" or m:GetAttribute("KitSiege") ~= "ram" then
			table.insert(out, `{tag}: KitKind/KitSiege attributes`)
		end
		if m:GetAttribute("KitRootHeight") ~= Siege.ROOT_HEIGHT then
			table.insert(out, `{tag}: KitRootHeight`)
		end
		-- thrust: 0 is the built pose; 1 puts the log head exactly THRUST_TRAVEL forward and nothing else moves
		local joint = jointByName(m, "Log")
		if joint then
			local still = posed(m, {})
			local at1 = posed(m, { Log = Siege.thrustTransform(1) })
			for _, p in parts(m) do
				local d = if at1[p] and still[p] then at1[p].Position - still[p].Position else Vector3.zero
				local inLog = p.Name == "Log" or p.Name == "RamHead" or p.Name == "RamBand" or p.Name == "Hanger"
				if inLog and math.abs(d.Z + Siege.THRUST_TRAVEL) > 1e-3 then
					table.insert(out, `{tag}: {p.Name} moves {r3(d.Z)} at thrust 1 (want {-Siege.THRUST_TRAVEL})`)
				elseif not inLog and d.Magnitude > 1e-3 then
					table.insert(out, `{tag}: {p.Name} moves with the log`)
				end
			end
			-- built at thrust 0 (the engine's Motor6D.Transform starts as the identity; the mock has no default)
			if transformOf(joint) ~= CFrame.new() then
				table.insert(out, `{tag}: not built at thrust 0`)
			end
			Kit.siegePose(m, 1)
			if (transformOf(joint).Position - Vector3.new(0, 0, -Siege.THRUST_TRAVEL)).Magnitude > 1e-3 then
				table.insert(out, `{tag}: Kit.siegePose(1) -> {transformOf(joint).Position}`)
			end
			local lastZ = math.huge
			for i = 0, 10 do
				Kit.siegePose(m, i / 10)
				local z = transformOf(joint).Position.Z
				if z > lastZ + 1e-9 then
					table.insert(out, `{tag}: thrust {i / 10} moves the log backwards ({z} > {lastZ})`)
				end
				lastZ = z
			end
			Kit.siegePose(m, 0.5)
			if math.abs(transformOf(joint).Position.Y - Siege.THRUST_LIFT) > 1e-4 then
				table.insert(out, `{tag}: no arc at mid-thrust`)
			end
			for _, odd in { 7, -3, math.huge, -math.huge } do
				Kit.siegePose(m, odd)
				local want = if odd > 0 then 1 else 0
				if (transformOf(joint).Position - Siege.thrustTransform(want).Position).Magnitude > 1e-6 then
					table.insert(out, `{tag}: thrust {odd} is not clamped to {want}`)
				end
			end
			Kit.siegePose(m, 0 / 0)
			if transformOf(joint) ~= CFrame.new() then
				table.insert(out, `{tag}: NaN thrust is not the built pose`)
			end
		end
		-- the LOG is the silhouette: long, thick, pale, an iron WEDGE head well past a low roof, visible from the side at thrust 0
		local logP, head, roofP = named(m, "Log")[1], named(m, "RamHead")[1], named(m, "RoofSlab")[1]
		if logP and head and roofP then
			if not logP:IsA("Part") or (logP :: Part).Shape ~= Enum.PartType.Cylinder then
				table.insert(out, `{tag}: the Log is not a cylinder`)
			end
			local length, thick = logP.Size.X, logP.Size.Y
			if length < 14 or thick < 2.4 then
				table.insert(out, `{tag}: the log is {r3(length)} x {r3(thick)} (want 14+ long, 2.4+ thick)`)
			end
			if luminance(logP.Color) < 0.5 then
				table.insert(out, `{tag}: the log is dark ({r3(luminance(logP.Color))}); it must be the pale shape`)
			end
			if head.ClassName ~= "WedgePart" then
				table.insert(out, `{tag}: the head is a {head.ClassName}, not a wedge (a round cap reads as a cannon)`)
			end
			if luminance(head.Color) > 0.25 or luminance(logP.Color) - luminance(head.Color) < 0.35 then
				table.insert(
					out,
					`{tag}: the head ({r3(luminance(head.Color))}) is not a dark iron cap on the pale log ({r3(
						luminance(logP.Color)
					)})`
				)
			end
			local headFront = head.CFrame.Position.Z - halfExtents(head).Z
			local roofFront = math.huge
			for _, name in { "RoofSlab", "RoofEdge" } do
				for _, q in named(m, name) do
					roofFront = math.min(roofFront, q.CFrame.Position.Z - halfExtents(q).Z)
				end
			end
			if roofFront - headFront < 6 then
				table.insert(out, `{tag}: the head projects only {r3(roofFront - headFront)} past the roof (want 6+)`)
			end
			local roofTop = roofP.CFrame.Position.Y + halfExtents(roofP).Y
			if roofTop > 7.8 then
				table.insert(out, `{tag}: the roof tops out at {r3(roofTop)} (a low roof: 7.8)`)
			end
			for _, q in parts(m) do
				if q ~= root and q.Transparency < 1 then
					if q.CFrame.Position.Z - halfExtents(q).Z < headFront - 0.01 then
						table.insert(out, `{tag}: {q.Name} projects past the head`)
						break
					end
					if
						q:IsA("Part")
						and (q :: Part).Shape == Enum.PartType.Ball
						and q.CFrame.Position.Z < roofFront
					then
						table.insert(out, `{tag}: {q.Name} is a ball out in front of the roof (a cap on the log)`)
						break
					end
					if q:IsA("Part") and (q :: Part).Shape == Enum.PartType.Cylinder and q.Name ~= "Wheel" then
						-- bands ring the log; none caps its front end
						if q.CFrame.Position.Z < logP.CFrame.Position.Z - length / 2 + 0.3 then
							table.insert(out, `{tag}: a round {q.Name} caps the log's front end`)
							break
						end
					end
				end
			end
			-- open sides: from +X and from -X the log's axis is seen along at least 75 % of its length (posts only)
			local logTop, logBottom = logP.CFrame.Position.Y + thick / 2, logP.CFrame.Position.Y - thick / 2
			for _, side in { 1, -1 } do
				local seen, total = 0, 0
				for i = 0, 29 do
					local z = logP.CFrame.Position.Z - length / 2 + (i + 0.5) * length / 30
					local y = (logTop + logBottom) / 2
					total += 1
					local hidden = false
					for _, q in parts(m) do
						if
							q ~= root
							and q.Transparency < 1
							and q.Name ~= "Log"
							and q.Name ~= "Hanger"
							and q.Name ~= "RamBand"
							and q.Name ~= "RamHead"
						then
							local c, e = q.CFrame.Position, halfExtents(q)
							if
								math.abs(y - c.Y) < e.Y
								and math.abs(z - c.Z) < e.Z
								and side * (c.X + side * e.X) > thick / 2 + 0.01
							then
								hidden = true
								break
							end
						end
					end
					if not hidden then
						seen += 1
					end
				end
				if seen / total < 0.75 then
					table.insert(
						out,
						`{tag}: the log is seen along only {r3(seen / total)} of its length from the side`
					)
				end
			end
			-- kingdom colour (and heraldry) on the roof only: nothing tinted below the log's top, nothing tinted on the log group
			for _, q in parts(m) do
				if q:GetAttribute("KitTint") ~= nil or q:GetAttribute("KitEmblem") ~= nil then
					if q.CFrame.Position.Y < logTop + 0.3 then
						table.insert(
							out,
							`{tag}: {q.Name} carries the kingdom at y {r3(q.CFrame.Position.Y)}, level with the log`
						)
						break
					end
				end
			end
		else
			table.insert(out, `{tag}: no Log, RamHead and RoofSlab`)
		end
		if #named(m, "Wheel") ~= 4 then
			table.insert(out, `{tag}: {#named(m, "Wheel")} wheels (want 4)`)
		end
		-- kingdom colour on the roof, ridge, pennant and crest; the emblem re-forms with the recolour
		local tinted = 0
		for _, p in parts(m) do
			if type(p:GetAttribute("KitTint")) == "number" then
				tinted += 1
			end
		end
		if tinted < 4 then
			table.insert(out, `{tag}: only {tinted} kingdom-tinted parts`)
		end
		local kinds = {}
		for _, p in parts(m) do
			local k = p:GetAttribute("KitEmblem")
			if k ~= nil then
				kinds[k :: string] = true
			end
		end
		if not kinds[EMBLEMS[hue]] then
			table.insert(out, `{tag}: no {EMBLEMS[hue]} emblem`)
		end
		-- a pooled ram recoloured within its kingdom (the style's own woods stay) is the same as one built in that colour
		local c0 = CANON[hue]
		local dyed = Color3.new(c0.R * 0.85, c0.G * 0.85, c0.B * 0.85)
		Kit.setKingdomColor(m, dyed)
		if signature(m) ~= signature(Kit.siege("ram", dyed)) or signature(m) == signature(Kit.siege("ram", c0)) then
			table.insert(out, `{tag}: recoloured is not the same as built in the new colour`)
		end
		if signature(Kit.siege("ram", CANON[hue])) ~= signature(Kit.siege("ram", CANON[hue])) then
			table.insert(out, `{tag}: not deterministic`)
		end
	end
	local ok, err = pcall(Kit.siege, "catapult", CANON.crimson)
	if ok or not string.find(tostring(err), "unknown siege kind") then
		table.insert(out, `Kit.siege("catapult") should error with "unknown siege kind", got {ok}/{err}`)
	end
	if table.concat(Kit.SIEGE_KINDS, ",") ~= "ram" then
		table.insert(out, "Kit.SIEGE_KINDS is not { ram }")
	end
	return out
end
CHECKS.ram = ramViolations

-- ------------------------------------------------------------------ the spec

local function expectClean(list: { string })
	if #list > 0 then
		error(`{#list} violations, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
	end
end

describe("Wall and gate at three levels (FL-0128)", function()
	it("keeps the levels distinct, within their caps, footprints and attachments as they were", function()
		expectClean(CHECKS.levels())
	end)
	it("gives the L3 wall its own outline, with the brazier seated on a plinth on the walkway", function()
		expectClean(CHECKS.wallL3())
	end)
	it("seats the gate's span at the tower tops and its voussoirs flush on the facade, over a light floor", function()
		expectClean(CHECKS.gateShape())
	end)
	it("keeps the L1 palisade the same dark timber in every kingdom", function()
		expectClean(CHECKS.palisade())
	end)
	it("opens and closes the gate by CFrame alone, both leaves swung open and in view", function()
		expectClean(CHECKS.gatePose())
	end)
	it("builds the walls and gates without yielding, as one Model with a Root", function()
		for _, bt in { "wall", "gate" } do
			for lv = 1, 3 do
				local m = noYield(function()
					return Kit.build(bt, lv, "complete", CANON.azure)
				end)
				expect(m.PrimaryPart ~= nil).toBe(true)
				expect((m.PrimaryPart :: BasePart).Name).toBe("Root")
				expect(m:GetAttribute("KitType")).toBe(bt)
				expect(m:GetAttribute("KitLevel")).toBe(lv)
			end
		end
	end)
end)

describe("Watchtower L2 is war-ready (FL-0128)", function()
	it("has hoarding galleries, braziers, a banner, more merlons and slits within 130 parts", function()
		expectClean(CHECKS.tower())
	end)
end)

describe("Kit.siege ram (FL-0128)", function()
	it("is a rigged, kingdom-tinted ram of at most 45 parts with one Log joint", function()
		expectClean(CHECKS.ram())
	end)
	it("builds without yielding", function()
		noYield(function()
			return Kit.siege("ram", CANON.gold)
		end)
	end)
end)

-- ------------------------------------------------------------------ mutants

describe("War kit structure mutants are caught", function()
	local original = {
		build = Kit.build,
		footprint = Kit.footprint,
		setGateOpen = Kit.setGateOpen,
		siege = Kit.siege,
		siegePose = Kit.siegePose,
		angle = Buildings.GATE_OPEN_ANGLE,
	}
	local function restore()
		Buildings.GATE_OPEN_ANGLE = original.angle
		Kit.build = original.build
		Kit.footprint = original.footprint
		Kit.setGateOpen = original.setGateOpen
		Kit.siege = original.siege
		Kit.siegePose = original.siegePose
	end
	local function caught(name: string, by: string, mutate: () -> ())
		it(`catches: {name} (by {by})`, function()
			mutate()
			local ok, list = pcall(CHECKS[by])
			restore()
			if not ok then
				error(`the mutant crashed instead of failing a check: {list}`)
			end
			if #(list :: { string }) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end
	local function addParts(m: Model, n: number)
		for i = 1, n do
			local p = Instance.new("Part")
			p.Name = `Extra{i}`
			p.Size = Vector3.new(1, 1, 1)
			p.CFrame = (m.PrimaryPart :: BasePart).CFrame
			p.Parent = m
		end
	end

	it("passes unmutated (the baseline)", function()
		for _, name in { "levels", "wallL3", "gateShape", "palisade", "gatePose", "tower", "ram" } do
			expectClean(CHECKS[name]())
		end
	end)

	-- walls, gates, tower
	caught("every wall is built at level 1", "levels", function()
		Kit.build = function(bt, lv, ...)
			return original.build(bt, if bt == "wall" then 1 else lv, ...)
		end
	end)
	caught("wall L3 is over its cap", "levels", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "wall" and lv == 3 then
				addParts(m, 12)
			end
			return m
		end
	end)
	caught("gate L3 lost its portcullis", "levels", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "gate" and lv == 3 then
				for _, p in parts(m) do
					if p.Name == "Portcullis" then
						p:Destroy()
					end
				end
			end
			return m
		end
	end)
	caught("the gate footprint grew", "levels", function()
		Kit.footprint = function(bt, lv)
			if bt == "gate" then
				return Vector2.new(32, 14)
			end
			return original.footprint(bt, lv)
		end
	end)
	caught("the gate has no Rally attachment", "levels", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "gate" then
				for _, a in (m.PrimaryPart :: BasePart):GetChildren() do
					if a.Name == "Rally" then
						a:Destroy()
					end
				end
			end
			return m
		end
	end)
	caught("opening the gate does nothing", "gatePose", function()
		Kit.setGateOpen = function() end
	end)
	caught("opening the gate adds a part", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			if open then
				addParts(m, 1)
			end
		end
	end)
	caught("the gate does not close exactly", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			if not open then
				for _, p in parts(m) do
					if p.Name == "GateLeaf" then
						p.CFrame = p.CFrame + Vector3.new(0.5, 0, 0)
					end
				end
			end
		end
	end)
	caught("the leaves open edge-on (90 degrees)", "gatePose", function()
		Buildings.GATE_OPEN_ANGLE = math.rad(88)
	end)
	caught("the leaves barely open (15 degrees)", "gatePose", function()
		Buildings.GATE_OPEN_ANGLE = math.rad(15)
	end)
	caught("one leaf is left closed when the gate opens", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			local done = false
			for _, p in parts(m) do
				if p.Name == "GateLeaf" and open and not done then
					done = true
					p.CFrame = (m.PrimaryPart :: BasePart).CFrame * (p:GetAttribute("KitGateClosedCF") :: CFrame)
				end
			end
		end
	end)
	caught("the portcullis only half lifts", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			for _, p in parts(m) do
				if (p.Name == "PortcullisBar" or p.Name == "Portcullis") and open then
					p.CFrame = p.CFrame - Vector3.new(0, 4, 0)
				end
			end
		end
	end)
	caught("a part stands in front of an open leaf", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			if open then
				local p = Instance.new("Part")
				p.Name = "Screen"
				p.Size = Vector3.new(10, 10, 0.5)
				p.CFrame = (m.PrimaryPart :: BasePart).CFrame * CFrame.new(0, 5, -8)
				p.Parent = m
			end
		end
	end)
	caught("the open leaves stay across the passage", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			for _, p in parts(m) do
				if p.Name == "GateLeaf" and open then
					p.CFrame = (m.PrimaryPart :: BasePart).CFrame * (p:GetAttribute("KitGateClosedCF") :: CFrame)
				end
			end
		end
	end)
	caught("the portcullis does not lift", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			for _, p in parts(m) do
				if p.Name == "PortcullisBar" then
					p.CFrame = (m.PrimaryPart :: BasePart).CFrame * (p:GetAttribute("KitGateClosedCF") :: CFrame)
				end
			end
		end
	end)
	caught("the pose is absolute, not relative to the Root", "gatePose", function()
		Kit.setGateOpen = function(m, open)
			original.setGateOpen(m, open)
			for _, p in parts(m) do
				local key = if open then "KitGateOpenCF" else "KitGateClosedCF"
				if typeof(p:GetAttribute(key)) == "CFrame" then
					p.CFrame = p:GetAttribute(key) :: CFrame
				end
			end
		end
	end)
	caught("the watchtower braziers are gone", "tower", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "watchtower" and lv == 2 then
				for _, p in parts(m) do
					if string.sub(p.Name, 1, 7) == "Brazier" then
						p:Destroy()
					end
				end
			end
			return m
		end
	end)
	caught("the watchtower L2 is over 130 parts", "tower", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "watchtower" and lv == 2 then
				addParts(m, 12)
			end
			return m
		end
	end)

	-- ram
	caught("the ram has no Log joint", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			for _, j in motors(m) do
				j.Name = "Joint"
			end
			return m
		end
	end)
	caught("the ram has a second joint", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			local extra = Instance.new("Motor6D")
			extra.Name = "Wheel"
			extra.Part0 = m.PrimaryPart
			extra.Part1 = m:FindFirstChild("Skid") :: BasePart
			extra.Parent = m.PrimaryPart
			return m
		end
	end)
	caught("the ram is over 45 parts", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			addParts(m, 8)
			return m
		end
	end)
	caught("a ram part is anchored", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color);
			(m:FindFirstChild("RoofSlab") :: BasePart).Anchored = true
			return m
		end
	end)
	caught("the ram faces +Z", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			for _, p in parts(m) do
				local cf = p.CFrame
				p.CFrame = CFrame.new(cf.X, cf.Y, -cf.Z) * (cf - cf.Position)
			end
			return m
		end
	end)
	caught("the thrust pose does nothing", "ram", function()
		Kit.siegePose = function() end
	end)
	caught("the thrust is not clamped", "ram", function()
		Kit.siegePose = function(m, t)
			local joint = jointByName(m, "Log")
			if joint then
				joint.Transform = CFrame.new(0, 0, -Siege.THRUST_TRAVEL * t)
			end
		end
	end)
	caught("the ram feet float", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color);
			(m.PrimaryPart :: BasePart).PivotOffset = CFrame.new(0, -1, 0)
			return m
		end
	end)
	caught("the ram head is a round dark cap", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			local head = m:FindFirstChild("RamHead") :: BasePart
			local cap = Instance.new("Part")
			cap.Name = "RamHead"
			cap.Shape = Enum.PartType.Cylinder
			cap.Size = Vector3.new(1, 3, 3)
			cap.Color = head.Color
			cap.CFrame = head.CFrame
			cap.Massless, cap.CanCollide, cap.Anchored = true, false, false
			cap.Parent = m
			local weld = Instance.new("Weld")
			weld.Name = "RigWeld"
			weld.Part0 = m:FindFirstChild("Log") :: BasePart
			weld.Part1 = cap
			weld.Parent = cap
			head:Destroy()
			return m
		end
	end)
	caught("the log is a short stub", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color);
			(m:FindFirstChild("Log") :: BasePart).Size = Vector3.new(8, 3, 3)
			return m
		end
	end)
	caught("the log is dark like the iron", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color);
			(m:FindFirstChild("Log") :: BasePart).Color = Color3.fromRGB(40, 40, 46)
			return m
		end
	end)
	caught("the sides are boarded over the log", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			for _, sx in { -1, 1 } do
				local p = Instance.new("Part")
				p.Name = "Cover"
				p.Size = Vector3.new(0.4, 4, 12)
				p.CFrame = (m.PrimaryPart :: BasePart).CFrame * CFrame.new(sx * 2.6, 3.4, -2.8)
				p.Massless, p.CanCollide, p.Anchored = true, false, false
				p.Parent = m
			end
			return m
		end
	end)
	caught("the roof reaches over the whole log", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			for _, name in { "RoofSlab", "RoofEdge" } do
				local p = m:FindFirstChild(name) :: BasePart
				p.CFrame = p.CFrame - Vector3.new(0, 0, 6)
			end
			return m
		end
	end)
	caught("the roof is a tall cabin", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color)
			local p = m:FindFirstChild("RoofSlab") :: BasePart
			p.CFrame = p.CFrame + Vector3.new(0, 3, 0)
			return m
		end
	end)
	caught("the kingdom colour is on the log", "ram", function()
		Kit.siege = function(kind, color)
			local m = original.siege(kind, color);
			(m:FindFirstChild("Log") :: BasePart):SetAttribute("KitTint", 1)
			return m
		end
	end)

	-- the L3 wall and the gate's shape
	caught("the L3 wall has the L2 outline", "wallL3", function()
		Kit.build = function(bt, lv, ...)
			return original.build(bt, if bt == "wall" and lv == 3 then 2 else lv, ...)
		end
	end)
	local function tweakWall(name: string, fn: (BasePart) -> ())
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "wall" and lv == 3 then
				for _, p in parts(m) do
					if p.Name == name then
						fn(p)
					end
				end
			end
			return m
		end
	end
	caught("the L3 brazier sinks into the crenellation", "wallL3", function()
		tweakWall("BrazierBowl", function(p)
			p.CFrame = p.CFrame - Vector3.new(0, 5, 0)
		end)
	end)
	caught("the L3 brazier legs stand in the crenellation, not on the plinth", "wallL3", function()
		tweakWall("BrazierLeg", function(p)
			p.CFrame = p.CFrame - Vector3.new(0, 2.8, 0)
		end)
	end)
	caught("the L3 brazier plinth sunk into the walkway", "wallL3", function()
		tweakWall("BrazierPlinth", function(p)
			p.CFrame = p.CFrame - Vector3.new(0, 2, 0)
		end)
	end)
	caught("the L3 brazier slid off its plinth", "wallL3", function()
		tweakWall("BrazierBowl", function(p)
			p.CFrame = p.CFrame + Vector3.new(2.5, 0, 0)
		end)
	end)
	caught("the L3 buttresses stop halfway", "wallL3", function()
		tweakWall("Buttress", function(p)
			p.Size = Vector3.new(p.Size.X, 4, p.Size.Z)
		end)
	end)
	caught("the L3 end piers are only wall height", "wallL3", function()
		tweakWall("EndPier", function(p)
			p.Size = Vector3.new(p.Size.X, 10, p.Size.Z)
		end)
	end)
	caught("the L3 banners are no wider than L2's", "wallL3", function()
		tweakWall("Banner", function(p)
			p.Size = Vector3.new(2.6, p.Size.Y, p.Size.Z)
		end)
	end)
	local function tweakGate(name: string, fn: (BasePart) -> ())
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "gate" then
				for _, p in parts(m) do
					if p.Name == name then
						fn(p)
					end
				end
			end
			return m
		end
	end
	caught("the arch shows sky above the closed leaves (no tympanum)", "gateShape", function()
		tweakGate("Tympanum", function(p)
			p:Destroy()
		end)
	end)
	caught("the passage floor matches the wall", "gateShape", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "gate" then
				local tower = named(m, "GateTower")[1]
				for _, p in parts(m) do
					if p.Name == "GateRoad" then
						p.Color = tower.Color
					end
				end
			end
			return m
		end
	end)
	caught("the L3 buttresses are flat upright planks again", "wallL3", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "wall" and lv == 3 then
				for _, sx in { -1, 1 } do
					local seen = 0
					for _, p in parts(m) do
						if p.Name == "Buttress" and (p.CFrame.Position.X < 0) == (sx < 0) then
							seen += 1
							p.Size = Vector3.new(2.2, 7.3, 1.8)
							p.CFrame = CFrame.new(p.CFrame.Position.X, p.CFrame.Position.Y, -4.4)
						end
					end
				end
			end
			return m
		end
	end)
	caught("a kingdom's palisade is grey stone-coloured again", "palisade", function()
		Kit.build = function(bt, lv, stage, color, ...)
			local m = original.build(bt, lv, stage, color, ...)
			if bt == "wall" and lv == 1 and color == CANON.azure then
				for _, p in parts(m) do
					if p.Name == "Palisade" then
						p.Color = Color3.fromRGB(128, 126, 124)
					end
				end
			end
			return m
		end
	end)
	caught("the watchtower cap floats over the platform (no seat)", "tower", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "watchtower" then
				for _, p in parts(m) do
					if p.Name == "CapSeat" then
						p:Destroy()
					end
				end
			end
			return m
		end
	end)
	caught("the gate's span sits lower than its towers (a saddle)", "gateShape", function()
		tweakGate("Lintel", function(p)
			p.Size = Vector3.new(p.Size.X, p.Size.Y - 4, p.Size.Z)
			p.CFrame = p.CFrame - Vector3.new(0, 2, 0)
		end)
	end)
	caught("the voussoirs float in front of the facade", "gateShape", function()
		tweakGate("Voussoir", function(p)
			p.CFrame = p.CFrame - Vector3.new(0, 0, 0.8)
		end)
	end)
	caught("the passage floor is near-black again (a void at 170 studs)", "gateShape", function()
		tweakGate("GateRoad", function(p)
			p.Color = Color3.fromRGB(78, 68, 60)
		end)
	end)
	caught("the passage floor is white", "gateShape", function()
		tweakGate("GateRoad", function(p)
			p.Color = Color3.fromRGB(235, 228, 214)
		end)
	end)
	caught("the L3 arch shows sky between the portcullis bars (no door head behind them)", "gateShape", function()
		Kit.build = function(bt, lv, ...)
			local m = original.build(bt, lv, ...)
			if bt == "gate" and lv == 3 then
				for _, p in parts(m) do
					if p.Name == "Tympanum" then
						p:Destroy()
					end
				end
			end
			return m
		end
	end)
	caught("the passage floor is near the wall's value (mid grey on a mid stone)", "gateShape", function()
		tweakGate("GateRoad", function(p)
			p.Color = Color3.fromRGB(122, 118, 112)
		end)
	end)
	caught("the gate leaves are dark", "gateShape", function()
		tweakGate("GateLeaf", function(p)
			p.Color = Color3.fromRGB(30, 26, 22)
		end)
	end)
end)
