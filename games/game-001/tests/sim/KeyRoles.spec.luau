--[[
	KeyRoles (FL-0149, D-061): the key roles a real match's starting population actually has. Today they are exactly the
	blacksmith, the elder, the healer and the provisioner, in every kingdom: no captain (its job is soldier, and soldiers are
	units, not citizens) and no merchant (the third hauler never appears in the starting quotas). This pins that fact so a
	later change that gives the population a captain or a merchant flips these expectations on purpose, with the Called
	Warning perk, the barracks and the market (D-061) decided at the same time.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local People = require("@game/ReplicatedStorage/Game/Sim/People")

local TODAY = { "blacksmith", "elder", "healer", "provisioner" }

describe("KeyRoles: the starting population's key roles (D-061)", function()
	it(
		"every kingdom starts with exactly a blacksmith, an elder, a healer and a provisioner: no captain, no merchant",
		function()
			for _, seed in { 3, 11, 29 } do
				local match = Match.new({
					random = Random.new(seed),
					minPlayers = 0,
					people = People.CONTENT,
					now = function()
						return 1700000000
					end,
				})
				local sim = match.sim
				for _, kid in sim.kingdomOrder do
					local k = sim.kingdoms[kid]
					local roles: { string } = {}
					for _, cid in k.citizenIds do
						local c = sim.citizens[cid]
						if c.profile and c.profile.keyRole then
							table.insert(roles, c.profile.keyRole)
						end
					end
					table.sort(roles)
					expect(table.concat(roles, ",")).toBe(table.concat(TODAY, ","))
				end
			end
		end
	)
end)
