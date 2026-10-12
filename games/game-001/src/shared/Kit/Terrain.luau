--!strict
--[[
	Kit/Terrain — the thin terrain adapter WorldService talks to (CONTRACTS G10, FL-0055).

		Terrain.live(terrain: Terrain, log?) -> Adapter -- real Workspace.Terrain (Roblox only)
		Terrain.recorder() -> Adapter                   -- records calls; Lune specs read adapter.calls
		Terrain.forWorkspace(workspace, log?) -> Adapter -- live when Terrain supports Fill*, else recorder
	Adapter:
		fill(op)                         -- WorldPlan op: Block / Ball / Cylinder with a material name
		setMaterialColor(name, Color3)
		setWater(props)                  -- WaterColor, WaterTransparency, ... on Terrain
		calls: { { method: string, op: any? } }   (recorder only)

	Every op is at most MAX_VOXELS_PER_CALL (64^3) voxels so no single call stalls a frame; bigger ops
	are refused so the plan stays chunked. (WriteVoxels, capped at 64 x 64 x 16 per frame by CONTRACTS
	G10, is not used.)
]]

local Terrain = {}

Terrain.MAX_VOXELS_PER_CALL = 64 * 64 * 64

local function voxels(op): number
	local V = 4
	if op.kind == "Block" then
		local s = op.size
		return math.ceil(s.X / V) * math.ceil(s.Y / V) * math.ceil(s.Z / V)
	elseif op.kind == "Ball" then
		local d = math.ceil(2 * op.radius / V)
		return d * d * d
	end
	local d = math.ceil(2 * op.radius / V)
	return d * d * math.ceil(op.height / V)
end
Terrain.voxels = voxels

local function check(op)
	local n = voxels(op)
	if n > Terrain.MAX_VOXELS_PER_CALL then
		error(`Terrain: op '{op.feature}' touches {n} voxels (> {Terrain.MAX_VOXELS_PER_CALL}); chunk it`, 3)
	end
end

function Terrain.recorder()
	local adapter = { calls = {} :: { any }, live = false }
	function adapter.fill(op)
		check(op)
		table.insert(adapter.calls, { method = "Fill" .. op.kind, op = op })
	end
	function adapter.setMaterialColor(name: string, color: Color3)
		table.insert(adapter.calls, { method = "SetMaterialColor", name = name, color = color })
	end
	function adapter.setWater(props: { [string]: any })
		table.insert(adapter.calls, { method = "SetWater", props = props })
	end
	return adapter
end

function Terrain.live(terrain: any, log: ((string, string, any?) -> ())?)
	local adapter = { live = true }
	function adapter.fill(op)
		check(op)
		local material = (Enum.Material :: any)[op.material]
		if op.kind == "Block" then
			terrain:FillBlock(op.cframe, op.size, material)
		elseif op.kind == "Ball" then
			terrain:FillBall(op.cframe.Position, op.radius, material)
		elseif op.kind == "Cylinder" then
			terrain:FillCylinder(op.cframe, op.height, op.radius, material)
		else
			error(`Terrain: unknown op kind {op.kind}`)
		end
	end
	function adapter.setMaterialColor(name: string, color: Color3)
		-- a material Roblox refuses (e.g. Water) must not abort the world build: warn and continue
		local ok, err = pcall(function()
			terrain:SetMaterialColor((Enum.Material :: any)[name], color)
		end)
		if not ok and log then
			log("warn", "Terrain:SetMaterialColor failed", { material = name, error = tostring(err) })
		end
	end
	function adapter.setWater(props: { [string]: any })
		for k, v in props do
			terrain[k] = v
		end
	end
	return adapter
end

-- Live adapter in Roblox; recorder anywhere Terrain:FillBlock is unavailable (Lune specs, MockEnv).
function Terrain.forWorkspace(workspace: any, log: ((string, string, any?) -> ())?)
	local terrain = workspace and workspace:FindFirstChildOfClass("Terrain")
	local ok = terrain ~= nil and pcall(function()
		return (terrain :: any).FillBlock
	end)
	if ok then
		return Terrain.live(terrain, log)
	end
	if log then
		log("info", "Terrain adapter: no live Terrain (headless); recording terrain calls", nil)
	end
	return Terrain.recorder()
end

return Terrain
