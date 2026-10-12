--[[
	FakeBus — a stand-in for Contracts/GameEvents with every declared event PLUS the proposed
	Experience/KingdomSignals events, so specs can drive kingdom signals before FORGE-01 declares them.
	Same shape as GameEvents: EVENT_NAMES + one Core/Signal per name.

		local bus = FakeBus.new()                       -- GameEvents + KingdomSignals.PROPOSED
		local bus = FakeBus.new({ only = { "PlayerReady" } })
		bus.BuildingCompleted:fire(player, { kingdomId = "k1", ... })
]]

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local KingdomSignals = require("@game/ReplicatedStorage/Forge/Experience/KingdomSignals")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local FakeBus = {}

function FakeBus.new(options: { only: { string }? }?)
	local names = {}
	if options and options.only then
		names = table.clone(options.only)
	else
		for _, name in GameEvents.EVENT_NAMES do
			table.insert(names, name)
		end
		for _, name in KingdomSignals.PROPOSED do
			table.insert(names, name)
		end
	end
	local bus = { EVENT_NAMES = names }
	for _, name in names do
		bus[name] = Signal.new()
	end
	return bus
end

return FakeBus
