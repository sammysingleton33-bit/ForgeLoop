local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local CrowdDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackCrowdController")

local A, B = 7501, 7502

local function duellist(userId, tier, kingdom, isAI)
	return {
		userId = userId,
		kingdom = kingdom,
		tier = tier,
		isAI = isAI == true,
		score = 50,
		triggers = {},
		reasons = {},
	}
end

local function state(stage, extra)
	local out = {
		stage = stage,
		a = duellist(A, "adoring", "crimson"),
		b = duellist(B, "hostile", "azure"),
	}
	for key, value in extra or {} do
		out[key] = value
	end
	return out
end

local function boot(opts)
	opts = opts or {}
	local env = MockEnv.new({ seed = 74, isServer = false, localPlayer = { userId = 9001 } })
	local gui = if opts.noGui then nil else env.newInstance("Folder")
	local plays = {}
	local defs = {}
	if not opts.noAudio then
		table.insert(defs, {
			name = "AudioController",
			dependencies = {},
			new = function()
				return {
					play = function(_, id, playOpts)
						table.insert(plays, { id = id, volume = playOpts and playOpts.volume })
					end,
				}
			end,
		})
	end
	table.insert(defs, {
		name = "AnnouncerController",
		dependencies = {},
		new = function()
			return { moment = Signal.new() }
		end,
	})
	table.insert(defs, {
		name = "FeedbackCrowdController",
		dependencies = {},
		new = function(e, r)
			return CrowdDef.create(e, r, {
				playerGui = gui,
				userNames = opts.userNames or { [A] = "Sam", [B] = "Kit" },
				studio = opts.studio,
			})
		end,
	})
	local registry = Loader.load(env, defs)
	return {
		env = env,
		gui = gui,
		plays = plays,
		crowd = registry:get("FeedbackCrowdController"),
		announcer = registry:get("AnnouncerController"),
	}
end

local function ids(plays)
	local out = {}
	for _, play in plays do
		table.insert(out, play.id)
	end
	return out
end

