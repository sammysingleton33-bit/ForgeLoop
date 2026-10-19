--!strict
--[[
	Kit/EnvMesh — imported nature meshes behind Kit.prop (FL-0136, D-057 (18)-(20)). Owner: FORGE-02.
	Data: Kit/EnvMeshData (generated from art/env_kit/env.json by art/env_kit/env_to_luau.py). Meshes: Models named by asset id in
	ReplicatedStorage.Forge.Assets (or its EnvKit folder), made from the Blender MeshParts by blender/studio/import_env_kit.luau.

	Kit.prop(assetId) stays "a Model in the asset source -> a clone, else the part-built stand-in" (Kit/Props). For an asset
	id that EnvMeshData lists, the clone goes through EnvMesh.accept first, which makes it behave like a stand-in for
	everything that places and reads props (WorldService.placeModel/decorate, the keep-out and clearance specs):
	  * shape: a Model with an invisible anchored Root PrimaryPart whose PivotOffset puts the pivot at the BASE CENTRE (y = 0),
	    and its MeshParts at the data's bbox_center (relative to that pivot). Anything else in the clone is deleted: scripts,
	    SurfaceAppearance, Decals, Welds, nested Models and Folders (the MeshParts are lifted out first), non-mesh parts,
	    attributes and tags. Nothing in an imported Model can run, load or carry state.
	  * physics as the stand-ins: Root and MeshParts are Anchored, CanTouch false, Massless, MeshParts CanCollide false and CanQuery
	    true (so selection and placement raycasts hit their shape; the shape is the Body's CollisionFidelity, which the Studio import
	    sets to Hull in the open place and which a game script cannot manipulate; the API dump lists it as not saved, so a saved or
	    built place is expected, unverified, to have Default, the precise shape: a cost in physics memory, not a behaviour), Root invisible. What
	    the part-built props block (trunks, rocks, bushes, low parts: WorldService.decorate lets only parts above
	    COLLIDE_HEIGHT through) is an invisible solid Collider Part from the
	    data (`collider`, used as given, else a family default: trees a trunk, rocks and haystacks 80 % of each footprint axis,
	    bushes 60 % of each axis, fences their length; flowers and crops block nothing); the defaults are at most SOLID_HEIGHT
	    (7, = WorldService.COLLIDE_HEIGHT) tall, a data collider over 7 is only warned about by the converter.
	  * SIZE SANITY: the MeshParts' bounding box in the pivot frame must match the data's size (per axis within
	    max(0.1, 0.5 %)) and centre (0.25). A Model that does not (a wrong import scale or axes, a moved pivot, a mesh gone)
	    is rejected: Kit.prop builds the stand-in instead, and the reason is logged ONCE per asset id (never an error).
	Ids the data does not list pass through Kit.prop unchanged (a Model in the folder is cloned as is, nothing is checked).

	API
		EnvMesh.accept(assetId, clone) -> (Model?, string?)   -- the clone made ready, or nil + why (the caller builds the stand-in)
		EnvMesh.has(assetId) -> boolean                       -- the data lists this id
		EnvMesh.find(source, assetId) -> Instance?            -- source[assetId] or source.EnvKit[assetId]
		EnvMesh.measure(model) -> (center: Vector3, size: Vector3)?   -- MeshPart bounds in the pivot frame
		EnvMesh.status() -> { props, accepted, rejected: { [id]: why } }
		EnvMesh.setData(data?), EnvMesh.setLogger(fn?)        -- specs and tools; nil restores
		EnvMesh.FOLDER_NAME ("EnvKit"), SIZE_TOLERANCE, REL_TOLERANCE, CENTER_TOLERANCE, SOLID_HEIGHT, FAMILIES, BUDGET
	Data (env.json shape): props = { [assetId] = { family, bbox_center, size, tris, tint = "fixed", standin_size, node,
	collider?, fit_note? } }, all in Roblox rig axes (+X right, +Y up, -Z front), base at y = 0, bbox_center from the base centre.
]]

local EnvMeshData = require("./EnvMeshData")

local EnvMesh = {}

export type Status = { props: number, accepted: number, rejected: { [string]: string } }

EnvMesh.FOLDER_NAME = "EnvKit"
EnvMesh.SIZE_TOLERANCE = 0.1 -- studs, or REL_TOLERANCE of the dimension if larger
EnvMesh.REL_TOLERANCE = 0.005
EnvMesh.CENTER_TOLERANCE = 0.25
EnvMesh.SOLID_HEIGHT = 7 -- WorldService.COLLIDE_HEIGHT: only parts below it block movement
EnvMesh.FAMILIES = table.freeze({ "tree", "bush", "rock", "flower", "crop", "haystack", "fence" })
-- Triangles per prop (D-057 (19): trees 300-900, bushes/rocks/flowers 40-400; crops, haystacks and fences are FORGE-02's
-- proposal, the decision is silent). The specs and env_to_luau.py read these and nothing else (--print-budget).
EnvMesh.BUDGET = table.freeze({
	tree = table.freeze({ min = 300, max = 900 }),
	bush = table.freeze({ min = 40, max = 400 }),
	rock = table.freeze({ min = 40, max = 400 }),
	flower = table.freeze({ min = 40, max = 400 }),
	crop = table.freeze({ min = 40, max = 1500 }),
	haystack = table.freeze({ min = 40, max = 600 }),
	fence = table.freeze({ min = 40, max = 600 }),
})
EnvMesh.MAX_MESH_TRIS = 20000 -- Roblox's per-mesh cap

