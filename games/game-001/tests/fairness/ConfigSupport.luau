--!strict
--[[
	ConfigSupport — the game's own support numbers for the fairness harness (FL-0076, FORGE-05).

	The same interface as DesignSupport (TIER_ORDER, TIERS, perkSets, modifiers), but every modifier comes from
	FORGE-01's `Arena/SupportModel.modifiers` reading config `Support`, so the gate measures what DuelService will
	hand the duel. DesignSupport stays as the design-doc fixture the harness specs run on.

		ConfigSupport.new(config?) -> support      config = a Support config table (nil: config Support)
		support.TIER_ORDER, support.TIERS[tier] = { slots, crowdRally }
		support.perkSets(tier, pool) -> { { string } }   every set of exactly min(slots, usable pool) distinct perks
		support.modifiers(tier, perks, power) -> { Modifier }
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local ConfigSupport = {}

function ConfigSupport.new(config: any?): any
	local cfg = config or Support
	local tiers = {}
	for _, tier in cfg.tierOrder do
		local def = cfg.tiers[tier]
		tiers[tier] = { slots = def.slots, crowdRally = def.crowdRally == true }
	end
	local support = { TIER_ORDER = cfg.tierOrder, TIERS = tiers, config = cfg }

	function support.perkSets(tier: string, pool: { string }): { { string } }
		local def = tiers[tier]
		if def == nil then
			error(`ConfigSupport: unknown tier '{tostring(tier)}'`, 2)
		end
		local usable = {}
		for _, name in pool do
			if name ~= "crowdRally" or def.crowdRally then
				table.insert(usable, name)
			end
		end
		local size = math.min(def.slots, #usable)
		local sets: { { string } } = {}
		local current: { string } = {}
		local function pick(from: number)
			if #current == size then
				table.insert(sets, table.clone(current))
				return
			end
			for i = from, #usable do
				table.insert(current, usable[i])
				pick(i + 1)
				table.remove(current)
			end
		end
		pick(1)
		return sets
	end

	function support.modifiers(tier: string, perks: { string }?, power: string?): { any }
		local picks = {}
		for _, name in perks or {} do
			table.insert(picks, { trigger = name, power = power or "empowered" })
		end
		return SupportModel.modifiers(tier :: any, picks, cfg)
	end

	return support
end

return ConfigSupport
