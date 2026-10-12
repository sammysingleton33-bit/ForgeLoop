local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Trove = require("@game/ReplicatedStorage/Forge/Core/Trove")

describe("Core/Trove", function()
	local reports
	local function newTrove()
		return Trove.new(function(message)
			table.insert(reports, message)
		end)
	end

	beforeEach(function()
		reports = {}
	end)

	it("cleans functions, Signal connections, engine connections, Instances and destroyables", function()
		local env = MockEnv.new()
		local trove = newTrove()
		local called = 0
		trove:add(function()
			called += 1
		end)
		local signal = Signal.new()
		local signalConnection = trove:add(signal:connect(function() end))
		local engineConnection = trove:add(env.Players.PlayerAdded:Connect(function() end))
		local folder = env.newInstance("Folder")
		folder.Parent = env.ReplicatedStorage
		trove:add(folder)
		local destroyed = {}
		trove:add({
			destroy = function()
				table.insert(destroyed, "lower")
			end,
		})
		trove:add({
			Destroy = function()
				table.insert(destroyed, "upper")
			end,
		})

		local failures = trove:clean()
		expect(failures).toEqual({})
		expect(called).toBe(1)
		expect(signalConnection.connected).toBe(false)
		expect(engineConnection.Connected).toBe(false)
		expect(folder.Parent).toBeNil()
		expect(destroyed).toEqual({ "upper", "lower" })
		expect(#reports).toBe(0)
	end)

	it("cleans in reverse order of add()", function()
		local trove = newTrove()
		local order = {}
		for i = 1, 3 do
			trove:add(function()
				table.insert(order, i)
			end)
		end
		trove:clean()
		expect(order).toEqual({ 3, 2, 1 })
	end)

	it("clean() is idempotent and the trove is reusable afterwards", function()
		local trove = newTrove()
		local count = 0
		trove:add(function()
			count += 1
		end)
		trove:clean()
		trove:clean()
		expect(count).toBe(1)
		trove:add(function()
			count += 10
		end)
		trove:clean()
		expect(count).toBe(11)
	end)

	it("an error in one cleanup does not stop the others; failures are returned and reported once", function()
		local trove = newTrove()
		local ran = {}
		trove:add(function()
			table.insert(ran, "first")
		end)
		trove:add(function()
			error("cleanup two broke")
		end)
		trove:add({
			Destroy = function()
				error("destroy broke")
			end,
		})
		trove:add(function()
			table.insert(ran, "last")
		end)
		local failures
		expect(function()
			failures = trove:clean()
		end).never.toThrow()
		expect(ran).toEqual({ "last", "first" })
		expect(#failures).toBe(2)
		expect(failures[1]).toContain("destroy broke")
		expect(failures[2]).toContain("cleanup two broke")
		expect(#reports).toBe(1)
		expect(reports[1]).toContain("cleanup two broke")
	end)

	it("extend() makes a child trove that the parent cleans, merging its failures", function()
		local trove = newTrove()
		local child = trove:extend()
		local ran = {}
		child:add(function()
			table.insert(ran, "child")
		end)
		child:add(function()
			error("child broke")
		end)
		trove:add(function()
			table.insert(ran, "parent")
		end)
		local failures = trove:clean()
		expect(ran).toEqual({ "parent", "child" })
		expect(#failures).toBe(1)
		expect(failures[1]).toContain("child broke")
		expect(#reports).toBe(1) -- reported by the parent only
		expect(Trove.is(child)).toBe(true)
	end)

	it("a child cleaned on its own does not affect the parent", function()
		local trove = newTrove()
		local child = trove:extend()
		local parentRan = false
		trove:add(function()
			parentRan = true
		end)
		child:clean()
		expect(parentRan).toBe(false)
	end)

	it("remove(item) takes the item out and cleans it now", function()
		local trove = newTrove()
		local count = 0
		local fn = function()
			count += 1
		end
		trove:add(fn)
		expect(trove:remove(fn)).toBe(true)
		expect(count).toBe(1)
		trove:clean()
		expect(count).toBe(1)
		expect(trove:remove(fn)).toBe(false)
	end)

	it("remove() reports a failing cleanup and returns its message", function()
		local trove = newTrove()
		local item = {
			disconnect = function()
				error("nope")
			end,
		}
		trove:add(item)
		local found, err = trove:remove(item)
		expect(found).toBe(true)
		expect(err).toContain("nope")
		expect(#reports).toBe(1)
	end)

	it("cleans items added during clean() in the same pass", function()
		local trove = newTrove()
		local late = false
		trove:add(function()
			trove:add(function()
				late = true
			end)
		end)
		trove:clean()
		expect(late).toBe(true)
	end)

	it("clean() from inside a cleanup returns {} and the outer pass finishes", function()
		local trove = newTrove()
		local ran = {}
		trove:add(function()
			table.insert(ran, "a")
		end)
		trove:add(function()
			expect(trove:clean()).toEqual({})
			table.insert(ran, "b")
		end)
		trove:clean()
		expect(ran).toEqual({ "b", "a" })
	end)

	it("add() rejects things it cannot clean", function()
		local trove = newTrove()
		expect(function()
			trove:add(nil)
		end).toThrow("cannot clean a nil")
		expect(function()
			trove:add(5)
		end).toThrow("cannot clean a number")
		expect(function()
			trove:add({ notACleanup = true })
		end).toThrow("cannot clean a table")
		expect(function()
			trove:add(trove)
		end).toThrow("cannot contain itself")
	end)

	it("add() returns the item; destroy() is clean()", function()
		local trove = newTrove()
		local count = 0
		local fn = function()
			count += 1
		end
		expect(trove:add(fn)).toBe(fn)
		trove:destroy()
		expect(count).toBe(1)
	end)
end)
