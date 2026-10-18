--!strict
--[[
	UI/DiplomacyModel — war and peace with the rival kingdoms (FL-0129, Operation Crownfall, D-053 (2)).
	Pure; no instances. The Kingdom panel's Rivals tab (UI/RivalsList) draws its rows.

	State (KingdomStore:diplomacy(), from the server's `diplomacy` payload; times are server time, the
	G3 endsAt scale):
		{ relations = { { a, b, relation = "Peace" | "War" } }, proposals = { { from, to, expiresAt } },
		  cooldowns = { { a, b, untilAt } }, graceEndsAt? }
	A pair that is not listed is at Peace (Sim/Diplomacy: every pair starts at Peace).

		DiplomacyModel.view(store, diplomacy, phase, now) -> View?   nil without my kingdom
			View = { rows: { Row }, incoming: number (peace offers waiting for my answer) }
			Row = { id, name, color, emblem, crownPoints, rank, alive,
			        relation: "peace" | "war" | "truce" | "fallen", status: string (the chip's words),
			        note: string? (a time-bound line: "Proposes peace · 0:42", "Truce · 1:20 left"),
			        actions: { Action } }
			Action = { id: "declareWar" | "proposePeace" | "acceptPeace", label, variant: "primary" |
			           "secondary" | "danger", enabled: boolean, reason: string? (why it is disabled) }
		DiplomacyModel.relation(diplomacy, a, b) -> "Peace" | "War"
		DiplomacyModel.WAR_FROM = "Conflict"   -- D-053 (2): war from Conflict on (the server decides; the
		                                          client only says why the button is off)
	Rules mirror Sim/Diplomacy so the buttons are off for the reasons the server would give:
		declare war: at peace, not in a truce (peace_cooldown), not before WAR_FROM or graceEndsAt
		(grace_period); propose peace: at war, no proposal of mine still open; accept peace: their
		proposal to me is still open (no_proposal otherwise). The server stays the authority.
]]

local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local HudModel = require("./HudModel")

local DiplomacyModel = {}

DiplomacyModel.WAR_FROM = "Conflict"
-- Phases before war may be declared (D-053 (2)); the full match's order (CONTRACTS G3).
local BEFORE_WAR = table.freeze({ Lobby = true, Founding = true, Expansion = true })

local function pairIs(entry: any, a: string, b: string): boolean
	return (entry.a == a and entry.b == b) or (entry.a == b and entry.b == a)
end

function DiplomacyModel.relation(diplomacy: any, a: string, b: string): string
	for _, entry in if diplomacy and type(diplomacy.relations) == "table" then diplomacy.relations else {} do
		if type(entry) == "table" and pairIs(entry, a, b) then
			return if entry.relation == "War" then "War" else "Peace"
		end
	end
	return "Peace"
end

local function proposal(diplomacy: any, from: string, to: string, now: number): number?
	for _, p in if diplomacy and type(diplomacy.proposals) == "table" then diplomacy.proposals else {} do
		if type(p) == "table" and p.from == from and p.to == to and type(p.expiresAt) == "number" then
			if p.expiresAt > now then
				return p.expiresAt
			end
		end
	end
	return nil
end

local function truceUntil(diplomacy: any, a: string, b: string, now: number): number?
	for _, c in if diplomacy and type(diplomacy.cooldowns) == "table" then diplomacy.cooldowns else {} do
		if type(c) == "table" and pairIs(c, a, b) and type(c.untilAt) == "number" and c.untilAt > now then
			return c.untilAt
		end
	end
	return nil
end

local function declareReason(diplomacy: any, phase: string?, now: number, truce: number?): string?
	if truce then
		return `Truce for {Format.clock(truce - now)}`
	end
	if phase and BEFORE_WAR[phase] then
		return `War opens in {DiplomacyModel.WAR_FROM}`
	end
	local grace = diplomacy and diplomacy.graceEndsAt
	if type(grace) == "number" and grace > now then
		return `No war for {Format.clock(grace - now)}`
	end
	return nil
end

function DiplomacyModel.view(store: any, diplomacy: any, phase: string?, now: number): any
	local mine = store:mine()
	if mine == nil then
		return nil
	end
	local ranks = {}
	for _, s in HudModel.standings(store) do
		ranks[s.id] = s.rank
	end
	local rows, incoming = {}, 0
	for _, kingdom in store:kingdoms() do
		if kingdom.id ~= mine.id then
			local war = DiplomacyModel.relation(diplomacy, mine.id, kingdom.id) == "War"
			local truce = if war then nil else truceUntil(diplomacy, mine.id, kingdom.id, now)
			local theirs = proposal(diplomacy, kingdom.id, mine.id, now)
			local ours = proposal(diplomacy, mine.id, kingdom.id, now)
			local alive = kingdom.alive ~= false
			local relation = if not alive then "fallen" elseif war then "war" elseif truce then "truce" else "peace"
			local row = {
				id = kingdom.id,
				name = if type(kingdom.name) == "string" then kingdom.name else kingdom.id,
				color = HudModel.color(kingdom),
				emblem = HudModel.EMBLEMS[kingdom.id] or "crest",
				crownPoints = if type(kingdom.crownPoints) == "number" then kingdom.crownPoints else 0,
				rank = ranks[kingdom.id],
				alive = alive,
				relation = relation,
				status = if relation == "fallen"
					then "Fallen"
					elseif relation == "war" then "At war"
					elseif relation == "truce" then "Truce"
					else "At peace",
				note = nil :: string?,
				actions = {},
			}
			if alive and war then
				if theirs then
					incoming += 1
					row.note = `Proposes peace · {Format.clock(theirs - now)}`
					table.insert(row.actions, {
						id = "acceptPeace",
						label = "Accept peace",
						variant = "primary",
						enabled = true,
					})
				end
				table.insert(row.actions, {
					id = "proposePeace",
					label = "Propose peace",
					variant = if theirs then "secondary" else "primary",
					enabled = ours == nil,
					reason = if ours then `Offer sent · {Format.clock(ours - now)}` else nil,
				})
			elseif alive then
				if truce then
					row.note = `Truce · {Format.clock(truce - now)} left`
				end
				local reason = declareReason(diplomacy, phase, now, truce)
				table.insert(row.actions, {
					id = "declareWar",
					label = "Declare war",
					variant = "danger",
					enabled = reason == nil,
					reason = reason,
				})
			end
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(x, y)
		return (x.rank or math.huge) < (y.rank or math.huge)
	end)
	return { rows = rows, incoming = incoming }
end

return table.freeze(DiplomacyModel)
