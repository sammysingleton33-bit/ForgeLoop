local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local roblox = require("@lune/roblox")
local DuelPoses = require("@game/ReplicatedStorage/Game/Feedback/DuelPoses")
local DuelRig = require("@game/ReplicatedStorage/Game/Feedback/DuelRig")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Duel = require("@game/ReplicatedStorage/Forge/Config/Duel")

local NOW = 100

local function snapshot(a, b)
	local data = {}
	if a then
		data.a = { state = a, weapon = "swordShield" }
	end
	if b then
		data.b = { state = b, weapon = "swordShield" }
	end
	return { kind = "snapshot", side = "a", data = data }
end

local function sample(track, t, motion)
	return track:sample(t, { weight = 0, body = 0 }, motion)
end

-- Samples every 60 Hz frame from t0 to t1, as the game does (a crossfade starts at the first frame that
-- sees a change); returns the last frame's output.
local function run(track, t0, t1, motion)
	local out = { weight = 0, body = 0 }
	local t = t0
	while t < t1 do
		track:sample(t, out, motion)
		t += 1 / 60
	end
	return track:sample(t1, out, motion)
end

-- the angle (degrees) between two directions
local function angle(u: Vector3, v: Vector3): number
	return math.deg(math.acos(math.clamp(u.Unit:Dot(v.Unit), -1, 1)))
end

