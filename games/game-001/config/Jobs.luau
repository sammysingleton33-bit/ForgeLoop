--!strict
--[[
	Jobs (ReplicatedStorage.Forge.Config.Jobs) — citizen jobs and what they harvest. Owner: FORGE-01.

	jobs: CONTRACTS G2 JobIds (farmer, woodcutter, miner, builder, hauler) with the resources they
	produce and their skill per activity kind (farm, wood, stone, gold, build), used both for utility
	scoring and as a work-rate multiplier. hauler is the generalist pool (quotas never apply to it).
	nodes: resource node kinds placed by the world (amount, footprint radius, worker slots, regrow).
	rates: gather units per second at a node, farm harvest time, builder work rate, carry size.
]]

return {
	jobOrder = { "farmer", "woodcutter", "miner", "builder", "hauler" },
	jobs = {
		farmer = { id = "farmer", resources = { "food" }, affinity = { farm = 1, build = 0.3 } },
		woodcutter = { id = "woodcutter", resources = { "wood" }, affinity = { wood = 1, build = 0.3 } },
		miner = { id = "miner", resources = { "stone", "gold" }, affinity = { stone = 1, gold = 1, build = 0.3 } },
		builder = { id = "builder", resources = {}, affinity = { build = 1, wood = 0.35, stone = 0.35, farm = 0.25 } },
		hauler = {
			id = "hauler",
			resources = {},
			affinity = { build = 0.6, wood = 0.6, stone = 0.6, farm = 0.6, gold = 0.4 },
		},
	},
	nodes = {
		tree = { id = "tree", resource = "wood", amount = 80, footprint = 3, slots = 2, regrow = 240 },
		rock = { id = "rock", resource = "stone", amount = 200, footprint = 4, slots = 3 },
		goldvein = { id = "goldvein", resource = "gold", amount = 300, footprint = 4, slots = 3 },
		berries = { id = "berries", resource = "food", amount = 60, footprint = 3, slots = 2, regrow = 180 },
	},
	gatherRate = { wood = 0.8, stone = 0.5, gold = 0.35, food = 0.8 },
	harvestTime = 6, -- seconds per farm harvest
	buildRate = 1, -- work units per second per builder (times job skill)
	carry = 10, -- units a citizen carries per trip
}
