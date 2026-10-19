--[[
	VoteDoubles — the co-rulers' champion vote for FL-0142's specs and scenes, as FORGE-01's ArenaFlow:vote and the
	proposed ArenaState.vote field describe it (handoff 2026-10-19-forge-03-to-forge-01-arena-vote).

		VoteDoubles.REMOTES       ArenaDoubles.REMOTES plus Arena.Vote(candidateUserId: integer) -> boolean
		VoteDoubles.service       (world) -> server Def "VoteDouble" (needs ArenaDoubles.service's "ArenaDouble"):
			svc.calls                    { { userId, candidate } } every Arena.Vote that reached the server
			svc.answer                   nil = the rules below; true / false = that answer; "drop" = no answer (nil)
			svc:open(kingdom, candidates, endsAt, side?)   the vote stage with one voting kingdom (side "a")
			Arena.Vote rules (ArenaFlow:vote): vote stage only; the sender is a candidate, the candidate one of the
			same side; the latest vote counts; an accepted vote adds the sender to `voted` and pushes Arena.State
		VoteDoubles.state(kingdom, candidates, endsAt, voted?, side?) -> ArenaState in the vote stage
]]

local ArenaDoubles = require("./ArenaDoubles")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local VoteDoubles = {}

local arena = table.clone(ArenaDoubles.REMOTES.Arena)
table.insert(arena, { name = "Arena.Vote", kind = "function", args = { Validate.integer(1, 9007199254740991) } })
VoteDoubles.REMOTES = { Arena = arena, Kingdom = ArenaDoubles.REMOTES.Kingdom }

function VoteDoubles.state(kingdom, candidates, endsAt, voted, side)
	return {
		stage = "vote",
		endsAt = endsAt,
		vote = { [side or "a"] = { kingdom = kingdom, candidates = candidates, voted = voted or {} } },
	}
end

local function contains(list, value)
	for _, v in list or {} do
		if v == value then
			return true
		end
	end
	return false
end

function VoteDoubles.service(_world)
	return {
		name = "VoteDouble",
		dependencies = { "RemoteService", "ArenaDouble" },
		new = function(_env, registry)
			local remotes = registry:get("RemoteService")
			local arenaDouble = registry:get("ArenaDouble")
			local svc = { calls = {}, votes = {}, answer = nil }
			function svc:open(kingdom, candidates, endsAt, side)
				self.votes = {}
				arenaDouble:setState(VoteDoubles.state(kingdom, candidates, endsAt, {}, side))
			end
			function svc:start()
				remotes:handle("Arena.Vote", function(player, candidate)
					table.insert(self.calls, { userId = player.UserId, candidate = candidate })
					if self.answer == "drop" then
						return nil
					elseif self.answer ~= nil then
						return self.answer
					end
					local st = arenaDouble.state
					if st.stage ~= "vote" or type(st.vote) ~= "table" then
						return false
					end
					for _, entry in st.vote do
						if contains(entry.candidates, player.UserId) then
							if not contains(entry.candidates, candidate) then
								return false
							end
							self.votes[player.UserId] = candidate
							if not contains(entry.voted, player.UserId) then
								table.insert(entry.voted, player.UserId)
							end
							arenaDouble:setState(st)
							return true
						end
					end
					return false
				end)
			end
			return svc
		end,
	}
end

return VoteDoubles
