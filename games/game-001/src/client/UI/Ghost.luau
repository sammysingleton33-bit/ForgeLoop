--!strict
--[[
	UI/Ghost — the see-through footprint shown in the world while placing a building: a flat slab
	the size of `Kit.footprint` (rotated with the placement), an outline, a cream "Door" strip on the
	front edge (Kit models face -Z) and a cream facing arrow pointing out of it ("Arrow" shaft and
	"ArrowLeft"/"ArrowRight" chevron), sized with the footprint so the facing reads from the aerial
	camera (the user's first Studio feedback: rotation was not visible). Around it a fainter "Room" outline: the ground
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
		ghost.door, ghost.arrow, ghost.arrowLeft, ghost.arrowRight -> BasePart
		Ghost.arrowLength(size: Vector2) -> number   the arrow's length; its tail sits ARROW_GAP in front of
		                                             the front edge
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
Ghost.MARK = Color3.fromRGB(247, 239, 220) -- door strip and arrow: cream on any verdict tint and on grass
Ghost.ARROW_GAP = 0.6 -- studs between the front edge and the arrow's tail

function Ghost.arrowLength(size: Vector2): number
	return math.clamp(math.min(size.X, size.Y) * 0.5, 6, 14)
end

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
	local door = part(env, "Door", folder)
	local arrow = part(env, "Arrow", folder)
	local arrowLeft = part(env, "ArrowLeft", folder)
	local arrowRight = part(env, "ArrowRight", folder)
	for _, mark in { door, arrow, arrowLeft, arrowRight } do
		mark.Color = Ghost.MARK
	end
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
		door = door,
		arrow = arrow,
		arrowLeft = arrowLeft,
		arrowRight = arrowRight,
		outline = outline,
		room = room,
		roomOutline = roomOutline,
		state = "pending",
	}, Ghost)
	self:tint("pending")
	self:hide()
	return self
end

function Ghost:_marks(): { BasePart }
	return { self.door, self.arrow, self.arrowLeft, self.arrowRight }
end

function Ghost:show(size: Vector2, cframe: CFrame, room: Vector2?)
	local base = self.base
	base.Size = Vector3.new(size.X, Ghost.HEIGHT, size.Y)
	base.CFrame = cframe * CFrame.new(0, Ghost.HEIGHT / 2, 0)
	base.Transparency = 0.45
	-- Everything below is in the building's own frame (front = -Z), so it turns with the cframe.
	local front = -size.Y / 2
	local length = Ghost.arrowLength(size)
	local thick = math.clamp(length * 0.22, 1.5, 3)
	local y = Ghost.HEIGHT + 0.2
	self.door.Size = Vector3.new(math.min(size.X * 0.4, 8), 0.3, 1)
	self.door.CFrame = cframe * CFrame.new(0, Ghost.HEIGHT + 0.15, front + 0.5)
	local shaft = length * 0.7
	self.arrow.Size = Vector3.new(thick, 0.4, shaft)
	self.arrow.CFrame = cframe * CFrame.new(0, y, front - Ghost.ARROW_GAP - shaft / 2)
	-- the chevron: two bars meeting at the tip, each running back at 45° to one side
	local tip = front - Ghost.ARROW_GAP - length
	local bar = length * 0.55
	local back = bar / 2 * math.sqrt(0.5)
	for side, mark in { [-1] = self.arrowLeft, [1] = self.arrowRight } do
		mark.Size = Vector3.new(thick, 0.4, bar)
		mark.CFrame = cframe * CFrame.new(side * back, y, tip + back) * CFrame.Angles(0, side * math.pi / 4, 0)
	end
	for _, mark in self:_marks() do
		mark.Transparency = 0.05
	end
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
	self.outline.Color3 = color
	self.room.Color = color
	self.roomOutline.Color3 = color
end

function Ghost:hide()
	self.base.Transparency = 1
	for _, mark in self:_marks() do
		mark.Transparency = 1
	end
	self.outline.Visible = false
	self.room.Transparency = 1
	self.roomOutline.Visible = false
	self.visible = false
end

function Ghost:destroy()
	self.folder:Destroy()
end

return Ghost