local override: any = nil
local logger: ((string) -> ())? = nil
local logged: { [string]: boolean } = {}
local rejected: { [string]: string } = {}
local accepted = 0

local function activeData(): any
	return override or EnvMeshData
end

local function propsOf(data: any): { [string]: any }
	local props = if type(data) == "table" then data.props else nil
	return if type(props) == "table" then props else {}
end

function EnvMesh.setData(data: any?)
	override = data
	logged, rejected, accepted = {}, {}, 0
end

function EnvMesh.setLogger(fn: ((string) -> ())?)
	logger = fn
end

function EnvMesh.has(assetId: string): boolean
	return propsOf(activeData())[assetId] ~= nil
end

function EnvMesh.status(): Status
	local n = 0
	for _ in propsOf(activeData()) do
		n += 1
	end
	return { props = n, accepted = accepted, rejected = table.clone(rejected) }
end

-- source[assetId], or source.EnvKit[assetId] (the folder the Studio import script fills and the .rbxm carries)
function EnvMesh.find(source: Instance?, assetId: string): Instance?
	if source == nil then
		return nil
	end
	local direct = source:FindFirstChild(assetId)
	if direct then
		return direct
	end
	local folder = source:FindFirstChild(EnvMesh.FOLDER_NAME)
	return if folder then folder:FindFirstChild(assetId) else nil
end

local function isVec3(v: any): boolean
	return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

-- A pcall because Lune's MeshPart throws on an unset MeshId where Roblox gives "".
local function meshIdOf(part: Instance): string
	local ok, id = pcall(function()
		return (part :: any).MeshId
	end)
	return if ok and type(id) == "string" then id else ""
end

