local Thing = require("@game/ReplicatedStorage/Forge/Core/Thing")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

return {
	name = "KingdomService",
	dependencies = { "DataService" },
	new = function(_env, registry)
		return { types = Types, thing = Thing, data = registry:get("DataService") }
	end,
}
