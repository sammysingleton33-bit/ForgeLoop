--!strict
--[[
	Experience/VfxPresets — particle presets played by VFXController (client) and their budgets.

	Preset
		id: string, category: string, priority: 1..3 (who keeps budget when the screen is busy)
		emitters: { Emitter } (1..2)
		durationSec: number?   continuous emitters run this long; nil = until VFXController:stop(handle)
		reducedMotion: "keep" | "reduce" | "skip"   what happens when the player turns on reduced motion
		shake: { magnitude: number, duration: number }?   camera shake request (never with reduced motion)
		tint: boolean?         colors may be replaced by the caller's kingdom colour (opts.tint)
	Emitter (maps 1:1 to ParticleEmitter properties; VFXController builds the instance)
		texture, colors: { Color3 } (1-2, start -> end), lifetime { min, max }, speed { min, max },
		size { start, end }, transparency { start, end }, spread (degrees), lightEmission 0..1,
		drag?, acceleration: Vector3?, burst: number? (Emit(n) once), rate: number? (per second, continuous)
		Exactly one of burst / rate.

	Mobile budgets (FL-0024 initial; FL-0032 refines; recorded in roblox/studio-tests/experience.md):
		BUDGET.emittersPerPreset = 2
		BUDGET.particlesPerPreset = 300   estimated live particles: burst + rate x lifetime.max
		BUDGET.ratePerEmitter = 100       creator-docs effects/particle-emitters.md @af5f853: "up to 400
		                                  particles per second (100 per second on mobile)"
		BUDGET.lifetimeMax = 5            house rule (platform cap is 20 s, same doc)
	VFXController additionally caps live particles across all presets (BUDGET.particlesOnScreen).

	Textures: rbxasset://textures/particles/sparkles_main.dds is ParticleEmitter's default texture;
	the smoke/fire textures are the legacy Smoke/Fire ones. All three are built-in client content and
	still need the Studio visual check (G5/G6). FORGE-02 may replace them with authored flipbooks.

	The kingdom presets (construction, harvest, siege, ...) are AI Kingdoms content kept here until a
	per-game VFX config file is assigned (handoff to FORGE-00).
]]

local VfxPresets = {}

VfxPresets.BUDGET = table.freeze({
	emittersPerPreset = 2,
	particlesPerPreset = 300,
	ratePerEmitter = 100,
	lifetimeMax = 5,
	particlesOnScreen = 600,
	activePresets = 16,
})

VfxPresets.TEXTURES = table.freeze({
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
})

local T = VfxPresets.TEXTURES
local rgb = Color3.fromRGB
local GOLD, WHITE, DUST, WOOD, STONE, WHEAT, EMBER, SMOKE =
	rgb(255, 207, 92),
	rgb(255, 255, 255),
	rgb(176, 148, 112),
	rgb(150, 105, 60),
	rgb(150, 150, 150),
	rgb(232, 200, 90),
	rgb(255, 140, 40),
	rgb(90, 85, 80)
local DOWN = Vector3.new(0, -18, 0)
local UP = Vector3.new(0, 3, 0)

local function burst(fields: { [string]: any }): { [string]: any }
	fields.size = fields.size or { 0.6, 0 }
	fields.transparency = fields.transparency or { 0, 1 }
	fields.spread = fields.spread or 180
	fields.lightEmission = fields.lightEmission or 0
	return fields
end

