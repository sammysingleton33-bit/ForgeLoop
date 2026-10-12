local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MockEnv = require("../../mocks/MockEnv")

-- A definition that records new/start calls into `log`.
local function def(log, name, dependencies, extra)
	return {
		name = name,
		dependencies = dependencies,
		new = function(_env, registry)
			table.insert(log, "new " .. name)
			local instance = { name = name, registry = registry }
			function instance:start()
				table.insert(log, "start " .. name)
				if extra and extra.onStart then
					extra.onStart(self)
				end
			end
			if extra and extra.onNew then
				extra.onNew(registry)
			end
			return instance
		end,
	}
end

describe("Contracts/Loader", function()
	describe("ordering", function()
		it("constructs in dependency order, then starts in the same order", function()
			local log = {}
			local registry = Loader.load(MockEnv.new(), {
				def(log, "Round", { "Data", "Player" }),
				def(log, "Player", { "Data" }),
				def(log, "Data"),
			})
			expect(registry.order).toEqual({ "Data", "Player", "Round" })
			expect(log).toEqual({ "new Data", "new Player", "new Round", "start Data", "start Player", "start Round" })
		end)

		it("breaks ties by name so the order is deterministic", function()
			local log = {}
			local registry = Loader.load(MockEnv.new(), { def(log, "Zeta"), def(log, "Alpha"), def(log, "Mid") })
			expect(registry.order).toEqual({ "Alpha", "Mid", "Zeta" })
		end)

		it("loads nothing when there are no definitions", function()
			expect(Loader.load(MockEnv.new(), {}).order).toEqual({})
			expect(Loader.boot(MockEnv.new(), nil).order).toEqual({})
		end)
	end)

	describe("errors", function()
		it("names a missing dependency", function()
			expect(function()
				Loader.sort({ def({}, "Round", { "Data" }) })
			end).toThrow("'Round' depends on 'Data', which is not loaded")
		end)

		it("names the exact cycle", function()
			expect(function()
				Loader.sort({ def({}, "A", { "B" }), def({}, "B", { "C" }), def({}, "C", { "A" }), def({}, "D") })
			end).toThrow("dependency cycle: A -> B -> C -> A")
		end)

		it("rejects self-dependencies and duplicate names", function()
			expect(function()
				Loader.sort({ def({}, "A", { "A" }) })
			end).toThrow("dependency cycle: A -> A")
			expect(function()
				Loader.sort({ def({}, "A"), def({}, "A") })
			end).toThrow("duplicate service name 'A'")
		end)

		it("rejects malformed definitions", function()
			expect(function()
				Loader.validate({ name = "X" }, "Services/X")
			end).toThrow("has no new(env, registry)")
			expect(function()
				Loader.validate({ new = function() end }, "Services/X")
			end).toThrow("has no string 'name'")
			expect(function()
				Loader.validate({ name = "X", new = function() end, dependencies = "Data" }, "Services/X")
			end).toThrow("dependencies must be a list")
		end)

		it("fails when new() yields, returns nil or throws, naming the service", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					{
						name = "Slow",
						new = function()
							coroutine.yield()
							return {}
						end,
					},
				})
			end).toThrow("Slow.new() yielded")
			expect(function()
				Loader.load(
					MockEnv.new(),
					{ {
						name = "Empty",
						new = function()
							return nil
						end,
					} }
				)
			end).toThrow("Empty.new() returned nil")
			expect(function()
				Loader.load(
					MockEnv.new(),
					{ {
						name = "Boom",
						new = function()
							error("kaput")
						end,
					} }
				)
			end).toThrow("Boom.new() failed")
		end)

		it("fails when start() throws, naming the service", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					def({}, "Broken", nil, {
						onStart = function()
							error("start exploded")
						end,
					}),
				})
			end).toThrow("Broken:start() failed")
		end)
	end)

	describe("registry", function()
		it("get() returns declared dependencies during new() and errors for missing services", function()
			local seen
			local registry = Loader.load(MockEnv.new(), {
				def({}, "Data"),
				def({}, "Round", { "Data" }, {
					onNew = function(reg)
						seen = reg:get("Data")
					end,
				}),
			})
			expect(seen.name).toBe("Data")
			expect(registry:get("Round").name).toBe("Round")
			expect(function()
				registry:get("Nope")
			end).toThrow("service 'Nope' is not loaded")
		end)

		it("get() of an undeclared service inside new() is an error", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					def({}, "Data"),
					def({}, "Shop", nil, {
						onNew = function(reg)
							reg:get("Data")
						end,
					}),
				})
			end).toThrow("Shop.new() fetched 'Data' without declaring it")
		end)

		it("find() returns nil when absent and the instance when present (start or later)", function()
			local foundInStart, missingInStart
			local registry = Loader.load(MockEnv.new(), {
				def({}, "Analytics"),
				def({}, "Economy", nil, {
					onStart = function(self)
						foundInStart = self.registry:find("Analytics")
						missingInStart = self.registry:find("Quest")
					end,
				}),
			})
			expect(foundInStart.name).toBe("Analytics")
			expect(missingInStart).toBeNil()
			expect(registry:find("Nope")).toBeNil()
		end)

		it("find() inside new() is an error (services built later would look absent)", function()
			expect(function()
				Loader.load(MockEnv.new(), {
					def({}, "Economy", nil, {
						onNew = function(reg)
							reg:find("Analytics")
						end,
					}),
				})
			end).toThrow("call find in start() or later")
		end)
	end)

	describe("destroy", function()
		local function destroyable(log, name, dependencies, failing)
			return {
				name = name,
				dependencies = dependencies,
				new = function()
					return {
						destroy = function()
							table.insert(log, "destroy " .. name)
							if failing then
								error(name .. " teardown broke")
							end
						end,
					}
				end,
			}
		end

		it("registry:destroy() calls destroy in reverse construction order, once", function()
			local log = {}
			local registry = Loader.load(MockEnv.new(), {
				destroyable(log, "Round", { "Data" }),
				destroyable(log, "Data"),
				{
					name = "NoHook",
					new = function()
						return {}
					end,
				},
			})
			expect(registry.order).toEqual({ "Data", "NoHook", "Round" })
			registry:destroy()
			registry:destroy()
			expect(log).toEqual({ "destroy Round", "destroy Data" })
		end)

		it("one failing destroy does not stop the others; the failure is raised afterwards", function()
			local log = {}
			local registry = Loader.load(MockEnv.new(), {
				destroyable(log, "A"),
				destroyable(log, "B", { "A" }, true),
				destroyable(log, "C", { "B" }),
			})
			expect(function()
				registry:destroy()
			end).toThrow("B:destroy() failed")
			expect(log).toEqual({ "destroy C", "destroy B", "destroy A" })
		end)
	end)

	describe("discovery", function()
		local function folderWith(names, extraFolder)
			local folder = Instance.new("Folder")
			folder.Name = "Services"
			for _, name in names do
				local module = Instance.new("ModuleScript")
				module.Name = name
				module.Parent = folder
			end
			if extraFolder then
				local helpers = Instance.new("Folder")
				helpers.Name = "Helpers"
				helpers.Parent = folder
			end
			return folder
		end

		it("requires every ModuleScript directly in the folder, sorted, ignoring sub-folders", function()
			local log = {}
			local definitions = Loader.discover(folderWith({ "Zed", "Abe" }, true), function(module)
				return def(log, module.Name)
			end)
			local names = {}
			for _, d in definitions do
				table.insert(names, d.name)
			end
			expect(names).toEqual({ "Abe", "Zed" })
		end)

		it("an empty folder loads without error (fresh skeleton)", function()
			local registry = Loader.boot(MockEnv.new(), folderWith({}), function()
				error("nothing to require")
			end)
			expect(registry.order).toEqual({})
		end)

		it("boots services from several trees together, in dependency order across trees (D-022)", function()
			local log = {}
			local forge = folderWith({ "DataService" })
			local gameTree = folderWith({ "KingdomService" })
			gameTree.Name = "GameServices"
			local registry = Loader.boot(MockEnv.new(), { forge, gameTree }, function(module)
				if module.Name == "KingdomService" then
					return def(log, "KingdomService", { "DataService" })
				end
				return def(log, module.Name)
			end)
			expect(registry.order).toEqual({ "DataService", "KingdomService" })
		end)

		it("rejects one name defined in two trees, naming both folders", function()
			local forge = folderWith({ "DataService" })
			local gameTree = folderWith({ "DataService" })
			gameTree.Name = "GameServices"
			expect(function()
				Loader.discoverAll({ forge, gameTree }, function(module)
					return def({}, module.Name)
				end)
			end).toThrow("'DataService' is defined in both Services and GameServices")
		end)

		it("boot accepts one folder, a list, or nil", function()
			local function req(module)
				return def({}, module.Name)
			end
			expect(Loader.boot(MockEnv.new(), folderWith({ "A" }), req).order).toEqual({ "A" })
			expect(Loader.boot(MockEnv.new(), { folderWith({ "A" }), folderWith({ "B" }) }, req).order).toEqual({
				"A",
				"B",
			})
			expect(Loader.boot(MockEnv.new(), nil, req).order).toEqual({})
		end)

		it("rejects a module whose definition name differs from the module name", function()
			expect(function()
				Loader.discover(folderWith({ "RoundService" }), function()
					return def({}, "RoundSvc")
				end)
			end).toThrow("declares name 'RoundSvc'; it must match the module name")
		end)
	end)
end)
