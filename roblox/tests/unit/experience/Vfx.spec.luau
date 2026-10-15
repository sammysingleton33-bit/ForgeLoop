local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local EngineStubs = require("./doubles/EngineStubs")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local VFXDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/VFXController")

EngineStubs.install()

-- Game-style presets, registered once for this spec file (VfxPresets.register is how games add theirs).
local rgb = Color3.fromRGB
local function spec(fields)
	local base = {
		texture = VfxPresets.TEXTURES.sparkle,
		colors = { rgb(255, 255, 255) },
		lifetime = { 0.5, 1 },
		speed = { 1, 2 },
		size = { 1, 0 },
		transparency = { 0, 1 },
		spread = 30,
		lightEmission = 0,
	}
	for k, v in fields do
		base[k] = v
	end
	return base
end
local TEST_PRESETS = {
	{
		id = "test.burning",
		category = "siege",
		priority = 2,
		reducedMotion = "keep",
		emitters = {
			spec({ rate = 20, lifetime = { 0.6, 1 } }),
			spec({ rate = 8, lifetime = { 2.5, 3.5 } }),
		},
	},
	{
		id = "test.chimney",
		category = "ambience",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			spec({ rate = 2, lifetime = { 3, 4 } }),
		},
	},
	{
		id = "test.festival",
		category = "event",
		priority = 2,
		reducedMotion = "reduce",
		durationSec = 6,
		emitters = {
			spec({ rate = 30, lifetime = { 2, 3 } }),
		},
	},
	{
		id = "test.victory",
		category = "celebration",
		priority = 3,
		reducedMotion = "reduce",
		durationSec = 4,
		emitters = {
			spec({ rate = 40, lifetime = { 1.5, 2 } }),
			spec({ burst = 80, lifetime = { 1, 1.8 } }),
		},
	},
	{
		id = "test.impact",
		category = "siege",
		priority = 3,
		reducedMotion = "reduce",
		shake = { magnitude = 0.4, duration = 0.3 },
		emitters = {
			spec({ burst = 18 }),
			spec({ burst = 20 }),
		},
	},
	{
		id = "test.claim",
		category = "territory",
		priority = 2,
		reducedMotion = "reduce",
		tint = true,
		emitters = {
			spec({ burst = 30 }),
		},
	},
}
assert(#VfxPresets.register(TEST_PRESETS) == 0, "test presets must be valid")

local function hasProblem(problems, substring)
	for _, p in problems do
		if string.find(p, substring, 1, true) then
			return true
		end
	end
	return false
end

local function emitter(fields)
	local base = {
		texture = VfxPresets.TEXTURES.sparkle,
		colors = { Color3.new(1, 1, 1) },
		burst = 10,
		lifetime = { 0.5, 1 },
		speed = { 1, 2 },
		size = { 1, 0 },
		transparency = { 0, 1 },
		spread = 30,
		lightEmission = 0,
	}
	for k, v in fields or {} do
		base[k] = v
	end
	if base.burst == false then -- `burst = nil` in a table literal cannot clear the default
		base.burst = nil
	end
	return base
end

describe("Experience/VfxPresets budgets", function()
	it("register() rejects invalid lists and duplicate ids, adding nothing", function()
		local problems = VfxPresets.register({
			{
				id = "test.ok",
				category = "x",
				priority = 1,
				reducedMotion = "keep",
				emitters = { spec({ burst = 5 }) },
			},
			{
				id = "test.bad",
				category = "x",
				priority = 1,
				reducedMotion = "keep",
				emitters = { spec({ burst = 999 }) },
			},
		})
		expect(table.concat(problems, "\n")).toContain("(test.bad): ~999 live particles")
		expect(VfxPresets.get("test.ok")).toBeNil()
		local dup = VfxPresets.register({ TEST_PRESETS[1] })
		expect(dup[1]).toContain("test.burning: already registered")
	end)

	it("every shipped preset is valid and inside the mobile budget", function()
		expect(VfxPresets.validate(VfxPresets.ALL)).toEqual({})
		for _, preset in VfxPresets.ALL do
			expect(#preset.emitters).toBeLessThanOrEqual(2)
			expect(VfxPresets.liveParticles(preset)).toBeLessThanOrEqual(300)
		end
	end)

	it("estimates live particles as bursts plus rate x max lifetime", function()
		local preset =
			{ emitters = { emitter({ burst = 40 }), emitter({ burst = false, rate = 20, lifetime = { 1, 3 } }) } }
		expect(VfxPresets.liveParticles(preset)).toBe(100)
	end)

	it("rejects presets over budget: emitters, particles, mobile rate, lifetime", function()
		local base = { priority = 1, reducedMotion = "keep" }
		local function preset(id, emitters)
			local p = table.clone(base)
			p.id = id
			p.emitters = emitters
			return p
		end
		local problems = VfxPresets.validate({
			preset("x.three", { emitter(), emitter(), emitter() }),
			preset("x.many", { emitter({ burst = 301 }) }),
			preset("x.rate", { emitter({ burst = false, rate = 120 }) }),
			preset("x.long", { emitter({ lifetime = { 1, 8 } }) }),
			preset("x.both", { emitter({ rate = 5 }) }),
		})
		expect(hasProblem(problems, "(x.three): 3 emitters; budget 2")).toBe(true)
		expect(hasProblem(problems, "(x.many): ~301 live particles; budget 300")).toBe(true)
		expect(hasProblem(problems, "(x.rate) emitter 1: rate 120 outside 0..100 (mobile cap)")).toBe(true)
		expect(hasProblem(problems, "(x.long) emitter 1: lifetime needs min > 0 and max <= 5")).toBe(true)
		expect(hasProblem(problems, "(x.both) emitter 1: set exactly one of burst or rate")).toBe(true)
	end)
end)

describe("VFXController", function()
	local env, registry, vfx, settings, platformReduce

	beforeEach(function()
		platformReduce = { ReducedMotionEnabled = false }
		env = MockEnv.new({
			isServer = false,
			localPlayer = { userId = 701 },
			services = { GuiService = platformReduce },
		})
		env.SoundService = env.mock.dataModel:GetService("SoundService")
		registry = Loader.load(env, { SettingsDef, VFXDef })
		vfx = registry:get("VFXController")
		settings = registry:get("SettingsController")
	end)

	it("builds real ParticleEmitters from the preset and emits the burst", function()
		local effect = vfx:play("reward.burst", { position = Vector3.new(4, 5, 6) })
		local holder, emitters = effect.parts[1], effect.parts[2]
		expect(holder.ClassName).toBe("Attachment")
		expect(holder.Position).toBe(Vector3.new(4, 5, 6))
		expect(#emitters).toBe(1)
		local e = emitters[1]
		expect(e.ClassName).toBe("ParticleEmitter")
		expect(e.Parent).toBe(holder)
		expect(e.Texture).toBe(VfxPresets.TEXTURES.sparkle)
		expect(e.Lifetime).toBe(NumberRange.new(0.6, 1.2))
		expect(e.Rate).toBe(0)
		expect(e.Enabled).toBe(false)
		expect(EngineStubs.emitted(e)).toEqual({ 28 })
	end)

	it("puts an effect on a Model into an owned Attachment under its PrimaryPart, gone with the burst", function()
		local model = env.newInstance("Model")
		local root = env.newInstance("Part")
		root.Parent = model
		model.PrimaryPart = root
		local effect = vfx:play("reward.burst", { position = Vector3.zero, parent = model })
		local holder, emitters = effect.parts[1], effect.parts[2]
		expect(holder.ClassName).toBe("Attachment") -- a ParticleEmitter emits only from a BasePart or Attachment
		expect(holder.Parent).toBe(root)
		expect(emitters[1].Parent).toBe(holder)
		env.mock:advance(1.3)
		expect(holder.Parent).toBeNil() -- a pooled rig keeps no emitter
		expect(#root:GetChildren()).toBe(0)
	end)

	it("uses a BasePart or Attachment parent as is; a Model without parts plays at the position", function()
		local part = env.newInstance("Part")
		local onPart = vfx:play("hit.generic", { parent = part })
		expect(onPart.parts[1]).toBeNil()
		expect(onPart.parts[2][1].Parent).toBe(part)
		local empty = env.newInstance("Model")
		local atPosition = vfx:play("hit.generic", { position = Vector3.new(1, 2, 3), parent = empty })
		expect(atPosition.parts[1].Parent).toBe(vfx._backend.anchor())
		expect(atPosition.parts[1].Position).toBe(Vector3.new(1, 2, 3))
	end)

	it("cleans a burst up after its longest lifetime", function()
		local effect = vfx:play("reward.burst", { position = Vector3.zero })
		expect(vfx:activeEffects()).toBe(1)
		env.mock:advance(1.3)
		expect(vfx:activeEffects()).toBe(0)
		expect(effect.parts[1].Parent).toBeNil()
	end)

	it("tints presets that allow it with the kingdom colour", function()
		local red = Color3.fromRGB(200, 30, 30)
		local effect = vfx:play("test.claim", { position = Vector3.zero, tint = red })
		expect(effect.parts[2][1].Color).toBe(ColorSequence.new(red, red))
		local plain = vfx:play("hit.generic", { position = Vector3.zero, tint = red })
		expect(plain.parts[2][1].Color).never.toBe(ColorSequence.new(red, red))
	end)

	it("runs continuous presets for durationSec, then stops emitting and cleans up", function()
		local effect = vfx:play("test.festival", { position = Vector3.zero })
		local e = effect.parts[2][1]
		expect(e.Enabled).toBe(true)
		expect(e.Rate).toBe(30)
		env.mock:advance(6.1)
		expect(e.Enabled).toBe(false)
		expect(vfx:activeEffects()).toBe(0)
		env.mock:advance(3.1)
		expect(effect.parts[1].Parent).toBeNil()
	end)

	it("reduced motion halves 'reduce' presets and drops their camera shake", function()
		local shakes = 0
		vfx.shakeRequested:connect(function()
			shakes += 1
		end)
		vfx:play("test.impact", { position = Vector3.zero })
		expect(shakes).toBe(1)
		platformReduce.ReducedMotionEnabled = true -- the platform's Reduce Motion counts too
		local effect = vfx:play("test.impact", { position = Vector3.zero })
		expect(shakes).toBe(1)
		expect(EngineStubs.emitted(effect.parts[2][1])).toEqual({ 9 })
		expect(effect.live).toBe(19)
	end)

	it("effectsQuality 'reduced' halves every effect's particles but keeps its motion (FL-0103)", function()
		local shakes = 0
		vfx.shakeRequested:connect(function()
			shakes += 1
		end)
		settings:set("effectsQuality", "reduced")
		local burst = vfx:play("reward.burst", { position = Vector3.zero })
		expect(EngineStubs.emitted(burst.parts[2][1])).toEqual({ 14 }) -- 28 at full quality
		local effect = vfx:play("test.impact", { position = Vector3.zero })
		expect(EngineStubs.emitted(effect.parts[2][1])).toEqual({ 9 })
		expect(effect.live).toBe(19)
		expect(shakes).toBe(1) -- quality is not motion: the shake stays
		platformReduce.ReducedMotionEnabled = true -- with reduced motion too: a quarter
		local both = vfx:play("test.impact", { position = Vector3.zero })
		expect(EngineStubs.emitted(both.parts[2][1])).toEqual({ 4 })
		expect(shakes).toBe(1)
	end)

	it("the camera shake setting turns shakes off", function()
		local shakes = 0
		vfx.shakeRequested:connect(function()
			shakes += 1
		end)
		settings:set("cameraShake", false)
		vfx:play("test.impact", { position = Vector3.zero })
		expect(shakes).toBe(0)
	end)

	it("keeps live particles on screen within budget, evicting lower-priority continuous effects first", function()
		local burning = {}
		for i = 1, 12 do -- each burning preset: 20 x 1 s fire + 8 x 3.5 s smoke = 48; 12 x 48 = 576
			burning[i] = vfx:play("test.burning", { position = Vector3.new(i, 0, 0) })
			expect(burning[i]).never.toBeNil()
		end
		expect(vfx:liveParticles()).toBe(576)
		local festival = vfx:play("test.festival", { position = Vector3.zero }) -- priority 2, ~90
		expect(festival).toBeNil() -- does not fit and cannot evict equal priority
		expect(vfx.stats.skipped.budget).toBe(1)
		local victory = vfx:play("test.victory", { position = Vector3.zero }) -- priority 3, 160
		expect(victory).never.toBeNil()
		expect(vfx:liveParticles()).toBeLessThanOrEqual(VfxPresets.BUDGET.particlesOnScreen)
		expect(burning[1].parts[2][1].Enabled).toBe(false)
	end)

	it("floating text rises, fades and is removed", function()
		local attachment = vfx:float("+3 Food", Vector3.new(1, 2, 3))
		local gui = attachment:FindFirstChildOfClass("BillboardGui")
		local label = gui:FindFirstChildOfClass("TextLabel")
		expect(label.Text).toBe("+3 Food")
		env.mock:advance(0.6)
		expect(gui.StudsOffset.Y).toBeGreaterThan(1)
		env.mock:advance(0.7)
		expect(attachment.Parent).toBeNil()
		expect(vfx:float("", Vector3.zero)).toBeNil()
	end)

	it("shows a speech bubble over a part, then removes it", function()
		local part = env.newInstance("Part")
		part.Parent = env.Workspace
		local bubble = vfx:bubble(part, "Aye!", 2)
		expect(bubble.Parent).toBe(part)
		expect(bubble:FindFirstChildOfClass("TextLabel").Text).toBe("Aye!")
		env.mock:advance(2.1)
		expect(part:FindFirstChild("ForgeBubble")).toBeNil()
		expect(vfx:bubble(nil, "x", 1)).toBeNil()
	end)

	it("text keeps the default engine distance unless the caller sets maxDistance (0 = no limit)", function()
		local function guiOf(instance)
			return if instance:IsA("BillboardGui") then instance else instance:FindFirstChildOfClass("BillboardGui")
		end
		expect(guiOf(vfx:float("+1 Wood", Vector3.zero)).MaxDistance).toBe(VFXDef.TEXT_MAX_DISTANCE)
		expect(guiOf(vfx:float("+1 Wood", Vector3.zero, { maxDistance = 0 })).MaxDistance).toBe(0)
		local part = env.newInstance("Part")
		part.Parent = env.Workspace
		expect(guiOf(vfx:bubble(part, "Aye!", 2, { maxDistance = 400 })).MaxDistance).toBe(400)
		expect(guiOf(vfx:bubble(part, "Aye!", 2, { maxDistance = -1 })).MaxDistance).toBe(VFXDef.TEXT_MAX_DISTANCE)
	end)
end)
