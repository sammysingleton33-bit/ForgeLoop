-- Studio debug panel (FL-0068): DebugCommands registry, DebugServer (Studio-only remotes), DebugPanel.
local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local DebugPanel = require("@game/ReplicatedStorage/Forge/Debug/DebugPanel")
local DebugServer = require("@game/ReplicatedStorage/Forge/Debug/DebugServer")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local function addPlayerGui(player)
	local gui = Instance.new("Folder")
	gui.Name = "PlayerGui"
	gui.Parent = player
	return gui
end

describe("Debug/DebugCommands", function()
	beforeEach(function()
		DebugCommands.reset()
	end)

	it("rejects bad definitions at registration", function()
		expect(function()
			DebugCommands.register({ name = "nodot", run = function() end })
		end).toThrow('name must look like "area.action"')
		expect(function()
			DebugCommands.register({ name = "a.b" } :: any)
		end).toThrow("needs a run(player, ...) function")
		DebugCommands.register({ name = "a.b", run = function() end })
		expect(function()
			DebugCommands.register({ name = "a.b", run = function() end })
		end).toThrow("already registered")
		expect(function()
			DebugCommands.registerPreset({ name = "p.q", steps = {} })
		end).toThrow("non-empty list of steps")
	end)

	it("validates arguments fail-closed and never throws", function()
		local got = {}
		DebugCommands.register({
			name = "economy.grant",
			args = { Validate.integer(0, 1000) },
			run = function(_player, amount)
				table.insert(got, amount)
				return `granted {amount}`
			end,
		})
		DebugCommands.register({
			name = "broken.typo",
			args = { Validate.boolean :: any }, -- forgot (): must reject everything
			run = function()
				return "should not run"
			end,
		})
		DebugCommands.register({
			name = "boom.now",
			run = function()
				error("kaboom")
			end,
		})
		expect({ DebugCommands.run(nil, "economy.grant", 500) }).toEqual({ true, "granted 500" })
		local ok, why = DebugCommands.run(nil, "economy.grant", 5000)
		expect(ok).toBe(false)
		expect(why).toContain("economy.grant:")
		expect((DebugCommands.run(nil, "economy.grant", 1, 2))).toBe(false) -- extra argument
		expect((DebugCommands.run(nil, "broken.typo", true))).toBe(false)
		local boomOk, boomWhy = DebugCommands.run(nil, "boom.now")
		expect(boomOk).toBe(false)
		expect(boomWhy).toContain("kaboom")
		expect((DebugCommands.run(nil, "missing.command"))).toBe(false)
		expect((DebugCommands.run(nil, 42))).toBe(false)
		expect(got).toEqual({ 500 })
	end)

	it("runs presets in order and stops at the first failing step", function()
		local log = {}
		DebugCommands.register({
			name = "step.one",
			run = function()
				table.insert(log, "one")
				return "1"
			end,
		})
		DebugCommands.register({
			name = "step.fail",
			run = function()
				error("no")
			end,
		})
		DebugCommands.registerPreset({ name = "vs1.ok", label = "ok", steps = { { "step.one" }, { "step.one" } } })
		DebugCommands.registerPreset({ name = "vs1.bad", steps = { { "step.one" }, { "step.fail" }, { "step.one" } } })
		expect({ DebugCommands.runPreset(nil, "vs1.ok") }).toEqual({ true, "vs1.ok: 1; 1" })
		local ok, why = DebugCommands.runPreset(nil, "vs1.bad")
		expect(ok).toBe(false)
		expect(why).toContain("vs1.bad step 2")
		expect(log).toEqual({ "one", "one", "one" })
		expect(DebugCommands.presets()).toEqual({
			{ name = "vs1.bad", label = "vs1.bad", steps = 3 },
			{ name = "vs1.ok", label = "ok", steps = 2 },
		})
	end)
end)

