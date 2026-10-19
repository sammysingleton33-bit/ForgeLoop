-- FL-0129 war and peace (Operation Crownfall, D-053 (2)): UI/DiplomacyModel's rows, and the Kingdom panel's
-- Rivals tab on the real KingdomHudController over a diplomacy server double (doubles/DiplomacyDoubles,
-- the contract proposed to FORGE-01): declare (with a confirm step), propose, accept, refusals in words,
-- the rail bubble and the notice for an offer, dormant without the remote.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DiplomacyDoubles = require("./doubles/DiplomacyDoubles")
local DiplomacyModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/DiplomacyModel")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Text = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Text")

local function find(root, name)
	if root == nil then
		return nil
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
	for _, d in if root then root:GetDescendants() else {} do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

-- A store stand-in for the pure model.
local function store(kingdoms, mine)
	local byId = {}
	for _, k in kingdoms do
		byId[k.id] = k
	end
	return {
		mine = function()
			return byId[mine]
		end,
		kingdoms = function()
			return kingdoms
		end,
	}
end

local KINGDOMS = {
	{ id = "crimson", name = "Emberhold", crownPoints = 10, alive = true },
	{ id = "azure", name = "Frostmere", crownPoints = 30, alive = true },
	{ id = "emerald", name = "Greenvale", crownPoints = 20, alive = true },
	{ id = "gold", name = "Sunreach", crownPoints = 0, alive = false },
}

local function rowOf(view, id)
	for _, r in view.rows do
		if r.id == id then
			return r
		end
	end
	return nil
end

local function action(row, id)
	for _, a in row.actions do
		if a.id == id then
			return a
		end
	end
	return nil
end

