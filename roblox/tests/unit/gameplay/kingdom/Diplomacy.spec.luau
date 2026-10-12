local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Diplomacy")
local Military = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Military")

local A, B, RIVAL, THIRD = 101, 102, 201, 301 -- A and B rule k1; RIVAL rules k2; THIRD rules k3

-- Three kingdoms 300 studs apart, no citizens (fast), Military installed for armies.
-- options: Diplomacy.install options (default: 10 s grace so most tests can start a war quickly).
local function setup(options: { [string]: number }?)
	local sim, k1 = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
	local k2 = sim:addKingdom({ id = "k2", name = "Rival", x = 300, z = 0 })
	local k3 = sim:addKingdom({ id = "k3", name = "Third", x = 0, z = 300 })
	Military.install(sim)
	Diplomacy.install(sim, options or { graceSeconds = 10 })
	assert(sim:addRuler("k1", A))
	assert(sim:addRuler("k1", B))
	assert(sim:addRuler("k2", RIVAL))
	assert(sim:addRuler("k3", THIRD))
	sim:advance(sim.diplomacy.graceSeconds)
	F.events(sim)
	return sim, k1, k2, k3
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
		for _, pair in { { "k1", "k2" }, { "k2", "k3" }, { "k1", "k3" } } do
			expect(Diplomacy.relation(sim, pair[1], pair[2])).toBe("Peace")
			expect(sim:atWar(pair[1], pair[2])).toBe(false)
		end
	end)

	it("refuses war during the grace period (default 300 s), then allows it", function()
		local sim, k1 = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
		sim:addKingdom({ id = "k2", x = 300, z = 0 })
		Diplomacy.install(sim)
		assert(sim:addRuler("k1", A))
		expect(sim.diplomacy.graceSeconds).toBe(300)
		expect(errorOf(sim, A, "DeclareWar", "k2")).toBe("grace_period")
		sim:advance(299.75)
		expect(errorOf(sim, A, "DeclareWar", "k2")).toBe("grace_period")
		expect(sim:atWar("k1", "k2")).toBe(false)
		sim:advance(0.25)
		expect((command(sim, A, "DeclareWar", "k2"))).toBe(true)
		expect(k1.alive).toBe(true)
	end)

	it("DeclareWar takes effect at once, both ways, and is announced with who declared it", function()
		local sim = setup()
		local ok, err, result = command(sim, B, "DeclareWar", "k2")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "k2" })
		expect(sim:atWar("k1", "k2")).toBe(true)
		expect(sim:atWar("k2", "k1")).toBe(true)
		expect(Diplomacy.relation(sim, "k2", "k1")).toBe("War")
		expect(sim:atWar("k1", "k3")).toBe(false)
		local declared = F.events(sim, "WarDeclared")
		expect(#declared).toBe(1)
		expect(declared[1].kingdomId).toBe("k1")
		expect(declared[1].targetId).toBe("k2")
		expect(declared[1].by).toBe(B)
	end)

	it("already_at_war for either side of an existing war", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		F.events(sim)
		expect(errorOf(sim, B, "DeclareWar", "k2")).toBe("already_at_war")
		expect(errorOf(sim, RIVAL, "DeclareWar", "k1")).toBe("already_at_war")
		expect(F.events(sim)).toEqual({})
	end)

	it("unknown_kingdom for itself, a missing or an eliminated kingdom; invalid_args for non-string ids", function()
		local sim, _, _, k3 = setup()
		Military.eliminate(sim, k3, nil)
		F.events(sim)
		for _, name in { "DeclareWar", "ProposePeace", "AcceptPeace" } do
			expect(errorOf(sim, A, name, "k1")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "k9")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "")).toBe("unknown_kingdom")
			expect(errorOf(sim, A, name, "k3")).toBe("unknown_kingdom")
			-- the documented contract: a non-string or over-long id is malformed input, not a kingdom
			for _, id in { 2, nil, true, {}, string.rep("k", 17) } do
				expect(errorOf(sim, A, name, id)).toBe("invalid_args")
			end
		end
		expect(F.events(sim)).toEqual({})
		expect(sim:atWar("k1", "k2")).toBe(false)
	end)
end)

