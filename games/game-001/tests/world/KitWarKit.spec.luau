--[[
	The war kit's structures (FL-0128, FORGE-02, Operation Crownfall): walls and gates at three levels, the war-ready
	watchtower and the battering ram. Everything is part-built (D-026) and kingdom-tinted. This spec pins:

	  1. levels    wall L1-3 and gate L1-3: distinct (level-specific parts, rising height), within their per-level part
	               caps (wall 30/45/60, gate 90/120/150) for every kingdom, footprints unchanged (32x8, 32x12), the Door
	               (and the gate's Rally) attachments where they were;
	  2. gatePose  Kit.setGateOpen moves leaves and portcullis by CFrame alone: no part added or removed, exactly the
	               movable parts move, the round trip is exact, a moved and turned gate still opens, the open leaves clear
	               the passage and the closed ones span it, the portcullis lifts, the recolour keeps the pose;
	  3. tower     watchtower L2 is war-ready (hoarding galleries, braziers, more merlons, slits) within its cap;
	  4. ram       Kit.siege("ram"): at most 45 parts, the character rig conventions (Root anchored and invisible, feet
	               at y = 0, front -Z, every other part welded, Massless, non-colliding) and ONE Motor6D "Log" that
	               Kit.siegePose drives (clamped, monotone, exactly Siege.THRUST_TRAVEL forward at 1);
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
	local rise = { wall = { 0, 4, 0 }, gate = { 0, 1.5, 1.5 } } -- the model's top must rise at least this much per level
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
						for _, absent in { "Merlon", "Curtain", "Buttress", "BrazierBowl" } do
							need(out, tag, hs, absent, NONE, "stone parts belong to L2+")
						end
					else
						need(out, tag, hs, "Palisade", NONE, "stone from L2")
						need(out, tag, hs, "Curtain", exactly(1), "the stone curtain")
						need(out, tag, hs, "Merlon", atLeast(12), "crenellations")
						need(out, tag, hs, "Buttress", exactly(if lv == 3 then 4 else 0), "four buttresses at L3 only")
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
			-- the passage (x within +-6.4): leaves span it closed, clear it open; the portcullis rises
			local leafOpen, leafClosed = {}, {}
			for p, was in closed do
				if p.Name == "GateLeaf" then
					local e = halfExtents(p)
					table.insert(leafOpen, { math.abs(rel(m, p).X) - e.X, e.X })
					local ec = (was :: CFrame).Position
					table.insert(leafClosed, ec)
				end
			end
			for _, l in leafOpen do
				if l[1] < 6.4 then
					table.insert(
						out,
						`{tag}: an open leaf still reaches into the passage (inner edge {r3(l[1])} < 6.4)`
					)
				end
				if l[2] > 1.0 then
					table.insert(out, `{tag}: an open leaf is {r3(l[2] * 2)} studs across (should lie along the wall)`)
				end
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
				for p, was in closed do
					if p.Name == "PortcullisBar" then
						local rise = rel(m, p).Y - (was :: CFrame).Y
						if math.abs(rise - 7) > 1e-3 then
							table.insert(out, `{tag}: a portcullis bar rises {r3(rise)} (want 7)`)
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
	it("opens and closes the gate by CFrame alone", function()
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
	}
	local function restore()
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
		for _, name in { "levels", "gatePose", "tower", "ram" } do
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
end)
