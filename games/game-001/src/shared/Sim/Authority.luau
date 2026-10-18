--!strict
--[[
	Sim/Authority — who among a kingdom's co-rulers may decide war and peace (D-054, FL-0125).

	Co-rulers share everything (building, upgrading, recruiting, quotas, conversations, the treasury); only these
	differ, and the rules live in the simulation so every route honours them (Commands.executeFor calls gate):
		- The SENIOR ruler is the human seated longest who is still present and active. Only the senior ruler
		  can DeclareWar or AcceptPeace; any ruler may ProposePeace. A senior ruler with no command or input for
		  config Match.rulers.idleSeniorSeconds (90 s) loses seniority to the next present, active ruler until
		  they act again; a lone ruler (or every ruler idle) keeps it. Leaving and coming back makes a ruler the
		  newest.
		- A non-senior ruler's DeclareWar is an ASK: after the same validation, the senior ruler gets a server
		  notice (WarAsked) and the ask stays open for askSeconds (60 s), at most maxAsks (3) per kingdom, one per
		  requester and target, and a requester's new asks are spaced askCooldownSeconds (30 s) apart.
		- The NEWCOMER LOCK: a ruler seated after Founding began (sim.active and sim.time > 0) cannot DeclareWar,
		  AcceptPeace or MoveBuilding for newcomerLockSeconds (120 s) of simulation time. Rulers seated in the
		  Lobby, or before the first tick, are exempt; so is every re-seating into a fresh world; AI governors
		  (by == nil) are exempt from all of it.
	Time is simulation time (it only runs in the active phases). Seats are in memory only.

	API
		Authority.seated(sim, userId)           -- Simulation:addRuler calls it
		Authority.left(sim, userId)             -- Simulation:removeRuler calls it (drops their open asks)
		Authority.touch(sim, userId)            -- the ruler did something (a command, gathering, a conversation, moved)
		Authority.seniorOf(sim, kingdom): number?
		Authority.lockedUntil(sim, userId): number?     -- sim time the newcomer lock ends, while it holds
		Authority.gate(sim, kingdom, by, name): string?  -- "newcomer_lock" | "not_senior" | "ask" | nil (allowed)
		Authority.ask(sim, kingdom, by, targetId): (boolean, string?, any?)   -- a non-senior's DeclareWar
		Authority.asks(sim, kingdomId): { { from, target, expiresAt } }       -- open asks (sim time), pruned
		Authority.clearAsks(sim, kingdomId, targetId?)
	Events: WarAsked { kingdomId, requester, target, seniorId }
]]

local Authority = {}

local DEFAULTS = {
	newcomerLockSeconds = 120,
	idleSeniorSeconds = 90,
	askSeconds = 60,
	askCooldownSeconds = 30,
	maxAsks = 3,
}

local function settings(sim: any): { [string]: number }
	return sim.catalog.tuning.rulers or DEFAULTS
end

local function setting(sim: any, key: string): number
	local rulers = settings(sim)
	local value = rulers[key]
	return if type(value) == "number" then value else DEFAULTS[key]
end

local function seats(sim: any): { [number]: any }
	local s = sim.seats
	if s == nil then
		s = {}
		sim.seats = s
		sim.seatSeq = 0
	end
	return s
end

function Authority.seated(sim: any, userId: number)
	local all = seats(sim)
	sim.seatSeq += 1
	all[userId] = {
		order = sim.seatSeq, -- the longer seated, the smaller; same-tick joiners keep their join order
		at = sim.time,
		late = sim.active == true and sim.time > 0, -- seated after Founding began: the newcomer lock applies
		lastActive = sim.time,
	}
end

function Authority.left(sim: any, userId: number)
	if sim.seats then
		sim.seats[userId] = nil
	end
	for _, list in sim.warAsks or {} do
		for i = #list, 1, -1 do
			if list[i].from == userId then
				table.remove(list, i)
			end
		end
	end
end

