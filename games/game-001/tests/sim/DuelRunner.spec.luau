--[[
	Arena/DuelRunner (FL-0071; CONTRACTS G12.2/G12.4): one duel as the server runs it. The caps check on the support, the
	geometry from real positions, the champions' actions (validation, rate limit, quiet refusal), a block that is never
	left held, AI hands, forfeits, and the shares-only relay of the duel's events.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local ArenaFlow = require("@game/ReplicatedStorage/Game/Arena/ArenaFlow")
local DuelRunner = require("@game/ReplicatedStorage/Game/Arena/DuelRunner")

local DuelRunnerAI = ArenaFlow.AI_USER_ID

local TICK = ArenaConfig.tick

local function human(userId: number, extra: any?)
	local side = { userId = userId, isAI = false, weapon = "swordShield", armour = "medium" }
	for k, v in extra or {} do
		side[k] = v
	end
	return side
end

local function ai(userId: number, skill: number?)
	return { userId = userId, isAI = true, weapon = "swordShield", armour = "medium", skill = skill or 0.5 }
end

local function newRunner(a: any, b: any, extra: any?)
	local logs = {}
	local setup = {
		a = a,
		b = b,
		seed = 5,
		log = function(level: string, message: string, fields: any)
			table.insert(logs, { level = level, message = message, fields = fields })
		end,
	}
	for k, v in extra or {} do
		setup[k] = v
	end
	return DuelRunner.new(setup), logs
end

-- advances `frames` ticks of real time, one tick per call; returns every relayed event
local function run(runner: any, clock: { t: number }, frames: number, each: ((number) -> ())?): { any }
	local out = {}
	for i = 1, frames do
		clock.t += TICK
		if each then
			each(i)
		end
		for _, event in runner:step(clock.t) do
			table.insert(out, event)
		end
	end
	return out
end

local function ofKind(events: { any }, kind: string): { any }
	local out = {}
	for _, e in events do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

describe("DuelRunner: actions", function()
	it(
		"refuses actions quietly before the duel starts, from strangers, from the AI's id, and for unknown actions",
		function()
			local runner = newRunner(human(1), human(2))
			local clock = { t = 0 }
			local ok, reason = runner:act(1, "light", 0)
			expect(ok).toBe(false)
			expect(reason).toBe("no_duel") -- the first step starts the duel
			runner:step(0)
			ok, reason = runner:act(77, "light", 0)
			expect(reason).toBe("not_champion")
			ok, reason = runner:act("1" :: any, "light", 0)
			expect(reason).toBe("not_champion")
			ok, reason = runner:act(1, "fireball", 0)
			expect(reason).toBe("bad_action")
			ok, reason = runner:act(1, 5 :: any, 0)
			expect(reason).toBe("bad_action")
			ok, reason = runner:act(1, "light", 0)
			expect(ok).toBe(true)
			expect(reason).toBeNil()
			local aiRunner = newRunner(human(1), ai(DuelRunnerAI.b))
			aiRunner:step(0)
			ok, reason = aiRunner:act(DuelRunnerAI.b, "light", 0)
			expect(reason).toBe("not_champion") -- nobody drives the AI from outside
			run(runner, clock, 2)
		end
	)

	it("rate limits a champion: a burst of 8, then 12 a second", function()
		local runner = newRunner(human(1), human(2))
		runner:step(0)
		local accepted = 0
		for _ = 1, 20 do
			if runner:act(1, "light", 0) then
				accepted += 1
			end
		end
		expect(accepted).toBe(ArenaConfig.rate.burst)
		local ok, reason = runner:act(1, "light", 0)
		expect(ok).toBe(false)
		expect(reason).toBe("rate_limited")
		expect((runner:act(1, "light", 1 / ArenaConfig.rate.perSecond + 0.001))).toBe(true) -- one token back
		expect((runner:act(2, "light", 0))).toBe(true) -- the other champion has a bucket of their own
		local later = 0
		for _ = 1, 20 do
			if runner:act(1, "light", 10) then
				later += 1
			end
		end
		expect(later).toBe(ArenaConfig.rate.burst) -- never more than the burst, however long the wait
	end)

	it("refuses actions after the duel is over", function()
		local runner = newRunner(ai(DuelRunnerAI.a, 1), ai(DuelRunnerAI.b, 0))
		local clock = { t = 0 }
		run(runner, clock, 2000)
		expect(runner:finished()).toBe(true)
		local ok, reason = runner:act(1, "light", clock.t)
		expect(ok).toBe(false)
		expect(reason).toBe("no_duel")
	end)

	it("a champion's action reaches the duel: a light swing lands as a hit event with shares only", function()
		local runner = newRunner(human(1), human(2))
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "light", 0)
		local events = run(runner, clock, 30)
		local hits = ofKind(events, "hit")
		expect(#hits).toBe(1)
		expect(hits[1].side).toBe("a")
		expect(hits[1].data.heavy).toBe(false)
		expect(hits[1].data.damageShare > 0 and hits[1].data.damageShare < 0.1).toBe(true)
		expect(hits[1].data.hpShare < 1 and hits[1].data.hpShare > 0.9).toBe(true)
		expect(hits[1].data.damage).toBeNil() -- raw HP never leaves the server
		expect(hits[1].data.targetHp).toBeNil()
	end)
end)

describe("DuelRunner: geometry", function()
	local function poses(a: any, b: any)
		return function(userId: number)
			if userId == 1 then
				return a
			end
			return b
		end
	end

	local function swingOnce(pose: any, aSide: any?, bSide: any?)
		local runner = newRunner(aSide or human(1), bSide or human(2), { pose = pose })
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "light", 0)
		local events = run(runner, clock, 30)
		local mine = 0
		for _, hit in ofKind(events, "hit") do
			if hit.side == "a" then -- an AI opponent swings back; only the swing under test counts
				mine += 1
			end
		end
		return mine, runner
	end

	it("lands a swing when the duellists are close enough and facing each other", function()
		local hits = swingOnce(poses({ x = 0, z = 0, fx = 1, fz = 0 }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(hits).toBe(1)
	end)

	it("a swing from too far away, or facing away, misses", function()
		local reach = ArenaConfig.reach
		local far = swingOnce(poses({ x = 0, z = 0, fx = 1, fz = 0 }, { x = reach + 1, z = 0, fx = -1, fz = 0 }))
		expect(far).toBe(0)
		local edge = swingOnce(poses({ x = 0, z = 0, fx = 1, fz = 0 }, { x = reach - 0.1, z = 0, fx = -1, fz = 0 }))
		expect(edge).toBe(1)
		local away = swingOnce(poses({ x = 0, z = 0, fx = -1, fz = 0 }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(away).toBe(0)
		local side = swingOnce(poses({ x = 0, z = 0, fx = 0, fz = 1 }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(side).toBe(0) -- at 90 degrees: below the facing bar
	end)

	it("a swing 45 degrees off the line still lands: the bar is a cone, not a line", function()
		local d = math.sqrt(0.5)
		local hits = swingOnce(poses({ x = 0, z = 0, fx = d, fz = d }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(hits).toBe(1)
	end)

	it("the same position is in range and facing; a human the world cannot find cannot hit", function()
		local same = swingOnce(poses({ x = 3, z = 3, fx = 1, fz = 0 }, { x = 3, z = 3, fx = 1, fz = 0 }))
		expect(same).toBe(1)
		local lost = swingOnce(function(userId: number)
			if userId == 2 then
				return { x = 0, z = 0, fx = 1, fz = 0 }
			end
			return nil
		end)
		expect(lost).toBe(0)
		local lostOpponent = swingOnce(function(userId: number)
			if userId == 1 then
				return { x = 0, z = 0, fx = 1, fz = 0 }
			end
			return nil
		end)
		expect(lostOpponent).toBe(0) -- the opponent cannot be found either
	end)

	it("a facing vector shorter than a unit vector still faces; a zero one does not", function()
		local pitched = swingOnce(poses({ x = 0, z = 0, fx = 0.4, fz = 0 }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(pitched).toBe(1)
		local zero = swingOnce(poses({ x = 0, z = 0, fx = 0, fz = 0 }, { x = 4, z = 0, fx = -1, fz = 0 }))
		expect(zero).toBe(0)
	end)

	it("a swing that misses is not relayed (miss and dodged stay inside)", function()
		local runner = newRunner(
			human(1),
			human(2),
			{ pose = poses({ x = 0, z = 0, fx = 1, fz = 0 }, { x = 99, z = 0, fx = -1, fz = 0 }) }
		)
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "light", 0)
		local events = run(runner, clock, 30)
		expect(#ofKind(events, "hit")).toBe(0)
		expect(#ofKind(events, "miss")).toBe(0)
		expect(#ofKind(events, "dodged")).toBe(0)
	end)

	it("an AI has no body: against one the duel is virtual, as it is with no pose provider at all", function()
		local vs = swingOnce(function(userId: number)
			if userId == 1 then
				return { x = 0, z = 0, fx = 1, fz = 0 }
			end
			return nil
		end, nil, ai(DuelRunnerAI.b))
		expect(vs).toBe(1)
		local noPose = swingOnce(nil)
		expect(noPose).toBe(1)
	end)
end)

describe("DuelRunner: the caps on support", function()
	local function reforge()
		return {
			{
				source = "perk:reforge",
				kind = "trigger",
				stat = "damageReduction",
				magnitude = 0.06,
				duration = 6,
				condition = "hpBelow:0.5",
			},
		}
	end

	it("runs a list within the caps as given", function()
		local runner, logs = newRunner(human(1, { modifiers = reforge() }), human(2))
		expect(#logs).toBe(0)
		expect(runner._model.a.triggers[1].source).toBe("perk:reforge")
	end)

	it("drops the perks, keeps the tier's blessing, and logs, when the whole list breaks a cap", function()
		local list = {
			{ source = "tier:adoring", kind = "passive", stat = "damageReduction", magnitude = 0.01 },
			{
				source = "perk:greedy",
				kind = "trigger",
				stat = "damage",
				magnitude = 0.5,
				duration = 6,
				condition = "hype",
			},
		}
		local runner, logs = newRunner(human(1, { modifiers = list }), human(2))
		expect(#logs).toBe(1)
		expect(logs[1].level).toBe("warn")
		expect(logs[1].fields.who).toBe("a")
		expect(#runner._model.a.triggers).toBe(0) -- the perk is gone
		expect(runner._model.a.passive.damageReduction).toBe(0.01) -- the tier's blessing stays
	end)

	it(
		"drops everything when even the blessing breaks a cap, and never throws on a trigger with no condition",
		function()
			local runner, logs = newRunner(
				human(1, { modifiers = { { source = "tier:x", kind = "passive", stat = "damage", magnitude = 0.9 } } }),
				human(2, {
					modifiers = {
						{
							source = "perk:broken",
							kind = "trigger",
							stat = "damage",
							magnitude = 0.05,
							duration = 4,
						},
					},
				})
			)
			expect(#logs).toBe(2)
			expect(runner._model.a.passive.damage).toBe(0)
			local clock = { t = 0 }
			runner:step(0)
			run(runner, clock, 600)
		end
	)

	it("a slotted passive is a perk: dropped with them, not kept as a blessing", function()
		local list = {
			{ source = "perk:fineWares", kind = "passive", stat = "damageReduction", magnitude = 0.02, slot = true },
			{
				source = "perk:greedy",
				kind = "trigger",
				stat = "damage",
				magnitude = 0.5,
				duration = 6,
				condition = "hype",
			},
		}
		local runner = newRunner(human(1, { modifiers = list }), human(2))
		expect(runner._model.a.passive.damageReduction).toBe(0)
	end)
end)

describe("DuelRunner: time", function()
	it("steps in fixed ticks: the same real time gives the same duel whatever the frame rate", function()
		local function play(frame: number)
			local runner = newRunner(ai(-1, 0.7), ai(-2, 0.3))
			local clock = { t = 0 }
			runner:step(0)
			local steps = math.floor(8 / frame)
			for _ = 1, steps do
				clock.t += frame
				runner:step(clock.t)
			end
			local snap = runner:snapshot()
			return string.format("%.1f %.1f %.2f", snap.a.hp, snap.b.hp, snap.t)
		end
		-- one tick per call and two ticks per call carry the same real time through the same fixed ticks
		expect(play(TICK)).toBe(play(2 * TICK))
		expect(play(TICK)).toBe(play(TICK))
	end)

	it("never catches up on more than maxCatchup seconds at once: a stall does not fast-forward the duel", function()
		local runner = newRunner(human(1), human(2))
		runner:step(0)
		runner:step(100) -- a 100 s stall
		expect(runner:snapshot().t <= ArenaConfig.maxCatchup + TICK).toBe(true)
		expect(runner:finished()).toBe(false)
	end)

	it("the first step only starts the clock", function()
		local runner = newRunner(human(1), human(2))
		expect(#runner:step(1000)).toBe(0)
		expect(runner:snapshot().t).toBe(0)
		runner:step(1000 + TICK) -- the next step counts from the first, not from zero
		expect(runner:snapshot().t <= 2 * TICK).toBe(true)
	end)

	it("sends a public snapshot every snapshotEvery duel seconds, and never after the end", function()
		local runner = newRunner(human(1), human(2))
		local clock = { t = 0 }
		runner:step(0)
		local events = run(runner, clock, 90) -- 3 s
		local snapshots = ofKind(events, "snapshot")
		expect(#snapshots >= 14 and #snapshots <= 16).toBe(true)
		expect(snapshots[1].side).toBe("a")
		expect(snapshots[1].data.a.hpShare).toBe(1)
		expect(snapshots[1].data.a.staminaShare).toBe(1)
		expect(snapshots[1].data.triggers).toBeNil()
		expect(snapshots[1].data.a.hp).toBeNil() -- shares only
		expect(snapshots[1].data.a.stamina).toBeNil()
		expect(snapshots[1].data.ended).toBeNil()
	end)
end)

describe("DuelRunner: a champion the world cannot find", function()
	local function located(lost: { [number]: boolean })
		return function(userId: number)
			if lost[userId] then
				return nil
			end
			return { x = if userId == 1 then 0 else 4, z = 0, fx = if userId == 1 then 1 else -1, fz = 0 }
		end
	end

	it("pauses the duel, and a pose that returns resumes it", function()
		local lost: { [number]: boolean } = {}
		local runner = newRunner(human(1), human(2), { pose = located(lost) })
		local clock = { t = 0 }
		runner:step(0)
		run(runner, clock, 30)
		local before = runner:snapshot().t
		lost[1] = true
		run(runner, clock, 30 * (ArenaConfig.poseGraceSeconds - 2))
		expect(runner:snapshot().t).toBe(before)
		expect(runner:finished()).toBe(false)
		lost[1] = nil
		run(runner, clock, 30)
		expect(runner:snapshot().t > before).toBe(true)
		-- the grace starts again after a pose came back
		lost[1] = true
		run(runner, clock, 30 * (ArenaConfig.poseGraceSeconds - 2))
		expect(runner:finished()).toBe(false)
	end)

	it("forfeits that champion once the grace runs out, and still takes their Arena.Action", function()
		local lost: { [number]: boolean } = { [1] = true }
		local runner = newRunner(human(1), human(2), { pose = located(lost) })
		local clock = { t = 0 }
		runner:step(0)
		local ok = runner:act(1, "light", 0)
		expect(ok).toBe(true)
		local events = run(runner, clock, 30 * (ArenaConfig.poseGraceSeconds + 1))
		local side, reason = runner:result()
		expect(side).toBe("b")
		expect(reason).toBe("forfeit")
		expect(#ofKind(events, "ended")).toBe(1)
		expect(runner:snapshot().t).toBe(0) -- the duel itself never ran
	end)

	it("both champions lost together is a draw", function()
		local runner = newRunner(human(1), human(2), { pose = located({ [1] = true, [2] = true }) })
		local clock = { t = 0 }
		runner:step(0)
		run(runner, clock, 30 * (ArenaConfig.poseGraceSeconds + 1))
		local side = runner:result()
		expect(side).toBe("draw")
	end)

	it("an AI champion needs no pose and never pauses the duel", function()
		local runner = newRunner(human(1), ai(DuelRunnerAI.b, 1), { pose = located({ [DuelRunnerAI.b] = true }) })
		local clock = { t = 0 }
		runner:step(0)
		run(runner, clock, 30)
		expect(runner:snapshot().t > 0.5).toBe(true)
	end)
end)

describe("DuelRunner: blocks", function()
	it("releases a block the client never ends", function()
		local runner = newRunner(human(1), human(2))
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "block", 0)
		run(runner, clock, 6)
		expect(runner:snapshot().a.state).toBe("block")
		run(runner, clock, math.ceil(ArenaConfig.blockMaxSeconds / TICK) + 6)
		expect(runner:snapshot().a.state).toBe("idle")
	end)

	it("a block held for less than the limit stays up, and a fresh block starts a fresh clock", function()
		local runner = newRunner(human(1), human(2))
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "block", 0)
		run(runner, clock, math.floor((ArenaConfig.blockMaxSeconds - 0.5) / TICK))
		expect(runner:snapshot().a.state).toBe("block")
		runner:act(1, "blockEnd", clock.t)
		run(runner, clock, 6)
		expect(runner:snapshot().a.state).toBe("idle")
		runner:act(1, "block", clock.t)
		run(runner, clock, math.floor((ArenaConfig.blockMaxSeconds - 0.5) / TICK))
		expect(runner:snapshot().a.state).toBe("block")
	end)
end)

describe("DuelRunner: AI hands and the end", function()
	it("two AI champions play a duel to the end, and the ended event names the winner and the reason", function()
		local runner = newRunner(ai(-1, 0.9), ai(-2, 0.1))
		local clock = { t = 0 }
		runner:step(0)
		local events = run(runner, clock, 6000)
		expect(runner:finished()).toBe(true)
		local ended = ofKind(events, "ended")
		expect(#ended).toBe(1)
		local side, reason = runner:result()
		expect(ended[1].side).toBe(side)
		expect(ended[1].data.reason).toBe(reason)
		expect(side == "a" or side == "b" or side == "draw").toBe(true)
		expect(#ofKind(runner:step(clock.t + 1), "snapshot")).toBe(0)
		for _, snapshot in ofKind(events, "snapshot") do
			expect(snapshot.t < ended[1].t).toBe(true) -- the last word is "ended"
		end
	end)

	it("the last word is ended: no snapshot follows it, even when one is due that very tick", function()
		local config = table.clone(ArenaConfig)
		config.snapshotEvery = 0 -- a snapshot is due on every tick
		local runner = DuelRunner.new({ a = human(1), b = human(2), seed = 3 }, config)
		runner._model.b.hp = 1 -- one light hit ends it
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "light", 0)
		local events = run(runner, clock, 30)
		expect(runner:finished()).toBe(true)
		expect(events[#events].kind).toBe("ended")
		local ended = 0
		for _, event in events do
			if event.kind == "ended" then
				ended += 1
			end
		end
		expect(ended).toBe(1)
	end)

	it("relays only the contract's kinds: no miss, no dodged, no raw sources", function()
		local runner = newRunner(ai(-1, 0.6), ai(-2, 0.6))
		local clock = { t = 0 }
		runner:step(0)
		local events = run(runner, clock, 4000)
		local allowed = {
			hit = true,
			heavyWindup = true,
			parry = true,
			stagger = true,
			staminaOut = true,
			hype = true,
			triggerFired = true,
			ended = true,
			snapshot = true,
		}
		for _, event in events do
			expect(allowed[event.kind]).toBe(true)
			expect(event.side == "a" or event.side == "b" or event.side == "draw").toBe(true)
		end
		for _, windup in ofKind(events, "heavyWindup") do
			expect(windup.data.impactIn > 0).toBe(true)
			expect(windup.data.impactAt).toBeNil()
		end
	end)

	it("a fired trigger is relayed by id with the citizen behind it, and the Crowd Rally has no citizen", function()
		local fires = {
			{ source = "perk:fieldRemedy", kind = "heal", magnitude = 0.05, duration = 4, condition = "hpBelow:0.99" },
		}
		local runner = newRunner(
			human(1),
			human(2, { modifiers = fires, triggerCitizens = { fieldRemedy = { name = "Bram", role = "healer" } } })
		)
		local clock = { t = 0 }
		runner:step(0)
		runner:act(1, "light", 0)
		local events = run(runner, clock, math.ceil(12 / TICK))
		local fired = ofKind(events, "triggerFired")
		expect(#fired).toBe(1)
		expect(fired[1].side).toBe("b")
		expect(fired[1].data.trigger).toBe("fieldRemedy")
		expect(fired[1].data.citizenName).toBe("Bram")
		expect(fired[1].t >= 10).toBe(true) -- the quiet start
		local rally = newRunner(
			human(1),
			human(2, {
				modifiers = {
					{
						source = "crowdRally",
						kind = "trigger",
						stat = "damageReduction",
						magnitude = 0.05,
						duration = 5,
						condition = "hpBelow:0.99",
					},
				},
			})
		)
		local c2 = { t = 0 }
		rally:step(0)
		rally:act(1, "light", 0)
		local rallyFired = ofKind(run(rally, c2, math.ceil(12 / TICK)), "triggerFired")
		expect(rallyFired[1].data.trigger).toBe("crowdRally")
		expect(rallyFired[1].data.citizenName).toBeNil()
	end)

	it("the same setup gives the same duel", function()
		local function play()
			local runner = newRunner(ai(-1, 0.5), ai(-2, 0.5))
			local clock = { t = 0 }
			runner:step(0)
			local events = run(runner, clock, 3000)
			local parts = {}
			for _, e in events do
				if e.kind ~= "snapshot" then
					table.insert(parts, `{e.kind}:{e.side}:{string.format("%.2f", e.t)}`)
				end
			end
			return table.concat(parts, "|")
		end
		expect(play()).toBe(play())
	end)
end)

describe("DuelRunner: forfeits", function()
	it("a champion who leaves loses: the other side wins, with a forfeit ending", function()
		local runner = newRunner(human(1), human(2))
		local clock = { t = 0 }
		runner:step(0)
		run(runner, clock, 30)
		local events = runner:forfeit(1, clock.t)
		expect(#events).toBe(1)
		expect(events[1].kind).toBe("ended")
		expect(events[1].side).toBe("b")
		expect(events[1].data.reason).toBe("forfeit")
		local side, reason = runner:result()
		expect(side).toBe("b")
		expect(reason).toBe("forfeit")
		expect(runner:finished()).toBe(true)
		expect(#runner:forfeit(1, clock.t)).toBe(0) -- already over
		expect(#runner:step(clock.t + 1)).toBe(0)
	end)

	it("both champions gone is a draw; a stranger leaving changes nothing", function()
		local runner = newRunner(human(1), human(2))
		runner:step(0)
		expect(#runner:forfeit(77, 0)).toBe(0)
		expect(runner:finished()).toBe(false)
		expect(runner:forfeit(1, 1)[1].side).toBe("b")
		expect(#runner:forfeit(1, 1.1)).toBe(0) -- the one who already left cannot make it a draw
		expect(#runner:forfeit(77, 1.1)).toBe(0)
		local events = runner:forfeit(2, 1 + ArenaConfig.simultaneousSeconds) -- the same moment
		expect(#events).toBe(1)
		expect(events[1].side).toBe("draw")
		local side, reason = runner:result()
		expect(side).toBe("draw")
		expect(reason).toBe("forfeit")
	end)

	it("the winner leaving after the moment has passed changes nothing", function()
		local runner = newRunner(human(1), human(2))
		runner:step(0)
		runner:forfeit(1, 1)
		expect(#runner:forfeit(2, 1 + ArenaConfig.simultaneousSeconds + 0.01)).toBe(0)
		expect((runner:result())).toBe("b")
	end)

	it("an AI cannot forfeit", function()
		local runner = newRunner(human(1), ai(DuelRunnerAI.b))
		runner:step(0)
		expect(#runner:forfeit(DuelRunnerAI.b, 0)).toBe(0)
		expect(runner:finished()).toBe(false)
	end)
end)
