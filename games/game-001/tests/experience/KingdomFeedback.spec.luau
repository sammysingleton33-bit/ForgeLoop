local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local FakeBus = require("../../../../roblox/tests/unit/experience/doubles/FakeBus")
local FakeRemoteService = require("../../../../roblox/tests/unit/experience/doubles/FakeRemoteService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")
local Moments = require("@game/ReplicatedStorage/Game/Feedback/Moments")
local Lines = require("@game/ReplicatedStorage/Game/Feedback/Lines")
local Presets = require("@game/ReplicatedStorage/Game/Feedback/Presets")
local FeedbackRemotes = require("@game/ReplicatedStorage/Game/Feedback/Remotes")
local AnnouncerDef = require("@game/ServerScriptService/Game/Services/AnnouncerService")
local AnnouncerControllerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/AnnouncerController")
local FeedbackDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackController")
local MusicDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/MusicController")
local AudioDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/AudioController")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")

local function presetIds(): { [string]: boolean }
	local ids = {}
	for _, preset in VfxPresets.ALL do
		ids[preset.id] = true
	end
	for _, preset in Presets do
		ids[preset.id] = true
	end
	return ids
end

-- A G9 ctx double: kingdoms -> players.
local function ctxWith(kingdoms: { [string]: { any } }, all: { any })
	return {
		all = function()
			return all
		end,
		members = function(id)
			return kingdoms[id] or {}
		end,
		kingdomName = function(id)
			return ({ crimson = "Emberhold", azure = "Frostmere" })[id]
		end,
		displayName = function(player)
			return player.name
		end,
		byUserId = function(userId)
			for _, player in all do
				if player.userId == userId then
					return player
				end
			end
			return nil
		end,
		kingdomOf = function(player)
			for id, list in kingdoms do
				if table.find(list, player) then
					return id
				end
			end
			return nil
		end,
	}
end

local function only(deliveries, player)
	local out = {}
	for _, delivery in deliveries do
		if delivery.player == player then
			table.insert(out, delivery.moment.kind)
		end
	end
	return out
end

-- the first moment one player gets
local function momentFor(deliveries, player)
	for _, delivery in deliveries do
		if delivery.player == player then
			return delivery.moment
		end
	end
	return nil
end

