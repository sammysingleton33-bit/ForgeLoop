--!strict
--[[
	MilitaryService — recruiting soldiers and commanding them (CONTRACTS G8, Army area; FL-0052).
	Owner: FORGE-01.

	Soldiers are simulation entities (Sim/Military in MatchService's host); EntityService replicates
	them like citizens. This service is the server API and the Army.Recruit / Army.Command remotes; both
	go through the host's command path (host:command -> Sim/Commands), so the simulation stays the
	authority on ownership, cost and limits.
	API (G8)
		MilitaryService:recruit(player, barracksId, unitType, count): (boolean, reason?)
			-- trains at that barracks, charged Costs.unit × count through the treasury (TreasuryService:spend
			   via the simulation); the soldiers appear at the barracks' Rally when trained
		MilitaryService:command(player, unitIds, order: { kind, targetPos: Vector3?, targetId: string? })
			: (boolean, reason?)  -- kind "move" | "attack" | "capture" | "guard"; unitIds = {} means every
			   idle soldier of the player's kingdom; ids that are not the kingdom's living soldiers are
			   ignored (Sim/Military UnitOrder)
	Remotes (Army/Remotes.luau): Army.Recruit (function) and Army.Command (event, no answer).
	Reasons: those of Sim/Military Recruit and UnitOrder, plus not_in_match (spectators and players
	without a kingdom), match_not_active and kingdom_eliminated.
	Events: G9 UnitsRecruited (player, KingdomId, count) is fired once per successful recruit by the
	host's event fan-out (Kingdom/MatchHost, on the simulation's RecruitQueued).
]]

local MilitaryService = {}
MilitaryService.__index = MilitaryService

local Def = { name = "MilitaryService", dependencies = { "MatchService", "RemoteService" } }

function Def.new(env: any, registry: any)
	local self = setmetatable({}, MilitaryService)
	self._env = env
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	return self
end

function MilitaryService:start()
	self._remotes:handle(
		"Army.Recruit",
		function(player: any, barracksId: number, unitType: string, count: number): (boolean, string?)
			return self:recruit(player, barracksId, unitType, count)
		end
	)
	self._remotes:handle(
		"Army.Command",
		function(player: any, unitIds: { number }, kind: string, targetPos: Vector3?, targetId: string?)
			self:command(player, unitIds, { kind = kind, targetPos = targetPos, targetId = targetId })
		end
	)
end

function MilitaryService:recruit(player: any, barracksId: number, unitType: string, count: number): (boolean, string?)
	local ok, err = self._match.host:command(player, "Recruit", unitType, count, barracksId)
	return ok, err
end

function MilitaryService:command(
	player: any,
	unitIds: { number },
	order: { kind: string, targetPos: Vector3?, targetId: string? }
): (boolean, string?)
	if type(order) ~= "table" then
		return false, "invalid_args"
	end
	local x, z = nil, nil
	if typeof(order.targetPos) == "Vector3" then
		local position = order.targetPos :: Vector3
		x, z = position.X, position.Z
	elseif order.targetPos ~= nil then
		return false, "invalid_args"
	end
	local ok, err = self._match.host:command(player, "UnitOrder", unitIds, order.kind, x, z, order.targetId)
	return ok, err
end

function MilitaryService:destroy() end

return Def