local PRESETS: { any } = {
	-- Factory presets (every game)
	{
		id = "hit.generic",
		category = "hit",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { WHITE, EMBER },
				burst = 10,
				lifetime = { 0.15, 0.3 },
				speed = { 10, 18 },
				size = { 0.35, 0 },
				lightEmission = 1,
				drag = 6,
			}),
		},
	},
	{
		id = "reward.burst",
		category = "reward",
		priority = 3,
		reducedMotion = "reduce",
		tint = true,
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				burst = 28,
				lifetime = { 0.6, 1.2 },
				speed = { 6, 12 },
				lightEmission = 0.7,
				drag = 3,
				acceleration = DOWN,
			}),
		},
	},
	{
		id = "levelup.column",
		category = "levelUp",
		priority = 3,
		reducedMotion = "reduce",
		durationSec = 1.2,
		emitters = {
			{
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				rate = 60,
				lifetime = { 1, 1.6 },
				speed = { 6, 10 },
				size = { 0.5, 0 },
				transparency = { 0, 1 },
				spread = 12,
				lightEmission = 0.8,
				acceleration = UP,
			},
			burst({ texture = T.sparkle, colors = { WHITE }, burst = 30, lifetime = { 0.5, 1 }, speed = { 8, 14 } }),
		},
	},
	{
		id = "ambience.motes",
		category = "ambience",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			{
				texture = T.sparkle,
				colors = { rgb(255, 240, 200) },
				rate = 3,
				lifetime = { 3, 4 },
				speed = { 0.3, 0.8 },
				size = { 0.15, 0.15 },
				transparency = { 0.3, 1 },
				spread = 180,
				lightEmission = 0.5,
			},
		},
	},
	-- AI Kingdoms presets
	{
		id = "kingdom.construction.place",
		category = "construction",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { DUST },
				burst = 12,
				lifetime = { 0.6, 1 },
				speed = { 3, 6 },
				size = { 1.2, 2.4 },
				spread = 70,
				drag = 4,
			}),
		},
	},
	{
		id = "kingdom.construction.progress",
		category = "construction",
		priority = 1,
		reducedMotion = "reduce",
		emitters = {
			{
				texture = T.smoke,
				colors = { DUST },
				rate = 4,
				lifetime = { 1, 1.5 },
				speed = { 1, 2 },
				size = { 0.8, 1.6 },
				transparency = { 0.4, 1 },
				spread = 40,
				lightEmission = 0,
			},
		},
	},
	{
		id = "kingdom.construction.complete",
		category = "construction",
		priority = 3,
		reducedMotion = "reduce",
		tint = true,
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				burst = 30,
				lifetime = { 0.8, 1.4 },
				speed = { 5, 10 },
				lightEmission = 0.7,
				acceleration = UP,
			}),
			burst({
				texture = T.smoke,
				colors = { DUST },
				burst = 14,
				lifetime = { 0.8, 1.2 },
				speed = { 4, 7 },
				size = { 1.5, 3 },
				spread = 90,
				drag = 4,
			}),
		},
	},
	{
		id = "kingdom.harvest.food",
		category = "harvest",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { WHEAT },
				burst = 10,
				lifetime = { 0.6, 1 },
				speed = { 2, 4 },
				size = { 0.35, 0 },
				spread = 40,
				acceleration = UP,
			}),
		},
	},
	{
		id = "kingdom.harvest.wood",
		category = "harvest",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { WOOD },
				burst = 8,
				lifetime = { 0.4, 0.7 },
				speed = { 4, 7 },
				size = { 0.3, 0.1 },
				acceleration = DOWN,
			}),
		},
	},
	{
		id = "kingdom.harvest.stone",
		category = "harvest",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { STONE },
				burst = 8,
				lifetime = { 0.4, 0.7 },
				speed = { 4, 7 },
				size = { 0.3, 0.1 },
				acceleration = DOWN,
			}),
		},
	},
	{
		id = "kingdom.harvest.gold",
		category = "harvest",
		priority = 2,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				burst = 12,
				lifetime = { 0.5, 0.9 },
				speed = { 2, 5 },
				size = { 0.3, 0 },
				lightEmission = 0.8,
				acceleration = UP,
			}),
		},
	},
	{
		id = "kingdom.upgrade",
		category = "levelUp",
		priority = 3,
		reducedMotion = "reduce",
		durationSec = 1.5,
		tint = true,
		shake = { magnitude = 0.25, duration = 0.35 },
		emitters = {
			{
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				rate = 60,
				lifetime = { 1.2, 1.6 },
				speed = { 8, 14 },
				size = { 0.8, 0 },
				transparency = { 0, 1 },
				spread = 15,
				lightEmission = 0.9,
				acceleration = UP,
			},
			burst({
				texture = T.sparkle,
				colors = { GOLD },
				burst = 40,
				lifetime = { 0.8, 1.4 },
				speed = { 10, 16 },
				lightEmission = 0.8,
			}),
		},
	},
	{
		id = "kingdom.army.recruit",
		category = "army",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { DUST },
				burst = 16,
				lifetime = { 0.6, 1 },
				speed = { 5, 8 },
				size = { 1, 2 },
				spread = 90,
				drag = 5,
			}),
		},
	},
	{
		id = "kingdom.combat.clash",
		category = "hit",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { WHITE, EMBER },
				burst = 10,
				lifetime = { 0.15, 0.3 },
				speed = { 12, 20 },
				size = { 0.3, 0 },
				lightEmission = 1,
				drag = 6,
			}),
		},
	},
	{
		id = "kingdom.siege.impact",
		category = "siege",
		priority = 3,
		reducedMotion = "reduce",
		shake = { magnitude = 0.4, duration = 0.3 },
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { STONE },
				burst = 18,
				lifetime = { 0.6, 1.1 },
				speed = { 10, 18 },
				size = { 0.5, 0.3 },
				acceleration = Vector3.new(0, -40, 0),
			}),
			burst({
				texture = T.smoke,
				colors = { DUST, SMOKE },
				burst = 20,
				lifetime = { 1, 1.8 },
				speed = { 4, 8 },
				size = { 2, 4 },
				spread = 120,
				drag = 3,
			}),
		},
	},
	{
		id = "kingdom.siege.burning",
		category = "siege",
		priority = 2,
		reducedMotion = "keep",
		emitters = {
			{
				texture = T.fire,
				colors = { EMBER, rgb(255, 210, 120) },
				rate = 20,
				lifetime = { 0.6, 1 },
				speed = { 2, 4 },
				size = { 1.5, 0.5 },
				transparency = { 0.2, 1 },
				spread = 20,
				lightEmission = 1,
				acceleration = UP,
			},
			{
				texture = T.smoke,
				colors = { SMOKE },
				rate = 8,
				lifetime = { 2.5, 3.5 },
				speed = { 2, 3 },
				size = { 2, 5 },
				transparency = { 0.4, 1 },
				spread = 15,
				lightEmission = 0,
				acceleration = UP,
			},
		},
	},
	{
		id = "kingdom.territory.claim",
		category = "territory",
		priority = 2,
		reducedMotion = "reduce",
		tint = true,
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				burst = 30,
				lifetime = { 1, 1.6 },
				speed = { 3, 6 },
				size = { 0.6, 0 },
				lightEmission = 0.6,
				acceleration = UP,
			}),
		},
	},
	{
		id = "kingdom.morale.up",
		category = "morale",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { rgb(255, 230, 150) },
				burst = 12,
				lifetime = { 1, 1.6 },
				speed = { 1, 3 },
				size = { 0.4, 0 },
				spread = 60,
				lightEmission = 0.5,
				acceleration = UP,
			}),
		},
	},
	{
		id = "kingdom.morale.down",
		category = "morale",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { rgb(120, 125, 140) },
				burst = 10,
				lifetime = { 1, 1.6 },
				speed = { 0.5, 1.5 },
				size = { 1, 2 },
				transparency = { 0.5, 1 },
				spread = 60,
			}),
		},
	},
	{
		id = "kingdom.festival",
		category = "event",
		priority = 2,
		reducedMotion = "reduce",
		durationSec = 6,
		emitters = {
			{
				texture = T.sparkle,
				colors = { rgb(255, 90, 90), rgb(90, 160, 255) },
				rate = 30,
				lifetime = { 2, 3 },
				speed = { 6, 10 },
				size = { 0.4, 0.3 },
				transparency = { 0, 1 },
				spread = 50,
				lightEmission = 0.3,
				acceleration = Vector3.new(0, -6, 0),
			},
		},
	},
	{
		id = "kingdom.chimney",
		category = "ambience",
		priority = 1,
		reducedMotion = "keep",
		emitters = {
			{
				texture = T.smoke,
				colors = { rgb(200, 200, 200) },
				rate = 2,
				lifetime = { 3, 4 },
				speed = { 1, 2 },
				size = { 0.8, 2.5 },
				transparency = { 0.5, 1 },
				spread = 10,
				lightEmission = 0,
				acceleration = UP,
			},
		},
	},
	{
		id = "kingdom.victory",
		category = "celebration",
		priority = 3,
		reducedMotion = "reduce",
		durationSec = 4,
		tint = true,
		emitters = {
			{
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				rate = 40,
				lifetime = { 1.5, 2 },
				speed = { 14, 22 },
				size = { 0.7, 0 },
				transparency = { 0, 1 },
				spread = 35,
				lightEmission = 1,
				acceleration = Vector3.new(0, -8, 0),
			},
			burst({
				texture = T.sparkle,
				colors = { GOLD },
				burst = 80,
				lifetime = { 1, 1.8 },
				speed = { 10, 18 },
				lightEmission = 0.8,
			}),
		},
	},
}