describe("FeedbackCrowdController: the duel's director (FL-0074 part 2a)", function()
	it("is made when Arena.State names both duellists at the intro; a new pair starts a new one", function()
		local t = boot()
		expect(t.crowd.director).toBeNil()
		t.crowd:onArenaState(state("loadout"))
		expect(t.crowd.director).toBeNil()
		t.crowd:onArenaState(state("intro"))
		local first = t.crowd.director
		assert(first ~= nil, "a director at the intro")
		t.crowd:onArenaState(state("duel"))
		expect(t.crowd.director).toBe(first) -- the same duel
		local other = state("duel")
		other.b = duellist(7600, "loyal", "gold")
		t.crowd:onArenaState(other)
		expect(t.crowd.director ~= first).toBe(true)
		t.crowd:onArenaState(state("done"))
		expect(t.crowd.director).toBeNil()
		t.crowd:onArenaState("duel")
		t.crowd:onArenaState(state("duel", { a = "nobody" }))
		expect(t.crowd.director).toBeNil()
	end)

	it("Results and Lobby drop the director and clear the subtitles; events before a director are dropped", function()
		local t = boot()
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(#t.plays).toBe(0)
		t.crowd:onArenaState(state("duel"))
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(#t.crowd:captions()).toBe(2)
		t.crowd:onPhase("Results")
		expect(t.crowd.director).toBeNil()
		expect(#t.crowd:captions()).toBe(0)
		expect(t.gui:FindFirstChild(CrowdDef.GUI_NAME)).toBeNil()
		t.crowd:onArenaState(state("duel"))
		t.crowd:onPhase("Lobby")
		expect(t.crowd.director).toBeNil()
		t.crowd:onEvents("parry")
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(#t.plays).toBe(2) -- only the one parry inside the duel
	end)
end)

describe("FeedbackCrowdController: sounds and subtitles (FL-0074 part 2a)", function()
	it("a big hit plays both stands' sounds and shows one line per stand with the kingdom's name", function()
		local t = boot()
		local seen = {}
		t.crowd.reacted:connect(function(reaction, kingdom)
			table.insert(seen, `{reaction.stand}:{reaction.kind}:{tostring(kingdom)}`)
		end)
		t.crowd:onArenaState(state("duel"))
		t.crowd:onEvents({ { t = 0, kind = "hit", side = "a", data = { heavy = true } } })
		expect(ids(t.plays)).toEqual({ "crowd.roar", "crowd.boo" })
		expect(t.plays[1].volume).toBe(1)
		expect(t.crowd:captions()).toEqual({
			"Crimson Kingdom: (The crowd roars)",
			"Azure Kingdom: (The stand turns its back)",
		})
		expect(seen).toEqual({ "a:roar:crimson", "b:turnBack:azure" })
		local screen = t.gui:FindFirstChild(CrowdDef.GUI_NAME)
		assert(screen ~= nil, "the subtitles are shown")
		expect(screen.ResetOnSpawn).toBe(false)
		local label = screen:FindFirstChild("Caption_a")
		expect(label.Text).toBe("Crimson Kingdom: (The crowd roars)")
		expect(label.Visible).toBe(true)
		expect(label.RichText).toBe(false)
	end)

	it("a reaction without a sound still shows its subtitle (every reaction has text)", function()
		local t = boot()
		local s = state("duel")
		s.a = duellist(A, "hostile", "crimson")
		s.b = duellist(B, "loyal", "azure")
		t.crowd:onArenaState(s)
		t.crowd:onEvents({ { kind = "parry", side = "a" } }) -- hostile good = silence (no sound)
		expect(ids(t.plays)).toEqual({ "crowd.gasp" })
		expect(t.crowd:captions()[1]).toBe("Crimson Kingdom: (The stand stays silent)")
	end)

	it("the announcer and a perk stinger duck the crowd's volume", function()
		local t = boot()
		t.crowd:onArenaState(state("duel"))
		t.announcer.moment:fire({ kind = "war" })
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(t.plays[1].volume).toBe(Crowd.duck.volume)
		t.env.mock:advance(math.max(Crowd.duck.announcerSec, Crowd.majorGapSec) + 0.1)
		t.crowd:onEvents({ { kind = "parry", side = "b" } })
		expect(t.plays[3].volume).toBe(1)
	end)

	it("lines expire after CAPTION_SEC; a perk's line holds PRIORITY_SEC against lesser lines", function()
		local t = boot()
		t.crowd:onArenaState(state("duel"))
		local now = t.env.clock()
		t.crowd:onEvents({
			{
				kind = "triggerFired",
				side = "a",
				data = { trigger = "reforge", triggerName = "Reforge", citizenName = "Mara" },
			},
		})
		expect(t.crowd:captions()).toEqual({ "Crimson Kingdom: Mara steps up: Reforge!" })
		t.crowd:onEvents({ { kind = "hit", side = "a", data = { damage = 0.05 } } }) -- a minor in the same stand
		expect(t.crowd:captions()).toEqual({ "Crimson Kingdom: Mara steps up: Reforge!" })
		t.crowd:step(now + CrowdDef.PRIORITY_SEC + 0.01)
		expect(#t.crowd:captions()).toBe(0)
		local label = t.gui:FindFirstChild(CrowdDef.GUI_NAME):FindFirstChild("Caption_a")
		expect(label.Visible).toBe(false)
		t.crowd:onEvents({ { kind = "hit", side = "b", data = { damage = 0.05 } } })
		local at = t.env.clock()
		t.crowd:step(at + CrowdDef.CAPTION_SEC - 0.1)
		expect(#t.crowd:captions()).toBe(1)
		t.crowd:step(at + CrowdDef.CAPTION_SEC + 0.01)
		expect(#t.crowd:captions()).toBe(0)
	end)

	it("chants use the duellist's display name; an AI duellist's stand chants a line without one", function()
		local t = boot()
		local s = state("duel")
		s.b = duellist(B, "loyal", "azure", true)
		t.crowd:onArenaState(s)
		t.crowd:onEvents({ { kind = "hype", side = "a", data = { full = true } } })
		t.env.mock:advance(Crowd.majorGapSec)
		t.crowd:onEvents({ { kind = "hype", side = "a", data = { full = true } } })
		expect(t.crowd:captions()[1]).toBe("Crimson Kingdom: Burn bright, Sam!")
		t.env.mock:advance(Crowd.majorGapSec)
		t.crowd:onEvents({ { kind = "hype", side = "b", data = { full = true } } })
		t.env.mock:advance(Crowd.majorGapSec)
		t.crowd:onEvents({ { kind = "hype", side = "b", data = { full = true } } })
		-- no name for the AI champion's stand
		expect(table.find(t.crowd:captions(), "Azure Kingdom: For the kingdom!") ~= nil).toBe(true)
	end)
end)

describe("FeedbackCrowdController: the ending (FL-0074 part 2a)", function()
	it("crowning plays the winner's ending once, even after an ended event", function()
		local t = boot()
		t.crowd:onArenaState(state("duel"))
		t.crowd:onArenaState(state("crowning", { winner = A }))
		expect(ids(t.plays)).toEqual({ "crowd.flood" }) -- a flood for adoring a; hostile b empties (no sound)
		expect(t.crowd:captions()).toEqual({
			"Crimson Kingdom: (The stand floods the arena to crown its ruler)",
			"Azure Kingdom: (The stand empties)",
		})
		t.crowd:onArenaState(state("crowning", { winner = A })) -- a repeated push
		expect(#t.plays).toBe(1)

		local e = boot()
		e.crowd:onArenaState(state("duel"))
		e.crowd:onEvents({ { kind = "ended", side = "b" } })
		e.crowd:onArenaState(state("crowning", { winner = B }))
		expect(ids(e.plays)).toEqual({ "crowd.salute", "crowd.scattered" }) -- adoring a salutes; hostile b: thin
		expect(#e.crowd:captions()).toBe(2)
	end)

	it("a crowning with no winner ends the crowd quietly", function()
		local t = boot()
		t.crowd:onArenaState(state("duel"))
		t.crowd:onArenaState(state("crowning"))
		expect(t.crowd:captions()).toEqual({
			"Crimson Kingdom: (The stand is quiet)",
			"Azure Kingdom: (The stand is quiet)",
		})
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(#t.plays).toBe(0)
	end)
end)

describe("FeedbackCrowdController: Studio preview and headless (FL-0074 part 2a)", function()
	it("the Studio preview plays the scripted duel, then stops; never outside Studio", function()
		local live = boot({ studio = false })
		expect(live.crowd:preview("adoring,hostile")).toBe(false)
		expect(live.crowd.director).toBeNil()

		local t = boot({ studio = true })
		expect(t.crowd:preview("adoring,hostile")).toBe(true)
		local now = t.env.clock()
		t.crowd:step(now + CrowdDef.PREVIEW_STEP_SEC) -- the heavy hit: both tiers from the attribute
		expect(t.crowd:captions()).toEqual({
			"Crimson Kingdom: (The crowd roars)",
			"Azure Kingdom: (The stand turns its back)",
		})
		for step = 2, #CrowdDef.PREVIEW + 1 do
			t.crowd:step(now + step * CrowdDef.PREVIEW_STEP_SEC)
		end
		local kinds = ids(t.plays)
		assert(table.find(kinds, "crowd.perk"), "the perk stinger plays")
		assert(table.find(kinds, "crowd.flood"), "the ending plays")
		expect(t.crowd:preview("")).toBe(true) -- stop
		expect(t.crowd:preview("adoring")).toBe(true) -- not a pair: stops, starts nothing
		expect(t.crowd.director).toBeNil()
		-- a real duel takes over, and the preview never interrupts one
		t.crowd:preview("loyal,divided")
		t.crowd:onArenaState(state("duel"))
		expect(t.crowd:preview("loyal,divided")).toBe(false)
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(t.crowd:captions()[1]).toBe("Crimson Kingdom: (The crowd roars)")
	end)

	it("without PlayerGui or AudioController it presents nothing and never errors", function()
		local t = boot({ noGui = true, noAudio = true })
		t.crowd:onArenaState(state("duel"))
		t.crowd:onEvents({ { kind = "parry", side = "a" } })
		expect(#t.crowd:captions()).toBe(2) -- the lines are kept for the HUD even with nowhere to draw
		t.crowd:step(t.env.clock() + 10)
		expect(#t.crowd:captions()).toBe(0)
		expect(t.env.mock.threadErrors).toEqual({})
	end)
end)
