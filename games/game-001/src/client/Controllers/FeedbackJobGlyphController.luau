--!strict
--[[
	FeedbackJobGlyphController (game-001, FORGE-04, D-059 B22.4 prototype): a small job icon over each citizen
	in the overview, so the start view tells a farmer from a miner. FORGE-02's blind reviews named 2 of 5
	jobs from the rigs alone (#317), even with the rig drawn bigger.

	Off by default: the `jobGlyphs` setting (Experience/Schema), until the owner answers "a closer start
	camera, or job icons?" (FORGE-00, 22 Oct). With it on:
	- Who: the rigs EntityController shows (G4.1 `rendered` / `released`) that are citizens with a job in
	  GLYPH, read from the rig's own Kit attributes (KitKind = "citizen", KitJob), so a job change (a
	  new rig) changes the icon. Soldiers, governors and rigs EntityController's LOD hides (unparented)
	  get none.
	- How many: one icon per cluster, never overlapping (FL-0152: the farm trio on a phone). Nearest the
	  view's centre first, on screen only: a neighbour with the same job closer than MERGE icon widths on
	  screen shares that icon, and any other closer than APART widths waits until it moves clear. At most
	  MAX_SHOWN icons (a phone draws ~50 without cost). A citizen with a bubble (CitizenBubbleController)
	  shows the bubble instead: same spot, and the bubble matters more.
	- Where: a BillboardGui GLYPH_PX px square at every zoom (PHONE_PX on a phone, where a 24 px citizen
	  would sit under an icon its own size), its centre HEIGHT studs above the rig's
	  pivot (where the bubble sits: clear of the head at RIG_SCALE). Not always on top, so a roof hides
	  the citizen and its icon together. It takes no input: a tap still picks the citizen under it.
	- When: only in the overview (not walk mode, the duel, a scripted shot or a conversation), and it
	  fades with the zoom: full from FADE_FULL studs out (the start view, 70, shows them at full), gone at
	  FADE_NONE and closer (the overview's closest zoom), where the rigs read by themselves.
	- Look: FORGE-03's kit badge, Icon.medallion(GLYPH[job].icon, px, GLYPH[job].color), so it matches the
	  HUD and picks up uploaded icon images from UITheme.icons with no code change (until then, its glyph
	  fallback). Colours are UITheme tokens; FORGE-03 picks the final job colours. Meaning is never colour
	  alone: each job has its own icon.
	Pooled: GUIs are reused, never more than MAX_SHOWN exist, and a released rig gives its GUI back.

		FeedbackJobGlyphController:refresh()     -- re-pick and redraw (Heartbeat calls it every POLL_SEC)
		FeedbackJobGlyphController:shown() -> { [entityId]: BillboardGui }   -- what is drawn now (specs)
]]

local EntityControllerDef = require("./EntityController")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local ScreenLayout = require("../UI/Layout")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local Def = {
	name = "FeedbackJobGlyphController",
	dependencies = {},
}

local RIG_SCALE: number = (EntityControllerDef :: any).RIG_SCALE or 1 -- #316: rigs drawn 1.5x

Def.POLL_SEC = 0.25
Def.MAX_SHOWN = 50
Def.GLYPH_PX = 26
Def.PHONE_PX = 20 -- a phone's citizen is ~25 px tall at the start view (#316)
Def.HEIGHT = 3.2 * RIG_SCALE -- studs above the pivot: the bubble's height (CitizenBubbleController)
Def.FADE_FULL = 55 -- studs from the view's centre: full from here out (the start view is 70)
Def.FADE_NONE = 40 -- and gone from here in (the overview's closest zoom; a conversation is 35)
Def.MERGE = 1.2 -- icon widths on screen: a same-job neighbour closer than this shares the icon (FL-0152)
Def.APART = 1 -- icon widths on screen: no two icons closer (they would overlap); another job's waits
Def.SETTING = "jobGlyphs"
-- job -> FORGE-03's kit icon (UITheme.icons) and colour token (FORGE-03, 22 Oct; final colours to come)
Def.GLYPH = table.freeze({
	farmer = table.freeze({ icon = "farm", color = Theme.resource("food") }),
	woodcutter = table.freeze({ icon = "lumbercamp", color = Theme.resource("wood") }),
	miner = table.freeze({ icon = "quarry", color = Theme.resource("stone") }),
	builder = table.freeze({ icon = "build", color = Theme.color("gold500") }),
	hauler = table.freeze({ icon = "storehouse", color = Theme.color("textMuted") }), -- the token nearest #8C7A66
})

local Controller = {}
Controller.__index = Controller

local function isId(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

local function pivotOf(model: any): Vector3?
	local ok, position = pcall(function()
		local primary = model.PrimaryPart
		if primary then
			return primary.CFrame.Position
		end
		return model:GetPivot().Position
	end)
	return if ok then position else nil
end

-- The glyph for a rig, from Kit's attributes on the model; nil for anything but a citizen with a known job.
local function glyphOf(model: any): any
	local ok, kind, job = pcall(function()
		return model:GetAttribute("KitKind"), model:GetAttribute("KitJob")
	end)
	if not ok or kind ~= "citizen" or type(job) ~= "string" then
		return nil
	end
	return Def.GLYPH[job]
end

-- 1 at FADE_FULL studs or farther, 0 at FADE_NONE or closer, linear between.
function Def.fade(zoom: number): number
	if zoom ~= zoom then
		return 0
	end
	return math.clamp((zoom - Def.FADE_NONE) / (Def.FADE_FULL - Def.FADE_NONE), 0, 1)
end

-- opts (specs): { origin = () -> Vector3, zoom = () -> number, playerGui = Instance,
--   project = (Vector3) -> (Vector2, boolean) (screen point in px, on screen), phone = () -> boolean }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_origin = options.origin,
		_zoomOverride = options.zoom,
		_project = options.project,
		_phoneOverride = options.phone,
		_playerGuiOverride = options.playerGui,
		_playerGui = nil :: any,
		_folder = nil :: any,
		_models = {} :: { [number]: any },
		_drawn = {} :: { [number]: any },
		_pool = {} :: { any },
		_connections = {},
		_running = false,
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

local function connect(target: any, signalName: string, handler: (...any) -> ()): any
	local signal = target and target[signalName]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:connect(handler)
	end)
	return if ok then connection else nil
end

function Controller:start()
	local registry = self._registry
	self._entities = registry:find("EntityController")
	self._settings = registry:find("SettingsController")
	self._camera = registry:find("RulerCameraController")
	self._input = registry:find("InputModeController")
	self._bubbles = registry:find("CitizenBubbleController")
	self._conversation = registry:find("ConversationController")
	self._playerGui = self._playerGuiOverride or self:_findPlayerGui()
	if self._entities == nil then
		return -- nothing to mark; EntityController is FORGE-01's (G4.1)
	end
	for _, item in
		{
			connect(self._entities, "rendered", function(id, model)
				if isId(id) then
					self._models[id] = model
				end
			end),
			connect(self._entities, "released", function(id)
				self:_release(id)
			end),
		}
	do
		table.insert(self._connections, item)
	end
	self._running = true
	local env = self._env
	env.spawn(function()
		while self._running do
			self:refresh()
			env.wait(Def.POLL_SEC)
		end
	end)
end

function Controller:destroy()
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
	for _, gui in self._drawn do
		gui:Destroy()
	end
	for _, gui in self._pool do
		gui:Destroy()
	end
	table.clear(self._drawn)
	table.clear(self._pool)
	table.clear(self._models)
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
end

function Controller:_findPlayerGui(): any
	local ok, gui = pcall(function()
		local player = self._env.Players.LocalPlayer
		return player and player:FindFirstChildOfClass("PlayerGui")
	end)
	return if ok then gui else nil
end

-- On only with the setting, in the overview, with no duel, scripted shot or conversation under way.
function Controller:_active(): boolean
	local settings = self._settings
	if settings == nil or settings:get(Def.SETTING) ~= true then
		return false
	end
	local camera = self._camera
	if camera ~= nil then
		if camera.mode ~= nil and camera.mode ~= "overview" then
			return false
		end
		local ok, playing = pcall(function()
			return camera.shotsPlaying and camera:shotsPlaying()
		end)
		if ok and playing then
			return false
		end
	end
	local input = self._input
	if input ~= nil and input.mode == "arena" then
		return false
	end
	local conversation = self._conversation
	if conversation ~= nil then
		local ok, open = pcall(function()
			return conversation.state ~= nil and conversation.state.entityId ~= nil
		end)
		if ok and open then
			return false
		end
	end
	return true
end

function Controller:_originOf(): Vector3?
	if self._origin then
		return self._origin()
	end
	local camera = self._camera
	if camera ~= nil and camera.getFocus then
		local focus = camera:getFocus()
		if focus then
			return focus
		end
	end
	local ok, position = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame.Position
	end)
	return if ok then position else nil
end

function Controller:_zoom(origin: Vector3): number
	if self._zoomOverride then
		return self._zoomOverride()
	end
	local ok, distance = pcall(function()
		return (self._env.Workspace.CurrentCamera.CFrame.Position - origin).Magnitude
	end)
	return if ok then distance else 0
end

-- The screen point (px) of a world position, and whether it is on screen.
function Controller:_screen(position: Vector3): (Vector2?, boolean)
	if self._project then
		local point, visible = self._project(position)
		return point, visible == true
	end
	local ok, point, visible = pcall(function()
		local p, onScreen = self._env.Workspace.CurrentCamera:WorldToViewportPoint(position)
		return Vector2.new(p.X, p.Y), onScreen
	end)
	if not ok then
		return nil, false
	end
	return point, visible == true
end

function Controller:_isPhone(): boolean
	if self._phoneOverride then
		return self._phoneOverride() == true
	end
	local ok, phone = pcall(function()
		local size = self._env.Workspace.CurrentCamera.ViewportSize
		return ScreenLayout.breakpoint(size.X, size.Y) == "phone"
	end)
	return ok and phone == true
end

function Controller:_hasBubble(id: number): boolean
	local bubbles = self._bubbles and self._bubbles.bubbles
	if bubbles == nil then
		return false
	end
	local ok, bubble = pcall(function()
		return bubbles:get(id)
	end)
	return ok and bubble ~= nil
end

function Controller:_build(): any
	local gui = self._env.newInstance("BillboardGui")
	gui.Name = "ForgeCitizenGlyph"
	gui.Size = UDim2.fromOffset(Def.GLYPH_PX, Def.GLYPH_PX)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Def.HEIGHT, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Active = false
	gui.ResetOnSpawn = false
	return gui
end

-- The kit badge for this job and size: built once, rebuilt when a pooled GUI changes job or size.
local function badgeFor(gui: any, look: any, px: number): any
	local badge = gui:FindFirstChild("Medallion")
	if badge ~= nil and badge:GetAttribute("icon") == look.icon and badge:GetAttribute("px") == px then
		return badge
	end
	if badge ~= nil then
		badge:Destroy()
	end
	badge = Icon.medallion(look.icon, px, look.color)
	badge:SetAttribute("icon", look.icon)
	badge:SetAttribute("px", px)
	badge.Parent = gui
	return badge
end

function Controller:_parentFor(model: any): any
	local playerGui = self._playerGui
	if playerGui == nil then
		return model -- headless: in the rig (no input either way)
	end
	if self._folder == nil or self._folder.Parent == nil then
		local folder = self._env.newInstance("Folder")
		folder.Name = "ForgeCitizenGlyphs"
		folder.Parent = playerGui
		self._folder = folder
	end
	return self._folder
end

function Controller:_draw(id: number, model: any, look: any, alpha: number, px: number)
	local gui = self._drawn[id]
	if gui == nil then
		gui = table.remove(self._pool) or self:_build()
		self._drawn[id] = gui
	end
	gui.Size = UDim2.fromOffset(px, px)
	gui.Adornee = model.PrimaryPart or model
	gui.Parent = self:_parentFor(model)
	gui.Enabled = true
	local badge = badgeFor(gui, look, px)
	local clear = 1 - alpha
	badge.BackgroundTransparency = clear
	local stroke = badge:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = clear
	end
	local inner = badge:FindFirstChild("Icon")
	if inner and inner:IsA("ImageLabel") then
		inner.ImageTransparency = clear
	elseif inner then
		inner.TextTransparency = clear
	end
end

function Controller:_hide(id: number)
	local gui = self._drawn[id]
	if gui == nil then
		return
	end
	self._drawn[id] = nil
	gui.Enabled = false
	pcall(function() -- Studio clears it; Lune's Ref properties take no nil
		gui.Adornee = nil
	end)
	gui.Parent = nil
	table.insert(self._pool, gui)
end

function Controller:_release(id: any)
	if not isId(id) then
		return
	end
	self:_hide(id)
	self._models[id] = nil
end

-- Same-job clusters on screen: neighbours closer than `reach` px join (chained, so a farm's row is one
-- cluster). `sorted` is nearest the view's centre first; returns each cluster's first member, in order.
-- A screen grid of `reach` cells keeps it linear in the citizens on screen.
local function clusters(sorted: { any }, reach: number): { any }
	local parent: { number } = {}
	local function root(i: number): number
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	local grid: { [number]: { [number]: { number } } } = {}
	for i, c in sorted do
		parent[i] = i
		local cx, cy = math.floor(c.point.X / reach), math.floor(c.point.Y / reach)
		for x = cx - 1, cx + 1 do
			local column = grid[x]
			if column then
				for y = cy - 1, cy + 1 do
					for _, j in column[y] or {} do
						local other = sorted[j]
						if other.look == c.look and (other.point - c.point).Magnitude < reach then
							local a, b = root(i), root(j)
							if a ~= b then -- the nearer member leads
								parent[math.max(a, b)] = math.min(a, b)
							end
						end
					end
				end
			end
		end
		local column = grid[cx] or {}
		grid[cx] = column
		local cell = column[cy] or {}
		column[cy] = cell
		table.insert(cell, i)
	end
	local out = {}
	for i, c in sorted do
		if root(i) == i then
			table.insert(out, c)
		end
	end
	return out
end

function Controller:refresh()
	local origin = self:_originOf()
	local alpha = if origin then Def.fade(self:_zoom(origin)) else 0
	if not self:_active() or alpha <= 0 or origin == nil then
		for id in self._drawn do
			self:_hide(id)
		end
		return
	end
	local px = if self:_isPhone() then Def.PHONE_PX else Def.GLYPH_PX
	local candidates = {}
	for id, model in self._models do
		local look = glyphOf(model)
		if look ~= nil and model.Parent ~= nil and not self:_hasBubble(id) then
			local pivot = pivotOf(model)
			local point, visible = nil, false
			if pivot then
				point, visible = self:_screen(pivot + Vector3.new(0, Def.HEIGHT, 0))
			end
			if pivot and point and visible then
				local distance = (pivot - origin).Magnitude
				table.insert(candidates, { id = id, model = model, look = look, distance = distance, point = point })
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	local leaders = clusters(candidates, Def.MERGE * px)
	-- one icon a cluster, over its member nearest the view's centre; a cluster closer than APART widths
	-- to a drawn icon (another job's) waits, so no two icons overlap into a smear
	local keep, kept = {}, {}
	for _, c in leaders do
		if #kept >= Def.MAX_SHOWN then
			break
		end
		local clear = true
		for _, k in kept do
			if (c.point - k.point).Magnitude < Def.APART * px then
				clear = false
				break
			end
		end
		if clear then
			table.insert(kept, c)
			keep[c.id] = c
		end
	end
	for id in self._drawn do
		if keep[id] == nil then
			self:_hide(id)
		end
	end
	for id, c in keep do
		self:_draw(id, c.model, c.look, alpha, px)
	end
end

function Controller:shown(): { [number]: any }
	return table.clone(self._drawn)
end

return Def
