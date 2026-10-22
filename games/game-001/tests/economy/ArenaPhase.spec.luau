-- D-059 arena pass: the phase pill while the Crown Arena runs. The match waits in Endgame with its clock at 0 (CONTRACTS
-- G3), so without the arena's state the pill read "Endgame 0:00 left, next Results" through the vote, the loadout and
-- the crowning. HudModel.timer names the arena's stage and its own clock; ArenaHudController passes every ArenaState
-- to KingdomHudController:setArenaState.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArenaIntroDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaIntroController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")
local HudModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/HudModel")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local world, previous = nil, nil
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

describe("HudModel.timer: the Crown Arena's stage", function()
	it("names the arena, the stage and the stage's own clock while a stage runs", function()
		local match = { phase = "Endgame", endsAt = 100 } -- the spent Endgame clock the server answers
		local t = HudModel.timer(match, 100, { stage = "vote", endsAt = 109 })
		expect(t.phase).toBe("Crown Arena")
		expect(t.label).toBe("Choosing champions")
		expect(t.clock).toBe("0:09")
		expect(t.step).toBeNil() -- no phase track: the arena is not a phase on it
		expect(t.next).toBeNil() -- never "next: Results" while the arena runs
		for stage, word in HudModel.ARENA_STAGES do
			expect(HudModel.timer(match, 100, { stage = stage, endsAt = 90 }).label).toBe(word)
			expect(HudModel.timer(match, 100, { stage = stage, endsAt = 90 }).clock).toBe("0:00") -- never negative
		end
		expect(HudModel.timer(match, 100, { stage = "crowning" }).clock).toBeNil()
	end)

	it("keeps the phase's own pill outside a running stage, and at Results", function()
		local match = { phase = "Endgame", endsAt = 160 }
		expect(HudModel.timer(match, 100, nil).phase).toBe(HudModel.timer(match, 100).phase)
		expect(HudModel.timer(match, 100, { stage = "done" }).label).toBe("left")
		expect(HudModel.timer(match, 100, { stage = "qualify" }).label).toBe("left")
		local results = HudModel.timer({ phase = "Results", endsAt = 130 }, 100, { stage = "crowning", endsAt = 110 })
		expect(results.phase).never.toBe("Crown Arena")
	end)
end)

describe("Kingdom HUD: the phase pill during the Crown Arena", function()
	it("reads the arena's stage from ArenaHudController, then goes back to the phase", function()
		world = KingdomWorld.new({
			remotes = ArenaDoubles.REMOTES,
			services = { ArenaDoubles.service },
			clientDefinitions = { KingdomHudDef, DuelDef, ArenaHudDef },
		})
		local hud = world.client:get("KingdomHudController")
		hud:setViewport(1920, 1022)
		local now = world.env.serverTimeNow()
		world.match:setPhase("Endgame", now) -- the arena runs: Endgame's clock is spent
		world:advance(0.3)
		local server = world.server:get("ArenaDouble")
		server:setState({ stage = "vote", endsAt = world.env.serverTimeNow() + 9 })
		world:advance(0.5)
		local timer = find(hud.guis.topbar, "Timer")
		expect(find(timer, "Phase").Text).toBe("CROWN ARENA")
		expect(find(timer, "Label").Text).toBe("Choosing champions")
		expect(find(timer, "Clock").Text).toBe("0:09") -- 8.5 s left: the clock rounds up, as every countdown here
		server:setState({ stage = "crowning", endsAt = world.env.serverTimeNow() + 15 })
		world:advance(0.5)
		expect(find(timer, "Label").Text).toBe("Crowning")
		server:setState({ stage = "done" })
		world:advance(0.5)
		expect(find(timer, "Phase").Text).toBe("ENDGAME")
	end)
end)

local function arenaWorld()
	local w = KingdomWorld.new({
		remotes = ArenaDoubles.REMOTES,
		services = { ArenaDoubles.service },
		clientDefinitions = { KingdomHudDef, DuelDef, ArenaHudDef, ArenaIntroDef },
	})
	w.hud = w.client:get("KingdomHudController")
	w.arena = w.client:get("ArenaHudController")
	w.intro = w.client:get("ArenaIntroController")
	w.arenaServer = w.server:get("ArenaDouble")
	w.hud:setViewport(1920, 1022)
	w.match:setPhase("Endgame", w.env.serverTimeNow())
	w:advance(0.3)
	return w
end

local function duellists(D)
	return D.duellist(1, "crimson", "adoring", { weapon = "spear", armour = "light", triggers = {} }),
		D.duellist(7, "azure", "divided", { weapon = "mace", armour = "heavy", triggers = {} })
end

describe("Crown Arena: the intro's ring shot and the crowning (D-059 arena pass)", function()
	it("the versus card steps aside for the intro's last shot, the ring", function()
		world = arenaWorld()
		local a, b = duellists(ArenaDoubles)
		world.arenaServer:setState({ stage = "intro", endsAt = world.env.serverTimeNow() + 12, a = a, b = b })
		world:advance(0.6)
		expect(world.intro:model()).never.toBeNil()
		expect(world.intro.view.instance).never.toBeNil()
		world:advance(12 - world.intro.RING_SEC - 0.6 + 0.2) -- into the ring shot
		expect(world.intro:model()).toBeNil()
		expect(world.intro.view.instance).toBeNil()
		expect(world.intro.RING_SEC > 0 and world.intro.RING_SEC < 12).toBe(true)
	end)

	it("names the kingdom that takes the crown once, when the crowning starts", function()
		world = arenaWorld()
		local shown = {}
		local notify = world.hud.notify
		world.hud.notify = function(self, toast)
			table.insert(shown, toast)
			return notify(self, toast)
		end
		local a, b = duellists(ArenaDoubles)
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 40, a = a, b = b })
		world:advance(0.3)
		local crowning = { stage = "crowning", endsAt = world.env.serverTimeNow() + 15, winner = 1, a = a, b = b }
		world.arenaServer:setState(crowning)
		world:advance(0.3)
		world.arenaServer:setState(crowning) -- a second push of the same stage: no second toast
		world:advance(0.3)
		local crowns = {}
		for _, toast in shown do
			if string.find(toast.title or "", "takes the crown", 1, true) then
				table.insert(crowns, toast)
			end
		end
		expect(#crowns).toBe(1)
		local mineName = world.hud.store:mine().name
		expect(crowns[1].title).toBe(`{mineName} takes the crown`)
		expect(crowns[1].kind).toBe("achievement")
		expect(crowns[1].body).toBe("Your champion won the duel")
		-- the other side, a coronation without a duel, and a draw
		local theirs = world.arena:crownToast({ stage = "crowning", winner = 7, a = a, b = b })
		expect(theirs.kind).toBe("info")
		expect(theirs.body).toBe("Their champion won the duel")
		expect(world.arena:crownToast({ stage = "crowning", coronation = "azure" }).body).toBe("Crowned without a duel")
		expect(world.arena:crownToast({ stage = "crowning", a = a, b = b })).toBeNil()
	end)
end)
