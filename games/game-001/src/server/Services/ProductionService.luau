--!strict
--[[
	ProductionService (FORGE-03, game-001) — the only food consumer (CONTRACTS G7).

	Every Costs.upkeep.intervalSeconds while the match runs (Founding, Expansion, Conflict,
	Endgame), for each kingdom:
		upkeep = ceil(citizens x Costs.upkeep.citizenFood + soldiers x Costs.unit("soldier").upkeepFood)
		taken  = TreasuryService:spendUpTo(kingdom, "food", upkeep, "upkeep:<kingdom>:<tick>", "upkeep")
		CitizenService:setFedRatio(kingdom, taken / upkeep)       (1 when upkeep is 0)
	Population comes from CitizenService:getPopulation(kingdom) (G5: soldiers are counted in
	byJob.soldier and in total). Citizens never draw food themselves.
	The interval restarts when a match enters Founding, so the first charge lands exactly one
	interval into the match. Each kingdom is charged in its own pcall: an error from
	CitizenService for one kingdom is logged and never stops the others or later ticks.

	Dependencies: TreasuryService (hard). CitizenService and MatchService (FORGE-01) are found in
	start(); without CitizenService there is no population and nothing is charged; without
	MatchService the phase is taken from GameEvents.MatchPhaseChanged only.

	API
		ProductionService:upkeepFor(population) -> number   whole food per interval (spendUpTo takes
		                                                    whole numbers only); pure (specs, HUD hints)
		ProductionService:tick()                            one upkeep pass (the loop calls it)
		ProductionService.lastFed: { [KingdomId]: number }  last fed ratio per kingdom (HUD, analytics)
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")

local ProductionService = {}
ProductionService.__index = ProductionService

ProductionService.RUNNING = table.freeze({ Founding = true, Expansion = true, Conflict = true, Endgame = true })

local Def = { name = "ProductionService", dependencies = { "TreasuryService" } }

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_treasury = registry:get("TreasuryService"),
		_phase = nil :: string?,
		_tick = 0,
		_running = false,
		_generation = 0,
		_connections = {},
		lastFed = {} :: { [string]: number },
	}, ProductionService)
end

function ProductionService:start()
	self._citizens = self._registry:find("CitizenService")
	self._match = self._registry:find("MatchService")
	if self._match and self._match.getPhase then
		self._phase = self._match:getPhase()
	end
	table.insert(
		self._connections,
		GameEvents.MatchPhaseChanged:connect(function(phase)
			self._phase = phase
			if phase == "Founding" then
				self:_startLoop() -- align the first charge to the start of the match
			end
		end)
	)
	self._running = true
	self:_startLoop()
end

-- One loop per generation: starting a new one retires the old at its next wake-up.
function ProductionService:_startLoop()
	self._generation += 1
	local generation = self._generation
	local env = self._env
	env.spawn(function()
		while self._running and self._generation == generation do
			env.wait(Costs.upkeep.intervalSeconds)
			if self._running and self._generation == generation then
				self:tick()
			end
		end
	end)
end

function ProductionService:destroy()
	self._running = false
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
end

function ProductionService:upkeepFor(population: { total: number, byJob: { [string]: number }? }): number
	local soldiers = if population.byJob then population.byJob.soldier or 0 else 0
	local citizens = math.max(0, (population.total or 0) - soldiers)
	local soldier = Costs.unit("soldier")
	local perSoldier = if soldier then soldier.upkeepFood else 0
	return math.ceil(citizens * Costs.upkeep.citizenFood + soldiers * perSoldier)
end

function ProductionService:_charge(citizens: any, kingdom: string)
	local population = citizens:getPopulation(kingdom)
	if population then
		local upkeep = self:upkeepFor(population)
		local ratio = 1
		if upkeep > 0 then
			local taken = self._treasury:spendUpTo(kingdom, "food", upkeep, `upkeep:{kingdom}:{self._tick}`, "upkeep")
			ratio = taken / upkeep
		end
		self.lastFed[kingdom] = ratio
		citizens:setFedRatio(kingdom, ratio)
	end
end

function ProductionService:tick()
	if self._phase == nil or not ProductionService.RUNNING[self._phase] then
		return
	end
	local citizens = self._citizens
	if citizens == nil then
		return
	end
	self._tick += 1
	for _, kingdom in self._treasury.KINGDOMS or { "crimson", "azure", "emerald", "gold" } do
		local ok, err = pcall(self._charge, self, citizens, kingdom)
		if not ok then
			self._env.log("error", "ProductionService: upkeep failed for a kingdom", {
				kingdom = kingdom,
				error = tostring(err),
			})
		end
	end
end

return Def
