--[[
	Kit.carried(resource) (visual upgrade, FORGE-02; FORGE-04's carry pose): the load a citizen holds in both hands, attached by
	EntityController at CFrame.new(0, 0, -1.2) on the Torso. This spec pins:
	  1. shape      a Model of 3 or 4 parts, one PrimaryPart whose pivot is the build origin, every other part welded to it, no
	                scripts, unanchored, massless, no collide / touch / query, attributes KitCarried and KitPiece;
	  2. fit        centred on the pivot (within 0.15 studs), at most 2.6 wide, 1.2 tall and 1.2 deep (between the hands, in front of the
	                chest), nothing behind the chest plane (z <= 0.6);
	  3. read       the four loads have clearly different key colours (the part with the most volume) and each stays inside its
	                resource's colour family (food red/gold basket, wood brown, stone pale grey, gold yellow), so a load reads like its node;
	  4. api        deterministic, an unknown resource errors, Kit.carried and Kit.CARRIED are exported;
	  5. mutants    each rule fails when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Gear = require("@game/ReplicatedStorage/Game/Kit/Gear")

local function bodyParts(model: Model): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local cf, s = p.CFrame, p.Size
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf * Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
					lo, hi = lo:Min(w), hi:Max(w)
				end
			end
		end
	end
	return lo, hi
end

-- everything the rules say about one load; empty when it is right
local function problems(resource: string, model: Model): { string }
	local out: { string } = {}
	local function add(msg: string)
		table.insert(out, `{resource}: {msg}`)
	end
	local parts = bodyParts(model)
	if #parts < 3 or #parts > Gear.MAX_PARTS_PER_CARRIED then
		add(`{#parts} parts, want 3 or {Gear.MAX_PARTS_PER_CARRIED}`)
	end
	local primary = model.PrimaryPart
	if primary == nil then
		add("no PrimaryPart")
		return out
	end
	local pivot = primary.CFrame * primary.PivotOffset
	if (pivot.Position - Vector3.zero).Magnitude > 1e-3 then
		add("the pivot is not the build origin")
	end
	if model:GetAttribute("KitCarried") ~= resource or model:GetAttribute("KitPiece") ~= "Carried" then
		add("attributes KitCarried / KitPiece are missing")
	end
	for _, p in parts do
		if p.Anchored or not p.Massless or p.CanCollide or p.CanTouch or p.CanQuery then
			add(`{p.Name} is anchored, has mass or collides / touches / queries`)
		end
		if p ~= primary then
			local welded = false
			for _, w in p:GetChildren() do
				if w:IsA("WeldConstraint") and (w.Part0 == primary or w.Part1 == primary) then
					welded = true
				end
			end
			if not welded then
				add(`{p.Name} is not welded to the PrimaryPart`)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			add("holds a script")
		end
	end
	local lo, hi = bounds(parts)
	local size, centre = hi - lo, (hi + lo) / 2
	local limit = Gear.CARRIED_BOUNDS
	if size.X > limit.X + 1e-3 or size.Y > limit.Y + 1e-3 or size.Z > limit.Z + 1e-3 then
		add(
			`measures {string.format("%.2f x %.2f x %.2f", size.X, size.Y, size.Z)}, more than {limit.X} x {limit.Y} x {limit.Z}`
		)
	end
	if centre.Magnitude > 0.15 then
		add(`its centre is {string.format("%.2f", centre.Magnitude)} studs off the pivot`)
	end
	if hi.Z > 0.6 + 1e-3 then
		add("it reaches behind the chest plane")
	end
	return out
end

-- the colour of the part with the most volume
local function keyColour(model: Model): Color3
	local best, bestVolume = Color3.new(), -1
	for _, p in bodyParts(model) do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > bestVolume then
			best, bestVolume = p.Color, v
		end
	end
	return best
end

local function distance(a: Color3, b: Color3): number
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) * 255
end

local function colourProblems(models: { [string]: Model }): { string }
	local out: { string } = {}
	local keys: { [string]: Color3 } = {}
	for r, m in models do
		keys[r] = keyColour(m)
	end
	for _, a in Gear.RESOURCES do
		for _, b in Gear.RESOURCES do
			if a < b and distance(keys[a], keys[b]) < 60 then
				table.insert(out, `{a} and {b} have almost the same key colour`)
			end
		end
	end
	local function lum(c: Color3): number
		return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
	end
	-- families: stone pale and grey, gold yellow, wood brown, food warm
	local s, g, w = keys.stone, keys.gold, keys.wood
	if lum(s) < 0.65 or math.abs(s.R - s.B) > 0.12 then
		table.insert(out, "stone is not pale grey")
	end
	if not (g.R > 0.85 and g.G > 0.6 and g.B < 0.35) then
		table.insert(out, "gold is not yellow")
	end
	if not (w.R > w.G and w.G > w.B and lum(w) < 0.5) then
		table.insert(out, "wood is not brown")
	end
	return out
end

local function all(): { [string]: Model }
	local out = {}
	for _, r in Gear.RESOURCES do
		out[r] = Kit.carried(r)
	end
	return out
end

describe("Kit.carried", function()
	it("is exported with its resources", function()
		expect(Kit.carried).toBe(Gear.carried)
		expect(table.concat(Kit.CARRIED, ",")).toBe("food,wood,stone,gold")
	end)

	it("builds a welded, scriptless, weightless Model that fits between the hands, for every resource", function()
		local list: { string } = {}
		for r, m in all() do
			for _, msg in problems(r, m) do
				table.insert(list, msg)
			end
		end
		if #list > 0 then
			error(`{#list} problems, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
		end
	end)

	it("makes each load read as its resource: distinct key colours in the node markers' families", function()
		local list = colourProblems(all())
		if #list > 0 then
			error(table.concat(list, "; "))
		end
	end)

	it("is deterministic and errors on an unknown resource", function()
		for _, r in Gear.RESOURCES do
			local a, b = bodyParts(Kit.carried(r)), bodyParts(Kit.carried(r))
			expect(#a).toBe(#b)
			for i = 1, #a do
				expect(a[i].Size).toBe(b[i].Size)
				expect(a[i].Color).toBe(b[i].Color)
			end
		end
		local ok = pcall(Kit.carried, "iron")
		expect(ok).toBe(false)
	end)
end)

describe("Kit.carried mutants are caught", function()
	local function caught(name: string, resource: string, mutate: (Model) -> ())
		it(`catches: {name}`, function()
			local m = Kit.carried(resource)
			mutate(m)
			if #problems(resource, m) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end
	caught("an oversize part (wider than the hands)", "wood", function(m)
		local p = bodyParts(m)[2]
		p.Size = Vector3.new(3.4, p.Size.Y, p.Size.Z)
	end)
	caught("a fifth part", "gold", function(m)
		local extra = Instance.new("Part")
		extra.Name = "Extra"
		extra.Massless, extra.CanCollide, extra.CanTouch, extra.CanQuery = true, false, false, false
		extra.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = m.PrimaryPart, extra
		w.Parent = extra
	end)
	caught("a collidable part", "stone", function(m)
		bodyParts(m)[2].CanCollide = true
	end)
	caught("a queryable part", "food", function(m)
		bodyParts(m)[3].CanQuery = true
	end)
	caught("an unwelded part", "food", function(m)
		for _, d in m:GetDescendants() do
			if d:IsA("WeldConstraint") then
				d:Destroy()
				break
			end
		end
	end)
	caught("an anchored part", "wood", function(m)
		bodyParts(m)[1].Anchored = true
	end)
	caught("a script inside", "gold", function(m)
		local s = Instance.new("Script")
		s.Parent = m
	end)
	caught("off the pivot", "stone", function(m)
		for _, p in bodyParts(m) do
			p.CFrame = p.CFrame + Vector3.new(0, 0, 1.4)
		end
	end)
	it("catches: a Model without a PrimaryPart", function()
		local m = Instance.new("Model")
		for _, p in bodyParts(Kit.carried("wood")) do
			p.Parent = m
		end
		if #problems("wood", m) == 0 then
			error("mutant not caught: no PrimaryPart")
		end
	end)
	it("catches: two loads with the same colour (read)", function()
		local models = all()
		for _, p in bodyParts(models.wood) do
			p.Color = keyColour(models.food)
		end
		for _, p in bodyParts(models.stone) do
			p.Color = Color3.fromRGB(122, 78, 44)
		end
		if #colourProblems(models) == 0 then
			error("mutant not caught: same key colours")
		end
	end)
end)
