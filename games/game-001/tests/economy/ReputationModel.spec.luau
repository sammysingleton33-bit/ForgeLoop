-- FL-0089: the pure parts of the reputation UI — formatting, clamping, history order, relative
-- times, value bands, the category texts provider, and the Layout zone of the HUD strip.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local ReputationModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ReputationModel")
local ReputationText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ReputationText")

local function payload(history)
	return {
		values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
		history = history or {},
		kingdom = { happiness = 68, stability = 54, morale = 41 },
	}
end

describe("ReputationModel formatting", function()
	it("clamps values to 0..100 and rounds them; anything else is unknown", function()
		expect(ReputationModel.value(-5)).toBe(0)
		expect(ReputationModel.value(140)).toBe(100)
		expect(ReputationModel.value(61.6)).toBe(62)
		expect(ReputationModel.value(61.4)).toBe(61)
		expect(ReputationModel.value(100)).toBe(100)
		expect(ReputationModel.value("62")).toBeNil()
		expect(ReputationModel.value(0 / 0)).toBeNil()
		expect(ReputationModel.value(math.huge)).toBeNil()
		expect(ReputationModel.value(nil)).toBeNil()
	end)

	it("signs deltas with a plus or a true minus and at most one decimal", function()
		expect(ReputationModel.signed(4)).toBe("+4")
		expect(ReputationModel.signed(-5)).toBe("−5")
		expect(ReputationModel.signed(1.5)).toBe("+1.5")
		expect(ReputationModel.signed(-0.25)).toBe("−0.3")
		expect(ReputationModel.signed(2.04)).toBe("+2")
		expect(ReputationModel.signed(0)).toBe("0")
		expect(ReputationModel.signed(0.01)).toBe("0")
	end)

	it("says how long ago in plain words (t and now are serverTimeNow seconds)", function()
		expect(ReputationModel.ago(1000, 1000)).toBe("just now")
		expect(ReputationModel.ago(1000, 1009.9)).toBe("just now")
		expect(ReputationModel.ago(1000, 1045)).toBe("45 s ago")
		expect(ReputationModel.ago(1000, 1059.9)).toBe("59 s ago")
		expect(ReputationModel.ago(1000, 1060)).toBe("1 min ago")
		expect(ReputationModel.ago(1000, 1130)).toBe("2 min ago")
		expect(ReputationModel.ago(1000, 1000 + 3599)).toBe("59 min ago")
		expect(ReputationModel.ago(1000, 1000 + 7300)).toBe("2 h ago")
		expect(ReputationModel.ago(1000, 990)).toBe("just now") -- clock skew: never "−10 s ago"
	end)

	it("names value bands (presentation words only)", function()
		expect(ReputationModel.band(0)).toBe("Low")
		expect(ReputationModel.band(33)).toBe("Low")
		expect(ReputationModel.band(34)).toBe("Medium")
		expect(ReputationModel.band(66)).toBe("Medium")
		expect(ReputationModel.band(67)).toBe("High")
		expect(ReputationModel.band(100)).toBe("High")
	end)
end)

