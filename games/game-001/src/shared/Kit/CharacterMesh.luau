--!strict
--[[
	Kit/CharacterMesh — citizens built from imported Blender MeshParts, with the part-built rigs as the automatic
	fallback (FL-0135, D-057). Owner: FORGE-02. Data: Kit/CharacterMeshData (generated from art/char_kit/rig.json by
	art/char_kit/rig_to_luau.py). Meshes: ReplicatedStorage.Forge.Assets.CitizenKit (a Folder of MeshParts named by
	piece id, put there by blender/studio/import_char_kit.luau). Procedural animation (Sim/Pose, FORGE-04) is
	untouched: a mesh rig is a segmented rig with the same Motor6D names and axis-aligned joint frames as Kit/Character.

	API
		CharacterMesh.character(kind, job, kingdomColor, look?, kingdom?) -> Model
			What Kit.character is: the mesh rig when the data has pieces AND the asset folder holds every piece this
			assembly needs (right class, a mesh, the declared size); otherwise Character.character's part-built rig,
			whole, never a mix. Never errors on art data: a malformed table is a fallback, not a crash.
		CharacterMesh.available() -> boolean         -- data has pieces, a source is set and it holds a CitizenKit folder
		CharacterMesh.status() -> Status             -- diagnostics: pieces, assemblies, missing pieces, mesh vs fallback builds
		CharacterMesh.setAssetSource(folder?)        -- the Assets folder (Kit.setAssetSource passes it on); CitizenKit is its child
		CharacterMesh.setData(data?)                 -- replaces the committed data (specs, tools); nil restores it
		CharacterMesh.plan(data, kind, job, kingdomColor, look?, kingdom?) -> (Plan?, string?)   -- pure: which pieces, why not
		CharacterMesh.build(data, folder, kind, job, kingdomColor, look?, kingdom?) -> (Model?, string?)   -- folder = CitizenKit
		CharacterMesh.missingPieces(data, folder?) -> { string }   -- piece ids absent or unusable in the CitizenKit folder
		CharacterMesh.FOLDER_NAME ("CitizenKit"), SIZE_TOLERANCE (0.1), MAX_PIECES (16), BUDGET (triangles per style), MAX_MESH_TRIS (20000)

	Rig data (rig.json shape, schema_version 1; CONTRACT in art/char_kit/rig_to_luau.py has the rules the converter checks)
		joints   { [name] = { parent, pos = {x, y, z} } }  rest-pose pivots in rig axes (+X right, +Y up, -Z front, feet at 0).
		         Names are Pose.JOINTS plus "TorsoTool" (the hauler's sack: a Motor6D named "Tool" off the Torso).
		pieces   { [id] = { joint, weld_to?, mirror?, empty?, bbox_center, size, tris, tint, tint_factor?, slot, tags? } }
		assemblies { [key] = { [slot key] = template | { template... } } }   key: a job, "soldier", "soldier_<unit>", "governor"
	A template is a piece id, or an id with ONE variant token chosen from the look (same look, same model):
		%look.<axis>%   axis skin | hair | hairColor | outfit (the look field, spilling over extra variants) or
		                face | boots | acc | weapon (a mix of the whole look): the pieces whose id fits the pattern with
		                digits for the token, in numeric order; the axis picks one
		%kingdom%       crimson | azure | emerald | gold from the kingdom argument or the colour's hue (Parts.hueStyle), else neutral
	Pieces: a base piece (no weld_to) is the rigid body of its joint and carries the Motor6D; every other piece is a Weld-ed
	extra (pieces of slot hair, hat, boot, sleeve, cape, acc are always extras: without weld_to they weld to their joint's
	base piece). `weld_to` is a joint name (its base piece in this assembly) or a piece id (a base piece that the assembly
	swaps for another variant of its joint is followed to the variant). `mirror` pieces stand for both sides
	of a Left/Right joint (the other side is the same mesh at mirrored x: it must be left-right symmetric). `empty` pieces
	have no mesh (a bald variant). Placement: MeshPart.CFrame = CFrame.new(bbox_center); nothing relies on PivotOffset.

	Parts: Root (anchored, invisible, PivotOffset at the feet) + one MeshPart per piece. Base pieces are named after their
	Motor6D ("Torso", "Head", "LeftArm", ...; "Tool"), the "hair" key's piece "Hair" (HairWeld, KitHeadwear), the "acc"
	key's "Accessory" (AccessoryWeld, KitAccessory); other extras take their piece id (plus the joint for mirrored ones) and
	a Weld named "PieceWeld". Every part: CanCollide/CanTouch/CanQuery false, Massless, SmoothPlastic (colour = the baked vertex colours
	or palette texture, if any, times MeshPart.Color; a TextureID (a shared palette texture) is kept as imported, never
	required); CollisionFidelity Box (set by the Studio import, a game script cannot write it). Colour per piece `tint`:
		skin   Character.LOOK_PALETTES.skin[look.skin]        hair   ...hairColor[look.hairColor]
		kingdom shade(kingdomColor, f), attribute KitTint = f (so Kit.setKingdomColor recolours exactly); f = tint_factor
		       or 0.8 (citizens, shifted per individual like the part-built outfits) / 1 (soldiers, governors); sleeves lighter
		cloth  Character.clothColor (the job's dyed panel; slot "leg": its trousers), KitAccent = job
		fixed  white (never tinted)
	Model attributes as Character: KitKind, KitJob, KitLook, KitRootHeight; plus KitMesh = true, KitAssembly = key.
]]

local Character = require("./Character")
local CharacterMeshData = require("./CharacterMeshData")
local Parts = require("./Parts")

local shade = Parts.shade

local CharacterMesh = {}

export type CitizenLook = Character.CitizenLook
export type Item = {
	id: string,
	key: string, -- the assembly key it came from ("torso", "hair", "extras", ...)
	def: any,
	joint: string, -- the joint it rides (a mirrored instance: the other side's)
	mirrored: boolean,
	base: boolean, -- carries a Motor6D
	name: string, -- the part's name
	weld: Item?, -- the item it is Weld-ed to (extras)
}
export type Plan = {
	items: { Item }, -- bases in joint order, then extras by depth
	assembly: string,
	style: string,
	look: CitizenLook,
	kingdomId: string,
	crest: string?,
	tris: number, -- all pieces
	toolTris: number, -- the hand tool or sack and everything welded to it (joint Tool / TorsoTool)
	bodyTris: number, -- the rest
}
export type Status = {
	pieces: number,
	assemblies: number,
	source: boolean,
	folder: boolean,
	available: boolean,
	missing: { string },
	meshBuilds: number,
	fallbackBuilds: number,
	lastFallback: string?,
}

CharacterMesh.FOLDER_NAME = "CitizenKit"
CharacterMesh.SIZE_TOLERANCE = 0.1 -- studs per axis between an imported MeshPart.Size and the data (a unit or axis mistake is far bigger)
CharacterMesh.MAX_PIECES = 16 -- D-057 (5): pieces (draw calls) per assembled rig
-- THE triangle budget per assembled rig (D-057 amendment (15)); the specs and the converter read these numbers and nothing else.
-- Citizens: 1,000 in all, of which the body (everything but the hand tool and its heads) <= 900 and the tool <= 150.
-- Soldiers and rulers carry armour, a crest and a weapon: up to 1,500 in all.
CharacterMesh.BUDGET = table.freeze({
	citizen = table.freeze({ total = 1000, body = 900, tool = 150 }),
	soldier = table.freeze({ total = 1500 }),
	governor = table.freeze({ total = 1500 }),
})
CharacterMesh.MAX_MESH_TRIS = 20000 -- Roblox's per-mesh cap

local JOINT_ORDER = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local REQUIRED = table.freeze(table.clone(JOINT_ORDER))
local TOOL_JOINTS = { Tool = true, TorsoTool = true } -- the hand tool (off the RightArm) or the sack (off the Torso)
local MOTOR_NAME: { [string]: string } = { TorsoTool = "Tool" }
-- the motor tree Sim/Pose assumes (its header): the data may place the joints, never rewire them
local EXPECTED_PARENT: { [string]: string } = {
	Torso = "Root",
	Head = "Torso",
	LeftArm = "Torso",
	RightArm = "Torso",
	LeftLeg = "Torso",
	RightLeg = "Torso",
	Tool = "RightArm",
	TorsoTool = "Torso",
}
local OPPOSITE: { [string]: string } = {
	LeftArm = "RightArm",
	RightArm = "LeftArm",
	LeftLeg = "RightLeg",
	RightLeg = "LeftLeg",
}
local TINTS = { skin = true, hair = true, kingdom = true, cloth = true, fixed = true }
-- Pieces of these slots are never the rigid body of a joint: without a weld_to they are welded to the base piece of their joint.
local EXTRA_SLOTS = { hair = true, hat = true, boot = true, sleeve = true, cape = true, acc = true }
-- default kingdom tint factors (the part-built outfits': citizens muted, soldiers and governors full)
local KINGDOM_TINT = {
	citizen = { default = 0.8, sleeve = 0.72 },
	soldier = { default = 1, sleeve = 0.85 },
	governor = { default = 1, sleeve = 0.9 },
}
local WHITE = Color3.new(1, 1, 1)
local JOB_ALIAS: { [string]: string } = { woodcutter = "lumberjack", lumberjack = "woodcutter" }

local override: any = nil
local assetSource: Instance? = nil
local meshBuilds, fallbackBuilds = 0, 0
local lastFallback: string? = nil

local function activeData(): any
	return override or CharacterMeshData
end

function CharacterMesh.setAssetSource(folder: Instance?)
	assetSource = folder
end

function CharacterMesh.setData(data: any?)
	override = data
	meshBuilds, fallbackBuilds, lastFallback = 0, 0, nil
end

local function isTable(v: any): boolean
	return type(v) == "table"
end

local function str(v: any): string?
	return if type(v) == "string" then v else nil
end

-- What a piece is welded to: its weld_to (a joint name or a piece id), else its own joint for the slots that are always extras;
-- nil = a base piece (the rigid body of its joint, with the Motor6D).
local function weldTarget(def: any): string?
	return str(def.weld_to) or (if EXTRA_SLOTS[def.slot] then str(def.joint) else nil)
end

local function isVec3(v: any): boolean
	return isTable(v) and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

local function vec(v: any): Vector3?
	if isTable(v) and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
		return Vector3.new(v[1], v[2], v[3])
	end
	return nil
end

-- ------------------------------------------------------------------ variants (look -> piece)

local function mix(salt: number, ...: number): number
	local h = salt
	for _, v in { ... } do
		h = (h * 31 + v) % 2147483629
	end
	return h
end

-- 0-based variant index of an axis for `n` variants; nil for an unknown axis. Direct axes follow the look field and spill
-- over the extra variants when there are more than the look has values (6 hair styles in the look, 8 meshes: the other
-- skin/outfit combinations reach the last two); derived axes mix the whole look.
local function axisIndex(l: CitizenLook, axis: string, n: number): number?
	local r = Character.LOOK_RANGES
	local base, range, aux
	if axis == "skin" then
		base, range, aux = l.skin - 1, r.skin, l.hair + l.outfit
	elseif axis == "hair" then
		base, range, aux = l.hair - 1, r.hair, l.skin + l.outfit
	elseif axis == "hairColor" then
		base, range, aux = l.hairColor - 1, r.hairColor, l.skin + l.outfit
	elseif axis == "outfit" then
		base, range, aux = l.outfit - 1, r.outfit, l.skin + l.hairColor
	elseif axis == "face" then
		return mix(11, l.skin, l.hairColor, l.hair, l.outfit) % n
	elseif axis == "boots" then
		return mix(23, l.outfit, l.skin, l.hairColor) % n
	elseif axis == "acc" then
		return mix(37, l.outfit, l.hair, l.skin) % n
	elseif axis == "weapon" then
		return mix(41, l.hair, l.hairColor, l.skin) % n
	else
		return nil
	end
	local spill = if n > range then (aux % math.ceil(n / range)) * range else 0
	return (base + spill) % n
end

local variantCache: { [any]: { [string]: { string } } } = setmetatable({}, { __mode = "k" }) :: any

-- ids that fit prefix <digits> suffix, in numeric order
local function variantsOf(data: any, prefix: string, suffix: string): { string }
	local perData = variantCache[data]
	if perData == nil then
		perData = {}
		variantCache[data] = perData
	end
	local cacheKey = `{prefix}\0{suffix}`
	local cached = perData[cacheKey]
	if cached then
		return cached
	end
	local found: { { id: string, n: number } } = {}
	for id in data.pieces do
		if #id > #prefix + #suffix and string.sub(id, 1, #prefix) == prefix then
			if suffix == "" or string.sub(id, -#suffix) == suffix then
				local middle = string.sub(id, #prefix + 1, #id - #suffix)
				if string.match(middle, "^%d+$") then
					table.insert(found, { id = id, n = tonumber(middle) :: number })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return if a.n ~= b.n then a.n < b.n else a.id < b.id
	end)
	local out = {}
	for _, f in found do
		table.insert(out, f.id)
	end
	perData[cacheKey] = out
	return out
end

type Entry = {
	key: string,
	template: string,
	kingdom: boolean, -- the template has a %kingdom% token
	axis: string?, -- its %look.axis% token, with the text around it
	prefix: string,
	suffix: string,
	resolved: { [string]: { id: string?, list: { string }?, why: string? } }, -- per kingdom id
}

-- An assembly's templates parsed once per data table (the data is read-only once it is in use: generated data is frozen).
local compiledCache: { [any]: { [string]: { entries: { Entry }?, why: string? } } } = setmetatable({}, { __mode = "k" }) :: any

local function sortedKeys(t: { [any]: any }): { string }
	local out = {}
	for k in t do
		if type(k) == "string" then
			table.insert(out, k)
		end
	end
	table.sort(out)
	return out
end

local function compile(data: any, assemblyKey: string, assembly: any): ({ Entry }?, string?)
	local perData = compiledCache[data]
	if perData == nil then
		perData = {}
		compiledCache[data] = perData
	end
	local hit = perData[assemblyKey]
	if hit then
		return hit.entries, hit.why
	end
	local entries: { Entry } = {}
	local failure: string? = nil
	for _, key in sortedKeys(assembly) do
		local value = assembly[key]
		local templates: { any } = if isTable(value) then value else { value }
		for _, template in templates do
			local t = str(template)
			if t == nil then
				failure = `assembly {assemblyKey}.{key}: not a piece id`
				break
			end
			local s, e = string.find(t, "%%look%.%w+%%")
			table.insert(entries, {
				key = key,
				template = t,
				kingdom = string.find(t, "%%kingdom%%") ~= nil,
				axis = if s and e then string.sub(t, s + 6, e - 1) else nil,
				prefix = if s then string.sub(t, 1, s - 1) else t,
				suffix = if e then string.sub(t, e + 1) else "",
				resolved = {},
			})
		end
		if failure then
			break
		end
	end
	perData[assemblyKey] = if failure then { why = failure } else { entries = entries }
	return if failure then nil else entries, failure
end

-- The piece id an entry names for this look and kingdom (nil and why when nothing fits).
local function resolve(data: any, e: Entry, l: CitizenLook, kingdomId: string): (string?, string?)
	local ck = if e.kingdom then kingdomId else ""
	local cached = e.resolved[ck]
	if cached == nil then
		local function expand(x: string): string
			return (string.gsub(x, "%%kingdom%%", kingdomId))
		end
		if e.axis == nil then
			cached = { id = expand(e.template) }
		else
			local list = variantsOf(data, expand(e.prefix), expand(e.suffix))
			cached = if #list == 0 then { why = `no piece fits {e.template}` } else { list = list }
		end
		e.resolved[ck] = cached
	end
	if cached.id then
		return cached.id, nil
	elseif cached.why then
		return nil, cached.why
	end
	local list = cached.list :: { string }
	local idx = axisIndex(l, e.axis :: string, #list)
	if idx == nil then
		return nil, `unknown look axis '{e.axis}' in {e.template}`
	end
	return list[idx + 1], nil
end

-- ------------------------------------------------------------------ plan (pure)

local function assemblyKeys(job: string, style: string): { string }
	local keys = {}
	if style == "governor" then
		table.insert(keys, "governor")
	elseif style == "soldier" then
		if job ~= "soldier" then
			table.insert(keys, `soldier_{job}`)
		end
		table.insert(keys, "soldier")
	else
		table.insert(keys, job)
		if JOB_ALIAS[job] then
			table.insert(keys, JOB_ALIAS[job])
		end
		table.insert(keys, "idle")
	end
	return keys
end

local function partName(key: string, item: Item): string
	if item.base then
		return MOTOR_NAME[item.joint] or item.joint
	elseif key == "hair" then
		return "Hair"
	elseif key == "acc" or key == "accessory" then
		return "Accessory"
	end
	return if item.def.mirror == true then `{item.id}_{item.joint}` else item.id
end

function CharacterMesh.plan(
	data: any,
	kind: string,
	job: string,
	kingdomColor: Color3,
	look: any?,
	kingdom: string?
): (Plan?, string?)
	if not isTable(data) or not isTable(data.pieces) or not isTable(data.assemblies) or not isTable(data.joints) then
		return nil, "no rig data"
	end
	if data.schema_version ~= 1 then
		return nil, `unsupported schema_version {tostring(data.schema_version)}`
	end
	if data.root_height ~= Character.ROOT_HEIGHT then
		return nil, `root_height {tostring(data.root_height)} is not {Character.ROOT_HEIGHT}`
	end
	local l = Character.normalizeLook(look)
	local style = Character.styleOf(kind, job)
	local assembly, assemblyKey
	for _, key in assemblyKeys(job, style) do
		if isTable(data.assemblies[key]) then
			assembly, assemblyKey = data.assemblies[key], key
			break
		end
	end
	if assembly == nil or assemblyKey == nil then
		return nil, `no assembly for {kind}/{job}`
	end
	local crest = if style == "soldier"
			and type(kingdom) == "string"
			and Character.CRESTS[kingdom]
		then kingdom
		else nil
	local kingdomId = if type(kingdom) == "string" and Character.CRESTS[kingdom]
		then kingdom
		else Parts.hueStyle(kingdomColor)

	-- 1. the pieces the assembly names, in a fixed order
	local items: { Item } = {}
	local seen: { [string]: boolean } = {}
	local entries, failure = compile(data, assemblyKey, assembly)
	if entries == nil then
		return nil, failure
	end
	for _, entry in entries do
		local key = entry.key
		local id, why = resolve(data, entry, l, kingdomId)
		if id == nil then
			return nil, `assembly {assemblyKey}.{key}: {why}`
		end
		local def = data.pieces[id]
		if not isTable(def) then
			return nil, `assembly {assemblyKey}.{key}: no piece '{id}'`
		end
		if def.empty ~= true and not seen[id] then
			seen[id] = true
			local joint = str(def.joint)
			if joint == nil or not isTable(data.joints[joint]) then
				return nil, `piece {id}: unknown joint {tostring(def.joint)}`
			end
			if not isVec3(def.bbox_center) or not isVec3(def.size) then
				return nil, `piece {id}: bbox_center and size must be three numbers`
			end
			if TINTS[def.tint] == nil then
				return nil, `piece {id}: unknown tint {tostring(def.tint)}`
			end
			local sides = { false }
			if def.mirror == true then
				if OPPOSITE[joint] == nil then
					return nil, `piece {id}: mirror needs a Left/Right joint, not {joint}`
				end
				table.insert(sides, true)
			end
			for _, mirrored in sides do
				local item: Item = {
					id = id,
					key = key,
					def = def,
					joint = if mirrored then OPPOSITE[joint] else joint,
					mirrored = mirrored,
					base = weldTarget(def) == nil,
					name = "",
				}
				item.name = partName(key, item)
				table.insert(items, item)
			end
		end
	end

	-- 2. one base piece per joint
	local baseOf: { [string]: Item } = {}
	local toolBase: Item? = nil
	for _, item in items do
		if item.base then
			if TOOL_JOINTS[item.joint] then
				if toolBase then
					return nil, `two tools in {assemblyKey}: {toolBase.id} and {item.id}`
				end
				toolBase = item
			else
				if baseOf[item.joint] then
					return nil,
						`two base pieces for {item.joint} in {assemblyKey}: {baseOf[item.joint].id} and {item.id}`
				end
				baseOf[item.joint] = item
			end
		end
	end
	for _, joint in REQUIRED do
		if baseOf[joint] == nil then
			return nil, `no base piece for {joint} in {assemblyKey}`
		end
	end
	for _, item in items do
		if item.base and data.joints[item.joint].parent ~= EXPECTED_PARENT[item.joint] then
			return nil,
				`joint {item.joint}: parent must be {EXPECTED_PARENT[item.joint]}, not {tostring(
					data.joints[item.joint].parent
				)}`
		end
		if item.base and not isVec3(data.joints[item.joint].pos) then
			return nil, `joint {item.joint}: pos must be three numbers`
		end
	end
	local nameTaken: { [string]: boolean } = { Root = true }
	for _, item in items do
		if nameTaken[item.name] then
			return nil, `duplicate part name {item.name} in {assemblyKey}`
		end
		nameTaken[item.name] = true
	end

	-- 3. welds: a joint name -> that joint's base piece (the mirrored instance: the other side's); a piece id -> that piece
	local byId: { [string]: { Item } } = {}
	for _, item in items do
		byId[item.id] = byId[item.id] or {}
		table.insert(byId[item.id], item)
	end
	local function baseForJoint(joint: string): Item?
		return if TOOL_JOINTS[joint] then toolBase else baseOf[joint]
	end
	for _, item in items do
		if not item.base then
			local target = weldTarget(item.def) :: string
			local found: Item? = nil
			if isTable(data.joints[target]) then
				local joint = if item.mirrored and OPPOSITE[target] then OPPOSITE[target] else target
				found = baseForJoint(joint)
			else
				for _, candidate in byId[target] or {} do
					if candidate.mirrored == item.mirrored then
						found = candidate
					end
				end
				-- a base piece this assembly swaps for another variant of its joint (hair welded to "head_01" on a
				-- rig that has head_03): the extra follows the variant
				local named = data.pieces[target]
				if found == nil and isTable(named) and weldTarget(named) == nil and str(named.joint) then
					local joint = named.joint :: string
					found = baseForJoint(if item.mirrored and OPPOSITE[joint] then OPPOSITE[joint] else joint)
				end
			end
			if found == nil then
				return nil, `piece {item.id}: weld target {target} is not in {assemblyKey}`
			end
			if found.joint ~= item.joint and not (TOOL_JOINTS[found.joint] and TOOL_JOINTS[item.joint]) then
				return nil, `piece {item.id} rides {item.joint} but is welded to {found.id} on {found.joint}`
			end
			item.weld = found
		end
	end
	-- no weld cycles; depth orders the extras so a target is placed before what hangs from it
	local depth: { [Item]: number } = {}
	for _, item in items do
		local d, at = 0, item
		while at.weld do
			d += 1
			at = at.weld
			if d > #items then
				return nil, `weld cycle at {item.id}`
			end
		end
		depth[item] = d
	end
	local order: { Item } = {}
	for _, joint in JOINT_ORDER do
		table.insert(order, baseOf[joint])
	end
	if toolBase then
		table.insert(order, toolBase)
	end
	local extras: { Item } = {}
	for _, item in items do
		if not item.base then
			table.insert(extras, item)
		end
	end
	table.sort(extras, function(a, b)
		if depth[a] ~= depth[b] then
			return depth[a] < depth[b]
		end
		return a.name < b.name
	end)
	for _, item in extras do
		table.insert(order, item)
	end

	local bodyTris, toolTris = 0, 0
	for _, item in order do
		if TOOL_JOINTS[item.joint] then
			toolTris += item.def.tris or 0
		else
			bodyTris += item.def.tris or 0
		end
	end
	return {
		items = order,
		assembly = assemblyKey,
		style = style,
		look = l,
		kingdomId = kingdomId,
		crest = crest,
		tris = bodyTris + toolTris,
		toolTris = toolTris,
		bodyTris = bodyTris,
	},
		nil
end

-- ------------------------------------------------------------------ build

-- A pcall because Lune's MeshPart throws on an unset MeshId where Roblox gives "".
local function meshIdOf(piece: Instance): string
	local ok, id = pcall(function()
		return (piece :: any).MeshId
	end)
	return if ok and type(id) == "string" then id else ""
end

-- Why a folder child cannot stand in for the piece (nil = usable).
local function unusable(piece: Instance?, id: string, def: any): string?
	if piece == nil then
		return `{id}: not in the folder`
	elseif not piece:IsA("MeshPart") then
		return `{id}: a {piece.ClassName}, not a MeshPart`
	elseif meshIdOf(piece) == "" then
		return `{id}: no MeshId (the import did not upload its mesh)`
	end
	local want = vec(def.size)
	if want == nil then
		return `{id}: the data has no size`
	end
	local have = (piece :: MeshPart).Size
	local tol = CharacterMesh.SIZE_TOLERANCE
	if math.abs(have.X - want.X) > tol or math.abs(have.Y - want.Y) > tol or math.abs(have.Z - want.Z) > tol then
		return `{id}: imported size {have.X}, {have.Y}, {have.Z} is not the data's {want.X}, {want.Y}, {want.Z}`
	end
	return nil
end

function CharacterMesh.missingPieces(data: any, folder: Instance?): { string }
	local out = {}
	if not isTable(data) or not isTable(data.pieces) then
		return out
	end
	for _, id in sortedKeys(data.pieces) do
		local def = data.pieces[id]
		if isTable(def) and def.empty ~= true then
			local piece = if folder then folder:FindFirstChild(id) else nil
			if unusable(piece, id, def) then
				table.insert(out, id)
			end
		end
	end
	return out
end

local function motor(part0: BasePart, part1: BasePart, name: string, jointWorld: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * jointWorld
	m.C1 = part1.CFrame:Inverse() * jointWorld
	m.Parent = part0
	return m
end

local function kingdomFactor(style: string, def: any, l: CitizenLook): number
	local f = def.tint_factor
	if type(f) ~= "number" then
		local row = KINGDOM_TINT[style] or KINGDOM_TINT.citizen
		f = if def.slot == "sleeve" then row.sleeve else row.default
	end
	if style == "citizen" and f <= 1 then
		f = math.clamp(f + Character.tintShift(l), 0.5, 1)
	end
	return f
end

function CharacterMesh.build(
	data: any,
	folder: Instance?,
	kind: string,
	job: string,
	kingdomColor: Color3,
	look: any?,
	kingdom: string?
): (Model?, string?)
	local plan, why = CharacterMesh.plan(data, kind, job, kingdomColor, look, kingdom)
	if plan == nil then
		return nil, why
	end
	if folder == nil then
		return nil, "no CitizenKit folder"
	end
	local templates: { [string]: MeshPart } = {}
	for _, item in plan.items do
		if templates[item.id] == nil then
			local piece = folder:FindFirstChild(item.id)
			local bad = unusable(piece, item.id, item.def)
			if bad then
				return nil, bad
			end
			templates[item.id] = piece :: MeshPart
		end
	end

	local l = plan.look
	local skin = Character.LOOK_PALETTES.skin[l.skin]
	local hairColor = Character.LOOK_PALETTES.hairColor[l.hairColor]

	local model = Instance.new("Model")
	model.Name = `{kind}_{job}`
	model:SetAttribute("KitKind", kind)
	model:SetAttribute("KitJob", job)
	model:SetAttribute("KitLook", Character.lookKey(l, plan.crest))
	model:SetAttribute("KitRootHeight", Character.ROOT_HEIGHT)
	model:SetAttribute("KitMesh", true)
	model:SetAttribute("KitAssembly", plan.assembly)

	local rootHeight = Character.ROOT_HEIGHT
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, rootHeight, 0)
	root.Color = Parts.C.cloth
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -rootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root

	local built: { [Item]: BasePart } = {}
	local partOfJoint: { [string]: BasePart } = {}
	for _, item in plan.items do
		local def = item.def
		local part = templates[item.id]:Clone()
		for _, child in part:GetChildren() do
			-- nothing from the import rides along: a SurfaceAppearance (PBR) goes too (D-057 (17)); the colour comes from the baked
			-- vertex colours, an optional shared palette TextureID and MeshPart.Color, and scripts, attachments, constraints and the like go
			child:Destroy()
		end
		-- attributes and tags on the imported piece itself go too (the Kit sets its own below)
		for name in part:GetAttributes() do
			part:SetAttribute(name, nil)
		end
		for _, tag in part:GetTags() do
			part:RemoveTag(tag)
		end
		local centre = vec(def.bbox_center) :: Vector3
		part.Name = item.name
		part.CFrame = CFrame.new(if item.mirrored then -centre.X else centre.X, centre.Y, centre.Z)
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = true
		part.Transparency = 0
		part.Reflectance = 0
		part.Material = Enum.Material.SmoothPlastic
		-- CollisionFidelity is not set here: a game script cannot write it (Plugin security); the Studio import sets Box
		-- (blender/studio/import_char_kit.luau) and the saved Forge.Assets pieces carry it

		local tint = def.tint
		if tint == "skin" then
			part.Color = skin
		elseif tint == "hair" then
			part.Color = hairColor
		elseif tint == "kingdom" then
			local f = kingdomFactor(plan.style, def, l)
			part.Color = shade(kingdomColor, f)
			part:SetAttribute("KitTint", f)
		elseif tint == "cloth" then
			part.Color = Character.clothColor(job, tostring(def.slot), l)
			if plan.style == "citizen" and job ~= "idle" then
				part:SetAttribute("KitAccent", job)
			end
		else
			part.Color = WHITE
		end
		part:SetAttribute("KitPiece", item.id)
		part:SetAttribute("KitSlot", tostring(def.slot))
		if item.name == "Hair" then
			part:SetAttribute("KitHeadwear", item.id)
		elseif item.name == "Accessory" then
			part:SetAttribute("KitAccessory", item.id)
		elseif item.base and TOOL_JOINTS[item.joint] then
			part:SetAttribute("KitTool", item.id)
		end
		if isTable(def.tags) and table.find(def.tags, "detail") then
			part:SetAttribute(Character.DETAIL_ATTRIBUTE, true)
		end
		part.Parent = model
		built[item] = part

		if item.base then
			local jointDef = data.joints[item.joint]
			local parentJoint = EXPECTED_PARENT[item.joint]
			local part0 = if parentJoint == "Root" then root else partOfJoint[parentJoint]
			assert(part0 ~= nil, `joint {item.joint}: parent {parentJoint} has no base piece`)
			partOfJoint[item.joint] = part
			motor(part0, part, MOTOR_NAME[item.joint] or item.joint, CFrame.new(vec(jointDef.pos) :: Vector3))
		else
			local target = built[item.weld :: Item]
			local weld = Instance.new("Weld")
			weld.Name = if item.name == "Hair"
				then "HairWeld"
				elseif item.name == "Accessory" then "AccessoryWeld"
				else "PieceWeld"
			weld.Part0 = target
			weld.Part1 = part
			weld.C0 = target.CFrame:Inverse() * part.CFrame
			weld.C1 = CFrame.new()
			weld.Parent = part
		end
	end
	return model, nil
end

-- ------------------------------------------------------------------ the Kit entry point

local function folderOf(source: Instance?): Instance?
	return if source then source:FindFirstChild(CharacterMesh.FOLDER_NAME) else nil
end

function CharacterMesh.available(): boolean
	local data = activeData()
	return isTable(data) and isTable(data.pieces) and next(data.pieces) ~= nil and folderOf(assetSource) ~= nil
end

function CharacterMesh.status(): Status
	local data = activeData()
	local folder = folderOf(assetSource)
	local pieces, assemblies = 0, 0
	if isTable(data) then
		for _ in data.pieces or {} do
			pieces += 1
		end
		for _ in data.assemblies or {} do
			assemblies += 1
		end
	end
	return {
		pieces = pieces,
		assemblies = assemblies,
		source = assetSource ~= nil,
		folder = folder ~= nil,
		available = pieces > 0 and folder ~= nil,
		missing = if pieces > 0 then CharacterMesh.missingPieces(data, folder) else {},
		meshBuilds = meshBuilds,
		fallbackBuilds = fallbackBuilds,
		lastFallback = lastFallback,
	}
end

function CharacterMesh.character(
	kind: string,
	job: string,
	kingdomColor: Color3,
	look: CitizenLook?,
	kingdom: string?
): Model
	local data = activeData()
	local folder = folderOf(assetSource)
	if folder ~= nil and isTable(data) and isTable(data.pieces) and next(data.pieces) ~= nil then
		local ok, model, why = pcall(CharacterMesh.build, data, folder, kind, job, kingdomColor, look, kingdom)
		if ok and model then
			meshBuilds += 1
			return model
		end
		lastFallback = if ok then why else `error: {tostring(model)}`
	end
	fallbackBuilds += 1
	return Character.character(kind, job, kingdomColor, look, kingdom)
end

return CharacterMesh
