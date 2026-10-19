-- FL-0142: the co-rulers' champion vote. The real KingdomHudController, DuelController, ArenaHudController and
-- ArenaHudVoteController over FORGE-01-shaped doubles (ArenaDoubles + VoteDoubles: Arena.Vote and the proposed
-- ArenaState.vote). Sam (user 1) and Mira (user 2) rule Emberhold (crimson).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArenaVoteModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaVoteModel")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local VoteDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudVoteController")
local VoteDoubles = require("./doubles/VoteDoubles")

local function find(root, name)
	if root == nil then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function newWorld(opts)
	local o = opts or {}
	local world = KingdomWorld.new({
		remotes = if o.noVote then ArenaDoubles.REMOTES else VoteDoubles.REMOTES,
		services = if o.noVote then { ArenaDoubles.service } else { ArenaDoubles.service, VoteDoubles.service },
		clientDefinitions = { KingdomHudDef, DuelDef, ArenaHudDef, VoteDef },
	})
	world.hud = world.client:get("KingdomHudController")
	world.vote = world.client:get("ArenaHudVoteController")
	world.arenaServer = world.server:get("ArenaDouble")
	world.voteServer = if o.noVote then nil else world.server:get("VoteDouble")
	world.toasts = {}
	local notify = world.hud.notify
	world.hud.notify = function(self, spec)
		table.insert(world.toasts, spec.title)
		return notify(self, spec)
	end
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world.match:setPhase("Endgame", world.env.serverTimeNow() + 60)
	world:advance(0.3)
	return world
end

local function panel(world)
	return find(world.hud.guis.modals, "ArenaVote")
end

local function open(world, candidates, seconds, kingdom)
	world.voteServer:open(kingdom or "crimson", candidates or { 1, 2 }, world.env.serverTimeNow() + (seconds or 10))
	world:advance(0.3)
end

describe("ArenaVoteModel (FL-0142)", function()
	local lookup = {
		kingdom = function(id)
			return { name = if id == "crimson" then "Emberhold" else id }
		end,
		name = function(id)
			return ({ [2] = "Mira", [3] = "Rowan" })[id]
		end,
	}

	it("only a candidate in the vote stage sees it; without ArenaState.vote nothing shows", function()
		local st = VoteDoubles.state("crimson", { 1, 2 }, 110)
		expect(ArenaVoteModel.view(st, lookup, 1, 100)).toBeTruthy()
		expect(ArenaVoteModel.view(st, lookup, 3, 100)).toBeNil() -- not a candidate
		expect(ArenaVoteModel.view({ stage = "vote", endsAt = 110 }, lookup, 1, 100)).toBeNil() -- today's main
		local loadout = table.clone(st)
		loadout.stage = "loadout"
		expect(ArenaVoteModel.view(loadout, lookup, 1, 100)).toBeNil()
		expect(ArenaVoteModel.view(st, lookup, nil, 100)).toBeNil()
	end)

	it("names, 'You', the countdown, who has voted, and the status for each step", function()
		local st = VoteDoubles.state("crimson", { 1, 2, 3 }, 107.2, { 2 })
		local v = ArenaVoteModel.view(st, lookup, 1, 100)
		expect(v.kingdom).toBe("Emberhold")
		expect(v.clock).toBe("8 s")
		expect(v.candidates[1].name).toBe("You")
		expect(v.candidates[2].name).toBe("Mira")
		expect(v.candidates[2].hasVoted).toBe(true)
		expect(v.votedText).toBe("1 of 3 voted")
		expect(v.statusKind).toBe("hint")
		expect(v.status).toContain("Emberhold")
		local pending = ArenaVoteModel.view(st, lookup, 1, 100, { candidate = 3, status = "pending" })
		expect(pending.statusKind).toBe("pending")
		expect(pending.candidates[3].picked).toBe(true)
		local ok = ArenaVoteModel.view(st, lookup, 1, 100, { candidate = 1, status = "ok" })
		expect(ok.status).toContain("yourself")
		local failed = ArenaVoteModel.view(st, lookup, 1, 100, { candidate = 3, status = "failed" })
		expect(failed.statusKind).toBe("failed")
		expect(failed.candidates[3].picked).toBe(false)
		expect(ArenaVoteModel.view(VoteDoubles.state("crimson", { 1, 2 }, 90), lookup, 1, 100).clock).toBe("0 s")
	end)

	it("the result names the champion once the champions are known", function()
		local d = ArenaDoubles.duellist(2, "crimson", "loyal")
		expect(ArenaVoteModel.result({ stage = "loadout", a = d }, "a", 1, lookup)).toBe(
			"Mira fights for Emberhold in the Crown Arena"
		)
		expect(ArenaVoteModel.result({ stage = "loadout", a = ArenaDoubles.duellist(1, "crimson") }, "a", 1, lookup)).toBe(
			"You fight for Emberhold in the Crown Arena"
		)
		local ai = ArenaDoubles.duellist(-1000000001, "crimson", "loyal", { isAI = true })
		expect(ArenaVoteModel.result({ stage = "loadout", a = ai }, "a", 1, lookup)).toBe(
			"Emberhold's champion fights in the Crown Arena"
		)
		expect(ArenaVoteModel.result({ stage = "vote" }, "a", 1, lookup)).toBeNil()
		expect(ArenaVoteModel.result({ stage = "done" }, "a", 1, lookup)).toBeNil()
	end)
end)

