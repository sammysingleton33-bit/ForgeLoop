--!strict
--[[
	Feedback/Presets (game-001, FORGE-04, FL-0062): AI Kingdoms particle presets, registered by
	FeedbackController through VFXController:register (validated against Experience/VfxPresets.BUDGET:
	≤ 2 emitters, ≤ 300 live particles, rate ≤ 100/s, lifetime ≤ 5 s). Built-in textures until FORGE-02's
	texture batch (handoff 2026-10-12-forge-04-to-forge-02-vfx-and-emotes.md); swapping one is a
	one-line `texture` change.

	Palette (EXPERIENCE.md §5): gold for rewards, dust brown for construction, bark and stone for
	gathering, wheat for food. Presets with `tint = true` take the kingdom colour.
]]

local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")

local T = VfxPresets.TEXTURES
local rgb = Color3.fromRGB
local GOLD, WHITE = rgb(255, 207, 92), rgb(255, 255, 255)
local DUST, BARK, STONE, WHEAT = rgb(170, 140, 105), rgb(130, 90, 55), rgb(150, 150, 145), rgb(235, 200, 110)
local DOWN, UP = Vector3.new(0, -18, 0), Vector3.new(0, 3, 0)

local function burst(fields: { [string]: any }): { [string]: any }
	fields.size = fields.size or { 0.6, 0 }
	fields.transparency = fields.transparency or { 0, 1 }
	fields.spread = fields.spread or 180
	fields.lightEmission = fields.lightEmission or 0
	return fields
end

local function chips(id: string, color: Color3): { [string]: any }
	return {
		id = id,
		category = "gather",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { color },
				burst = 8,
				lifetime = { 0.3, 0.6 },
				speed = { 6, 10 },
				size = { 0.4, 0.1 },
				spread = 60,
				acceleration = DOWN,
			}),
		},
	}
end

return table.freeze({
	{
		id = "kingdom.construction.place",
		category = "construction",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { DUST },
				burst = 14,
				lifetime = { 0.6, 1 },
				speed = { 3, 6 },
				size = { 1.2, 2.4 },
				spread = 70,
				drag = 4,
			}),
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
				burst = 24,
				lifetime = { 0.6, 1.2 },
				speed = { 6, 11 },
				lightEmission = 0.7,
				drag = 3,
			}),
			burst({
				texture = T.smoke,
				colors = { DUST },
				burst = 10,
				lifetime = { 0.8, 1.2 },
				speed = { 2, 4 },
				size = { 1.5, 2.5 },
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
				lifetime = { 0.5, 0.9 },
				speed = { 4, 8 },
				size = { 1, 2 },
				spread = 90,
				drag = 3,
			}),
		},
	},
	{
		id = "kingdom.territory.claim",
		category = "territory",
		priority = 3,
		reducedMotion = "reduce",
		tint = true,
		durationSec = 1.5,
		emitters = {
			{
				texture = T.sparkle,
				colors = { GOLD, WHITE },
				rate = 50,
				lifetime = { 1, 1.8 },
				speed = { 5, 9 },
				size = { 0.6, 0 },
				transparency = { 0, 1 },
				spread = 20,
				lightEmission = 0.8,
				acceleration = UP,
			},
			burst({ texture = T.sparkle, colors = { GOLD }, burst = 30, lifetime = { 0.6, 1.1 }, speed = { 8, 14 } }),
		},
	},
	chips("kingdom.harvest.wood", BARK),
	chips("kingdom.harvest.stone", STONE),
	chips("kingdom.harvest.food", WHEAT),
	-- A riot's burning building (FORGE-01's Burning attribute, D-050 (1b)), until the fire is out: large
	-- flames and a tall smoke column above the roof, so it reads from the aerial camera (FL-0091).
	{
		id = "kingdom.building.fire",
		category = "consequence",
		priority = 3,
		reducedMotion = "reduce",
		emitters = {
			{
				texture = T.fire,
				colors = { rgb(255, 170, 60), rgb(220, 60, 20) },
				rate = 40,
				lifetime = { 0.6, 1.2 },
				speed = { 5, 9 },
				size = { 5, 1 },
				transparency = { 0.1, 1 },
				spread = 20,
				lightEmission = 1,
				acceleration = Vector3.new(0, 4, 0),
			},
			{
				texture = T.smoke,
				colors = { rgb(70, 64, 58), rgb(150, 145, 140) },
				rate = 10,
				lifetime = { 3, 4.5 },
				speed = { 6, 10 },
				size = { 6, 16 },
				transparency = { 0.2, 1 },
				spread = 15,
				lightEmission = 0,
				acceleration = Vector3.new(0, 3, 0),
			},
		},
	},
	-- War (FL-0130): sparks and dust, never blood (13+ fantasy violence, BRIEF §11); the aerial camera
	-- is 40-220 studs away, so the building effects are large and the hit sparks small and bright.
	{
		id = "war.hit",
		category = "war",
		priority = 1,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { WHITE, rgb(255, 214, 140) },
				burst = 8,
				lifetime = { 0.15, 0.3 },
				speed = { 6, 12 },
				size = { 0.8, 0 },
				lightEmission = 1,
			}),
		},
	},
	{
		id = "war.building.hit",
		category = "war",
		priority = 2,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { DUST, STONE },
				burst = 10,
				lifetime = { 0.6, 1.1 },
				speed = { 4, 8 },
				size = { 2.5, 5 },
				spread = 60,
				drag = 3,
			}),
			burst({
				texture = T.sparkle,
				colors = { STONE, BARK },
				burst = 8,
				lifetime = { 0.5, 0.9 },
				speed = { 8, 14 },
				size = { 0.9, 0.4 },
				acceleration = DOWN,
			}),
		},
	},
	{
		id = "war.building.collapse",
		category = "war",
		priority = 3,
		reducedMotion = "reduce",
		emitters = {
			burst({
				texture = T.smoke,
				colors = { DUST, rgb(120, 110, 100) },
				burst = 60,
				lifetime = { 2, 3.5 },
				speed = { 6, 14 },
				size = { 8, 18 },
				transparency = { 0.15, 1 },
				spread = 90,
				drag = 2,
				acceleration = UP,
			}),
			burst({
				texture = T.sparkle,
				colors = { STONE, BARK },
				burst = 40,
				lifetime = { 0.8, 1.6 },
				speed = { 10, 22 },
				size = { 1.6, 0.6 },
				acceleration = DOWN,
			}),
		},
	},
	-- where a raid is: a red beacon in the raided land, until the raid ends (the camera ping goes here)
	{
		id = "war.raid.ping",
		category = "war",
		priority = 3,
		reducedMotion = "reduce",
		emitters = {
			{
				texture = T.sparkle,
				colors = { rgb(255, 70, 50), rgb(255, 160, 120) },
				rate = 14,
				lifetime = { 1.5, 2.5 },
				speed = { 10, 16 },
				size = { 3, 1 },
				transparency = { 0, 1 },
				spread = 8,
				lightEmission = 1,
				acceleration = Vector3.new(0, 2, 0),
			},
		},
	},
	{
		id = "kingdom.deposit",
		category = "economy",
		priority = 1,
		reducedMotion = "skip",
		emitters = {
			burst({
				texture = T.sparkle,
				colors = { GOLD },
				burst = 5,
				lifetime = { 0.3, 0.5 },
				speed = { 2, 4 },
				size = { 0.3, 0 },
				lightEmission = 0.6,
			}),
		},
	},
})
