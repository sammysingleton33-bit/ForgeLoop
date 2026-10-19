local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")

-- (i, value) for every argument, nil ones included: a list literal drops its nil entries from `for in`
local function each(...)
	local cases = table.pack(...)
	local i = 0
	return function()
		i += 1
		if i <= cases.n then
			return i, cases[i]
		end
		return nil
	end
end

local A, B, RIVAL, THIRD = 101, 102, 201, 301 -- A and B rule crimson; RIVAL rules azure; THIRD rules emerald

-- Three kingdoms 300 studs apart, no citizens (fast), Military installed for armies.
-- options: Diplomacy.install options (default: 10 s grace so most tests can start a war quickly).
local function setup(options: { [string]: number }?)
	local sim, crimson = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
	local azure = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
	local emerald = sim:addKingdom({ id = "emerald", name = "Third", x = 0, z = 300 })
	Military.install(sim)
	Diplomacy.install(sim, options or { graceSeconds = 10 })
	assert(sim:addRuler("crimson", A))
	assert(sim:addRuler("crimson", B))
	assert(sim:addRuler("azure", RIVAL))
	assert(sim:addRuler("emerald", THIRD))
	sim:advance(sim.diplomacy.graceSeconds)
	F.events(sim)
	return sim, crimson, azure, emerald
end

local function command(sim, userId: number, name: string, ...: any)
	return Commands.execute(sim, userId, name, ...)
end

local function errorOf(sim, userId: number, name: string, ...: any): string?
	local ok, err = command(sim, userId, name, ...)
	expect(ok).toBe(false)
	return err
end

describe("Kingdom/Diplomacy: war", function()
	it("every pair starts at Peace", function()
		local sim = setup()
		for _, pair in { { "crimson", "azure" }, { "azure", "emerald" }, { "crimson", "emerald" } } do
			expect(Diplomacy.relation(sim, pair[1], pair[2])).toBe("Peace")
			expect(sim:atWar(pair[1], pair[2])).toBe(false)
		end
	end)

	it("refuses war during the grace period (default 300 s), then allows it", function()
		local sim, crimson = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
		sim:addKingdom({ id = "azure", x = 300, z = 0 })
		Diplomacy.install(sim)
		assert(sim:addRuler("crimson", A))
		expect(sim.diplomacy.graceSeconds).toBe(300)
		expect(errorOf(sim, A, "DeclareWar", "azure")).toBe("grace_period")
		sim:advance(299.75)
		expect(errorOf(sim, A, "DeclareWar", "azure")).toBe("grace_period")
		expect(sim:atWar("crimson", "azure")).toBe(false)
		sim:advance(0.25)
		expect((command(sim, A, "DeclareWar", "azure"))).toBe(true)
		expect(crimson.alive).toBe(true)
	end)

	it("DeclareWar takes effect at once, both ways, and is announced with who declared it", function()
		local sim = setup()
		local ok, err, result = command(sim, A, "DeclareWar", "azure") -- A is crimson's senior ruler (D-054)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "azure", outcome = "declared" })
		expect(sim:atWar("crimson", "azure")).toBe(true)
		expect(sim:atWar("azure", "crimson")).toBe(true)
		expect(Diplomacy.relation(sim, "azure", "crimson")).toBe("War")
		expect(sim:atWar("crimson", "emerald")).toBe(false)
		local declared = F.events(sim, "WarDeclared")
		expect(#declared).toBe(1)
		expect(declared[1].kingdomId).toBe("crimson")
		expect(declared[1].targetId).toBe("azure")
		expect(declared[1].by).toBe(A)
	end)

	it("already_at_war for either side of an existing war", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		F.events(sim)
		expect(errorOf(sim, B, "DeclareWar", "azure")).toBe("already_at_war")
		expect(errorOf(sim, RIVAL, "DeclareWar", "crimson")).toBe("already_at_war")
		expect(F.events(sim)).toEqual({})
	end)

	it("unknown_kingdom for itself, a missing or an eliminated kingdom; invalid_args for non-string ids", function()
		local sim, _, _, emerald = setup()
		Military.eliminate(sim, emerald, nil)
		F.events(sim)
		for _, name in { "DeclareWar", "ProposePeace", "AcceptPeace" } do
			expect(errorOf(sim, A, name, "crimson")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "k9")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "emerald")).toBe("unknown_kingdom")
			-- the documented contract: a non-string or over-long id is malformed input, not a kingdom
			for _, id in each(2, nil, true, {}, string.rep("k", 17)) do
				expect(errorOf(sim, A, name, id)).toBe("invalid_args")
			end
		end
		expect(F.events(sim)).toEqual({})
		expect(sim:atWar("crimson", "azure")).toBe(false)
	end)