describe("Debug/DebugServer", function()
	beforeEach(function()
		DebugCommands.reset()
	end)

	it("outside Studio creates no remotes and returns nil (FL-0068)", function()
		local env = MockEnv.new({ studio = false })
		expect(DebugServer.start(env, { order = {} })).toBeNil()
		expect(env.ReplicatedStorage:FindFirstChild("ForgeDebug")).toBeNil()
		expect(DebugCommands.list()).toEqual({}) -- built-ins are not even registered
	end)

	it("in Studio serves List/Run with built-ins, validation and rate limits", function()
		local env = MockEnv.new({ studio = true })
		local handle = DebugServer.start(env, { order = { "DataService", "RemoteService" } })
		expect(handle).toBeTruthy()
		local folder = env.ReplicatedStorage:FindFirstChild("ForgeDebug")
		expect(folder).toBeTruthy()
		local alice = env.mock.players:add({ userId = 7 })
		local listing, answer, unknownKind
		env.mock.remotes:asClient(alice, function()
			listing = folder.List:InvokeServer()
			answer = folder.Run:InvokeServer("command", "forge.services")
			unknownKind = folder.Run:InvokeServer("teleport", "x")
		end)
		local names = {}
		for _, command in listing.commands do
			table.insert(names, command.name)
		end
		expect(names).toEqual({ "forge.buildInfo", "forge.services" })
		expect(answer).toEqual({ ok = true, message = "DataService > RemoteService" })
		expect(unknownKind.ok).toBe(false)
		local limited = 0
		env.mock.remotes:asClient(alice, function()
			for _ = 1, 40 do
				local reply = folder.Run:InvokeServer("command", "forge.buildInfo")
				if reply.message == "rate limited" then
					limited += 1
				end
			end
		end)
		expect(limited).toBeGreaterThan(0)
		handle.stop()
		expect(env.ReplicatedStorage:FindFirstChild("ForgeDebug")).toBeNil()
	end)
end)

describe("Debug/DebugPanel", function()
	beforeEach(function()
		DebugCommands.reset()
	end)

	it("outside Studio builds nothing", function()
		local env = MockEnv.new({ studio = false, isServer = false, localPlayer = { userId = 1 } })
		expect(DebugPanel.start(env)).toBeNil()
	end)

	it("in Studio lists presets and argument-free commands and runs them through the server", function()
		local env = MockEnv.new({ studio = true, localPlayer = { userId = 1, name = "Ruler" } })
		local player = env.Players.LocalPlayer
		local playerGui = addPlayerGui(player)
		local ran = {}
		DebugCommands.register({
			name = "kingdom.ping",
			label = "Ping",
			run = function(p)
				table.insert(ran, p.UserId)
				return "pong"
			end,
		})
		DebugCommands.register({ name = "economy.grant", args = { Validate.integer(0, 9) }, run = function() end })
		DebugCommands.registerPreset({ name = "vs1.row1", label = "Row 1", steps = { { "kingdom.ping" } } })
		DebugServer.start(env, { order = {} })
		local handle = DebugPanel.start(env) :: any
		env.mock:advance(1)
		expect(handle.ready).toBe(true)
		local gui = playerGui:FindFirstChild("ForgeDebugPanel")
		expect(gui).toBeTruthy()
		local texts = {}
		for _, child in gui.Panel:GetChildren() do
			if child:IsA("TextButton") or child:IsA("TextLabel") then
				table.insert(texts, child.Text)
			end
		end
		table.sort(texts)
		expect(table.find(texts, "  vs1.row1 — Row 1") ~= nil).toBe(true)
		expect(table.find(texts, "  kingdom.ping — Ping") ~= nil).toBe(true)
		expect(table.find(texts, "  economy.grant (1 args: run from a preset or code)") ~= nil).toBe(true)
		expect({ handle.press("preset", "vs1.row1") }).toEqual({ true, "vs1.row1: pong" })
		expect(gui.Result.Text).toBe("OK  vs1.row1: pong")
		expect({ handle.press("command", "nope.nope") }).toEqual({ false, "unknown command 'nope.nope'" })
		expect(ran).toEqual({ 1 })
	end)
end)