describe("DuelPoses: Arena.Events → each champion's animation (FL-0141)", function()
	it("a snapshot windup plays a light swing; a second windup sample of the same swing changes nothing", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent(snapshot("windup", "idle"), NOW)
		expect(duel.a.name).toBe("light")
		expect(duel.b.name).toBeNil()
		local started = duel.a._anim.start
		duel:onEvent(snapshot("windup", "idle"), NOW + 0.2)
		expect(duel.a._anim.start).toBe(started)
		-- a later swing: the first one has ended, so the next windup starts a new one
		duel:onEvent(snapshot("idle", "idle"), NOW + 0.4)
		duel:onEvent(snapshot("windup", "idle"), NOW + 0.6)
		expect(duel.a.name).toBe("light")
		expect(duel.a._anim.start).toBe(NOW + 0.6)
	end)

	it("the hit jumps a winding-up swing to its strike; recover first starts one at its strike", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent(snapshot("windup", nil), NOW)
		duel:onEvent(
			{ kind = "hit", side = "a", data = { heavy = false, damageShare = 0.06, hpShare = 0.94 } },
			NOW + 0.05
		)
		local anim = duel.a._anim
		expect(math.abs(anim.start - (NOW + 0.05 - DuelPoses.LIGHT_WINDUP)) < 1e-9).toBe(true)
		-- a swing whose windup no snapshot saw: the recover state starts it at the strike
		local late = DuelPoses.newDuel()
		late:start(NOW)
		late:onEvent(snapshot("recover", nil), NOW)
		expect(late.a.name).toBe("light")
		expect(math.abs(late.a._anim.start - (NOW - DuelPoses.LIGHT_WINDUP)) < 1e-9).toBe(true)
		-- ... but a recover sample right after that strike is the same swing, not a new one
		local start = late.a._anim.start
		late:onEvent(snapshot("recover", nil), NOW + 0.2)
		expect(late.a._anim.start).toBe(start)
		late:onEvent(snapshot("idle", nil), NOW + 0.3)
		late:onEvent(snapshot("recover", nil), NOW + 0.45) -- the swing has ended, still the same strike
		expect(late.a.name).toBeNil()
	end)

	it("heavyWindup holds the wind-up for impactIn, then the hit strikes; the snapshot windup adds no light", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent({ kind = "heavyWindup", side = "b", data = { impactIn = 0.9, warned = 0 } }, NOW)
		duel:onEvent(snapshot(nil, "windup"), NOW) -- the same tick: the relay's events come first
		expect(duel.b.name).toBe("heavy")
		expect(duel.b._anim.windup).toBe(0.9)
		-- the hit arrives early (the wind-up seen late): the strike jumps to now
		duel:onEvent(
			{ kind = "hit", side = "b", data = { heavy = true, damageShare = 0.14, hpShare = 0.7 } },
			NOW + 0.7
		)
		expect(math.abs(duel.b._anim.start - (NOW + 0.7 - 0.9)) < 1e-9).toBe(true)
		-- impactIn out of range is clamped; a missing one is the default
		duel:reset()
		duel:start(NOW)
		duel:onEvent({ kind = "heavyWindup", side = "a", data = { impactIn = 30 } }, NOW)
		expect(duel.a._anim.windup).toBe(DuelPoses.HEAVY_WINDUP.max)
		duel:onEvent({ kind = "heavyWindup", side = "b" }, NOW)
		expect(duel.b._anim.windup).toBe(DuelPoses.HEAVY_WINDUP.default)
	end)

	it("the target of a hit flinches (bigger for a heavy); while blocking its guard jolts instead", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent({ kind = "hit", side = "a", data = { heavy = false } }, NOW)
		expect(duel.b.name).toBe("flinch")
		duel:onEvent({ kind = "hit", side = "a", data = { heavy = true } }, NOW + 1)
		expect(duel.b.name).toBe("flinchHeavy")
		duel:onEvent(snapshot(nil, "block"), NOW + 2)
		expect(duel.b.name).toBe("block")
		duel:onEvent({ kind = "hit", side = "a", data = { heavy = true } }, NOW + 2.1)
		expect(duel.b.name).toBe("guardHit")
		-- after the jolt the guard is held again, already raised: no dip to the ready stance
		local raised = run(duel.b, NOW + 2.1, NOW + 2.1 + DuelPoses.LENGTH.guardHit + 0.05).pose.LeftArm
		expect(duel.b.name).toBe("block")
		local _, lifted = raised:ToAxisAngle()
		expect(math.deg(lifted) > 80).toBe(true) -- the shield arm still up (block: 95° forward)
		-- the block ends with the state
		duel:onEvent(snapshot(nil, "idle"), NOW + 3)
		sample(duel.b, NOW + 3)
		expect(duel.b.name).toBeNil()
	end)

	it("parry, dodge and stagger: from the state and from their events; dodges go left, then right", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent(snapshot("parry", nil), NOW)
		expect(duel.a.name).toBe("parry")
		local first = duel.a._anim
		duel:onEvent({ kind = "parry", side = "a" }, NOW + 0.05) -- the same moment: kept
		expect(duel.a._anim).toBe(first)
		duel:onEvent({ kind = "parry", side = "a" }, NOW + 0.2) -- the deflect: played again
		expect(duel.a._anim ~= first).toBe(true)
		duel:onEvent({ kind = "stagger", side = "b" }, NOW + 0.2)
		expect(duel.b.name).toBe("stagger")
		local dodges = DuelPoses.newDuel()
		dodges:start(NOW)
		dodges:onEvent(snapshot("dodge", nil), NOW)
		local left = run(dodges.a, NOW, NOW + 0.12).pose.Root.Position.X -- the sidestep's peak
		dodges:onEvent(snapshot("idle", nil), NOW + 0.5)
		dodges:onEvent(snapshot("dodge", nil), NOW + 1)
		run(dodges.a, NOW + 0.12, NOW + 1)
		local right = run(dodges.a, NOW + 1, NOW + 1.12).pose.Root.Position.X
		expect(math.abs(left + 1.1) < 1e-6).toBe(true) -- 1.1 studs to the left
		expect(math.abs(right - 1.1) < 1e-6).toBe(true) -- then to the right
	end)

	it("priorities: a stagger cuts a swing; a flinch never cuts a swing; a swing cuts a flinch", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent({ kind = "heavyWindup", side = "a", data = { impactIn = 0.8 } }, NOW)
		duel:onEvent({ kind = "hit", side = "b", data = { heavy = false } }, NOW + 0.1) -- a is hit mid wind-up
		expect(duel.a.name).toBe("heavy")
		duel:onEvent({ kind = "parry", side = "b" }, NOW + 0.8)
		duel:onEvent({ kind = "stagger", side = "a" }, NOW + 0.8)
		expect(duel.a.name).toBe("stagger")
		duel:onEvent(snapshot("windup", nil), NOW + 1) -- the server would not let it attack while staggered
		expect(duel.a.name).toBe("stagger")
		duel:onEvent({ kind = "hit", side = "a", data = { heavy = false } }, NOW + 3)
		expect(duel.b.name).toBe("flinch")
		duel:onEvent(snapshot(nil, "windup"), NOW + 3.05) -- b swings back at once
		expect(duel.b.name).toBe("light")
	end)

	it("the end: KO kneels the loser and raises the winner's weapon; nothing starts after", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent({ kind = "ended", side = "a", data = { reason = "ko" } }, NOW)
		expect(duel.a.name).toBe("victory")
		expect(duel.b.name).toBe("ko")
		duel:onEvent(snapshot("windup", "dodge"), NOW + 0.5)
		duel:onEvent({ kind = "hit", side = "a", data = { heavy = true } }, NOW + 0.5)
		expect(duel.a.name).toBe("victory")
		expect(duel.b.name).toBe("ko")
		-- the ending holds, then fades out
		local out = run(duel.b, NOW, NOW + DuelPoses.LENGTH.ko + 1)
		expect(out.weight).toBe(1)
		expect(out.body).toBe(1)
		local gone =
			run(duel.b, NOW + DuelPoses.LENGTH.ko + 1, NOW + DuelPoses.LENGTH.ko + DuelPoses.HOLD.ko + DuelPoses.XFADE)
		expect(gone.weight).toBe(0)
		-- after the winner's pose has held and faded, still nothing starts
		local after = NOW + DuelPoses.LENGTH.victory + DuelPoses.HOLD.victory + 1
		run(duel.a, NOW, after)
		expect(duel.a.name).toBeNil()
		duel:onEvent({ kind = "heavyWindup", side = "a", data = { impactIn = 0.8 } }, after)
		duel:onEvent({ kind = "parry", side = "a" }, after)
		expect(duel.a.name).toBeNil()
		-- time cap: the loser yields; a double KO: both slump; a forfeit: the one who stayed wins
		local cap = DuelPoses.newDuel()
		cap:onEvent({ kind = "ended", side = "b", data = { reason = "timeCap" } }, NOW)
		expect(cap.a.name).toBe("yield")
		expect(cap.b.name).toBe("victory")
		local draw = DuelPoses.newDuel()
		draw:onEvent({ kind = "ended", side = "draw", data = { reason = "draw" } }, NOW)
		expect(draw.a.name).toBe("ko")
		expect(draw.b.name).toBe("ko")
		local hardCap = DuelPoses.newDuel()
		hardCap:onEvent(snapshot("block", nil), NOW)
		hardCap:onEvent({ kind = "ended", side = "draw", data = { reason = "hardCap" } }, NOW)
		expect(hardCap.a.name).toBeNil()
		expect(hardCap.a.final).toBe(true)
		local forfeit = DuelPoses.newDuel()
		forfeit:onEvent({ kind = "ended", side = "b", data = { reason = "forfeit" } }, NOW)
		expect(forfeit.b.name).toBe("victory")
		expect(forfeit.a.name).toBeNil()
	end)

	it("a late joiner starts from the next snapshot; unknown or malformed events change nothing", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		for _, junk in
			{
				nil,
				"hit",
				{},
				{ kind = 4 },
				{ kind = "hit" },
				{ kind = "hit", side = "c" },
				{ kind = "snapshot", side = "a" },
				{ kind = "snapshot", side = "a", data = { a = "x" } },
				{ kind = "hype", side = "a" },
				{ kind = "triggerFired", side = "b", data = { trigger = "reforge" } },
				{ kind = "staminaOut", side = "a" },
			}
		do
			duel:onEvent(junk, NOW)
		end
		expect(duel.a.name).toBeNil()
		expect(duel.b.name).toBeNil()
		duel:onEvent(snapshot("block", "dodge"), NOW + 0.2) -- mid-duel: the first snapshot
		expect(duel.a.name).toBe("block")
		expect(duel.b.name).toBe("dodge")
	end)

	it("the weapon sets the style: greatsword two-handed, spear thrust, an unknown weapon slashes", function()
		local duel = DuelPoses.newDuel()
		duel:onEvent({
			kind = "snapshot",
			side = "a",
			data = { a = { state = "idle", weapon = "spear" }, b = { state = "idle", weapon = "greatsword" } },
		}, NOW)
		expect(duel.a.style).toBe("thrust")
		expect(duel.b.style).toBe("twoHand")
		duel:onEvent({ kind = "snapshot", side = "a", data = { a = { state = "idle", weapon = "bow" } } }, NOW)
		expect(duel.a.style).toBe("slash")
		-- the strike reads differently: the spear's arm ends straight forward, the sword's swept across
		local spear = DuelPoses.keys("light", "thrust") :: any
		local sword = DuelPoses.keys("light", "slash") :: any
		expect(spear[3].pose.RightArm[1]).toBe(95)
		expect(sword[3].pose.RightArm[3] < 0).toBe(true)
	end)

	it(
		"a worn left-hand shield makes a one-handed champion's style shield; two hands, or none worn, keep theirs",
		function()
			local cases = {
				{ "swordShield", false, "slash" }, -- the shield rides the weapon (Kit.weapon's default form)
				{ "swordShield", true, "shield" },
				{ "mace", false, "slash" }, -- the mace's off hand is empty
				{ "mace", true, "shield" },
				{ "greatsword", true, "twoHand" },
				{ "spear", true, "thrust" },
				{ nil, true, "shield" }, -- no snapshot yet
				{ nil, nil, "slash" },
				{ "bow", true, "shield" },
			}
			for _, case in cases do
				expect(DuelPoses.styleFor(case[1], case[2])).toBe(case[3])
			end
			-- the track: what is worn and the snapshot's weapon, in either order
			local duel = DuelPoses.newDuel()
			local a = duel.a
			a:setShield(true)
			expect(a.style).toBe("shield")
			duel:onEvent(snapshot("idle"), NOW)
			expect(a.style).toBe("shield") -- swordShield, worn on the left
			duel:onEvent(
				{ kind = "snapshot", side = "a", data = { a = { state = "idle", weapon = "greatsword" } } },
				NOW
			)
			expect(a.style).toBe("twoHand")
			a:setShield(false)
			expect(a.style).toBe("twoHand")
			duel:onEvent(snapshot("idle"), NOW)
			expect(a.style).toBe("slash")
			a:setShield(true)
			expect(a.style).toBe("shield")
			a:setShield(true) -- unchanged: nothing to do
			expect(a.style).toBe("shield")
			duel:reset() -- a new pair: the body's gear is the controller's to set again
			expect(a.leftShield).toBe(true)
			expect(duel.b.leftShield).toBe(false)
		end
	)

	it(
		"your own press plays at once with the weapon's windup; the server's state confirms it, never restarts it",
		function()
			local duel = DuelPoses.newDuel()
			duel:start(NOW)
			duel:onEvent({
				kind = "snapshot",
				side = "a",
				data = { a = { state = "idle", weapon = "greatsword", staminaShare = 1 } },
			}, NOW)
			expect(duel:predict("a", "light", NOW)).toBe(true)
			expect(duel.a.name).toBe("light")
			expect(duel.a._anim.windup).toBe(Duel.weapons.greatsword.lightWindup) -- config Duel's own windup
			local first = duel.a._anim
			duel:onEvent(
				{ kind = "snapshot", side = "a", data = { a = { state = "windup", weapon = "greatsword" } } },
				NOW + 0.15
			)
			expect(duel.a._anim).toBe(first) -- confirmed, not restarted
			expect(first.predicted).toBeNil()
			run(duel.a, NOW, NOW + DuelPoses.CONFIRM_SEC + 0.02)
			expect(duel.a.name).toBe("light") -- a confirmed swing runs to its end
			-- a heavy: the heavyWindup event confirms it and the wind-up goes on
			duel:onEvent({ kind = "snapshot", side = "a", data = { a = { state = "idle" } } }, NOW + 1)
			expect(duel:predict("a", "heavy", NOW + 1)).toBe(true)
			local heavy = duel.a._anim
			expect(heavy.windup).toBe(Duel.weapons.greatsword.heavyWindup)
			duel:onEvent({ kind = "heavyWindup", side = "a", data = { impactIn = 0.8 } }, NOW + 1.1)
			expect(duel.a._anim).toBe(heavy)
			expect(heavy.predicted).toBeNil()
			-- a hit from us confirms a swing too
			duel:onEvent({ kind = "snapshot", side = "a", data = { a = { state = "idle" } } }, NOW + 3)
			duel:predict("a", "light", NOW + 3)
			duel:onEvent({ kind = "hit", side = "a", data = { heavy = false } }, NOW + 3.05)
			expect(duel.a._anim.predicted).toBeNil()
		end
	)

	it(
		"an unconfirmed press stops after CONFIRM_SEC; one the state, the stamina or a busy body refuses never plays",
		function()
			local duel = DuelPoses.newDuel()
			expect(duel:predict("a", "light", NOW)).toBe(false) -- no duel on
			duel:start(NOW)
			local function view(state, stamina, armour)
				duel:onEvent({
					kind = "snapshot",
					side = "a",
					data = { a = { state = state, staminaShare = stamina, armour = armour } },
				}, NOW)
			end
			view("idle", 1)
			expect(duel:predict("a", "heavy", NOW)).toBe(true)
			run(duel.a, NOW, NOW + DuelPoses.CONFIRM_SEC - 0.02)
			expect(duel.a.name).toBe("heavy")
			run(duel.a, NOW + DuelPoses.CONFIRM_SEC - 0.02, NOW + DuelPoses.CONFIRM_SEC + 0.02)
			expect(duel.a.name).toBeNil() -- refused or lost: it stops
			expect(duel:predict("a", "kick", NOW)).toBe(false)
			expect(duel:predict("c", "light", NOW)).toBe(false)
			view("stagger", 1)
			expect(duel:predict("a", "light", NOW)).toBe(false) -- DuelModel: a swing starts only from idle
			duel.a:reset() -- (the stagger state also played a stagger, which keeps the body busy)
			duel:start(NOW)
			view("block", 1)
			expect(duel:predict("a", "light", NOW)).toBe(false)
			expect(duel:predict("a", "dodge", NOW)).toBe(true) -- a dodge may start from the guard
			duel.a:reset()
			duel:start(NOW)
			view("idle", 0.05)
			expect(duel:predict("a", "heavy", NOW)).toBe(false) -- 22 stamina needed
			expect(duel:predict("a", "parry", NOW)).toBe(false) -- 6 needed
			expect(duel:predict("a", "block", NOW)).toBe(true) -- free
			duel.a:reset()
			duel:start(NOW)
			view("idle", 0.2, "heavy")
			expect(duel:predict("a", "dodge", NOW)).toBe(false) -- heavy armour: 24
			view("idle", 0.2, "light")
			expect(duel:predict("a", "dodge", NOW)).toBe(true) -- light armour: 14
			expect(duel:predict("a", "light", NOW)).toBe(false) -- busy dodging
			duel:onEvent({ kind = "ended", side = "b", data = { reason = "ko" } }, NOW)
			expect(duel:predict("a", "parry", NOW + 1)).toBe(false) -- the end
		end
	)

	it("your own guard holds from the press to the release; the release lowers it at once", function()
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent(snapshot("idle", "idle"), NOW)
		expect(duel:predict("a", "block", NOW)).toBe(true)
		duel:onEvent({ kind = "hit", side = "b", data = { heavy = true } }, NOW + 0.05) -- before the server's state
		expect(duel.a.name).toBe("guardHit") -- the guard is up: a jolt, not a flinch
		duel:onEvent(snapshot("block", "idle"), NOW + 0.15) -- the server confirms
		run(duel.a, NOW, NOW + 2)
		expect(duel.a.name).toBe("block")
		expect(duel:predict("a", "blockEnd", NOW + 2)).toBe(true)
		expect(duel.a.name).toBeNil() -- lowered at once
		duel:onEvent(snapshot("block", "idle"), NOW + 2.1) -- stale: sent before the server had the release
		run(duel.a, NOW + 2, NOW + 2.2)
		expect(duel.a.name).toBeNil()
		duel:onEvent(snapshot("block", "idle"), NOW + 2 + DuelPoses.RELEASE_GRACE + 0.05) -- still blocking: it shows
		expect(duel.a.name).toBe("block")
		-- a guard the server never confirms drops after CONFIRM_SEC
		local lone = DuelPoses.newDuel()
		lone:start(NOW)
		lone:predict("b", "block", NOW)
		run(lone.b, NOW, NOW + DuelPoses.CONFIRM_SEC + 0.05)
		expect(lone.b.name).toBeNil()
		expect(lone.b._holding).toBe(false)
	end)

	it(
		"a Called Warning (heavyWindup.warned) raises the heavy's telegraph sooner; the strike keeps its time",
		function()
			local R = DuelPoses.WARNED_RAISE
			local function raisedAt(warned)
				return (DuelPoses.keys("heavy", "slash", 0.8, nil, warned) :: any)[2].t
			end
			local function strikeAt(warned)
				return (DuelPoses.keys("heavy", "slash", 0.8, nil, warned) :: any)[4].t
			end
			expect(raisedAt(nil)).toBe(R.normal)
			expect(math.abs(raisedAt(0.1) - (R.normal - 0.1)) < 1e-9).toBe(true) -- that much sooner
			expect(raisedAt(0.25)).toBe(R.min) -- config Support's 0.15 and 0.25 both reach the floor today
			expect(raisedAt(0.15)).toBe(R.min)
			for _, bad in { -1, 0 / 0, "0.25", 0 } do
				expect(raisedAt(bad)).toBe(R.normal)
			end
			expect(strikeAt(0.25)).toBe(strikeAt(nil)) -- the strike lands when the server's hit does
			expect(math.abs(strikeAt(nil) - (0.8 + DuelPoses.HEAVY_STRIKE)) < 1e-9).toBe(true)
			-- a short wind-up raises at half of it, and a warning never makes the raise later
			expect((DuelPoses.keys("heavy", "slash", 0.3, nil, 0.25) :: any)[2].t).toBe(0.15)
			-- through the event: 0.2 s in, the warned arm is up while the plain one is still rising
			local warned, plain = DuelPoses.newDuel(), DuelPoses.newDuel()
			for _, duel in { warned, plain } do
				duel:start(NOW)
				duel:onEvent(snapshot(nil, "idle"), NOW)
			end
			warned:onEvent({ kind = "heavyWindup", side = "b", data = { impactIn = 0.8, warned = 0.25 } }, NOW + 1)
			plain:onEvent({ kind = "heavyWindup", side = "b", data = { impactIn = 0.8 } }, NOW + 1)
			local function armUp(duel)
				local out = run(duel.b, NOW, NOW + 1.2)
				local _, a = out.pose.RightArm:ToAxisAngle()
				return math.deg(a)
			end
			local up, rising = armUp(warned), armUp(plain)
			expect(up > 135).toBe(true)
			expect(up > rising + 15).toBe(true)
			expect(warned.b._anim.start + warned.b._anim.windup).toBe(plain.b._anim.start + plain.b._anim.windup)
		end
	)

	it("a press the stamina refuses plays winded (out of breath), once, and only when nothing else plays", function()
		local function tired(share)
			return {
				kind = "snapshot",
				side = "a",
				data = { a = { state = "idle", weapon = "mace", staminaShare = share } },
			}
		end
		local duel = DuelPoses.newDuel()
		duel:start(NOW)
		duel:onEvent(tired(0.05), NOW) -- a heavy costs 22 of 100
		expect(duel:predict("a", "heavy", NOW)).toBe(false) -- never a swing
		expect(duel.a.name).toBe("winded")
		local started = duel.a._anim.start
		expect(duel:predict("a", "light", NOW + 0.1)).toBe(false) -- mashing does not restart it
		expect(duel.a._anim.start).toBe(started)
		local out = run(duel.a, NOW, NOW + 0.2)
		expect(out.weight).toBe(1)
		expect(out.body).toBe(0) -- the upper body only: a walking avatar keeps its legs
		local sag = DuelPoses.pose((DuelPoses.keys("winded", "slash") :: any)[2].pose)
		expect(DuelRig.same(out.pose.RightArm, sag.RightArm)).toBe(true) -- held, so it reads
		run(duel.a, NOW + 0.2, NOW + DuelPoses.LENGTH.winded + 0.05)
		expect(duel.a.name).toBeNil()
		-- it is never in the way: the guard (free) rises over it at once
		duel:predict("a", "heavy", NOW + 0.6)
		expect(duel.a.name).toBe("winded")
		expect(duel:predict("a", "block", NOW + 0.65)).toBe(true)
		expect(duel.a.name).toBe("block")
		duel:predict("a", "blockEnd", NOW + 0.7)
		-- a hit cuts it; and while a flinch plays, a refused press shows nothing new
		duel:predict("a", "heavy", NOW + 1)
		duel:onEvent({ kind = "hit", side = "b", data = { heavy = false } }, NOW + 1.1)
		expect(duel.a.name).toBe("flinch")
		duel:predict("a", "heavy", NOW + 1.15)
		expect(duel.a.name).toBe("flinch")
		-- enough stamina: the press plays as before; the dodge's cost is the armour's
		local fresh = DuelPoses.newDuel()
		fresh:start(NOW)
		fresh:onEvent(tired(0.5), NOW)
		expect(fresh:predict("a", "heavy", NOW)).toBe(true)
		expect(fresh.a.name).toBe("heavy")
		-- outside a duel nothing plays at all
		local idle = DuelPoses.newDuel()
		idle:onEvent(tired(0), NOW)
		expect(idle:predict("a", "heavy", NOW)).toBe(false)
		expect(idle.a.name).toBeNil()
	end)

	it(
		"STARTS_FROM is DuelModel.step's rule: each press starts from exactly the states the model starts it from",
		function()
			local fs = require("@lune/fs")
			local DuelModel = require("@game/ReplicatedStorage/Game/Arena/DuelModel")
			-- every state DuelModel can put a duellist in: the known ones, plus any its source names (a new one is
			-- then checked too)
			local states =
				{ idle = true, windup = true, recover = true, block = true, parry = true, dodge = true, stagger = true }
			local ok, source = pcall(fs.readFile, "games/game-001/src/shared/Arena/DuelModel.luau")
			if ok then
				for name in string.gmatch(source, 'state = "(%a+)"') do
					states[name] = true
				end
			end
			local STARTS = { light = "windup", heavy = "windup", block = "block", parry = "parry", dodge = "dodge" }
			local actions = 0
			for action in DuelPoses.STARTS_FROM do
				assert(STARTS[action] ~= nil, `STARTS_FROM.{action}: not a press DuelModel starts`)
				actions += 1
			end
			expect(actions).toBe(5)
			local checked = 0
			for action, into in STARTS do
				for state in states do
					local duel = DuelModel.new(nil, {}, {}, 1)
					duel.a.state, duel.a.timer = state, 10 -- held in that state for the step
					DuelModel.step(duel, { a = { action = action, inRange = false, facing = false } }, 1 / 60)
					local started = state ~= into and duel.a.state == into
					local copied = DuelPoses.STARTS_FROM[action][state] == true
					assert(
						started == copied,
						`{action} from {state}: DuelModel {started}, DuelPoses.STARTS_FROM {copied}`
					)
					checked += 1
				end
			end
			expect(checked >= 35).toBe(true)
		end
	)

	it("every key pose stays within LIMITS and Root's offsets within 1.5 studs", function()
		local names = {
			"ready",
			"block",
			"light",
			"heavy",
			"guardHit",
			"parry",
			"dodge",
			"flinch",
			"flinchHeavy",
			"stagger",
			"ko",
			"yield",
			"victory",
			"winded",
		}
		local checked = 0
		for _, name in names do
			for _, style in { "slash", "twoHand", "thrust", "shield" } do
				for _, dir in { -1, 1 } do
					for _, key in DuelPoses.keys(name, style, nil, dir) :: any do
						for joint, v in key.pose do
							local limit = DuelPoses.LIMITS[joint]
							assert(limit ~= nil, `{name}: unknown joint {joint}`)
							for i = 1, 3 do
								assert(math.abs(v[i] or 0) <= limit, `{name}/{style} {joint}[{i}] = {v[i]} > {limit}`)
							end
							for i = 4, 6 do
								assert(math.abs(v[i] or 0) <= 1.5, `{name}/{style} {joint} offset {v[i]}`)
							end
							checked += 1
						end
					end
				end
			end
		end
		expect(checked > 500).toBe(true)
		expect(DuelPoses.keys("nothing")).toBeNil()
	end)

	it("crossfades: no joint jumps more than 25° between two 60 Hz frames through a whole exchange", function()
		for _, shield in { false, true } do -- the slash, then the shield style (a left-hand shield)
			local duel = DuelPoses.newDuel()
			duel.a:setShield(shield)
			duel.b:setShield(shield)
			duel:start(NOW)
			local script = {
				{ 0.1, snapshot("windup", "block") },
				{ 0.3, { kind = "hit", side = "a", data = { heavy = false } } },
				{ 0.9, { kind = "heavyWindup", side = "b", data = { impactIn = 0.8, warned = 0.25 } } }, -- the fastest raise
				{ 1.0, snapshot("dodge", "windup") },
				{ 1.7, { kind = "hit", side = "b", data = { heavy = true } } },
				{ 2.4, { kind = "stagger", side = "a" } },
				{ 3.6, { kind = "ended", side = "b", data = { reason = "ko" } } },
			}
			local i = 1
			local prev = { a = {}, b = {} }
			local worst = 0
			local out = { a = { weight = 0, body = 0 }, b = { weight = 0, body = 0 } }
			for frame = 0, 60 * 6 do
				local t = NOW + frame / 60
				while script[i] ~= nil and NOW + script[i][1] <= t do
					duel:onEvent(script[i][2], t)
					i += 1
				end
				for _, side in { "a", "b" } do
					duel[side]:sample(t, out[side])
					for joint, cf in out[side].pose do
						local last = prev[side][joint]
						if last ~= nil then
							local _, turned = (last:Inverse() * cf):ToAxisAngle()
							worst = math.max(worst, math.deg(turned))
						end
						prev[side][joint] = cf
					end
				end
			end
			assert(worst <= 25, `shield {shield}: a joint turned {worst}° in one frame`)
			expect(duel.a.style).toBe(if shield then "shield" else "slash")
		end
	end)

	it(
		"weights: upper-body swings leave an avatar's legs (body 0), whole-body ones pose them; stop fades all",
		function()
			local track = DuelPoses.newTrack()
			track.active = true
			track:play("light", NOW)
			local out = run(track, NOW, NOW + 0.3)
			expect(out.weight).toBe(1)
			expect(out.body).toBe(0)
			track:play("dodge", NOW + 1)
			out = run(track, NOW + 0.3, NOW + 1.05 + DuelPoses.XFADE)
			expect(out.body).toBe(1)
			-- after the dodge the legs go back to the avatar over XFADE: no pop (FORGE-07 #278 L2)
			local dodgeEnds = NOW + 1 + DuelPoses.LENGTH.dodge
			local easing = run(track, NOW + 1.05 + DuelPoses.XFADE, dodgeEnds + DuelPoses.XFADE / 2)
			expect(easing.body > 0.2 and easing.body < 0.9).toBe(true)
			-- the ready stance between actions: weight 1; before a duel (not active): weight 0
			out = run(track, dodgeEnds + DuelPoses.XFADE / 2, NOW + 3)
			expect(out.weight).toBe(1)
			expect(out.body).toBe(0)
			expect(run(DuelPoses.newTrack(), NOW, NOW + 1).weight).toBe(0)
			local duel = DuelPoses.newDuel()
			duel:start(NOW)
			run(duel.a, NOW, NOW + 1)
			duel:stop(NOW + 1)
			local mid = run(duel.a, NOW + 1, NOW + 1 + DuelPoses.XFADE / 2)
			expect(mid.weight > 0 and mid.weight < 1).toBe(true)
			expect(run(duel.a, NOW + 1 + DuelPoses.XFADE / 2, NOW + 1.2).weight).toBe(0)
			-- stopped while an animation holds (the KO, when the stage moves on): it fades too, no jump
			local held = DuelPoses.newDuel()
			held:start(NOW)
			held:onEvent({ kind = "ended", side = "a", data = { reason = "ko" } }, NOW)
			run(held.b, NOW, NOW + 1)
			held:stop(NOW + 1)
			local fading = run(held.b, NOW + 1, NOW + 1 + DuelPoses.XFADE / 2)
			expect(fading.weight > 0 and fading.weight < 1).toBe(true)
		end
	)

	it(
		"reduced motion keeps every pose but freezes its periodic part (stagger wobble, victory pump, breathing)",
		function()
			-- the stagger's wobble (Waist roll) is there with motion, and gone with reduced motion
			local wobbling, still = DuelPoses.newTrack(), DuelPoses.newTrack()
			wobbling:play("stagger", NOW)
			still:play("stagger", NOW)
			run(wobbling, NOW, NOW + 0.3, true)
			run(still, NOW, NOW + 0.3, false)
			expect(math.abs(wobbling._numbers.Waist[3]) > 1).toBe(true)
			expect(still._numbers.Waist[3]).toBe(0) -- the stagger's keys never roll the waist
			-- the victory pose holds still with reduced motion, and pumps without it
			local held, pumped = DuelPoses.newTrack(), DuelPoses.newTrack()
			held:play("victory", NOW)
			pumped:play("victory", NOW)
			local h1 = run(held, NOW, NOW + 0.6, false).pose.RightArm
			local h2 = run(held, NOW + 0.6, NOW + 0.8, false).pose.RightArm
			local p1 = run(pumped, NOW, NOW + 0.6, true).pose.RightArm
			local p2 = run(pumped, NOW + 0.6, NOW + 0.8, true).pose.RightArm
			expect(h1 == h2).toBe(true)
			expect(p1 ~= p2).toBe(true)
			-- the ready stance breathes only with motion
			local calm, breathing = DuelPoses.newTrack(), DuelPoses.newTrack()
			calm.active, breathing.active = true, true
			local c1 = run(calm, NOW, NOW + 0.5, false).pose.Waist
			local c2 = run(calm, NOW + 0.5, NOW + 1, false).pose.Waist
			local b1 = run(breathing, NOW, NOW + 0.5, true).pose.Waist
			local b2 = run(breathing, NOW + 0.5, NOW + 1, true).pose.Waist
			expect(c1 == c2).toBe(true)
			expect(b1 ~= b2).toBe(true)
		end
	)
end)

-- ------------------------------------------------------------------ rigs

local CF = CFrame.new
local function part(model, name, size, at)
	local p = roblox.Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = at
	p.Parent = model
	return p
end
local function motor(name, p0, p1, c0, c1, class)
	local m
	if class == "AnimationConstraint" then
		m = roblox.Instance.new("AnimationConstraint")
		local a0, a1 = roblox.Instance.new("Attachment"), roblox.Instance.new("Attachment")
		a0.CFrame, a1.CFrame = c0, c1
		a0.Parent, a1.Parent = p0, p1
		m.Attachment0, m.Attachment1 = a0, a1
	else
		m = roblox.Instance.new("Motor6D")
		m.Part0, m.Part1, m.C0, m.C1 = p0, p1, c0, c1
	end
	m.Name = name
	m.Parent = p1
	return m
end

-- A standard R15 avatar (only the joints DuelRig uses), joints as Motor6Ds or AnimationConstraints.
local function r15(class)
	local model = roblox.Instance.new("Model")
	local h = roblox.Instance.new("Humanoid")
	h.HipHeight = 2
	h.Parent = model
	local hrp = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CF(0, 3, 0))
	local lower = part(model, "LowerTorso", Vector3.new(2, 0.4, 1), CF(0, 2.2, 0))
	local upper = part(model, "UpperTorso", Vector3.new(2, 1.6, 1), CF(0, 3.2, 0))
	local head = part(model, "Head", Vector3.new(1.2, 1.2, 1.2), CF(0, 4.6, 0))
	local la = part(model, "LeftUpperArm", Vector3.new(1, 1.2, 1), CF(-1.5, 3.4, 0))
	local ra = part(model, "RightUpperArm", Vector3.new(1, 1.2, 1), CF(1.5, 3.4, 0))
	local ll = part(model, "LeftUpperLeg", Vector3.new(1, 1.2, 1), CF(-0.5, 1.4, 0))
	local rl = part(model, "RightUpperLeg", Vector3.new(1, 1.2, 1), CF(0.5, 1.4, 0))
	motor("Root", hrp, lower, CF(0, -1, 0), CF(0, -0.2, 0), class)
	motor("Waist", lower, upper, CF(0, 0.2, 0), CF(0, -0.8, 0), class)
	motor("Neck", upper, head, CF(0, 0.8, 0), CF(0, -0.6, 0), class)
	motor("LeftShoulder", upper, la, CF(-1, 0.6, 0), CF(0.5, 0.4, 0), class)
	motor("RightShoulder", upper, ra, CF(1, 0.6, 0), CF(-0.5, 0.4, 0), class)
	local hand = part(model, "RightHand", Vector3.new(0.6, 0.4, 0.6), CF(1.5, 2.6, 0))
	motor("RightWrist", ra, hand, CF(0, -0.6, 0), CF(0, 0.2, 0), class)
	motor("LeftHip", lower, ll, CF(-0.5, -0.2, 0), CF(0, 0.6, 0), class)
	motor("RightHip", lower, rl, CF(0.5, -0.2, 0), CF(0, 0.6, 0), class)
	model.PrimaryPart = hrp
	return model
end

-- A classic R6 avatar with R6's own turned joint frames.
local function r6()
	local model = roblox.Instance.new("Model")
	local h = roblox.Instance.new("Humanoid")
	h.Parent = model
	local hrp = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CF(0, 3, 0))
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), CF(0, 3, 0))
	local head = part(model, "Head", Vector3.new(2, 1, 1), CF(0, 4.5, 0))
	local la = part(model, "Left Arm", Vector3.new(1, 2, 1), CF(-1.5, 3, 0))
	local ra = part(model, "Right Arm", Vector3.new(1, 2, 1), CF(1.5, 3, 0))
	local ll = part(model, "Left Leg", Vector3.new(1, 2, 1), CF(-0.5, 1, 0))
	local rl = part(model, "Right Leg", Vector3.new(1, 2, 1), CF(0.5, 1, 0))
	local ROOT = CF(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", hrp, torso, ROOT, ROOT)
	motor("Neck", torso, head, CF(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CF(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor(
		"Right Shoulder",
		torso,
		ra,
		CF(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CF(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)
	motor(
		"Left Shoulder",
		torso,
		la,
		CF(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CF(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)
	motor("Right Hip", torso, rl, CF(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CF(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, CF(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CF(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	model.PrimaryPart = hrp
	return model
end

-- Every part's world CFrame from the joints (Part1 = Part0 * C0 * Transform * C1^-1), from the root.
local function solve(model)
	local world = { [model.PrimaryPart] = model.PrimaryPart.CFrame }
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = d.C0, c1 = d.C1, t = d.Transform })
		elseif d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			table.insert(joints, { p0 = a0.Parent, p1 = a1.Parent, c0 = a0.CFrame, c1 = a1.CFrame, t = d.Transform })
		elseif d:IsA("Weld") then -- the gear (Figures' welds)
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = d.C0, c1 = d.C1, t = CFrame.new() })
		elseif d:IsA("WeldConstraint") and d.Part0 ~= nil and d.Part1 ~= nil then -- a Kit model's parts
			local rel = d.Part0.CFrame:Inverse() * d.Part1.CFrame
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = rel, c1 = CFrame.new(), t = CFrame.new() })
		end
	end
	for _ = 1, #joints do
		for _, j in joints do
			if world[j.p0] ~= nil and world[j.p1] == nil then
				world[j.p1] = world[j.p0] * j.c0 * j.t * j.c1:Inverse()
			end
		end
	end
	return world
end

local function find(model, name)
	return model:FindFirstChild(name, true)
end

-- A pose with one joint set (numbers, degrees) and the rest at zero.
local function poseWith(spec)
	local numbers = table.clone(spec)
	return { pose = DuelPoses.pose(numbers), weight = 1, body = 1 }
end

describe("DuelRig: the same pose on a Kit rig, an R15 avatar (Motor6D or AnimationConstraint) and R6", function()
	local rigs = {
		{ "kit", Kit.character("governor", "idle", Color3.fromRGB(200, 40, 40)), "RightArm", "LeftLeg" },
		{ "r15", r15(), "RightUpperArm", "LeftUpperLeg" },
		{ "r15", r15("AnimationConstraint"), "RightUpperArm", "LeftUpperLeg" },
		{ "r6", r6(), "Right Arm", "Left Leg" },
	}

	it("scan finds each rig's kind and joints; a model without joints is no rig", function()
		for _, entry in rigs do
			local rig = DuelRig.scan(entry[2]) :: any
			assert(rig ~= nil, entry[1])
			expect(rig.kind).toBe(entry[1])
			for _, joint in { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				assert(rig.joints[joint] ~= nil, `{entry[1]} {joint}`)
			end
			if entry[1] == "r15" then
				assert(rig.joints.Root ~= nil and rig.joints.Waist ~= nil, "r15 Root and Waist")
				expect(math.abs(rig.scale - 2 / 2.2) < 1e-9).toBe(true) -- HipHeight 2
			else
				assert(rig.joints.Torso ~= nil, `{entry[1]} Torso`)
			end
		end
		expect(DuelRig.scan(roblox.Instance.new("Model"))).toBeNil()
		expect(DuelRig.scan(nil)).toBeNil()
	end)

	it("an arm swung forward 90° points forward (-Z) on every rig, R6's turned joint frames included", function()
		for _, entry in rigs do
			local model = entry[2]
			local rig = DuelRig.scan(model) :: any
			DuelRig.apply(rig, poseWith({ RightArm = { 90, 0, 0 } }))
			local world = solve(model)
			local arm = find(model, entry[3])
			local restDown = -arm.CFrame.UpVector -- built at rest (Kit's arms hang splayed 7°)
			local down = -world[arm].UpVector
			local want = CFrame.Angles(math.rad(90), 0, 0):VectorToWorldSpace(restDown)
			expect(angle(want, Vector3.new(0, 0, -1)) < 8).toBe(true) -- forward
			assert(angle(down, want) < 1, `{entry[1]}: the arm points {down}, not {want}`)
			DuelRig.release(rig)
		end
	end)

	it("a whole-body lean keeps the legs upright (feet planted) on every rig", function()
		for _, entry in rigs do
			local model = entry[2]
			local rig = DuelRig.scan(model) :: any
			DuelRig.apply(rig, poseWith({ Root = { -25, 0, 0 }, Waist = { -10, 20, 0 } }))
			local world = solve(model)
			local leg = find(model, entry[4])
			assert(angle(-world[leg].UpVector, -leg.CFrame.UpVector) < 1, `{entry[1]}: the leg tilts`)
			-- and the body did lean: the head moved forward (-Z) of the hips
			local head = find(model, "Head")
			if head:IsA("BasePart") then
				expect(world[head].Position.Z < head.CFrame.Position.Z - 0.3).toBe(true)
			end
			DuelRig.release(rig)
		end
	end)

	it(
		"over an avatar's Animator: weight 1 replaces, 0.5 blends, body 0 leaves the legs, weight 0 writes nothing",
		function()
			local model = r15()
			local rig = DuelRig.scan(model) :: any
			local shoulder = find(model, "RightShoulder")
			local hip = find(model, "LeftHip")
			local rightHip = find(model, "RightHip")
			local rootJoint = find(model, "Root")
			local waist, wrist = find(model, "Waist"), find(model, "RightWrist")
			local animated = CFrame.Angles(math.rad(30), 0, 0) -- the Animator's value this frame
			for _, j in { shoulder, hip, rightHip, rootJoint, waist, wrist } do
				j.Transform = animated
			end
			local swing = poseWith({
				Root = { -20, 0, 0 },
				Waist = { 0, 20, 0 },
				RightArm = { 90, 0, 0 },
				LeftLeg = { 40, 0, 0 },
				RightLeg = { -40, 0, 0 },
				Tool = { -60, 0, 0 },
			})
			swing.body = 0
			DuelRig.apply(rig, swing)
			local _, full = shoulder.Transform:ToAxisAngle()
			expect(math.abs(math.deg(full) - 90) < 1e-3).toBe(true)
			expect(DuelRig.same(hip.Transform, animated)).toBe(true) -- an upper-body swing leaves the walk on the legs
			expect(DuelRig.same(rightHip.Transform, animated)).toBe(true)
			expect(DuelRig.same(rootJoint.Transform, animated)).toBe(true) -- ... and the hips (Root) to the Animator
			-- ... but the swing is ours above the hips: the waist's twist and the weapon's angle (FORGE-07 #278 L2)
			local _, twist = waist.Transform:ToAxisAngle()
			expect(math.abs(math.deg(twist) - 20) < 1e-3).toBe(true)
			local _, tipped = wrist.Transform:ToAxisAngle()
			expect(math.abs(math.deg(tipped) - 60) < 1e-3).toBe(true)
			-- R6 too (no waist): the torso and the legs stay the Animator's
			local old6 = r6()
			local rig6 = DuelRig.scan(old6) :: any
			local torso6, hip6, rightHip6 = find(old6, "RootJoint"), find(old6, "Left Hip"), find(old6, "Right Hip")
			for _, j in { torso6, hip6, rightHip6 } do
				j.Transform = animated
			end
			DuelRig.apply(rig6, swing)
			for _, j in { torso6, hip6, rightHip6 } do
				assert(DuelRig.same(j.Transform, animated), `R6 {j.Name} written under body 0`)
			end
			shoulder.Transform = animated -- the Animator writes again next frame
			swing.weight = 0.5
			DuelRig.apply(rig, swing)
			local _, half = shoulder.Transform:ToAxisAngle()
			expect(math.abs(math.deg(half) - 60) < 1e-3).toBe(true) -- halfway from the Animator's 30° to 90°
			-- the joint still holds our own last write (no Animator on it): blend from rest instead
			DuelRig.apply(rig, swing)
			local _, fromRest = shoulder.Transform:ToAxisAngle()
			expect(math.abs(math.deg(fromRest) - 45) < 1e-3).toBe(true)
			-- weight 0 writes nothing, not even the Animator's own value back
			shoulder.Transform = animated
			swing.weight = 0
			DuelRig.apply(rig, swing)
			expect(DuelRig.same(shoulder.Transform, animated)).toBe(true)
			-- ... nor rest over a joint that still holds our own last write
			swing.weight = 1
			DuelRig.apply(rig, swing)
			local ours = shoulder.Transform
			swing.weight = 0
			DuelRig.apply(rig, swing)
			expect(DuelRig.same(shoulder.Transform, ours)).toBe(true)
			-- release: a joint still holding our write goes back to rest; one the Animator wrote is left alone
			swing.weight = 1
			DuelRig.apply(rig, swing)
			local neck = find(model, "Neck")
			neck.Transform = animated
			DuelRig.release(rig)
			expect(DuelRig.same(shoulder.Transform, CFrame.new())).toBe(true)
			expect(DuelRig.same(neck.Transform, animated)).toBe(true)
		end
	)

	it("the weapon's angle goes to R15's RightWrist and the Kit rig's Tool joint; R6 has none", function()
		local avatar = r15()
		local rig = DuelRig.scan(avatar) :: any
		assert(rig.joints.Tool ~= nil, "RightWrist found")
		DuelRig.apply(rig, poseWith({ Tool = { -60, 0, 0 } }))
		local _, tipped = find(avatar, "RightWrist").Transform:ToAxisAngle()
		expect(math.abs(math.deg(tipped) - 60) < 1e-3).toBe(true)
		local kit = Kit.character("governor", "idle", Color3.fromRGB(40, 90, 200)) -- the governor holds a staff
		expect((DuelRig.scan(kit) :: any).joints.Tool ~= nil).toBe(true)
		expect((DuelRig.scan(r6()) :: any).joints.Tool).toBeNil()
	end)

	it("Root's lift scales with the rig's legs: Kit 1, an R15 of HipHeight 2 by 2/2.2", function()
		local kit = Kit.character("governor", "idle", Color3.fromRGB(40, 90, 200))
		local avatar = r15()
		local down = poseWith({ Root = { 0, 0, 0, 0, -1.1, 0 } })
		DuelRig.apply(DuelRig.scan(kit) :: any, down)
		DuelRig.apply(DuelRig.scan(avatar) :: any, down)
		local kitTorso = nil
		for _, d in kit:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == "Torso" then
				kitTorso = d
			end
		end
		expect(math.abs(kitTorso.Transform.Position.Y + 1.1) < 1e-4).toBe(true)
		expect(math.abs(find(avatar, "Root").Transform.Position.Y + 1.1 * 2 / 2.2) < 1e-4).toBe(true)
	end)
end)

-- The AI figure's gear as FORGE-01 is asked to wire it (FL-0141 follow-up 3): Figures' weapon weld (its own
-- weapon off the Tool part; the Handle at the fist, C1 = Grip) with #297's turned rest, so the blade stands
-- upright when the arm points forward, for Kit.weapon("swordShield", c, { shield = false }); and Kit.shield
-- on the left fist at the same turned rest, its LeftGripAttachment as C1 (the left hand's grip frame).
local TURN = CFrame.Angles(-math.pi / 2, 0, 0)
local RED = Color3.fromRGB(190, 40, 50)
local function weldTo(p0, p1, c0, c1)
	local w = roblox.Instance.new("Weld")
	w.Part0, w.Part1, w.C0, w.C1 = p0, p1, c0, c1
	w.Parent = p0
	return w
end
local function shieldFigure(): (any, any)
	local model = Kit.character("governor", "idle", RED)
	local toolPart, right, left = find(model, "Tool"), find(model, "RightArm"), find(model, "LeftArm")
	for _, d in model:GetDescendants() do -- the governor's staff goes (Figures.stripOwnWeapon)
		if (d:IsA("Weld") or d:IsA("WeldConstraint")) and d.Part0 == toolPart and d.Part1 ~= nil then
			d.Part1:Destroy()
		end
	end
	toolPart.Transparency = 1
	local sword = Kit.weapon("swordShield", RED, { shield = false })
	local atFist = right.CFrame * CFrame.new(0, -right.Size.Y / 2, 0) * TURN
	weldTo(toolPart, sword:FindFirstChild("Handle"), toolPart.CFrame:Inverse() * atFist, sword.Grip)
	sword.Parent = model
	local shield = Kit.shield(RED)
	local handle = shield:FindFirstChild("Handle")
	local atLeft = left.CFrame * CFrame.new(0, -left.Size.Y / 2, 0) * TURN
	local grip =
		weldTo(left, handle, left.CFrame:Inverse() * atLeft, handle:FindFirstChild("LeftGripAttachment").CFrame)
	shield.Parent = model
	return model, grip
end

-- The shield's facing (the left grip's LookVector): its turn (degrees sideways from straight at the
-- opponent, -Z) and tilt (+ face up); blade points through the shield's disc; shield points (centre and
-- rim) inside the body.
local function shieldCheck(model, grip, world)
	local look = (world[grip.Part0] * grip.C0).LookVector
	local turn = math.deg(math.atan2(-look.X, -look.Z))
	local tilt = math.deg(math.asin(look.Y))
	local face = world[find(model, "ShieldFace")]
	local through = 0
	for _, d in model:FindFirstChildWhichIsA("Tool"):GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" then
			for y = -0.5, 0.5, 0.1 do
				for x = -0.5, 0.5, 0.5 do
					local l =
						face:PointToObjectSpace(world[d]:PointToWorldSpace(Vector3.new(x * d.Size.X, y * d.Size.Y, 0)))
					if math.abs(l.X) < 0.2 and math.sqrt(l.Y * l.Y + l.Z * l.Z) < 1.2 then
						through += 1
					end
				end
			end
		end
	end
	local inside = 0
	local points = { face.Position }
	for k = 0, 11 do
		local a = k * math.pi / 6
		table.insert(points, face:PointToWorldSpace(Vector3.new(0, 1.1 * math.cos(a), 1.1 * math.sin(a))))
	end
	for _, name in { "Torso", "Head", "RightArm", "LeftLeg", "RightLeg" } do
		local body = find(model, name)
		for _, w in points do
			local l = world[body]:PointToObjectSpace(w)
			local half = body.Size / 2
			if
				if name == "Head"
					then l.Magnitude < half.X
					else math.abs(l.X) < half.X and math.abs(l.Y) < half.Y and math.abs(l.Z) < half.Z
			then
				inside += 1
			end
		end
	end
	return turn, tilt, through, inside
end

describe("the shield style: Kit.shield on the left hand faces the opponent (FL-0141 follow-up 3)", function()
	it("a worn Kit.shield is the left hand's; the sword-and-shield Tool, a hat or nothing is not", function()
		local model = Kit.character("governor", "idle", RED)
		expect(DuelRig.leftShield(model)).toBe(false)
		local tool = Kit.weapon("swordShield", RED) -- the shield on the weapon (KitShield on a Tool)
		tool.Parent = model
		expect(tool:GetAttribute("KitShield") ~= nil).toBe(true)
		expect(DuelRig.leftShield(model)).toBe(false)
		local hat = roblox.Instance.new("Accessory")
		hat.Parent = model
		expect(DuelRig.leftShield(model)).toBe(false)
		local shield = Kit.shield(RED)
		shield.Parent = model -- an avatar's AddAccessory
		expect(DuelRig.leftShield(model)).toBe(true)
		shield.Parent = find(model, "LeftArm") -- the AI figure may keep it under a part
		expect(DuelRig.leftShield(model)).toBe(true)
		shield.Parent = nil
		expect(DuelRig.leftShield(model)).toBe(false)
		expect(DuelRig.leftShield(nil)).toBe(false)
	end)

	it(
		"the shield style is the slash with the shield arm up: the sword arm, the body and the legs are the slash's",
		function()
			local names = {
				"ready",
				"block",
				"light",
				"heavy",
				"guardHit",
				"parry",
				"dodge",
				"flinch",
				"stagger",
				"ko",
				"victory",
				"winded",
			}
			local raised = 0
			for _, name in names do
				for _, dir in { -1, 1 } do
					local shield = DuelPoses.keys(name, "shield", nil, dir) :: any
					local slash = DuelPoses.keys(name, "slash", nil, dir) :: any
					expect(#shield).toBe(#slash)
					for i, key in shield do
						expect(key.t).toBe(slash[i].t)
						for _, joint in DuelPoses.JOINTS do
							local a, b = key.pose[joint] or {}, slash[i].pose[joint] or {}
							if joint ~= "LeftArm" then
								for k = 1, 6 do
									assert((a[k] or 0) == (b[k] or 0), `{name} key {i}: {joint} differs from the slash`)
								end
							elseif (a[1] or 0) ~= (b[1] or 0) or (a[3] or 0) ~= (b[3] or 0) then
								raised += 1
							end
						end
					end
				end
			end
			expect(raised > 20).toBe(true)
			-- the mace (and a shield on the weapon) keeps the slash's left arm
			expect((DuelPoses.keys("ready", "slash") :: any)[1].pose.LeftArm[1]).toBe(65)
		end
	)

	it(
		"through the stance, the guard and every swing the shield faces the opponent, about level, clear of the blade and body",
		function()
			-- each animation from the ready stance (as in a duel), every 60 Hz frame, on the AI figure
			local runs =
				{ { "block" }, { "guardHit" }, { "light" }, { "heavy" }, { "parry" }, { "dodge" }, { "dodge", 2 } }
			local function sweep(style)
				local worst = { turn = 0, tilt = 0, through = 0, inside = 0 }
				for _, anim in runs do
					local model, grip = shieldFigure()
					local rig = DuelRig.scan(model) :: any
					local track = DuelPoses.newTrack()
					track:setShield(style == "shield")
					track.active = true
					local out = { weight = 0, body = 0 }
					local t = NOW - 0.5
					while t < NOW do
						track:sample(t, out, false)
						t += 1 / 60
					end
					for _ = 1, anim[2] or 1 do -- a second dodge goes the other way
						track:play(anim[1], NOW)
					end
					local length = track._anim.length
					t = NOW - 2 / 60
					while t <= NOW + length + 0.15 do
						track:sample(t, out, false)
						DuelRig.apply(rig, out)
						local turn, tilt, through, inside = shieldCheck(model, grip, solve(model))
						worst.turn = math.max(worst.turn, math.abs(turn))
						worst.tilt = math.max(worst.tilt, math.abs(tilt))
						worst.through = math.max(worst.through, through)
						worst.inside = math.max(worst.inside, inside)
						t += 1 / 60
					end
				end
				return worst
			end
			local up = sweep("shield")
			assert(up.turn <= 10, `the shield turned {up.turn}° away from the opponent`)
			assert(up.tilt <= 15, `the shield tilted {up.tilt}°`) -- the stance's 13° down, a guard jolt's 13° up
			expect(up.through).toBe(0) -- the blade never passes through it
			expect(up.inside).toBe(0) -- nor it through the body
			-- the slash's own left arm (the mace's empty hand) would swing a worn shield away: why the style exists
			local slash = sweep("slash")
			assert(slash.turn > 60 and slash.tilt > 30, `slash: {slash.turn}° turned, {slash.tilt}° tilted`)
		end
	)
end)
