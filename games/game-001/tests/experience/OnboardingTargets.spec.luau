--[[
	Onboarding hint targets (FORGE-00's ask on #140, CONTRACTS G13.5 and G13.9). The VS-1 hints never name a
	position: a world hint names a tag, and OnboardingController marks the tagged instance nearest the
	character. These specs keep it that way and check that what gets marked is somewhere the player can do
	what the hint says: the plot marker nearest a fresh ruler (who stands on the spawn pad) is the ruler's own,
	its plot menu offers the House the hint names (Fit.typesFor, the menu's rule), and the server accepts it.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local WORLD = Layout.WORLD
-- the world tags a hint may target, each with a check below; a new one needs its own check first
local CHECKED = { BuildSlot = true, ObjectiveZone = true }
-- what BuildOnPlot's body names ("choose a House"; config/Onboarding.luau)
local HINT_BUILDING = "house"

local function worldTargets(): { { step: string, target: any } }
	local out = {}
	for _, flow in OnboardingConfig.flows do
		for _, step in flow.steps do
			local target = step.hint and step.hint.target
			if target ~= nil and target.kind == "world" then
				table.insert(out, { step = `{flow.id}.{step.id}`, target = target })
			end
		end
	end
	return out
end

-- the build slot nearest a point, over every plot (OnboardingController:_nearest looks at every BuildSlot)
local function nearestSlot(point: Vector3): (any, string?)
	local nearest, owner, best = nil, nil, math.huge
	for _, identity in KingdomsConfig.identities do
		for _, slot in WORLD.plots[identity.id].buildSlots do
			local d = (Vector2.new(slot.center.X, slot.center.Z) - Vector2.new(point.X, point.Z)).Magnitude
			if d < best then
				nearest, owner, best = slot, identity.id, d
			end
		end
	end
	return nearest, owner
end

describe("Onboarding hint targets (FL-0092 v2, #140 ask)", function()
	it("world hints name a checked tag and never a fixed position", function()
		local targets = worldTargets()
		expect(#targets > 0).toBe(true)
		for _, entry in targets do
			local fields = {}
			for key in entry.target do
				if key ~= "kind" and key ~= "tag" then
					table.insert(fields, key)
				end
			end
			table.sort(fields)
			expect(`{entry.step}: extra fields {table.concat(fields, ",")}`).toBe(`{entry.step}: extra fields `)
			expect(`{entry.step}: {entry.target.tag} checked {CHECKED[entry.target.tag] == true}`).toBe(
				`{entry.step}: {entry.target.tag} checked true`
			)
		end
	end)

	it("BuildOnPlot: the marker nearest a fresh ruler is their own, offers a House and the server takes it", function()
		local sim = Simulation.new({ random = Random.new(5), catalog = Catalog.default(), bounds = Layout.bounds() })
		Layout.generate(sim)
		for _, identity in KingdomsConfig.identities do
			local slot, owner = nearestSlot(WORLD.plots[identity.id].spawn.Position)
			assert(slot, `{identity.id}: a plot marker`)
			expect(`{identity.id}: nearest marker is {owner}'s`).toBe(
				`{identity.id}: nearest marker is {identity.id}'s`
			)
			local offered = table.find(Fit.typesFor(slot.size), HINT_BUILDING) ~= nil
			expect(`{slot.id} ({slot.size}) offers {HINT_BUILDING}: {offered}`).toBe(
				`{slot.id} ({slot.size}) offers {HINT_BUILDING}: true`
			)
			for _, res in { "wood", "stone", "gold", "food" } do
				sim:deposit(identity.id, res, 5000, `spec:onboarding:{identity.id}:{res}`, "spec")
			end
			local refused = {}
			for _, turn in Fit.turns(HINT_BUILDING, slot.size) do
				local ok, why = sim:canPlace(
					sim.kingdoms[identity.id],
					HINT_BUILDING,
					slot.center.X,
					slot.center.Z,
					slot.rot + turn * math.pi / 2
				)
				if not ok then
					table.insert(refused, `turn {turn}: {why}`)
				end
			end
			expect(`{slot.id}: refused {table.concat(refused, "; ")}`).toBe(`{slot.id}: refused `)
		end
	end)
end)
