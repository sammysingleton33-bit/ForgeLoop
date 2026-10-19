--!strict
--[[
	Arena/Figures — what the Crown Arena puts in the world besides the venue (FL-0140, CONTRACTS G12.6): the body of an AI
	champion, the loadout gear every champion wears, and the venue's dress in the two qualifiers' colours. ArenaService
	calls it; it keeps what it made so that one `clear()` takes all of it away again (the crowning, a cancel, destroy).
	Owner: FORGE-01. The Kit is injected (`deps.kit`) so a spec can watch the calls instead of building parts.

		Figures.new({ kit, parent, new, collection?, log? }) -> Figures
			kit      Kit-shaped: character(kind, job, color, look, kingdom), weapon(name, color), armour(name, color),
			         arenaDress(model, colorA?, colorB?)
			parent   where the AI figures live (a Folder "ArenaFigures" is made in it on the first figure)
			new      env.newInstance (Instance.new in the game): how Folder and Weld are made
			collection  env.CollectionService: tags the AI figure `ArenaChampion` (CONTRACTS G12.6), with the attribute
			         ArenaSide = "a" | "b" (the DuelRunner side), so a client can find and pose it
		figures:spawn(userId, spec) -> Model?
			an AI champion's body: Kit.character("governor") in the kingdom colour with the governor look, anchored on its
			mark (spec.cframe = the feet), the loadout's armour and weapon worn. nil when the Kit refuses.
			spec { side, color, kingdom, look?, weapon, armour, cframe }
		figures:wear(character, spec)
			the loadout gear on a human champion's own character: the armour as Accessories (Humanoid:AddAccessory), the
			weapon as a Tool in the hand (Humanoid:EquipTool). spec { color, weapon, armour }
		figures:poseOf(userId) -> { x, z, fx, fz }?
			where an AI figure stands and which way it faces (the same shape as ArenaService:poseOf); nil for anyone else
		figures:approach(userId, tx, tz, step, standoff, ring?) -> boolean
			walks an AI figure up to `step` studs towards (tx, tz), stopping `standoff` short, turned to face it, and
			never beyond ring { x, z, radius }
		figures:dress(arenaModel, colorA?, colorB?)
			Kit.arenaDress; `reset()` puts the venue back to neutral. Both remember nothing: ArenaService owns the model.
		figures:clear()
			destroys every figure and every piece of gear made, and forgets them (the venue is reset by `reset`)

	The rig has no Humanoid (Kit.character), so its armour cannot use Humanoid:AddAccessory: each Accessory's Handle holds an
	Attachment named for the body point it fits (HatAttachment, BodyFrontAttachment, BodyBackAttachment, Left/RightCollar
	Attachment) and is welded to the rig's Head or Torso at that point, measured from the part's size. The weapon replaces the
	rig's own spear: it is welded at the right fist at the plain Grip rest (the blade square to the arm, as an equipped Tool sits in a human's hand: FORGE-04's wrist poses assume it). Unverified in Studio: how this looks (the fits are
	computed, not seen).
]]

local Figures = {}
Figures.__index = Figures

-- The venue's marks are a character's root height above the floor (Kit/Arena SPAWN_HEIGHT); a rig's pivot is at its feet.
Figures.FEET_BELOW_MARK = 3
-- Where a colour is unknown (a kingdom the Kingdoms config does not list): Kit.NEUTRAL_COLOR's value.
Figures.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)

export type Spec = {
	side: string,
	color: Color3,
	kingdom: string?,
	look: any?,
	weapon: string,
	armour: string,
	cframe: CFrame?,
}

function Figures.new(deps: {
	kit: any,
	parent: any,
	new: (string) -> any,
	collection: any?,
	log: ((string, string, any?) -> ())?,
})
	local self = setmetatable({}, Figures)
	self._kit = deps.kit
	self._parent = deps.parent
	self._new = deps.new
	self._collection = deps.collection
	self._log = deps.log
	self._folder = nil :: any
	self._figures = {} :: { [number]: any }
	self._gear = {} :: { any }
	return self
end

function Figures:_warn(message: string, fields: any?)
	if self._log then
		self._log("warn", message, fields)
	end
end

local function partNamed(model: any, name: string): any?
	for _, d in model:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

-- Where on the rig an armour attachment sits: the part and the offset from its centre, from the part's size.
local function fitOf(model: any, attachment: string): (any?, CFrame?)
	if attachment == "HatAttachment" then
		local head = partNamed(model, "Head")
		return head, if head then CFrame.new(0, head.Size.Y / 2, 0) else nil
	end
	local torso = partNamed(model, "Torso")
	if torso == nil then
		return nil, nil
	end
	local size = torso.Size
	if attachment == "BodyFrontAttachment" then
		return torso, CFrame.new(0, 0, -size.Z / 2)
	elseif attachment == "BodyBackAttachment" then
		return torso, CFrame.new(0, 0, size.Z / 2)
	elseif attachment == "LeftCollarAttachment" then
		return torso, CFrame.new(-size.X / 2, size.Y / 2, 0)
	elseif attachment == "RightCollarAttachment" then
		return torso, CFrame.new(size.X / 2, size.Y / 2, 0)
	end
	return nil, nil
