--!strict
--[[
	UI/ArenaVoteModel — the co-rulers' champion vote (FL-0142; design crown-arena.md §2 "Champion choice", CONTRACTS
	G12.4 Arena.Vote). Pure; no instances. UI/ArenaVote draws it, ArenaHudVoteController sends the vote.

	Reads ArenaState.vote (asked of FORGE-01, handoff 2026-10-19-forge-03-to-forge-01-arena-vote): only while
	stage == "vote", one entry per side with two or more candidates:
		vote = { a = { kingdom, candidates: { userId }, voted: { userId } }, b = ... }
	`voted` names who has voted, never for whom (the ballot is secret). Without the field nothing shows: the
	panel is dark until the server sends it.

		ArenaVoteModel.entry(state, me) -> (side?, entry?)   the local player's own vote, when they are a candidate
		ArenaVoteModel.view(state, lookup, me, now, pick?) -> View?
			lookup = { kingdom: (KingdomId) -> { name? }?, name: (userId) -> string? }
			pick   = { candidate, status = "pending" | "ok" | "failed" }?   the local player's last vote
			View = { side, kingdomId, kingdom, seconds, clock ("8 s"), candidates: { Candidate }, voted, total,
			         votedText ("1 of 2 voted"), status, statusKind ("hint" | "pending" | "ok" | "failed") }
			Candidate = { userId, name, you, picked, hasVoted }
		ArenaVoteModel.result(state, side, me, lookup) -> string?   once the champions are known (any stage after
			the vote): "You fight for Emberhold" / "Rowan fights for Emberhold" / "Emberhold's champion fights"
]]

local ArenaVoteModel = {}

ArenaVoteModel.SIDES = table.freeze({ "a", "b" })

local function contains(list: any, value: any): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

local function kingdomName(lookup: any, id: any): string
	local k = if type(id) == "string" and lookup and lookup.kingdom then lookup.kingdom(id) else nil
	return if type(k) == "table" and type(k.name) == "string" then k.name else tostring(id or "Your kingdom")
end

function ArenaVoteModel.entry(state: any, me: number?): (string?, any)
	if type(state) ~= "table" or state.stage ~= "vote" or type(state.vote) ~= "table" or type(me) ~= "number" then
		return nil, nil
	end
	for _, side in ArenaVoteModel.SIDES do
		local e = state.vote[side]
		if type(e) == "table" and contains(e.candidates, me) then
			return side, e
		end
	end
	return nil, nil
end

function ArenaVoteModel.view(state: any, lookup: any, me: number?, now: number, pick: any?): any
	local side, e = ArenaVoteModel.entry(state, me)
	if side == nil then
		return nil
	end
	local candidates = {}
	local voted = 0
	for _, id in e.candidates do
		if type(id) ~= "number" then
			continue
		end
		local you = id == me
		local name = if you then "You" else (lookup and lookup.name and lookup.name(id)) or "A ruler"
		local hasVoted = contains(e.voted, id)
		if hasVoted then
			voted += 1
		end
		table.insert(candidates, {
			userId = id,
			name = name,
			you = you,
			picked = pick ~= nil and pick.candidate == id and pick.status ~= "failed",
			hasVoted = hasVoted,
		})
	end
	local seconds = if type(state.endsAt) == "number" then math.max(0, math.ceil(state.endsAt - now)) else nil
	local kingdom = kingdomName(lookup, e.kingdom)
	local status, kind
	local pickedName = nil
	for _, c in candidates do
		if pick and c.userId == pick.candidate then
			pickedName = if c.you then "yourself" else c.name
		end
	end
	if pick == nil then
		status, kind = `Choose who fights for {kingdom}. A tie goes to the higher leadership.`, "hint"
	elseif pick.status == "pending" then
		status, kind = "Sending your vote…", "pending"
	elseif pick.status == "ok" then
		status, kind = `You voted for {pickedName or "a ruler"}. You can change it until the time runs out.`, "ok"
	else
		status, kind = "Your vote was not counted. Try again.", "failed"
	end
	return {
		side = side,
		kingdomId = e.kingdom,
		kingdom = kingdom,
		seconds = seconds,
		clock = if seconds then `{seconds} s` else nil,
		candidates = candidates,
		voted = voted,
		total = #candidates,
		votedText = `{voted} of {#candidates} voted`,
		status = status,
		statusKind = kind,
	}
end

function ArenaVoteModel.result(state: any, side: string?, me: number?, lookup: any): string?
	if type(state) ~= "table" or side == nil or state.stage == "vote" then
		return nil
	end
	local d = state[side]
	if type(d) ~= "table" then
		return nil
	end
	local kingdom = kingdomName(lookup, d.kingdom)
	if d.isAI == true or type(d.userId) ~= "number" then
		return `{kingdom}'s champion fights in the Crown Arena`
	end
	if d.userId == me then
		return `You fight for {kingdom} in the Crown Arena`
	end
	local name = (lookup and lookup.name and lookup.name(d.userId)) or "Your co-ruler"
	return `{name} fights for {kingdom} in the Crown Arena`
end

return table.freeze(ArenaVoteModel)
