--[[
	Arena/SupportModel + config Support (FL-0070, design §3-§4, CONTRACTS G12.2/G12.3): the score, the tiers, the
	trigger offers and the duel modifiers. Pure and deterministic; every modifier set it can produce passes Caps.check.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Caps = require("@game/ReplicatedStorage/Game/Arena/Caps")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

-- samples every 30 s from `from` to `to` where every component has `value`
local function flat(from: number, to: number, value: number, into: { any }?): { any }
	local out = into or {}
	local t = from
	while t <= to do
		local components = {}
		for _, c in Support.componentOrder do
			components[c] = value
		end
		table.insert(out, { t = t, components = components })
		t += 30
	end
	return out
end

describe("config Support", function()
	it("component weights add up to 100, tiers descend, every role's perk exists", function()
		local sum = 0
		for _, c in Support.componentOrder do
			sum += Support.components[c].weight
		end
		expect(sum).toBe(100)
		local last = math.huge
		for _, tier in Support.tierOrder do
			expect(Support.tiers[tier].min < last).toBe(true)
			last = Support.tiers[tier].min
		end
		expect(Support.tiers.hostile.min).toBe(0)
		for _, role in Support.roleOrder do
			expect(Support.perks[Support.roles[role].perk]).never.toBeNil()
		end
		for id, act in Support.acts do
			expect(Support.components[act.component]).never.toBeNil()
			expect(type(act.text) == "string" and #act.text > 0).toBe(true)
			expect(act.delta ~= 0).toBe(true)
			expect(id).never.toBe("")
		end
	end)
end)

describe("Arena/SupportModel: score and tiers", function()
	it("tierOf honours the band edges", function()
		expect(SupportModel.tierOf(100)).toBe("adoring")
		expect(SupportModel.tierOf(85)).toBe("adoring")
		expect(SupportModel.tierOf(84.99)).toBe("loyal")
		expect(SupportModel.tierOf(65)).toBe("loyal")
		expect(SupportModel.tierOf(64.99)).toBe("divided")
		expect(SupportModel.tierOf(40)).toBe("divided")
		expect(SupportModel.tierOf(39.99)).toBe("restless")
		expect(SupportModel.tierOf(20)).toBe("restless")
		expect(SupportModel.tierOf(19.99)).toBe("hostile")
		expect(SupportModel.tierOf(0)).toBe("hostile")
	end)

	it("no samples is neutral (50, divided); a flat history scores its value", function()
		local score, tier = SupportModel.score({}, { now = 600 })
		expect(score).toBe(50)
		expect(tier).toBe("divided")
		for _, v in { 0, 19, 20, 64, 65, 85, 100 } do
			local s, t = SupportModel.score(flat(0, 1800, v), { now = 1800 })
			expect(math.abs(s - v) < 1e-9).toBe(true)
			expect(t).toBe(SupportModel.tierOf(v))
		end
	end)

	it("a sample that lacks a component counts it as neutral, not as zero", function()
		local score = SupportModel.score({ { t = 30, components = { loyalty = 100 } } }, { now = 60 })
		-- loyalty 100 (weight 20) + six components at 50 (weight 80)
		expect(math.abs(score - (20 * 100 + 80 * 50) / 100) < 1e-9).toBe(true)
	end)

	it("a NaN or infinite input is never evidence: the middle tier, not a top or bottom score", function()
		local nan = 0 / 0
		-- one component NaN, one infinite, one negative-infinite: each counts as neutral, like a missing one
		local samples = flat(0, 600, 50)
		samples[3].components.loyalty = nan
		samples[4].components.morale = math.huge
		samples[5].components.conduct = -math.huge
		local score, tier = SupportModel.score(samples, { now = 600 })
		expect(score).toBe(50)
		expect(tier).toBe("divided")
		-- a NaN timestamp is dropped; a NaN or infinite `now` reads as no history
		local stamped = flat(0, 600, 90)
		stamped[2].t = nan
		table.insert(stamped, { t = -math.huge, components = { loyalty = 0, conduct = 0, morale = 0 } }) -- an infinite past
		local good = SupportModel.score(stamped, { now = 600 })
		expect(math.abs(good - 90) < 1e-9).toBe(true)
		local noNow, noNowTier = SupportModel.score(flat(0, 600, 90), { now = nan })
		expect(noNow).toBe(50)
		expect(noNowTier).toBe("divided")
		expect((SupportModel.score(flat(0, 600, 90), { now = math.huge }))).toBe(50)
		-- tierOf: NaN is the neutral tier; real out-of-range scores still clamp to the ends
		expect(SupportModel.tierOf(nan)).toBe("divided")
		expect(SupportModel.tierOf(-5)).toBe("hostile")
		expect(SupportModel.tierOf(500)).toBe("adoring")
		-- and the trend stays a finite number
		local trend = SupportModel.trend(samples, { now = 600 })
		expect(trend == trend).toBe(true)
	end)

	it("each component counts by its weight: loyalty (20) moves the score twice as far as morale (10)", function()
		local function with(component: string, value: number)
			local samples = flat(0, 900, 50)
			for _, s in samples do
				s.components[component] = value
			end
			return (SupportModel.score(samples, { now = 900 }))
		end
		local loyaltyGain = with("loyalty", 100) - 50
		local moraleGain = with("morale", 100) - 50
		expect(math.abs(loyaltyGain - 2 * moraleGain) < 1e-9).toBe(true)
		expect(math.abs(loyaltyGain - 10) < 1e-9).toBe(true) -- 20 % of +50
	end)

	it("a good deed in the last minute cannot jump a tier: 40 minutes at 50, then two samples at 100", function()
		local samples = flat(0, 2400, 50)
		local before = SupportModel.score(samples, { now = 2400 })
		flat(2430, 2490, 100, samples)
		local after, tier = SupportModel.score(samples, { now = 2490 })
		expect(after - before < 5).toBe(true)
		expect(tier).toBe("divided")
	end)

	it("an early mistake is repairable: 10 minutes at 0, then 30 minutes at 80 ends loyal", function()
		local samples = flat(0, 570, 0)
		flat(600, 2400, 80, samples)
		local score, tier = SupportModel.score(samples, { now = 2400 })
		expect(score >= 65).toBe(true)
		expect(tier).toBe("loyal")
	end)

	it("ignores samples from the future and does not depend on their order", function()
		local samples = flat(0, 900, 70)
		local shuffled = {}
		for i = #samples, 1, -1 do
			table.insert(shuffled, samples[i])
		end
		flat(960, 1500, 0, shuffled) -- later than `now`
		local a = SupportModel.score(samples, { now = 900 })
		local b = SupportModel.score(shuffled, { now = 900 })
		expect(math.abs(a - b) < 1e-9).toBe(true)
	end)

	it("the breakdown reports each component's time-weighted value; the trend is the change over 5 minutes", function()
		local samples = flat(0, 900, 40)
		flat(930, 1200, 80, samples)
		local _, _, breakdown = SupportModel.score(samples, { now = 1200 })
		for _, c in Support.componentOrder do
			expect(breakdown[c] > 40 and breakdown[c] < 80).toBe(true)
		end
		expect(SupportModel.trend(samples, { now = 1200 }) > 0).toBe(true)
		expect(SupportModel.trend(flat(0, 1200, 60), { now = 1200 })).toBe(0)
		expect(SupportModel.trend(flat(0, 100, 60), { now = 100 })).toBe(0) -- not enough history
		local falling = flat(0, 900, 80)
		flat(930, 1200, 30, falling)
		expect(SupportModel.trend(falling, { now = 1200 }) < 0).toBe(true)
	end)
end)

describe("Arena/SupportModel: offers", function()
	local function keys(loyalty: number, alive: boolean?)
		return {
			{ role = "blacksmith", citizenId = 11, name = "Brann", loyalty = loyalty, alive = alive ~= false },
			{ role = "healer", citizenId = 12, name = "Ilse", loyalty = 95, alive = true },
		}
	end

	it("offers a perk at loyalty 80 (pledged) and the stronger one at 95 (empowered), nothing below 80", function()
		local low = SupportModel.offers(keys(79), "adoring")
		for _, offer in low do
			expect(offer.trigger ~= "reforge").toBe(true)
		end
		local pledged = SupportModel.offers(keys(80), "loyal")
		expect(pledged[1].trigger).toBe("reforge")
		expect(pledged[1].power).toBe("pledged")
		expect(pledged[1].citizenName).toBe("Brann")
		expect(pledged[1].loyalty).toBe(80)
		expect(pledged[1].effect).toBe("Damage taken -6 % for 6 s")
		local empowered = SupportModel.offers(keys(95), "loyal")
		expect(empowered[1].power).toBe("empowered")
		expect(empowered[1].effect).toBe("Damage taken -10 % for 6 s")
		expect(empowered[2].trigger).toBe("fieldRemedy")
		expect(empowered[2].effect).toBe("Regain 8 % of your HP over 4 s")
	end)

	it("a dead key citizen offers nothing; one key citizen per role", function()
		local offers = SupportModel.offers(keys(99, false), "loyal")
		expect(#offers).toBe(1)
		expect(offers[1].trigger).toBe("fieldRemedy")
		local twice = SupportModel.offers({
			{ role = "captain", loyalty = 90, alive = true, name = "A" },
			{ role = "captain", loyalty = 99, alive = true, name = "B" },
		}, "loyal")
		expect(#twice).toBe(1)
		expect(twice[1].citizenName).toBe("A")
		expect(twice[1].effect).toBe("Their first two heavy attacks are shown 0.15 s earlier")
	end)

	it("the Crowd Rally is offered to Adoring only, without a citizen; slots follow the tier", function()
		local adoring, adoringSlots = SupportModel.offers(keys(90), "adoring")
		expect(adoring[#adoring].trigger).toBe("crowdRally")
		expect(adoring[#adoring].citizenId).toBeNil()
		expect(adoringSlots).toBe(3)
		for tier, slots in { loyal = 3, divided = 2, restless = 1, hostile = 0 } do
			local offers, n = SupportModel.offers(keys(90), tier)
			expect(n).toBe(slots)
			for _, offer in offers do
				expect(offer.trigger ~= "crowdRally").toBe(true)
			end
		end
	end)
end)

describe("Arena/SupportModel: duel modifiers pass the caps", function()
	local TRIGGERS =
		{ "reforge", "fieldRemedy", "calledWarning", "heartyRations", "rallyingHymn", "fineWares", "crowdRally" }

	local function sets(pool: { string }, size: number): { { string } }
		local out: { { string } } = {}
		local current: { string } = {}
		local function pick(from: number)
			if #current == size then
				table.insert(out, table.clone(current))
				return
			end
			for i = from, #pool do
				table.insert(current, pool[i])
				pick(i + 1)
				table.remove(current)
			end
		end
		pick(1)
		return out
	end

	it("every tier x every pick set up to its slots x both powers is within Caps.check", function()
		local checked = 0
		for _, tier in Support.tierOrder do
			local slots = Support.tiers[tier].slots
			local pool = {}
			for _, name in TRIGGERS do
				if name ~= "crowdRally" or Support.tiers[tier].crowdRally then
					table.insert(pool, name)
				end
			end
			for size = 0, slots do
				for _, set in sets(pool, size) do
					for _, power in { "pledged", "empowered" } do
						local picks = {}
						for _, name in set do
							table.insert(picks, { trigger = name, power = power })
						end
						local ok, reason = Caps.check(SupportModel.modifiers(tier, picks))
						if not ok then
							error(`{tier} {table.concat(set, "+")} {power}: {reason}`)
						end
						checked += 1
					end
				end
			end
		end
		expect(checked > 100).toBe(true)
	end)

	it("the tier's passive blessing comes first; the Crowd Rally is one source with two effects", function()
		local mods = SupportModel.modifiers("adoring", { { trigger = "crowdRally", power = "empowered" } })
		expect(mods[1]).toEqual({
			source = "tier:adoring",
			kind = "passive",
			stat = "damageReduction",
			magnitude = 0.02,
		})
		local rally = {}
		for _, m in mods do
			if m.source == "crowdRally" then
				table.insert(rally, m)
			end
		end
		expect(#rally).toBe(2)
		expect(#SupportModel.modifiers("hostile", {})).toBe(0)
	end)

	it("refuses too many picks, the Rally below Adoring, an unknown trigger or power", function()
		expect(function()
			SupportModel.modifiers("hostile", { { trigger = "reforge", power = "pledged" } })
		end).toThrow("0 trigger slot")
		expect(function()
			SupportModel.modifiers("loyal", { { trigger = "crowdRally", power = "pledged" } })
		end).toThrow("needs the Adoring tier")
		expect(function()
			SupportModel.modifiers("loyal", { { trigger = "meteor", power = "pledged" } })
		end).toThrow("unknown trigger")
		expect(function()
			SupportModel.modifiers("loyal", { { trigger = "reforge", power = "mighty" } })
		end).toThrow("power must be")
		expect(function()
			SupportModel.modifiers("emperor" :: any, {})
		end).toThrow("unknown tier")
	end)
end)
