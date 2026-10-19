--[[
	PetitionDoubles — a stand-in for FORGE-01's key-citizen fields and `Kingdom.FulfilPetition` (CONTRACTS G12 v0.4-g11e:
	CitizenService:inspect gains `role: KeyRole?` and `petition: { id, text, need?, expiresAt }?`; G12.4
	`Kingdom.FulfilPetition(petitionId: string(1,32)) -> (ok, reason?)`, spending the need through TreasuryService), for
	the FL-0073 citizen-card specs and scenes. Rides on doubles/CitizenDoubles: it writes `role` / `petition` / `loyalty`
	onto CitizenService's citizens, so Sim.Inspect returns them.

		local world = KingdomWorld.new({
			remotes = merge(CitizenDoubles.INSPECT_ONLY, PetitionDoubles.REMOTES),   -- or leave REMOTES out: dark
			services = { CitizenDoubles.inspectOnly, PetitionDoubles.service(PetitionDoubles.KEYS) },
			clientDefinitions = { KingdomHudDef, CitizenCardDef },
		})
		local petitions = world.server:get("PetitionService")
		petitions.calls        { { petitionId } }
		petitions.refuse = "expired"   the next call answers (false, reason)
		petitions.latency = 0.3        seconds a call takes
		petitions.drop = true          the next call returns nil (a dropped call)

	Double rules (not the game's): only the caller's kingdom's citizens; an unknown id → "unknown_petition"; past
	`expiresAt` → "expired"; the need is spent through the real TreasuryService ("insufficient"); a fulfilled petition
	is cleared and the citizen gains LOYALTY_GAIN loyalty. Sample petitions are config Support.roles texts.
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local PetitionDoubles = {}

PetitionDoubles.REMOTES = {
	Kingdom = {
		{
			name = "Kingdom.FulfilPetition",
			kind = "function",
			args = { V.string(1, 32) },
			rate = { burst = 4, perSecond = 2 },
		},
	},
}

PetitionDoubles.LOYALTY_GAIN = 6

-- entityId → key-citizen fields. 41 Edda (72): a blacksmith below 80 with a stone petition; 43 Lise (88): a pledged
-- healer; 42 Bran (60): a captain with a petition the treasury can't cover; 44 Osric: no role.
PetitionDoubles.KEYS = {
	[41] = {
		role = "blacksmith",
		petition = { id = "p-41", text = Support.roles.blacksmith.petition, need = { stone = 20 }, expiresIn = 240 },
	},
	[43] = { role = "healer" },
	[42] = {
		role = "captain",
		petition = { id = "p-42", text = Support.roles.captain.petition, need = { gold = 500 }, expiresIn = 50 },
	},
}

function PetitionDoubles.service(keys: { [number]: any }?, opts: { remote: boolean? }?)
	local declared = not (opts and opts.remote == false)
	return function(world)
		return {
			name = "PetitionService",
			dependencies = { "RemoteService", "TreasuryService", "KingdomService", "CitizenService" },
			new = function(_, registry)
				local remotes = registry:get("RemoteService")
				local treasury = registry:get("TreasuryService")
				local kingdoms = registry:get("KingdomService")
				local citizens = registry:get("CitizenService")
				local svc = { calls = {}, refuse = nil :: string?, latency = 0, drop = false }
				local now = world.env.serverTimeNow()
				for entityId, k in keys or {} do
					local c = citizens.citizens[entityId]
					if c then
						c.role = k.role
						if k.loyalty then
							c.loyalty = k.loyalty
						end
						if k.petition then
							local p = k.petition
							c.petition =
								{ id = p.id, text = p.text, need = p.need, expiresAt = now + (p.expiresIn or 300) }
						end
					end
				end

				function svc:start()
					if not declared then
						return -- dark: the inspect fields only, no remote (PetitionDoubles.service(keys, { remote = false }))
					end
					remotes:handle("Kingdom.FulfilPetition", function(player, petitionId)
						table.insert(self.calls, { petitionId = petitionId })
						if self.latency > 0 then
							world.env.wait(self.latency)
						end
						if self.drop then
							self.drop = false
							return nil
						end
						if self.refuse then
							local reason = self.refuse
							self.refuse = nil
							return false, reason
						end
						local found = nil
						for _, c in citizens.citizens do
							if c.petition and c.petition.id == petitionId then
								found = c
							end
						end
						if found == nil then
							return false, "unknown_petition"
						end
						local kingdom = kingdoms:getKingdomOf(player)
						if found.kingdom ~= kingdom then
							return false, "not_yours"
						end
						if world.env.serverTimeNow() >= found.petition.expiresAt then
							return false, "expired"
						end
						local need = found.petition.need
						if
							need
							and next(need)
							and not treasury:spend(kingdom, need, "petition:" .. petitionId, "decision")
						then
							return false, "insufficient"
						end
						found.petition = nil
						found.loyalty = math.clamp(found.loyalty + PetitionDoubles.LOYALTY_GAIN, 0, 100)
						return true
					end)
				end
				return svc
			end,
		}
	end
end

return PetitionDoubles
