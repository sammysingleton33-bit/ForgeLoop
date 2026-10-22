--[[
	world/Lighting preset sanity (visual upgrade pass 1, FORGE-02).

	WorldService assigns every key of the preset to a Roblox instance one by one (`instance[key] = value`), so a misspelt key or a value of the
	wrong type throws on the server in Studio, which the Lune mock does not notice. This spec pins:
	  1. names    every key of lighting / atmosphere / sky / colorCorrection / bloom / sunRays / clouds / water is a real property of its
	              class, of the right type, inside Roblox's range;
	  2. terrain  every terrainColors key is a real terrain material, a Color3, never Air or Water;
	  3. look     the design range of this pass: a morning sun between 25 and 55 degrees up (the equinox sun path the preview uses:
	              sin(el) = cos(latitude) * cos(15 degrees * (ClockTime - 12))), so shadows give form without covering the village or washing
	              it out, a sun colour that is warm (red >= green >= blue), a cool fill (blue >= red) and a ColorCorrection that does not
	              desaturate or darken the picture;
	  4. mutants  each rule fails when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it

local Preset = require("@game/ReplicatedStorage/Game/World/Lighting")

type Rule = { kind: string, low: number?, high: number? }
local function number(low: number, high: number): Rule
	return { kind = "number", low = low, high = high }
end
local COLOR: Rule = { kind = "color" }
local BOOL: Rule = { kind = "boolean" }

local SCHEMA: { [string]: { [string]: Rule } } = {
	lighting = {
		ClockTime = number(0, 24),
		GeographicLatitude = number(0, 90),
		Brightness = number(0, 10),
		Ambient = COLOR,
		OutdoorAmbient = COLOR,
		EnvironmentDiffuseScale = number(0, 1),
		EnvironmentSpecularScale = number(0, 1),
		ShadowSoftness = number(0, 1),
		GlobalShadows = BOOL,
		ColorShift_Top = COLOR,
		ColorShift_Bottom = COLOR,
		ExposureCompensation = number(-5, 5),
	},
	atmosphere = {
		Density = number(0, 1),
		Offset = number(0, 1),
		Color = COLOR,
		Decay = COLOR,
		Glare = number(0, 10),
		Haze = number(0, 10),
	},
	sky = {
		CelestialBodiesShown = BOOL,
		SunAngularSize = number(0, 21),
		MoonAngularSize = number(0, 11),
		StarCount = number(0, 5000),
	},
	colorCorrection = {
		Brightness = number(-1, 1),
		Contrast = number(-1, 1),
		Saturation = number(-1, 1),
		TintColor = COLOR,
	},
	bloom = { Intensity = number(0, 10), Size = number(0, 56), Threshold = number(0, 10) },
	sunRays = { Intensity = number(0, 1), Spread = number(0, 1) },
	clouds = { Cover = number(0, 1), Density = number(0, 1), Color = COLOR },
	water = {
		WaterColor = COLOR,
		WaterTransparency = number(0, 1),
		WaterReflectance = number(0, 1),
		WaterWaveSize = number(0, 1),
		WaterWaveSpeed = number(0, 100),
	},
}

local TERRAIN_MATERIALS = {
	Grass = true,
	LeafyGrass = true,
	Ground = true,
	Mud = true,
	Sand = true,
	Sandstone = true,
	Limestone = true,
	Rock = true,
	Slate = true,
	Basalt = true,
	Cobblestone = true,
	Pavement = true,
	Asphalt = true,
	Brick = true,
	Concrete = true,
	WoodPlanks = true,
	Salt = true,
	Snow = true,
	Ice = true,
	Glacier = true,
	CrackedLava = true,
}

local function problems(preset: any): { string }
	local out: { string } = {}
	for group, rules in SCHEMA do
		local table_ = preset[group]
		if type(table_) ~= "table" then
			table.insert(out, `{group}: missing`)
			continue
		end
		for key, value in table_ do
			local rule = rules[key]
			if rule == nil then
				table.insert(out, `{group}.{key}: not a property the preset may set (misspelt?)`)
			elseif rule.kind == "color" then
				if typeof(value) ~= "Color3" then
					table.insert(out, `{group}.{key}: not a Color3`)
				end
			elseif type(value) ~= rule.kind then
				table.insert(out, `{group}.{key}: a {type(value)}, want a {rule.kind}`)
			elseif rule.kind == "number" and (value < (rule.low :: number) or value > (rule.high :: number)) then
				table.insert(out, `{group}.{key}: {value} is outside {rule.low} .. {rule.high}`)
			end
		end
	end
	for name, color in preset.terrainColors or {} do
		if not TERRAIN_MATERIALS[name] then
			table.insert(out, `terrainColors.{name}: not a terrain material the preset may colour`)
		elseif typeof(color) ~= "Color3" then
			table.insert(out, `terrainColors.{name}: not a Color3`)
		end
	end
	local lt, cc = preset.lighting, preset.colorCorrection
	if type(lt) == "table" and type(cc) == "table" then
		local lat = math.rad(lt.GeographicLatitude)
		local el = math.deg(math.asin(math.max(0.05, math.cos(lat) * math.cos(math.rad((lt.ClockTime - 12) * 15)))))
		if el < 25 or el > 55 then
			table.insert(
				out,
				`the sun is {math.floor(el + 0.5)} degrees up, want 25 to 55 (shadows that give form without covering the village)`
			)
		end
		local sun, fill = lt.ColorShift_Top, lt.OutdoorAmbient
		if typeof(sun) == "Color3" and not (sun.R >= sun.G and sun.G >= sun.B) then
			table.insert(out, "the sun colour is not warm (red >= green >= blue)")
		end
		if typeof(fill) == "Color3" and fill.B < fill.R then
			table.insert(out, "the sky fill is not cool (blue >= red): shadows should lean blue against the warm sun")
		end
		if cc.Saturation < 0 or cc.Brightness < -0.05 or cc.Contrast < 0 then
			table.insert(out, "the ColorCorrection desaturates, darkens or flattens the picture")
		end
	end
	return out
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

describe("world/Lighting preset", function()
	it(
		"sets only real properties of the right type and range, and keeps the design range of the visual pass",
		function()
			local list = problems(Preset)
			if #list > 0 then
				error(`{#list} problems, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
			end
		end
	)
end)

describe("world/Lighting preset mutants are caught", function()
	local function caught(name: string, mutate: (any) -> ())
		it(`catches: {name}`, function()
			local copy = deepCopy(Preset)
			mutate(copy)
			if #problems(copy) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end
	caught("a misspelt Lighting property", function(p)
		p.lighting.Brigthness = 2
	end)
	caught("an Atmosphere density above 1", function(p)
		p.atmosphere.Density = 1.5
	end)
	caught("a ClockTime past 24", function(p)
		p.lighting.ClockTime = 25
	end)
	caught("a colour given as a table", function(p)
		p.lighting.Ambient = { 88, 96, 120 }
	end)
	caught("a low evening sun (shadows cover the village)", function(p)
		p.lighting.ClockTime = 7.2
	end)
	caught("a noon sun (flat, no shadow form)", function(p)
		p.lighting.ClockTime = 12
		p.lighting.GeographicLatitude = 5
	end)
	caught("a cold sun", function(p)
		p.lighting.ColorShift_Top = Color3.fromRGB(190, 210, 255)
	end)
	caught("a warm fill (no cool shadows)", function(p)
		p.lighting.OutdoorAmbient = Color3.fromRGB(170, 150, 120)
	end)
	caught("a desaturating grade", function(p)
		p.colorCorrection.Saturation = -0.3
	end)
	caught("a terrain colour for Water", function(p)
		p.terrainColors.Water = Color3.fromRGB(0, 0, 255)
	end)
	caught("a terrain colour that is not a Color3", function(p)
		p.terrainColors.Grass = "green"
	end)
end)
