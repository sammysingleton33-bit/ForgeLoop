local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local Pacing = require("@game/ReplicatedStorage/Forge/Config/Pacing")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")
local StageDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CrowdStageController")

local CENTRE = Vector3.new(141, 2, -27)
local STAND_A = Vector3.new(141, 6, -55) -- Stand A at the arena's -Z
local STAND_B = Vector3.new(141, 6, 1)
local USER = 9001

local function near(a: Vector3, b: Vector3, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

describe("CrowdStageController (FL-0074 part 2b: the arena intro, music and stingers)", function()
	local env, controller, camera, music, audio

	local function arenaModel()
		local model = roblox.Instance.new("Model")
		model.Name = "CrownArena"
		local root = roblox.Instance.new("Part")
		root.Name = "Root"
		root.CFrame = CFrame.new(CENTRE)
		root.Parent = model
		for name, position in { StandA_RoyalBox = STAND_A, StandB_RoyalBox = STAND_B, Centre = CENTRE } do
			local attachment = roblox.Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = CFrame.new(position - CENTRE)
			attachment.Parent = root
		end
		model.Parent = env.Workspace
		env.CollectionService:AddTag(model, "CrownArena")
		return model
	end

	local function boot(opts)
		opts = opts or {}
		camera = { shots = {}, stopped = 0 }
		function camera.playShots(_, shots)
			table.insert(camera.shots, shots)
			return opts.cameraRefuses ~= true
		end
		function camera.stopShots()
			camera.stopped += 1
			return true
		end
		music = { scenes = {} }
		function music.setScene(_, scene)
			table.insert(music.scenes, scene or false)
		end
		audio = { played = {} }
		function audio.play(_, id)
			table.insert(audio.played, id)
		end
		local defs = {
			{
				name = "RulerCameraController",
				new = function()
					return camera
				end,
			},
			{
				name = "MusicController",
				new = function()
					return music
				end,
			},
			{
				name = "AudioController",
				new = function()
					return audio
				end,
			},
			{
				name = "CrowdStageController",
				new = function(e, r)
					return StageDef.create(e, r, { studio = opts.studio, player = { UserId = USER } })
				end,
			},
		}
		controller = Loader.load(env, defs):get("CrowdStageController")
	end

	local function state(stage, extra)
		local s = {
			stage = stage,
			a = { userId = 101, kingdom = "crimson", isAI = false },
			b = { userId = 202, kingdom = "azure", isAI = false },
		}
		for k, v in extra or {} do
			s[k] = v
		end
		return s
	end

	local function count(list, value)
		local n = 0
		for _, v in list do
			if v == value then
				n += 1
			end
		end
		return n
	end

	-- the overview camera of a shot looks from the ring side toward its focus (yaw 0 looks toward -Z)
	local function looksAt(shot, from)
		local look = CameraDef.aerialCFrame(shot.focus, shot.yaw, shot.zoom, CameraDef.DEFAULTS.overview).LookVector
		local want = Vector3.new(shot.focus.X - from.X, 0, shot.focus.Z - from.Z).Unit
		return Vector3.new(look.X, 0, look.Z).Unit:Dot(want) > 0.99
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 74, isServer = false, localPlayer = { userId = USER } })
	end)

	it("the intro: one horn, the arena music, and a pass over the other stand, your own, then the ring", function()
		arenaModel()
		boot()
		controller:onKingdomState({ mine = "crimson" }) -- we are stand A
		controller:onArenaState(state("intro"))
		expect(count(audio.played, "arena.horn")).toBe(1)
		expect(music.scenes[#music.scenes]).toBe("arena")
		expect(#camera.shots).toBe(1)
		local shots = camera.shots[1]
		expect(#shots).toBe(3)
		expect(near(shots[1].focus, STAND_B)).toBe(true) -- the other kingdom's stand first
		expect(near(shots[2].focus, STAND_A)).toBe(true) -- then our own
		expect(near(shots[3].focus, CENTRE)).toBe(true) -- then the ring, seen from our side
		expect(looksAt(shots[1], CENTRE)).toBe(true)
		expect(looksAt(shots[2], CENTRE)).toBe(true)
		expect(looksAt(shots[3], STAND_A)).toBe(true)
		expect(shots[1].zoom).toBe(Crowd.intro.standZoom)
		expect(shots[3].zoom).toBe(Crowd.intro.ringZoom)
		local total = 0
		for _, shot in shots do
			total += shot.seconds
		end
		expect(total <= Pacing.arena.intro).toBe(true)
		-- a repeated push of the same stage plays nothing twice
		controller:onArenaState(state("intro"))
		expect(#camera.shots).toBe(1)
		expect(count(audio.played, "arena.horn")).toBe(1)
	end)

	it("a ruler of neither kingdom sees A, B, then the ring from A; a champion is found by userId", function()
		arenaModel()
		boot()
		controller:onKingdomState({ mine = "gold" })
		controller:onArenaState(state("intro"))
		local shots = camera.shots[1]
		expect(near(shots[1].focus, STAND_A)).toBe(true)
		expect(near(shots[2].focus, STAND_B)).toBe(true)
		expect(looksAt(shots[3], STAND_A)).toBe(true)
		-- the local player is champion b (no Kingdom.State yet): our stand is B, so it comes second
		env = MockEnv.new({ seed = 75, isServer = false, localPlayer = { userId = USER } })
		arenaModel()
		boot()
		controller:onArenaState(state("intro", { b = { userId = USER, kingdom = "azure", isAI = false } }))
		local mine = camera.shots[1]
		expect(near(mine[1].focus, STAND_A)).toBe(true)
		expect(near(mine[2].focus, STAND_B)).toBe(true)
		expect(looksAt(mine[3], STAND_B)).toBe(true)
	end)

	it("the pass shrinks to the intro time left; with none left only the ring is shown", function()
		arenaModel()
		boot()
		local now = env.serverTimeNow()
		controller:onArenaState(state("intro", { endsAt = now + 6 }))
		local total = 0
		for _, shot in camera.shots[1] do
			total += shot.seconds
			expect(shot.seconds >= Crowd.intro.minShotSec).toBe(true)
		end
		expect(math.abs(total - 6) < 1e-6).toBe(true)
		controller:onPhase("Lobby")
		controller:onArenaState(state("intro", { endsAt = now - 1 }))
		local late = camera.shots[2]
		expect(#late).toBe(1)
		expect(near(late[1].focus, CENTRE)).toBe(true)
		-- an absurd endsAt is capped at Pacing.arena.intro
		controller:onPhase("Lobby")
		controller:onArenaState(state("intro", { endsAt = now + 9999 }))
		local long = 0
		for _, shot in camera.shots[3] do
			long += shot.seconds
		end
		expect(long <= Pacing.arena.intro).toBe(true)
	end)

	it("a late joiner gets the ring at the duel; the intro's own pass is not repeated", function()
		arenaModel()
		boot()
		controller:onArenaState(state("duel"))
		expect(#camera.shots).toBe(1)
		expect(#camera.shots[1]).toBe(1)
		expect(near(camera.shots[1][1].focus, CENTRE)).toBe(true)
		expect(music.scenes[#music.scenes]).toBe("arena")
		expect(count(audio.played, "arena.horn")).toBe(0) -- the horn belongs to the intro
		local other = env
		other = MockEnv.new({ seed = 76, isServer = false, localPlayer = { userId = USER } })
		env = other
		arenaModel()
		boot()
		controller:onArenaState(state("intro"))
		controller:onArenaState(state("duel"))
		expect(#camera.shots).toBe(1) -- only the intro's pass
	end)

	it("crowning: a fanfare for a winner, none when the duel is called off; done and Results end the music", function()
		arenaModel()
		boot()
		controller:onArenaState(state("intro"))
		controller:onArenaState(state("duel"))
		controller:onArenaState(state("crowning", { winner = 101 }))
		expect(count(audio.played, "arena.fanfare")).toBe(1)
		expect(music.scenes[#music.scenes]).toBe("arena")
		controller:onArenaState(state("done"))
		expect(music.scenes[#music.scenes]).toBe(false)
		expect(controller.stage).toBe("done")
		controller:onPhase("Results")
		expect(controller.stage).toBeNil()
		expect(camera.stopped).toBe(1)
		-- a called-off duel: no winner, no fanfare
		controller:onArenaState(state("intro"))
		controller:onArenaState(state("crowning"))
		expect(count(audio.played, "arena.fanfare")).toBe(1)
		expect(music.scenes[#music.scenes]).toBe("arena")
		controller:onPhase("Lobby")
		expect(music.scenes[#music.scenes]).toBe(false)
	end)

	it("without the arena model it uses Layout.arena; with neither the pass is skipped, the music still plays", function()
		local saved = (Layout :: any).arena -- nil on main until FORGE-02's FL-0072 (#217) lands
		local ok, err = pcall(function()
			;(Layout :: any).arena = nil
			boot()
			controller:onArenaState(state("intro"))
			expect(#camera.shots).toBe(0)
			expect(music.scenes[#music.scenes]).toBe("arena")
			expect(count(audio.played, "arena.horn")).toBe(1)
			local logged = 0
			for _, entry in env.mock.logs do
				if string.find(entry.message, "intro pass skipped", 1, true) then
					logged += 1
				end
			end
			expect(logged).toBe(1)
			;(Layout :: any).arena = { cframe = CFrame.new(CENTRE) }
			controller:onPhase("Lobby")
			controller:onArenaState(state("intro"))
			local shots = camera.shots[1]
			expect(#shots).toBe(3)
			expect(near(shots[3].focus, CENTRE)).toBe(true)
			expect(near(shots[1].focus, CENTRE + Vector3.new(0, 0, -StageDef.STAND_STUDS))).toBe(true) -- A at -Z
		end)
		;(Layout :: any).arena = saved
		assert(ok, err)
	end)

	it("Studio preview plays the intro as a or b or neutral, never outside Studio, never over a real stage", function()
		arenaModel()
		boot({ studio = false })
		expect(controller:preview("a")).toBe(false)
		expect(#camera.shots).toBe(0)
		boot({ studio = true })
		expect(controller:preview("b")).toBe(true)
		expect(#camera.shots).toBe(1)
		expect(near(camera.shots[1][2].focus, STAND_B)).toBe(true) -- b's own stand second
		expect(music.scenes[#music.scenes]).toBe("arena")
		expect(count(audio.played, "arena.horn")).toBe(1)
		expect(controller:preview("")).toBe(true) -- stops
		expect(music.scenes[#music.scenes]).toBe(false)
		expect(camera.stopped).toBe(1)
		expect(controller:preview("neutral")).toBe(true)
		expect(near(camera.shots[2][1].focus, STAND_A)).toBe(true)
		controller:onArenaState(state("intro")) -- the real arena takes over
		expect(#camera.shots).toBe(3)
		expect(controller:preview("a")).toBe(false)
		expect(#camera.shots).toBe(3)
	end)

	it("pure helpers: yawToward faces the target; pass keeps every shot at least minShotSec", function()
		local yaw = StageDef.yawToward(Vector3.zero, Vector3.new(0, 0, -10))
		expect(math.abs(yaw :: number) < 1e-9).toBe(true) -- -Z is yaw 0
		expect(StageDef.yawToward(Vector3.zero, Vector3.new(0, 5, 0))).toBeNil()
		local geometry = { centre = CENTRE, a = STAND_A, b = STAND_B }
		for _, shot in StageDef.pass(geometry, nil, 0.5, Crowd) do
			expect(shot.seconds).toBe(Crowd.intro.minShotSec)
		end
		-- a degenerate arena (A on the centre): no yaw to A, and none for the ring seen from A, only B's shot
		expect(#StageDef.pass({ centre = CENTRE, a = CENTRE, b = STAND_B }, nil, nil, Crowd)).toBe(1)
	end)
end)
