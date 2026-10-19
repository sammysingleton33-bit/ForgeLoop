local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local FeedbackDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackController")

local CRIMSON = Color3.fromRGB(190, 40, 50)

-- The real Kit, counting applyDamage calls.
local function countingKit()
	local calls = {}
	local kit = setmetatable({
		applyDamage = function(model)
			table.insert(calls, model)
			return Kit.applyDamage(model)
		end,
	}, { __index = Kit })
	return kit, calls
end

local function boot(env, kit)
	local defs = {
		{
			name = "FeedbackController",
			new = function(e, r)
				return FeedbackDef.create(e, r, { kit = kit, layout = { resourceNodes = {} } })
			end,
		},
	}
	return Loader.load(env, defs):get("FeedbackController")
end

-- Workspace.ForgeKingdoms/crimson/Buildings, as WorldView lays it out.
local function buildingsFolder(env)
	local root = roblox.Instance.new("Folder")
	root.Name = "ForgeKingdoms"
	local kingdom = roblox.Instance.new("Folder")
	kingdom.Name = "crimson"
	kingdom.Parent = root
	local buildings = roblox.Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = kingdom
	root.Parent = env.Workspace
	return buildings
end

local function building(folder, kind, level, id, hp, maxHp)
	local model = Kit.build(kind, level, "complete", CRIMSON)
	model:SetAttribute("BuildingId", id)
	model:SetAttribute("Hp", hp)
	model:SetAttribute("MaxHp", maxHp)
	model.Parent = folder
	return model
end

