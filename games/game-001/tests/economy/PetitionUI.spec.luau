-- FL-0073 (e) end to end, headless: the citizen card's arena perk preview and open petition. The real
-- KingdomHudController and CitizenCardController talk through the framework RemoteService to FORGE-01 doubles
-- (doubles/CitizenDoubles for Sim.Inspect, doubles/PetitionDoubles for `role`, `petition` and Kingdom.FulfilPetition).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("./doubles/CitizenDoubles")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local PetitionDoubles = require("./doubles/PetitionDoubles")
local PetitionModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/PetitionModel")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local function find(root, name)
	if root == nil then
		return nil
	end
	if root.Name == name then
		return root
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function newWorld(opts)
	local o = opts or {}
	local remotes = { Sim = CitizenDoubles.INSPECT_ONLY.Sim }
	if not o.dark then
		remotes.Kingdom = PetitionDoubles.REMOTES.Kingdom
	end
	local world = KingdomWorld.new({
		remotes = remotes,
		services = {
			CitizenDoubles.inspectOnly,
			PetitionDoubles.service(o.keys or PetitionDoubles.KEYS, { remote = not o.dark }),
		},
		clientDefinitions = { KingdomHudDef, CitizenCardDef },
	})
	world.hud = world.client:get("KingdomHudController")
	world.card = world.client:get("CitizenCardController")
	world.petitions = world.server:get("PetitionService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function open(world, entityId)
	world.card:open(entityId)
	world:advance(0.1)
	return find(world.hud.guis.menus, "CitizenCard")
end

local function fulfilFace(card)
	local button = find(card, "Fulfil")
	return button and (button:FindFirstChild("Face") or button)
end

describe("PetitionModel (pure)", function()
	it("no role, an unknown role or no view: no perk", function()
		expect(PetitionModel.perk(nil)).toBeNil()
		expect(PetitionModel.perk({ name = "Osric Vale", loyalty = 90 })).toBeNil()
		expect(PetitionModel.perk({ name = "Osric Vale", loyalty = 90, role = "jester" })).toBeNil()
	end)

	it("below 80: 'At 80 loyalty, <name> will lend you <perk>' with SupportModel's own effect and condition", function()
		local k = PetitionModel.perk({ name = "Edda Thornbury", loyalty = 72, role = "blacksmith" })
		local offer = SupportModel.offers({ { role = "blacksmith", loyalty = 80, alive = true } }, "loyal")[1]
		expect(k.power).toBe("none")
		expect(k.headline).toBe(`At {Support.offer.pledgedLoyalty} loyalty, Edda will lend you Reforge`)
		expect(k.effect).toBe(offer.effect)
		expect(k.when).toBe(`When {offer.condition}`)
		expect(k.toGo).toBe(8)
		expect(k.next).toBeNil()
		expect(k.roleName).toBe("Blacksmith")
	end)

	it("80..94 is pledged and previews the empowered effect; 95+ is empowered", function()
		local p = PetitionModel.perk({ name = "Lise Thornbury", loyalty = 88, role = "healer" })
		expect(p.power).toBe("pledged")
		expect(p.headline).toBe("Lise stands with you: Field Remedy (Pledged)")
		local strong = SupportModel.offers({ { role = "healer", loyalty = 95, alive = true } }, "loyal")[1]
		expect(p.next).toBe(`At {Support.offer.empoweredLoyalty}: {strong.effect}`)
		expect(p.toGo).toBeNil()
		local e = PetitionModel.perk({ name = "Lise Thornbury", loyalty = 97, role = "healer" })
		expect(e.power).toBe("empowered")
		expect(e.effect).toBe(strong.effect)
		expect(e.next).toBeNil()
	end)

	it(
		"a petition: cost from the need, short entries against the treasury, the time left, Fulfil only when covered",
		function()
			local view = { petition = { id = "p1", text = "Bring stone", need = { stone = 20 }, expiresAt = 1000 } }
			local p = PetitionModel.petition(view, 700, { stone = 50 })
			expect(p.id).toBe("p1")
			expect(#p.cost).toBe(1)
			expect(p.cost[1].id).toBe("stone")
			expect(p.left).toBe("5 min left")
			expect(p.canFulfil).toBe(true)
			local short = PetitionModel.petition(view, 970, { stone = 5 })
			expect(short.short.stone).toBe(true)
			expect(short.need).toBe("Need 15 Stone")
			expect(short.left).toBe("Under a minute left")
			expect(short.canFulfil).toBe(false)
			local lapsed = PetitionModel.petition(view, 1000, { stone = 50 })
			expect(lapsed.expired).toBe(true)
			expect(lapsed.left).toBe("Lapsed")
			expect(lapsed.canFulfil).toBe(false)
		end
	)

	it("fails closed on a need it can't show, and drops a petition without id or text", function()
		local bad = PetitionModel.petition({ petition = { id = "p", text = "x", need = { gems = 3 } } }, 0, {})
		expect(bad.costUnknown).toBe(true)
		expect(bad.canFulfil).toBe(false)
		expect(PetitionModel.petition({ petition = { id = "", text = "x" } }, 0)).toBeNil()
		expect(PetitionModel.petition({ petition = { id = "p" } }, 0)).toBeNil()
		expect(PetitionModel.petition({}, 0)).toBeNil()
	end)

	it("refusal reasons are sentences, never the raw code", function()
		expect(PetitionModel.reason("insufficient")).toBe("The treasury can't cover it yet.")
		expect(PetitionModel.reason("weird_code")).toBe(PetitionModel.GENERIC)
		expect(PetitionModel.reason(nil)).toBe(PetitionModel.GENERIC)
	end)
end)

describe("Citizen card: perk preview and petition (desktop)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("a key citizen below 80 shows the perk they will lend and their petition with Fulfil", function()
		local card = open(world, 41)
		local perk = find(card, "ArenaPerk")
		expect(perk).toBeTruthy()
		expect(perk:GetAttribute("power")).toBe("none")
		expect(perk:GetAttribute("trigger")).toBe("reforge")
		expect(find(perk, "Headline").Text).toBe("At 80 loyalty, Edda will lend you Reforge")
		expect(find(perk, "ToGo").Text).toBe("8 more loyalty")
		local petition = find(card, "Petition")
		expect(petition:GetAttribute("petitionId")).toBe("p-41")
		expect(find(petition, "PetitionText").Text).toBe(Support.roles.blacksmith.petition)
		expect(find(petition, "Cost_stone").Text).toBe("20")
		expect(find(petition, "Left").Text).toBe("4 min left")
		expect(fulfilFace(card):GetAttribute("fulfil")).toBe("ready")
	end)

	it("a pledged key citizen without a petition shows the perk and the empowered preview only", function()
		local card = open(world, 43)
		local perk = find(card, "ArenaPerk")
		expect(perk:GetAttribute("power")).toBe("pledged")
		expect(find(perk, "Next")).toBeTruthy()
		expect(find(card, "Petition")).toBeNil()
	end)

	it("an ordinary citizen shows neither", function()
		local card = open(world, 44)
		expect(card).toBeTruthy()
		expect(find(card, "ArenaPerk")).toBeNil()
		expect(find(card, "Petition")).toBeNil()
	end)

	it("Fulfil spends the need, says so, and the refreshed card has no petition and more loyalty", function()
		local before = world.hud.store:balances().stone
		local card = open(world, 41)
		expect(Create.fire(fulfilFace(card), "Activated")).toBeGreaterThan(0)
		world:advance(0.2)
		expect(#world.petitions.calls).toBe(1)
		expect(world.petitions.calls[1].petitionId).toBe("p-41")
		world:advance(0.3)
		expect(world.hud.store:balances().stone).toBe(before - 20)
		expect(texts(world.hud.guis.notices)).toContain(PetitionModel.FULFILLED)
		card = find(world.hud.guis.menus, "CitizenCard")
		expect(find(card, "Petition")).toBeNil()
		expect(world.card.view.loyalty).toBe(72 + PetitionDoubles.LOYALTY_GAIN)
		expect(find(find(card, "ArenaPerk"), "ToGo").Text).toBe(`{80 - 72 - PetitionDoubles.LOYALTY_GAIN} more loyalty`)
	end)

	it("one call at a time: Fulfil shows loading and a second tap sends nothing", function()
		world.petitions.latency = 1
		local card = open(world, 41)
		world.card:fulfil()
		world:advance(0.1)
		card = find(world.hud.guis.menus, "CitizenCard")
		expect(fulfilFace(card):GetAttribute("fulfil")).toBe("loading")
		world.card:fulfil()
		world:advance(0.1)
		expect(#world.petitions.calls).toBe(1)
		world:advance(1.2)
	end)

	it("a refusal shows its reason under the button and keeps the petition", function()
		world.petitions.refuse = "expired"
		open(world, 41)
		world.card:fulfil()
		world:advance(0.3)
		local card = find(world.hud.guis.menus, "CitizenCard")
		expect(find(card, "PetitionError").Text).toBe(PetitionModel.reason("expired"))
		expect(find(card, "Petition")).toBeTruthy()
		expect(fulfilFace(card):GetAttribute("fulfil")).toBe("ready")
	end)

	it("a dropped call says the server could not be reached", function()
		world.petitions.drop = true
		open(world, 41)
		world.card:fulfil()
		world:advance(0.3)
		local card = find(world.hud.guis.menus, "CitizenCard")
		expect(find(card, "PetitionError").Text).toBe(CitizenText.unreachable())
	end)

	it("a petition the treasury can't cover: Need in red, Fulfil blocked, nothing sent", function()
		local card = open(world, 42)
		expect(find(card, "Need").Text).toContain("Need")
		expect(find(card, "Need").Text).toContain("Gold")
		expect(fulfilFace(card):GetAttribute("fulfil")).toBe("blocked")
		world.card:fulfil()
		world:advance(0.2)
		expect(#world.petitions.calls).toBe(0)
	end)

	it("a reply for the citizen before never lands on the next citizen's card", function()
		world.petitions.latency = 0.5
		world.petitions.refuse = "expired" -- a refusal that would otherwise put its reason under the button
		open(world, 41)
		world.card:fulfil()
		world:advance(0.1)
		open(world, 43)
		world:advance(0.6)
		local card = find(world.hud.guis.menus, "CitizenCard")
		expect(world.card.entityId).toBe(43)
		expect(world.card.petition.state).toBe("idle")
		expect(world.card.petition.error).toBeNil()
		expect(find(card, "PetitionError")).toBeNil()
	end)

	it("treasury pushes that don't change what the card shows leave it alone", function()
		local card = open(world, 41)
		world.treasury:deposit("crimson", "food", 5, "pet:food", "test")
		world:advance(0.1)
		expect(find(world.hud.guis.menus, "CitizenCard")).toBe(card)
	end)
end)

describe("Petition edge cases", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("dark until Kingdom.FulfilPetition is served: no petition box, no call; the perk preview still shows", function()
		local world = newWorld({ dark = true })
		expect(world.hud:hasRemote("Kingdom.FulfilPetition")).toBe(false)
		local card = open(world, 41)
		expect(find(card, "Petition")).toBeNil()
		expect(find(card, "ArenaPerk")).toBeTruthy()
		local asked = 0
		local remotes = world.hud.remotes
		local invoke = remotes.invoke
		remotes.invoke = function(self, name, ...)
			if name == "Kingdom.FulfilPetition" then
				asked += 1
			end
			return invoke(self, name, ...)
		end
		world.card:fulfil()
		world:advance(0.2)
		remotes.invoke = invoke
		expect(asked).toBe(0) -- never invoked while undeclared
		expect(#world.petitions.calls).toBe(0)
		world:destroy()
	end)

	it("phone 667 × 375: petition and perk sit in the one scrolling column with a 44 px Fulfil", function()
		local world = newWorld({ width = 667, height = 375 })
		local card = open(world, 41)
		local body = find(card, "Body")
		expect(body:IsA("ScrollingFrame")).toBe(true)
		expect(find(body, "Petition")).toBeTruthy()
		expect(find(body, "ArenaPerk")).toBeTruthy()
		expect(find(body, "Petition").LayoutOrder).toBeLessThan(find(body, "ArenaPerk").LayoutOrder)
		expect(find(body, "Petition").LayoutOrder).toBeLessThan(find(body, "Opinion").LayoutOrder) -- the action first
		expect(find(card, "Fulfil").Size.Y.Offset).toBeGreaterThan(43)
		world:destroy()
	end)
end)

-- FORGE-07 L1 / L4 on #227: the edges the first round did not pin.
describe("Petition edges (FORGE-07)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("loyalty: the power follows the raw value (79.6 is not pledged), clamped, NaN as 0", function()
		local function k(l)
			return PetitionModel.perk({ name = "Edda", loyalty = l, role = "blacksmith" })
		end
		expect(k(79.6).power).toBe("none")
		expect(k(79.6).loyalty).toBe(79)
		expect(k(79.6).toGo).toBe(1)
		expect(k(72.4).toGo).toBe(8) -- 72.4 + 7 is still short of 80 (FORGE-07 L1')
		expect(k(80).power).toBe("pledged")
		expect(k(94.9).power).toBe("pledged")
		expect(k(95).power).toBe("empowered")
		expect(k(120).power).toBe("empowered")
		expect(k(120).loyalty).toBe(100)
		expect(k(0 / 0).power).toBe("none")
		expect(k(0 / 0).toGo).toBe(80)
	end)

	it("time left: no expiresAt shows none, the minute boundary is exact", function()
		local noExpiry = PetitionModel.petition({ petition = { id = "p", text = "x" } }, 0, {})
		expect(noExpiry.left).toBeNil()
		expect(noExpiry.expired).toBe(false)
		expect(noExpiry.canFulfil).toBe(true)
		local view = { petition = { id = "p", text = "x", expiresAt = 100 } }
		expect(PetitionModel.petition(view, 40, {}).left).toBe("1 min left")
		expect(PetitionModel.petition(view, 40.1, {}).left).toBe("Under a minute left")
	end)

	it("a blocked Fulfil looks disabled, not only marked", function()
		local world = newWorld()
		local card = open(world, 42)
		expect(fulfilFace(card):GetAttribute("state")).toBe("disabled")
		expect(fulfilFace(card).Active).toBe(false)
		world:destroy()
	end)

	it("no Fulfil once the card is closed", function()
		local world = newWorld()
		open(world, 41)
		world.card:close()
		world:advance(0.1)
		world.card:fulfil()
		world:advance(0.3)
		expect(#world.petitions.calls).toBe(0)
		world:destroy()
	end)

	it("an earlier Fulfil's timer never cuts a later one short (FORGE-07 L2')", function()
		local world = newWorld()
		local limit = world.card.FULFIL_TIMEOUT_SEC
		world.petitions.latency = 2
		world.petitions.refuse = "insufficient"
		open(world, 41)
		world.card:fulfil() -- #1: refused at 2 s
		world:advance(3)
		expect(world.card.petition.state).toBe("idle")
		world.petitions.latency = limit + 20 -- #2: no answer
		world.card:fulfil()
		world:advance(limit - 3 + 0.5) -- past #1's timer, well inside #2's
		expect(world.card.petition.state).toBe("loading")
		world:advance(3)
		expect(world.card.petition.state).toBe("idle") -- #2's own timer
		world:destroy()
	end)

	it("a call with no answer gives up after FULFIL_TIMEOUT_SEC; the late answer is ignored", function()
		local world = newWorld()
		world.petitions.latency = world.card.FULFIL_TIMEOUT_SEC + 5
		open(world, 41)
		world.card:fulfil()
		world:advance(0.2)
		expect(world.card.petition.state).toBe("loading")
		world:advance(world.card.FULFIL_TIMEOUT_SEC)
		expect(world.card.petition.state).toBe("idle")
		expect(world.card.petition.error).toBe(CitizenText.unreachable())
		world:advance(6)
		expect(texts(world.hud.guis.notices)).never.toContain(PetitionModel.FULFILLED)
		expect(world.card.petition.error).toBe(CitizenText.unreachable())
		world:destroy()
	end)
end)
