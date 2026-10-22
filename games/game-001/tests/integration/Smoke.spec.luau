-- game-001 integration: a four-kingdom match with one joined player, 120 virtual seconds (FORGE-00's B22.2 smoke, written by
-- FORGE-07; adopted by FORGE-05). The server trees and the client trees boot in one MockEnv as Main.server / Main.client do,
-- a player joins, and the run must show: no thread error, no error-level log, only the one known warning, no failed controller,
-- the six KingdomHUD ScreenGuis present and enabled right after the join and at the end, and the three AI kingdoms building
-- (>= 3 buildings each) and gathering. Headless: MockEnv has no engine, so this cannot see an engine-side HUD loss.
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

local SERVER_TREES = {
	{ dir = "roblox/src/server/Services", dm = "ServerScriptService/Forge/Services" },
	{ dir = "games/game-001/src/server/Services", dm = "ServerScriptService/Game/Services" },
}
local CLIENT_TREES = {
	{ dir = "roblox/src/client/Controllers", dm = "StarterPlayer/StarterPlayerScripts/Forge/Controllers" },
	{ dir = "games/game-001/src/client/Controllers", dm = "StarterPlayer/StarterPlayerScripts/Game/Controllers" },
}
local SHARED_ROOTS = {
	{ dir = "roblox/src/shared", dm = "ReplicatedStorage/Forge" },
	{ dir = "games/game-001/src/shared", dm = "ReplicatedStorage/Game" },
}
local HUD = { "KingdomHUD", "KingdomTopbar", "KingdomMenus", "KingdomModals", "KingdomNotices", "KingdomBackdrop" }
local KNOWN_WARNINGS = { ["PlacementInput: no input events; use the placement bar buttons"] = true } -- MockEnv has no input events

local function moduleNames(dir: string): { string }
	local names = {}
	local full = T.root .. "/" .. dir
	if not fs.isDir(full) then
		return names
	end
	for _, entry in fs.readDir(full) do
		local name = string.match(entry, "^(.-)%.luau$")
		if name and not string.find(name, "%.") and fs.isFile(full .. "/" .. entry) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function definitionsIn(trees): { any }
	local definitions = {}
	for _, tree in trees do
		for _, name in moduleNames(tree.dir) do
			table.insert(definitions, Loader.validate(require(`@game/{tree.dm}/{name}`), `{tree.dir}/{name}`))
		end
	end
	return definitions
end

local function remotesByArea(): { [string]: any }
	local result = {}
	for _, root in SHARED_ROOTS do
		local full = T.root .. "/" .. root.dir
		if fs.isDir(full) then
			for _, area in fs.readDir(full) do
				if fs.isDir(`{full}/{area}`) and fs.isFile(`{full}/{area}/Remotes.luau`) then
					result[area] = require(`@game/{root.dm}/{area}/Remotes`)
				end
			end
		end
	end
	return result
end

-- The character adapter KingdomService needs outside Roblox (Boot.spec's).
local function characterAdapter(env)
	return {
		partyOf = function()
			return nil
		end,
		load = function(player)
			local character = env.newInstance("Model")
			local root = env.newInstance("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.new()
			root.Parent = character
			character.Parent = env.Workspace
			player.Character = character
			return character
		end,
		pivot = function(character, cframe)
			character.HumanoidRootPart.CFrame = cframe
		end,
		attach = function(character, accessory)
			accessory.Parent = character
		end,
		onDied = function()
			return { Disconnect = function() end }
		end,
		respawnDelay = function()
			return 5
		end,
		sit = function() end,
		seatOf = function()
			return nil
		end,
		occupant = function()
			return nil
		end,
		unseat = function() end,
	}
end

describe("game-001 headless match smoke (four kingdoms, one joined player)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector() -- Lune has no TextButton.Activated; the HUD connects it at mount
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("runs 120 virtual seconds: clean logs, no failed controller, HUD enabled, the AIs build and gather", function()
		local env = MockEnv.new({
			seed = 1,
			localPlayer = { userId = 1001, name = "Ruler" },
			sharedModules = { Remotes = remotesByArea() },
		})
		local server = Loader.load(env, definitionsIn(SERVER_TREES))
		server:get("KingdomService").adapter = characterAdapter(env)
		local playerGui = env.newInstance("PlayerGui")
		playerGui.Parent = env.Players.LocalPlayer
		local client = Loader.loadClient(env, definitionsIn(CLIENT_TREES)) -- as Main.client: failures are recorded by name

		local function expectHud(label: string)
			for _, name in HUD do
				local gui = playerGui:FindFirstChild(name)
				expect(gui ~= nil).toBe(true) -- `${label}: ${name} missing` is the failing case's context
				expect((gui :: any).Enabled).toBe(true)
			end
			expect(label ~= "").toBe(true)
		end

		env.mock:advance(3) -- the join, the kingdom assignment and the first Kingdom.GetState reply
		expectHud("after the join")
		env.mock:advance(117)
		expectHud("after 120 s")

		expect(client.failed).toEqual({})
		expect(env.mock.threadErrors).toEqual({})
		for _, entry in env.mock.logs do
			expect(entry.level ~= "error").toBe(true)
			if entry.level == "warn" then
				expect(KNOWN_WARNINGS[entry.message] == true).toBe(true)
			end
		end

		-- the three kingdoms without a ruler are run by the AI governor: 3 buildings each by now (the keep's yard comes
		-- with the kingdom), and gathered resources > 0 (measured on 22 Oct: built 3, gathered 400+ per kingdom at 120 s)
		local sim = server:get("MatchService").host.match.sim
		local ais = 0
		for _, kingdomId in sim.kingdomOrder do
			local k = sim.kingdoms[kingdomId]
			if #k.rulers == 0 then
				ais += 1
				expect(k.stats.built >= 3).toBe(true)
				local total = 0
				for _, amount in k.stats.gathered do
					total += amount
				end
				expect(total > 0).toBe(true)
			end
		end
		expect(ais).toBe(3)

		client:destroy()
		server:destroy()
	end)
end)
