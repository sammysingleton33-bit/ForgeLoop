--!strict
--[[
	UI/Ghost — the see-through footprint shown in the world while placing a building: a flat slab
	the size of `Kit.footprint` (rotated with the placement), an outline, and a marker on the front
	edge (Kit models face -Z) so rotation is readable. Around it a fainter "Room" outline: the ground
	the server keeps free for the building's upgrades plus the placement gap (BuildModel.room), so a
	red verdict next to a neighbour or a tree is visible (FORGE-05 M-2 on #62). Tinted by the
	server's verdict.

		Ghost.new(env, parent?: Instance) -> ghost   parent defaults to env.Workspace; the ghost lives in
		                                             its own client-created Folder "BuildGhost" (D-025)
		ghost:show(size: Vector2 (X × Z studs), cframe: CFrame, room: Vector2?)
		                                             cframe = Placement.cframe(position, rot); no room,
		                                             no outer outline
		ghost:tint(state)                            "pending" | "ok" | "bad"
		ghost:hide()      ghost:destroy()
		ghost.folder -> Folder                       exclude it from placement raycasts
	Parts are anchored with CanCollide, CanTouch and CanQuery off, and cast no shadow.
]]

local Ghost = {}
Ghost.__index = Ghost

Ghost.COLORS = table.freeze({
	pending = Color3.fromRGB(234, 196, 108),
	ok = Color3.fromRGB(91, 174, 95),
	bad = Color3.fromRGB(217, 87, 63),
})
Ghost.HEIGHT = 0.6
Ghost.ROOM_HEIGHT = 0.2

local function part(env: any, name: string, parent: Instance): BasePart
	local p = env.newInstance("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Ghost.new(env: any, parent: Instance?)
	local folder = env.newInstance("Folder")
	folder.Name = "BuildGhost"
	local base = part(env, "Footprint", folder)
	base.Transparency = 0.45
	local front = part(env, "Front", folder)
	front.Transparency = 0.15
	front.Size = Vector3.new(2, 0.4, 2)
	local outline = env.newInstance("SelectionBox")
	outline.Name = "Outline"
	outline.Adornee = base
	outline.LineThickness = 0.12
	outline.SurfaceTransparency = 1
	outline.Parent = base
	local room = part(env, "Room", folder)
	room.Transparency = 0.88
	local roomOutline = env.newInstance("SelectionBox")
	roomOutline.Name = "RoomOutline"
	roomOutline.Adornee = room
	roomOutline.LineThickness = 0.06
	roomOutline.SurfaceTransparency = 1
	roomOutline.Transparency = 0.35
	roomOutline.Parent = room
	folder.Parent = parent or env.Workspace
	local self = setmetatable({
		folder = folder,
		base = base,
		front = front,
		outline = outline,
		room = room,
		roomOutline = roomOutline,
		state = "pending",
	}, Ghost)
	self:tint("pending")
	self:hide()
	return self
end

function Ghost:show(size: Vector2, cframe: CFrame, room: Vector2?)
	local base, front = self.base, self.front
	base.Size = Vector3.new(size.X, Ghost.HEIGHT, size.Y)
	base.CFrame = cframe * CFrame.new(0, Ghost.HEIGHT / 2, 0)
	-- The marker sits on the front edge in the building's own frame, so it turns with it.
	front.CFrame = cframe * CFrame.new(0, Ghost.HEIGHT + 0.2, -size.Y / 2 - 1.2) * CFrame.Angles(0, math.pi / 4, 0)
	base.Transparency = 0.45
	front.Transparency = 0.15
	self.outline.Visible = true
	if room then
		-- under the slab, so the building's own footprint reads first
		self.room.Size = Vector3.new(room.X, Ghost.ROOM_HEIGHT, room.Y)
		self.room.CFrame = cframe * CFrame.new(0, Ghost.ROOM_HEIGHT / 2, 0)
		self.room.Transparency = 0.88
		self.roomOutline.Visible = true
	else
		self.room.Transparency = 1
		self.roomOutline.Visible = false
	end
	self.visible = true
end

function Ghost:tint(state: string)
	local color = Ghost.COLORS[state] or Ghost.COLORS.pending
	self.state = state
	self.base.Color = color
	self.front.Color = color
	self.outline.Color3 = color
	self.room.Color = color
	self.roomOutline.Color3 = color
end

function Ghost:hide()
	self.base.Transparency = 1
	self.front.Transparency = 1
	self.outline.Visible = false
	self.room.Transparency = 1
	self.roomOutline.Visible = false
	self.visible = false
end

function Ghost:destroy()
	self.folder:Destroy()
end

return Ghost