describe("Feedback/Moments audience and payload (FL-0062, G9 attribution)", function()
	local a1, a2, b1, ctx
	beforeEach(function()
		a1, a2, b1 = { name = "Ann", userId = 1 }, { name = "Ben", userId = 2 }, { name = "Cat", userId = 3 }
		ctx = ctxWith({ crimson = { a1, a2 }, azure = { b1 } }, { a1, a2, b1 })
	end)

	local function building(fields)
		local b =
			{ id = 1, kingdom = "crimson", type = "house", level = 1, cframe = CFrame.new(10, 0, 5), placedBy = 1 }
		for k, v in fields or {} do
			b[k] = v
		end
		return b
	end

	it("KingdomJoined: the joiner's kingdom is founded; the other members learn who joined", function()
		local out = Moments.fromEvent("KingdomJoined", { a2, "crimson" }, ctx)
		expect(only(out, a2)).toEqual({ "kingdomFounded" })
		expect(only(out, a1)).toEqual({ "memberJoined" })
		expect(only(out, b1)).toEqual({})
		expect(out[1].moment.kingdomName).toBe("Emberhold")
	end)

	it("buildings: members only, with the placer's name and the position as a Vector3", function()
		local out = Moments.fromEvent("BuildingPlaced", { building(), a1 }, ctx)
		expect(#out).toBe(1) -- the co-ruler; the placer already has FORGE-03's own notice (#49 M1)
		expect(only(out, a1)).toEqual({})
		expect(only(out, b1)).toEqual({})
		expect(only(out, a2)).toEqual({ "buildingPlaced" })
		expect(out[1].moment.actor).toBe("Ann")
		expect(out[1].moment.position).toBe(Vector3.new(10, 0, 5))
		expect(#Moments.fromEvent("BuildingCompleted", { building() }, ctx)).toBe(2)
	end)

	it("recruits: the co-rulers hear it; the recruiter already has FORGE-03's own toast", function()
		local out = Moments.fromEvent("UnitsRecruited", { a1, "crimson", 3 }, ctx)
		expect(#out).toBe(1)
		expect(only(out, a1)).toEqual({})
		expect(only(out, b1)).toEqual({})
		expect(only(out, a2)).toEqual({ "unitsRecruited" })
		expect(out[1].moment.actor).toBe("Ann")
		expect(out[1].moment.count).toBe(3)
		-- a recruiter who already left (no Player): every member hears it
		expect(#Moments.fromEvent("UnitsRecruited", { nil, "crimson", 3 }, ctx)).toBe(2)
	end)

	it("a keep upgrade is celebrated at home and reported to rivals without its location", function()
		local out = Moments.fromEvent("BuildingUpgraded", { building({ type = "keep", level = 2 }) }, ctx)
		expect(only(out, a1)).toEqual({ "keepUpgraded" })
		expect(only(out, b1)).toEqual({ "rivalKeepUpgraded" })
		for _, delivery in out do
			if delivery.player == b1 then
				expect(delivery.moment.position).toBeNil()
				expect(delivery.moment.kingdomName).toBe("Emberhold")
			end
		end
		local farm = Moments.fromEvent("BuildingUpgraded", { building({ type = "farm", level = 2 }) }, ctx)
		expect(only(farm, b1)).toEqual({})
	end)

	it("captures: members celebrate, everyone else is warned", function()
		local out = Moments.fromEvent("ObjectiveCaptured", { "tower_1", "azure" }, ctx)
		expect(only(out, b1)).toEqual({ "objectiveCaptured" })
		expect(only(out, a1)).toEqual({ "rivalCaptured" })
		expect(only(out, a2)).toEqual({ "rivalCaptured" })
	end)

	it("phases go to everyone; MatchEnded tells each player whether their kingdom won", function()
		expect(#Moments.fromEvent("MatchPhaseChanged", { "Conflict" }, ctx)).toBe(3)
		local ended = Moments.fromEvent("MatchEnded", { { winner = "azure", standings = {}, durationSec = 600 } }, ctx)
		for _, delivery in ended do
			expect(delivery.moment.won).toBe(delivery.player == b1)
		end
	end)

	it("MatchEnded outcome: won / lost per ruler, watched for a spectator, draw without a winner (#49 L4)", function()
		local spectator = { name = "Dee", userId = 4 }
		local all = ctxWith({ crimson = { a1, a2 }, azure = { b1 } }, { a1, b1, spectator })
		local function outcomes(result)
			local out = {}
			for _, delivery in Moments.fromEvent("MatchEnded", { result }, all) do
				out[delivery.player.name] = delivery.moment.outcome
			end
			return out
		end
		expect(outcomes({ winner = "crimson", standings = {}, durationSec = 60 })).toEqual({
			Ann = "won",
			Cat = "lost",
			Dee = "watched",
		})
		expect(outcomes({ standings = {}, durationSec = 60 })).toEqual({ Ann = "draw", Cat = "draw", Dee = "draw" })
		expect(Moments.present({ kind = "matchEnded", outcome = "won" }).celebrate).toBe("victory")
		expect(Moments.present({ kind = "matchEnded", outcome = "lost" }).celebrate).toBe("defeat")
		local draw = Moments.present({ kind = "matchEnded", outcome = "draw" })
		expect(draw.celebrate).toBeNil()
		expect(draw.toast.title).toBe("A draw")
		local watched = Moments.present({ kind = "matchEnded", outcome = "watched", kingdomName = "Emberhold" })
		expect(watched.celebrate).toBeNil()
		expect(watched.toast.title).toBe("Emberhold wins the match")
	end)

	it(
		"ConsequenceChanged: the kingdom's rulers get one notice per start and per end (FL-0091, G9 v0.4-g10c)",
		function()
			ctx.buildingKind = function(id)
				return if id == 7 then "storehouse" else nil
			end
			local riot = Moments.fromEvent(
				"ConsequenceChanged",
				{ "crimson", "riot", true, { buildingId = 7, count = 4, instigator = 11, entityIds = { 11, 12 } } },
				ctx
			)
			expect(#riot).toBe(2) -- Ann and Ben rule crimson; Cat (azure) hears nothing
			expect(#only(riot, b1)).toBe(0)
			local moment = momentFor(riot, a1)
			expect(moment).toEqual({
				kind = "consequence",
				kingdom = "crimson",
				rule = "riot",
				on = true,
				count = 4,
				buildingType = "storehouse",
			}) -- no instigator or entity ids on the wire
			local shown = Moments.present(moment)
			expect(shown.toast.title).toBe("Riot at the storehouse!")
			expect(shown.toast.body).toBe("4 rioters set it alight. Nobody works there while it burns.")
			expect(shown.toast.kind).toBe("warning")
			expect(shown.sound).toBe("kingdom.horn.war")
			-- no building known: the plain title, never "Riot at the !"
			local plain =
				momentFor(Moments.fromEvent("ConsequenceChanged", { "crimson", "riot", true, { count = 2 } }, ctx), a1)
			expect(Moments.present(plain).toast.title).toBe("A riot breaks out!")
			local over = momentFor(
				Moments.fromEvent("ConsequenceChanged", { "crimson", "riot", false, { buildingId = 7 } }, ctx),
				a1
			)
			expect(Moments.present(over).toast.title).toBe("The riot is over")
			expect(Moments.present(over).toast.body).toBe("The storehouse slowly mends.")
			expect(Moments.present(over).toast.key).toBe(shown.toast.key) -- the end replaces the start
		end
	)

	it(
		"ConsequenceChanged: strikes name the job, shortages the food; a rebellion has no end; bad payloads drop",
		function()
			local function title(args)
				local delivered = momentFor(Moments.fromEvent("ConsequenceChanged", args, ctx), a1)
				return if delivered then Moments.present(delivered).toast else nil
			end
			local strike = title({ "crimson", "strike", true, { occupation = "farmer", count = 3 } })
			expect(strike.title).toBe("The farmers are on strike")
			expect(strike.body).toBe("3 stopped work over a grievance. Win back their loyalty.")
			expect(title({ "crimson", "strike", false, { occupation = "farmer", count = 3 } }).title).toBe(
				"The farmers are back at work"
			)
			expect(title({ "crimson", "strike", true, { count = 2 } }).title).toBe("The workers are on strike")
			expect(title({ "crimson", "strike", true, { occupation = "riot", count = 2 } }).title).toBe(
				"The workers are on strike"
			) -- "riot" marks rioters, never a job
			local rioters = momentFor(
				Moments.fromEvent(
					"ConsequenceChanged",
					{ "crimson", "riot", true, { occupation = "riot", count = 2 } },
					ctx
				),
				a1
			)
			expect(rioters.occupation).toBeNil()
			expect(title({ "crimson", "strike", true, { occupation = "farmer", count = 0 / 0 } }).body).toBeNil()
			expect(title({ "crimson", "shortage", true, { count = 9 } }).title).toBe("Food is running out")
			expect(title({ "crimson", "shortage", false, { count = 9 } }).title).toBe("Your people have food again")
			expect(title({ "crimson", "rebellion", true, { instigator = 11, count = 5 } }).title).toBe(
				"Your people rise in rebellion!"
			)
			expect(Moments.fromEvent("ConsequenceChanged", { "crimson", "rebellion", false, {} }, ctx)).toEqual({})
			expect(Moments.fromEvent("ConsequenceChanged", { "crimson", "plague", true, {} }, ctx)).toEqual({})
			expect(Moments.fromEvent("ConsequenceChanged", { "crimson", "riot", "yes", {} }, ctx)).toEqual({})
			expect(Moments.fromEvent("ConsequenceChanged", { nil, "riot", true, {} }, ctx)).toEqual({})
			expect(#Moments.fromEvent("ConsequenceChanged", { "crimson", "shortage", true }, ctx)).toBe(2) -- no info
			for rule, phases in Lines.CONSEQUENCE do
				for phase, line in phases do
					assert(
						utf8.len(line.title) <= 60 and (line.plain == nil or utf8.len(line.plain) <= 60),
						`{rule}.{phase}`
					)
				end
			end
		end
	)

	it("gathering is never announced, and bad payloads produce nothing", function()
		expect(Moments.fromEvent("ResourceGathered", { a1, "crimson", "wood", 3, "ruler" }, ctx)).toEqual({})
		expect(Moments.fromEvent("BuildingPlaced", { "not a building" }, ctx)).toEqual({})
		expect(Moments.fromEvent("ObjectiveCaptured", { "tower_1", nil }, ctx)).toEqual({})
	end)

	it("moments carry only primitives and Vector3 (nothing else crosses the wire, G8)", function()
		local events = {
			{ "KingdomJoined", { a1, "crimson" } },
			{ "BuildingPlaced", { building(), a1 } },
			{ "BuildingUpgraded", { building({ type = "keep", level = 2 }) } },
			{ "UnitsRecruited", { a1, "crimson", 3 } },
			{ "ObjectiveCaptured", { "tower_1", "crimson" } },
			{ "MatchEnded", { { winner = "crimson", standings = {}, durationSec = 1 } } },
			{ "ConsequenceChanged", { "crimson", "riot", true, { buildingId = 1, count = 2, entityIds = { 4 } } } },
		}
		for _, event in events do
			for _, delivery in Moments.fromEvent(event[1], event[2], ctx) do
				for key, value in delivery.moment do
					local kind = typeof(value)
					assert(
						kind == "string" or kind == "number" or kind == "boolean" or kind == "Vector3",
						`{event[1]}.{key} is a {kind}`
					)
				end
			end
		end
	end)
end)

describe("Feedback/Lines presentation (FL-0062)", function()
	it("every moment kind presents a toast or a celebration with a short title", function()
		local samples = AnnouncerDef.SAMPLES
		for _, kind in Moments.KINDS do
			local moment = {
				kind = kind,
				phase = "Conflict",
				buildingType = "house",
				level = 2,
				count = 3,
				actor = "Ann",
				kingdomName = "Frostmere",
				won = true,
				rule = "strike",
				on = true,
				occupation = "miner",
			}
			local presentation = Moments.present(moment)
			assert(presentation.toast or presentation.celebrate, `{kind} presents nothing`)
			if presentation.toast then
				expect(utf8.len(presentation.toast.title) <= 60).toBe(true)
			end
		end
		expect(Moments.present({ kind = "phase", phase = "Lobby" }).toast).toBeNil() -- no lobby line
		expect(samples.victory ~= nil).toBe(true)
	end)

	it("every sound and effect named in Lines exists, and no celebration is sound-only", function()
		local ids = presetIds()
		local function check(where, spec)
			if spec.sound then
				assert(Sounds.registry:get(spec.sound), `{where}: unknown sound {spec.sound}`)
			end
			if spec.vfx then
				assert(ids[spec.vfx], `{where}: unknown effect {spec.vfx}`)
			end
		end
		for kind, line in Lines.MOMENT do
			check(kind, line)
			if line.sound then
				assert(line.vfx or line.title, `{kind}: a sound needs a visual`)
			end
		end
		for kind, line in Lines.PHASE do
			check(kind, line)
		end
		for kind, spec in Lines.CELEBRATIONS do
			check(kind, spec)
			assert(spec.toast or spec.vfx, `celebration {kind} has no visual`)
		end
		for rule, phases in Lines.CONSEQUENCE do
			for phase, line in phases do
				check(`{rule}.{phase}`, line)
			end
		end
	end)

	it("the kingdom presets fit the mobile budget", function()
		expect(VfxPresets.validate(Presets)).toEqual({})
	end)
end)

describe("AnnouncerService (FL-0062)", function()
	local env, bus, remotes, registry, p1, p2, p3

	local function boot(withKingdoms, analytics)
		local defs = {
			{
				name = "RemoteService",
				new = function()
					return remotes
				end,
			},
			{
				name = "AnnouncerService",
				dependencies = { "RemoteService" },
				new = function(e, r)
					return AnnouncerDef.create(e, r, { bus = bus })
				end,
			},
		}
		if analytics then
			table.insert(defs, {
				name = "AnalyticsService",
				new = function()
					return analytics
				end,
			})
		end
		if withKingdoms then
			table.insert(defs, {
				name = "KingdomService",
				new = function()
					return {
						getKingdom = function(_, id)
							local rulers = ({ crimson = { 3101, 3102 }, azure = { 3103 } })[id]
							return {
								id = id,
								name = ({ crimson = "Emberhold", azure = "Frostmere" })[id],
								rulers = rulers or {},
							}
						end,
						getKingdomOf = function(_, player)
							return if player.UserId == 3103 then "azure" else "crimson"
						end,
					}
				end,
			})
		end
		registry = Loader.load(env, defs)
	end

	local function kindsFor(player)
		local out = {}
		for _, sent in remotes:sentTo("Feedback.Moment", player) do
			table.insert(out, sent.args[1].kind)
		end
		return out
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 62 })
		bus = FakeBus.new()
		remotes = FakeRemoteService.new({ declarations = FeedbackRemotes })
		p1 = env.mock.players:add({ userId = 3101, name = "Ann" })
		p2 = env.mock.players:add({ userId = 3102, name = "Ben" })
		p3 = env.mock.players:add({ userId = 3103, name = "Cat" })
	end)

	it("sends kingdom-scoped moments through Feedback.Moment", function()
		boot(true)
		bus.BuildingPlaced:fire(
			{ id = 1, kingdom = "crimson", type = "farm", level = 1, cframe = CFrame.new(), placedBy = 3101 },
			p1
		)
		bus.ObjectiveCaptured:fire("tower_1", "azure")
		expect(kindsFor(p1)).toEqual({ "rivalCaptured" }) -- Ann placed it: no second toast for her
		expect(kindsFor(p3)).toEqual({ "objectiveCaptured" })
		local placed = remotes:sentTo("Feedback.Moment", p2)[1].args[1]
		expect(placed.actor).toBe("Ann")
		expect(registry:get("AnnouncerService").sent.buildingPlaced).toBe(1)
	end)

	it("ConsequenceChanged reaches that kingdom's rulers, naming the burning building from its model", function()
		boot(true)
		local root = roblox.Instance.new("Folder")
		root.Name = "ForgeKingdoms"
		local crimson = roblox.Instance.new("Folder")
		crimson.Name = "crimson"
		crimson.Parent = root
		local buildings = roblox.Instance.new("Folder")
		buildings.Name = "Buildings"
		buildings.Parent = crimson
		local store = roblox.Instance.new("Model")
		store:SetAttribute("BuildingId", 21)
		store:SetAttribute("Kind", "storehouse")
		store.Parent = buildings
		root.Parent = env.Workspace
		bus.ConsequenceChanged:fire("crimson", "riot", true, { buildingId = 21, instigator = 5, count = 3 })
		expect(kindsFor(p1)).toEqual({ "consequence" })
		expect(kindsFor(p2)).toEqual({ "consequence" })
		expect(kindsFor(p3)).toEqual({}) -- azure's ruler
		local sent = remotes:sentTo("Feedback.Moment", p1)[1].args[1]
		expect(sent.buildingType).toBe("storehouse")
		expect(Moments.present(sent).toast.title).toBe("Riot at the storehouse!")
	end)

	it("without KingdomService: phases still reach everyone, kingdom moments reach nobody", function()
		boot(false)
		bus.MatchPhaseChanged:fire("Conflict")
		bus.BuildingCompleted:fire({ id = 1, kingdom = "crimson", type = "farm", level = 1, cframe = CFrame.new() })
		expect(kindsFor(p1)).toEqual({ "phase" })
		expect(kindsFor(p3)).toEqual({ "phase" })
		expect(env.mock:hasLog("info", "no KingdomService yet")).toBe(true)
	end)

	it("logs CelebrationShown on the server for each player a celebrating moment reached (M3)", function()
		local logged = {}
		boot(true, {
			event = function(_, player, name, fields)
				table.insert(logged, `{player.UserId}:{name}:{fields.kind}`)
				return true
			end,
		})
		bus.ObjectiveCaptured:fire("tower_1", "azure") -- azure celebrates, crimson gets a rival notice
		bus.BuildingPlaced:fire(
			{ id = 1, kingdom = "crimson", type = "farm", level = 1, cframe = CFrame.new(), placedBy = 3101 },
			p1
		) -- a toast, not a celebration
		expect(logged).toEqual({ "3103:CelebrationShown:objectiveCaptured" })
		DebugCommands.run(p1, "fx.announce", "keepUpgraded") -- a Studio sample: nothing logged
		expect(#logged).toBe(1)
	end)

	it("an analytics error never stops an announcement", function()
		boot(true, {
			event = function()
				error("analytics down")
			end,
		})
		bus.ObjectiveCaptured:fire("tower_1", "azure")
		expect(kindsFor(p3)).toEqual({ "objectiveCaptured" })
		expect(env.mock.threadErrors).toEqual({})
	end)

	it("registers fx.announce and fx.burst once (Studio debug panel)", function()
		boot(true)
		boot(true) -- a second boot must not fail on duplicate commands
		local names = {}
		for _, command in DebugCommands.list() do
			names[command.name] = true
		end
		expect(names["fx.announce"]).toBe(true)
		expect(names["fx.burst"]).toBe(true)
		local ok = DebugCommands.run(p1, "fx.announce", "keepUpgraded")
		expect(ok).toBe(true)
		expect(DebugCommands.run(p1, "fx.announce", "dragons")).toBe(false)
		expect(kindsFor(p1)).toEqual({ "keepUpgraded" })
	end)
end)

describe("client feedback controllers (FL-0062)", function()
	local env, notices, celebrations, registered, played, effects, stopped, floats, music, ambience, silenced
	local vfxOff = false -- the VFX budget skips every effect while true

	local function doubles(opts)
		opts = opts or {}
		local defs = {
			{
				name = "AudioController",
				new = function()
					return {
						play = function(_, id, o)
							local voice = { id = id, position = o and o.position }
							table.insert(played, voice)
							return voice
						end,
						stop = function(_, voice)
							table.insert(silenced, voice)
						end,
						setMusic = function(_, state)
							table.insert(music, state)
						end,
						setAmbience = function(_, list)
							table.insert(ambience, list)
						end,
					}
				end,
			},
			{
				name = "VFXController",
				new = function()
					return {
						play = function(_, id, o)
							if vfxOff then
								return nil
							end
							local effect = { id = id, position = o and o.position, tint = o and o.tint }
							table.insert(effects, effect)
							return effect
						end,
						stop = function(_, effect)
							table.insert(stopped, effect)
						end,
						float = function(_, text, position, floatOpts)
							table.insert(floats, { text = text, position = position, opts = floatOpts })
						end,
						register = function(_, list)
							for _, preset in list do
								table.insert(registered, preset.id)
							end
							return {}
						end,
					}
				end,
			},
		}
		if opts.notifications ~= false then
			table.insert(defs, {
				name = "NotificationController",
				new = function()
					return {
						show = function(_, spec)
							table.insert(notices, spec)
							return spec, "shown"
						end,
						celebrate = function(_, kind, payload)
							table.insert(celebrations, { kind = kind, payload = payload })
							return opts.celebrateResult ~= false
						end,
						registerCelebration = if opts.noCelebrations
							then nil
							else function(_, kind)
								return if opts.rejected and opts.rejected[kind] then { "rejected" } else {}
							end,
					}
				end,
			})
		end
		return defs
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 63, isServer = false, localPlayer = { userId = 3201 } })
		notices, celebrations, registered, played, effects, stopped, floats, music, ambience, silenced =
			{}, {}, {}, {}, {}, {}, {}, {}, {}, {}
		vfxOff = false
	end)

	it(
		"FeedbackController: a burning building gets fire, smoke and a crackle until the fire is out (FL-0091)",
		function()
			local defs = doubles({ notifications = false })
			table.insert(defs, FeedbackDef)
			local feedback = Loader.load(env, defs):get("FeedbackController")
			local root = roblox.Instance.new("Folder")
			root.Name = "ForgeKingdoms"
			local crimson = roblox.Instance.new("Folder")
			crimson.Name = "crimson"
			crimson.Parent = root
			local buildings = roblox.Instance.new("Folder")
			buildings.Name = "Buildings"
			buildings.Parent = crimson
			local function building(id, x)
				local model = roblox.Instance.new("Model")
				model:SetAttribute("BuildingId", id)
				local base = roblox.Instance.new("Part")
				base.CFrame = CFrame.new(x, 0, 0)
				base.Parent = model
				model.PrimaryPart = base
				model.Parent = buildings
				return model
			end
			local storehouse, house = building(12, 40), building(13, 80)
			root.Parent = env.Workspace
			feedback:refreshFires()
			expect(#effects).toBe(0) -- nothing burns
			storehouse:SetAttribute("Burning", true)
			env.mock:advance(FeedbackDef.BURN_POLL_SEC + 0.05) -- the poll started by start()
			expect(#effects).toBe(1)
			expect(effects[1].id).toBe(FeedbackDef.FIRE.vfx)
			expect(effects[1].position ~= nil and effects[1].position.X).toBe(40)
			expect(played[#played].id).toBe(FeedbackDef.FIRE.sound)
			feedback:refreshFires()
			expect(#effects).toBe(1) -- one fire per building, not one per read
			-- a skipped effect is tried again; the crackle is not doubled
			vfxOff = true
			house:SetAttribute("Burning", true)
			feedback:refreshFires()
			expect(feedback:fires()[13].effect).toBeNil()
			vfxOff = false
			local sounds = #played
			feedback:refreshFires()
			expect(feedback:fires()[13].effect).never.toBeNil()
			expect(#played).toBe(sounds)
			-- out: the attribute goes, or the model does
			storehouse:SetAttribute("Burning", nil)
			feedback:refreshFires()
			expect(stopped[1]).toBe(effects[1])
			expect(silenced[1].id).toBe(FeedbackDef.FIRE.sound)
			expect(feedback:fires()[12]).toBeNil()
			house:Destroy()
			feedback:refreshFires()
			expect(feedback:fires()[13]).toBeNil()
			expect(#stopped).toBe(2)
			expect(env.mock.threadErrors).toEqual({})
		end
	)

	it("FeedbackController: the fire preset fits the budget and the crackle is a looping sound", function()
		local preset
		for _, p in Presets do
			if p.id == FeedbackDef.FIRE.vfx then
				preset = p
			end
		end
		assert(preset, "fire preset")
		expect(VfxPresets.validate({ preset })).toEqual({})
		expect(preset.durationSec).toBeNil() -- continuous until stopped
		local sound = Sounds.registry:get(FeedbackDef.FIRE.sound)
		assert(sound, "fire sound")
		expect(sound.loop).toBe(true)
	end)

	it("AnnouncerController: celebrations celebrate; other moments toast, silently when they have a sound", function()
		local defs = doubles()
		table.insert(defs, AnnouncerControllerDef)
		local registry = Loader.load(env, defs)
		local announcer = registry:get("AnnouncerController")
		announcer:onMoment({ kind = "keepUpgraded", level = 2, position = Vector3.new(1, 2, 3) })
		expect(celebrations[1].kind).toBe("keepUpgraded")
		expect(#notices).toBe(0)
		announcer:onMoment({ kind = "buildingPlaced", buildingType = "house", position = Vector3.new(5, 0, 5) })
		expect(notices[1].title).toBe("House placed")
		expect(notices[1].key).toBe("placed:house")
		expect(notices[1].silent).toBe(true)
		expect(played[1].id).toBe("kingdom.build.place")
		expect(effects[1].id).toBe("kingdom.construction.place")
		expect(effects[1].position).toBe(Vector3.new(5, 0, 5))
		announcer:onMoment({ kind = "memberJoined", actor = "Ben" })
		expect(notices[2].silent).toBe(false)
		announcer:onMoment({ kind = "dragons" })
		expect(#notices).toBe(2)
	end)

	it(
		"AnnouncerController: a celebration declined inside its cooldown shows no second toast; a rejected kind falls back (#49 L3)",
		function()
			local defs = doubles({ celebrateResult = false, rejected = { objectiveCaptured = true } })
			table.insert(defs, AnnouncerControllerDef)
			local announcer = Loader.load(env, defs):get("AnnouncerController")
			announcer:onMoment({ kind = "keepUpgraded", level = 2 })
			expect(#celebrations).toBe(1)
			expect(#notices).toBe(0) -- declined = the same moment twice: nothing more to show
			announcer:onMoment({ kind = "objectiveCaptured", kingdom = "crimson", objectiveId = "tower_1" })
			expect(#celebrations).toBe(1) -- not registered, so not celebrated
			expect(notices[1].title).toBe("Watchtower captured") -- the fallback toast
		end
	)

	it("AnnouncerController: effects and celebrations get the kingdom colour (#49 L8)", function()
		local defs = doubles()
		table.insert(defs, AnnouncerControllerDef)
		local announcer = Loader.load(env, defs):get("AnnouncerController")
		local crimson = Color3.fromRGB(190, 40, 50)
		announcer:onMoment({
			kind = "buildingCompleted",
			kingdom = "crimson",
			buildingType = "farm",
			position = Vector3.zero,
		})
		expect(effects[1].id).toBe("kingdom.construction.complete")
		expect(effects[1].tint).toBe(crimson)
		local moment = { kind = "objectiveCaptured", kingdom = "crimson", objectiveId = "tower_1" }
		announcer:onMoment(moment)
		expect(celebrations[1].payload.tint).toBe(crimson)
		expect(moment.tint).toBeNil() -- the received moment is not changed
		announcer:onMoment({ kind = "buildingCompleted", buildingType = "farm", position = Vector3.zero })
		expect(effects[2].tint).toBeNil() -- no kingdom, no colour
	end)

	it("AnnouncerController without the celebration API still shows the moment's toast", function()
		local defs = doubles({ noCelebrations = true })
		table.insert(defs, AnnouncerControllerDef)
		local announcer = Loader.load(env, defs):get("AnnouncerController")
		announcer:onMoment({ kind = "kingdomFounded", kingdomName = "Emberhold" })
		expect(#celebrations).toBe(0)
		expect(notices[1].title).toBe("Emberhold is yours")
	end)

	it(
		"AnnouncerController with the slice summary: no result toast, celebrations and music stay (FORGE-00 ruling)",
		function()
			local summary = {
				name = "SliceSummaryController",
				new = function()
					return {}
				end,
			}
			local defs = doubles()
			table.insert(defs, summary)
			table.insert(defs, AnnouncerControllerDef)
			local announcer = Loader.load(env, defs):get("AnnouncerController")
			local heard = {}
			announcer.moment:connect(function(moment)
				table.insert(heard, moment.outcome)
			end)
			announcer:onMoment({ kind = "matchEnded", outcome = "draw" })
			announcer:onMoment({ kind = "matchEnded", outcome = "watched", winner = "azure", kingdomName = "Frostmere" })
			expect(#notices).toBe(0) -- the summary shows the result line
			expect(heard).toEqual({ "draw", "watched" }) -- MusicController still hears both
			announcer:onMoment({ kind = "matchEnded", outcome = "won", won = true, kingdomName = "Emberhold" })
			expect(celebrations[1].kind).toBe("victory")
			announcer:onMoment({ kind = "buildingCompleted", buildingType = "farm", position = Vector3.zero })
			expect(notices[1].title).toBe("Farm complete") -- other moments still toast

			-- a celebration that falls back to its toast is still the celebration: it stays
			notices, celebrations = {}, {}
			local fallback = doubles({ noCelebrations = true })
			table.insert(fallback, summary)
			table.insert(fallback, AnnouncerControllerDef)
			local plain =
				Loader.load(MockEnv.new({ seed = 64, isServer = false, localPlayer = { userId = 3202 } }), fallback)
					:get("AnnouncerController")
			plain:onMoment({ kind = "matchEnded", outcome = "lost", kingdomName = "Frostmere" })
			expect(notices[1].title).toBe("Defeat")
		end
	)

	it("AnnouncerController without the slice summary keeps the result toast", function()
		local defs = doubles()
		table.insert(defs, AnnouncerControllerDef)
		local announcer = Loader.load(env, defs):get("AnnouncerController")
		announcer:onMoment({ kind = "matchEnded", outcome = "draw" })
		announcer:onMoment({ kind = "matchEnded", outcome = "watched", winner = "azure", kingdomName = "Frostmere" })
		expect(notices[1].title).toBe("A draw")
		expect(notices[2].title).toBe("Frostmere wins the match")
	end)

	it("FeedbackController: a gather sounds, bursts chips at the node and floats +N", function()
		local defs = doubles({ notifications = false })
		local node = { id = "oak_1", cframe = CFrame.new(40, 0, 0) }
		table.insert(defs, {
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, { layout = { resourceNodes = { node } } })
			end,
		})
		local feedback = Loader.load(env, defs):get("FeedbackController")
		feedback:gathered("oak_1", "wood", 3)
		expect(played[1].id).toBe("kingdom.chop")
		expect(effects[1].id).toBe("kingdom.harvest.wood")
		expect(effects[1].position).toBe(Vector3.new(40, 0, 0))
		expect(floats[1].text).toBe("+3 Wood")
		expect(floats[1].opts).toEqual({ maxDistance = 0 }) -- culled here from the focus, not by the engine
		feedback:gathered("oak_1", "silk", 3)
		expect(#played).toBe(1)
	end)

	it("FeedbackController: floats only within MAX_STUDS of the view; walk mode measures from the camera", function()
		local defs = doubles({ notifications = false })
		local camera = { mode = "follow" }
		function camera.getFocus()
			return Vector3.new(500, 0, 0) -- left over from the overview
		end
		table.insert(defs, {
			name = "RulerCameraController",
			new = function()
				return camera
			end,
		})
		local nodes = { { id = "oak_1", cframe = CFrame.new(10, 0, 0) } }
		table.insert(defs, {
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, { layout = { resourceNodes = nodes } })
			end,
		})
		local feedback = Loader.load(env, defs):get("FeedbackController")
		local view = roblox.Instance.new("Camera")
		view.CFrame = CFrame.new(0, 12, 18)
		view.Parent = env.Workspace
		env.Workspace.CurrentCamera = view
		feedback:gathered("oak_1", "wood", 2) -- next to the walking ruler
		expect(#floats).toBe(1)
		camera.mode = "overview"
		feedback:gathered("oak_1", "wood", 2) -- 490 studs from the overview's focus
		expect(#floats).toBe(1)
	end)

	it("FeedbackController: deposits coalesce, swings are rate-limited and culled by distance", function()
		local defs = doubles({ notifications = false })
		local origin = Vector3.zero
		table.insert(defs, {
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, {
					layout = { resourceNodes = {} },
					origin = function()
						return origin
					end,
				})
			end,
		})
		local feedback = Loader.load(env, defs):get("FeedbackController")
		local near = roblox.Instance.new("Model")
		local part = roblox.Instance.new("Part")
		part.CFrame = CFrame.new(20, 0, 0)
		part.Parent = near
		near.PrimaryPart = part
		feedback:onEntityEvent(1, "deposit", {}, near)
		feedback:onEntityEvent(2, "deposit", {}, near)
		expect(#played).toBe(1) -- coalesced
		env.mock:advance(FeedbackDef.DEPOSIT_GAP_SEC)
		feedback:onEntityEvent(2, "deposit", {}, near)
		expect(#played).toBe(2)
		feedback:onEntityEvent(5, "swing", { job = "woodcutter" }, near)
		feedback:onEntityEvent(5, "swing", { job = "woodcutter" }, near)
		expect(#played).toBe(3)
		origin = Vector3.new(10000, 0, 0)
		env.mock:advance(FeedbackDef.SWING_GAP_SEC)
		feedback:onEntityEvent(5, "swing", { job = "woodcutter" }, near)
		expect(#played).toBe(3) -- beyond MAX_STUDS from the camera
	end)

	it(
		"FeedbackController: distance is from the camera focus, so a zoomed-out overview still hears work (#49 L1)",
		function()
			local defs = doubles({ notifications = false })
			table.insert(defs, {
				name = "RulerCameraController",
				new = function()
					return {
						mode = "overview",
						getFocus = function()
							return Vector3.new(500, 0, 0)
						end,
					}
				end,
			})
			table.insert(defs, {
				name = "FeedbackController",
				new = function(e, r)
					return FeedbackDef.create(e, r, { layout = { resourceNodes = {} } })
				end,
			})
			local feedback = Loader.load(env, defs):get("FeedbackController")
			local function rig(x)
				local model = roblox.Instance.new("Model")
				local part = roblox.Instance.new("Part")
				part.CFrame = CFrame.new(x, 0, 0)
				part.Parent = model
				model.PrimaryPart = part
				return model
			end
			feedback:onEntityEvent(1, "swing", { job = "miner" }, rig(520)) -- under the view
			feedback:onEntityEvent(2, "swing", { job = "miner" }, rig(0)) -- 500 studs from the focus
			expect(#played).toBe(1)
			expect(played[1].position).toBe(Vector3.new(520, 0, 0))
		end
	)

	it("FeedbackController: a citizen's attached effects list never grows with the match (#49 L2)", function()
		local defs = doubles({ notifications = false })
		table.insert(defs, {
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, {
					layout = { resourceNodes = {} },
					origin = function()
						return Vector3.zero
					end,
				})
			end,
		})
		local feedback = Loader.load(env, defs):get("FeedbackController")
		local model = roblox.Instance.new("Model")
		local part = roblox.Instance.new("Part")
		part.CFrame = CFrame.new(10, 0, 0)
		part.Parent = model
		model.PrimaryPart = part
		for _ = 1, 50 do
			feedback:onEntityEvent(1, "celebrate", {}, model)
			env.mock:advance(FeedbackDef.ATTACH_KEEP_SEC / 2)
		end
		expect(#feedback._attached[1]).toBeLessThanOrEqual(2)
		feedback:released(1)
		expect(feedback._attached[1]).toBeNil()
	end)

	it(
		"FeedbackController: cheers are culled by distance and share one sound per gap; NaN ids are ignored (#49 lows)",
		function()
			local defs = doubles({ notifications = false })
			table.insert(defs, {
				name = "FeedbackController",
				new = function(e, r)
					return FeedbackDef.create(e, r, {
						layout = { resourceNodes = {} },
						origin = function()
							return Vector3.zero
						end,
					})
				end,
			})
			local feedback = Loader.load(env, defs):get("FeedbackController")
			local function rig(x)
				local model = roblox.Instance.new("Model")
				local part = roblox.Instance.new("Part")
				part.CFrame = CFrame.new(x, 0, 0)
				part.Parent = model
				model.PrimaryPart = part
				return model
			end
			for id = 1, 10 do
				feedback:onEntityEvent(id, "celebrate", {}, rig(id * 5)) -- the whole kingdom cheers at once
			end
			feedback:onEntityEvent(99, "celebrate", {}, rig(2000)) -- far away
			local cheers = 0
			for _, sound in played do
				cheers += if sound.id == "kingdom.cheer" then 1 else 0
			end
			expect(cheers).toBe(1)
			expect(#effects).toBe(10) -- every nearby citizen still bursts; the far one does nothing
			env.mock:advance(FeedbackDef.CHEER_GAP_SEC + 0.01)
			feedback:onEntityEvent(1, "celebrate", {}, rig(5))
			expect(#played).toBe(2)
			feedback:onEntityEvent(0 / 0, "swing", { job = "miner" }, rig(5))
			feedback:released(0 / 0)
			expect(env.mock.threadErrors).toEqual({})
		end
	)

	it("MusicController: a Match.GetState reply that arrives after destroy plays nothing (#49 low)", function()
		local defs = doubles({ notifications = false })
		table.insert(defs, MusicDef)
		local controller = Loader.load(env, defs):get("MusicController")
		controller:destroy()
		local root = env.newInstance("Folder")
		root.Name = "ForgeRemotes"
		root.Parent = env.ReplicatedStorage
		local area = env.newInstance("Folder")
		area.Name = "Match"
		area.Parent = root
		local getState = env.newInstance("RemoteFunction")
		getState.Name = "GetState"
		getState.Parent = area
		getState.OnServerInvoke = function()
			return "Conflict", nil, 0
		end
		env.mock:advance(1)
		expect(controller.phase).toBeNil()
		expect(music).toEqual({})
	end)

	it("FeedbackController: a released rig loses every effect attached to it (pooled rigs)", function()
		local defs = doubles({ notifications = false })
		local entities = { event = Signal.new(), released = Signal.new() }
		table.insert(defs, {
			name = "EntityController",
			new = function()
				return entities
			end,
		})
		table.insert(defs, {
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, {
					layout = { resourceNodes = {} },
					origin = function()
						return Vector3.zero
					end,
				})
			end,
		})
		Loader.load(env, defs)
		local rig = roblox.Instance.new("Model")
		local part = roblox.Instance.new("Part")
		part.CFrame = CFrame.new(5, 0, 0)
		part.Parent = rig
		rig.PrimaryPart = part
		entities.event:fire(9, "celebrate", {}, rig)
		entities.event:fire(9, "swing", { job = "miner" }, rig)
		expect(#effects).toBe(2)
		entities.released:fire(9, rig)
		expect(#stopped).toBe(2)
		entities.released:fire(9, rig)
		expect(#stopped).toBe(2) -- nothing left to stop
	end)

	it("FeedbackController registers the kingdom presets once", function()
		local defs = doubles({ notifications = false })
		table.insert(defs, FeedbackDef)
		Loader.load(env, defs)
		local first = #registered
		for _, preset in Presets do
			if VfxPresets.get(preset.id) == nil then
				expect(table.find(registered, preset.id) ~= nil).toBe(true)
			end
		end
		expect(first <= #Presets).toBe(true)
	end)

	it(
		"MusicController with the real AudioController and game-001's placeholder Sounds: silent, no errors or warnings",
		function()
			-- every config/Sounds.luau entry is still "needed" (no asset chosen; user handoff), so nothing may
			-- play, and nothing may error or warn while the match runs through its phases (FORGE-00's #49 check)
			local client = MockEnv.new({ seed = 4962, isServer = false, localPlayer = { userId = 4962 } })
			local registry = Loader.load(client, { SettingsDef, AudioDef, MusicDef })
			local controller = registry:get("MusicController")
			for _, phase in { "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" } do
				controller:setPhase(phase)
				client.mock:advance(25)
			end
			controller:setResult("won")
			client.mock:advance(5)
			local audio = registry:get("AudioController")
			expect(audio.stats.played).toBe(0)
			expect((audio.stats.skipped.needed or 0) > 0).toBe(true) -- skipped as "needed", counted, not logged
			local loud = {}
			for _, entry in client.mock.logs do
				if entry.level == "warn" or entry.level == "error" then
					table.insert(loud, entry.message)
				end
			end
			expect(loud).toEqual({})
			expect(client.mock.threadErrors).toEqual({})
		end
	)

	it("MusicController: the phase picks the music, the match result wins at once, ambience starts once", function()
		local defs = doubles({ notifications = false })
		table.insert(defs, MusicDef)
		local controller = Loader.load(env, defs):get("MusicController")
		controller:setPhase("Founding")
		expect(music).toEqual({ "calm" })
		expect(#ambience).toBe(1)
		env.mock:advance(30)
		controller:setPhase("Conflict")
		expect(music[#music]).toBe("tension")
		controller:setResult("won")
		expect(music[#music]).toBe("victory")
		controller:setPhase("Expansion")
		expect(#ambience).toBe(1)
		controller:setPhase("Siege")
		expect(controller.phase).toBe("Expansion")
	end)

	it(
		"MusicController: a late joiner asks Match.GetState once; a draw or a spectator keeps the phase music (#49 L6, L4)",
		function()
			local root = env.newInstance("Folder")
			root.Name = "ForgeRemotes"
			root.Parent = env.ReplicatedStorage
			local area = env.newInstance("Folder")
			area.Name = "Match"
			area.Parent = root
			local getState = env.newInstance("RemoteFunction")
			getState.Name = "GetState"
			getState.Parent = area
			getState.OnServerInvoke = function()
				return "Conflict", nil, 0
			end
			local defs = doubles({ notifications = false })
			local announcer = { moment = Signal.new() }
			table.insert(defs, {
				name = "AnnouncerController",
				new = function()
					return announcer
				end,
			})
			table.insert(defs, MusicDef)
			local controller = Loader.load(env, defs):get("MusicController")
			env.mock:advance(0.1)
			expect(controller.phase).toBe("Conflict") -- no Match.State needed
			expect(music[#music]).toBe("tension")
			announcer.moment:fire({ kind = "matchEnded", outcome = "draw", won = false }, {})
			expect(controller.result).toBeNil()
			announcer.moment:fire({ kind = "matchEnded", outcome = "watched", won = false }, {})
			expect(controller.result).toBeNil()
			announcer.moment:fire({ kind = "matchEnded", outcome = "lost", won = false }, {})
			expect(controller.result).toBe("lost")
		end
	)
end)