describe("UI/DiplomacyModel (FL-0129)", function()
	it("one row per rival by rank: relation, score, the actions the server would allow", function()
		local view = DiplomacyModel.view(store(KINGDOMS, "crimson"), nil, "Conflict", 1000)
		expect(#view.rows).toBe(3)
		expect(view.rows[1].id).toBe("azure") -- by Crown Points
		local azure = view.rows[1]
		expect(azure.relation).toBe("peace")
		expect(azure.rank).toBe(1)
		local declare = action(azure, "declareWar")
		expect(declare.enabled).toBe(true)
		expect(declare.variant).toBe("danger")
		local gold = rowOf(view, "gold")
		expect(gold.relation).toBe("fallen")
		expect(#gold.actions).toBe(0)
		expect(view.incoming).toBe(0)
	end)

	it("war is closed before Conflict, during grace and in a truce, each with its reason", function()
		local early = rowOf(DiplomacyModel.view(store(KINGDOMS, "crimson"), nil, "Expansion", 1000), "azure")
		expect(action(early, "declareWar").enabled).toBe(false)
		expect(action(early, "declareWar").reason).toBe("War opens in Conflict")
		local grace =
			rowOf(DiplomacyModel.view(store(KINGDOMS, "crimson"), { graceEndsAt = 1090 }, "Conflict", 1000), "azure")
		expect(action(grace, "declareWar").reason).toBe("No war for 1:30")
		local truce = rowOf(
			DiplomacyModel.view(
				store(KINGDOMS, "crimson"),
				{ cooldowns = { { a = "azure", b = "crimson", untilAt = 1080 } } },
				"Conflict",
				1000
			),
			"azure"
		)
		expect(truce.relation).toBe("truce")
		expect(truce.note).toBe("Truce · 1:20 left")
		expect(action(truce, "declareWar").reason).toBe("Truce for 1:20")
		-- an expired truce no longer counts
		local over = rowOf(
			DiplomacyModel.view(
				store(KINGDOMS, "crimson"),
				{ cooldowns = { { a = "azure", b = "crimson", untilAt = 990 } } },
				"Conflict",
				1000
			),
			"azure"
		)
		expect(over.relation).toBe("peace")
	end)

	it("at war: propose peace; their open offer adds Accept and counts as incoming; mine waits", function()
		local diplomacy = {
			relations = {
				{ a = "azure", b = "crimson", relation = "War" },
				{ a = "crimson", b = "emerald", relation = "War" },
			},
			proposals = {
				{ from = "azure", to = "crimson", expiresAt = 1042 },
				{ from = "crimson", to = "emerald", expiresAt = 1030 },
			},
		}
		local view = DiplomacyModel.view(store(KINGDOMS, "crimson"), diplomacy, "Conflict", 1000)
		local azure = rowOf(view, "azure")
		expect(azure.relation).toBe("war")
		expect(azure.note).toBe("Proposes peace · 0:42")
		expect(azure.actions[1].id).toBe("acceptPeace")
		expect(azure.actions[1].variant).toBe("primary")
		expect(action(azure, "proposePeace").variant).toBe("secondary")
		local emerald = rowOf(view, "emerald")
		expect(action(emerald, "proposePeace").enabled).toBe(false)
		expect(action(emerald, "proposePeace").reason).toBe("Offer sent · 0:30")
		expect(action(emerald, "acceptPeace")).toBeNil()
		expect(view.incoming).toBe(1)
		-- expired offers are gone
		local later = DiplomacyModel.view(store(KINGDOMS, "crimson"), diplomacy, "Conflict", 1050)
		expect(later.incoming).toBe(0)
		expect(action(rowOf(later, "emerald"), "proposePeace").enabled).toBe(true)
	end)

	it("D-054: a co-ruler asks the senior ruler for war and cannot accept peace; a new ruler waits", function()
		local war = {
			relations = { { a = "azure", b = "crimson", relation = "War" } },
			proposals = { { from = "azure", to = "crimson", expiresAt = 1042 } },
		}
		local me = {
			userId = 1,
			nameOf = function(id)
				return if id == 2 then "Mira" else nil
			end,
		}
		-- the senior ruler is someone else: Declare war becomes an ask, Accept is theirs
		war.seniors = { crimson = 2, azure = 1 } -- azure's senior is not mine
		local view = DiplomacyModel.view(store(KINGDOMS, "crimson"), war, "Conflict", 1000, me)
		expect(view.senior).toBe("Mira")
		local declare = action(rowOf(view, "emerald"), "declareWar")
		expect(declare.label).toBe("Ask Mira to declare war")
		expect(declare.ask).toBe(true)
		expect(declare.enabled).toBe(true)
		local accept = action(rowOf(view, "azure"), "acceptPeace")
		expect(accept.enabled).toBe(false)
		expect(accept.reason).toBe("Mira decides")
		expect(action(rowOf(view, "azure"), "proposePeace").enabled).toBe(true) -- any ruler may propose
		expect(view.incoming).toBe(1) -- still an offer to my kingdom
		-- I am the senior ruler: everything is mine
		war.seniors = { crimson = 1 }
		view = DiplomacyModel.view(store(KINGDOMS, "crimson"), war, "Conflict", 1000, me)
		expect(view.senior).toBeNil()
		expect(action(rowOf(view, "emerald"), "declareWar").label).toBe("Declare war")
		expect(action(rowOf(view, "azure"), "acceptPeace").enabled).toBe(true)
		-- newly seated: no war, no accepting peace, proposing is fine
		war.lockedUntil = 1075
		view = DiplomacyModel.view(store(KINGDOMS, "crimson"), war, "Conflict", 1000, me)
		expect(action(rowOf(view, "emerald"), "declareWar").reason).toBe("New ruler · 1:15")
		expect(action(rowOf(view, "azure"), "acceptPeace").reason).toBe("New ruler · 1:15")
		expect(action(rowOf(view, "azure"), "proposePeace").enabled).toBe(true)
		view = DiplomacyModel.view(store(KINGDOMS, "crimson"), war, "Conflict", 1080, me)
		expect(action(rowOf(view, "emerald"), "declareWar").enabled).toBe(true)
	end)

	it(
		"a fallen kingdom and a finished match make no war or peace: every button off, with why (FORGE-07 L1)",
		function()
			local war = { relations = { { a = "azure", b = "crimson", relation = "War" } } }
			local fallen = table.clone(KINGDOMS)
			fallen[1] = { id = "crimson", name = "Emberhold", crownPoints = 10, alive = false }
			local view = DiplomacyModel.view(store(fallen, "crimson"), war, "Conflict", 1000)
			for _, row in view.rows do
				for _, a in row.actions do
					expect(a.enabled).toBe(false)
					expect(a.reason).toBe("Your kingdom has fallen")
				end
			end
			view = DiplomacyModel.view(store(KINGDOMS, "crimson"), war, "Results", 1000)
			expect(action(rowOf(view, "azure"), "proposePeace").reason).toBe("The match is over")
			expect(action(rowOf(view, "emerald"), "declareWar").enabled).toBe(false)
		end
	)

	it("every diplomacy refusal code reads in words, none as the generic fallback", function()
		local generic = Text.reason("not_a_real_code")
		for _, code in
			{
				"unknown_kingdom",
				"grace_period",
				"already_at_war",
				"peace_cooldown",
				"not_at_war",
				"no_proposal",
				"not_senior",
				"newcomer_lock",
			}
		do
			expect(Text.reason(code)).never.toBe(generic)
		end
	end)
end)

describe("The Rivals tab (FL-0129)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	local function newWorld(opts)
		local o = opts or {}
		local w = KingdomWorld.new({
			clientDefinitions = { KingdomHudDef },
			remotes = if o.noRemote then nil else DiplomacyDoubles.remotes(nil),
			services = if o.noRemote then nil else { DiplomacyDoubles.service },
		})
		w.hud = w.client:get("KingdomHudController")
		w.diplomacy = if o.noRemote then nil else w.server:get("DiplomacyService")
		w.hud:setViewport(o.width or 1920, o.height or 1022)
		w.match:setPhase(o.phase or "Conflict", w.env.serverTimeNow() + 600)
		w:advance(0.6)
		return w
	end

	local function openRivals(w)
		w.hud:setMenu("kingdom")
		w.hud:panelTab("rivals")
		w:advance(0.1)
		return find(w.hud.guis.menus, "Rivals")
	end

	it("declare war asks first, then the server makes it war; the row turns to war with Propose peace", function()
		world = newWorld()
		local list = openRivals(world)
		expect(list).toBeTruthy()
		local azure = find(list, "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("peace")
		tap(find(azure, "Action_declareWar"))
		world:advance(0.1)
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		expect(texts(azure)).toContain("Declare war on")
		expect(#world.diplomacy.calls).toBe(0) -- not yet
		tap(find(azure, "Action_confirm"))
		world:advance(0.3)
		expect(world.diplomacy.calls[1].action).toBe("declareWar")
		expect(world.diplomacy.calls[1].target).toBe("azure")
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("war")
		expect(find(azure, "Action_proposePeace")).toBeTruthy()
		expect(texts(world.hud.guis.notices)).toContain("War declared on")
		-- Cancel leaves peace alone
		local emerald = find(find(world.hud.guis.menus, "Rivals"), "Rival_emerald")
		tap(find(emerald, "Action_declareWar"))
		world:advance(0.1)
		tap(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_emerald"), "Action_cancel"))
		world:advance(0.1)
		expect(#world.diplomacy.calls).toBe(1)
		expect(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_emerald"), "Action_declareWar")).toBeTruthy()
	end)

	it("an offer of peace: a notice once, the Kingdom rail bubble, Accept makes peace and starts a truce", function()
		world = newWorld()
		world.diplomacy:setWar("crimson", "azure")
		world:advance(0.2)
		world.diplomacy:propose("azure", "crimson")
		world:advance(0.3)
		expect(texts(world.hud.guis.notices)).toContain("proposes peace")
		local badge = find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge")
		expect(badge).toBeTruthy()
		expect(badge.Text).toBe("1")
		local list = openRivals(world)
		local azure = find(list, "Rival_azure")
		expect(texts(azure)).toContain("Proposes peace")
		tap(find(azure, "Action_acceptPeace"))
		world:advance(0.3)
		expect(world.diplomacy.calls[1].action).toBe("acceptPeace")
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("truce")
		expect(find(azure, "Action_declareWar"):GetAttribute("enabled")).toBe(false)
		expect(find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge")).toBeNil()
	end)

	it("a refusal is said in words and changes nothing; before Conflict the button explains itself", function()
		world = newWorld({ phase = "Expansion" })
		local list = openRivals(world)
		local azure = find(list, "Rival_azure")
		expect(find(azure, "Action_declareWar"):GetAttribute("enabled")).toBe(false)
		expect(texts(azure)).toContain("War opens in Conflict")
		expect(azure:FindFirstChild("Reason")).toBeTruthy() -- its own line, not squeezed beside the button
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 600)
		world:advance(0.6)
		world.diplomacy.refuse = "grace_period"
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		tap(find(azure, "Action_declareWar"))
		world:advance(0.1)
		tap(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"), "Action_confirm"))
		world:advance(0.3)
		expect(texts(world.hud.guis.notices)).toContain(Text.reason("grace_period"))
		expect(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"), "Relation"):GetAttribute("relation")).toBe(
			"peace"
		)
	end)

	it("countdowns tick in place (no rebuild); phone 667 × 375 keeps every row and button", function()
		world = newWorld({ width = 667, height = 375 })
		expect(world.hud:metrics().breakpoint).toBe("phone")
		world.diplomacy:setWar("crimson", "azure")
		world.diplomacy:propose("azure", "crimson")
		world:advance(0.3)
		local list = openRivals(world)
		local note = find(find(list, "Rival_azure"), "Note")
		local before = note.Text
		world:advance(2)
		expect(find(world.hud.guis.menus, "Rivals")).toBe(list) -- same instance: patched, not rebuilt
		expect(note.Text).never.toBe(before)
		for _, id in { "azure", "emerald", "gold" } do
			expect(find(list, "Rival_" .. id)).toBeTruthy()
		end
		local azure = find(list, "Rival_azure")
		-- both offers fit the 260 px drawer: each button fills a half-width slot, not a fixed 120+ px
		for _, id in { "acceptPeace", "proposePeace" } do
			local slot = find(azure, "Slot_" .. id)
			expect(slot).toBeTruthy()
			expect(slot.Size.X.Scale).toBe(0.5)
			expect(find(slot, "Action_" .. id)).toBeTruthy()
		end
		expect(texts(find(azure, "Head"))).toContain("pts") -- "Crown Points" would truncate beside the chip
		expect(texts(find(azure, "Head"))).never.toContain("Crown Points")
		-- four tabs and Close: icons only on the phone header (the selected one keeps its underline)
		local tab = find(world.hud.guis.menus, "Tab_rivals")
		expect(tab:GetAttribute("selected")).toBe(true)
		expect(texts(tab)).never.toContain("Rivals")
		-- D-054: a co-ruler's longer "Ask Mira to declare war" takes the whole row when it is alone
		world.diplomacy:setSenior(2)
		world:advance(0.3)
		local slot = find(find(find(world.hud.guis.menus, "Rivals"), "Rival_emerald"), "Slot_declareWar")
		expect(slot.Size.X.Scale).toBe(1)
		expect(texts(slot)).toContain("Ask Mira to declare war")
	end)

	it("D-054: a co-ruler's Declare war is an ask to the senior ruler; it changes nothing yet", function()
		world = newWorld()
		world.diplomacy:setSenior(2) -- Mira, the second ruler, was seated first
		world:advance(0.2)
		local azure = find(openRivals(world), "Rival_azure")
		tap(find(azure, "Action_declareWar"))
		world:advance(0.1)
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		expect(texts(azure)).toContain("Ask Mira to declare war on Frostmere?")
		tap(find(azure, "Action_confirm"))
		world:advance(0.3)
		expect(#world.diplomacy.asks).toBe(1)
		expect(world.diplomacy.asks[1].target).toBe("azure")
		expect(texts(world.hud.guis.notices)).toContain("Asked your senior ruler for war on Frostmere")
		azure = find(find(world.hud.guis.menus, "Rivals"), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("peace")
		-- the open ask stays on the row (diplomacy.asks) until answered or expired, for the asker too
		expect(texts(azure)).toContain("You asked for war · 1:00")
		world:advance(DiplomacyDoubles.ASK_SEC + 1)
		expect(texts(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"))).never.toContain("asked for war")
	end)

	it("the senior ruler sees an open ask on the rival's row and in the Kingdom bubble until it runs out", function()
		world = newWorld()
		world.diplomacy:setSenior(1) -- I decide
		world.diplomacy:askFrom(2, "Mira", "azure", 1)
		world:advance(0.3)
		local azure = find(openRivals(world), "Rival_azure")
		expect(find(azure, "Ask").Text).toBe("Mira asks for war · 1:00")
		expect(find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge").Text).toBe("1")
		local line = find(azure, "Ask")
		world:advance(2)
		expect(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"), "Ask")).toBe(line) -- patched, not rebuilt
		expect(line.Text).toBe("Mira asks for war · 0:58")
		world:advance(DiplomacyDoubles.ASK_SEC + 1)
		expect(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"), "Ask")).toBeNil()
		expect(find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge")).toBeNil()
	end)

	it("the war toast follows the server's answer, not the panel's copy of who is senior (FORGE-07 M1)", function()
		-- the panel thinks Mira is senior, but seniority has moved to me on the server (not pushed yet)
		world = newWorld()
		world.diplomacy:setSenior(2)
		world:advance(0.2)
		world.diplomacy.state.seniors.crimson = 1
		local azure = find(openRivals(world), "Rival_azure")
		tap(find(azure, "Action_declareWar"))
		world:advance(0.1)
		tap(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_azure"), "Action_confirm"))
		world:advance(0.3)
		expect(#world.diplomacy.asks).toBe(0)
		expect(texts(world.hud.guis.notices)).toContain("War declared on Frostmere")
		expect(texts(world.hud.guis.notices)).never.toContain("Asked")
		world:destroy()
		-- the panel thinks I decide, but the server only asks the senior ruler
		world = newWorld()
		world.diplomacy.state.seniors.crimson = 2
		tap(find(find(openRivals(world), "Rival_emerald"), "Action_declareWar"))
		world:advance(0.1)
		tap(find(find(find(world.hud.guis.menus, "Rivals"), "Rival_emerald"), "Action_confirm"))
		world:advance(0.3)
		expect(#world.diplomacy.asks).toBe(1)
		expect(texts(world.hud.guis.notices)).toContain("Asked your senior ruler for war on")
		expect(texts(world.hud.guis.notices)).never.toContain("War declared")
	end)

	it("an offer that runs out takes the Kingdom bubble with it, without a push (FORGE-07 L2)", function()
		world = newWorld()
		world.diplomacy:setWar("crimson", "azure")
		world.diplomacy:propose("azure", "crimson")
		world:advance(0.3)
		expect(find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge")).toBeTruthy()
		world:advance(DiplomacyDoubles.PROPOSAL_SEC + 2)
		expect(find(find(world.hud.guis.hud, "Menu_kingdom"), "Badge")).toBeNil()
	end)

	it("a Kingdom.State without diplomacy clears last match's wars (FORGE-07 L3)", function()
		world = newWorld()
		world.diplomacy:setWar("crimson", "azure")
		world:advance(0.3)
		expect(world.hud.store:diplomacy()).toBeTruthy()
		world.kingdoms.diplomacy = nil
		world.kingdoms:publish()
		world:advance(0.3)
		expect(world.hud.store:diplomacy()).toBeNil()
		local azure = find(openRivals(world), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("peace")
	end)

	it("the senior ruler hears a co-ruler's ask for war, once, with where to answer (Kingdom.WarAsk)", function()
		world = newWorld()
		world.diplomacy:setSenior(1) -- I am senior
		world:advance(0.2)
		world.diplomacy:askFrom(2, "Mira", "azure", 1)
		world:advance(0.2)
		expect(texts(world.hud.guis.notices)).toContain("Mira asks for war on Frostmere")
		expect(texts(world.hud.guis.notices)).toContain("Rivals to decide")
		-- an unknown kingdom says nothing
		world.diplomacy:askFrom(2, "Mira", "nowhere", 1)
		world:advance(0.2)
		expect(texts(world.hud.guis.notices)).never.toContain("nowhere")
	end)

	it("without the server's diplomacy remote there is no Rivals tab (dormant on today's main)", function()
		world = newWorld({ noRemote = true })
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		expect(find(world.hud.guis.menus, "Tab_rivals")).toBeNil()
		world.hud:panelTab("rivals")
		world:advance(0.1)
		expect(find(world.hud.guis.menus, "Rivals")).toBeNil()
	end)
end)
