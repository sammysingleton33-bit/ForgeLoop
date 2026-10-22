--[[
	Citizen readability at the gameplay camera (visual upgrade pass 1, stream C; the owner: "citizens are barely recognisable at the
	default aerial camera"). Rules that keep what the pass changed from drifting back, each measured on the shipped rigs:

	1. Ground contrast. The ground a citizen stands on is green grass, brown fields and roads and grey cobble (world/Lighting.luau
	   terrainColors), all of middling value. Every colour a citizen wears that is NOT the kingdom tint, a skin tone or a hair colour
	   (job hats, job panels and trousers in every dyed variant, outfit neutrals, the hauler's sack) differs from Grass, LeafyGrass and Ground
	   by CIELAB dE >= 32 and from Mud and Cobblestone by dE >= 22. The first pass had a hauler panel and sack 2 to 4 from Ground, idle
	   trousers 0 from Mud, a miner pot 25 and a farmer hat 31 from Ground.
	2. Hats differ in hue as well as in value: the four job hats (default look) are at least dE 40 apart, so a jobs read in colour too (the
	   grayscale value bands stay in KitCharacter.spec).
	3. The kingdom tint on the torso or the sleeves keeps dE >= 25 from the three main grounds in all four kingdoms (the colour that says
	   "ours"; gold and emerald are the hard cases).
	4. Parts per citizen: no readability change adds a part (the pass recoloured; counts are pinned per job).
	7. Job codes (pass 3): each job's tool head (the hauler's sack) is one saturated colour, no kingdom's, 40 dE or more from the other jobs'; the
	   tool handles are ink; the ground rule 1 covers tool handles, heads, the sack and its tie too.
	6. Silhouette parts (pass 2): a citizen's head, hat, tool and the hauler's sack are drawn bigger (Character.HEAD_SCALE, HAT_SCALE,
	   TOOL_SCALE(S), SACK_SCALE); sizes are pinned in studs below, and the pixel floors in 5 are the sizes measured with them.
	5. Size on screen: at the approved start view (zoom 70, FOV 55, pitch 42.5), at zoom 220 (pitch 65) and on a 750 x 311 phone, the body
	   (head, torso, legs) projects to at least the heights measured with tools/citizen_screen.py. A citizen smaller than that (a shrunk
	   rig, a farther camera) fails here before a player sees it.

	The checkers are checked too: the colours the pass replaced, and a rig shrunk to 70 %, must trip them (mutants).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Character = require("@game/ReplicatedStorage/Game/Kit/Character")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local LightingPreset = require("@game/ReplicatedStorage/Game/World/Lighting")
local StartView = require("./support/StartView")

local CRIMSON = Color3.fromRGB(190, 40, 50)
local KINGDOMS = {
	crimson = CRIMSON,
	azure = Color3.fromRGB(40, 110, 210),
	emerald = Color3.fromRGB(35, 128, 95),
	gold = Color3.fromRGB(235, 185, 16),
}
local JOBS = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" }
local WORKING = { "farmer", "woodcutter", "miner", "builder" }
local R = Kit.LOOK_RANGES

-- ------------------------------------------------------------------ colour distance (CIELAB dE76, D65)

local function lin(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function lab(c: Color3): (number, number, number)
	local r, g, b = lin(c.R), lin(c.G), lin(c.B)
	local x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
	local z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	local function f(t: number): number
		return if t > 0.008856 then t ^ (1 / 3) else 7.787 * t + 16 / 116
	end
	local fx, fy, fz = f(x), f(y), f(z)
	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

local function dE(a: Color3, b: Color3): number
	local l1, a1, b1 = lab(a)
	local l2, a2, b2 = lab(b)
	return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

-- the ground colours and how far a worn colour must stay from each
local GROUND: { { name: string, color: Color3, need: number } } = {
	{ name = "Grass", color = LightingPreset.terrainColors.Grass, need = 32 },
	{ name = "LeafyGrass", color = LightingPreset.terrainColors.LeafyGrass, need = 32 },
	{ name = "Ground", color = LightingPreset.terrainColors.Ground, need = 32 },
	{ name = "Mud", color = LightingPreset.terrainColors.Mud, need = 22 },
	{ name = "Cobblestone", color = LightingPreset.terrainColors.Cobblestone, need = 22 },
}

-- the first ground a colour is too close to, as "Ground 2.1", or nil when it is clear of all of them
local function tooClose(c: Color3): string?
	for _, g in GROUND do
		local d = dE(c, g.color)
		if d < g.need then
			return `{g.name} {string.format("%.1f", d)}`
		end
	end
	return nil
end

-- ------------------------------------------------------------------ the worn colours of a rig

local function child(rig: Model, name: string): BasePart
	return rig:FindFirstChild(name) :: BasePart
end

local function lookOf(hair: number, hairColor: number, outfit: number, skin: number?): any
	return { skin = skin or 1, hair = hair, hairColor = hairColor, outfit = outfit }
end

local SKIN_HEX = {}
for _, c in Kit.LOOK_PALETTES.skin do
	SKIN_HEX[c:ToHex()] = true
end
local HAT_NAMES = {}
for _, name in Kit.JOB_HEADWEAR do
	HAT_NAMES[name] = true
end

local TOOL_HEAD_KINDS =
	{ hoeblade = true, axehead = true, pickhead = true, pickpoint = true, mallet = true, tie = true }

-- Every part whose colour the Kit chooses for readability: not tinted by the kingdom, not skin, not a hair colour. The job hats, the
-- body parts in neutral cloth, the tool handles and heads and the hauler's sack and tie. Returns { label, colour } pairs.
local function wornColours(rig: Model): { { label: string, color: Color3 } }
	local out = {}
	for _, name in { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		local p = child(rig, name)
		if p:GetAttribute("KitTint") == nil and not SKIN_HEX[p.Color:ToHex()] then
			table.insert(out, { label = name, color = p.Color })
		end
	end
	local hat = rig:FindFirstChild("Hair") :: BasePart?
	if hat and HAT_NAMES[tostring(hat:GetAttribute("KitHeadwear"))] then
		table.insert(out, { label = "Hair", color = hat.Color })
	end
	local tool = rig:FindFirstChild("Tool") :: BasePart?
	if tool and tool:GetAttribute("KitTool") ~= nil then
		table.insert(out, { label = tostring(tool:GetAttribute("KitTool")), color = tool.Color }) -- the handle, and the sack
	end
	for _, name in { "Detail1", "Detail2" } do -- tool heads and the sack's tie: not the kingdom-tinted strap
		local d = rig:FindFirstChild(name) :: BasePart?
		if d and d:GetAttribute("KitTint") == nil and TOOL_HEAD_KINDS[tostring(d:GetAttribute("KitDetailKind"))] then
			table.insert(out, { label = tostring(d:GetAttribute("KitDetailKind")), color = d.Color })
		end
	end
	return out
end

local function countParts(rig: Model): number
	local n = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- ------------------------------------------------------------------ the camera (the real start view: support/StartView)

-- RulerCameraController's pitch law (Def.pitchFor): 38 degrees at zoom 40 up to 65 at zoom 220, linear between
local function pitchFor(zoom: number): number
	return 38 + 27 * (math.clamp(zoom, 40, 220) - 40) / 180
end

-- Projects the body of a rig standing at the camera's focus: its height in pixels. The camera is StartView.camera (the start view's
-- focus and yaw, `zoom` studs away at the zoom's pitch), vertical FOV `fov`, on a viewport `height` px tall.
local function bodyPixels(rig: Model, zoom: number, fov: number, height: number): number
	local START = StartView.START
	local root = CFrame.new(0, 2.75, START.ahead) -- facing -Z: the focus (ahead studs in front of it) is the origin column, 2.75 up
	local cam = StartView.camera(root, zoom, pitchFor(zoom), START.ahead, START.turn)
	local f = (height / 2) / math.tan(math.rad(fov) / 2)
	local lo, hi = math.huge, -math.huge
	for _, name in { "Torso", "Head", "LeftLeg", "RightLeg", "LeftArm", "RightArm" } do
		local p = child(rig, name)
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local rel = p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z) - cam.position
					local y = f * rel:Dot(cam.up) / rel:Dot(cam.forward)
					lo, hi = math.min(lo, y), math.max(hi, y)
				end
			end
		end
	end
	return hi - lo
end

local function shrunk(rig: Model, k: number): Model -- a mutant: the same rig drawn at k of its size about the feet
	local m = rig:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Size = d.Size * k
			d.CFrame = CFrame.new(d.CFrame.Position * k) * d.CFrame.Rotation
		end
	end
	return m
end

-- ------------------------------------------------------------------ job-coded tool colours (pass 3)

local function saturation(c: Color3): number -- HSV saturation
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	return if mx == 0 then 0 else (mx - mn) / mx
end

local TOOL_CODE = { farmer = "hoeblade", woodcutter = "axehead", miner = "pickhead", builder = "mallet" }

-- the colour a job's tool head (or, for the hauler, its sack) carries: the job's code
local function jobCode(job: string): Color3
	local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1))
	if job == "hauler" then
		return child(rig, "Tool").Color
	end
	for _, name in { "Detail1", "Detail2" } do
		local d = rig:FindFirstChild(name) :: BasePart?
		if d and d:GetAttribute("KitDetailKind") == TOOL_CODE[job] then
			return d.Color
		end
	end
	error(`{job} has no {TOOL_CODE[job]}`)
end

-- why a colour is not a job code: dull (saturation under 0.6: steel, iron, wood, stone) or a kingdom's (dE under 30 from crimson,
-- azure, emerald or gold at full tint), so that a tool never reads as ownership
local function jobCodeProblem(c: Color3): string?
	if saturation(c) < 0.6 then
		return `saturation {string.format("%.2f", saturation(c))} is under 0.6`
	end
	for id, k in KINGDOMS do
		local d = dE(c, k)
		if d < 30 then
			return `dE {string.format("%.1f", d)} from {id}`
		end
	end
	return nil
end

-- ------------------------------------------------------------------ silhouette sizes (pass 2)

local function horizontal(
	p: BasePart
): number -- the widest horizontal extent of a part's box (corners: a hat is a turned cylinder)
	local lo, hi = math.huge, -math.huge
	local h = p.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				lo, hi = math.min(lo, w.X, w.Z), math.max(hi, w.X, w.Z)
			end
		end
	end
	return hi - lo
end

-- The studs the silhouette parts were before the pass, and the least each must now be (default look, rest pose).
local OLD_HEAD = 1.6
local MIN_HEAD = 2.0 -- 1.25 x
local MIN_HAT = { farmer = 2.7, woodcutter = 1.85, miner = 2.35, builder = 2.2 } -- widths: was 3.1, 1.5, 1.9, 1.8 (the farmer's disc is 0.9 x: work slots)
local MIN_HANDLE = { farmer = 7.0, woodcutter = 5.6, miner = 6.7, builder = 3.3 } -- cylinder lengths: was 5.2, 3.9, 5.4, 3.0 (hoe x1.4, axe x1.5, pick x1.3, mallet x1.15)
local MIN_TOOL_HEAD = { farmer = 2.5, woodcutter = 3.5, miner = 3.1, builder = 2.2 } -- the head's longest side: blade 2.64, bit 3.7, tine 3.25, mallet 2.3 (were 1.3, 1.9, 2.5, 2.0)
local MIN_SACK = 3.0 -- was 2.7
local TOOL_HEADS = { hoeblade = true, axehead = true, pickhead = true, mallet = true }

-- the silhouette rules a rig set breaks (empty when the pass is in place)
local function silhouetteFailures(): { string }
	local out = {}
	for _, job in JOBS do
		local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1))
		local head = child(rig, "Head")
		if head.Size.X < MIN_HEAD then
			table.insert(out, `{job} head {head.Size.X}`)
		end
		local hat = rig:FindFirstChild("Hair") :: BasePart?
		if MIN_HAT[job] and hat and horizontal(hat) < MIN_HAT[job] then
			table.insert(out, `{job} hat {string.format("%.2f", horizontal(hat))}`)
		end
		local tool = rig:FindFirstChild("Tool") :: BasePart?
		if tool and MIN_HANDLE[job] and tool.Size.X < MIN_HANDLE[job] then
			table.insert(out, `{job} handle {string.format("%.2f", tool.Size.X)}`)
		end
		local toolHead: BasePart? -- the tool's head: the detail named for it (the first detail of a hatted job is the hat's crown, pompom or visor)
		for _, name in { "Detail1", "Detail2" } do
			local d = rig:FindFirstChild(name) :: BasePart?
			if d and TOOL_HEADS[tostring(d:GetAttribute("KitDetailKind"))] then
				toolHead = d
			end
		end
		if MIN_TOOL_HEAD[job] and toolHead then
			local side = math.max(toolHead.Size.X, toolHead.Size.Y, toolHead.Size.Z)
			if side < MIN_TOOL_HEAD[job] then
				table.insert(out, `{job} tool head {string.format("%.2f", side)}`)
			end
		end
		if tool and job == "hauler" and tool.Size.X < MIN_SACK then
			table.insert(out, `hauler sack {string.format("%.2f", tool.Size.X)}`)
		end
	end
	return out
