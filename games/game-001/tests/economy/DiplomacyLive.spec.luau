-- FL-0129 × FORGE-01's D-054 PR 2 (#195): the real KingdomHudController's Rivals tab against the REAL
-- server (RemoteService, MatchService, KingdomService with MatchHost and Sim/Diplomacy + Authority),
-- not DiplomacyDoubles. One MockEnv carries the server and the local player's client, as KingdomWorld does.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local TICK = MatchConfig.tickSeconds
local WAR = { Lobby = 2, Founding = 3, Expansion = 3, Conflict = 300, Endgame = 300, Results = 2 }

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
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

local function adapter(env)
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

local booted = {}

-- The local player (client) is `me`; userIds 1..5 are seated in the Lobby in order (1 and 5 in crimson).
local function boot(me)
	local saved = MatchConfig.mode
	MatchConfig.mode = "match"
	local others = {}
	local env = MockEnv.new({
		seed = 5,
		localPlayer = { userId = me, name = `Ruler{me}` },
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Treasury = TreasuryRemotes } },
	})
	local pacing = {
		name = "PacingService",
		new = function()
			return {
				phaseDurations = function()
					return table.clone(WAR)
				end,
			}
		end,
	}
	local server = Loader.load(env, { RemoteServiceDef, MatchServiceDef, KingdomServiceDef, pacing })
	MatchConfig.mode = saved
	server:get("KingdomService").adapter = adapter(env)
	for userId = 1, 5 do
		if userId ~= me then
			others[userId] =
				env.mock.players:add({ userId = userId, name = `Ruler{userId}`, displayName = `Dis{userId}` })
		end
	end
	local playerGui = env.newInstance("PlayerGui")
	playerGui.Parent = env.Players.LocalPlayer
	local client = Loader.load(env, { KingdomHudDef })
	local hud = client:get("KingdomHudController")
	hud:setViewport(1920, 1022)
	table.insert(booted, { server = server, client = client })
	env.mock:advance(3 + 6 + 2) -- Lobby, Founding, Expansion: Conflict, past the war grace
	return env, server, hud, others
end

local function rivals(hud)
	hud:setMenu("kingdom")
	hud:panelTab("rivals")
	return find(hud.guis.menus, "Rivals")
end

describe("Rivals against FORGE-01's real D-054 server (#195)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		for _, b in booted do
			b.client:destroy()
			b.server:destroy()
		end
		booted = {}
		Create.setConnector(previous)
	end)

	it("the senior ruler declares war from the Rivals tab: the server makes it war and the row turns red", function()
		local env, server, hud = boot(1)
		expect(server:get("MatchService"):getPhase()).toBe("Conflict")
		env.mock:advance(TICK * 2)
		local list = rivals(hud)
		expect(list).toBeTruthy()
		local azure = find(list, "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("peace")
		expect(find(azure, "Action_declareWar"):GetAttribute("enabled")).toBe(true)
		tap(find(azure, "Action_declareWar"))
		env.mock:advance(0.1)
		tap(find(find(find(hud.guis.menus, "Rivals"), "Rival_azure"), "Action_confirm"))
		env.mock:advance(0.5) -- about five server ticks: the command, then the next Kingdom.State push
		expect(server:get("MatchService").host.match.sim:atWar("crimson", "azure")).toBe(true)
		azure = find(find(hud.guis.menus, "Rivals"), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("war")
		expect(texts(hud.guis.notices)).toContain("War declared on")
	end)

	it("a co-ruler's ask reaches the senior: the WarAsk notice, the ask on the row and the Kingdom bubble", function()
		local env, server, hud, others = boot(1) -- I am crimson's senior; Ruler5 (Dis5) is my co-ruler
		env.mock:advance(TICK * 2)
		local results
		env.mock.remotes:asClient(others[5], function()
			local remote = env.ReplicatedStorage.ForgeRemotes:FindFirstChild("Kingdom"):FindFirstChild("Diplomacy")
			results = table.pack(remote:InvokeServer("declareWar", "azure"))
		end)
		expect(results[1]).toBe(true)
		expect(results[2]).toBe("asked")
		env.mock:advance(0.5) -- about five server ticks: the command, then the next Kingdom.State push
		expect(server:get("MatchService").host.match.sim:atWar("crimson", "azure")).toBe(false)
		expect(texts(hud.guis.notices)).toContain("Dis5 asks for war on")
		local azure = find(rivals(hud), "Rival_azure")
		expect(find(azure, "Ask").Text).toContain("Dis5 asks for war ·")
		expect(find(find(hud.guis.hud, "Menu_kingdom"), "Badge").Text).toBe("1")
		-- I declare: the server makes it war and the ask goes
		tap(find(azure, "Action_declareWar"))
		env.mock:advance(0.1)
		tap(find(find(find(hud.guis.menus, "Rivals"), "Rival_azure"), "Action_confirm"))
		env.mock:advance(0.5) -- about five server ticks: the command, then the next Kingdom.State push
		expect(server:get("MatchService").host.match.sim:atWar("crimson", "azure")).toBe(true)
		azure = find(find(hud.guis.menus, "Rivals"), "Rival_azure")
		expect(find(azure, "Relation"):GetAttribute("relation")).toBe("war")
		expect(find(azure, "Ask")).toBeNil()
	end)
end)