end)

describe("Kingdom/Diplomacy: peace", function()
	it("ProposePeace needs a war (not_at_war) and announces the proposal", function()
		local sim = setup()
		expect(errorOf(sim, RIVAL, "ProposePeace", "crimson")).toBe("not_at_war")
		expect(F.events(sim)).toEqual({})
		assert(command(sim, A, "DeclareWar", "azure"))
		local ok, err, result = command(sim, RIVAL, "ProposePeace", "crimson")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "crimson" })
		local proposed = F.events(sim, "PeaceProposed")
		expect(#proposed).toBe(1)
		expect(proposed[1].kingdomId).toBe("azure")
		expect(proposed[1].targetId).toBe("crimson")
		expect(proposed[1].by).toBe(RIVAL)
	end)

	it("AcceptPeace within proposalSeconds makes peace and armies attacking each other stand down", function()
		local sim, crimson, azure, emerald = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, A, "DeclareWar", "emerald"))
		local onK2 = Military.spawnUnit(sim, crimson, "soldier", 50, 0)
		onK2.order = { kind = "Attack", kingdomId = "azure" }
		local onK3 = Military.spawnUnit(sim, crimson, "soldier", 0, 50)
		onK3.order = { kind = "Attack", kingdomId = "emerald" }
		local theirs = Military.spawnUnit(sim, azure, "soldier", 250, 0)
		theirs.order = { kind = "Attack", kingdomId = "crimson" }
		local bystander = Military.spawnUnit(sim, emerald, "soldier", 0, 250)
		bystander.order = { kind = "Attack", kingdomId = "crimson" }
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		sim:advance(1)
		expect(onK2.alive and theirs.alive).toBe(true)
		onK2.target = { kind = "building", id = azure.keepId } -- mid-march on the enemy keep
		F.events(sim)

		local ok, err, result = command(sim, A, "AcceptPeace", "azure")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "azure" })
		expect(sim:atWar("crimson", "azure")).toBe(false)
		expect(sim:atWar("crimson", "emerald")).toBe(true) -- other wars go on
		expect(onK2.order).toEqual({ kind = "Defend" })
		expect(onK2.target).toBeNil()
		expect(theirs.order).toEqual({ kind = "Defend" })
		expect(onK3.order).toEqual({ kind = "Attack", kingdomId = "emerald" })
		expect(bystander.order).toEqual({ kind = "Attack", kingdomId = "crimson" })
		local made = F.events(sim, "PeaceMade")
		expect(#made).toBe(1)
		expect(made[1].kingdomId).toBe("crimson")
		expect(made[1].targetId).toBe("azure")
		expect(made[1].by).toBe(A)
		-- the proposal is used up
		expect(errorOf(sim, A, "AcceptPeace", "azure")).toBe("no_proposal")
		expect(crimson.alive and azure.alive and emerald.alive).toBe(true)
	end)

	it("a proposal can still be accepted exactly proposalSeconds after it was made", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		sim:advance(sim.diplomacy.proposalSeconds)
		expect((command(sim, A, "AcceptPeace", "azure"))).toBe(true)
		expect(sim:atWar("crimson", "azure")).toBe(false)
	end)

	it("an expired proposal cannot be accepted (no_proposal) and the war goes on", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		sim:advance(sim.diplomacy.proposalSeconds + 0.25)
		F.events(sim)
		expect(errorOf(sim, A, "AcceptPeace", "azure")).toBe("no_proposal")
		expect(sim:atWar("crimson", "azure")).toBe(true)
		expect(F.events(sim)).toEqual({})
		-- a fresh proposal works again
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		expect((command(sim, A, "AcceptPeace", "azure"))).toBe(true)
	end)

	it("only the kingdom that received a proposal can accept it", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, A, "DeclareWar", "emerald"))
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		F.events(sim)
		expect(errorOf(sim, RIVAL, "AcceptPeace", "crimson")).toBe("no_proposal") -- its own proposal
		expect(errorOf(sim, A, "AcceptPeace", "emerald")).toBe("no_proposal") -- emerald proposed nothing
		expect(errorOf(sim, THIRD, "AcceptPeace", "azure")).toBe("no_proposal") -- not at war, no proposal
		expect(sim:atWar("crimson", "azure")).toBe(true)
		expect((command(sim, A, "AcceptPeace", "azure"))).toBe(true)
	end)

	it("a new war declaration clears open proposals between the pair", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		Diplomacy.setRelation(sim, "crimson", "azure", "Peace") -- e.g. scenario reset
		assert(command(sim, A, "DeclareWar", "azure"))
		expect(errorOf(sim, A, "AcceptPeace", "azure")).toBe("no_proposal")
	end)

	it("peace_cooldown blocks a new war between the pair, from either side, for peaceCooldown seconds", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		assert(command(sim, RIVAL, "ProposePeace", "crimson"))
		assert(command(sim, A, "AcceptPeace", "azure"))
		F.events(sim)
		expect(errorOf(sim, A, "DeclareWar", "azure")).toBe("peace_cooldown")
		expect(errorOf(sim, RIVAL, "DeclareWar", "crimson")).toBe("peace_cooldown")
		expect((command(sim, A, "DeclareWar", "emerald"))).toBe(true) -- other pairs are unaffected
		sim:advance(sim.diplomacy.peaceCooldown - 0.25)
		expect(errorOf(sim, RIVAL, "DeclareWar", "crimson")).toBe("peace_cooldown")
		sim:advance(0.25)
		expect((command(sim, RIVAL, "DeclareWar", "crimson"))).toBe(true)
	end)
