local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local KitDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackKitController")

describe("FeedbackKitController (FORGE-02's FL-0135 handoff: the client's asset folder)", function()
	local function client()
		return MockEnv.new({ seed = 135, isServer = false, localPlayer = { userId = 13501 } })
	end

	local function assetsIn(env)
		local forge = roblox.Instance.new("Folder")
		forge.Name = "Forge"
		local assets = roblox.Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = forge
		forge.Parent = env.ReplicatedStorage
		return forge, assets
	end

	local function fakeKit()
		local kit = { calls = {} }
		function kit.setAssetSource(folder)
			table.insert(kit.calls, { folder = folder })
		end
		return kit
	end

	it("passes ReplicatedStorage.Forge.Assets to the Kit when it is built", function()
		local env = client()
		local _, assets = assetsIn(env)
		local kit = fakeKit()
		local controller = KitDef.create(env, nil, { kit = kit })
		expect(#kit.calls).toBe(1)
		expect(kit.calls[1].folder).toBe(assets)
		expect(controller.assets).toBe(assets)
	end)

	it("passes nil without Forge or without Forge.Assets (the part-built fallback)", function()
		local env = client()
		local kit = fakeKit()
		KitDef.create(env, nil, { kit = kit })
		expect(#kit.calls).toBe(1)
		expect(kit.calls[1].folder).toBeNil()
		local other = client()
		local forge, assets = assetsIn(other)
		assets.Parent = nil
		expect(forge:FindFirstChild("Assets")).toBeNil()
		KitDef.create(other, nil, { kit = kit })
		expect(#kit.calls).toBe(2)
		expect(kit.calls[2].folder).toBeNil()
	end)

	it("is set before any controller starts, so EntityController's first rig can be a mesh", function()
		local env = client()
		local _, assets = assetsIn(env)
		local kit = fakeKit()
		local seen = {}
		local registry = Loader.load(env, {
			{
				name = "EntityController", -- sorts before FeedbackKitController: start order alone would not do
				new = function()
					return {
						start = function()
							table.insert(seen, if #kit.calls == 1 then kit.calls[1].folder else false)
						end,
					}
				end,
			},
			{
				name = "FeedbackKitController",
				new = function(e, r)
					return KitDef.create(e, r, { kit = kit })
				end,
			},
		})
		expect(registry.order[1]).toBe("EntityController")
		expect(#seen).toBe(1)
		expect(seen[1]).toBe(assets)
		registry:destroy()
	end)

	it("with the real Kit, a model in Forge.Assets replaces the part-built stand-in", function()
		local env = client()
		local _, assets = assetsIn(env)
		local mesh = roblox.Instance.new("Model")
		mesh.Name = "prop_goods_01"
		roblox.Instance.new("Part").Parent = mesh
		mesh.Parent = assets
		KitDef.new(env, nil)
		local prop = Kit.prop("prop_goods_01")
		Kit.setAssetSource(nil) -- the Kit is shared by every spec: put the default back
		expect(prop:GetAttribute("KitStandIn")).toBeNil()
		expect(prop.Name).toBe("prop_goods_01")
		expect(Kit.prop("prop_goods_01"):GetAttribute("KitStandIn")).toBe(true)
	end)
end)
