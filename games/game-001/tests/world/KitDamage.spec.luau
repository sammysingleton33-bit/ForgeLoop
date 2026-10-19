--[[
	Damage states on buildings (FL-0128, FORGE-02, Operation Crownfall): the model attribute `Damage` (0..1) is turned into
	parts by Kit.applyDamage (Kit/Damage.luau). This spec pins:

	  1. states     Damage 0 (and anything under 0.25 or not a number) is exactly the model as built; the four thresholds
	                0.25/0.5/0.75/0.95 add and remove exactly the documented cracks, rubble, smoke and missing parts, at most 14
	                extra parts, harmless to touch;
	  2. repair     deterministic, idempotent and reversible in any order: a repaired model is exactly the model as built;
	  3. burning    the Burning attribute and the model's top are untouched (FORGE-04's Burning look reads both), the smoke
	                stays inside the model;
	  4. recolour   Kit.setKingdomColor works on damaged models and on the parts waiting for a repair;
	  5. mutants    the key rules above are caught when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Damage = require("@game/ReplicatedStorage/Game/Kit/Damage")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local MAX_LEVEL = { keep = 3, barracks = 4, wall = 3, gate = 3 }

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

type Check = () -> { string }
local CHECKS: { [string]: Check } = {}

local function shapeOf(p: BasePart): string
	if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
		return "ball"
	elseif p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Cylinder then
		return "cylinder"
	end
	return "box"
end

-- ------------------------------------------------------------------ 6. damage

local DAMAGE_TYPES = {}
for _, bt in Kit.BUILDING_TYPES do
	table.insert(DAMAGE_TYPES, { bt, MAX_LEVEL[bt] or 2 })
end

local function damaged(bt: string, lv: number, hue: string, d: any): Model
	local m = Kit.build(bt, lv, "complete", CANON[hue])
	m:SetAttribute("Damage", d)
	Kit.applyDamage(m)
	return m
end

local function extras(m: Model, kind: string?): number
	local n = 0
	for _, c in m:GetChildren() do
		if
			c:IsA("BasePart")
			and c:GetAttribute("KitDamage") == true
			and (kind == nil or c:GetAttribute("KitDamageKind") == kind)
		then
			n += 1
		end
	end
	return n
end

local STATE_AT = { 0.25, 0.5, 0.75, 0.95 }

CHECKS.damage = function()
	local out: { string } = {}
	-- the table and the pure functions
	if table.concat(Kit.DAMAGE_THRESHOLDS, ",") ~= "0.25,0.5,0.75,0.95" or Damage.MAX_EXTRA_PARTS ~= 14 then
		table.insert(out, "thresholds are not 0.25/0.5/0.75/0.95 or the extra budget is not 14")
	end
	for _, c in
		{
			{ 0, 0 },
			{ 0.2499, 0 },
			{ 0.25, 1 },
			{ 0.4999, 1 },
			{ 0.5, 2 },
			{ 0.75, 3 },
			{ 0.9499, 3 },
			{ 0.95, 4 },
			{ 1, 4 },
			{ 7, 4 },
			{ -1, 0 },
			{ 0 / 0, 0 },
		}
	do
		if Kit.damageState(c[1]) ~= c[2] then
			table.insert(out, `damageState({c[1]}) = {Kit.damageState(c[1])}, want {c[2]}`)
		end
	end
	if Kit.damageState("0.9" :: any) ~= 0 or Kit.damageState(nil :: any) ~= 0 then
		table.insert(out, "damageState of a non-number must be 0")
	end
	for _, c in { { 50, 100, 0.5 }, { 0, 100, 1 }, { 100, 100, 0 }, { 150, 100, 0 }, { -5, 100, 1 }, { 1, 0, 0 } } do
		if math.abs(Kit.damageFromHp(c[1], c[2]) - c[3]) > 1e-9 then
			table.insert(out, `damageFromHp({c[1]}, {c[2]}) = {Kit.damageFromHp(c[1], c[2])}, want {c[3]}`)
		end
	end
	local cracks, rubble, smoke = Damage.CRACKS, Damage.RUBBLE, Damage.SMOKE
	for _, hue in { "crimson", "emerald" } do
		for _, e in DAMAGE_TYPES do
			local bt, lv = e[1], e[2]
			local tag = `{bt} L{lv} {hue}`
			local base = Kit.build(bt, lv, "complete", CANON[hue])
			local baseSig, baseN, baseTop = signature(base), count(base), topOf(base)
			-- Damage 0 (and every non-number, and 0.2499) is exactly the model as built
			for _, zero in { 0, 0.2499, "x", 0 / 0 } do
				local z = damaged(bt, lv, hue, zero)
				if signature(z) ~= baseSig or z:GetAttribute("KitDamageState") ~= nil or extras(z) > 0 then
					table.insert(out, `{tag}: Damage {zero} is not the model as built`)
				end
			end
			local removedBefore = 0
			for s = 1, 4 do
				local m = damaged(bt, lv, hue, STATE_AT[s])
				local stag = `{tag} state {s}`
				if m:GetAttribute("KitDamageState") ~= s then
					table.insert(out, `{stag}: KitDamageState {m:GetAttribute("KitDamageState")}`)
				end
				local ex = extras(m)
				if ex > Damage.MAX_EXTRA_PARTS then
					table.insert(out, `{stag}: {ex} extra parts (cap 14)`)
				end
				local hasBody = extras(m, "crack") > 0
				if hasBody then
					if extras(m, "crack") ~= cracks[s] or extras(m, "rubble") ~= rubble[s] then
						table.insert(
							out,
							`{stag}: cracks {extras(m, "crack")}/{cracks[s]} rubble {extras(m, "rubble")}/{rubble[s]}`
						)
					end
				elseif not (bt == "wall" and lv == 1) then
					table.insert(out, `{stag}: no wall to crack`)
				end
				if extras(m, "smoke") ~= smoke[s] then
					table.insert(out, `{stag}: smoke {extras(m, "smoke")}, want {smoke[s]}`)
				end
				-- parts that went missing: monotone, at least the documented number where the model has them
				local removed = baseN - (count(m) - ex)
				if removed < removedBefore then
					table.insert(out, `{stag}: {removed} parts removed, fewer than state {s - 1} ({removedBefore})`)
				end
				removedBefore = removed
				if removed < math.min(Damage.REMOVED[s], 1) then
					table.insert(out, `{stag}: nothing goes missing`)
				end
				if s == 1 and removed > Damage.REMOVED[1] then
					table.insert(out, `{stag}: {removed} parts removed, state 1 removes {Damage.REMOVED[1]}`)
				end
				-- the damage parts: thin dark wedges, grey translucent balls, blocks; all harmless to touch
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p:GetAttribute("KitDamage") == true then
						local kind = p:GetAttribute("KitDamageKind")
						if p.CanCollide or p.CanQuery or p.CanTouch then
							table.insert(out, `{stag}: a {kind} part can collide or be touched`)
						end
						if
							kind == "crack"
							and not (
								p.ClassName == "WedgePart"
								and math.min(p.Size.X, p.Size.Z) <= 0.15
								and p.Color.R < 0.2
							)
						then
							table.insert(out, `{stag}: a crack is not a thin dark wedge`)
						elseif
							kind == "smoke"
							and not (shapeOf(p) == "ball" and p.Transparency >= 0.5 and p.Transparency < 1)
						then
							table.insert(out, `{stag}: smoke is not a translucent ball`)
						elseif kind == "rubble" and shapeOf(p) ~= "box" then
							table.insert(out, `{stag}: rubble is not a block`)
						end
					end
				end
				-- the Burning look reads the model's top: still the same part, no smoke above it
				if math.abs(topOf(m, true) - baseTop) > 1e-6 or topOf(m) > baseTop + 1e-6 then
					table.insert(out, `{stag}: the model's top moved ({r3(baseTop)} -> {r3(topOf(m))})`)
				end
				-- deterministic: the same build and damage, the same parts
				if signature(m) ~= signature(damaged(bt, lv, hue, STATE_AT[s])) then
					table.insert(out, `{stag}: not deterministic`)
				end
				-- repair: back to exactly the model as built
				m:SetAttribute("Damage", 0)
				Kit.applyDamage(m)
				if signature(m) ~= baseSig or m:GetAttribute("KitDamageState") ~= nil then
					table.insert(out, `{stag}: repair does not restore the model exactly`)
				end
			end
			-- any order, and applying twice is applying once
			local m = Kit.build(bt, lv, "complete", CANON[hue])
			for _, d in { 0.97, 0.3, 0.6, 0.6, 0.1, 0.8, 0.3 } do
				m:SetAttribute("Damage", d)
				Kit.applyDamage(m)
				Kit.applyDamage(m)
				if signature(m) ~= signature(damaged(bt, lv, hue, d)) then
					table.insert(
						out,
						`{tag}: after the sequence ending at Damage {d} the model differs from a fresh one`
					)
					break
				end
			end
			-- a burning model still burns: the attribute is not touched
			local burning = Kit.build(bt, lv, "complete", CANON[hue])
			burning:SetAttribute("Burning", true)
			burning:SetAttribute("Hp", 12)
			burning:SetAttribute("MaxHp", 100)
			burning:SetAttribute("Damage", Kit.damageFromHp(12, 100))
			Kit.applyDamage(burning)
			if
				burning:GetAttribute("Burning") ~= true
				or burning:GetAttribute("Hp") ~= 12
				or burning:GetAttribute("MaxHp") ~= 100
			then
				table.insert(out, `{tag}: damage touched the Burning, Hp or MaxHp attributes`)
			end
			-- smoke stays inside the model's footprint box
			for _, p in burning:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "smoke" then
					local ext = {}
					for _, q in parts(base) do
						ext.lo = math.min(ext.lo or math.huge, q.CFrame.Position.X - halfExtents(q).X)
						ext.hi = math.max(ext.hi or -math.huge, q.CFrame.Position.X + halfExtents(q).X)
					end
					local x = p.CFrame.Position.X
					if x < ext.lo or x > ext.hi then
						table.insert(out, `{tag}: smoke at x {r3(x)} outside the model {r3(ext.lo)}..{r3(ext.hi)}`)
					end
				end
			end
			-- the kingdom colour still works on a damaged model, before and after the repair
			if bt ~= "wall" or lv > 1 then
				local newColor = Color3.fromRGB(196, 60, 52)
				local hurt = damaged(bt, lv, hue, 0.9)
				Kit.setKingdomColor(hurt, newColor)
				local fresh = damaged(bt, lv, hue, 0.9)
				Kit.setKingdomColor(fresh, newColor)
				local direct = Kit.build(bt, lv, "complete", CANON[hue])
				Kit.setKingdomColor(direct, newColor)
				direct:SetAttribute("Damage", 0.9)
				Kit.applyDamage(direct)
				if signature(hurt, false) ~= signature(direct, false) then
					table.insert(out, `{tag}: recolour then damage differs from damage then recolour`)
				end
				hurt:SetAttribute("Damage", 0)
				Kit.applyDamage(hurt)
				local plain = Kit.build(bt, lv, "complete", CANON[hue])
				Kit.setKingdomColor(plain, newColor)
				if signature(hurt, false) ~= signature(plain, false) then
					table.insert(out, `{tag}: parts that were off while recolouring come back in the old colour`)
				end
			end
		end
	end
	-- construction stages and part-less models ignore Damage
	local stage = damaged("keep", 1, "crimson", 0.9)
	stage:Destroy()
	local building = Kit.build("keep", 1, 1, CANON.crimson)
	building:SetAttribute("Damage", 0.9)
	Kit.applyDamage(building)
	if extras(building) > 0 or building:GetAttribute("KitDamageState") ~= nil then
		table.insert(out, "a construction stage was damaged")
	end
	local empty = Instance.new("Model")
	empty:SetAttribute("Damage", 0.9)
	local ok = pcall(Kit.applyDamage, empty)
	if not ok then
		table.insert(out, "a model without a PrimaryPart made applyDamage error")
	end
	return out
end

-- ------------------------------------------------------------------ the spec

local function expectClean(list: { string })
	if #list > 0 then
		error(`{#list} violations, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
	end
end

describe("Damage states (FL-0128)", function()
	it("adds and removes exactly the documented parts, deterministically and reversibly", function()
		expectClean(CHECKS.damage())
	end)
end)

-- ------------------------------------------------------------------ mutants

describe("Damage mutants are caught", function()
	local original = {
		build = Kit.build,
		applyDamage = Kit.applyDamage,
		setKingdomColor = Kit.setKingdomColor,
		stashed = Damage.stashed,
	}
	local function restore()
		Kit.build = original.build
		Kit.applyDamage = original.applyDamage
		Kit.setKingdomColor = original.setKingdomColor
		Damage.stashed = original.stashed
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
	it("passes unmutated (the baseline)", function()
		for _, name in { "damage" } do
			expectClean(CHECKS[name]())
		end
	end)

	caught("applyDamage does nothing", "damage", function()
		Kit.applyDamage = function() end
	end)
	caught("Damage 0 still adds a part", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 0 then
				local p = Instance.new("Part")
				p.Name = "Soot"
				p:SetAttribute("KitDamage", true)
				p.Parent = m
			end
		end
	end)
	caught("the damage budget is exceeded", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 4 then
				for i = 1, 4 do
					local p = Instance.new("Part")
					p.Name = `Soot{i}`
					p.Anchored = true
					p.CanCollide = false
					p.CanTouch = false
					p.CanQuery = false
					p:SetAttribute("KitDamage", true)
					p:SetAttribute("KitDamageKind", "rubble")
					p.Parent = m
				end
			end
		end
	end)
	caught("damage is random", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "crack" then
					p.CFrame = p.CFrame + Vector3.new(math.random(), 0, 0)
				end
			end
		end
	end)
	caught("a repair leaves the damage parts behind", "damage", function()
		Kit.applyDamage = function(m)
			local before = m:GetAttribute("KitDamageState")
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 0 and before ~= nil then
				local p = Instance.new("Part")
				p.Name = "Stain"
				p:SetAttribute("KitDamage", true)
				p.Parent = m
			end
		end
	end)
	caught("damage clears the Burning attribute", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			m:SetAttribute("Burning", nil)
		end
	end)
	caught("damage removes the top of the model", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) >= 2 then
				local top, topY = nil, -math.huge
				for _, p in parts(m) do
					if p:GetAttribute("KitDamage") ~= true and p.CFrame.Position.Y + halfExtents(p).Y > topY then
						top, topY = p, p.CFrame.Position.Y + halfExtents(p).Y
					end
				end
				if top then
					top:Destroy()
				end
			end
		end
	end)
	caught("the recolour forgets the parts waiting for a repair", "damage", function()
		Damage.stashed = function()
			return {}
		end
	end)
	caught("damage is applied to construction stages", "damage", function()
		Kit.build = function(bt, lv, stage, ...)
			local m = original.build(bt, lv, stage, ...)
			if stage ~= "complete" then
				m:SetAttribute("KitStage", "complete")
			end
			return m
		end
	end)
end)
