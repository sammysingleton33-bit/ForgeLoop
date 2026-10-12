--!strict
--[[
	Kit/Props — imported meshes by asset id (when an asset source is registered) or part-built
	stand-ins with the same ids, and territory markers.
]]

local Parts = require("./Parts")
local C = Parts.C
local newModel = Parts.newModel
local block = Parts.block
local column = Parts.column
local log = Parts.log
local ball = Parts.ball
local Pieces = require("./Pieces")
local flagpole = Pieces.flagpole

local Props = {}

-- ------------------------------------------------------------------ props (stand-ins until meshes import)

local assetSource: Instance? = nil

function Props.setAssetSource(folder: Instance?)
	assetSource = folder
end

local function standIn(assetId: string): Model
	local ctx = newModel(assetId, Vector2.new(4, 4))
	ctx.model:SetAttribute("KitStandIn", true)
	local h = 0
	for i = 1, #assetId do
		h = (h * 31 + string.byte(assetId, i)) % 1000003
	end
	local rng = Random.new(h)
	if string.find(assetId, "^tree_") then
		local pine = string.find(assetId, "pine") ~= nil
		local th = if pine then rng:NextNumber(18, 26) else rng:NextNumber(10, 14)
		column(ctx, "Trunk", if pine then 0.9 else 1.3, th, Vector3.new(0, 0, 0), C.bark, Enum.Material.Wood)
		if pine then
			for i = 0, 4 do
				local r = 6.5 - i * 1.15
				column(
					ctx,
					"Tier",
					r,
					2.6,
					Vector3.new(0, 6 + i * 3.6, 0),
					if i % 2 == 0 then C.leafDark else C.leaf,
					Enum.Material.Grass
				)
			end
		else
			local colors = { C.leafDark, C.leaf, C.leafLight }
			for i = 1, 9 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = if i == 1 then 0 else rng:NextNumber(3, 6)
				local d = if i == 1 then 11 else rng:NextNumber(6, 9)
				ball(
					ctx,
					"Canopy",
					d,
					Vector3.new(math.cos(a) * r, th + rng:NextNumber(0, 5) + (if i == 1 then 3 else 0), math.sin(a) * r),
					colors[1 + (i % 3)],
					Enum.Material.Grass
				)
			end
		end
	elseif string.find(assetId, "^rock_") or string.find(assetId, "^resource_stone") then
		block(
			ctx,
			"Rock",
			Vector3.new(6, 4, 5),
			CFrame.new(0, 1.8, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15),
			C.stone,
			Enum.Material.Slate
		)
		block(
			ctx,
			"Rock",
			Vector3.new(3, 2.5, 3),
			CFrame.new(3, 1.1, 1.5) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0),
			C.stoneLight,
			Enum.Material.Slate
		)
	elseif string.find(assetId, "^resource_wood") then
		for i = 0, 2 do
			log(
				ctx,
				"Log",
				0.7,
				6,
				CFrame.new(0, 0.7 + i * 1.2, (i % 2) * 0.6) * CFrame.Angles(0, math.rad(90), 0),
				C.bark
			)
		end
	elseif string.find(assetId, "^bush") then
		ball(ctx, "Bush", 5, Vector3.new(0, 2, 0), C.leaf, Enum.Material.Grass)
		ball(ctx, "Bush", 3.6, Vector3.new(1.8, 1.6, 0.6), C.leafLight, Enum.Material.Grass)
	else
		block(ctx, "Crate", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), C.wood, Enum.Material.WoodPlanks)
		block(ctx, "CrateBand", Vector3.new(2.1, 0.3, 2.1), CFrame.new(0, 1, 0), C.woodDark, Enum.Material.Wood)
	end
	return ctx.model
end

function Props.prop(assetId: string): Model
	if assetSource then
		local found = assetSource:FindFirstChild(assetId)
		if found and found:IsA("Model") then
			return found:Clone()
		end
	end
	return standIn(assetId)
end

-- ------------------------------------------------------------------ territory markers

function Props.regionMarkers(polygon: { Vector2 }, kingdomColor: Color3): Model
	local ctx = newModel("RegionMarkers", Vector2.new(1, 1))
	local n = #polygon
	for i = 1, n do
		local a, b = polygon[i], polygon[(i % n) + 1]
		for _, t in { 0, 0.5 } do
			local p = a:Lerp(b, t)
			block(
				ctx,
				"MarkerBase",
				Vector3.new(1.6, 0.8, 1.6),
				CFrame.new(p.X, 0.4, p.Y),
				C.stone,
				Enum.Material.Slate
			)
			flagpole(ctx, p.X, 0.8, p.Y, 7, kingdomColor)
		end
	end
	return ctx.model
end

return Props
