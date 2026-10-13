--[[
	ArmyDoubles — FORGE-01's army, objectives and match-end remotes (CONTRACTS G8, FL-0052 not built
	yet) as a test double for FL-0060: declarations for `Army.Recruit`, `Army.Command`,
	`Army.Objectives`, `Army.GetObjectives` and `Match.Ended` (KingdomWorld's Match area has only State /
	GetState), and a server double "MilitaryService" on top of KingdomWorld's doubles, the real
	TreasuryService and PopulationDoubles' PopulationService.

		local world = KingdomWorld.new({
			remotes = ArmyDoubles.remotes(),           -- Army + Match.Ended + PopulationDoubles' Kingdom remotes
			                                           -- (more maps may be passed: remotes(Rep.REMOTES))
			services = { PopulationDoubles.service, ArmyDoubles.service },
			clientDefinitions = { ... },
		})
		local army = world.server:get("MilitaryService")
		army:setProgress("watchtower", "azure", 0.3)  -- server side: move a capture bar and push the list
		army:setOwner("watchtower", "crimson")         -- capture: owner, progress { [owner] = 1 }
		army:endMatch({ winner = "azure", standings = { ... }, durationSec = 754 })
		army.refuse = "recruit_cap"                    -- the next recruits answer (false, reason)

	Double rules (stand-ins for FORGE-01, not the game's): a recruit needs the caller's own barracks
	("not_found", "not_owner", "not_barracks"), finished ("barracks_not_ready"), with #70's codes; it spends Costs.unit("soldier").cost × count
	through TreasuryService:spend ("cannot_afford") and raises byJob.soldier at once (no training
	time). Army.Command is recorded in world.calls ({ name = "Command", args = { unitIds, kind,
	targetPos, targetId } }) and does nothing else. The objective list starts with the neutral
	"watchtower" (world/Layout) and nobody's progress.
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local PopulationDoubles = require("./PopulationDoubles")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local ArmyDoubles = {}

ArmyDoubles.UNITS = { "soldier" }
ArmyDoubles.ORDERS = { "move", "attack", "capture", "guard" }

-- CONTRACTS G8 (kinds, arguments); rates are the double's (the contract says "rate-limited").
ArmyDoubles.REMOTES = {
	Army = {
		{
			name = "Army.Recruit",
			kind = "function",
			args = { V.integer(1, 65535), V.enum(ArmyDoubles.UNITS), V.integer(1, 10) },
			rate = { burst = 3, perSecond = 1 },
		},
		{
			name = "Army.Command",
			kind = "event",
			args = {
				V.array(V.integer(1, 65535), 50),
				V.enum(ArmyDoubles.ORDERS),
				V.optional(V.vector3(4000)),
				V.optional(V.string(1, 32)),
			},
			rate = { burst = 3, perSecond = 1 },
		},
		{ name = "Army.Objectives", kind = "serverEvent" },
		{ name = "Army.GetObjectives", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	},
	Match = {
		{ name = "Match.Ended", kind = "serverEvent" },
	},
}

-- Army + Match.Ended, plus PopulationDoubles' Kingdom remotes (the soldier count) and any other
-- declaration maps passed (e.g. ReputationDoubles.REMOTES), merged for KingdomWorld's `remotes`.
function ArmyDoubles.remotes(...: { [string]: { any } }): { [string]: { any } }
	local out = {}
	for _, source in { ArmyDoubles.REMOTES, PopulationDoubles.REMOTES, ... } do
		for area, decls in source do
			out[area] = out[area] or {}
			for _, decl in decls do
				table.insert(out[area], decl)
			end
		end
	end
	return out
end

function ArmyDoubles.service(world)
	return {
		name = "MilitaryService",
		dependencies = { "RemoteService", "TreasuryService", "KingdomService", "BuildingService", "PopulationService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local build = registry:get("BuildingService")
			local population = registry:get("PopulationService")
			local svc = {
				refuse = nil :: string?,
				recruits = 0,
				objectives = {
					{
						id = "watchtower",
						kind = "capture",
						position = Vector3.new(10, 0, -6),
						radius = 26,
						owner = nil,
						progress = {},
					},
				},
			}
			function svc:list()
				local out = {}
				for _, o in self.objectives do
					local copy = table.clone(o)
					copy.progress = table.clone(o.progress)
					table.insert(out, copy)
				end
				return out
			end
			function svc:publish()
				remotes:fireAll("Army.Objectives", self:list())
			end
			function svc:find(id)
				for _, o in self.objectives do
					if o.id == id then
						return o
					end
				end
				return nil
			end
			function svc:add(o)
				table.insert(self.objectives, o)
				self:publish()
			end
			function svc:setProgress(id, kingdom, value)
				self:find(id).progress[kingdom] = value
				self:publish()
			end
			function svc:setOwner(id, kingdom)
				local o = self:find(id)
				o.owner = kingdom
				o.progress = if kingdom then { [kingdom] = 1 } else {}
				self:publish()
			end
			function svc:endMatch(payload)
				remotes:fireAll("Match.Ended", payload)
			end
			function svc:start()
				remotes:handle("Army.GetObjectives", function()
					return self:list()
				end)
				remotes:handle("Army.Command", function(_player, unitIds, kind, targetPos, targetId)
					table.insert(world.calls, { name = "Command", args = { unitIds, kind, targetPos, targetId } })
				end)
				remotes:handle("Army.Recruit", function(player, barracksId, unitType, count)
					table.insert(world.calls, { name = "Recruit", args = { barracksId, unitType, count } })
					if world.latency > 0 then
						world.env.wait(world.latency) -- the round trip (KingdomWorld option `latency`)
					end
					local kingdom = kingdoms:getKingdomOf(player)
					local b = build.buildings[barracksId]
					if kingdom == nil then
						return false, "not_in_match"
					elseif self.refuse then
						return false, self.refuse
					elseif b == nil then
						return false, "not_found"
					elseif b.kingdom ~= kingdom then
						return false, "not_owner"
					elseif b.type ~= "barracks" then
						return false, "not_barracks"
					elseif b.state ~= "complete" then
						return false, "barracks_not_ready"
					end
					local unit = Costs.unit(unitType)
					local cost = {}
					for currency, amount in unit.cost do
						cost[currency] = amount * count
					end
					self.recruits += 1
					if not treasury:spend(kingdom, cost, `recruit:{self.recruits}`, "army") then
						return false, "cannot_afford"
					end
					local before = population:get(kingdom).byJob.soldier or 0
					population:set(kingdom, "soldier", before + count)
					return true
				end)
			end
			return svc
		end,
	}
end

return ArmyDoubles
