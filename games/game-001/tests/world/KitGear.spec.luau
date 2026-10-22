--[[
	Kit.armour, Kit.shield and Kit.weapon (FL-0072, FORGE-02; CONTRACTS G12.1 Armour / Weapon, G12.6, design/crown-arena.md §5; D-026):
	duel gear. Armour = Accessories on body attachments that fit R15 and R6 (stand-in avatars, tests/world/support): light, medium,
	heavy, with distinct silhouettes (sidegrades) and kingdom trim. Weapons = Tools with a Handle, welded parts, no scripts,
	held upright through Grip, four distinct silhouettes. The sword-and-shield's shield is also an Accessory on the left hand
	(Kit.shield, LeftGripAttachment); Kit.weapon("swordShield") still carries its own shield on the Tool unless opts.shield == false.
	Primitive parts only, no yields. Studio fit is UNVERIFIED: the stand-ins follow the Roblox
	attachment reference, nobody has seen the gear on a real rig.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Avatar = require("./support/AvatarStandIn")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local COLORS: { Color3 } = { CANON.crimson, CANON.azure, CANON.emerald, CANON.gold, Kit.NEUTRAL_COLOR }
local ARMOURS = Kit.ARMOURS
local WEAPONS = Kit.WEAPONS

-- the accessories of each armour: name -> body attachment
local PIECES: { [string]: { [string]: string } } = {
	light = {
		KitLightCap = "HatAttachment",
		KitLightJerkin = "BodyFrontAttachment",
		KitLightCloak = "BodyBackAttachment",
	},
	medium = {
		KitMediumHelm = "HatAttachment",
		KitMediumMail = "BodyFrontAttachment",
		KitMediumPauldronLeft = "LeftCollarAttachment",
		KitMediumPauldronRight = "RightCollarAttachment",
	},
	heavy = {
		KitHeavyHelm = "HatAttachment",
		KitHeavyPlate = "BodyFrontAttachment",
		KitHeavyBack = "BodyBackAttachment",
		KitHeavyPauldronLeft = "LeftCollarAttachment",
		KitHeavyPauldronRight = "RightCollarAttachment",
	},
}
local WEAPON_REACH = { mace = 5.5, swordShield = 4.9, greatsword = 7.8, spear = 9.5 }

local function noYield<R>(fn: () -> R): R
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "Kit yielded")
	return result
end

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function halfExtents(p: BasePart): Vector3
	local s = p.Size
	local rv, uv, lv = p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector
	return Vector3.new(
		math.abs(rv.X) * s.X / 2 + math.abs(uv.X) * s.Y / 2 + math.abs(lv.X) * s.Z / 2,
		math.abs(rv.Y) * s.X / 2 + math.abs(uv.Y) * s.Y / 2 + math.abs(lv.Y) * s.Z / 2,
		math.abs(rv.Z) * s.X / 2 + math.abs(uv.Z) * s.Y / 2 + math.abs(lv.Z) * s.Z / 2
	)
end

local function boundsOf(list: { BasePart }): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in list do
		local e, c = halfExtents(p), p.CFrame.Position
		lo = lo:Min(c - e)
		hi = hi:Max(c + e)
	end
	return lo, hi
end

local function outline(
	list: { BasePart },
	u: string,
	v: string,
	uMin: number,
	vMin: number,
	cols: number,
	rows: number
): { boolean }
	local cells = table.create(cols * rows, false)
	for _, p in list do
		local e, c = halfExtents(p), p.CFrame.Position
		local u0, u1 = math.floor((c[u] - e[u] - uMin) / 0.5), math.ceil((c[u] + e[u] - uMin) / 0.5) - 1
		local v0, v1 = math.floor((c[v] - e[v] - vMin) / 0.5), math.ceil((c[v] + e[v] - vMin) / 0.5) - 1
		for i = math.max(0, u0), math.min(cols - 1, u1) do
			for j = math.max(0, v0), math.min(rows - 1, v1) do
				cells[j * cols + i + 1] = true
			end
		end
	end
	return cells
end

local function hamming(a: { boolean }, b: { boolean }): number
	local n = 0
	for i = 1, #a do
		if a[i] ~= b[i] then
			n += 1
		end
	end
	return n
end

local function wornParts(accessories: { Accessory }): { BasePart }
	local out = {}
	for _, acc in accessories do
		for _, p in parts(acc) do
			table.insert(out, p)
		end
	end
	return out
end

local function wear(rigType: string, armour: string, color: Color3): (Avatar.Avatar, { Accessory })
	local av = Avatar.build(rigType)
	local list = Kit.armour(armour, color)
	for _, acc in list do
		local used = Avatar.wear(acc, av)
		expect(used).never.toBeNil()
	end
	return av, list
end

describe("Kit.armour (light | medium | heavy)", function()
	it("builds the documented accessories on the documented attachments, for every colour", function()
		for _, armour in ARMOURS do
			for _, color in COLORS do
				local list = noYield(function()
					return Kit.armour(armour, color)
				end)
				local want = PIECES[armour]
				local n = 0
				for _ in want do
					n += 1
				end
				expect(#list).toBe(n)
				for _, acc in list do
					expect(acc.ClassName).toBe("Accessory")
					expect(want[acc.Name]).never.toBeNil()
					expect(acc:GetAttribute("KitArmour")).toBe(armour)
					local handle = acc:FindFirstChild("Handle") :: BasePart
					expect(handle).never.toBeNil()
					local a = handle:FindFirstChildOfClass("Attachment") :: Attachment
					expect(a.Name).toBe(want[acc.Name])
					expect((a.CFrame * handle.CFrame).Position.Magnitude).toBeLessThan(1e-4) -- modelled in attachment space
					expect(#parts(acc)).toBeLessThanOrEqual(10)
				end
			end
		end
	end)

	it("builds the same accessories every time", function()
		for _, armour in ARMOURS do
			local function sig(): string
				local rows = {}
				for _, acc in Kit.armour(armour, CANON.azure) do
					for _, p in parts(acc) do
						local pos = p.CFrame.Position
						table.insert(rows, `{acc.Name} {p.Name} {p.Size} {pos} {p.Color}`)
					end
				end
				return table.concat(rows, "\n")
			end
			expect(sig()).toBe(sig())
		end
	end)

	it("welds every part to the Handle, unanchored, massless, non-colliding, no scripts", function()
		for _, armour in ARMOURS do
			for _, acc in Kit.armour(armour, CANON.gold) do
				local handle = acc:FindFirstChild("Handle") :: BasePart
				for _, p in parts(acc) do
					expect(p.Anchored).toBe(false)
					expect(p.CanCollide or p.CanTouch or p.CanQuery).toBe(false)
					expect(p.Massless).toBe(true)
					expect(p.ClassName == "Part" or p.ClassName == "WedgePart" or p.ClassName == "CornerWedgePart").toBe(
						true
					)
					if p ~= handle then
						local w = p:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
						expect(w).never.toBeNil()
						expect(w.Part0).toBe(handle)
						expect(w.Part1).toBe(p)
					end
				end
				for _, d in acc:GetDescendants() do
					expect(d:IsA("LuaSourceContainer") or d:IsA("Humanoid")).toBe(false)
				end
			end
		end
	end)

	it(
		"carries the kingdom colour as trim on every armour: exactly shade(colour, KitTint), at least two parts",
		function()
			for _, armour in ARMOURS do
				for _, color in COLORS do
					local tinted = 0
					for _, acc in Kit.armour(armour, color) do
						for _, p in parts(acc) do
							local f = p:GetAttribute("KitTint")
							if type(f) == "number" then
								tinted += 1
								expect(p.Color.R).toBeNear(math.clamp(color.R * f, 0, 1), 0.002)
								expect(p.Color.G).toBeNear(math.clamp(color.G * f, 0, 1), 0.002)
								expect(p.Color.B).toBeNear(math.clamp(color.B * f, 0, 1), 0.002)
							end
						end
					end
					expect(tinted).toBeGreaterThanOrEqual(2)
				end
			end
		end
	)

	it("leaves no part floating: every part of an accessory touches another of the same accessory", function()
		for _, armour in ARMOURS do
			for _, acc in Kit.armour(armour, CANON.gold) do
				local list = parts(acc)
				for _, p in list do
					local e, c = halfExtents(p), p.CFrame.Position
					local touches = #list == 1
					for _, q in list do
						if q ~= p then
							local f, d = halfExtents(q), q.CFrame.Position
							if
								math.abs(c.X - d.X) <= e.X + f.X + 0.05
								and math.abs(c.Y - d.Y) <= e.Y + f.Y + 0.05
								and math.abs(c.Z - d.Z) <= e.Z + f.Z + 0.05
							then
								touches = true
								break
							end
						end
					end
					if not touches then
						error(`{acc.Name}: {p.Name} floats clear of the rest of the accessory`)
					end
				end
			end
		end
	end)

	it("recolours in place with Kit.setKingdomColor", function()
		for _, armour in ARMOURS do
			local list = Kit.armour(armour, CANON.crimson)
			for _, acc in list do
				Kit.setKingdomColor(acc :: any, CANON.emerald)
			end
			local fresh = Kit.armour(armour, CANON.emerald)
			for i, acc in list do
				local a, b = parts(acc), parts(fresh[i])
				for j, p in a do
					expect(p.Color:ToHex()).toBe(b[j].Color:ToHex())
				end
			end
		end
	end)

	it("rejects an unknown armour", function()
		expect(pcall(function()
			Kit.armour("plate" :: any, CANON.azure)
		end)).toBe(false)
	end)

	for _, rigType in { "R15", "R6" } do
		it(
			`fits a {rigType} avatar: helm on the head, plates on the chest and back, pauldrons on the shoulders`,
			function()
				for _, armour in ARMOURS do
					local av, list = wear(rigType, armour, CANON.azure)
					local head, torso = av.parts.head, av.parts.torso
					local headTop = head.CFrame.Position.Y + head.Size.Y / 2
					local front = torso.CFrame.Position.Z - torso.Size.Z / 2
					local back = torso.CFrame.Position.Z + torso.Size.Z / 2
					local shoulderTop = torso.CFrame.Position.Y + torso.Size.Y / 2
					for _, acc in list do
						local lo, hi = boundsOf(parts(acc))
						local used = PIECES[armour][acc.Name]
						if used == "HatAttachment" then
							expect(lo.Y).toBeGreaterThan(headTop - 1.1) -- never below the eyes
							expect(lo.Y).toBeLessThan(headTop + 0.1) -- sits on the head
							expect(hi.Y).toBeLessThan(headTop + 3.3)
							local centre = (lo + hi) / 2
							expect(math.abs(centre.X - head.CFrame.Position.X)).toBeLessThan(0.7)
							expect(hi.X - lo.X).toBeGreaterThan(1.3) -- wider than the narrowest head
						elseif used == "BodyFrontAttachment" then
							expect(hi.Z).toBeLessThan(front + 0.3) -- in front of the chest, not buried in it
							expect(lo.Z).toBeGreaterThan(front - 1.0)
							expect(hi.X - lo.X).toBeGreaterThan(1.7)
							expect(hi.X - lo.X).toBeLessThan(torso.Size.X + 1) -- no wider than the body and its plate
							expect(hi.Y).toBeLessThan(shoulderTop + 0.5)
							expect(lo.Y).toBeGreaterThan(0.9) -- hangs no lower than the knees
						elseif used == "BodyBackAttachment" then
							expect(lo.Z).toBeGreaterThan(back - 0.3)
							expect(hi.Z).toBeLessThan(back + 1.0)
							expect(hi.X - lo.X).toBeLessThan(torso.Size.X + 1)
						else
							local centre = (lo + hi) / 2
							local side = if used == "LeftCollarAttachment" then -1 else 1
							expect(math.sign(centre.X)).toBe(side)
							expect(math.abs(centre.X)).toBeGreaterThan(0.6)
							expect(math.abs(centre.X)).toBeLessThan(2.6)
							expect(hi.Y).toBeLessThan(shoulderTop + 1.3)
							expect(lo.Y).toBeGreaterThan(shoulderTop - 1.4)
							-- shoulders hug the arm: no plate flares more than 0.45 past the arm's outer edge (the review: "wings")
							local outer = if side > 0 then hi.X else -lo.X
							expect(outer).toBeLessThan(2.0 + 0.45)
							if armour == "medium" then -- a round cop sits on the shoulder, not sunk into the arm block
								expect(lo.Y).toBeGreaterThan(shoulderTop - 0.3)
							end
						end
					end
				end
			end
		)
	end

	it(
		"gives each armour its own silhouette on the stand-in avatar (sidegrades: none is a re-skin of another)",
		function()
			local sil = {}
			for _, armour in ARMOURS do
				local av, list = wear("R15", armour, CANON.azure)
				local all = parts(av.model)
				local front = outline(all, "X", "Y", -4, 0, 16, 18)
				local side = outline(all, "Z", "Y", -4, 0, 16, 18)
				for _, c in side do
					table.insert(front, c)
				end
				sil[armour] = front
				expect(#wornParts(list)).toBeGreaterThan(5)
			end
			expect(hamming(sil.light, sil.medium)).toBeGreaterThanOrEqual(10)
			expect(hamming(sil.medium, sil.heavy)).toBeGreaterThanOrEqual(10)
			expect(hamming(sil.light, sil.heavy)).toBeGreaterThanOrEqual(20)
			-- the same armour in two kingdoms has the same outline (colour is trim; the shape is the armour's)
			local av2 = wear("R15", "heavy", CANON.gold)
			local f2 = outline(parts(av2.model), "X", "Y", -4, 0, 16, 18)
			local f1 = outline(parts(wear("R15", "heavy", CANON.crimson).model), "X", "Y", -4, 0, 16, 18)
			expect(hamming(f1, f2)).toBe(0)
		end
	)

	it(
		"grows broader with each step but never reaches the ground or the arms' swing (no clipping through the limbs)",
		function()
			local widths = {}
			for _, armour in ARMOURS do
				local _, list = wear("R15", armour, CANON.crimson)
				local lo, hi = boundsOf(wornParts(list))
				widths[armour] = hi.X - lo.X
				expect(lo.Y).toBeGreaterThan(1.0)
			end
			expect(widths.heavy).toBeGreaterThan(widths.medium - 0.01)
			expect(widths.medium).toBeGreaterThan(widths.light + 0.5)
		end
	)
end)

local SHIELD_PARTS = { "ShieldRim", "ShieldFace", "ShieldBand", "ShieldBoss" }

local function overlaps(a: BasePart, b: BasePart): boolean
	local e, c = halfExtents(a), a.CFrame.Position
	local f, d = halfExtents(b), b.CFrame.Position
	return math.abs(c.X - d.X) < e.X + f.X - 0.01
		and math.abs(c.Y - d.Y) < e.Y + f.Y - 0.01
		and math.abs(c.Z - d.Z) < e.Z + f.Z - 0.01
end

local function byKitPart(model: Instance, kitPart: string): BasePart?
	for _, p in parts(model) do
		if p:GetAttribute("KitPart") == kitPart then
			return p
		end
	end
	return nil
end

-- the shield's parts as comparable rows: name, size, colour (the same four parts on the Tool and on the Accessory)
local function shieldRows(model: Instance): { string }
	local rows = {}
	for _, name in SHIELD_PARTS do
		local p = byKitPart(model, name) :: BasePart
		table.insert(rows, `{name} {p.Size} {p.Color:ToHex()} {p.Material.Name}`)
	end
	return rows
end

describe("Kit.shield (the sword-and-shield's shield: an Accessory on the left hand)", function()
	it("builds an Accessory with a Handle holding LeftGripAttachment, at most 10 parts, for every colour", function()
		for _, color in COLORS do
			local acc = noYield(function()
				return Kit.shield(color)
			end)
			expect(acc.ClassName).toBe("Accessory")
			expect(acc.Name).toBe("KitShield")
			expect(acc:GetAttribute("KitPiece")).toBe("Shield")
			expect(acc:GetAttribute("KitShield")).toBe("shield")
			expect(acc:GetAttribute("KitArmour")).toBeNil() -- not armour: nothing that lists a set by KitArmour picks it up
			local handle = acc:FindFirstChild("Handle") :: BasePart
			expect(handle).never.toBeNil()
			local attachments = {}
			for _, d in acc:GetDescendants() do
				if d:IsA("Attachment") then
					table.insert(attachments, d)
				end
			end
			expect(#attachments).toBe(1)
			expect(attachments[1].Name).toBe("LeftGripAttachment")
			expect(attachments[1].Parent).toBe(handle)
			expect((attachments[1].CFrame * handle.CFrame).Position.Magnitude).toBeLessThan(1e-4) -- modelled in attachment space
			local list = parts(acc)
			expect(#list).toBeLessThanOrEqual(10)
			expect(#list).toBeGreaterThanOrEqual(4)
			for _, name in SHIELD_PARTS do
				expect(byKitPart(acc, name)).never.toBeNil()
			end
		end
	end)

	it("welds every part to the Handle, unanchored, massless, non-colliding, no scripts", function()
		for _, color in COLORS do
			local acc = Kit.shield(color)
			local handle = acc:FindFirstChild("Handle") :: BasePart
			for _, p in parts(acc) do
				expect(p.Anchored).toBe(false)
				expect(p.CanCollide).toBe(false)
				expect(p.CanTouch).toBe(false)
				expect(p.CanQuery).toBe(false)
				expect(p.Massless).toBe(true)
				expect(p.ClassName == "Part" or p.ClassName == "WedgePart" or p.ClassName == "CornerWedgePart").toBe(
					true
				)
				if p ~= handle then
					local w = p:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
					expect(w).never.toBeNil()
					expect(w.Part0).toBe(handle)
					expect(w.Part1).toBe(p)
				end
			end
			for _, d in acc:GetDescendants() do
				expect(d:IsA("LuaSourceContainer") or d:IsA("Humanoid")).toBe(false)
			end
		end
	end)

	it("leaves no part floating: every part touches another of the shield", function()
		local list = parts(Kit.shield(CANON.gold))
		for _, p in list do
			local e, c = halfExtents(p), p.CFrame.Position
			local touches = false
			for _, q in list do
				if q ~= p then
					local f, d = halfExtents(q), q.CFrame.Position
					if
						math.abs(c.X - d.X) <= e.X + f.X + 0.05
						and math.abs(c.Y - d.Y) <= e.Y + f.Y + 0.05
						and math.abs(c.Z - d.Z) <= e.Z + f.Z + 0.05
					then
						touches = true
						break
					end
				end
			end
			if not touches then
				error(`ShieldFloat: {p.Name} floats clear of the rest of the shield`)
			end
		end
	end)

	it("is deterministic", function()
		local function sig(): string
			local rows = {}
			for _, p in parts(Kit.shield(CANON.emerald)) do
				table.insert(rows, `{p.Name} {p.Size} {p.CFrame.Position} {p.Color}`)
			end
			return table.concat(rows, "\n")
		end
		expect(sig()).toBe(sig())
	end)

	it(
		"takes the kingdom colour on the face: exactly shade(colour, KitTint), and Kit.setKingdomColor recolours it",
		function()
			for _, color in COLORS do
				local tinted = 0
				for _, p in parts(Kit.shield(color)) do
					local f = p:GetAttribute("KitTint")
					if type(f) == "number" then
						tinted += 1
						expect(p:GetAttribute("KitPart")).toBe("ShieldFace")
						expect(p.Color.R).toBeNear(math.clamp(color.R * f, 0, 1), 0.002)
						expect(p.Color.G).toBeNear(math.clamp(color.G * f, 0, 1), 0.002)
						expect(p.Color.B).toBeNear(math.clamp(color.B * f, 0, 1), 0.002)
					end
				end
				expect(tinted).toBe(1)
			end
			local acc = Kit.shield(CANON.crimson)
			Kit.setKingdomColor(acc :: any, CANON.azure)
			local fresh = Kit.shield(CANON.azure)
			for j, p in parts(acc) do
				expect(p.Color:ToHex()).toBe(parts(fresh)[j].Color:ToHex())
			end
			expect((byKitPart(acc, "ShieldFace") :: BasePart).Color:ToHex()).never.toBe(
				(byKitPart(Kit.shield(CANON.crimson), "ShieldFace") :: BasePart).Color:ToHex()
			)
		end
	)

	it("is neutral without a colour", function()
		local a, b = Kit.shield(), Kit.shield(Kit.NEUTRAL_COLOR)
		for j, p in parts(a) do
			expect(p.Color:ToHex()).toBe(parts(b)[j].Color:ToHex())
			expect(p.CFrame.Position).toBe(parts(b)[j].CFrame.Position)
		end
		local face = byKitPart(a, "ShieldFace") :: BasePart
		expect(face.Color:ToHex()).toBe(Kit.NEUTRAL_COLOR:ToHex())
	end)

	it("is the same shield as the one on the sword Tool: the same four parts in the same kingdom colour", function()
		for _, color in COLORS do
			local onTool = shieldRows(Kit.weapon("swordShield", color))
			local worn = shieldRows(Kit.shield(color))
			for i = 1, #SHIELD_PARTS do
				expect(worn[i]).toBe(onTool[i])
			end
		end
	end)

	for _, rigType in { "R15", "R6" } do
		it(
			`rests on a {rigType} avatar's left forearm: outside it, in front of it, a disc facing forward, clear of the body`,
			function()
				local av = Avatar.build(rigType, nil, { guard = true })
				expect(av.attachments.LeftGripAttachment).never.toBeNil() -- the stand-in has the attachment
				local acc = Kit.shield(CANON.azure)
				expect(Avatar.wear(acc, av)).toBe("LeftGripAttachment")
				expect(acc.Parent).toBe(av.model)
				local arm = av.parts.leftArm
				local armTip = arm.CFrame.Position.Z - arm.Size.Z / 2
				local list = parts(acc)
				local lo, hi = boundsOf(list)
				local centre = (lo + hi) / 2
				expect((acc:FindFirstChild("Handle") :: BasePart).CFrame.Position.Z).toBeLessThan(armTip) -- ahead of the fist
				expect(hi.Z).toBeLessThan(armTip + 0.05) -- all of it in front of the forearm, none sunk into it
				expect(centre.X).toBeLessThan(arm.CFrame.Position.X) -- on the outside (the left is -X) of the arm
				expect(hi.X).toBeLessThan(0.1) -- and wholly on the left half: it does not cross the chest centre
				expect(math.abs(centre.Y - av.leftHand.Y)).toBeLessThan(0.8) -- about the fist's height
				for _, p in list do
					for _, q in parts(av.model) do
						if q.Parent == av.model then
							expect(overlaps(p, q)).toBe(false) -- no part of the avatar's body is inside the shield
						end
					end
				end
				-- a disc facing forward: about 2.4 wide, thin in depth; the boss stands proud of the face towards -Z
				local face = byKitPart(acc, "ShieldFace") :: BasePart
				local fLo, fHi = boundsOf({ face })
				expect(fHi.X - fLo.X).toBeGreaterThan(2.2)
				expect(fHi.Y - fLo.Y).toBeGreaterThan(2.2)
				expect(fHi.Z - fLo.Z).toBeLessThan(0.5)
				local boss = byKitPart(acc, "ShieldBoss") :: BasePart
				expect(boss.CFrame.Position.Z).toBeLessThan(face.CFrame.Position.Z)
				local rim = byKitPart(acc, "ShieldRim") :: BasePart
				expect(rim.CFrame.Position.Z).toBeGreaterThan(face.CFrame.Position.Z) -- the rim is behind the face
			end
		)
	end

	it(
		"sits opposite the sword: the sword Tool in the right hand, the shield on the left, never overlapping",
		function()
			for _, rigType in { "R15", "R6" } do
				local av = Avatar.build(rigType, nil, { guard = true })
				local sword = Kit.weapon("swordShield", CANON.crimson, { shield = false })
				Avatar.hold(sword, av)
				local acc = Kit.shield(CANON.crimson)
				Avatar.wear(acc, av)
				local sLo, sHi = boundsOf(parts(sword))
				local hLo, hHi = boundsOf(parts(acc))
				expect((sLo.X + sHi.X) / 2).toBeGreaterThan(0)
				expect((hLo.X + hHi.X) / 2).toBeLessThan(0)
				expect(hHi.X).toBeLessThan(sLo.X) -- apart on X: nothing of the sword is in the shield's column
			end
		end
	)

	it(
		"documents the hanging arm: the shield hangs below the fist, clear of the forearm (equip it with the arm raised)",
		function()
			for _, rigType in { "R15", "R6" } do
				local av = Avatar.build(rigType) -- the left arm hangs; its grip attachment is turned down with it
				local acc = Kit.shield(CANON.azure)
				expect(Avatar.wear(acc, av)).toBe("LeftGripAttachment")
				local lo, hi = boundsOf(parts(acc))
				expect((lo.X + hi.X) / 2).toBeLessThan(av.parts.leftArm.CFrame.Position.X) -- still on the left, outside the arm
				expect(((lo.Y + hi.Y) / 2)).toBeLessThan(av.leftHand.Y) -- under the fist
				for _, p in parts(acc) do
					expect(overlaps(p, av.parts.leftArm)).toBe(false)
				end
			end
		end
	)
end)

describe("Kit.weapon (swordShield | greatsword | spear | mace)", function()
	it("builds a Tool with a Handle, welded parts and no scripts, for every colour", function()
		for _, weapon in WEAPONS do
			for _, color in COLORS do
				local tool = noYield(function()
					return Kit.weapon(weapon, color)
				end)
				expect(tool.ClassName).toBe("Tool")
				expect(tool.Name).toBe(weapon)
				expect(tool.RequiresHandle).toBe(true)
				expect(tool.CanBeDropped).toBe(false)
				expect(tool:GetAttribute("KitWeapon")).toBe(weapon)
				local handle = tool:FindFirstChild("Handle") :: BasePart
				expect(handle).never.toBeNil()
				expect(handle.CFrame.Position.Magnitude).toBeLessThan(1e-6) -- the grip is the origin
				local list = parts(tool)
				expect(#list).toBeLessThanOrEqual(12)
				expect(#list).toBeGreaterThanOrEqual(5)
				for _, p in list do
					expect(p.Anchored).toBe(false)
					expect(p.CanCollide or p.CanTouch or p.CanQuery).toBe(false) -- hits are the server's, not Touched
					expect(p.Massless).toBe(true)
					expect(p.ClassName == "Part" or p.ClassName == "WedgePart" or p.ClassName == "CornerWedgePart").toBe(
						true
					)
					if p ~= handle then
						expect(p.Parent).toBe(tool)
						local w = p:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
						expect(w).never.toBeNil()
						expect(w.Part0).toBe(handle)
					end
				end
				for _, d in tool:GetDescendants() do
					expect(d:IsA("LuaSourceContainer") or d:IsA("Humanoid")).toBe(false)
				end
			end
		end
	end)

	it(
		"leaves no part floating: every part touches another, so a blade is on its hilt and a spear head on its shaft",
		function()
			for _, weapon in WEAPONS do
				local list = parts(Kit.weapon(weapon, CANON.gold))
				for _, p in list do
					local e, c = halfExtents(p), p.CFrame.Position
					local touches = false
					for _, q in list do
						if q ~= p then
							local f, d = halfExtents(q), q.CFrame.Position
							if
								math.abs(c.X - d.X) <= e.X + f.X + 0.05
								and math.abs(c.Y - d.Y) <= e.Y + f.Y + 0.05
								and math.abs(c.Z - d.Z) <= e.Z + f.Z + 0.05
							then
								touches = true
								break
							end
						end
					end
					if not touches then
						error(`{weapon}: {p.Name} floats clear of every other part`)
					end
				end
			end
		end
	)

	it("is deterministic", function()
		for _, weapon in WEAPONS do
			local function sig(): string
				local rows = {}
				for _, p in parts(Kit.weapon(weapon, CANON.emerald)) do
					table.insert(rows, `{p.Name} {p.Size} {p.CFrame.Position} {p.Color}`)
				end
				return table.concat(rows, "\n")
			end
			expect(sig()).toBe(sig())
		end
	end)

	it("sets Grip so the weapon is held as modelled: Handle * Grip is the identity (blade up, front -Z)", function()
		for _, weapon in WEAPONS do
			local tool = Kit.weapon(weapon, CANON.crimson)
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local id = tool.Grip * handle.CFrame
			local r, u, l = id.RightVector, id.UpVector, id.LookVector
			expect(r:Dot(Vector3.new(1, 0, 0))).toBeNear(1, 1e-4)
			expect(u:Dot(Vector3.new(0, 1, 0))).toBeNear(1, 1e-4)
			expect(l:Dot(Vector3.new(0, 0, -1))).toBeNear(1, 1e-4)
			expect(id.Position.Magnitude).toBeLessThan(1e-4)
		end
	end)

	it(
		"rises from the grip: the tip is at the documented reach, and the weapons order sword < mace < greatsword < spear",
		function()
			local reach = {}
			for _, weapon in WEAPONS do
				local tool = Kit.weapon(weapon, CANON.azure)
				local _, hi = boundsOf(parts(tool))
				reach[weapon] = hi.Y
				expect(tool:GetAttribute("KitReach")).toBeNear(hi.Y, 0.4)
				expect(hi.Y).toBeNear(WEAPON_REACH[weapon], 0.5)
			end
			expect(reach.swordShield).toBeLessThan(reach.mace)
			expect(reach.mace).toBeLessThan(reach.greatsword)
			expect(reach.greatsword).toBeLessThan(reach.spear)
			expect(Kit.weapon("greatsword"):GetAttribute("KitHands")).toBe(2)
			expect(Kit.weapon("spear"):GetAttribute("KitHands")).toBe(2)
			expect(Kit.weapon("mace"):GetAttribute("KitHands")).toBe(1)
			expect(Kit.weapon("swordShield"):GetAttribute("KitHands")).toBe(1)
		end
	)

	it("gives each weapon its own silhouette in grip space", function()
		local sil = {}
		for _, weapon in WEAPONS do
			local list = parts(Kit.weapon(weapon, CANON.gold))
			local front = outline(list, "X", "Y", -4, -4, 16, 32)
			local side = outline(list, "Z", "Y", -4, -4, 16, 32)
			for _, c in side do
				table.insert(front, c)
			end
			sil[weapon] = front
		end
		for i = 1, #WEAPONS do
			for j = i + 1, #WEAPONS do
				local d = hamming(sil[WEAPONS[i]], sil[WEAPONS[j]])
				if d < 12 then
					error(`{WEAPONS[i]} and {WEAPONS[j]} differ by only {d} cells`)
				end
			end
		end
	end)

	it("carries the kingdom colour as trim on every weapon, in the same kind of place", function()
		local tint = { swordShield = "ShieldFace", greatsword = "GuardTipLeft", spear = "Pennant", mace = "Ribbon" }
		for _, weapon in WEAPONS do
			for _, color in COLORS do
				local found = false
				for _, p in parts(Kit.weapon(weapon, color)) do
					local f = p:GetAttribute("KitTint")
					if type(f) == "number" then
						expect(p.Color.R).toBeNear(math.clamp(color.R * f, 0, 1), 0.002)
						expect(p.Color.G).toBeNear(math.clamp(color.G * f, 0, 1), 0.002)
						found = found or p.Name == tint[weapon] or p:GetAttribute("KitPart") == tint[weapon]
					end
				end
				expect(found).toBe(true)
			end
		end
	end)

	it("shows the shield of sword-and-shield beside the hand, as a disc facing forward", function()
		local tool = Kit.weapon("swordShield", CANON.azure)
		local face
		for _, p in parts(tool) do
			if p:GetAttribute("KitPart") == "ShieldFace" then
				face = p
			end
		end
		expect(face).never.toBeNil()
		local lo, hi = boundsOf({ face })
		expect(hi.X - lo.X).toBeGreaterThan(2) -- a disc about 2.4 wide ...
		expect(hi.Z - lo.Z).toBeLessThan(0.5) -- ... and thin: it faces forward
		expect(hi.X).toBeLessThan(0.1) -- on the inside of the hand
	end)

	it(
		"shapes the review's four weak spots: a broad ridged blade, a pointed leaf head, studs clear of the mace ball",
		function()
			local function named(tool: Instance, name: string): BasePart
				for _, p in parts(tool) do
					if p.Name == name then
						return p
					end
				end
				error(`no {name} in {tool.Name}`)
			end
			local sword = Kit.weapon("swordShield", CANON.azure)
			expect(named(sword, "Blade").Size.X).toBeGreaterThan(0.5) -- not a stick against the sky
			expect(named(sword, "Fuller").Color).never.toBe(named(sword, "Blade").Color) -- a dark ridge down the blade
			-- the spear head is a leaf: each wedge's tall edge (local +Z) faces the centre line, so the point is at the top
			local spear = Kit.weapon("spear", CANON.azure)
			for _, name in { "HeadLeft", "HeadRight" } do
				local p = named(spear, name)
				local toCentre = -math.sign(p.CFrame.Position.X)
				local tall = -p.CFrame.LookVector -- local +Z in the world
				expect(tall.X * toCentre).toBeGreaterThan(0.99)
				expect(p.Size.Y).toBeGreaterThan(1.8)
			end
			expect(named(spear, "HeadLeft").CFrame.Position.X).toBeLessThan(0)
			expect(named(spear, "HeadRight").CFrame.Position.X).toBeGreaterThan(0)
			-- the mace's studs stand clear of its ball on every side (a studded morning star, not a bomb on a stick)
			local mace = Kit.weapon("mace", CANON.azure)
			local ball = named(mace, "Head")
			for i = 1, 4 do
				local f = named(mace, `Stud{i}`)
				local offset = (f.CFrame.Position - ball.CFrame.Position).Magnitude
				expect(offset).toBeGreaterThan(ball.Size.X / 2 + 0.2) -- the stud's centre is outside the ball ...
				expect(offset - f.Size.Z / 2).toBeLessThan(ball.Size.X / 2) -- ... and its inner end still sinks into it
				expect(f.Color).never.toBe(ball.Color)
			end
		end
	)

	it("keeps the round shield on the swordShield Tool by default, and says KitShield", function()
		for _, color in COLORS do
			for _, opts in { nil, {}, { shield = true } } do
				local tool = Kit.weapon("swordShield", color, opts)
				expect(#parts(tool)).toBe(10) -- the sword's 6 and the shield's 4, as before Kit.shield
				for _, name in SHIELD_PARTS do
					expect(byKitPart(tool, name)).never.toBeNil()
				end
				expect(tool:GetAttribute("KitShield")).toBe("shield")
				expect(tool:GetAttribute("KitHands")).toBe(1)
			end
		end
	end)

	it(
		"builds the sword alone with { shield = false }: 6 parts, no Shield* part, KitShield, the same reach and grip",
		function()
			for _, color in COLORS do
				local full = Kit.weapon("swordShield", color)
				local tool = noYield(function()
					return Kit.weapon("swordShield", color, { shield = false })
				end)
				expect(tool.ClassName).toBe("Tool")
				expect(tool.Name).toBe("swordShield")
				expect(tool.RequiresHandle).toBe(true)
				expect(tool:GetAttribute("KitWeapon")).toBe("swordShield")
				expect(tool:GetAttribute("KitHands")).toBe(1)
				expect(tool:GetAttribute("KitShield")).toBe("shield")
				expect(tool:GetAttribute("KitReach")).toBe(full:GetAttribute("KitReach"))
				expect(tool:GetAttribute("KitReach")).toBeNear(4.72, 1e-6)
				expect(#parts(tool)).toBe(6)
				for _, p in parts(tool) do
					expect(p.Name:sub(1, 6)).never.toBe("Shield")
					expect(tostring(p:GetAttribute("KitPart")):sub(1, 6)).never.toBe("Shield")
					expect(p.CanCollide or p.CanTouch or p.CanQuery or p.Anchored).toBe(false)
					expect(p.Massless).toBe(true)
				end
				for _, name in SHIELD_PARTS do
					expect(tool:FindFirstChild(name)).toBeNil()
				end
				expect((tool.Grip * (tool:FindFirstChild("Handle") :: BasePart).CFrame).Position.Magnitude).toBeLessThan(
					1e-4
				)
				local _, hi = boundsOf(parts(tool))
				expect(hi.Y).toBeNear(4.9, 0.1) -- the geometry's top is the sword's tip, with or without the shield
				-- the sword is the same six parts, in the same places, as the first six of the full form
				local a, b = parts(tool), parts(full)
				for i = 1, 6 do
					expect(`{a[i].Name} {a[i].Size} {a[i].CFrame.Position}`).toBe(
						`{b[i].Name} {b[i].Size} {b[i].CFrame.Position}`
					)
				end
			end
		end
	)

	it("sets KitShield on swordShield only: the other weapons ignore opts and carry none", function()
		for _, weapon in { "greatsword", "spear", "mace" } do
			local plain = Kit.weapon(weapon, CANON.azure)
			local with = Kit.weapon(weapon, CANON.azure, { shield = false })
			expect(plain:GetAttribute("KitShield")).toBeNil()
			expect(with:GetAttribute("KitShield")).toBeNil()
			expect(#parts(with)).toBe(#parts(plain))
			for i, p in parts(plain) do
				expect(p.Name).toBe(parts(with)[i].Name)
				expect(p.CFrame.Position).toBe(parts(with)[i].CFrame.Position)
			end
		end
	end)

	it(
		"keeps the part count the same when the shield moves to the hand: sword 6 + shield 4 = the old Tool's 10",
		function()
			for _, color in COLORS do
				local before = #parts(Kit.weapon("swordShield", color))
				local after = #parts(Kit.weapon("swordShield", color, { shield = false })) + #parts(Kit.shield(color))
				expect(after).toBe(before)
			end
		end
	)

	it("rejects an unknown weapon", function()
		expect(pcall(function()
			Kit.weapon("crossbow" :: any)
		end)).toBe(false)
	end)

	for _, rigType in { "R15", "R6" } do
		it(`is carried upright in a {rigType} avatar's right hand`, function()
			for _, weapon in WEAPONS do
				local av = Avatar.build(rigType)
				local tool = Kit.weapon(weapon, CANON.emerald)
				Avatar.hold(tool, av)
				local handle = tool:FindFirstChild("Handle") :: BasePart
				expect((handle.CFrame.Position - av.hand).Magnitude).toBeLessThan(1e-3)
				local lo, hi = boundsOf(parts(tool))
				expect(hi.Y - av.hand.Y).toBeNear(WEAPON_REACH[weapon], 0.5) -- the tip is `reach` above the fist
				expect(lo.Y).toBeGreaterThan(av.hand.Y - 2.6) -- the butt stays at or above the hip's height
				expect(math.abs((lo.X + hi.X) / 2 - av.hand.X)).toBeLessThan(2.2)
				if weapon == "mace" then -- the mace's head is held clear above the wearer's head, not at face height
					local ball: BasePart
					for _, p in parts(tool) do
						if p.Name == "Head" then
							ball = p
						end
					end
					local head = av.parts.head
					expect(ball.CFrame.Position.Y - ball.Size.Y / 2).toBeGreaterThan(
						head.CFrame.Position.Y + head.Size.Y / 2 + 0.8
					)
				end
			end
		end)
	end
end)