local function signature(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

describe("FeedbackController: building damage follows HP (FL-0143, FL-0128 war kit)", function()
	it("Damage follows Hp/MaxHp; the parts change only when the damage state does; a repair restores them", function()
		local env = MockEnv.new({ seed = 143, isServer = false, localPlayer = { userId = 1 } })
		local kit, calls = countingKit()
		local feedback = boot(env, kit)
		local folder = buildingsFolder(env)
		local wall = building(folder, "wall", 2, 21, 100, 100)
		local whole = signature(wall)
		expect(feedback:refreshDamage()).toBe(0) -- full HP: Damage 0, state 0, nothing to build
		expect(wall:GetAttribute("Damage")).toBe(0)
		expect(#calls).toBe(0)
		wall:SetAttribute("Hp", 60) -- 0.4: state 1
		expect(feedback:refreshDamage()).toBe(1)
		expect(math.abs(wall:GetAttribute("Damage") - 0.4) < 1e-9).toBe(true)
		expect(wall:GetAttribute("KitDamageState")).toBe(1)
		expect(feedback:refreshDamage()).toBe(0) -- the same HP: nothing again
		wall:SetAttribute("Hp", 55) -- 0.45: still state 1: the number moves, the parts do not
		expect(feedback:refreshDamage()).toBe(0)
		expect(math.abs(wall:GetAttribute("Damage") - 0.45) < 1e-9).toBe(true)
		wall:SetAttribute("Hp", 10) -- 0.9: state 3
		expect(feedback:refreshDamage()).toBe(1)
		expect(wall:GetAttribute("KitDamageState")).toBe(3)
		expect(#calls).toBe(2)
		-- repaired: back to the model exactly as built
		wall:SetAttribute("Hp", 100)
		expect(feedback:refreshDamage()).toBe(1)
		expect(wall:GetAttribute("Damage")).toBe(0)
		expect(wall:GetAttribute("KitDamageState")).toBeNil()
		expect(signature(wall)).toBe(whole)
	end)

	it(
		"the poll does it (no per-frame work); a rebuilt model starts fresh; stand-ins and bad numbers are left alone",
		function()
			local env = MockEnv.new({ seed = 144, isServer = false, localPlayer = { userId = 1 } })
			local kit, calls = countingKit()
			boot(env, kit)
			local folder = buildingsFolder(env)
			local house = building(folder, "house", 1, 31, 20, 100) -- 0.8: state 3
			env.mock:advance(FeedbackDef.BURN_POLL_SEC + 0.05) -- the poll started by start()
			expect(house:GetAttribute("KitDamageState")).toBe(3)
			expect(#calls).toBe(1)
			env.mock:advance(FeedbackDef.BURN_POLL_SEC * 4) -- four more reads: no change, no call
			expect(#calls).toBe(1)
			-- WorldView rebuilds a building at a new level: a new model, no Damage yet
			house:Destroy()
			local rebuilt = building(folder, "house", 2, 31, 20, 100)
			env.mock:advance(FeedbackDef.BURN_POLL_SEC)
			expect(rebuilt:GetAttribute("KitDamageState")).toBe(3)
			expect(#calls).toBe(2)
			-- a plain-part stand-in, a model with no MaxHp, MaxHp 0 or a NaN Hp: untouched, no error
			local part = roblox.Instance.new("Part")
			part:SetAttribute("BuildingId", 40)
			part:SetAttribute("Hp", 1)
			part:SetAttribute("MaxHp", 100)
			part.Parent = folder
			local odd = {
				building(folder, "house", 1, 41, 10, nil),
				building(folder, "house", 1, 42, 10, 0),
				building(folder, "house", 1, 43, 0 / 0, 100),
				roblox.Instance.new("Model"), -- no PrimaryPart: Kit would dress nothing
			}
			roblox.Instance.new("Part").Parent = odd[4]
			odd[4]:SetAttribute("Hp", 10)
			odd[4]:SetAttribute("MaxHp", 100)
			odd[4].Parent = folder
			-- a kingdom whose Buildings folder has not streamed in yet
			local azure = roblox.Instance.new("Folder")
			azure.Name = "azure"
			azure.Parent = env.Workspace:FindFirstChild("ForgeKingdoms")
			-- ... and none of them stops a damaged house in the same read
			local fresh = building(folder, "house", 1, 44, 30, 100) -- 0.7: state 2
			env.mock:advance(FeedbackDef.BURN_POLL_SEC)
			expect(part:GetAttribute("Damage")).toBeNil()
			for _, model in odd do
				expect(model:GetAttribute("Damage")).toBeNil()
			end
			expect(fresh:GetAttribute("KitDamageState")).toBe(2)
			expect(#calls).toBe(3)
			expect(env.mock.threadErrors).toEqual({})
		end
	)

	it("an applyDamage that throws is logged and the poll goes on", function()
		local env = MockEnv.new({ seed = 145, isServer = false, localPlayer = { userId = 1 } })
		local broken = setmetatable({
			applyDamage = function()
				error("kit broke")
			end,
		}, { __index = Kit })
		local feedback = boot(env, broken)
		local folder = buildingsFolder(env)
		building(folder, "house", 1, 51, 10, 100)
		expect(feedback:refreshDamage()).toBe(0)
		expect(env.mock:hasLog("warn", "FeedbackController: Kit.applyDamage failed")).toBe(true)
		-- without the war kit at all, nothing happens: no Damage written, nothing logged
		local bare = MockEnv.new({ seed = 146, isServer = false })
		local none = boot(bare, setmetatable({ applyDamage = false }, { __index = Kit }))
		local untouched = building(buildingsFolder(bare), "house", 1, 52, 10, 100)
		expect(none:refreshDamage()).toBe(0)
		expect(untouched:GetAttribute("Damage")).toBeNil()
		expect(bare.mock:hasLog("warn", "FeedbackController: Kit.applyDamage failed")).toBe(false)
	end)

	it("a damaged building the server moves is dressed again where it stands (FORGE-07 #273 M1)", function()
		local env = MockEnv.new({ seed = 147, isServer = false, localPlayer = { userId = 1 } })
		local kit, calls = countingKit()
		local feedback = boot(env, kit)
		local keep = building(buildingsFolder(env), "keep", 3, 61, 20, 100) -- 0.8: state 3
		expect(feedback:refreshDamage()).toBe(1)
		-- the keep's own extent, in its root's frame
		local root = keep.PrimaryPart
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, d in keep:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("KitDamage") ~= true then
				local p = root.CFrame:PointToObjectSpace(d.CFrame.Position)
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
		-- WorldView's placeModel on the server moves the parts it knows; the damage parts are this client's
		local function serverMoves(delta)
			for _, d in keep:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("KitDamage") ~= true then
					d.CFrame = delta * d.CFrame
				end
			end
		end
		local function marksOnTheKeep()
			local marks = 0
			for _, d in keep:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("KitDamage") == true then
					marks += 1
					local p = root.CFrame:PointToObjectSpace(d.CFrame.Position)
					local inside = p.X >= lo.X - 2 and p.X <= hi.X + 2 and p.Z >= lo.Z - 2 and p.Z <= hi.Z + 2
					assert(inside, `{d.Name} stayed behind at {d.CFrame.Position}`)
				end
			end
			return marks
		end
		serverMoves(CFrame.new(44, 0, 0))
		expect(feedback:refreshDamage()).toBe(1) -- dressed again
		expect(#calls).toBe(3) -- the repair and the new dressing
		expect(keep:GetAttribute("KitDamageState")).toBe(3)
		expect(math.abs(keep:GetAttribute("Damage") - 0.8) < 1e-9).toBe(true)
		expect(marksOnTheKeep() > 0).toBe(true)
		-- turned in place (a quarter turn about its root): dressed again too. Where the marks then sit is
		-- FORGE-02's Kit/Damage fix (FORGE-00's g11l (a): today the kit works in world axes)
		local at = CFrame.new(root.CFrame.Position)
		serverMoves(at * CFrame.Angles(0, math.rad(90), 0) * at:Inverse())
		expect(feedback:refreshDamage()).toBe(1)
		expect(#calls).toBe(5)
		expect(keep:GetAttribute("KitDamageState")).toBe(3)
		expect(feedback:refreshDamage()).toBe(0) -- standing still: nothing more
		expect(#calls).toBe(5)
	end)

	it("an error in the damage pass is logged and the poll (and the fires) go on", function()
		local env = MockEnv.new({ seed = 148, isServer = false, localPlayer = { userId = 1 } })
		local reads = 0
		boot(
			env,
			setmetatable({
				damageFromHp = function()
					reads += 1
					error("kit broke")
				end,
			}, { __index = Kit })
		)
		building(buildingsFolder(env), "house", 1, 71, 10, 100)
		env.mock:advance(FeedbackDef.BURN_POLL_SEC * 3 + 0.05)
		expect(reads >= 3).toBe(true) -- the loop kept polling
		expect(env.mock:hasLog("warn", "FeedbackController: building damage failed")).toBe(true)
		expect(env.mock.threadErrors).toEqual({})
	end)
end)
