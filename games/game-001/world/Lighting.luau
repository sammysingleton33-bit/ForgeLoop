--!strict
--[[
	Lighting preset for AI Kingdoms VS-1 (FORGE-02; BRIEF §6, CONTRACTS G10). Pure data, applied by
	WorldService at server start. Fixed time of day for VS-1: a clear morning, a lower and warmer sun than the first build
	(long soft shadows that give the buildings and trees form), cool sky fill in the shadows, a little more contrast
	(art bible: blender/ART_DIRECTION.md).

	Visual upgrade pass 1 (owner's Studio playtest of B22: "lighting and atmosphere need a lot of work"). What changed against the
	B22 values (the revert is these numbers back, or `git revert` of the commit that carries them):
	  ClockTime 10.6 -> 9.8 (the sun about 47 -> 41 degrees up by the preview's equinox sun path), Brightness 2.6 -> 2.9, ColorShift_Top (255,236,200) -> (255,232,196),
	  Ambient (96,88,104) -> (88,96,120), OutdoorAmbient (150,146,158) -> (132,142,168) (cool fill: shadows lean blue against the
	  warm sun), EnvironmentDiffuseScale 0.55 -> 0.65, ExposureCompensation 0.1 -> 0.15, ShadowSoftness 0.25 -> 0.3;
	  Atmosphere Density 0.28 -> 0.32, Offset 0.12 -> 0.16, Color (199,214,235) -> (208,214,226), Decay (106,126,160) -> (112,128,166),
	  Haze 1.4 -> 1.8; ColorCorrection Contrast 0.08 -> 0.12, Saturation 0.14 -> 0.10, TintColor (255,250,240) -> (255,248,236).
	Tuned in a Blender PREVIEW of the real world at the default camera (blender/scripts/render_world.py): the preview approximates sun
	height, colour, fill, haze and grade, not Roblox's own lighting. UNVERIFIED in Studio; the checks are in the PR that carries it.

	Every key below is a real property of its class: WorldService assigns them one by one, so a misspelt name would throw in Studio
	(tests/world/LightingPreset.spec.luau checks the names and the ranges).

	Note: `Lighting.Technology` is not scriptable in Roblox. It must be set in the place/project file
	(games/game-001/default.project.json, FORGE-05): `technology` below is the requested value.
]]

return {
	technology = "Future", -- set in the project file, not by script

	lighting = {
		ClockTime = 9.8,
		GeographicLatitude = 38,
		Brightness = 2.9,
		Ambient = Color3.fromRGB(88, 96, 120),
		OutdoorAmbient = Color3.fromRGB(132, 142, 168),
		EnvironmentDiffuseScale = 0.65,
		EnvironmentSpecularScale = 0.35,
		ShadowSoftness = 0.3,
		GlobalShadows = true,
		ColorShift_Top = Color3.fromRGB(255, 232, 196),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ExposureCompensation = 0.15,
	},

	atmosphere = {
		Density = 0.32,
		Offset = 0.16,
		Color = Color3.fromRGB(208, 214, 226),
		Decay = Color3.fromRGB(112, 128, 166),
		Glare = 0.15,
		Haze = 1.8,
	},

	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 14,
		MoonAngularSize = 9,
		StarCount = 0,
	},

	colorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.10,
		TintColor = Color3.fromRGB(255, 248, 236),
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
		Grass = Color3.fromRGB(106, 168, 62),
		LeafyGrass = Color3.fromRGB(84, 150, 52),
		Ground = Color3.fromRGB(150, 116, 78),
		Mud = Color3.fromRGB(110, 86, 60),
		Sand = Color3.fromRGB(214, 190, 138),
		Rock = Color3.fromRGB(128, 124, 118),
		Slate = Color3.fromRGB(110, 108, 104),
		Cobblestone = Color3.fromRGB(150, 144, 132),
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