end

-- ------------------------------------------------------------------ specs

describe("citizen aerial readability (ground contrast, hat hues, size on screen)", function()
	it("keeps every worn colour of every job, outfit, hair colour and hat variant clear of the ground", function()
		local checked = 0
		for _, job in JOBS do
			for outfit = 1, R.outfit do
				for hairColor = 1, R.hairColor do
					local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, outfit))
					for _, w in wornColours(rig) do
						checked += 1
						local bad = tooClose(w.color)
						if bad then
							expect(
								`{job} outfit {outfit} hairColor {hairColor} {w.label} {w.color:ToHex()} too close to {bad}`
							).toBe("clear of the ground")
						end
					end
				end
			end
			for hair = 1, R.hair do -- the six hat variants
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(hair, 1, 1))
				for _, w in wornColours(rig) do
					local bad = tooClose(w.color)
					if bad then
						expect(`{job} hair {hair} {w.label} {w.color:ToHex()} too close to {bad}`).toBe(
							"clear of the ground"
						)
					end
				end
			end
		end
		expect(checked).toBeGreaterThan(900)
	end)

	it("trips the checker on the colours this pass replaced (mutants)", function()
		local replaced = {
			hauler_panel = Color3.fromRGB(156, 118, 80), -- the old hauler sleeves and sack: 2 and 4 from Ground
			hauler_sack = Color3.fromRGB(146, 108, 70),
			idle_trousers = Color3.fromRGB(110, 86, 60), -- the tunic's trousers: 0 from Mud
			miner_pot = Color3.fromRGB(168, 104, 34), -- 25 from Ground
			farmer_straw = Color3.fromRGB(200, 156, 64), -- 30.9 from Ground
			builder_panel = Color3.fromRGB(196, 158, 104), -- 18 from Ground
			woodcutter_panel = Color3.fromRGB(96, 66, 46), -- 9 from Mud
		}
		for name, c in replaced do
			if tooClose(c) == nil then
				expect(`{name} {c:ToHex()} passes the ground check`).toBe("trips it")
			end
		end
		expect(tooClose(replaced.hauler_panel)).never.toBeNil()
		expect(tooClose(replaced.idle_trousers)).never.toBeNil()
		expect(tooClose(replaced.miner_pot)).never.toBeNil()
		-- and the checker's own arithmetic: a colour is 0 from itself, and the worst of the old set is under 10 from some ground
		expect(dE(GROUND[3].color, GROUND[3].color)).toBeNear(0, 1e-9)
		expect(dE(replaced.hauler_panel, GROUND[3].color)).toBeLessThan(10)
		expect(dE(replaced.idle_trousers, GROUND[4].color)).toBeLessThan(5)
	end)

	it("separates the four job hats by hue as well as by value (dE 40 or more apart, default look)", function()
		local hats = {}
		for _, job in WORKING do
			hats[job] = child(Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1)), "Hair").Color
		end
		for i, a in WORKING do
			for j = i + 1, #WORKING do
				local b = WORKING[j]
				local d = dE(hats[a], hats[b])
				if d < 40 then
					expect(`{a} and {b} hats only dE {string.format("%.1f", d)} apart`).toBe("40 or more")
				end
			end
		end
		-- the old farmer straw and miner ochre were 41 apart in dE but 26 and 25 from the fields: that is rule 1's job
		expect(dE(hats.farmer, hats.miner)).toBeGreaterThan(40)
	end)

	it(
		"keeps the kingdom tint on the torso or the sleeves clear of the three main grounds in all four kingdoms",
		function()
			for id, color in KINGDOMS do
				for _, job in JOBS do
					local rig = Kit.character("citizen", job, color, lookOf(1, 1, 1))
					local best = 0
					for _, name in { "Torso", "LeftArm", "RightArm" } do
						local p = child(rig, name)
						if p:GetAttribute("KitTint") ~= nil then
							local worst = math.huge
							for k = 1, 3 do
								worst = math.min(worst, dE(p.Color, GROUND[k].color))
							end
							best = math.max(best, worst)
						end
					end
					if best < 25 then
						expect(`{id} {job} kingdom tint only dE {string.format("%.1f", best)} from the ground`).toBe(
							"25 or more"
						)
					end
				end
			end
		end
	)

	it("adds no parts to a citizen: counts per job are the ones before the pass", function()
		-- base parts + detail parts, default look (idle: Root, Torso, Head, two arms, two legs, hair, +1 accessory in some looks)
		local want = { idle = 8, farmer = 11, woodcutter = 11, miner = 11, builder = 11, hauler = 11 }
		for _, job in JOBS do
			local n = countParts(Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1)))
			expect(n).toBe(want[job])
			for outfit = 1, R.outfit do
				for hair = 1, R.hair do
					expect(countParts(Kit.character("citizen", job, CRIMSON, lookOf(hair, 2, outfit)))).toBeLessThanOrEqual(
						Kit.CHARACTER_MAX_PARTS
					)
				end
			end
		end
	end)

	it(
		"draws the body at least this tall: start view, zoom 220 and a 750 x 311 phone (tools/citizen_screen.py numbers)",
		function()
			-- Measured with this projection (default look, rest pose, body = head + torso + arms + legs, citizen at the focus), after the
			-- silhouette pass 2 (head x1.3, neck lift 0.07): start view 80.9 px at 1080p and 23.3 on the phone, zoom 220 18.5 and 5.3 (the
			-- same for every job: the body is the same height; before the pass 72.4, 20.8, 16.4, 4.7). tools/citizen_screen.py measures the
			-- citizens as the dump stands them (farther ones are smaller; medians 62.8, 18.1, 20.0, 5.7). The floors sit 3 % under the
			-- measure: an unscaled head (HEAD_SCALE 1) or a shrunk rig is under every one.
			local floors = {
				{
					zoom = StartView.START.zoom,
					fov = StartView.START.fov,
					height = 1080,
					min = 78.5,
					label = "start view, desktop 1080p",
				},
				{
					zoom = StartView.START.zoom,
					fov = StartView.START.fov,
					height = 311,
					min = 22.6,
					label = "start view, phone",
				},
				{ zoom = 220, fov = StartView.START.fov, height = 1080, min = 17.9, label = "zoom 220, desktop 1080p" },
				{ zoom = 220, fov = StartView.START.fov, height = 311, min = 5.1, label = "zoom 220, phone" },
			}
			for _, job in JOBS do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1))
				for _, fl in floors do
					local px = bodyPixels(rig, fl.zoom, fl.fov, fl.height)
					if px < fl.min then
						expect(`{job} {fl.label}: {string.format("%.1f", px)} px`).toBe(`at least {fl.min} px`)
					end
				end
			end
			-- the checker sees a shrunk rig (mutant): 70 % of the idle citizen is under every floor
			local idle = Kit.character("citizen", "idle", CRIMSON, lookOf(1, 1, 1))
			local small = shrunk(idle, 0.7)
			local trips = 0
			for _, fl in floors do
				if bodyPixels(small, fl.zoom, fl.fov, fl.height) < fl.min then
					trips += 1
				end
			end
			expect(trips).toBeGreaterThanOrEqual(3)
		end
	)

	it(
		"draws the head, hat, tool handle and the hauler's sack bigger (silhouette pass 2), at the same part count",
		function()
			expect(silhouetteFailures()).toEqual({})
			expect(Character.HEAD_SCALE).toBeGreaterThanOrEqual(1.25)
			expect(Character.TOOL_SCALE).toBeGreaterThanOrEqual(1.25)
			-- the head still sits on the shoulders (it touches the torso top, 3.9) and the part count is the one before the pass
			for _, job in JOBS do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1))
				local head, torso = child(rig, "Head"), child(rig, "Torso")
				local headBottom = head.CFrame.Position.Y - head.Size.Y / 2
				local torsoTop = torso.CFrame.Position.Y + torso.Size.Y / 2
				expect(headBottom).toBeLessThanOrEqual(torsoTop + 0.01)
				expect(headBottom).toBeGreaterThanOrEqual(torsoTop - 0.15)
			end
			expect(OLD_HEAD * Character.HEAD_SCALE).toBeGreaterThanOrEqual(MIN_HEAD)
		end
	)

	it("trips on the old proportions (mutants: head, hat, tool and sack scales set back to 1)", function()
		local headScale, toolScale, sackScale, toolScales, hatScale =
			Character.HEAD_SCALE, Character.TOOL_SCALE, Character.SACK_SCALE, Character.TOOL_SCALES, Character.HAT_SCALE
		local function with(patch: () -> (), check: () -> any): any
			patch()
			local ok, result = pcall(check)
			Character.HEAD_SCALE, Character.TOOL_SCALE, Character.SACK_SCALE = headScale, toolScale, sackScale
			Character.TOOL_SCALES, Character.HAT_SCALE = toolScales, hatScale
			assert(ok, result)
			return result
		end
		-- head and hats back to 1: the head and every hat rule trips
		local headFails = with(function()
			Character.HEAD_SCALE = 1
			Character.HAT_SCALE = table.freeze({})
		end, silhouetteFailures)
		expect(#headFails).toBeGreaterThanOrEqual(5)
		-- tools back to 1: every handle rule trips
		local toolFails = with(function()
			Character.TOOL_SCALE = 1
			Character.TOOL_SCALES = table.freeze({})
		end, silhouetteFailures)
		expect(#toolFails).toBeGreaterThanOrEqual(4)
		-- the sack back to 1: the sack rule trips
		local sackFails = with(function()
			Character.SACK_SCALE = 1
		end, silhouetteFailures)
		expect(#sackFails).toBeGreaterThanOrEqual(1)
		-- and the body floors trip on an unscaled head (the 80.9 px at the start view was 72.4)
		local idleFloor = with(function()
			Character.HEAD_SCALE = 1
		end, function()
			return bodyPixels(
				Kit.character("citizen", "idle", CRIMSON, lookOf(1, 1, 1)),
				StartView.START.zoom,
				StartView.START.fov,
				1080
			)
		end)
		expect(idleFloor).toBeLessThan(78.5)
		-- restored: the pass is back in place
		expect(silhouetteFailures()).toEqual({})
	end)

	it(
		"codes every job by one saturated tool colour that is no kingdom colour and 40 dE or more from the other jobs' (pass 3)",
		function()
			local codes = {}
			for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
				local c = jobCode(job)
				codes[job] = c
				local problem = jobCodeProblem(c)
				if problem then
					expect(`{job} tool colour {c:ToHex()}: {problem}`).toBe("a saturated colour that is no kingdom's")
				end
			end
			local jobs = { "farmer", "woodcutter", "miner", "builder", "hauler" }
			for i, a in jobs do
				for k = i + 1, #jobs do
					local d = dE(codes[a], codes[jobs[k]])
					if d < 40 then
						expect(`{a} and {jobs[k]} tool colours only dE {string.format("%.1f", d)} apart`).toBe(
							"40 or more"
						)
					end
				end
			end
		end
	)

	it(
		"trips the tool colour checker on the colours pass 3 replaced (mutants: steel, iron, wood, the pale sack, a gold head)",
		function()
			local replaced = {
				steel_blade = Color3.fromRGB(138, 146, 158), -- the hoe blade and axe head
				iron_tines = Color3.fromRGB(104, 110, 122), -- the pick
				wood_mallet = Color3.fromRGB(139, 90, 51), -- the mallet head: dirt brown
				pale_sack = Color3.fromRGB(244, 232, 140), -- the hauler's sack of pass 1
				gold_head = Color3.fromRGB(235, 185, 16), -- a head in the gold kingdom's colour
				crimson_head = Color3.fromRGB(190, 40, 50), -- and in crimson's
			}
			for name, c in replaced do
				if jobCodeProblem(c) == nil and tooClose(c) == nil then -- dull or a kingdom's colour, or the ground's
					expect(`{name} {c:ToHex()} passes the job-code and ground checks`).toBe("trips them")
				end
			end
			expect(tooClose(replaced.wood_mallet)).never.toBeNil() -- and the ground check alone catches the brown
			-- the checker's own arithmetic: pure white and pure red saturation
			expect(saturation(Color3.new(1, 1, 1))).toBeNear(0, 1e-9)
			expect(saturation(Color3.new(1, 0, 0))).toBeNear(1, 1e-9)
		end
	)
end)
