--[[
	SupportCoverage (FL-0149, D-060): do the Crown Arena's key citizens reach a real match? A role offers a perk when its
	building stands (a finished one of config Support roles[r].building) AND its key citizen lives; the perk is offered from
	loyalty `offer.pledgedLoyalty` (80) and the stronger one from `empoweredLoyalty` (95). This plays the real match (four
	AI governors, no human) to the start of Endgame and counts, per kingdom, the roles that have their building and a living
	key citizen ("roles") and those whose citizen is also loyal enough to offer ("perks"). One kingdom is made an idle
	player's (a seated ruler nobody acts for: RulerAI skips it), the control: it builds nothing, so it has no roles.

	The numbers are printed once per run. FORGE-00's target for the AI kingdoms: at least 2 roles each on average.
]]

local T = require("../../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")

local SEEDS = { 11, 12, 13 }
local IDLE = "gold" -- the kingdom played by an idle player
local ENDGAME = 20 + 480 + 720 + 900 -- match seconds when Endgame begins (Lobby 20, Founding 480, Expansion 720, Conflict 900)

-- roles with a standing building and a living key citizen, and of those the ones loyal enough to offer a perk
local function coverage(sim: any, k: any): (number, number, number)
	local standing: { [string]: boolean } = {}
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		if b.level >= 1 and not b.destroyed then
			standing[b.kind] = true
		end
	end
	local roles, perks, topLoyalty = 0, 0, 0
	local seen: { [string]: boolean } = {}
	for _, cid in k.citizenIds do
		local c = sim.citizens[cid]
		local role = if c and c.alive and c.profile then c.profile.keyRole else nil
		local def = if role then Support.roles[role] else nil
		if def then
			topLoyalty = math.max(topLoyalty, c.loyalty or 50) -- any living key citizen, building or not
		end
		if def and not seen[role] and standing[def.building] then
			seen[role] = true
			roles += 1
			if (c.loyalty or 50) >= Support.offer.pledgedLoyalty then
				perks += 1
			end
		end
	end
	return roles, perks, topLoyalty
end

describe("SupportCoverage: key citizens in the real match (FL-0149)", function()
	it(
		"AI governors build support buildings: at least two roles per kingdom on average; an idle player has none",
		function()
			local aiRoles, aiPerks, aiKingdoms = 0, 0, 0
			local topLoyalty = 0 -- the highest loyalty any AI kingdom's key citizen reached (a perk is offered from 80)
			local idleRoles = 0
			local lines = {}
			for _, seed in SEEDS do
				local match = Match.new({
					random = Random.new(seed),
					minPlayers = 0,
					people = People.CONTENT, -- generated people, as CitizenService turns them on: key citizens exist only with them
					now = function()
						return 1700000000
					end,
				})
				local sim = match.sim
				sim.kingdoms[IDLE].rulers = { 99 } -- a seated human ruler: the governor leaves this kingdom alone
				while sim.time < ENDGAME and match.state ~= "Results" do
					match:update(MatchConfig.tickSeconds)
				end
				local parts = {}
				for _, kid in sim.kingdomOrder do
					local k = sim.kingdoms[kid]
					if k.alive then
						local roles, perks, top = coverage(sim, k)
						if kid == IDLE then
							idleRoles += roles
							table.insert(parts, `{kid}(idle player):{roles}r/{perks}p`)
						else
							aiRoles += roles
							aiPerks += perks
							aiKingdoms += 1
							topLoyalty = math.max(topLoyalty, top)
							table.insert(parts, `{kid}:{roles}r/{perks}p`)
						end
					else
						table.insert(parts, `{kid}:fell`)
					end
				end
				table.insert(lines, `seed {seed} t={math.floor(sim.time)}: {table.concat(parts, " ")}`)
			end
			print(
				`SupportCoverage: AI kingdoms standing {aiKingdoms}, roles per kingdom {string.format(
					"%.2f",
					aiRoles / math.max(aiKingdoms, 1)
				)}, perks per kingdom {string.format("%.2f", aiPerks / math.max(aiKingdoms, 1))}, highest AI key-citizen loyalty {math.floor(
					topLoyalty
				)} (perk from {Support.offer.pledgedLoyalty}); idle player roles {idleRoles}\n  {table.concat(
					lines,
					"\n  "
				)}`
			)
			expect(aiKingdoms >= 3).toBe(true)
			expect(aiRoles / aiKingdoms >= 2).toBe(true)
			expect(idleRoles).toBe(0)
		end
	)
end)