end

local function weld(new: (string) -> any, part0: any, part1: any, c0: CFrame, c1: CFrame?)
	local w = new("Weld")
	w.Name = "ArenaGearWeld"
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	if c1 ~= nil then
		w.C1 = c1
	end
	w.Parent = part1
end

-- A Kit rig's pivot is the feet: Root.CFrame * Root.PivotOffset (Root stands 3.2 above them). Model:GetPivot and
-- Model:PivotTo follow that rule in the engine; where a model cannot (the headless mock), the same rule is applied by hand.
local function pivotOf(model: any): CFrame
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if ok and pivot ~= nil then
		return pivot
	end
	local root = model.PrimaryPart
	local offsetOk, offset = pcall(function()
		return root.PivotOffset
	end)
	return root.CFrame * (if offsetOk and offset ~= nil then offset else CFrame.new())
end

local function pivotTo(model: any, cframe: CFrame)
	local placed = pcall(function()
		model:PivotTo(cframe)
	end)
	if placed then
		return
	end
	local root = model.PrimaryPart
	local offsetOk, offset = pcall(function()
		return root.PivotOffset
	end)
	root.CFrame = cframe * (if offsetOk and offset ~= nil then offset:Inverse() else CFrame.new())
end

-- Welds an armour Accessory onto a rig at the point its Handle's Attachment names.
function Figures:_fitArmour(model: any, accessory: any): boolean
	local handle = accessory:FindFirstChild("Handle")
	if handle == nil then
		return false
	end
	for _, child in handle:GetChildren() do
		if child:IsA("Attachment") then
			local part, offset = fitOf(model, child.Name)
			if part ~= nil and offset ~= nil then
				weld(self._new, part, handle, offset * child.CFrame:Inverse())
				accessory.Parent = model
				return true
			end
		end
	end
	return false
end

-- Takes the rig's own held item off (the soldier's spear, the governor's staff and orb) but keeps its Tool part: the
-- rig's `Tool` joint (Sim/Pose.JOINTS) drives that part, so the loadout weapon welded to it follows the pose. The part goes
-- invisible and every part welded to it (the spearhead, the pennant, the orb) is destroyed. Returns the Tool part, if any.
local function stripOwnWeapon(model: any): any?
	local toolPart = partNamed(model, "Tool")
	if toolPart == nil then
		return nil
	end
	local doomed = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") then
			if d.Part0 == toolPart and d.Part1 ~= nil then
				table.insert(doomed, d.Part1)
			elseif d.Part1 == toolPart and d.Part0 ~= nil then
				table.insert(doomed, d.Part0)
			end
		end
	end
	for _, d in doomed do
		d:Destroy()
	end
	toolPart.Transparency = 1
	return toolPart
end

function Figures:_fitWeapon(model: any, tool: any): boolean
	local handle = tool:FindFirstChild("Handle")
	local fist = partNamed(model, "RightArm")
	if handle == nil or fist == nil then
		return false
	end
	-- the loadout weapon rides the Tool part (the arm if the rig has none), at the fist, at the Grip rest
	local toolPart = stripOwnWeapon(model)
	local carrier = toolPart or fist
	local atFist = fist.CFrame * CFrame.new(0, -fist.Size.Y / 2, 0)
	-- the Tool is modelled in grip space and `Grip` puts it right in a hand: the weld's C1, as an equipped Tool's RightGrip has it
	local gripOk, grip = pcall(function()
		return tool.Grip
	end)
	weld(self._new, carrier, handle, carrier.CFrame:Inverse() * atFist, if gripOk then grip else nil)
	tool.Parent = model
	return true
end

function Figures:spawn(userId: number, spec: Spec): any?
	local kit = self._kit
	local ok, model = pcall(kit.character, "governor", "idle", spec.color, spec.look, spec.kingdom)
	if not ok or model == nil then
		self:_warn("Figures: the AI champion figure could not be built", { error = tostring(model) })
		return nil
	end
	model.Name = `ArenaChampion{userId}`
	model:SetAttribute("ArenaSide", spec.side)
	if self._collection ~= nil then
		pcall(function()
			self._collection:AddTag(model, "ArenaChampion")
		end)
	end
	if self._folder == nil then
		local folder = self._new("Folder")
		folder.Name = "ArenaFigures"
		folder.Parent = self._parent
		self._folder = folder
	end
	local cframe = spec.cframe
	if cframe ~= nil then
		pivotTo(model, cframe)
	end
	model.Parent = self._folder
	local armourOk, accessories = pcall(kit.armour, spec.armour, spec.color)
	if armourOk then
		for _, accessory in accessories do
			if self:_fitArmour(model, accessory) then
				table.insert(self._gear, accessory)
			else
				accessory:Destroy()
			end
		end
	else
		self:_warn("Figures: the armour could not be built", { armour = spec.armour, error = tostring(accessories) })
	end
	local weaponOk, tool = pcall(kit.weapon, spec.weapon, spec.color)
	if weaponOk and tool ~= nil then
		if self:_fitWeapon(model, tool) then
			table.insert(self._gear, tool)
		else
			tool:Destroy()
		end
	else
		self:_warn("Figures: the weapon could not be built", { weapon = spec.weapon, error = tostring(tool) })
	end
	self._figures[userId] = model
	return model
