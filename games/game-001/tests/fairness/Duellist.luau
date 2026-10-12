--!strict
--[[
	Duellist — scripted duellists for the fairness harness (FL-0076, FORGE-05; design §9).

		Duellist.SKILLS[tier] = { accuracy, parry, guard, tempo }    tiers: novice < average < expert
		Duellist.TIERS = { "novice", "average", "expert" }
		Duellist.new(skill: string, seed: number) -> policy
		policy:act(view, events: { DuelEvent }) -> DuelInput?

	One tier better is +15 points of hit and parry accuracy (design §6: "about +15 % hit and parry
	accuracy"). A duellist sees what a player sees: its own view (DuelDouble.view) and the duel's
	events. It reacts to a telegraphed heavy (heavyWindup) by parrying, blocking or taking the hit,
	and a Called Warning (data.warned, seconds of extra notice) raises its parry chance. Every roll
	comes from its own seeded generator, so a duel is reproducible from its seed.
]]

local Duellist = {}

Duellist.TIERS = table.freeze({ "novice", "average", "expert" })
Duellist.SKILLS = table.freeze({
	novice = table.freeze({ accuracy = 0.55, parry = 0.30, guard = 0.40, tempo = 0.80 }),
	average = table.freeze({ accuracy = 0.70, parry = 0.45, guard = 0.50, tempo = 0.65 }),
	expert = table.freeze({ accuracy = 0.85, parry = 0.60, guard = 0.60, tempo = 0.55 }),
})

local WARNING_PARRY_PER_SECOND = 0.6 -- 0.25 s of extra notice -> +15 points of parry chance
local HEAVY_COST, LIGHT_COST = 22, 10

-- Park-Miller minimal standard generator: exact in doubles, identical on every Luau runtime.
local MODULUS = 2147483647
local function newRng(seed: number): () -> number
	local value = (math.floor(math.abs(seed)) % (MODULUS - 1)) + 1
	return function(): number
		value = (value * 48271) % MODULUS
		return value / MODULUS
	end
end
Duellist.newRng = newRng

local Policy = {}
Policy.__index = Policy

function Duellist.new(skill: string, seed: number): any
	local stats = Duellist.SKILLS[skill]
	assert(stats, `Duellist: unknown skill tier '{tostring(skill)}'`)
	return setmetatable({
		skill = skill,
		stats = stats,
		rng = newRng(seed),
		side = nil :: string?,
		plan = {} :: { { at: number, action: string } },
		reactingUntil = -math.huge,
		nextDecision = 0,
	}, Policy)
end

function Policy:_schedule(at: number, action: string)
	table.insert(self.plan, { at = at, action = action })
	table.sort(self.plan, function(x, y)
		return x.at < y.at
	end)
end

function Policy:_react(event: any)
	local data = event.data or {}
	local impactAt = data.impactAt or event.t
	local warned = data.warned or 0
	local parryChance = math.min(0.95, self.stats.parry + warned * WARNING_PARRY_PER_SECOND)
	local roll = self.rng()
	table.clear(self.plan)
	self.reactingUntil = impactAt + 0.1
	if roll < parryChance then
		self:_schedule(math.max(event.t, impactAt - 0.12), "parry")
	elseif roll < parryChance + (1 - parryChance) * self.stats.guard then
		self:_schedule(math.max(event.t, impactAt - 0.3), "block")
		self:_schedule(impactAt + 0.05, "blockEnd")
	end
end

-- side: "a" or "b" (set by the harness); view: DuelDouble.view(state, side).
function Policy:act(view: any, events: { any }): any
	for _, event in events do
		if event.kind == "heavyWindup" and event.side ~= self.side then
			self:_react(event)
		end
	end
	local t = view.t
	local nextPlanned = self.plan[1]
	if nextPlanned and nextPlanned.at <= t + 1e-9 then
		table.remove(self.plan, 1)
		return { action = nextPlanned.action, inRange = true, facing = true }
	end
	if view.blocking and nextPlanned == nil then
		return { action = "blockEnd", inRange = true, facing = true }
	end
	if not view.canAct or t < self.nextDecision or t < self.reactingUntil or nextPlanned then
		return nil
	end
	local stats = self.stats
	self.nextDecision = t + stats.tempo * (0.6 + 0.8 * self.rng())
	if view.stamina < 25 then
		return nil -- recover stamina
	end
	if self.rng() < stats.guard * 0.3 then
		self:_schedule(t + 0.5, "blockEnd")
		return { action = "block", inRange = true, facing = true }
	end
	local heavy = view.stamina >= HEAVY_COST and self.rng() < 0.35
	if not heavy and view.stamina < LIGHT_COST then
		return nil
	end
	return { action = if heavy then "heavy" else "light", inRange = self.rng() < stats.accuracy, facing = true }
end

return Duellist
