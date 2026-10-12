-- Debug/MapReport: the runtime map summary Main.server logs at start (Studio smoke test S4).
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")
local Map = require("@game/ReplicatedStorage/Forge/Config/Map")
local MapReport = require("@game/ReplicatedStorage/Forge/Debug/MapReport")

local TAGS, ATTR = Map.TAGS, Map.ATTR

local function anchor(env, parent, tags: { string }, attributes: { [string]: any }?)
	local part = Instance.new("Part")
	part.Parent = parent
	for key, value in attributes or {} do
		part:SetAttribute(key, value)
	end
	for _, tag in tags do
		env.CollectionService:AddTag(part, tag)
	end
	return part
end

-- A minimal map that satisfies the contract, with options to break one rule at a time.
local function buildMap(env, options: { skipKingdom: string?, extraLobby: boolean?, noRuler: string? }?)
	local opts = options or {}
	local root = Instance.new("Folder")
	root.Name = "ForgeMap"
	root.Parent = env.Workspace
	local lobby = Instance.new("SpawnLocation")
	lobby.Parent = root
	env.CollectionService:AddTag(lobby, TAGS.LobbySpawn)
	if opts.extraLobby then
		anchor(env, root, { TAGS.LobbySpawn })
	end
	anchor(env, root, { TAGS.PlayArea })
	for _, id in Map.KINGDOM_IDS do
		if id == opts.skipKingdom then
			continue
		end
		local model = Instance.new("Model")
		model.Name = `Kingdom_{id}`
		model.Parent = root
		model:SetAttribute(ATTR.KingdomId, id)
		env.CollectionService:AddTag(model, TAGS.Kingdom)
		local k = { [ATTR.KingdomId] = id }
		anchor(env, model, { TAGS.Keep }, k)
		if opts.noRuler ~= id then
			anchor(env, model, { TAGS.RulerSpawn, TAGS.Spawn }, k)
		end
		anchor(env, model, { TAGS.Stockpile }, k)
		anchor(env, model, { TAGS.RallyPoint }, k)
		anchor(env, model, { TAGS.VillagerSpawn }, k)
		anchor(env, model, { TAGS.BuildPlot }, { [ATTR.KingdomId] = id, [ATTR.PlotId] = `{id}-Plot-1` })
		for _, kind in Map.KINGDOM_RESOURCES do
			anchor(
				env,
				model,
				{ TAGS.ResourceNode },
				{ [ATTR.KingdomId] = id, [ATTR.Resource] = kind, [ATTR.NodeId] = `{id}-{kind}-1` }
			)
		end
	end
	anchor(
		env,
		root,
		{ TAGS.ResourceNode },
		{ [ATTR.KingdomId] = Map.NEUTRAL, [ATTR.Resource] = "Gold", [ATTR.NodeId] = "Neutral-Gold-1" }
	)
	return root
end

describe("Debug/MapReport", function()
	it("reports a complete map as ready, with counts, as one info line", function()
		local env = MockEnv.new()
		buildMap(env)
		local summary = MapReport.log(env)
		expect(summary.ok).toBe(true)
		expect(summary.kingdoms).toBe(4)
		expect(summary.counts.RulerSpawn).toBe(4)
		expect(summary.counts.ResourceNode).toBe(13)
		expect(summary.counts.BuildPlot).toBe(4)
		expect(summary.problems).toEqual({})
		expect(env.mock:hasLog("info", "map ready")).toBe(true)
		expect(env.mock:hasLog("warn", "map problems")).toBe(false)
		local fields = env.mock.logs[#env.mock.logs].fields
		expect(fields.kingdoms).toBe(4)
		expect(fields.lobbySpawn).toBe(1)
	end)

	it("warns with the missing kingdom and its missing anchors", function()
		local env = MockEnv.new()
		buildMap(env, { skipKingdom = "West" })
		local summary = MapReport.log(env)
		expect(summary.ok).toBe(false)
		expect(summary.kingdoms).toBe(3)
		expect(table.find(summary.problems, "no ForgeKingdom with KingdomId West") ~= nil).toBe(true)
		expect(table.find(summary.problems, "kingdom West: 0 ForgeKeep (expected 1)") ~= nil).toBe(true)
		expect(env.mock:hasLog("warn", "map problems")).toBe(true)
		expect(env.mock:hasLog("info", "map ready")).toBe(false)
	end)

	it("flags a kingdom without a ruler spawn and a second lobby spawn", function()
		local env = MockEnv.new()
		buildMap(env, { noRuler = "East", extraLobby = true })
		local summary = MapReport.summarize(env)
		expect(summary.ok).toBe(false)
		expect(table.find(summary.problems, "kingdom East: 0 ForgeRulerSpawn (expected 1)") ~= nil).toBe(true)
		expect(table.find(summary.problems, "2 ForgeLobbySpawn (expected 1)") ~= nil).toBe(true)
		expect(#env.mock.logs).toBe(0) -- summarize never logs
	end)

	it("reports an empty Workspace (no map synced) instead of erroring", function()
		local env = MockEnv.new()
		local summary = MapReport.log(env)
		expect(summary.ok).toBe(false)
		expect(summary.kingdoms).toBe(0)
		expect(table.find(summary.problems, "0 ForgeLobbySpawn (expected 1)") ~= nil).toBe(true)
		expect(env.mock:hasLog("warn", "map problems")).toBe(true)
	end)
end)