function VfxPresets.liveParticles(preset: any): number
	local total = 0
	for _, emitter in preset.emitters do
		if emitter.burst then
			total += emitter.burst
		elseif emitter.rate then
			total += emitter.rate * emitter.lifetime[2]
		end
	end
	return total
end

local function isRange(value: any): boolean
	return type(value) == "table" and type(value[1]) == "number" and type(value[2]) == "number" and value[1] <= value[2]
end

function VfxPresets.validate(presets: { any }): { string }
	local problems: { string } = {}
	local seen = {}
	local B = VfxPresets.BUDGET
	for i, preset in presets do
		local where = `preset[{i}] ({tostring(preset.id)})`
		if type(preset.id) ~= "string" or not string.match(preset.id, "^[a-z][a-z0-9_]*%.[a-z0-9_%.]+$") then
			table.insert(problems, `{where}: id must look like "area.name"`)
		elseif seen[preset.id] then
			table.insert(problems, `{where}: duplicate id`)
		end
		seen[preset.id] = true
		if type(preset.priority) ~= "number" or preset.priority < 1 or preset.priority > 3 then
			table.insert(problems, `{where}: priority must be 1..3`)
		end
		if preset.reducedMotion ~= "keep" and preset.reducedMotion ~= "reduce" and preset.reducedMotion ~= "skip" then
			table.insert(problems, `{where}: reducedMotion must be keep | reduce | skip`)
		end
		local emitters = preset.emitters
		if type(emitters) ~= "table" or #emitters < 1 then
			table.insert(problems, `{where}: needs at least one emitter`)
			continue
		end
		if #emitters > B.emittersPerPreset then
			table.insert(problems, `{where}: {#emitters} emitters; budget {B.emittersPerPreset}`)
		end
		for e, emitter in emitters do
			local at = `{where} emitter {e}`
			if (emitter.burst == nil) == (emitter.rate == nil) then
				table.insert(problems, `{at}: set exactly one of burst or rate`)
			end
			if emitter.rate and (emitter.rate <= 0 or emitter.rate > B.ratePerEmitter) then
				table.insert(problems, `{at}: rate {emitter.rate} outside 0..{B.ratePerEmitter} (mobile cap)`)
			end
			if emitter.burst and (emitter.burst < 1 or emitter.burst % 1 ~= 0) then
				table.insert(problems, `{at}: burst must be a positive integer`)
			end
			if not isRange(emitter.lifetime) or emitter.lifetime[2] > B.lifetimeMax or emitter.lifetime[1] <= 0 then
				table.insert(problems, `{at}: lifetime needs min > 0 and max <= {B.lifetimeMax}`)
			end
			if not isRange(emitter.speed) then
				table.insert(problems, `{at}: speed needs a min and a max`)
			end
			if type(emitter.colors) ~= "table" or #emitter.colors < 1 or #emitter.colors > 2 then
				table.insert(problems, `{at}: colors must list 1 or 2 Color3`)
			end
			if type(emitter.texture) ~= "string" or emitter.texture == "" then
				table.insert(problems, `{at}: texture required`)
			end
			if type(emitter.lightEmission) ~= "number" or emitter.lightEmission < 0 or emitter.lightEmission > 1 then
				table.insert(problems, `{at}: lightEmission must be 0..1`)
			end
		end
		local live = VfxPresets.liveParticles(preset)
		if live > B.particlesPerPreset then
			table.insert(problems, `{where}: ~{live} live particles; budget {B.particlesPerPreset}`)
		end
		if preset.durationSec ~= nil and (type(preset.durationSec) ~= "number" or preset.durationSec <= 0) then
			table.insert(problems, `{where}: durationSec must be positive`)
		end
		if
			preset.shake ~= nil
			and (type(preset.shake.magnitude) ~= "number" or type(preset.shake.duration) ~= "number")
		then
			table.insert(problems, `{where}: shake needs magnitude and duration`)
		end
	end
	return problems
end

local byId = {}
for _, preset in PRESETS do
	byId[preset.id] = preset
end

VfxPresets.ALL = PRESETS
VfxPresets.byId = byId

function VfxPresets.get(id: string): any
	return byId[id]
end

return VfxPresets
