--!strict
--[[
	Lighting preset for AI Kingdoms VS-1 (FORGE-02; BRIEF §6, CONTRACTS G10). Pure data, applied by
	WorldService at server start. Fixed time of day for VS-1: warm late morning, long soft shadows,
	saturated but natural colours (art bible: blender/ART_DIRECTION.md).

	Note: `Lighting.Technology` is not scriptable in Roblox. It must be set in the place/project file
	(games/game-001/default.project.json, FORGE-05): `technology` below is the requested value.
]]

return {
	technology = "Future", -- set in the project file, not by script

	lighting = {
		ClockTime = 10.6,
		GeographicLatitude = 38,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(96, 88, 104),
		OutdoorAmbient = Color3.fromRGB(150, 146, 158),
		EnvironmentDiffuseScale = 0.55,
		EnvironmentSpecularScale = 0.35,
		ShadowSoftness = 0.25,
		GlobalShadows = true,
		ColorShift_Top = Color3.fromRGB(255, 236, 200),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ExposureCompensation = 0.1,
	},

	atmosphere = {
		Density = 0.28,
		Offset = 0.12,
		Color = Color3.fromRGB(199, 214, 235),
		Decay = Color3.fromRGB(106, 126, 160),
		Glare = 0.15,
		Haze = 1.4,
	},

	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 14,
		MoonAngularSize = 9,
		StarCount = 0,
	},

	colorCorrection = {
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.14,
		TintColor = Color3.fromRGB(255, 250, 240),
	},

	bloom = {
		Intensity = 0.35,
		Size = 22,
		Threshold = 1.6,
	},

	sunRays = {
		Intensity = 0.04,
		Spread = 0.6,
	},

	clouds = {
		Cover = 0.45,
		Density = 0.55,
		Color = Color3.fromRGB(255, 255, 255),
	},

	-- Terrain material colours (Terrain:SetMaterialColor). Warm greens and earthy browns that sit
	-- with the Kit palette (Kit/Parts.luau, blender/lib/palette.py).
	terrainColors = {
		Grass = Color3.fromRGB(116, 156, 66),
		LeafyGrass = Color3.fromRGB(80, 122, 54),
		Ground = Color3.fromRGB(150, 114, 76),
		Mud = Color3.fromRGB(106, 80, 56),
		Sand = Color3.fromRGB(214, 190, 138),
		Rock = Color3.fromRGB(132, 128, 120),
		Slate = Color3.fromRGB(100, 98, 96),
		Cobblestone = Color3.fromRGB(178, 164, 140),
		-- no Water entry: water colour is Terrain.WaterColor (below), not a material colour
	},

	water = {
		WaterColor = Color3.fromRGB(46, 120, 168),
		WaterTransparency = 0.6,
		WaterReflectance = 0.6,
		WaterWaveSize = 0.08,
		WaterWaveSpeed = 8,
	},
}
