local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")

local function folder(env, name: string, parent)
	local f = env.newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

describe("MockInstanceEvents", function()
	describe("WaitForChild", function()
		it("returns an existing child at once", function()
			local env = MockEnv.new()
			local remotes = folder(env, "ForgeRemotes", env.ReplicatedStorage)
			expect(env.ReplicatedStorage:WaitForChild("ForgeRemotes")).toBe(remotes)
			expect(env.mock:elapsed()).toBe(0)
		end)

		it("a client thread waits on the virtual clock until the server creates the folder", function()
			local env = MockEnv.new({ isServer = false, localPlayer = { userId = 1 } })
			local found, foundAt
			env.spawn(function()
				found = env.ReplicatedStorage:WaitForChild("ForgeRemotes", 10)
				foundAt = env.mock:elapsed()
			end)
			env.mock:advance(1)
			expect(found).toBeNil()
			local remotes = folder(env, "ForgeRemotes", env.ReplicatedStorage)
			env.mock:advance(1)
			expect(found).toBe(remotes)
			expect(foundAt).toBeGreaterThan(1)
			expect(foundAt).toBeLessThanOrEqual(1 + MockEnv.FRAME + 1e-9)
		end)

		it("returns nil after the timeout (virtual seconds)", function()
			local env = MockEnv.new()
			local result, done = "unset", false
			env.spawn(function()
				result = env.ReplicatedStorage:WaitForChild("Never", 5)
				done = true
			end)
			env.mock:advance(4.9)
			expect(done).toBe(false)
			env.mock:advance(0.2)
			expect(done).toBe(true)
			expect(result).toBeNil()
		end)

		it("in the spec's own thread it advances time itself", function()
			local env = MockEnv.new()
			env.spawn(function()
				env.wait(2)
				folder(env, "Late", env.Workspace)
			end)
			local late = env.Workspace:WaitForChild("Late", 10)
			expect(late.Name).toBe("Late")
			expect(env.mock:elapsed()).toBeGreaterThanOrEqual(2)
		end)

		it(
			"without a timeout: a scheduled thread records the infinite-yield warning; the spec's thread errors",
			function()
				local env = MockEnv.new()
				env.spawn(function()
					env.ReplicatedStorage:WaitForChild("Missing")
				end)
				env.mock:advance(6)
				expect(#env.mock.warnings).toBe(1)
				expect(env.mock.warnings[1]).toContain(
					"Infinite yield possible on 'ReplicatedStorage:WaitForChild(\"Missing\")'"
				)
				expect(function()
					env.Workspace:WaitForChild("AlsoMissing")
				end).toThrow("Infinite yield possible")
			end
		)

		it("works on an unparented instance made with env.newInstance, not on a bare Instance.new", function()
			local env = MockEnv.new()
			local loose = env.newInstance("Folder")
			expect(loose:WaitForChild("X", 0.1)).toBeNil()
			expect(function()
				Instance.new("Folder"):WaitForChild("X", 1)
			end).toThrow("needs an instance inside a MockEnv DataModel")
		end)
	end)

	describe("ChildAdded / ChildRemoved", function()
		it("fire at the next scheduler step, removals first, handlers through env.spawn", function()
			local env = MockEnv.new()
			local events = {}
			local old = folder(env, "Old", env.Workspace)
			env.Workspace.ChildAdded:Connect(function(child)
				table.insert(events, "added " .. child.Name)
			end)
			env.Workspace.ChildRemoved:Connect(function(child)
				table.insert(events, "removed " .. child.Name)
			end)
			folder(env, "A", env.Workspace)
			folder(env, "B", env.Workspace)
			old.Parent = nil
			expect(events).toEqual({})
			env.mock:advance(0)
			expect(events).toEqual({ "removed Old", "added A", "added B" })
		end)

		it("fires for children added by scheduled threads, and a waiting handler parks", function()
			local env = MockEnv.new()
			local seen = {}
			env.ReplicatedStorage.ChildAdded:Connect(function(child)
				env.wait(1)
				table.insert(seen, child.Name .. "@" .. env.mock:elapsed())
			end)
			env.spawn(function()
				env.wait(2)
				folder(env, "ForgeRemotes", env.ReplicatedStorage)
			end)
			env.mock:advance(2.5)
			expect(seen).toEqual({})
			env.mock:advance(1)
			expect(seen).toEqual({ "ForgeRemotes@3" })
		end)

		it("does not fire for children that existed before the signal was first used", function()
			local env = MockEnv.new()
			folder(env, "Existing", env.Workspace)
			local count = 0
			env.Workspace.ChildAdded:Connect(function()
				count += 1
			end)
			env.mock:advance(1)
			expect(count).toBe(0)
		end)
	end)

	it("unsupported Instance members fail with a clear message", function()
		local env = MockEnv.new()
		local f = folder(env, "F", env.Workspace)
		for _, member in { "Changed", "Destroying", "AncestryChanged", "DescendantAdded", "DescendantRemoving" } do
			expect(function()
				return (f :: any)[member]
			end).toThrow(`Folder.{member} is not mocked under the Lune harness`)
		end
		expect(function()
			f:GetPropertyChangedSignal("Name")
		end).toThrow("GetPropertyChangedSignal() is not mocked")
	end)
end)
