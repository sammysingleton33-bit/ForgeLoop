-- FL-0142: the co-rulers' champion vote. The real KingdomHudController, DuelController, ArenaHudController and
-- ArenaHudVoteController over FORGE-01-shaped doubles (ArenaDoubles + VoteDoubles: Arena.Vote and FORGE-01's
-- ArenaState.vote, live since #275). Sam (user 1) and Mira (user 2) rule Emberhold (crimson).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaVote = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaVote")
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
	world.toastKinds = {}
	local notify = world.hud.notify
	world.hud.notify = function(self, spec)
		table.insert(world.toasts, spec.title)
		table.insert(world.toastKinds, spec.kind)
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
		expect(v.status).toContain("A tie goes to the higher leadership") -- ArenaFlow._pickChampions
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

	it(
		"the second kingdom (side b) votes too; a vote for a ruler who left counts as no vote (FORGE-07 M3, L2)",
		function()
			local st = VoteDoubles.state("azure", { 7, 1 }, 110, {}, "b")
			local v = ArenaVoteModel.view(st, lookup, 1, 100)
			expect(v.side).toBe("b")
			expect(v.kingdomId).toBe("azure")
			local both = VoteDoubles.state("crimson", { 2, 3 }, 110)
			both.vote.b = { kingdom = "azure", candidates = { 1, 7 }, voted = {} }
			expect(ArenaVoteModel.view(both, lookup, 1, 100).side).toBe("b")
			expect(ArenaVoteModel.view(both, lookup, 3, 100).side).toBe("a")
			local left = ArenaVoteModel.view(st, lookup, 1, 100, { candidate = 3, status = "ok" })
			expect(left.statusKind).toBe("hint")
			for _, c in left.candidates do
				expect(c.picked).toBe(false)
			end
		end
	)

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

	it("the latest vote counts: a ruler may change it until the vote closes", function()
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
		expect(world.toastKinds[1]).toBe("info")
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

	it("the countdown moves in place: the buttons are not rebuilt while nothing else changes (FORGE-07 M1)", function()
		world = newWorld()
		open(world, { 1, 2 }, 9.5)
		local button = find(panel(world), "Candidate_2")
		world:advance(3)
		expect(find(panel(world), "Candidate_2")).toBe(button)
		expect(button.Parent).toBeTruthy()
		expect(find(panel(world), "VoteClock"):FindFirstChildWhichIsA("TextLabel").Text).toBe("7 s")
		world.hud:setViewport(667, 375) -- a new screen rebuilds it
		world:advance(0.3)
		expect(find(panel(world), "Candidate_2") ~= button).toBe(true)
	end)

	it("the second kingdom's rulers get the panel too (side b) and their vote is sent (FORGE-07 M3)", function()
		world = newWorld()
		world.voteServer:open("crimson", { 1, 2 }, world.env.serverTimeNow() + 10, "b")
		world:advance(0.3)
		expect(panel(world):GetAttribute("side")).toBe("b")
		tap(find(panel(world), "Candidate_2"))
		world:advance(0.3)
		expect(world.voteServer.votes[1]).toBe(2)
	end)

	it("long names are cut to fit their buttons; the full name stays on the button (FORGE-07 M2)", function()
		world = newWorld({ width = 667, height = 375 })
		local names = { [3] = "Maximiliano_The_Great", [4] = "WWWWWWWWWWWWWWWWWWWW" }
		local nameOf = world.hud._nameOf
		world.hud._nameOf = function(self, id)
			return names[id] or nameOf(self, id)
		end
		open(world, { 1, 2, 3, 4 })
		for _, id in { 3, 4 } do
			local b = find(panel(world), `Candidate_{id}`)
			expect(b:GetAttribute("fullName")).toBe(names[id])
			local label = b:FindFirstChildWhichIsA("TextLabel", true)
			expect(string.sub(label.Text, -3)).toBe("…")
			expect(ArenaVote.textWidth(label.Text)).toBeLessThan(b.Size.X.Offset - ArenaVote.PAD + 1)
			expect(label.TextTruncate).toBe(Enum.TextTruncate.AtEnd) -- Roblox ends it with "…" at the button's edge
			expect(label.Size.X.Offset).toBe(b.Size.X.Offset - ArenaVote.PAD)
		end
		expect(ArenaVote.shorten("Mira", 120)).toBe("Mira")
		expect(ArenaVote.textWidth("WWW")).toBeGreaterThan(ArenaVote.textWidth("iii") * 3)
	end)

	it(
		"everything fits inside the panel on desktop and phone, buttons and gaps within the row (FORGE-07 L1)",
		function()
			for _, size in { { 1920, 1022 }, { 667, 375 } } do
				world = newWorld({ width = size[1], height = size[2] })
				open(world, { 1, 2, 3, 4 })
				local box = panel(world):FindFirstChildWhichIsA("Frame")
				local content = box:FindFirstChild("Content", true)
				local contentHeight = box.Size.Y.Offset + content.Size.Y.Offset
				local row = find(box, "Candidates")
				expect(row.Position.Y.Offset + 44 + 18 + 2).toBeLessThan(contentHeight + 1)
				local contentWidth = box.Size.X.Offset + content.Size.X.Offset
				local used = (4 - 1) * ArenaVote.GAP
				for _, id in { 1, 2, 3, 4 } do
					used += find(box, `Candidate_{id}`).Size.X.Offset
				end
				expect(used).toBeLessThan(contentWidth + 1)
				expect(panel(world).ZIndex).toBeGreaterThan(9)
				world:destroy()
				world = nil
			end
		end
	)

	it("the phone status line holds its longest text in two lines (FORGE-07 low on #265)", function()
		world = newWorld({ width = 667, height = 375 })
		open(world, { 1, 2 })
		local status = find(panel(world), "VoteStatus")
		local lineHeight = 12 * status.LineHeight
		expect(status.TextSize).toBe(12)
		expect(status.TextWrapped).toBe(true)
		expect(status.Size.Y.Offset).toBeGreaterThan(2 * lineHeight - 0.01) -- two lines fit in the box
		-- the longest status: "ok" for a 20-character name; ArenaVote's bold 15 px estimate, scaled to 12 px
		local long = ArenaVoteModel.view(VoteDoubles.state("crimson", { 1, 2 }, 100), {
			name = function(id)
				return if id == 2 then "WWWWWWWWWWWWWWWWWWWW" else nil
			end,
		}, 1, 0, { candidate = 2, status = "ok" })
		local width = ArenaVote.textWidth(long.status) * 12 / 15
		local box = panel(world):FindFirstChildWhichIsA("Frame")
		local content = box:FindFirstChild("Content", true)
		local lineWidth = box.Size.X.Offset + content.Size.X.Offset
		expect(width).toBeLessThan(2 * lineWidth) -- wraps to at most two lines
		for _, kind in { "hint", "pending", "failed" } do
			local pick = if kind == "hint" then nil else { candidate = 2, status = kind }
			local v = ArenaVoteModel.view(VoteDoubles.state("crimson", { 1, 2 }, 100), nil, 1, 0, pick)
			expect(ArenaVote.textWidth(v.status) * 12 / 15).toBeLessThan(2 * lineWidth)
		end
		world:destroy()
		world = nil
	end)

	it("a vote never waits longer than the vote stage lasts (FORGE-07 L1)", function()
		expect(VoteDef.VOTE_TIMEOUT_SEC).toBeLessThan(ArenaConfig.voteSeconds)
		expect(VoteDef.VOTE_TIMEOUT_SEC).toBeGreaterThan(1)
	end)

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
