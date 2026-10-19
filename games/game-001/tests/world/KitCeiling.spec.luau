--[[
	The all-built part ceiling with the war kit (FL-0128, D-047): BRIEF section 14 keeps 25k parts as the target of a
	typical match and 27k as the hard ceiling of the all-built worst case. The worst case is the world WorldService builds
	plus every kingdom fully built at its top levels (wall level 3 x 12, the gate at level 3, every other type at its
	highest level, two building sites) plus the three neutral towers. Fails above 27k and prints the breakdown, so the war
	kit's wall and gate levels cannot push the world past the ceiling; if it ever does, cap the wall segments per kingdom in
	config (FORGE-00) before thinning the art.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CEILING = 27000

-- the highest level of each type (the others have two levels; Kit.build clamps)
local TOP = { keep = 3, barracks = 4, mine = 3, blacksmith = 3, wall = 3, gate = 3 }
-- { type, count, stage? } per kingdom: the kingdom in the Buildings.luau budget note
local KINGDOM = {
	{ "keep", 1 },
	{ "house", 10 },
	{ "farm", 3 },
	{ "storehouse", 1 },
	{ "lumbercamp", 2 },
	{ "quarry", 2 },
	{ "barracks", 2 },
	{ "watchtower", 2 },
	{ "wall", 12 },
	{ "gate", 1 },
	{ "mine", 1 },
	{ "blacksmith", 1 },
	{ "market", 1 },
	{ "infirmary", 1 },
	{ "granary", 1 },
	{ "shrine", 1 },
	{ "barracks", 1, 2 }, -- two sites in progress
	{ "house", 1, 2 },
}

describe("World part ceiling with the war kit (D-047, FL-0128)", function()
	it("keeps WorldService plus four fully built kingdoms at max levels within 27k parts", function()
		local env = MockEnv.new({ seed = 1 })
		local svc = Def.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc:start()
		env.mock:advance(30)
		expect(svc:isReady()).toBe(true)
		local world = svc.stats.parts
		svc:destroy()

		local perKingdom = {}
		local buildings = 0
		for _, identity in KingdomsConfig.identities do
			local c = identity.color
			local color = Color3.fromRGB(c[1], c[2], c[3])
			local n = 0
			for _, row in KINGDOM do
				local bt, count, stage = row[1], row[2], row[3] or "complete"
				for i = 1, count do
					local variant = if bt == "house" then ((i - 1) % 8) + 1 else nil
					n += Kit.partCount(Kit.build(bt, TOP[bt] or 2, stage, color, variant))
				end
			end
			table.insert(perKingdom, `{identity.id} {n}`)
			buildings += n
		end
		local neutral = 3 * Kit.partCount(Kit.build("watchtower", TOP.watchtower or 2, "complete", Kit.NEUTRAL_COLOR))
		local total = world + buildings + neutral
		print(
			`world part ceiling (D-047): WorldService {world} + kingdoms {buildings} ({table.concat(perKingdom, ", ")})`
				.. ` + neutral towers {neutral} = {total} / {CEILING}`
		)
		if total > CEILING then
			error(`all-built worst case {total} parts > {CEILING} (D-047)`)
		end
	end)
end)
