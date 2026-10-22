local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local DuelPoses = require("@game/ReplicatedStorage/Game/Feedback/DuelPoses")
local DuelRig = require("@game/ReplicatedStorage/Game/Feedback/DuelRig")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")
local AnimDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackDuelController")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local ME, RIVAL = 4101, 4102
local CF = CFrame.new

-- A minimal R15 avatar: the joints DuelRig writes, as Motor6Ds named like Roblox's.
local function avatar()
	local model = roblox.Instance.new("Model")
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	local function part(name, at)
		local p = roblox.Instance.new("Part")
		p.Name = name
		p.CFrame = at
		p.Parent = model
		return p
	end
	local function motor(name, p0, p1, c0)
		local m = roblox.Instance.new("Motor6D")
		m.Name, m.Part0, m.Part1, m.C0 = name, p0, p1, c0
		m.Parent = p1
	end
	local hrp = part("HumanoidRootPart", CF(0, 3, 0))
	local lower, upper = part("LowerTorso", CF(0, 2.2, 0)), part("UpperTorso", CF(0, 3.2, 0))
	motor("Root", hrp, lower, CF(0, -1, 0))
	motor("Waist", lower, upper, CF(0, 0.2, 0))
	motor("Neck", upper, part("Head", CF(0, 4.6, 0)), CF(0, 0.8, 0))
	local rightArm = part("RightUpperArm", CF(1.5, 3.4, 0))
	motor("RightShoulder", upper, rightArm, CF(1, 0.6, 0))
	motor("RightWrist", rightArm, part("RightHand", CF(1.5, 2.6, 0)), CF(0, -0.6, 0))
	motor("LeftShoulder", upper, part("LeftUpperArm", CF(-1.5, 3.4, 0)), CF(-1, 0.6, 0))
	motor("LeftHip", lower, part("LeftUpperLeg", CF(-0.5, 1.4, 0)), CF(-0.5, -0.2, 0))
	motor("RightHip", lower, part("RightUpperLeg", CF(0.5, 1.4, 0)), CF(0.5, -0.2, 0))
	model.PrimaryPart = hrp
	model.Parent = roblox.Instance.new("Folder") -- a live model has a parent
	return model
end

local function aiFigure(side)
	local model = Kit.character("governor", "idle", Color3.fromRGB(40, 90, 200))
	model:SetAttribute(AnimDef.SIDE_ATTRIBUTE, side)
	model.Parent = roblox.Instance.new("Folder")
	return model
end

local function joint(model, name)
	for _, d in model:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and d.Name == name then
			return d
		end
	end
	return nil
end

local function angleOf(cf: CFrame): number
	local _, a = cf:ToAxisAngle()
	return math.deg(a)
end

local function duellist(userId, isAI)
	return {
		userId = userId,
		kingdom = "crimson",
		isAI = isAI == true,
		tier = "loyal",
		score = 60,
		triggers = {},
		reasons = {},
	}
end

-- Boots the real DuelController and the animation controller. opts: { characters, champions, studio,
-- reduced, beforeStart, sets (counts adapter writes) }
local function boot(opts)
	opts = opts or {}
	local env = MockEnv.new({ seed = 141, isServer = false, localPlayer = { userId = ME } })
	local counts = { looks = 0, sets = 0, scans = 0 }
	local adapter = {
		get = function(j)
			return j.Transform
		end,
		set = function(j, value)
			counts.sets += 1
			j.Transform = value
		end,
	}
	local defs = {
		{ name = "DuelController", dependencies = DuelDef.dependencies, new = DuelDef.new },
		{
			name = "FeedbackDuelController",
			dependencies = AnimDef.dependencies,
			new = function(e, r)
				return AnimDef.create(e, r, {
					adapter = adapter,
					studio = opts.studio == true,
					player = opts.player,
					characterOf = function(userId)
						counts.looks += 1
						return (opts.characters or {})[userId]
					end,
					champions = function()
						return opts.champions or {}
					end,
				})
			end,
		},
	}
	if opts.sent ~= nil then -- InputModeArenaController's sent signal (a double)
		table.insert(defs, {
			name = "InputModeArenaController",
			new = function()
				return { sent = opts.sent }
			end,
		})
	end
	if opts.reduced ~= nil then
		table.insert(defs, {
			name = "SettingsController",
			new = function()
				return {
					reducedMotion = function()
						return opts.reduced == true
					end,
				}
			end,
		})
	end
	if opts.beforeStart then
		opts.beforeStart(env)
	end
	local registry = Loader.load(env, defs)
	return {
		env = env,
		duel = registry:get("DuelController"),
		anim = registry:get("FeedbackDuelController"),
		counts = counts,
	}