end)

describe("Kingdom/Diplomacy: setup helpers", function()
	it("install takes options, installs once and registers the three commands", function()
		local sim = setup({ graceSeconds = 1, proposalSeconds = 5, peaceCooldown = 7 })
		expect(sim.diplomacy.graceSeconds).toBe(1)
		expect(sim.diplomacy.proposalSeconds).toBe(5)
		expect(sim.diplomacy.peaceCooldown).toBe(7)
		expect(function()
			Diplomacy.install(sim)
		end).toThrow("already installed")
		local names = Commands.namesFor(sim)
		for _, name in { "DeclareWar", "ProposePeace", "AcceptPeace" } do
			expect(table.find(names, name)).toBeTruthy()
		end
	end)

	it("setRelation sets a pair directly (no events) and rejects anything but Peace or War", function()
		local sim = setup()
		Diplomacy.setRelation(sim, "azure", "crimson", "War")
		expect(sim:atWar("crimson", "azure")).toBe(true)
		expect(F.events(sim)).toEqual({})
		expect(function()
			Diplomacy.setRelation(sim, "crimson", "azure", "Truce")
		end).toThrow("Peace or War")
		expect(Diplomacy.relation(sim, "crimson", "azure")).toBe("War")
	end)

	it("an eliminated kingdom's wars end", function()
		local sim, _, azure = setup()
		assert(command(sim, A, "DeclareWar", "azure"))
		Military.eliminate(sim, azure, "crimson")
		expect(Diplomacy.relation(sim, "crimson", "azure")).toBe("Peace")
		expect(errorOf(sim, A, "DeclareWar", "azure")).toBe("unknown_kingdom")
	end)
end)
