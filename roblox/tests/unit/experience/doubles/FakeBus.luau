--[[
	FakeBus — a private stand-in for Contracts/GameEvents (same names, same shape: EVENT_NAMES + one
	Core/Signal per name), so specs never share connections with other specs through the real bus.

		local bus = FakeBus.new()                       -- every GameEvents name
		local bus = FakeBus.new({ only = { "PlayerReady" } })
		local bus = FakeBus.new({ extra = { "TestEvent" } })   -- plus names the real bus does not have
		bus.ShopViewed:fire(player, "main", nil)
]]

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local FakeBus = {}

function FakeBus.new(options: { only: { string }?, extra: { string }? }?)
	local names = {}
	if options and options.only then
		names = table.clone(options.only)
	else
		for _, name in GameEvents.EVENT_NAMES do
			table.insert(names, name)
		end
	end
	for _, name in (options and options.extra) or {} do
		table.insert(names, name)
	end
	local bus = { EVENT_NAMES = names }
	for _, name in names do
		bus[name] = Signal.new()
	end
	return bus
end

return FakeBus
