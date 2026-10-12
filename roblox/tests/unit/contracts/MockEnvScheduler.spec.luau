-- MockEnv virtual-time semantics in every kind of thread (review of FL-0003): scheduled threads
-- park in env.wait like task.wait; only the spec's own thread fast-forwards.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local MockEnv = require("../../mocks/MockEnv")

-- Captures what the harness would report (the failure path of a spawned thread) for one call.
local function capturingReports(fn: () -> ()): { string }
	local reported = {}
	local original = T.reportUnhandledError
	T.reportUnhandledError = function(message)
		table.insert(reported, tostring(message))
	end
	local ok, err = pcall(fn)
	T.reportUnhandledError = original
	if not ok then
		error(err, 0)
	end
	return reported
end

describe("MockEnv scheduler", function()
	describe("Signal / GameEvents handlers are scheduled threads", function()
		it("a handler that waits does not delay fire() or the handlers after it", function()
			local env = MockEnv.new({ startTime = 0 })
			local log = {}
			local signal = Signal.new()
			signal:connect(function()
				table.insert(log, "h1 start " .. env.now())
				env.wait(10)
				table.insert(log, "h1 end " .. env.now())
			end)
			signal:connect(function()
				table.insert(log, "h2 " .. env.now())
			end)
			signal:fire()
			table.insert(log, "after fire " .. env.now())
			expect(log).toEqual({ "h1 start 0", "h2 0", "after fire 0" })
			env.mock:advance(10)
			expect(log).toEqual({ "h1 start 0", "h2 0", "after fire 0", "h1 end 10" })
		end)

		it("a GameEvents listener that waits resumes only when the spec advances time", function()
			local env = MockEnv.new({ startTime = 0 })
			local order = {}
			GameEvents.RoundEnded:connect(function()
				table.insert(order, "listener start")
				env.wait(5)
				table.insert(order, "listener resumed")
			end)
			GameEvents.RoundEnded:fire({})
			table.insert(order, "after fire")
			env.mock:advance(5)
			GameEvents.disconnectAll()
			expect(order).toEqual({ "listener start", "after fire", "listener resumed" })
		end)

		it("advance(1) never runs threads due later, even when a resumed thread fires a waiting handler", function()
			local env = MockEnv.new()
			local signal = Signal.new()
			local ranAt = nil
			signal:connect(function()
				env.wait(5)
			end)
			env.spawn(function()
				env.wait(0.5)
				signal:fire()
			end)
			env.spawn(function()
				env.wait(3)
				ranAt = env.mock:elapsed()
			end)
			env.mock:advance(1)
			expect(env.mock:elapsed()).toBe(1)
			expect(ranAt).toBeNil()
			env.mock:advance(2)
			expect(ranAt).toBe(3)
		end)

		it("an error after a handler waited and resumed fails the test (is reported)", function()
			local env = MockEnv.new()
			local reported = capturingReports(function()
				GameEvents.PlayerReady:connect(function()
					env.wait(1)
					error("quest bookkeeping crashed")
				end)
				GameEvents.PlayerReady:fire({})
				env.mock:advance(1)
				GameEvents.disconnectAll()
			end)
			expect(#reported).toBe(1)
			expect(reported[1]).toContain("quest bookkeeping crashed")
		end)

		it("an error after Signal:wait() resumed a handler is reported", function()
			local roundOver = Signal.new()
			local reported = capturingReports(function()
				GameEvents.PlayerReady:connect(function()
					roundOver:wait()
					error("late handler error")
				end)
				GameEvents.PlayerReady:fire({})
				roundOver:fire()
				GameEvents.disconnectAll()
			end)
			expect(#reported).toBe(1)
			expect(reported[1]).toContain("late handler error")
		end)
	end)

	describe("Loader: new() must not yield (interfaces §3)", function()
		it("fails when new() calls env.wait", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					{
						name = "SlowService",
						new = function(e)
							e.wait(1)
							return {}
						end,
					},
				})
			end).toThrow("SlowService.new() yielded")
		end)

		it("fails when new() makes a DataStore request (async calls always yield)", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					{
						name = "Greedy",
						new = function(e)
							e.DataStoreService:GetDataStore("Config"):GetAsync("global")
							return {}
						end,
					},
				})
			end).toThrow("Greedy.new() yielded")
		end)

		it("fails when new() asks PolicyService or MarketplaceService", function()
			local env = MockEnv.new()
			local player = env.mock.players:add({ userId = 1 })
			expect(function()
				Loader.load(env, {
					{
						name = "Policy",
						new = function(e)
							e.PolicyService:GetPolicyInfoForPlayerAsync(player)
							return {}
						end,
					},
				})
			end).toThrow("Policy.new() yielded")
			expect(function()
				Loader.load(env, {
					{
						name = "Pass",
						new = function(e)
							e.MarketplaceService:UserOwnsGamePassAsync(1, 2)
							return {}
						end,
					},
				})
			end).toThrow("Pass.new() yielded")
		end)

		it("start() may wait in a thread it spawns", function()
			local env = MockEnv.new()
			local ticked = false
			Loader.load(env, {
				{
					name = "Ticker",
					new = function(e)
						return {
							start = function()
								e.spawn(function()
									e.wait(1)
									ticked = true
								end)
							end,
						}
					end,
				},
			})
			expect(ticked).toBe(false)
			env.mock:advance(1)
			expect(ticked).toBe(true)
		end)
	end)

	describe("frames", function()
		it("wait() and wait(0) last one frame (1/60 s), so a per-frame loop is bounded", function()
			local env = MockEnv.new()
			local ticks = 0
			env.spawn(function()
				while true do
					ticks += 1
					env.wait()
				end
			end)
			env.mock:advance(1)
			expect(ticks).toBe(61) -- the first iteration ran at spawn time, then one per frame
			local zeroTicks = 0
			env.spawn(function()
				while true do
					zeroTicks += 1
					env.wait(0)
				end
			end)
			env.mock:advance(0.5)
			expect(zeroTicks).toBe(31)
		end)

		it("wait returns the virtual seconds waited; the spec's own wait advances at least one frame", function()
			local env = MockEnv.new()
			local waited
			env.spawn(function()
				waited = env.wait(2)
			end)
			env.mock:advance(2)
			expect(waited).toBe(2)
			local before = env.mock:elapsed()
			expect(env.wait(0)).toBeNear(MockEnv.FRAME)
			expect(env.mock:elapsed() - before).toBeNear(MockEnv.FRAME)
		end)

		it("a runaway loop errors instead of hanging the gate", function()
			local env = MockEnv.new()
			env.spawn(function()
				while true do
					env.wait()
				end
			end)
			local original = MockEnv.MAX_RESUMES
			MockEnv.MAX_RESUMES = 100
			local ok, err = pcall(function()
				env.mock:advance(10)
			end)
			MockEnv.MAX_RESUMES = original
			expect(ok).toBe(false)
			expect(tostring(err)).toContain("runaway")
		end)
	end)

	it("advance() is not re-entrant: calling it from a scheduled thread is reported", function()
		local env = MockEnv.new()
		local reported = capturingReports(function()
			env.spawn(function()
				env.wait(1)
				env.mock:advance(5)
			end)
			env.mock:advance(1)
		end)
		expect(#reported).toBe(1)
		expect(reported[1]).toContain("already advancing")
		expect(env.mock:elapsed()).toBe(1)
	end)

	it("errors in plain coroutines resumed by the scheduler are reported", function()
		local env = MockEnv.new()
		local reported = capturingReports(function()
			local thread = coroutine.create(function()
				env.wait(1)
				error("raw coroutine broke")
			end)
			coroutine.resume(thread)
			env.mock:advance(1)
		end)
		expect(#reported).toBe(1)
		expect(reported[1]).toContain("raw coroutine broke")
	end)
end)