end

-- frames at 60 Hz from the env clock, for `seconds`
local function frames(t, seconds)
	local n = math.floor(seconds * 60 + 0.5)
	for _ = 1, n do
		t.env.mock:advance(1 / 60)
		t.anim:step()
	end
end

local function snapshot(a, b)
	return {
		kind = "snapshot",
		side = "a",
		data = { a = { state = a, weapon = "swordShield" }, b = { state = b, weapon = "greatsword" } },
	}
end

describe("FeedbackDuelController: the champions move with the duel (FL-0141)", function()
	it("depends on DuelController and follows its state and events: the human and the AI champion animate", function()
		expect(table.find(AnimDef.dependencies, "DuelController") ~= nil).toBe(true)
		local me, ai = avatar(), aiFigure("b")
		local t = boot({ characters = { [ME] = me }, champions = { aiFigure("a"), ai } })
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(0, true) })
		frames(t, 0.3)
		expect(t.anim:rig("a").kind).toBe("r15")
		expect(t.anim:rig("b").kind).toBe("kit")
		expect(t.anim:rig("b").model).toBe(ai) -- the figure tagged for side b, not a's
		expect(t.env.mock:hasLog("info", "champion a is a r15 rig, 8 Motor6D joints")).toBe(true) -- E21 step 1
		-- the ready stance: the sword arm forward (40°, 15° out)
		local ready = angleOf(CFrame.Angles(math.rad(40), 0, math.rad(15)))
		expect(math.abs(angleOf(joint(me, "RightShoulder").Transform) - ready) < 0.5).toBe(true)
		-- a light swing on a, a heavy wind-up on b, through DuelController's Arena.Events handler
		t.duel:onEvents({ snapshot("windup", "idle"), { kind = "heavyWindup", side = "b", data = { impactIn = 0.8 } } })
		frames(t, DuelPoses.LIGHT_WINDUP)
		expect(t.anim.poses.a.name).toBe("light")
		expect(angleOf(joint(me, "RightShoulder").Transform) > 100).toBe(true) -- cocked high
		frames(t, 0.3)
		expect(t.anim.poses.b.name).toBe("heavy")
		expect(angleOf(joint(ai, "RightArm").Transform) > 120).toBe(true) -- raised: the telegraph
		-- the AI is hit while blocking: its guard jolts; we are hit: we flinch
		t.duel:onEvents({ snapshot("idle", "block") })
		frames(t, 1.2) -- the heavy swing ends; the held guard follows it
		t.duel:onEvents({ { kind = "hit", side = "a", data = { heavy = false, damageShare = 0.02, hpShare = 0.9 } } })
		expect(t.anim.poses.b.name).toBe("guardHit")
		expect(t.anim.poses.a.name).toBe("light") -- a's hit is a's swing (its windup sample was missed)
		frames(t, 0.7)
		t.duel:onEvents({ { kind = "hit", side = "b", data = { heavy = true, damageShare = 0.14, hpShare = 0.7 } } })
		expect(t.anim.poses.a.name).toBe("flinchHeavy")
		-- the end: we win by KO; the AI kneels
		t.duel:onEvents({ { kind = "ended", side = "a", data = { reason = "ko" } } })
		frames(t, 1)
		expect(t.anim.poses.a.name).toBe("victory")
		expect(t.anim.poses.b.name).toBe("ko")
		local torso = joint(ai, "Torso").Transform
		expect(torso.Position.Y < -0.9).toBe(true) -- down on its knees
		-- the crowning keeps the poses; done fades them out, then gives the avatar back to its Animator
		t.duel:setState({ stage = "crowning", a = duellist(ME), b = duellist(0, true), winner = ME })
		frames(t, 0.5)
		expect(t.anim.poses.b.name).toBe("ko")
		t.duel:setState({ stage = "done" })
		frames(t, 0.05) -- halfway through the fade: still posed and easing out, no pop
		expect(t.anim:rig("b") ~= nil).toBe(true)
		local easing = joint(ai, "Torso").Transform.Position.Y
		expect(easing < -0.2 and easing > torso.Position.Y + 0.1).toBe(true)
		frames(t, DuelPoses.XFADE + 0.15)
		expect(t.anim:rig("a")).toBeNil()
		expect(DuelRig.same(joint(ai, "Torso").Transform, CFrame.new())).toBe(true) -- the Kit rig at rest
		local writes = t.counts.sets
		frames(t, 1)
		expect(t.counts.sets).toBe(writes) -- nothing is written outside the duel
	end)

	it("a burst of events costs no per-event work: one lookup per champion, one write per joint per frame", function()
		local me = avatar()
		local t = boot({ characters = { [ME] = me, [RIVAL] = avatar() } })
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(RIVAL) })
		frames(t, 0.1)
		local looks, sets = t.counts.looks, t.counts.sets
		local burst = {}
		for i = 1, 60 do
			local kinds = {
				snapshot("windup", "block"),
				{ kind = "hit", side = "a", data = { heavy = false } },
				snapshot("dodge", "parry"),
			}
			table.insert(burst, kinds[i % 3 + 1])
		end
		t.duel:onEvents(burst) -- 60 events in one frame
		frames(t, 1 / 60)
		expect(t.counts.looks).toBe(looks) -- no new lookup or scan
		local perFrame = t.counts.sets - sets
		expect(perFrame <= 2 * 10).toBe(true) -- at most the joints of two avatars, once each
		expect(perFrame > 0).toBe(true)
	end)

	it("your own sent press animates your champion at once; a spectator's press does nothing", function()
		local sent = Signal.new()
		local me = avatar()
		local t = boot({ characters = { [ME] = me, [RIVAL] = avatar() }, sent = sent })
		t.duel:setState({ stage = "duel", a = duellist(RIVAL), b = duellist(ME) }) -- we are champion b
		frames(t, 0.2)
		sent:fire("heavy") -- InputModeArenaController: DuelController:act("heavy") returned true
		expect(t.anim.poses.b.name).toBe("heavy")
		expect(t.anim.poses.a.name).toBeNil()
		frames(t, 0.3)
		expect(angleOf(joint(me, "RightShoulder").Transform) > 120).toBe(true) -- raised, no 0.2 s wait
		-- watching another pair: our presses (if any reached here) animate nobody
		t.duel:setState({ stage = "duel", a = duellist(RIVAL), b = duellist(9999) })
		sent:fire("light")
		expect(t.anim.poses.a.name).toBeNil()
		expect(t.anim.poses.b.name).toBeNil()
		-- an AI champion with our id (Studio's negative test ids) is not us, on either side
		t.duel:setState({ stage = "duel", a = duellist(ME, true), b = duellist(RIVAL) })
		sent:fire("light")
		expect(t.anim.poses.a.name).toBeNil()
		t.duel:setState({ stage = "duel", a = duellist(RIVAL), b = duellist(ME, true) })
		sent:fire("light")
		expect(t.anim.poses.a.name).toBeNil()
		expect(t.anim.poses.b.name).toBeNil()
	end)

	it("a pair first seen in the crowning (a late join, a coronation) is not posed: no ready stance", function()
		local winner, rival = avatar(), avatar()
		local t = boot({ characters = { [ME] = winner, [RIVAL] = rival } })
		t.duel:setState({ stage = "crowning", a = duellist(ME), b = duellist(RIVAL), winner = ME }) -- GetState
		frames(t, 0.5)
		expect(t.anim.poses.a.active).toBe(false)
		expect(t.anim:rig("a")).toBeNil()
		expect(t.counts.sets).toBe(0) -- the avatars stay their Animators' own
		expect(t.counts.looks).toBe(0)
		t.duel:setState({ stage = "done" })
		frames(t, 0.3)
		expect(t.counts.sets).toBe(0)
		-- a coronation: one kingdom left, straight to the crowning with no duel
		local crowned = boot({ characters = { [ME] = avatar() } })
		crowned.duel:setState({ stage = "crowning", a = duellist(ME), winner = ME })
		frames(crowned, 0.5)
		expect(crowned.counts.sets).toBe(0)
		-- the next duel this client sees from its start is posed as usual
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(9999) })
		frames(t, 0.1)
		expect(t.anim.poses.a.active).toBe(true)
		expect(t.anim:rig("a").model).toBe(winner)
		-- and a later pair first seen in its crowning is not, though this client watched the last duel
		t.duel:setState({ stage = "crowning", a = duellist(RIVAL), b = duellist(9999), winner = RIVAL })
		frames(t, 0.2)
		expect(t.anim.poses.a.active).toBe(false)
	end)

	it("a late joiner starts from DuelController's state and animates from the next event", function()
		local me = avatar()
		local t = boot({ characters = { [RIVAL] = me } }) -- we watch: RIVAL is champion b
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(RIVAL) }) -- the GetState answer
		frames(t, 0.2)
		expect(t.anim.poses.b.name).toBeNil() -- nothing yet: no event since we joined
		expect(t.anim.poses.b.active).toBe(true) -- the ready stance
		t.duel:onEvents({ snapshot("idle", "dodge") })
		expect(t.anim.poses.b.name).toBe("dodge")
	end)

	it("a new pair resets both; a respawned character is found again; a model without joints is retried", function()
		local first = avatar()
		local characters = { [ME] = first }
		local t = boot({ characters = characters })
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(RIVAL) })
		t.duel:onEvents({ snapshot("block", "idle") })
		frames(t, 0.2)
		expect(t.anim:rig("a").model).toBe(first)
		expect(t.anim.poses.a.name).toBe("block")
		-- a reset: the old character leaves, a new one comes
		local second = avatar()
		first.Parent = nil
		characters[ME] = second
		frames(t, 1 / 60) -- found again at once
		expect(t.anim:rig("a").model).toBe(second)
		-- a model whose joints have not streamed in yet: no rig, one info line, looked up again later
		local empty = roblox.Instance.new("Model")
		empty.Parent = roblox.Instance.new("Folder")
		characters[RIVAL] = empty
		frames(t, AnimDef.RESOLVE_SEC + 0.1)
		expect(t.anim:rig("b")).toBeNil()
		characters[RIVAL] = avatar()
		frames(t, AnimDef.RESOLVE_SEC + 0.1)
		expect(t.anim:rig("b") ~= nil).toBe(true)
		local infos = 0
		for _, entry in t.env.mock.logs do
			infos += if string.find(entry.message, "no joints to pose", 1, true) then 1 else 0
		end
		expect(infos).toBe(1)
		-- another pair: both tracks start over
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(9999) })
		expect(t.anim.poses.a.name).toBeNil()
		expect(t.anim.poses.a.active).toBe(true)
	end)

	it("reduced motion (SettingsController) keeps the stagger but not its wobble", function()
		local t = boot({ characters = { [ME] = avatar() }, reduced = true })
		t.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(RIVAL) })
		t.duel:onEvents({ { kind = "stagger", side = "a" } })
		frames(t, 0.3)
		expect(t.anim.poses.a.name).toBe("stagger")
		expect(t.anim.poses.a._numbers.Waist[3]).toBe(0)
		local moving = boot({ characters = { [ME] = avatar() }, reduced = false })
		moving.duel:setState({ stage = "duel", a = duellist(ME), b = duellist(RIVAL) })
		moving.duel:onEvents({ { kind = "stagger", side = "a" } })
		frames(moving, 0.3)
		expect(math.abs(moving.anim.poses.a._numbers.Waist[3]) > 1).toBe(true)
	end)

	it("Studio preview: your character plays every action; never outside Studio; a real duel takes over", function()
		local me = avatar()
		local t = boot({ characters = { [ME] = me }, studio = false })
		expect(t.anim:preview("spear")).toBe(false)
		local sent = Signal.new()
		local s = boot({ characters = { [ME] = me }, studio = true, player = { UserId = ME }, sent = sent })
		expect(s.anim:preview("spear")).toBe(true)
		sent:fire("heavy") -- the preview ignores presses (it plays as side a = you)
		expect(s.anim.poses.a.name).toBeNil()
		expect(s.anim.poses.a.style).toBe("slash") -- the weapon comes with the first preview snapshot
		local seen = {}
		for _ = 1, 60 * 16 do
			s.env.mock:advance(1 / 60)
			s.anim:step()
			local name = s.anim.poses.a.name
			if name ~= nil then
				seen[name] = true
			end
		end
		expect(s.anim.poses.a.style).toBe("thrust")
		for _, name in
			{ "light", "heavy", "block", "guardHit", "parry", "dodge", "flinch", "flinchHeavy", "stagger", "ko" }
		do
			assert(seen[name], `the preview plays {name}`)
		end
		expect(s.anim:rig("a").model).toBe(me)
		expect(s.anim:preview("")).toBe(true) -- stops
		expect(s.anim._preview).toBeNil()
		-- a "done" state does not stop a preview; a real duel stage does, and the preview cannot start over it
		s.anim:preview("mace")
		s.duel:setState({ stage = "done" })
		expect(s.anim._preview ~= nil).toBe(true)
		s.duel:setState({ stage = "duel", a = duellist(RIVAL), b = duellist(ME) })
		expect(s.anim._preview).toBeNil()
		expect(s.anim:preview("mace")).toBe(false)
	end)
end)