describe("Kingdom/Diplomacy: peace", function()
	it("ProposePeace needs a war (not_at_war) and announces the proposal", function()
		local sim = setup()
		expect(errorOf(sim, RIVAL, "ProposePeace", "k1")).toBe("not_at_war")
		expect(F.events(sim)).toEqual({})
		assert(command(sim, A, "DeclareWar", "k2"))
		local ok, err, result = command(sim, RIVAL, "ProposePeace", "k1")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "k1" })
		local proposed = F.events(sim, "PeaceProposed")
		expect(#proposed).toBe(1)
		expect(proposed[1].kingdomId).toBe("k2")
		expect(proposed[1].targetId).toBe("k1")
		expect(proposed[1].by).toBe(RIVAL)
	end)

	it("AcceptPeace within proposalSeconds makes peace and armies attacking each other stand down", function()
		local sim, k1, k2, k3 = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, A, "DeclareWar", "k3"))
		local onK2 = Military.spawnUnit(sim, k1, "Militia", 50, 0)
		onK2.order = { kind = "Attack", kingdomId = "k2" }
		onK2.targetId = "b9"
		local onK3 = Military.spawnUnit(sim, k1, "Militia", 0, 50)
		onK3.order = { kind = "Attack", kingdomId = "k3" }
		local theirs = Military.spawnUnit(sim, k2, "Militia", 250, 0)
		theirs.order = { kind = "Attack", kingdomId = "k1" }
		local bystander = Military.spawnUnit(sim, k3, "Militia", 0, 250)
		bystander.order = { kind = "Attack", kingdomId = "k1" }
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		sim:advance(1)
		expect(onK2.alive and theirs.alive).toBe(true)
		F.events(sim)

		local ok, err, result = command(sim, B, "AcceptPeace", "k2")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ targetId = "k2" })
		expect(sim:atWar("k1", "k2")).toBe(false)
		expect(sim:atWar("k1", "k3")).toBe(true) -- other wars go on
		expect(onK2.order).toEqual({ kind = "Defend" })
		expect(onK2.targetId).toBeNil()
		expect(theirs.order).toEqual({ kind = "Defend" })
		expect(onK3.order).toEqual({ kind = "Attack", kingdomId = "k3" })
		expect(bystander.order).toEqual({ kind = "Attack", kingdomId = "k1" })
		local made = F.events(sim, "PeaceMade")
		expect(#made).toBe(1)
		expect(made[1].kingdomId).toBe("k1")
		expect(made[1].targetId).toBe("k2")
		expect(made[1].by).toBe(B)
		-- the proposal is used up
		expect(errorOf(sim, A, "AcceptPeace", "k2")).toBe("no_proposal")
		expect(k1.alive and k2.alive and k3.alive).toBe(true)
	end)

	it("a proposal can still be accepted exactly proposalSeconds after it was made", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		sim:advance(sim.diplomacy.proposalSeconds)
		expect((command(sim, A, "AcceptPeace", "k2"))).toBe(true)
		expect(sim:atWar("k1", "k2")).toBe(false)
	end)

	it("an expired proposal cannot be accepted (no_proposal) and the war goes on", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		sim:advance(sim.diplomacy.proposalSeconds + 0.25)
		F.events(sim)
		expect(errorOf(sim, A, "AcceptPeace", "k2")).toBe("no_proposal")
		expect(sim:atWar("k1", "k2")).toBe(true)
		expect(F.events(sim)).toEqual({})
		-- a fresh proposal works again
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		expect((command(sim, A, "AcceptPeace", "k2"))).toBe(true)
	end)

	it("only the kingdom that received a proposal can accept it", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, A, "DeclareWar", "k3"))
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		F.events(sim)
		expect(errorOf(sim, RIVAL, "AcceptPeace", "k1")).toBe("no_proposal") -- its own proposal
		expect(errorOf(sim, A, "AcceptPeace", "k3")).toBe("no_proposal") -- k3 proposed nothing
		expect(errorOf(sim, THIRD, "AcceptPeace", "k2")).toBe("no_proposal") -- not at war, no proposal
		expect(sim:atWar("k1", "k2")).toBe(true)
		expect((command(sim, A, "AcceptPeace", "k2"))).toBe(true)
	end)

	it("a new war declaration clears open proposals between the pair", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		Diplomacy.setRelation(sim, "k1", "k2", "Peace") -- e.g. scenario reset
		assert(command(sim, A, "DeclareWar", "k2"))
		expect(errorOf(sim, A, "AcceptPeace", "k2")).toBe("no_proposal")
	end)

	it("peace_cooldown blocks a new war between the pair, from either side, for peaceCooldown seconds", function()
		local sim = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		assert(command(sim, RIVAL, "ProposePeace", "k1"))
		assert(command(sim, A, "AcceptPeace", "k2"))
		F.events(sim)
		expect(errorOf(sim, A, "DeclareWar", "k2")).toBe("peace_cooldown")
		expect(errorOf(sim, RIVAL, "DeclareWar", "k1")).toBe("peace_cooldown")
		expect((command(sim, A, "DeclareWar", "k3"))).toBe(true) -- other pairs are unaffected
		sim:advance(sim.diplomacy.peaceCooldown - 0.25)
		expect(errorOf(sim, RIVAL, "DeclareWar", "k1")).toBe("peace_cooldown")
		sim:advance(0.25)
		expect((command(sim, RIVAL, "DeclareWar", "k1"))).toBe(true)
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
		Diplomacy.setRelation(sim, "k2", "k1", "War")
		expect(sim:atWar("k1", "k2")).toBe(true)
		expect(F.events(sim)).toEqual({})
		expect(function()
			Diplomacy.setRelation(sim, "k1", "k2", "Truce")
		end).toThrow("Peace or War")
		expect(Diplomacy.relation(sim, "k1", "k2")).toBe("War")
	end)

	it("an eliminated kingdom's wars end", function()
		local sim, _, k2 = setup()
		assert(command(sim, A, "DeclareWar", "k2"))
		Military.eliminate(sim, k2, "k1")
		expect(Diplomacy.relation(sim, "k1", "k2")).toBe("Peace")
		expect(errorOf(sim, A, "DeclareWar", "k2")).toBe("unknown_kingdom")
	end)
end)
