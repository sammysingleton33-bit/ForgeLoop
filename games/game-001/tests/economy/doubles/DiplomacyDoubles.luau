--[[
	DiplomacyDoubles — the war and peace server as FL-0129's Rivals tab expects it (proposed to FORGE-01
	for the full match, Operation Crownfall): `Kingdom.Diplomacy(action, target) -> (ok, reason?)` and the
	`diplomacy` payload on Kingdom.State. The rules and codes follow Sim/Diplomacy (grace_period,
	already_at_war, peace_cooldown, not_at_war, no_proposal, unknown_kingdom); times are server time.

		DiplomacyDoubles.remotes(base?) -> remotes with Kingdom.Diplomacy added
		DiplomacyDoubles.service(world) a server definition ("DiplomacyService") over KingdomWorld's
		                                KingdomService: svc:setWar(a, b), svc:propose(from, to),
		                                svc:setGrace(seconds), svc.refuse = code (answer it once), svc.calls;
		                                D-054: svc:setSenior(userId) (others ask: svc.asks), svc:lock(seconds)
		DiplomacyDoubles.PROPOSAL_SEC, DiplomacyDoubles.TRUCE_SEC   60 and 120, as Sim/Diplomacy
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local DiplomacyDoubles = {}

DiplomacyDoubles.PROPOSAL_SEC = 60
DiplomacyDoubles.TRUCE_SEC = 120
DiplomacyDoubles.ASK_SEC = 60 -- an open ask for war lasts this long (FORGE-01, config)
DiplomacyDoubles.DECLARATION = {
	name = "Kingdom.Diplomacy",
	kind = "function",
	args = {
		Validate.enum({ "declareWar", "proposePeace", "acceptPeace" }),
		Validate.string(1, 16),
	},
	rate = { burst = 3, perSecond = 1 },
}

DiplomacyDoubles.WAR_ASK = { name = "Kingdom.WarAsk", kind = "serverEvent" }

function DiplomacyDoubles.remotes(base: { [string]: any }?): { [string]: any }
	local out = {}
	for area, decls in base or {} do
		out[area] = table.clone(decls)
	end
	out.Kingdom = out.Kingdom or {}
	table.insert(out.Kingdom, DiplomacyDoubles.DECLARATION)
	table.insert(out.Kingdom, DiplomacyDoubles.WAR_ASK)
	return out
end

local function samePair(entry, a, b)
	return (entry.a == a and entry.b == b) or (entry.a == b and entry.b == a)
end

function DiplomacyDoubles.service(_world)
	return DiplomacyDoubles.def
end

-- The final contract (FORGE-01, 2026-10-18): `seniors = { [KingdomId] = UserId? }`, `lockedUntil` for
-- the receiving player, and `Kingdom.WarAsk(requesterUserId, requesterName, target)` to the senior ruler.
local function playerOf(env, userId)
	for _, p in env.Players:GetPlayers() do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

DiplomacyDoubles.def = {
	name = "DiplomacyService",
	dependencies = { "RemoteService", "KingdomService" },
	new = function(env, registry)
		local remotes = registry:get("RemoteService")
		local kingdoms = registry:get("KingdomService")
		local svc = {
			state = { relations = {}, proposals = {}, cooldowns = {}, graceEndsAt = nil, seniors = {}, asks = {} },
			calls = {},
			asks = {},
			refuse = nil :: string?,
		}
		local function now()
			return env.serverTimeNow()
		end
		local function publish()
			kingdoms.diplomacy = svc.state
			kingdoms:publish()
		end
		local function relation(a, b)
			for _, r in svc.state.relations do
				if samePair(r, a, b) then
					return r.relation
				end
			end
			return "Peace"
		end
		local function setRelation(a, b, rel)
			for _, r in svc.state.relations do
				if samePair(r, a, b) then
					r.relation = rel
					return
				end
			end
			table.insert(svc.state.relations, { a = a, b = b, relation = rel })
		end
		local function clearProposals(a, b)
			for i = #svc.state.proposals, 1, -1 do
				local p = svc.state.proposals[i]
				if samePair({ a = p.from, b = p.to }, a, b) then
					table.remove(svc.state.proposals, i)
				end
			end
		end
		function svc:setWar(a, b)
			setRelation(a, b, "War")
			publish()
		end
		function svc:propose(from, to)
			table.insert(
				self.state.proposals,
				{ from = from, to = to, expiresAt = now() + DiplomacyDoubles.PROPOSAL_SEC }
			)
			publish()
		end
		function svc:setGrace(seconds)
			self.state.graceEndsAt = now() + seconds
			publish()
		end
		function svc:setSenior(userId, kingdomId)
			self.state.seniors[kingdomId or "crimson"] = userId
			publish()
		end
		-- a co-ruler asks the senior ruler (userId) for war on target: the server's notice to them
		-- (and, as FORGE-01's PR 2, the open ask in state: asks = { { from, fromName, target, expiresAt } })
		function svc:askFrom(fromUserId, fromName, target, seniorUserId)
			table.insert(self.state.asks, {
				from = fromUserId,
				fromName = fromName,
				target = target,
				expiresAt = now() + DiplomacyDoubles.ASK_SEC,
			})
			publish()
			local senior = playerOf(env, seniorUserId)
			if senior then
				remotes:fire("Kingdom.WarAsk", senior, fromUserId, fromName, target)
			end
		end
		function svc:lock(seconds)
			self.state.lockedUntil = now() + seconds
			publish()
		end
		function svc:start()
			publish()
			remotes:handle("Kingdom.Diplomacy", function(player, action, target)
				table.insert(svc.calls, { action = action, target = target })
				if svc.refuse then
					local code = svc.refuse
					svc.refuse = nil
					return false, code
				end
				local mine = kingdoms:getKingdomOf(player)
				local other = kingdoms:getKingdom(target)
				if mine == nil or other == nil or other.alive == false or target == mine then
					return false, "unknown_kingdom"
				end
				local t = now()
				-- D-054: newcomer lock on war and accepting peace; only the senior ruler decides
				if action ~= "proposePeace" and svc.state.lockedUntil and t < svc.state.lockedUntil then
					return false, "newcomer_lock"
				end
				local senior = svc.state.seniors[mine]
				if senior ~= nil and player.UserId ~= senior then
					if action == "acceptPeace" then
						return false, "not_senior"
					elseif action == "declareWar" then
						table.insert(svc.asks, { from = player.UserId, target = target })
						table.insert(svc.state.asks, {
							from = player.UserId,
							fromName = player.Name,
							target = target,
							expiresAt = t + DiplomacyDoubles.ASK_SEC,
						})
						publish()
						local to = playerOf(env, senior)
						if to then
							remotes:fire("Kingdom.WarAsk", to, player.UserId, player.Name, target)
						end
						return true, "asked" -- the ask goes to the senior ruler as a server notice
					end
				end
				if action == "declareWar" then
					if svc.state.graceEndsAt and t < svc.state.graceEndsAt then
						return false, "grace_period"
					end
					if relation(mine, target) == "War" then
						return false, "already_at_war"
					end
					for _, c in svc.state.cooldowns do
						if samePair(c, mine, target) and c.untilAt > t then
							return false, "peace_cooldown"
						end
					end
					setRelation(mine, target, "War")
				elseif action == "proposePeace" then
					if relation(mine, target) ~= "War" then
						return false, "not_at_war"
					end
					table.insert(svc.state.proposals, {
						from = mine,
						to = target,
						expiresAt = t + DiplomacyDoubles.PROPOSAL_SEC,
					})
				else -- acceptPeace
					local found = false
					for _, p in svc.state.proposals do
						if p.from == target and p.to == mine and p.expiresAt > t then
							found = true
						end
					end
					if not found then
						return false, "no_proposal"
					end
					setRelation(mine, target, "Peace")
					clearProposals(mine, target)
					table.insert(
						svc.state.cooldowns,
						{ a = mine, b = target, untilAt = t + DiplomacyDoubles.TRUCE_SEC }
					)
				end
				publish()
				return true, if action == "declareWar" then "declared" else nil
			end)
		end
		return svc
	end,
}

return DiplomacyDoubles