function Authority.touch(sim: any, userId: number)
	local seat = if sim.seats then sim.seats[userId] else nil
	if seat then
		seat.lastActive = sim.time
	end
end

local function idle(sim: any, seat: any): boolean
	return sim.time - seat.lastActive >= setting(sim, "idleSeniorSeconds")
end

-- The longest-seated present ruler who is active; if none is active, the longest-seated present ruler.
function Authority.seniorOf(sim: any, kingdom: any): number?
	local all = seats(sim)
	local first, firstActive = nil, nil
	for _, userId in kingdom.rulers do
		local seat = all[userId]
		if seat then
			if first == nil or seat.order < all[first].order then
				first = userId
			end
			if not idle(sim, seat) and (firstActive == nil or seat.order < all[firstActive].order) then
				firstActive = userId
			end
		end
	end
	return firstActive or first
end

function Authority.lockedUntil(sim: any, userId: number): number?
	local seat = if sim.seats then sim.seats[userId] else nil
	if seat == nil or not seat.late then
		return nil
	end
	local untilT = seat.at + setting(sim, "newcomerLockSeconds")
	return if sim.time < untilT then untilT else nil
end

function Authority.gate(sim: any, kingdom: any, by: number?, name: string): string?
	if by == nil then
		return nil -- AI governors
	end
	if name == "DeclareWar" or name == "AcceptPeace" then
		if Authority.lockedUntil(sim, by) ~= nil then
			return "newcomer_lock"
		end
		if Authority.seniorOf(sim, kingdom) ~= by then
			return if name == "DeclareWar" then "ask" else "not_senior"
		end
	elseif name == "MoveBuilding" then
		if Authority.lockedUntil(sim, by) ~= nil then
			return "newcomer_lock"
		end
	end
	return nil
end

function Authority.asks(sim: any, kingdomId: string): { any }
	local list = (sim.warAsks or {})[kingdomId]
	if list == nil then
		return {}
	end
	for i = #list, 1, -1 do
		if sim.time >= list[i].expiresAt then
			table.remove(list, i)
		end
	end
	return list
end

function Authority.clearAsks(sim: any, kingdomId: string, targetId: string?)
	local list = (sim.warAsks or {})[kingdomId]
	if list == nil then
		return
	end
	for i = #list, 1, -1 do
		if targetId == nil or list[i].target == targetId then
			table.remove(list, i)
		end
	end
end

-- A non-senior ruler asks the senior to declare war on `targetId`. The caller has validated the target.
-- Returns (true, nil, { outcome = "asked", targetId, delivered }): `delivered` is false when the ask was a
-- repeat or inside the requester's cooldown (nothing new reaches the senior).
function Authority.ask(sim: any, kingdom: any, by: number, targetId: string): (boolean, string?, any?)
	sim.warAsks = sim.warAsks or {}
	sim.askedAt = sim.askedAt or {}
	local list = Authority.asks(sim, kingdom.id)
	sim.warAsks[kingdom.id] = list
	for _, entry in list do
		if entry.from == by and entry.target == targetId then
			entry.expiresAt = sim.time + setting(sim, "askSeconds") -- the same ask again: refreshed, not repeated
			return true, nil, { outcome = "asked", targetId = targetId, delivered = false }
		end
	end
	local last = sim.askedAt[by]
	if last ~= nil and sim.time - last < setting(sim, "askCooldownSeconds") then
		return true, nil, { outcome = "asked", targetId = targetId, delivered = false }
	end
	if #list >= setting(sim, "maxAsks") then
		table.remove(list, 1) -- the oldest open ask makes room
	end
	sim.askedAt[by] = sim.time
	table.insert(list, { from = by, target = targetId, expiresAt = sim.time + setting(sim, "askSeconds") })
	sim:emit("WarAsked", {
		kingdomId = kingdom.id,
		requester = by,
		target = targetId,
		seniorId = Authority.seniorOf(sim, kingdom),
	})
	return true, nil, { outcome = "asked", targetId = targetId, delivered = true }
end

return Authority
