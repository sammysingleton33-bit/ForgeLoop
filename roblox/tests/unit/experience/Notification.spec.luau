local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local NotificationQueue = require("@game/ReplicatedStorage/Forge/Experience/NotificationQueue")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")
local Toast = require("@game/ReplicatedStorage/Forge/UI/Components/Toast")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local NotificationDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/NotificationController")

local function titles(items)
	local out = {}
	for _, item in items do
		table.insert(out, item.title)
	end
	return out
end

describe("Experience/NotificationQueue (FL-0027)", function()
	local clock, queue

	beforeEach(function()
		clock = 100
		queue = NotificationQueue.new({
			now = function()
				return clock
			end,
		})
	end)

	it("shows at most 3; the rest wait by priority, then arrival", function()
		for _, title in { "a", "b", "c", "d" } do
			queue:push({ title = title })
		end
		queue:push({ title = "warn", kind = "warning" }) -- replaces the oldest info toast
		queue:push({ title = "gift", kind = "reward" }) -- replaces the next info toast
		expect(titles(queue:visible())).toEqual({ "c", "warn", "gift" })
		queue:push({ title = "e" })
		queue:push({ title = "medal", kind = "achievement" }) -- nothing lower than achievement is left but info c
		expect(titles(queue:visible())).toEqual({ "warn", "gift", "medal" })
		expect(titles(queue:pending())).toEqual({ "d", "e" })
		expect(queue.stats.replaced).toBe(3)
	end)

	it("coalesces repeats by key into a ×N count and refreshes, but not past maxRefreshSec", function()
		local item = queue:push({ title = "House complete", kind = "success" })
		clock += 3
		local again, how = queue:push({ title = "House complete", kind = "success" })
		expect(how).toBe("coalesced")
		expect(again).toBe(item)
		expect(item.count).toBe(2)
		expect(item.expiresAt).toBe(clock + item.durationSec)
		for _ = 1, 10 do
			clock += 3
			queue:push({ title = "House complete", kind = "success" })
		end
		expect(item.count).toBe(12)
		expect(item.expiresAt).toBe(item.shownAt + NotificationQueue.DEFAULTS.maxRefreshSec)
		expect(#queue:visible()).toBe(1)
		local keyed, keyedHow = queue:push({ title = "Farm complete", kind = "success", key = "built" })
		local _, sameKey = queue:push({ title = "House complete (2)", kind = "success", key = "built" })
		expect(keyedHow).toBe("shown")
		expect(sameKey).toBe("coalesced")
		expect(keyed.count).toBe(2)
	end)

	it("expires toasts and promotes the highest-priority waiting one", function()
		for _, title in { "a", "b", "c" } do
			queue:push({ title = title, durationSec = 2 })
		end
		queue:push({ title = "later" })
		queue:push({ title = "medal", kind = "achievement", durationSec = 5 }) -- replaces a
		expect(titles(queue:pending())).toEqual({ "later" })
		clock += 2
		local shown, hidden = queue:tick()
		expect(titles(hidden)).toEqual({ "b", "c" })
		expect(titles(shown)).toEqual({ "later" })
		expect(titles(queue:visible())).toEqual({ "medal", "later" })
	end)

	it("keeps at most maxPending waiting, dropping the lowest-priority oldest first", function()
		for i = 1, 3 do
			queue:push({ title = `warn{i}`, kind = "warning" })
		end
		for i = 1, 8 do
			queue:push({ title = `info{i}` })
		end
		expect(#queue:pending()).toBe(8)
		local _, how = queue:push({ title = "reward", kind = "reward" })
		expect(how).toBe("waiting")
		expect(#queue:pending()).toBe(8)
		expect(titles(queue:pending())[1]).toBe("reward")
		expect(table.find(titles(queue:pending()), "info1")).toBeNil() -- the oldest info went
		local _, dropped = queue:push({ title = "lowly", kind = "info" })
		expect(dropped).toBe("waiting") -- equal priority: the oldest waiting info leaves instead
		expect(table.find(titles(queue:pending()), "info2")).toBeNil()
		expect(queue.stats.dropped).toBe(2)
	end)

	it("the 'important' filter keeps only warnings, errors, achievements and important = true", function()
		queue:setFilter("important")
		expect(select(2, queue:push({ title = "chat" }))).toBe("filtered")
		expect(select(2, queue:push({ title = "gift", kind = "reward" }))).toBe("filtered")
		expect(select(2, queue:push({ title = "raid", kind = "warning" }))).toBe("shown")
		expect(select(2, queue:push({ title = "medal", kind = "achievement" }))).toBe("shown")
		expect(select(2, queue:push({ title = "slice", kind = "reward", important = true }))).toBe("shown")
		expect(queue.stats.filtered).toBe(2)
	end)

	it("clamps durations, cuts long text, maps unknown kinds to info and rejects empty titles", function()
		local long = queue:push({ title = string.rep("t", 80), body = string.rep("b", 200), durationSec = 60 })
		expect(utf8.len(long.title)).toBe(60)
		expect(utf8.len(long.body)).toBe(140)
		expect(long.durationSec).toBe(NotificationQueue.DEFAULTS.maxSec)
		local odd = queue:push({ title = "odd", kind = "party", durationSec = 0 })
		expect(odd.kind).toBe("info")
		expect(odd.durationSec).toBe(NotificationQueue.DEFAULTS.minSec)
		expect(select(2, queue:push({ title = "" }))).toBe("invalid")
		expect(select(2, queue:push({}))).toBe("invalid")
	end)

	it("a NaN duration gets the kind's default; invalid UTF-8 is cut by bytes", function()
		local nan = queue:push({ title = "nan", durationSec = 0 / 0 })
		expect(nan.durationSec).toBe(NotificationQueue.DURATION.info)
		local broken = queue:push({ title = string.rep("\255", 5000), body = string.rep("\254", 5000) })
		expect(#broken.title).toBe(60 + #"…")
		expect(#broken.body).toBe(140 + #"…")
	end)
end)

describe("NotificationQueue:setMaxVisible (FL-0027 follow-up, #33 L3)", function()
	it("fewer cards fit: the lowest-priority toast waits and shows again in full; the cap never leaves 1..3", function()
		local clock = 100
		local queue = NotificationQueue.new({
			now = function()
				return clock
			end,
		})
		queue:push({ title = "a", kind = "warning" })
		queue:push({ title = "b", kind = "info" })
		queue:push({ title = "c", kind = "success" })
		local hidden = queue:setMaxVisible(2)
		expect(#hidden).toBe(1)
		expect(hidden[1].title).toBe("b") -- info, older than the success: it leaves first
		expect(#queue:visible()).toBe(2)
		expect(queue:pending()[1].title).toBe("b")
		expect(queue:pending()[1].expiresAt).toBeNil()
		queue:setMaxVisible(10) -- back to the configured 3 at most
		local shown = queue:tick()
		expect(#shown).toBe(1)
		expect(shown[1].expiresAt).toBe(clock + shown[1].durationSec) -- a full showing
		expect(#queue:visible()).toBe(3)
		queue:setMaxVisible(0)
		expect(#queue:visible()).toBe(1)
		queue:setMaxVisible(0 / 0)
		queue:tick()
		expect(#queue:visible()).toBe(3)
	end)
end)

describe("NotificationController (FL-0027, interfaces §8)", function()
	local env, gui, registry, controller, settings, played, effects, screenHeight

	local function boot()
		screenHeight = nil
		registry = Loader.load(env, {
			SettingsDef,
			{
				name = "AudioController",
				new = function()
					return {
						play = function(_, id)
							table.insert(played, id)
							return if string.find(id, "^reward%.") then nil else { id = id }
						end,
					}
				end,
			},
			{
				name = "VFXController",
				new = function()
					return {
						play = function(_, id, opts)
							table.insert(
								effects,
								{ id = id, position = opts and opts.position, tint = opts and opts.tint }
							)
						end,
					}
				end,
			},
			{
				name = "NotificationController",
				dependencies = { "SettingsController" },
				new = function(e, r)
					return NotificationDef.create(e, r, {
						playerGui = gui,
						screenHeight = function()
							return screenHeight
						end,
					})
				end,
			},
		})
		controller = registry:get("NotificationController")
		settings = registry:get("SettingsController")
	end

	local function stack()
		local screen = gui:FindFirstChild("ForgeNotifications")
		return screen and screen:FindFirstChild("Stack")
	end

	local function toasts()
		local out = {}
		local frame = stack()
		if frame == nil then
			return out
		end
		for _, child in frame:GetChildren() do
			if string.match(child.Name, "^Toast_") then
				table.insert(out, child)
			end
		end
		table.sort(out, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		return out
	end

	beforeEach(function()
		env = MockEnv.new({ isServer = false, localPlayer = { userId = 2701 }, services = { GuiService = {} } })
		gui = env.newInstance("Folder")
		gui.Name = "PlayerGui"
		gui.Parent = env.mock.localPlayer
		played, effects = {}, {}
		boot()
	end)

	it("draws the stack in the notifications band (DisplayOrder 70), newest on top, with a ×N badge", function()
		controller:show({ title = "House complete", kind = "success" })
		controller:show({ title = "Wood is low", kind = "warning" })
		controller:show({ title = "House complete", kind = "success" })
		local screen = gui:FindFirstChild("ForgeNotifications")
		expect(screen.DisplayOrder).toBe(70)
		local shown = toasts()
		expect(#shown).toBe(2)
		expect(shown[1]:FindFirstChild("Title", true).Text).toBe("Wood is low") -- newest on top
		expect(shown[2]:FindFirstChild("Count", true).Text).toBe("×2")
		expect(shown[2]:GetAttribute("kind")).toBe("success") -- the card is FORGE-03's UI/Components/Toast
		expect(shown[2]:FindFirstChild("Dismiss")).never.toBeNil()
		expect(played).toEqual({ "notify.info", "notify.warning" }) -- a coalesced repeat is silent
	end)

	it("hides expired toasts and shows the waiting one on the virtual clock", function()
		for i = 1, 4 do
			controller:show({ title = `t{i}`, durationSec = 2 })
		end
		expect(#toasts()).toBe(3)
		env.mock:advance(2.2)
		local shown = toasts()
		expect(#shown).toBe(1)
		expect(shown[1]:FindFirstChild("Title", true).Text).toBe("t4")
		env.mock:advance(4)
		expect(#toasts()).toBe(0)
	end)

	it("applies the notifications setting live", function()
		settings:set("notifications", "important")
		expect(select(2, controller:show({ title = "chat" }))).toBe("filtered")
		expect(select(2, controller:show({ title = "raid", kind = "warning" }))).toBe("shown")
		settings:set("notifications", "all")
		expect(select(2, controller:show({ title = "chat" }))).toBe("shown")
	end)

	it(
		"celebrate('reward') plays the rarity sound (falling back when it is missing), a burst and no extra notify sound",
		function()
			expect(controller:celebrate("reward", { rarity = "Epic", itemId = "banner", qty = 1 })).toBe(true)
			expect(played).toEqual({ "reward.epic", "notify.reward" })
			expect(effects[1].id).toBe("reward.burst")
			expect(#toasts()).toBe(0) -- FORGE-03's reveal is the visual; no title, no toast
		end
	)

	it("a reward without a rarity never asks for the sound id 'reward.'", function()
		controller:celebrate("reward", { itemId = "banner" })
		expect(table.find(played, "reward.")).toBeNil()
		expect(played).toEqual({ "notify.reward" })
	end)

	it("coalesces the same celebration within its cooldown (no double fanfare)", function()
		expect(controller:celebrate("achievement", { title = "First capture" })).toBe(true)
		expect(controller:celebrate("achievement", { title = "First capture" })).toBe(false)
		expect(#effects).toBe(1)
		env.mock:advance(1.1)
		expect(controller:celebrate("achievement", { title = "Keep level 2" })).toBe(true)
		expect(#effects).toBe(2)
	end)

	it("a different moment of the same kind within the cooldown gets its toast, without a second fanfare", function()
		expect(controller:celebrate("achievement", { title = "Watchtower captured" })).toBe(true)
		expect(controller:celebrate("achievement", { title = "Bridge captured" })).toBe(true)
		expect(controller:celebrate("achievement", { title = "Bridge captured" })).toBe(false) -- reported twice
		expect(#effects).toBe(1)
		local shownTitles = {}
		for _, toast in toasts() do
			table.insert(shownTitles, toast:FindFirstChild("Title", true).Text)
		end
		table.sort(shownTitles)
		expect(shownTitles).toEqual({ "Bridge captured", "Watchtower captured" })
	end)

	it("payload.tint colours the celebration's effect; anything else is ignored", function()
		local red = Color3.fromRGB(190, 40, 50)
		controller:celebrate("achievement", { title = "A", tint = red })
		env.mock:advance(1.1)
		controller:celebrate("achievement", { title = "B", tint = "red" })
		expect(effects[1].tint).toBe(red)
		expect(effects[2].tint).toBeNil()
	end)

	it("a payload that is not a table counts as none and never throws", function()
		expect(controller:celebrate("achievement", 42)).toBe(true)
		expect(controller:celebrate("levelUp", "five")).toBe(true)
		expect(env.mock.threadErrors).toEqual({})
	end)

	it("place() follows the game's layout; reserveTop() keeps the stack below a card until freed", function()
		controller:show({ title = "House complete" })
		local frame = stack()
		expect(frame.Position).toEqual(UDim2.new(1, -12, 0, 12))
		controller:place(UDim2.new(1, -60, 0, 96), Vector2.new(1, 0), 250)
		expect(frame.Position).toEqual(UDim2.new(1, -60, 0, 96))
		expect(frame:FindFirstChildOfClass("UISizeConstraint").MaxSize.X).toBe(250)
		controller:reserveTop("onboarding", 168)
		expect(frame.Position.Y.Offset).toBe(168)
		controller:reserveTop("onboarding", 40) -- below the placement: the placement wins
		expect(frame.Position.Y.Offset).toBe(96)
		controller:reserveTop("onboarding", nil)
		expect(frame.Position.Y.Offset).toBe(96)
		expect(#toasts()).toBe(1) -- the card was rebuilt at the new width, not lost
	end)

	it("celebration toasts are important (pass the filter) and silent (the moment has its own sound)", function()
		settings:set("notifications", "important")
		controller:celebrate("onboardingComplete", { body = "Your kingdom is yours to grow." })
		local shown = toasts()
		expect(#shown).toBe(1)
		expect(shown[1]:FindFirstChild("Title", true).Text).toBe("Tutorial complete")
		expect(played).toEqual({ "onboarding.complete" })
	end)

	it("games register celebrations; sound-only or empty specs are rejected", function()
		expect(controller:registerCelebration("keepUpgraded", {
			sound = "kingdom.keep.upgrade",
			vfx = "levelup.column",
			toast = { kind = "achievement", title = "Keep level {level}" },
		})).toEqual({})
		expect(controller:celebrate("keepUpgraded", { level = 2 })).toBe(true)
		expect(toasts()[1]:FindFirstChild("Title", true).Text).toBe("Keep level 2")
		expect(#controller:registerCelebration("horn", { sound = "kingdom.horn.war" })).toBe(1)
		expect(#controller:registerCelebration("nothing", {})).toBe(1)
		expect(controller:celebrate("horn")).toBe(false)
		expect(env.mock:hasLog("warn", "unknown celebration 'horn'")).toBe(true)
	end)

	it("every factory celebration is valid", function()
		for kind, spec in NotificationDef.CELEBRATIONS do
			expect(NotificationDef.validateCelebration(kind, spec)).toEqual({})
		end
	end)

	it("after destroy(), show and celebrate do nothing and no GUI comes back (#33 L1)", function()
		controller:destroy()
		expect(select(2, controller:show({ title = "late" }))).toBe("dropped")
		expect(controller:celebrate("achievement", { title = "late" })).toBe(false)
		controller:reserveTop("onboarding", 168)
		controller:place(UDim2.fromOffset(40, 40), Vector2.new(1, 0), 250) -- a rebuild must not recreate it
		expect(gui:FindFirstChild("ForgeNotifications")).toBeNil()
		expect(#effects).toBe(0)
	end)

	it(
		"a toast's own icon reaches the card; without one, Toast's default for the kind (achievement: laurel)",
		function()
			-- FORGE-03's Toast has the achievement icon itself since FL-0105 (#86), so nothing here picks one
			local seen = {}
			local original = Toast.new
			Toast.new = function(props)
				seen[props.title] = { icon = props.icon }
				return original(props)
			end
			local ok, err = pcall(function()
				controller:show({ title = "First capture", kind = "achievement" })
				controller:show({ title = "Crest", kind = "achievement", icon = "crest" })
			end)
			Toast.new = original
			assert(ok, err)
			expect(seen["Crest"]).never.toBeNil()
			expect(seen["Crest"].icon).toBe("crest")
			expect(seen["First capture"]).never.toBeNil()
			expect(seen["First capture"].icon).toBeNil() -- Toast's own default
			expect(Toast.ICON.achievement).toBe("laurel")
			local laurel = Theme.icon("laurel") -- the card really renders it (glyph fallback headless)
			local achievement
			for _, toast in toasts() do
				if toast:FindFirstChild("Title", true).Text == "First capture" then
					achievement = toast:FindFirstChild("Icon", true)
				end
			end
			expect(achievement).never.toBeNil()
			if laurel.image ~= "" then
				expect(achievement.Image).toBe(laurel.image)
			else
				expect(achievement.Text).toBe(laurel.glyph)
			end
		end
	)

	it(
		"a short screen under the onboarding card shows fewer cards, and all three again when it frees (#33 L3)",
		function()
			screenHeight = 360 -- a phone in landscape, safe area
			for i = 1, 3 do
				controller:show({ title = `t{i}` })
			end
			expect(#toasts()).toBe(3)
			controller:reserveTop("onboarding", 168)
			expect(#toasts()).toBe(2) -- 360 - 168 leaves room for 2 cards; the third waits
			expect(controller.queue:pending()[1].title).toBe("t1")
			controller:reserveTop("onboarding", nil)
			env.mock:advance(0.2) -- the next tick shows it again
			expect(#toasts()).toBe(3)
			expect(#played).toBe(3) -- shown again, not announced again (FORGE-07 #82 L1)
		end
	)

	it(
		"place()'s limit caps the cards in that placement; a later place() without it shows 3 again (FORGE-03)",
		function()
			for i = 1, 3 do
				controller:show({ title = `t{i}` })
			end
			controller:place(UDim2.fromOffset(300, 200), Vector2.new(1, 0), 240, 1) -- a narrow band above a sheet
			expect(#toasts()).toBe(1)
			expect(toasts()[1]:FindFirstChild("Title", true).Text).toBe("t3") -- the newest stays
			controller:place(UDim2.fromOffset(300, 60), Vector2.new(1, 0), 240)
			env.mock:advance(0.2)
			expect(#toasts()).toBe(3)
		end
	)

	it("dismiss() removes a toast at once and lets the next one in", function()
		local items = {}
		for i = 1, 4 do
			table.insert(items, (controller:show({ title = `t{i}` })))
		end
		expect(controller:dismiss(items[1].id)).toBe(true)
		local shown = toasts()
		expect(#shown).toBe(3)
		expect(shown[1]:FindFirstChild("Title", true).Text).toBe("t4")
	end)
end)
