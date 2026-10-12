--[[
	PopulationDoubles — FORGE-01's population remotes (G13.2, approved by FORGE-00) and its real
	`Kingdom.SetJobQuota` (G8, games/game-001/src/shared/Kingdom/Remotes.luau) as a test double:

		local world = KingdomWorld.new({
			remotes = PopulationDoubles.REMOTES,
			services = { PopulationDoubles.service },
			clientDefinitions = { ... },
		})
		local pop = world.server:get("PopulationService")
		pop:set("crimson", "soldier", 4)           -- server side: change a count and push it

	Kingdom.Population (serverEvent to members) / Kingdom.GetPopulation (function) carry
	CitizenService:getPopulation(myKingdom) = { total, byJob, cap }; soldiers count as byJob.soldier.
	Kingdom.SetJobQuota(job, count) -> (boolean, errorCode?): jobs are config Jobs.jobOrder without the
	hauler pool. The double's rule (a stand-in, not the game's): the quota moves haulers into the job,
	or back into the pool, at once; it never takes more haulers than there are.
]]

local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local PopulationDoubles = {}

PopulationDoubles.JOBS = { "farmer", "woodcutter", "miner", "builder" }
PopulationDoubles.START = { farmer = 3, woodcutter = 2, miner = 1, builder = 1, hauler = 3, soldier = 0 }
PopulationDoubles.CAP = 12

PopulationDoubles.REMOTES = {
	Kingdom = {
		{ name = "Kingdom.Population", kind = "serverEvent" },
		{ name = "Kingdom.GetPopulation", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
		{
			name = "Kingdom.SetJobQuota",
			kind = "function",
			args = { V.enum(PopulationDoubles.JOBS), V.integer(0, 50) },
			rate = { burst = 10, perSecond = 4 },
		},
	},
}

function PopulationDoubles.service(world)
	return {
		name = "PopulationService",
		dependencies = { "RemoteService", "KingdomService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local kingdoms = registry:get("KingdomService")
			local svc = { byKingdom = {} }
			function svc:_of(kingdom)
				local p = self.byKingdom[kingdom]
				if p == nil then
					p = { cap = PopulationDoubles.CAP, byJob = table.clone(PopulationDoubles.START) }
					self.byKingdom[kingdom] = p
				end
				return p
			end
			function svc:get(kingdom)
				local p = self:_of(kingdom)
				local total = 0
				for _, n in p.byJob do
					total += n
				end
				return { total = total, cap = p.cap, byJob = table.clone(p.byJob) }
			end
			function svc:publish(kingdom)
				for _, player in world.env.Players:GetPlayers() do
					if kingdoms:getKingdomOf(player) == kingdom then
						remotes:fire("Kingdom.Population", player, self:get(kingdom))
					end
				end
			end
			function svc:set(kingdom, job, count)
				self:_of(kingdom).byJob[job] = count
				self:publish(kingdom)
			end
			function svc:start()
				remotes:handle("Kingdom.GetPopulation", function(player)
					local kingdom = kingdoms:getKingdomOf(player)
					return if kingdom then self:get(kingdom) else nil
				end)
				remotes:handle("Kingdom.SetJobQuota", function(player, job, count)
					table.insert(world.calls, { name = "SetJobQuota", args = { job, count } })
					if world.latency > 0 then
						world.env.wait(world.latency)
					end
					local kingdom = kingdoms:getKingdomOf(player)
					if kingdom == nil then
						return false, "no_kingdom"
					end
					local byJob = self:_of(kingdom).byJob
					local current = byJob[job] or 0
					local moved = math.clamp(count - current, -current, byJob.hauler or 0)
					byJob[job] = current + moved
					byJob.hauler = (byJob.hauler or 0) - moved
					self:publish(kingdom)
					return true
				end)
			end
			return svc
		end,
	}
end

return PopulationDoubles