describe("Arena vote panel (FL-0142)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("opens in the vote stage for a candidate; a tap sends Arena.Vote and the server's answer shows", function()
		world = newWorld()
		expect(panel(world)).toBeNil()
		open(world)
		local p = panel(world)
		expect(p).toBeTruthy()
		expect(p:GetAttribute("kingdom")).toBe("crimson")
		expect(find(p, "VotedCount").Text).toBe("0 of 2 voted")
		expect(world.vote:vote(99)).toBe(false) -- not one of the candidates: nothing is sent
		tap(find(p, "Candidate_2"))
		world:advance(0.3)
		expect(#world.voteServer.calls).toBe(1)
		expect(world.voteServer.calls[1].userId).toBe(1)
		expect(world.voteServer.calls[1].candidate).toBe(2)
		expect(world.voteServer.votes[1]).toBe(2)
		p = panel(world)
		expect(find(p, "VoteStatus"):GetAttribute("kind")).toBe("ok")
		expect(find(p, "Candidate_2"):FindFirstChild("Face"):GetAttribute("picked")).toBe(true)
		expect(find(p, "VotedCount").Text).toBe("1 of 2 voted") -- the server's push
	end)

	it("the latest vote counts: a ruler may change it until the time runs out", function()
		world = newWorld()
		open(world)
		tap(find(panel(world), "Candidate_2"))
		world:advance(1.2)
		tap(find(panel(world), "Candidate_1"))
		world:advance(0.3)
		expect(world.voteServer.votes[1]).toBe(1)
		expect(find(panel(world), "Candidate_1"):FindFirstChild("Face"):GetAttribute("picked")).toBe(true)
		expect(find(panel(world), "Candidate_2"):FindFirstChild("Face"):GetAttribute("picked")).toBe(false)
	end)

	it("one call at a time: taps while a vote is on its way send nothing", function()
		world = newWorld()
		open(world)
		local invoke = world.hud.remotes.invoke
		local release = false
		world.hud.remotes.invoke = function(self, name, ...)
			while name == VoteDef.VOTE and not release do
				world.env.wait(0.1)
			end
			return invoke(self, name, ...)
		end
		expect(world.vote:vote(2)).toBe(true)
		world:advance(0.3)
		expect(world.vote.pick.status).toBe("pending")
		expect(find(panel(world), "VoteStatus"):GetAttribute("kind")).toBe("pending")
		expect(world.vote:vote(1)).toBe(false)
		release = true
		world:advance(0.3)
		expect(#world.voteServer.calls).toBe(1)
		expect(world.vote.pick.status).toBe("ok")
	end)

	it("a refused or dropped vote says it was not counted and can be tried again", function()
		world = newWorld()
		open(world)
		world.voteServer.answer = false
		world.vote:vote(2)
		world:advance(0.3)
		expect(find(panel(world), "VoteStatus"):GetAttribute("kind")).toBe("failed")
		world.voteServer.answer = "drop"
		world.vote:vote(2)
		world:advance(0.3)
		expect(world.vote.pick.status).toBe("failed")
		world.voteServer.answer = nil
		expect(world.vote:vote(2)).toBe(true)
		world:advance(0.3)
		expect(world.vote.pick.status).toBe("ok")
	end)

	it("no answer within VOTE_TIMEOUT_SEC says not counted; a late answer for an older call changes nothing", function()
		world = newWorld()
		open(world)
		local invoke = world.hud.remotes.invoke
		local release = false
		world.hud.remotes.invoke = function(self, name, ...)
			if name == VoteDef.VOTE then
				while not release do
					world.env.wait(0.1)
				end
			end
			return invoke(self, name, ...)
		end
		world.vote:vote(2)
		world:advance(VoteDef.VOTE_TIMEOUT_SEC + 0.2)
		expect(world.vote.pick.status).toBe("failed")
		world.hud.remotes.invoke = invoke
		world.vote:vote(1)
		world:advance(0.3)
		expect(world.vote.pick.candidate).toBe(1)
		expect(world.vote.pick.status).toBe("ok")
		release = true
		world:advance(0.5)
		expect(world.vote.pick.candidate).toBe(1)
		expect(world.vote.pick.status).toBe("ok")
	end)

	it(
		"not a candidate (another kingdom votes), or no ArenaState.vote (today's main): no panel, nothing sent",
		function()
			world = newWorld()
			open(world, { 7, 8 }, 10, "azure")
			expect(panel(world)).toBeNil()
			expect(world.vote:vote(7)).toBe(false)
			world.arenaServer:setState({ stage = "vote", endsAt = world.env.serverTimeNow() + 10 })
			world:advance(0.3)
			expect(panel(world)).toBeNil()
			expect(#world.voteServer.calls).toBe(0)
		end
	)

	it("dark without the Arena.Vote remote, even with ArenaState.vote", function()
		world = newWorld({ noVote = true })
		world.arenaServer:setState(VoteDoubles.state("crimson", { 1, 2 }, world.env.serverTimeNow() + 10))
		world:advance(0.3)
		expect(panel(world)).toBeNil()
		expect(world.vote:vote(2)).toBe(false)
	end)

	it("the countdown ticks down while the panel is open", function()
		world = newWorld()
		open(world, { 1, 2 }, 9.5)
		expect(find(panel(world), "VoteClock"):FindFirstChildWhichIsA("TextLabel").Text).toBe("10 s")
		world:advance(3)
		expect(find(panel(world), "VoteClock"):FindFirstChildWhichIsA("TextLabel").Text).toBe("7 s")
	end)

	it("closes when the loadout starts and says the champion once", function()
		world = newWorld()
		open(world)
		world.vote:vote(2)
		world:advance(0.3)
		world.arenaServer:setState({
			stage = "loadout",
			endsAt = world.env.serverTimeNow() + 20,
			a = ArenaDoubles.duellist(2, "crimson", "loyal"),
			b = ArenaDoubles.duellist(7, "azure", "divided"),
		})
		world:advance(0.3)
		expect(panel(world)).toBeNil()
		expect(#world.toasts).toBe(1)
		expect(world.toasts[1]).toBe("Mira fights for Emberhold in the Crown Arena")
		world.arenaServer:setState({
			stage = "intro",
			endsAt = world.env.serverTimeNow() + 12,
			a = world.arenaServer.state.a,
		})
		world:advance(0.3)
		expect(#world.toasts).toBe(1)
	end)

	it("a spectator of the vote (not a candidate) gets no result toast", function()
		world = newWorld()
		open(world, { 7, 8 }, 10, "azure")
		world.arenaServer:setState({ stage = "loadout", a = ArenaDoubles.duellist(7, "azure", "loyal") })
		world:advance(0.3)
		expect(#world.toasts).toBe(0)
	end)

	it(
		"phone 667 × 375: the panel fits the screen with 44 px candidate buttons; four candidates share the row",
		function()
			world = newWorld({ width = 667, height = 375 })
			open(world, { 1, 2, 3, 4 })
			local p = panel(world)
			local box = p:FindFirstChildWhichIsA("Frame")
			expect(box.Size.X.Offset).toBeLessThan(667 - 15)
			expect(box.Size.Y.Offset).toBeLessThan(375 - 15)
			-- centred 4 px low, its top edge clears the Roblox top bar (58 px)
			expect((375 - box.Size.Y.Offset) / 2 + 4).toBeGreaterThan(57)
			for _, id in { 1, 2, 3, 4 } do
				local b = find(p, `Candidate_{id}`)
				expect(b.Size.Y.Offset).toBe(44)
				expect(b.Size.X.Offset).toBeGreaterThan(100)
			end
		end
	)

	it("destroy removes the panel and stops listening, even with a vote on its way", function()
		world = newWorld()
		open(world)
		expect(panel(world)).toBeTruthy()
		local invoke = world.hud.remotes.invoke
		local release = false
		world.hud.remotes.invoke = function(self, name, ...)
			while name == VoteDef.VOTE and not release do
				world.env.wait(0.1)
			end
			return invoke(self, name, ...)
		end
		world.vote:vote(2)
		world:advance(0.2)
		world.vote:destroy()
		release = true
		world:advance(0.3)
		expect(panel(world)).toBeNil()
		world.arenaServer:setState(VoteDoubles.state("crimson", { 1, 2 }, world.env.serverTimeNow() + 10))
		world:advance(0.3)
		expect(panel(world)).toBeNil()
	end)
end)