describe("ReputationModel.normalize", function()
	it("orders history newest first, whatever order the server sent", function()
		local data = ReputationModel.normalize(payload({
			{ t = 100, category = "honor", delta = -5, text = "oldest" },
			{ t = 300, category = "fear", delta = 3, text = "newest" },
			{ t = 200, category = "compassion", delta = 4, text = "middle" },
		}))
		expect(#data.history).toBe(3)
		expect(data.history[1].text).toBe("newest")
		expect(data.history[2].text).toBe("middle")
		expect(data.history[3].text).toBe("oldest")
		local rows = ReputationModel.history(data, 400)
		expect(rows[1].text).toBe("newest")
		expect(rows[1].ago).toBe("1 min ago")
		expect(rows[3].deltaText).toBe("−5")
		expect(rows[3].positive).toBe(false)
	end)

	it("keeps the later of two changes with the same time first (one decision, two categories)", function()
		local data = ReputationModel.normalize(payload({
			{ t = 50, category = "fear", delta = 6, text = "burned (fear)" },
			{ t = 50, category = "honor", delta = -4, text = "burned (honor)" },
		}))
		expect(data.history[1].category).toBe("honor")
		expect(data.history[2].category).toBe("fear")
	end)

	it("drops malformed entries and fields instead of failing", function()
		local data = ReputationModel.normalize({
			values = { compassion = 250, honor = "high", fear = -3, unknown = 50 },
			history = {
				{ t = 10, category = "honor", delta = 2, text = "ok" },
				{ t = "x", category = "honor", delta = 2, text = "bad time" },
				{ t = 11, category = "greed", delta = 2, text = "unknown category" },
				{ t = 12, category = "fear", delta = "3", text = "bad delta" },
				{ t = 13, category = "courage", delta = 1 }, -- no text: kept, text ""
				"not a table",
			},
			kingdom = { happiness = 101, stability = nil, morale = 30 },
		})
		expect(data.known).toBe(true)
		expect(data.values.compassion).toBe(100)
		expect(data.values.honor).toBeNil()
		expect(data.values.fear).toBe(0)
		expect(data.values.unknown).toBeNil()
		expect(#data.history).toBe(2)
		expect(data.history[1].category).toBe("courage")
		expect(data.history[1].text).toBe("")
		expect(data.kingdom.happiness).toBe(100)
		expect(data.kingdom.stability).toBeNil()
		expect(ReputationModel.normalize(nil).known).toBe(false)
		expect(ReputationModel.normalize("oops").known).toBe(false)
	end)

	it("reports per-category changes between two payloads, and none from an unknown start", function()
		local a = ReputationModel.normalize(payload())
		local p = payload()
		p.values.compassion = 66
		p.values.fear = 13
		local b = ReputationModel.normalize(p)
		local d = ReputationModel.deltas(a, b)
		expect(d.compassion).toBe(4)
		expect(d.fear).toBe(-2)
		expect(d.honor).toBeNil()
		expect(next(ReputationModel.deltas(ReputationModel.empty(), b))).toBeNil()
		expect(next(ReputationModel.deltas(nil, b))).toBeNil()
	end)
end)

describe("ReputationModel rows", function()
	it("gives six strip items in display order, each labelled by its number (never colour alone)", function()
		local items = ReputationModel.strip(ReputationModel.normalize(payload()))
		expect(#items).toBe(6)
		local ids = {}
		for i, item in items do
			ids[i] = item.id
			expect(item.icon).toBe("rep_" .. item.id)
			expect(item.label).toBe(tostring(item.value))
		end
		expect(table.concat(ids, ",")).toBe("compassion,honor,competence,courage,authority,fear")
		local unknown = ReputationModel.strip(ReputationModel.empty())
		expect(unknown[1].label).toBe("…")
		expect(unknown[1].value).toBeNil()
	end)

	it("shows category prose only from a provider, and the latest three changes per category", function()
		local data = ReputationModel.normalize(payload({
			{ t = 1, category = "honor", delta = 1, text = "h1" },
			{ t = 2, category = "honor", delta = 1, text = "h2" },
			{ t = 3, category = "honor", delta = 1, text = "h3" },
			{ t = 4, category = "honor", delta = 1, text = "h4" },
			{ t = 5, category = "fear", delta = 1, text = "f1" },
		}))
		local rows = ReputationModel.categories(data, 10)
		for _, r in rows do
			expect(r.description).toBeNil()
			expect(r.affects).toBeNil()
		end
		local honor = rows[2]
		expect(honor.id).toBe("honor")
		expect(honor.band).toBe("Medium")
		expect(#honor.recent).toBe(3)
		expect(honor.recent[1].text).toBe("h4")
		expect(honor.recent[3].text).toBe("h2")
		local withText = ReputationModel.categories(data, 10, function(id)
			return if id == "honor" then { description = "D", affects = "A", name = "Honour" } else nil
		end)
		expect(withText[2].description).toBe("D")
		expect(withText[2].affects).toBe("A")
		expect(withText[2].name).toBe("Honour")
		expect(withText[1].description).toBeNil()
	end)

	it("gives the three kingdom conditions with bands", function()
		local c = ReputationModel.conditions(ReputationModel.normalize(payload()))
		expect(#c).toBe(3)
		expect(c[1].id).toBe("happiness")
		expect(c[1].label).toBe("68")
		expect(c[1].band).toBe("High")
		expect(c[3].name).toBe("Army morale")
		expect(c[3].band).toBe("Medium")
		expect(ReputationModel.conditions(ReputationModel.empty())[2].label).toBe("…")
	end)
end)

describe("ReputationText", function()
	it("lists the six G13.2 categories and invents no prose until the content library lands", function()
		expect(#ReputationText.IDS).toBe(6)
		for _, id in ReputationText.IDS do
			local info = ReputationText.CATEGORIES[id]
			expect(info.name).toBeTruthy()
			expect(info.icon).toBe("rep_" .. id)
		end
		expect(ReputationText.isCategory("fear")).toBe(true)
		expect(ReputationText.isCategory("greed")).toBe(false)
		-- FL-0083 not merged: no default provider. When it lands this becomes a provider over
		-- Content/Reputation (see the switch in UI/ReputationText).
		expect(ReputationText.provider).toBeNil()
	end)

	it("reads Content/Reputation.categories[id] = { name, description, affects } loosely", function()
		local provider = ReputationText.fromContent({
			categories = { honor = { name = "Honor", description = "D", affects = "A" }, fear = { description = 3 } },
		})
		assert(provider, "provider")
		expect(provider("honor").description).toBe("D")
		expect(provider("fear").description).toBeNil()
		expect(provider("courage")).toBeNil()
		expect(ReputationText.fromContent(nil)).toBeNil()
		expect(ReputationText.fromContent({ categories = "x" })).toBeNil()
	end)
end)

describe("Layout: the reputation strip zone", function()
	local SIZES = { { 750, 311 }, { 1024, 690 }, { 1920, 1022 }, { 1280, 662 }, { 640, 360 } }

	it("puts the strip in the top-left stack, clear of the pills, rulers and crest badge", function()
		for _, size in SIZES do
			local m = Layout.compute(size[1], size[2])
			local r = m.hud.reputation
			expect(r.x).toBe(m.hud.x)
			expect(r.width % 1).toBe(0)
			expect(r.height % 1).toBe(0)
			expect(r.y).toBeGreaterThan(m.hud.pills.y + Layout.PILL_HEIGHT - 1)
			if m.hud.members then
				expect(r.y).toBeGreaterThan(m.hud.members.y + Layout.MEMBERS_HEIGHT - 1)
				expect(r.columns).toBe(3)
			else
				expect(r.y).toBeGreaterThan(m.hud.y + m.hud.crest + 8) -- the Crown Points badge hangs to here
				expect(r.columns).toBe(6)
			end
			expect(m.hud.bottom).toBe(r.y + r.height)
			expect(r.x + r.width).toBeLessThan(m.width / 2)
		end
	end)

	it("never lets a drawer overlap the strip", function()
		for _, size in SIZES do
			local m = Layout.compute(size[1], size[2])
			local r = m.hud.reputation
			local d = m.drawer
			local apart = (r.x + r.width <= d.x) or (r.y + r.height <= d.y)
			expect(apart).toBe(true)
			if m.breakpoint == "phone" then
				expect(r.x + r.width).toBeLessThan(d.x) -- side by side
			else
				expect(d.y).toBeGreaterThan(r.y + r.height) -- the drawer starts below it
				expect(d.height).toBeGreaterThan(380) -- still room for the build detail and CTA
			end
		end
	end)

	it("keeps phone toasts under the strip while a drawer is open", function()
		local m = Layout.compute(750, 311)
		expect(Layout.toastTop(m, true)).toBeGreaterThan(m.hud.reputation.y + m.hud.reputation.height)
	end)
end)
