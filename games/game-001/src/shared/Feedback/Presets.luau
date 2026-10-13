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