-- Bounds of the MeshParts' boxes in the pivot frame (centre, size), nil without a PrimaryPart or a MeshPart.
function EnvMesh.measure(model: Model): (Vector3?, Vector3?)
	local root = model.PrimaryPart
	if root == nil then
		return nil, nil
	end
	local pivot = root.CFrame * root.PivotOffset
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	local any = false
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			any = true
			local h = (d :: MeshPart).Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w =
							pivot:PointToObjectSpace((d :: MeshPart).CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						mn = mn:Min(w)
						mx = mx:Max(w)
					end
				end
			end
		end
	end
	if not any then
		return nil, nil
	end
	return (mn + mx) / 2, mx - mn
end

-- Solid box (w, h, d) at the base centre for a prop: the data's `collider`, else the family default; nil = blocks nothing.
local function colliderOf(def: any): Vector3?
	if def.collider == false then
		return nil
	elseif isVec3(def.collider) then
		return Vector3.new(def.collider[1], def.collider[2], def.collider[3])
	end
	local s = def.size
	local family = def.family
	local top = EnvMesh.SOLID_HEIGHT
	if family == "tree" then
		local w = math.clamp(0.2 * math.max(s[1], s[3]), 1.4, 3.4) -- a trunk, not the canopy
		return Vector3.new(w, math.min(top, s[2]), w)
	elseif family == "rock" or family == "haystack" then
		return Vector3.new(0.8 * s[1], math.min(top, s[2]), 0.8 * s[3])
	elseif family == "bush" then
		return Vector3.new(0.6 * s[1], math.min(3, s[2]), 0.6 * s[3])
	elseif family == "fence" then
		return Vector3.new(s[1], math.min(4, s[2]), math.max(s[3], 0.8))
	end
	return nil -- flowers and crops: walkable
end
EnvMesh._colliderOf = colliderOf

local function clearState(inst: Instance)
	for name in inst:GetAttributes() do
		inst:SetAttribute(name, nil)
	end
	pcall(function()
		for _, tag in inst:GetTags() do
			inst:RemoveTag(tag)
		end
	end)
end

local function tolerance(dimension: number): number
	return math.max(EnvMesh.SIZE_TOLERANCE, EnvMesh.REL_TOLERANCE * dimension)
end

-- Makes the clone of a Forge.Assets Model a prop (see the header). Returns nil and why when it cannot be one.
local function prepare(assetId: string, def: any, model: Model): (Model?, string?)
	local root = model.PrimaryPart
	if root == nil or root:IsA("MeshPart") or not root:IsA("BasePart") then
		return nil, "it has no PrimaryPart that is a plain Part (the Root)"
	end
	if not (isVec3(def.size) and isVec3(def.bbox_center)) then
		return nil, "the data has no size or bbox_center"
	end
	local meshes: { MeshPart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(meshes, d :: MeshPart)
		end
	end
	if #meshes == 0 then
		return nil, "it has no MeshPart"
	end
	for _, mesh in meshes do
		if meshIdOf(mesh) == "" then
			return nil, `{mesh.Name} has no MeshId (its mesh was not uploaded)`
		end
	end
	-- the geometry only: lift the Root and the MeshParts out of any nesting, delete everything else
	local keep: { [Instance]: boolean } = { [root] = true }
	if root.Parent ~= model then
		root.Parent = model
	end
	for _, mesh in meshes do
		keep[mesh] = true
		if mesh.Parent ~= model then
			mesh.Parent = model
		end
	end
	for _, d in model:GetDescendants() do
		if not keep[d] then
			d:Destroy()
		end
	end
	for _, d in model:GetChildren() do
		if not keep[d] then
			d:Destroy()
		end
	end
	clearState(model)
	clearState(root)
	for _, mesh in meshes do
		clearState(mesh)
	end

	-- size sanity: the bounds the MeshParts really have against the data
	local center, size = EnvMesh.measure(model)
	if center == nil or size == nil then
		return nil, "it has no measurable MeshPart"
	end
	local want, at = def.size, def.bbox_center
	for i, axis in { "X", "Y", "Z" } do
		local got = (size :: any)[axis]
		if math.abs(got - want[i]) > tolerance(want[i]) then
			return nil,
				`size {string.format("%.2f x %.2f x %.2f", size.X, size.Y, size.Z)} is not the data's {string.format(
					"%.2f x %.2f x %.2f",
					want[1],
					want[2],
					want[3]
				)}`
		end
		if math.abs((center :: any)[axis] - at[i]) > EnvMesh.CENTER_TOLERANCE then
			return nil,
				`centre {string.format("%.2f, %.2f, %.2f", center.X, center.Y, center.Z)} is not the data's {string.format(
					"%.2f, %.2f, %.2f",
					at[1],
					at[2],
					at[3]
				)} (is the pivot at the base centre?)`
		end
	end

	-- physics and look like the stand-ins (Parts.newModel / Parts.finish)
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Transparency = 1
	root.CastShadow = false
	root.Massless = true
	for _, mesh in meshes do
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = true
		mesh.Massless = true
		mesh.CastShadow = true
		mesh.Transparency = 0
		mesh.Reflectance = 0
		mesh.Material = Enum.Material.SmoothPlastic
		mesh.Color = Color3.new(1, 1, 1) -- the colours are baked into the mesh (tint "fixed")
		-- CollisionFidelity is not set here: scripts cannot manipulate it at runtime (API reference) and the API dump lists it as not
		-- saved and not replicated. The Studio import sets Hull on every Body (blender/studio/import_env_kit.luau) in the open place; a saved
		-- or built place is expected (unverified) to have Default. Nothing here sets or reads it, but the Body is CanQuery true, so selection
		-- and placement raycasts hit whichever shape it has (Default = precise, a cost in physics memory; the owner reads it in Render Stats).
	end
	local box = colliderOf(def)
	if box then
		local pivot = root.CFrame * root.PivotOffset
		local collider = Instance.new("Part")
		collider.Name = "Collider"
		collider.Size = box
		collider.CFrame = pivot * CFrame.new(0, box.Y / 2, 0)
		collider.Anchored = true
		collider.CanCollide = true
		collider.CanTouch = false
		collider.CanQuery = false -- an invisible solid must not catch placement or selection raycasts
		collider.CastShadow = false
		collider.Massless = true
		collider.Transparency = 1
		collider.Parent = model
	end
	model.Name = assetId
	model:SetAttribute("KitEnvMesh", true)
	return model, nil
end

local function log(assetId: string, why: string)
	if logged[assetId] then
		return
	end
	logged[assetId] = true
	local message = `Kit.prop: the imported {assetId} is not used ({why}); building the stand-in`
	if logger then
		logger(message)
	elseif type(warn :: any) == "function" then
		warn(message)
	end
end

function EnvMesh.accept(assetId: string, clone: Model?): (Model?, string?)
	local def = propsOf(activeData())[assetId]
	if def == nil then
		return clone, nil
	end
	if clone == nil then -- the template is not Archivable: it clones to nil
		local reason = "the template cannot be cloned (Archivable is false)"
		rejected[assetId] = reason
		log(assetId, reason)
		return nil, reason
	end
	local ok, model, why
	if type(def) == "table" then
		ok, model, why = pcall(prepare, assetId, def, clone)
	else
		ok, model, why = true, nil, "its data entry is not a table"
	end
	if ok and model then
		accepted += 1
		return model, nil
	end
	local reason = if ok then tostring(why) else `error: {tostring(model)}`
	clone:Destroy()
	rejected[assetId] = reason
	log(assetId, reason)
	return nil, reason
end

return EnvMesh
