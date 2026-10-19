-- FL-0129 × FORGE-01's FL-0125 (#187, on main): the real KingdomHudController and
-- KingdomHudSpectateController against the REAL server (RemoteService, MatchService, KingdomService with
-- MatchHost and the Sim): our kingdom falls, Match.Spectate arrives, and the fallen card shows on the
-- modal layer with the phase bar kept. One MockEnv carries the server and the local player's client.
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
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local SpectateDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudSpectateController")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local PHASES = { Lobby = 2, Founding = 300, Expansion = 300, Conflict = 300, Endgame = 300, Results = 2 }

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

local function boot()
	local saved = MatchConfig.mode
	MatchConfig.mode = "match"
	local env = MockEnv.new({
		seed = 5,
		localPlayer = { userId = 1, name = "Ruler1" },
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Treasury = TreasuryRemotes } },
	})
	local pacing = {
		name = "PacingService",
		new = function()
			return {
				phaseDurations = function()
					return table.clone(PHASES)
				end,
			}
		end,
	}
	local server = Loader.load(env, { RemoteServiceDef, MatchServiceDef, KingdomServiceDef, pacing })
	MatchConfig.mode = saved
	server:get("KingdomService").adapter = adapter(env)
	env.mock.players:add({ userId = 2, name = "Ruler2", displayName = "Dis2" }) -- azure
	local playerGui = env.newInstance("PlayerGui")
	playerGui.Parent = env.Players.LocalPlayer
	local client = Loader.load(env, { KingdomHudDef, SpectateDef })
	local hud = client:get("KingdomHudController")
	hud:setViewport(1920, 1022)
	table.insert(booted, { server = server, client = client })
	env.mock:advance(3 + 0.5) -- the Lobby, into Founding
	return env, server, hud, client:get("KingdomHudSpectateController")
end

describe("Spectate against FORGE-01's real FL-0125 server (#187)", function()
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

	it("our kingdom falls: Match.Spectate, the fallen card on the modal layer, the phase bar kept", function()
		local env, server, hud, spectate = boot()
		local match = server:get("MatchService")
		expect(match:getPhase()).toBe("Founding")
		expect(hud.guis.menus.Enabled).toBe(true) -- ruling crimson
		local sim = match.host.match.sim
		Military.eliminate(sim, sim.kingdoms.crimson, "azure")
		env.mock:advance(0.5)
		expect(spectate.spectating).toBe(true)
		expect(spectate.info.reason).toBe("eliminated")
		expect(hud.store:mine()).toBeNil()
		expect(hud.guis.menus.Enabled).toBe(false) -- no kingdom: the kingdom HUD goes
		expect(hud.guis.topbar.Enabled).toBe(true) -- the phase bar stays
		local card = find(hud.guis.modals, "FallenCard")
		expect(card).toBeTruthy()
		expect(texts(card)).toContain("has fallen")
		expect(texts(card)).toContain("took your keep")
		expect(texts(card)).toContain("3 kingdoms still stand")
		tap(find(card, "Stay"))
		env.mock:advance(0.1)
		expect(find(hud.guis.modals, "WatchPanel")).toBeTruthy()
	end)
end)