end

function Figures:wear(character: any, spec: { color: Color3, weapon: string, armour: string })
	local kit = self._kit
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local armourOk, accessories = pcall(kit.armour, spec.armour, spec.color)
	if armourOk then
		for _, accessory in accessories do
			local added = pcall(function()
				humanoid:AddAccessory(accessory)
			end)
			if added then
				table.insert(self._gear, accessory)
			else
				accessory:Destroy()
			end
		end
	else
		self:_warn("Figures: the armour could not be built", { armour = spec.armour, error = tostring(accessories) })
	end
	local weaponOk, tool = pcall(kit.weapon, spec.weapon, spec.color)
	if weaponOk and tool ~= nil then
		local equipped = pcall(function()
			humanoid:EquipTool(tool)
		end)
		if not equipped then
			tool.Parent = character
		end
		table.insert(self._gear, tool)
	else
		self:_warn("Figures: the weapon could not be built", { weapon = spec.weapon, error = tostring(tool) })
	end
end

function Figures:poseOf(userId: number): { x: number, z: number, fx: number, fz: number }?
	local model = self._figures[userId]
	if model == nil then
		return nil
	end
	local ok, pose = pcall(function()
		local root = model.PrimaryPart or model:FindFirstChild("Root")
		if root == nil then
			return nil
		end
		local position, look = root.CFrame.Position, root.CFrame.LookVector
		local length = math.sqrt(look.X * look.X + look.Z * look.Z)
		if length < 1e-6 then
			return { x = position.X, z = position.Z, fx = 0, fz = 0 }
		end
		return { x = position.X, z = position.Z, fx = look.X / length, fz = look.Z / length }
	end)
	return if ok then pose else nil
end

-- Walks an AI figure up to `step` studs towards (tx, tz), stopping `standoff` studs short of it, and turns it to face
-- there. The duel measures reach and facing from where the figure stands, so an AI champion has to close in on its
-- opponent as a player would. Returns true when it moved.
function Figures:approach(
	userId: number,
	tx: number,
	tz: number,
	step: number,
	standoff: number,
	ring: { x: number, z: number, radius: number }?
): boolean
	local model = self._figures[userId]
	local root = if model then model.PrimaryPart else nil
	if root == nil then
		return false
	end
	local ok, moved = pcall(function()
		local position = pivotOf(model).Position -- the feet: their height is the figure's height
		local dx, dz = tx - position.X, tz - position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < 1e-6 then
			return false
		end
		local travel = math.clamp(distance - standoff, 0, step)
		local x, z = position.X + dx / distance * travel, position.Z + dz / distance * travel
		if ring ~= nil then
			-- the figure stays inside the ring, as the champions do
			local rx, rz = x - ring.x, z - ring.z
			local out = math.sqrt(rx * rx + rz * rz)
			if out > ring.radius then
				x, z = ring.x + rx / out * ring.radius, ring.z + rz / out * ring.radius
			end
		end
		local cframe = CFrame.lookAt(Vector3.new(x, position.Y, z), Vector3.new(tx, position.Y, tz))
		pivotTo(model, cframe)
		return travel > 0
	end)
	return ok and moved == true
end

function Figures:has(userId: number): boolean
	return self._figures[userId] ~= nil
end

function Figures:dress(arenaModel: any, colorA: Color3?, colorB: Color3?)
	local ok, err = pcall(self._kit.arenaDress, arenaModel, colorA, colorB)
	if not ok then
		self:_warn("Figures: the venue could not be dressed", { error = tostring(err) })
	end
end

function Figures:reset(arenaModel: any)
	self:dress(arenaModel, nil, nil)
end

function Figures:clear()
	for _, gear in self._gear do
		pcall(function()
			gear:Destroy()
		end)
	end
	table.clear(self._gear)
	for _, model in self._figures do
		pcall(function()
			model:Destroy()
		end)
	end
	table.clear(self._figures)
	if self._folder ~= nil then
		pcall(function()
			self._folder:Destroy()
		end)
		self._folder = nil
	end
end

return Figures
