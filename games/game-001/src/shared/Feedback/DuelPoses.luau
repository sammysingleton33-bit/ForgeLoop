--!strict
--[[
	Feedback/DuelPoses (game-001, FORGE-04, FL-0141; CONTRACTS G12.4 Arena.Events, G12.6): what each Crown
	Arena champion's body does in the duel. Pure: numbers and CFrame maths only, no instances, no clock (the
	caller passes `now`), deterministic. Self-made keyframes (D-026 (2): procedural poses, no animation
	assets; licence: this repository's own code, no third-party data). Feedback/DuelRig writes the poses to
	a rig's joints; FeedbackDuelController feeds the events from FORGE-01's DuelController.

	Events → animations (G12.4; the relay sends no light, block, dodge or miss event, so those come from
	each side's `snapshot` state, sent every 0.2 s):
		snapshot state "windup"   light swing, unless a heavy is already winding up
		snapshot state "recover"  the swing jumps to its strike (or starts at it: the windup was missed)
		heavyWindup               heavy: wind-up held for data.impactIn, then the strike
		hit (side = the hitter)   the hitter's swing strikes now; the target flinches (heavy: a bigger
		                          flinch, a step back), or its guard jolts when it is blocking
		snapshot state "block"    the guard is held while the state says block; it eases out after
		snapshot state "parry"    parry (the window); a `parry` event plays it again as the deflect
		snapshot state "dodge"    dodge: a ducking sidestep, left and right in turn
		stagger / state "stagger" stagger: a stumble back (a parried attacker, a broken guard)
		ended                     reason "ko": the loser kneels and slumps, the winner raises the weapon;
		                          "timeCap": the loser kneels upright (yields), the winner raises the
		                          weapon; side "draw" with reason "draw" (both at 0 HP): both slump;
		                          a forfeit: the champion who stayed raises the weapon. Then nothing more.
	A late joiner starts from the next event: the next snapshot gives each side's state.
	The local champion's own presses play at once (FORGE-00's ruling on FL-0141): track:predict(action) when
	DuelController:act() sent one. It is a cosmetic guess on this client only: a press the last state or the
	stamina would refuse (DuelModel.step's rules, config Duel's costs) does not play; the server's next state
	or event confirms it (windup or recover for a swing, heavyWindup, a hit, block, parry, dodge); unconfirmed
	after CONFIRM_SEC it stops. A predicted guard holds from the press to the release (blockEnd), and a stale
	"block" state just after the release does not raise it again (RELEASE_GRACE).
	Priorities: the ending 4 > stagger 3 > an action (light, heavy, parry, dodge) 2 > a flinch or a guard
	jolt 1 > the held guard 0. A new animation replaces the current one when its priority is at least as
	high or the current one has finished. Every change crossfades over XFADE seconds.

	Weapon styles (snapshot side.weapon): swordShield and mace "slash" (one-handed, shield on the left
	arm), greatsword "twoHand", spear "thrust". light, heavy, the held guard and the ready stance differ by
	style; an unknown weapon reads as "slash".

	Joints (Sim/Pose frame: X right, Y up, Z back; the rig faces -Z):
		Root   the whole body at the hips: lift (Y), sidestep (X), step back (Z) and lean
		Waist  the upper body: twist (Y) and lean (X); Rx(-a) leans forward
		Head, LeftArm, RightArm (Rx(+a) swings forward; Rz(-a) raises the left arm sideways, Rz(+a) the
		right one), LeftLeg, RightLeg (in the Root's frame before the lean: DuelRig keeps the feet planted),
		Tool   the weapon at the hand (R15 RightWrist; a Kit rig's Tool joint): FORGE-02's weapons stand upright
		       when the arm points forward (Kit.weapon's grip), so the weapon's elevation is about the arm's
		       swing plus Tool's: Rx(-a) tips it down (a level thrust, a chop that ends low)
	`full` animations (dodge, flinch, stagger, kneel) move Root and the legs; the others move only the upper
	body, so a walking avatar keeps its own legs (DuelRig, `body` weight).
	Bounds: every joint within LIMITS (degrees), Root offsets within 1.5 studs (spec).

	API
		DuelPoses.newDuel() -> Duel                     both sides' tracks
		duel:predict(side, action, now) -> boolean     the local champion's own sent press (above)
		duel:onEvent(event, now)                        one Arena.Events entry (G12.1 DuelEvent)
		duel:start(now) / duel:stop(now) / duel:reset() a duel's ready stances on; fade out; forget all
		duel.a, duel.b: Track
		track.name -> string?                           the animation playing ("light", "block", ...)
		track:sample(now, out, motion?) -> Out          out = { pose: { [joint]: CFrame }, weight, body }
		    weight 0..1: how much the pose applies (0 = leave the rig alone); body 0..1: Root and legs
		    motion = false freezes the periodic parts (reduced motion: no wobble, no pump, no breathing)
		DuelPoses.keys(name, style?, windup?) -> { { t, pose } }?   the keyframes (specs, renders)
		DuelPoses.pose(numbers, out?) -> { [joint]: CFrame }        numbers → CFrames
		DuelPoses.JOINTS, LIMITS, STYLE, PRIORITY, FULL, LENGTH, XFADE, LIGHT_WINDUP, HEAVY_WINDUP
]]

local DuelConfig = require("@game/ReplicatedStorage/Forge/Config/Duel")

local DuelPoses = {}

export type Joints = { [string]: CFrame }
export type Numbers = { [string]: { number } } -- joint -> { x, y, z (degrees), px, py, pz (studs) }
export type Key = { t: number, pose: Numbers }
export type Out = { pose: Joints, weight: number, body: number }

DuelPoses.JOINTS = table.freeze({ "Root", "Waist", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" })
DuelPoses.LIMITS = table.freeze({
	Root = 90,
	Waist = 60,
	Head = 30,
	LeftArm = 150,
	RightArm = 150,
	LeftLeg = 90,
	RightLeg = 90,
	Tool = 90,
})
DuelPoses.STYLE = table.freeze({ swordShield = "slash", mace = "slash", greatsword = "twoHand", spear = "thrust" })
DuelPoses.PRIORITY = table.freeze({
	ko = 4,
	yield = 4,
	victory = 4,
	stagger = 3,
	light = 2,
	heavy = 2,
	parry = 2,
	dodge = 2,
	flinch = 1,
	flinchHeavy = 1,
	guardHit = 1,
	block = 0,
})
DuelPoses.FULL =
	table.freeze({ dodge = true, flinch = true, flinchHeavy = true, stagger = true, ko = true, yield = true })
DuelPoses.XFADE = 0.1 -- seconds of crossfade between two animations
DuelPoses.LIGHT_WINDUP = 0.18 -- seen from the snapshot (up to 0.2 s late): the server's 0.26–0.36 s less the lag
DuelPoses.LIGHT_STRIKE = 0.12
DuelPoses.LIGHT_RECOVER = 0.27
DuelPoses.HEAVY_WINDUP = table.freeze({ default = 0.8, min = 0.25, max = 1.5 })
DuelPoses.HEAVY_STRIKE = 0.16
DuelPoses.HEAVY_RECOVER = 0.45
DuelPoses.RECENT_STRIKE = 0.5 -- a recover state or a hit this soon after a strike is the same swing
DuelPoses.CONFIRM_SEC = 0.5 -- a predicted press the server has not confirmed by then stops (ping + 0.2 s snapshots)
DuelPoses.RELEASE_GRACE = 0.35 -- after your own release, a stale "block" state does not raise the guard again
-- DuelModel.step: the states each action may start from (light, heavy, block from idle; parry, dodge from block too)
DuelPoses.STARTS_FROM = table.freeze({
	light = table.freeze({ idle = true }),
	heavy = table.freeze({ idle = true }),
	block = table.freeze({ idle = true }),
	parry = table.freeze({ idle = true, block = true }),
	dodge = table.freeze({ idle = true, block = true }),
})
-- the server states and events that confirm a predicted animation
local CONFIRMS = table.freeze({
	windup = table.freeze({ light = true, heavy = true }),
	recover = table.freeze({ light = true, heavy = true }),
	block = table.freeze({ block = true }),
	parry = table.freeze({ parry = true }),
	dodge = table.freeze({ dodge = true }),
})
DuelPoses.HOLD = table.freeze({ ko = 5, yield = 5, victory = 3 }) -- seconds an ending pose holds
DuelPoses.LENGTH = table.freeze({
	parry = 0.35,
	dodge = 0.35,
	flinch = 0.35,
	flinchHeavy = 0.55,
	guardHit = 0.25,
	stagger = 1.0,
	ko = 0.6,
	yield = 0.6,
	victory = 0.4,
})

local rad = math.rad
local TAU = 2 * math.pi
local IDENTITY = CFrame.new()
local JOINTS = DuelPoses.JOINTS

-- ------------------------------------------------------------------ key poses (degrees, studs)

local function p(spec: { [string]: { number } }): Numbers
	return table.freeze(spec) :: any
end

-- The ready stance: feet apart, left foot forward, the upper body turned right so the off hand leads.
-- Yaw: Ry(+a) turns the chest left (the right shoulder comes forward), Ry(-a) turns it right.
local LEGS_READY = { LeftLeg = { 10, 0, -7 }, RightLeg = { -10, 0, 7 } }

local function with(base: { [string]: { number } }, extra: { [string]: { number } }): Numbers
	local out = table.clone(base)
	for joint, value in extra do
		out[joint] = value
	end
	return p(out)
end

local READY = {
	slash = with(LEGS_READY, {
		Waist = { -8, -15, 0 },
		Head = { 8, 15, 0 },
		RightArm = { 40, 0, 15 },
		LeftArm = { 65, 0, -10 },
	}),
	twoHand = with(LEGS_READY, {
		Waist = { -8, -10, 0 },
		Head = { 8, 10, 0 },
		RightArm = { 55, 0, -10 },
		Tool = { -15, 0, 0 },
		LeftArm = { 55, 0, 20 },
	}),
	thrust = with(LEGS_READY, {
		Waist = { -8, -20, 0 },
		Head = { 8, 20, 0 },
		RightArm = { 55, 0, 10 },
		Tool = { -35, 0, 0 },
		LeftArm = { 60, 0, -5 },
	}),
}

local BLOCK = {
	-- the shield raised across the chest, the sword low and ready
	slash = with(LEGS_READY, {
		Waist = { -10, -30, 0 },
		Head = { 5, 25, 0 },
		LeftArm = { 95, 0, 25 }, -- Rz(+a) brings the left arm in, across the chest
		RightArm = { 60, 0, 20 },
	}),
	-- the blade held level across the front
	twoHand = with(LEGS_READY, {
		Waist = { -10, -10, 0 },
		Head = { 5, 10, 0 },
		RightArm = { 105, 0, -25 },
		Tool = { -90, 0, 0 },
		LeftArm = { 105, 0, 25 },
	}),
	thrust = with(LEGS_READY, {
		Waist = { -10, -15, 0 },
		Head = { 5, 15, 0 },
		RightArm = { 85, 0, -30 },
		Tool = { -85, 0, 0 },
		LeftArm = { 85, 0, 15 },
	}),
}

-- light: { windup pose, strike pose } per style
local LIGHT = {
	slash = {
		with(LEGS_READY, {
			Waist = { -5, -40, 0 },
			Head = { 5, 28, 0 },
			RightArm = { 125, 0, 55 },
			LeftArm = { 60, 0, -20 },
		}),
		with(LEGS_READY, {
			Waist = { -20, 35, 0 },
			Head = { 12, -25, 0 },
			RightArm = { 55, 0, -30 },
			LeftArm = { 25, 0, -30 },
			Tool = { -70, 0, 0 },
		}),
	},
	twoHand = {
		with(LEGS_READY, {
			Waist = { -5, -35, 0 },
			Head = { 5, 30, 0 },
			RightArm = { 130, 0, 40 },
			LeftArm = { 130, 0, 15 },
		}),
		with(LEGS_READY, {
			Waist = { -20, 30, 0 },
			Head = { 12, -25, 0 },
			RightArm = { 60, 0, -25 },
			Tool = { -70, 0, 0 },
			LeftArm = { 60, 0, -45 },
		}),
	},
	thrust = {
		with(LEGS_READY, {
			Waist = { 0, -25, 0 },
			Head = { 5, 25, 0 },
			RightArm = { 40, 0, 10 },
			Tool = { -40, 0, 0 },
			LeftArm = { 70, 0, -5 },
		}),
		with(LEGS_READY, {
			Waist = { -18, 20, 0 },
			Head = { 12, -15, 0 },
			RightArm = { 95, 0, -5 },
			Tool = { -90, 0, 0 },
			LeftArm = { 85, 0, -15 },
		}),
	},
}

-- heavy: { wind-up pose (held), strike pose } per style
local HEAVY = {
	slash = {
		with(LEGS_READY, {
			Waist = { 20, -20, 0 },
			Head = { -8, 20, 0 },
			RightArm = { 150, 0, 8 },
			LeftArm = { 115, 0, 12 },
		}),
		with(LEGS_READY, {
			Waist = { -35, 10, 0 },
			Head = { 20, -10, 0 },
			RightArm = { 35, 0, -10 },
			LeftArm = { 30, 0, -30 },
			Tool = { -60, 0, 0 },
		}),
	},
	twoHand = {
		with(LEGS_READY, {
			Waist = { 15, -10, 0 },
			Head = { -5, 10, 0 },
			RightArm = { 150, 0, -8 }, -- both hands together over the head
			LeftArm = { 150, 0, 8 },
		}),
		with(LEGS_READY, {
			Waist = { -35, 5, 0 },
			Head = { 20, -5, 0 },
			RightArm = { 40, 0, -15 },
			Tool = { -55, 0, 0 },
			LeftArm = { 40, 0, 15 },
		}),
	},
	thrust = {
		with(LEGS_READY, {
			Waist = { 8, -35, 0 },
			Head = { 0, 30, 0 },
			RightArm = { 30, 0, 25 },
			Tool = { -30, 0, 0 },
			LeftArm = { 80, 0, -10 },
		}),
		with(LEGS_READY, {
			Waist = { -30, 25, 0 },
			Head = { 20, -20, 0 },
			RightArm = { 95, 0, -8 },
			Tool = { -90, 0, 0 },
			LeftArm = { 90, 0, -20 },
		}),
	},
}

-- the deflect: a sweep across, then a flick outwards
local PARRY_IN = with(LEGS_READY, {
	Waist = { -10, 30, 0 },
	Head = { 8, -25, 0 },
	RightArm = { 95, 0, -50 },
	Tool = { -50, 0, 0 },
	LeftArm = { 40, 0, -10 },
})
local PARRY_OUT = with(LEGS_READY, {
	Waist = { -5, -20, 0 },
	Head = { 8, 15, 0 },
	RightArm = { 110, 0, 45 },
	Tool = { -30, 0, 0 },
	LeftArm = { 55, 0, -25 },
})

-- a ducking sidestep; dir -1 = to the left, 1 = to the right
local function dodgePose(dir: number): Numbers
	return p({
		Root = { 0, 0, -dir * 18, dir * 1.1, -0.3, 0 },
		Waist = { -15, 0, 0 },
		Head = { 10, 0, dir * 10 },
		LeftArm = { 70, 0, -30 },
		RightArm = { 40, 0, 30 },
		LeftLeg = { 0, 0, -15 },
		RightLeg = { 0, 0, 15 },
	})
end

local function flinchPose(scale: number): Numbers
	return p({
		Root = { 12 * scale, 0, 0, 0, -0.1 * scale, 0.6 * (scale - 0.5) },
		Waist = { 10 * scale, 0, 0 },
		Head = { 20 * scale, 0, 0 },
		RightArm = { 20, 0, 35 * scale },
		LeftArm = { 20, 0, -35 * scale },
		LeftLeg = { 8 * scale, 0, -7 },
		RightLeg = { -12 * scale, 0, 7 },
	})
end

local STAGGER_BACK = p({
	Root = { 18, 0, 0, 0, -0.2, 0.8 },
	Waist = { 10, 15, 0 },
	Head = { 15, -15, 0 },
	RightArm = { 60, 0, 60 },
	LeftArm = { 70, 0, -55 },
	LeftLeg = { 25, 0, -8 },
	RightLeg = { -20, 0, 8 },
})
local STAGGER_SWAY = p({
	Root = { 10, 0, 8, 0, -0.15, 0.5 },
	Waist = { 5, -15, 0 },
	Head = { 10, 10, 0 },
	RightArm = { 45, 0, 40 },
	LeftArm = { 50, 0, -45 },
	LeftLeg = { 15, 0, -8 },
	RightLeg = { -10, 0, 8 },
})

-- the defeat: knocked back, then down on both knees (the legs swing back), slumped
local KO_BACK = p({
	Root = { 10, 0, 0, 0, -0.2, 0.3 },
	Waist = { 8, 0, 0 },
	Head = { 15, 0, 0 },
	RightArm = { 30, 0, 35 },
	LeftArm = { 30, 0, -35 },
	LeftLeg = { 10, 0, -6 },
	RightLeg = { -5, 0, 6 },
})
local KO_DOWN = p({
	Root = { -6, 0, 0, 0, -1.1, 0 },
	Waist = { -22, 0, 5 },
	Head = { -28, 0, 0 },
	RightArm = { 18, 0, 6 },
	Tool = { -20, 0, 0 },
	LeftArm = { 22, 0, -6 },
	LeftLeg = { -55, 0, -6 },
	RightLeg = { -65, 0, 6 },
})
-- the yield: down on both knees, upright, the head bowed and the weapon lowered
local YIELD_DOWN = p({
	Root = { 0, 0, 0, 0, -1.1, 0 },
	Waist = { -5, 0, 0 },
	Head = { -25, 0, 0 },
	RightArm = { 10, 0, 8 },
	Tool = { -40, 0, 0 },
	LeftArm = { 10, 0, -8 },
	LeftLeg = { -60, 0, -6 },
	RightLeg = { -60, 0, 6 },
})
local VICTORY = with(LEGS_READY, {
	Waist = { 8, 0, 0 },
	Head = { 15, 0, 0 },
	RightArm = { 150, 0, 15 },
	Tool = { -60, 0, 0 },
	LeftArm = { 40, 0, -35 },
})

local function styleOf(style: string?): string
	return if style == "twoHand" or style == "thrust" then style else "slash"
end

local function heavyWindup(windup: number?): number
	local w = if type(windup) == "number" and windup == windup then windup else DuelPoses.HEAVY_WINDUP.default
	return math.clamp(w, DuelPoses.HEAVY_WINDUP.min, DuelPoses.HEAVY_WINDUP.max)
end

-- The keyframes of one animation: { { t, pose } }, t in seconds from its start. dir: the dodge's side.
function DuelPoses.keys(name: string, style: string?, windup: number?, dir: number?): { Key }?
	local s = styleOf(style)
	local ready = READY[s]
	if name == "ready" then
		return { { t = 0, pose = ready } }
	elseif name == "block" then
		return { { t = 0, pose = ready }, { t = 0.12, pose = BLOCK[s] } }
	elseif name == "light" then
		local w = if type(windup) == "number" and windup == windup
			then math.clamp(windup, 0.1, 0.6)
			else DuelPoses.LIGHT_WINDUP
		local strike = w + DuelPoses.LIGHT_STRIKE
		return {
			{ t = 0, pose = ready },
			{ t = w, pose = LIGHT[s][1] },
			{ t = strike, pose = LIGHT[s][2] },
			{ t = strike + DuelPoses.LIGHT_RECOVER, pose = ready },
		}
	elseif name == "heavy" then
		local w = heavyWindup(windup)
		local strike = w + DuelPoses.HEAVY_STRIKE
		return {
			{ t = 0, pose = ready },
			{ t = math.min(0.3, w * 0.5), pose = HEAVY[s][1] }, -- raised fast, then held: the telegraph
			{ t = w, pose = HEAVY[s][1] },
			{ t = strike, pose = HEAVY[s][2] },
			{ t = strike + DuelPoses.HEAVY_RECOVER, pose = ready },
		}
	elseif name == "guardHit" then
		local block = BLOCK[s]
		local jolt = table.clone(block) :: any
		local waist = block.Waist
		jolt.Waist = { waist[1] + 10, waist[2], waist[3] }
		local head = block.Head
		jolt.Head = { head[1] + 12, head[2], head[3] }
		jolt.Root = { 4, 0, 0, 0, 0, 0.25 }
		return { { t = 0, pose = block }, { t = 0.06, pose = p(jolt) }, { t = DuelPoses.LENGTH.guardHit, pose = block } }
	elseif name == "parry" then
		return {
			{ t = 0, pose = ready },
			{ t = 0.08, pose = PARRY_IN },
			{ t = 0.2, pose = PARRY_OUT },
			{ t = DuelPoses.LENGTH.parry, pose = ready },
		}
	elseif name == "dodge" then
		local side = if dir == 1 then 1 else -1
		return {
			{ t = 0, pose = ready },
			{ t = 0.12, pose = dodgePose(side) },
			{ t = DuelPoses.LENGTH.dodge, pose = ready },
		}
	elseif name == "flinch" or name == "flinchHeavy" then
		local length = DuelPoses.LENGTH[name]
		local scale = if name == "flinchHeavy" then 1 else 0.6
		return { { t = 0, pose = ready }, { t = 0.07, pose = flinchPose(scale) }, { t = length, pose = ready } }
	elseif name == "stagger" then
		return {
			{ t = 0, pose = ready },
			{ t = 0.15, pose = STAGGER_BACK },
			{ t = 0.45, pose = STAGGER_SWAY },
			{ t = 0.8, pose = STAGGER_BACK },
			{ t = DuelPoses.LENGTH.stagger, pose = ready },
		}
	elseif name == "ko" then
		return { { t = 0, pose = ready }, { t = 0.25, pose = KO_BACK }, { t = DuelPoses.LENGTH.ko, pose = KO_DOWN } }
	elseif name == "yield" then
		return { { t = 0, pose = ready }, { t = DuelPoses.LENGTH.yield, pose = YIELD_DOWN } }
	elseif name == "victory" then
		return { { t = 0, pose = ready }, { t = DuelPoses.LENGTH.victory, pose = VICTORY } }
	end
	return nil
end

-- The stamina share an action needs (config Duel: a cost over maxStamina; a dodge's cost is the armour's).
function DuelPoses.cost(action: string, armour: string?): number
	local rules = DuelConfig.rules
	local max = rules.maxStamina
	if action == "light" then
		return rules.lightCost / max
	elseif action == "heavy" then
		return rules.heavyCost / max
	elseif action == "parry" then
		return rules.parryCost / max
	elseif action == "dodge" then
		local kind = DuelConfig.armour[armour or "medium"] or DuelConfig.armour.medium
		return kind.dodgeCost / max
	end
	return 0
end

-- A predicted swing's windup: the weapon's own (config Duel), nil for any other action or an unknown weapon.
function DuelPoses.windup(action: string, weapon: string?): number?
	local stats = DuelConfig.weapons[weapon or ""]
	if stats == nil then
		return nil
	end
	return if action == "light" then stats.lightWindup elseif action == "heavy" then stats.heavyWindup else nil
end

-- ------------------------------------------------------------------ sampling

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local ZERO = table.freeze({ 0, 0, 0, 0, 0, 0 })

-- out[joint][i] = a + (b - a) * u for every joint and component (missing joints and components are 0).
local function blend(a: Numbers, b: Numbers, u: number, out: { [string]: { number } })
	for _, joint in JOINTS do
		local x, y = a[joint] or ZERO, b[joint] or ZERO
		local into = out[joint]
		if into == nil then
			into = { 0, 0, 0, 0, 0, 0 }
			out[joint] = into
		end
		for i = 1, 6 do
			local from, to = x[i] or 0, y[i] or 0
			into[i] = from + (to - from) * u
		end
	end
end

-- The keyframes at time t (seconds from the start), into out; after the last key its pose holds.
local function sampleKeys(keys: { Key }, t: number, out: { [string]: { number } })
	if t <= keys[1].t or #keys == 1 then
		blend(keys[1].pose, keys[1].pose, 0, out)
		return
	end
	for i = 2, #keys do
		local key = keys[i]
		if t < key.t then
			local prev = keys[i - 1]
			blend(prev.pose, key.pose, smooth((t - prev.t) / (key.t - prev.t)), out)
			return
		end
	end
	local last = keys[#keys].pose
	blend(last, last, 0, out)
end

-- numbers → CFrames (Root's offset first, then its rotation)
function DuelPoses.pose(numbers: { [string]: { number } }, out: Joints?): Joints
	local joints = out or {}
	for _, joint in JOINTS do
		local v = numbers[joint] or ZERO
		local rotation = CFrame.Angles(rad(v[1] or 0), rad(v[2] or 0), rad(v[3] or 0))
		local px, py, pz = v[4] or 0, v[5] or 0, v[6] or 0
		joints[joint] = if px == 0 and py == 0 and pz == 0 then rotation else CFrame.new(px, py, pz) * rotation
	end
	return joints
end

-- ------------------------------------------------------------------ one champion's track

local Track = {}
Track.__index = Track

local function newTrack()
	return setmetatable({
		name = nil :: string?, -- the animation playing
		style = "slash",
		state = nil :: string?, -- the last snapshot state
		active = false, -- a duel is on: the ready stance shows between animations
		final = false, -- the duel ended: nothing more starts
		_anim = nil :: any, -- { name, start, keys, length, priority, full, windup? }
		_lastStrike = -math.huge,
		_dodges = 0,
		_source = nil :: any, -- what the last sample showed (crossfades start when it changes)
		_from = {} :: { [string]: { number } }, -- the crossfade's start pose
		_fromWeight = 0,
		_fromBody = 0,
		_fromAt = -math.huge,
		_numbers = {} :: { [string]: { number } }, -- the last sampled pose (numbers)
		_target = {} :: { [string]: { number } },
		_weight = 0,
		_body = 0,
		_stopAt = nil :: number?,
		weapon = nil :: string?, -- the snapshot's weapon, armour and stamina share (the press echo's checks)
		armour = nil :: string?,
		stamina = nil :: number?,
		_holding = false, -- the local champion holds the guard (a predicted block until the release)
		_releasedAt = nil :: number?,
	}, Track)
end

function Track:reset()
	self.name, self.state, self.active, self.final = nil, nil, false, false
	self._anim, self._lastStrike, self._dodges, self._source, self._stopAt = nil, -math.huge, 0, nil, nil
	self._weight, self._body, self._fromWeight, self._fromBody, self._fromAt = 0, 0, 0, 0, -math.huge
	self.weapon, self.armour, self.stamina, self._holding, self._releasedAt = nil, nil, nil, false, nil
end

-- The guard is up: held by the local champion, or the server's state says block (except just after our
-- own release, while that state may still be stale).
function Track:_guarding(now: number): boolean
	if self._holding then
		return true
	end
	if self.state ~= "block" then
		return false
	end
	return self._releasedAt == nil or now - self._releasedAt >= DuelPoses.RELEASE_GRACE
end

function Track:_ended(now: number): boolean
	local anim = self._anim
	if anim == nil then
		return true
	end
	if anim.predicted ~= nil and now - anim.predicted > DuelPoses.CONFIRM_SEC then
		return true -- the server never confirmed our press (refused, or lost)
	end
	if anim.name == "block" then
		return not self:_guarding(now) -- held while the guard is up
	end
	return now >= anim.start + anim.length + (anim.hold or 0)
end

function Track:_current(now: number): any
	if self._anim ~= nil and self:_ended(now) then
		if self._anim.predicted ~= nil and self._anim.name == "block" then
			self._holding = false -- an unconfirmed guard is not held any more
		end
		self._anim = nil
		self.name = nil
		if self:_guarding(now) and not self.final then
			-- back to the held guard (after a guard jolt, say), already raised: no dip to the ready stance
			self:play("block", now, { start = now - 0.12 })
		end
	end
	return self._anim
end

-- Starts `name` when its priority allows. start: its start time (a jump into the middle sets it earlier).
function Track:play(name: string, now: number, opts: { windup: number?, start: number? }?): boolean
	if self.final and DuelPoses.PRIORITY[name] < 4 then
		return false
	end
	local current = self:_current(now)
	if current ~= nil and DuelPoses.PRIORITY[name] < current.priority then
		return false
	end
	local options = opts or {}
	local dir = nil
	if name == "dodge" then
		self._dodges += 1
		dir = if self._dodges % 2 == 1 then -1 else 1
	end
	local keys = DuelPoses.keys(name, self.style, options.windup, dir) :: { Key }
	local windup = nil
	if name == "light" then
		windup = keys[2].t -- the windup the keys were built with
	elseif name == "heavy" then
		windup = heavyWindup(options.windup)
	end
	self._anim = {
		name = name,
		start = options.start or now,
		keys = keys,
		length = keys[#keys].t,
		priority = DuelPoses.PRIORITY[name],
		full = DuelPoses.FULL[name] == true,
		windup = windup,
		hold = if name == "block" then nil else DuelPoses.HOLD[name],
	}
	self.name = name
	return true
end

function Track:_attack(now: number): any
	local anim = self:_current(now)
	return if anim ~= nil and (anim.name == "light" or anim.name == "heavy") then anim else nil
end

-- The swing reaches its strike now: a winding-up swing jumps to it; with no swing (its windup was not
-- seen), a new one starts at its strike, unless one struck a moment ago (the same swing).
function Track:strike(heavy: boolean?, now: number)
	local anim = self:_attack(now)
	if anim ~= nil then
		anim.predicted = nil -- a hit confirms our own press
		if now < anim.start + anim.windup then
			anim.start = now - anim.windup
			self._lastStrike = now
		end
		return
	end
	if now - self._lastStrike < DuelPoses.RECENT_STRIKE then
		return
	end
	local name = if heavy == true then "heavy" else "light"
	local windup = if name == "heavy" then heavyWindup(nil) else DuelPoses.LIGHT_WINDUP
	if self:play(name, now, { start = now - windup }) then
		self._lastStrike = now
	end
end

function Track:onState(state: any, now: number)
	if type(state) ~= "string" then
		return
	end
	self.state = state
	local current = self._anim
	if current ~= nil and current.predicted ~= nil and CONFIRMS[state] and CONFIRMS[state][current.name] then
		current.predicted = nil -- the server confirms our own press
	end
	if self.final then
		return
	end
	if state == "windup" then
		if self:_attack(now) == nil then -- a second windup sample of the same swing finds it playing
			self:play("light", now)
		end
	elseif state == "recover" then
		self:strike(nil, now)
	elseif state == "block" then
		local anim = self:_current(now)
		if anim == nil and self:_guarding(now) then
			self:play("block", now)
		end
	elseif state == "parry" or state == "dodge" or state == "stagger" then
		local anim = self:_current(now)
		if anim == nil or anim.name ~= state then
			self:play(state, now)
		end
	end
end

-- Hit by the other side's swing: a flinch, or the guard jolts while blocking.
function Track:hitBy(heavy: boolean, now: number)
	if self.final then
		return
	end
	if self:_guarding(now) then
		self:play("guardHit", now)
	else
		self:play(if heavy then "flinchHeavy" else "flinch", now)
	end
end

-- The local champion's own press, sent (see the header): true when it plays.
function Track:predict(action: string, now: number): boolean
	if self.final or not self.active then
		return false
	end
	if action == "blockEnd" then
		self._holding = false
		self._releasedAt = now
		self:_current(now) -- the guard is down now (a stale "block" state is ignored): the block ends at once
		return true
	end
	local from = DuelPoses.STARTS_FROM[action]
	if from == nil or (self.state ~= nil and not from[self.state]) then
		return false -- the server would refuse it from this state
	end
	if type(self.stamina) == "number" and self.stamina < DuelPoses.cost(action, self.armour) then
		return false -- not enough stamina
	end
	local current = self:_current(now)
	if current ~= nil and current.priority >= DuelPoses.PRIORITY.light then
		return false -- busy: an action, a stagger or the end
	end
	if not self:play(action, now, { windup = DuelPoses.windup(action, self.weapon) }) then
		return false
	end
	self._anim.predicted = now
	if action == "block" then
		self._holding, self._releasedAt = true, nil
	end
	return true
end

function Track:finish(name: string?, now: number)
	if name ~= nil then
		self:play(name, now)
	elseif self._anim ~= nil and self._anim.priority < 4 then
		self._anim = nil
		self.name = nil
	end
	self.final = true
end

-- The pose now, into out = { pose, weight, body }. motion false: no periodic movement.
function Track:sample(now: number, out: Out, motion: boolean?): Out
	local moving = motion ~= false
	local anim = self:_current(now)
	local target = self._target
	local source: any
	local weight, body = 0, 0
	if anim ~= nil then
		sampleKeys(anim.keys, now - anim.start, target)
		source = anim
		weight, body = 1, if anim.full then 1 else 0
		local t = now - anim.start
		if moving and anim.name == "stagger" then
			target.Waist[3] += 8 * math.sin(TAU * 3 * t) * (1 - math.clamp(t / anim.length, 0, 1))
		elseif moving and anim.name == "victory" and t > anim.length then
			target.RightArm[1] -= 12 * math.abs(math.sin(TAU * 1.2 * (t - anim.length)))
		end
		if anim.hold ~= nil then -- the ending pose fades out over the last XFADE of its hold
			local fade = smooth((anim.start + anim.length + anim.hold - now) / DuelPoses.XFADE)
			weight, body = fade, body * fade
		end
	elseif self.active and not self.final then
		sampleKeys(DuelPoses.keys("ready", self.style) :: { Key }, 0, target)
		source = self.style -- the stance changes with the weapon
		weight = 1
		if moving then
			target.Waist[1] += 1.5 * math.sin(TAU * 0.5 * now)
		end
	else
		sampleKeys(DuelPoses.keys("ready", self.style) :: { Key }, 0, target)
		source = "rest"
	end
	if self._stopAt ~= nil then
		source, weight, body = "stop", 0, 0 -- the duel is over here: fade out (a crossfade)
	end
	if source ~= self._source then
		self._source = source
		blend(self._numbers, self._numbers, 0, self._from) -- copy the last pose
		self._fromWeight, self._fromBody, self._fromAt = self._weight, self._body, now
	end
	local u = smooth((now - self._fromAt) / DuelPoses.XFADE)
	blend(self._from, target, u, self._numbers)
	self._weight = self._fromWeight + (weight - self._fromWeight) * u
	self._body = self._fromBody + (body - self._fromBody) * u
	if self._weight < 1e-3 then
		self._weight = 0 -- faded out: DuelRig leaves an avatar to its Animator
	end
	if self._body < 1e-3 then
		self._body = 0
	end
	out.pose = DuelPoses.pose(self._numbers, out.pose)
	out.weight = self._weight
	out.body = self._body
	return out
end

-- ------------------------------------------------------------------ both sides

local Duel = {}
Duel.__index = Duel

local OTHER = table.freeze({ a = "b", b = "a" })

function DuelPoses.newDuel()
	return setmetatable({ a = newTrack(), b = newTrack() }, Duel)
end

function Duel:reset()
	self.a:reset()
	self.b:reset()
end

function Duel:start(_now: number)
	for _, side in { "a", "b" } do
		local track = self[side]
		track.active = true
		track._stopAt = nil
	end
end

function Duel:stop(now: number)
	for _, side in { "a", "b" } do
		local track = self[side]
		track.active = false
		track._stopAt = now
	end
end

function Duel:predict(side: string, action: string, now: number): boolean
	local track = if side == "a" or side == "b" then self[side] else nil
	return track ~= nil and track:predict(action, now)
end

function Duel:onEvent(event: any, now: number)
	if type(event) ~= "table" or type(event.kind) ~= "string" then
		return
	end
	local kind, side, data = event.kind, event.side, event.data
	local track = if side == "a" or side == "b" then self[side] else nil
	if kind == "snapshot" then
		if type(data) ~= "table" then
			return
		end
		for _, s in { "a", "b" } do
			local view = data[s]
			if type(view) == "table" then
				local t = self[s]
				if type(view.weapon) == "string" then
					t.style = DuelPoses.STYLE[view.weapon] or "slash"
					t.weapon = view.weapon
				end
				if type(view.armour) == "string" then
					t.armour = view.armour
				end
				if type(view.staminaShare) == "number" and view.staminaShare == view.staminaShare then
					t.stamina = view.staminaShare
				end
				t:onState(view.state, now)
			end
		end
	elseif kind == "heavyWindup" and track ~= nil then
		local impactIn = if type(data) == "table" then data.impactIn else nil
		local current = track:_attack(now)
		if current ~= nil and current.name == "heavy" then
			current.predicted = nil -- our own press, confirmed: the swing goes on, never restarted
		else
			track:play("heavy", now, { windup = impactIn })
		end
	elseif kind == "hit" and track ~= nil then
		local heavy = type(data) == "table" and data.heavy == true
		track:strike(heavy, now)
		self[OTHER[side]]:hitBy(heavy, now)
	elseif (kind == "parry" or kind == "stagger") and track ~= nil then
		local anim = track:_current(now)
		if not (anim ~= nil and anim.name == kind and now - anim.start < 0.1) then
			track:play(kind, now)
		end
	elseif kind == "ended" then
		local reason = if type(data) == "table" then data.reason else nil
		if track ~= nil then
			local loser = self[OTHER[side]]
			track:finish("victory", now)
			loser:finish(if reason == "ko" then "ko" elseif reason == "timeCap" then "yield" else nil, now)
		elseif reason == "draw" then
			self.a:finish("ko", now)
			self.b:finish("ko", now)
		else
			self.a:finish(nil, now)
			self.b:finish(nil, now)
		end
	end
end

DuelPoses.newTrack = newTrack
DuelPoses.IDENTITY = IDENTITY

return DuelPoses
