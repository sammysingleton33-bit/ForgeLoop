--!strict
--[[
	Sim/Diplomacy — war and peace between kingdoms.

	Every pair of kingdoms starts at "Peace". Combat only happens between kingdoms at "War"
	(Simulation:atWar). Rules (tunable through install options):
		- No war declarations during the grace period at the start of the match (default 300 s), so
		  every kingdom gets time to build up.
		- DeclareWar takes effect immediately and is announced to everyone (WarDeclared event).
		- Peace needs both sides: one proposes, the other accepts within proposalSeconds (60 s).
		- After peace, the same pair cannot go back to war for peaceCooldown seconds (120 s).
	Any ruler of a kingdom may use these commands (shared ownership; events record who did it).
		- DeclareWar and AcceptPeace set kingdom.moveLockedUntil on both sides (Buildings.moveLockout seconds
		  of sim time): the kingdoms' buildings can't be moved meanwhile (Simulation:_checkMove).

	API
		Diplomacy.install(sim, options?)  -- options: { graceSeconds?, proposalSeconds?, peaceCooldown? }
		Diplomacy.relation(sim, a, b): "Peace" | "War"
		Diplomacy.setRelation(sim, a, b, relation)   -- direct (tests, scenario setup); emits nothing
	Commands
		DeclareWar(kingdomId)    errors: invalid_args, unknown_kingdom, grace_period, already_at_war, peace_cooldown
		ProposePeace(kingdomId)  errors: invalid_args, unknown_kingdom, not_at_war
		AcceptPeace(kingdomId)   errors: invalid_args, unknown_kingdom, no_proposal
	Events
		WarDeclared { kingdomId, targetId, by } · PeaceProposed { kingdomId, targetId, by }
		PeaceMade { kingdomId, targetId, by }   (kingdomId accepted targetId's proposal)
]]

local Commands = require("./Commands")

local Diplomacy = {}

local DEFAULTS = { graceSeconds = 300, proposalSeconds = 60, peaceCooldown = 120 }

local function otherKingdom(sim: any, kingdom: any, id: any): (any?, string?)
	if type(id) ~= "string" or #id > 16 then
		return nil, "invalid_args"
	end
	local other = sim.kingdoms[id]
	if other == nil or not other.alive or other.id == kingdom.id then
		return nil, "unknown_kingdom"
	end
	return other, nil
end

-- A war declaration or a peace freezes base editing for both kingdoms for config Buildings.moveLockout seconds
-- (CONTRACTS G13.9 v0.4-g9j): no sliding walls and towers around at the moment a war starts or ends.
local function lockMoves(sim: any, a: any, b: any)
	local until_ = sim.time + sim.catalog.tuning.moveLockout
	a.moveLockedUntil, b.moveLockedUntil = until_, until_
end

function Diplomacy.relation(sim: any, a: string, b: string): string
	return sim.relations[sim:relationKey(a, b)] or "Peace"
end

function Diplomacy.setRelation(sim: any, a: string, b: string, relation: string)
	assert(relation == "Peace" or relation == "War", "setRelation: Peace or War")
	sim.relations[sim:relationKey(a, b)] = relation
end

function Diplomacy.install(sim: any, options: { [string]: number }?)
	assert(sim.diplomacy == nil, "Diplomacy.install: already installed")
	local opts = options or {}
	local state = {
		graceSeconds = opts.graceSeconds or DEFAULTS.graceSeconds,
		proposalSeconds = opts.proposalSeconds or DEFAULTS.proposalSeconds,
		peaceCooldown = opts.peaceCooldown or DEFAULTS.peaceCooldown,
		proposals = {} :: { [string]: number }, -- "from>to" -> time proposed
		peaceAt = {} :: { [string]: number }, -- pair key -> time peace was made
	}
	sim.diplomacy = state

	Commands.install(sim, "DeclareWar", function(s, kingdom, by, targetId)
		local target, err = otherKingdom(s, kingdom, targetId)
		if target == nil then
			return false, err
		end
		if s.time < state.graceSeconds then
			return false, "grace_period"
		end
		local key = s:relationKey(kingdom.id, target.id)
		if s.relations[key] == "War" then
			return false, "already_at_war"
		end
		local madePeace = state.peaceAt[key]
		if madePeace and s.time - madePeace < state.peaceCooldown then
			return false, "peace_cooldown"
		end
		s.relations[key] = "War"
		state.proposals[kingdom.id .. ">" .. target.id] = nil
		state.proposals[target.id .. ">" .. kingdom.id] = nil
		lockMoves(s, kingdom, target)
		s:emit("WarDeclared", { kingdomId = kingdom.id, targetId = target.id, by = by })
		return true, nil, { targetId = target.id }
	end)

	Commands.install(sim, "ProposePeace", function(s, kingdom, by, targetId)
		local target, err = otherKingdom(s, kingdom, targetId)
		if target == nil then
			return false, err
		end
		if not s:atWar(kingdom.id, target.id) then
			return false, "not_at_war"
		end
		state.proposals[kingdom.id .. ">" .. target.id] = s.time
		s:emit("PeaceProposed", { kingdomId = kingdom.id, targetId = target.id, by = by })
		return true, nil, { targetId = target.id }
	end)

	Commands.install(sim, "AcceptPeace", function(s, kingdom, by, fromId)
		local from, err = otherKingdom(s, kingdom, fromId)
		if from == nil then
			return false, err
		end
		local proposalKey = from.id .. ">" .. kingdom.id
		local proposedAt = state.proposals[proposalKey]
		if proposedAt == nil or s.time - proposedAt > state.proposalSeconds or not s:atWar(kingdom.id, from.id) then
			state.proposals[proposalKey] = nil
			return false, "no_proposal"
		end
		local key = s:relationKey(kingdom.id, from.id)
		s.relations[key] = "Peace"
		state.proposals[proposalKey] = nil
		state.peaceAt[key] = s.time
		-- armies attacking the new friend stand down
		for _, side in { kingdom, from } do
			for _, uid in side.unitIds do
				local u = s.units[uid]
				if u.order.kind == "Attack" and (u.order.kingdomId == kingdom.id or u.order.kingdomId == from.id) then
					u.order = { kind = "Defend" }
				end
				u.target = nil
			end
		end
		lockMoves(s, kingdom, from)
		s:emit("PeaceMade", { kingdomId = kingdom.id, targetId = from.id, by = by })
		return true, nil, { targetId = from.id }
	end)
end

return Diplomacy
