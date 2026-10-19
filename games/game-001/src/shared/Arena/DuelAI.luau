--!strict
--[[
	Arena/DuelAI — the AI champion's hands (design §2: an AI kingdom that qualifies fields an AI champion whose skill
	follows the governor difficulty, BRIEF §16.3). Owner: FORGE-01. Pure and deterministic: its only randomness is a
	seeded generator, its only clock is the duel time in the snapshots it is shown.

		DuelAI.new(side: "a" | "b", skill: number, seed: number, config?) -> AI
			skill 0..1 (clamped): reaction time 0.30 s at 0 down to 0.12 s at 1, the chance to see and answer a
			telegraphed heavy 35 % up to 90 %, parry rather than block or dodge more often, fewer wasted swings
		AI:observe(events: { DuelEvent })     the duel's events since the last call (an AI sees a telegraph, like a player)
		AI:decide(snapshot) -> DuelAction?        the one action to send now, or nil; `snapshot` = DuelModel.snapshot(state)

	The AI plays the way a careful player does and sends only what a client could send: light, heavy, block, blockEnd,
	parry, dodge. It reads what the HUD shows (both HP and stamina, who is winding up), never the other side's reserve
	triggers or the RNG. It never acts while it cannot (DuelModel ignores that anyway) and never sends an action faster
	than its reaction time.
]]

local Duel = require("@game/ReplicatedStorage/Forge/Config/Duel")
local Types = require("./Types")

type DuelAction = Types.DuelAction
type DuelEvent = Types.DuelEvent

local DuelAI = {}
DuelAI.__index = DuelAI

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- A small seeded generator (Park-Miller): the same seed gives the same AI.
local function nextRandom(self: any): number
	self._rng = (self._rng * 48271) % 2147483647
	return self._rng / 2147483647
end

function DuelAI.new(side: string, skill: number, seed: number, config: any?): any
	assert(side == "a" or side == "b", "DuelAI.new: side must be 'a' or 'b'")
	local rules = (config or Duel).rules
	local s = clamp(if type(skill) == "number" and skill == skill then skill else 0.5, 0, 1)
	local self = setmetatable({}, DuelAI)
	self._side = side
	self._other = if side == "a" then "b" else "a"
	self._skill = s
	self._rules = rules
	local seedNumber = if type(seed) == "number" and seed == seed and math.abs(seed) < math.huge then seed else 1
	self._rng = (math.floor(math.abs(seedNumber)) % 2147483646) + 1
	self._armours = (config or Duel).armour
	self._reaction = 0.30 - 0.18 * s
	self._seeAndAnswer = 0.35 + 0.55 * s
	self._parryBias = 0.25 + 0.6 * s
	self._heavyBias = 0.45 - 0.2 * s
	self._nextThink = 0
	self._threats = {} :: { { impactAt: number, handled: boolean, plan: string? } }
	self._plan = nil :: { action: string, at: number }?
	return self
end

function DuelAI:observe(events: { DuelEvent })
	for _, event in events do
		if event.kind == "heavyWindup" and event.side == self._other and event.data then
			local impactAt = event.data.impactAt
			if type(impactAt) == "number" then
				table.insert(self._threats, { impactAt = impactAt, handled = false })
			end
		end
	end
end

-- Which defence answers a heavy that lands at `impactAt`: a parry when it can, else a dodge, else a block.
function DuelAI:_defence(me: any): string
	local rules = self._rules
	if me.stamina >= rules.parryCost and nextRandom(self) < self._parryBias then
		return "parry"
	end
	local armour = self._armours[me.armour]
	local dodgeCost = if armour then armour.dodgeCost else 25
	if me.stamina >= dodgeCost and nextRandom(self) < 0.5 then
		return "dodge"
	end
	return "block"
end

function DuelAI:decide(snapshot: any): DuelAction?
	local now = snapshot.t
	if snapshot.ended then
		return nil
	end
	local me, them = snapshot[self._side], snapshot[self._other]
	local rules = self._rules

	-- a planned defence goes out when its time comes (and only if the hands are free)
	local plan = self._plan
	if plan and now >= plan.at then
		self._plan = nil
		if me.state == "idle" or (me.state == "block" and plan.action ~= "block") then
			return plan.action :: DuelAction
		end
	end

	-- drop threats that have landed
	local live = {}
	for _, threat in self._threats do
		if threat.impactAt > now - 0.5 then
			table.insert(live, threat)
		end
	end
	self._threats = live

	if now < self._nextThink then
		return nil
	end
	self._nextThink = now + self._reaction * (0.8 + 0.4 * nextRandom(self))

	-- 1. a telegraphed heavy: see it (or not), and answer so the defence is up when it lands
	for _, threat in self._threats do
		if not threat.handled then
			threat.handled = true
			if nextRandom(self) < self._seeAndAnswer and threat.impactAt > now then
				local defence = self:_defence(me)
				local lead = if defence == "parry"
					then rules.parryWindow * 0.5
					elseif defence == "dodge" then rules.dodgeTime * 0.4
					else 0.15
				self._plan = { action = defence, at = math.max(now, threat.impactAt - lead) }
				if defence == "block" and me.state == "idle" then
					self._plan = nil
					return "block"
				end
				return nil
			end
		end
	end

	-- 2. holding a block with nothing coming: let it go
	if me.state == "block" then
		local incoming = false
		for _, threat in self._threats do
			incoming = incoming or threat.impactAt > now - 0.1
		end
		if not incoming and them.state ~= "windup" then
			return "blockEnd"
		end
		return nil
	end

	if me.state ~= "idle" then
		return nil
	end

	-- 3. out of breath: guard and recover rather than swing
	if me.stamina < rules.lightCost + 6 then
		return "block"
	end

	-- 4. attack: a heavy when there is breath to spare and the roll says so, else a light
	if me.stamina >= rules.heavyCost + rules.parryCost and nextRandom(self) < self._heavyBias then
		return "heavy"
	end
	-- the opponent is winded and open: press on
	if them.stamina < rules.lightCost and nextRandom(self) < 0.7 then
		return "heavy"
	end
	return "light"
end

return DuelAI
