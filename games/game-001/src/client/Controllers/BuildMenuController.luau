--!strict
--[[
	BuildMenuController (FORGE-03, game-001 client, FL-0059) — the build menu and building
	placement, end to end:
		1. Build (HUD rail) opens the drawer: tabs Economy / Homes / Military, each building with its
		   cost against the treasury, its build time and footprint (UI/BuildModel).
		2. "Place <building>" closes the drawer and enters build mode: InputModeController:set("build")
		   (FORGE-04, G4.1) and a ghost of the `Kit.footprint` size in the world (UI/Ghost).
		3. Every new ghost spot is checked with `Build.CanPlace(type, position, rot)`, throttled
		   (UI/Placement.Checker, under the remote's 10/s): green = valid, red = the server's reason.
		4. Turn (R or gamepad R1; Shift+R or L1 turns back) turns it in 90° steps: the ghost's facing arrow and
		   the Turn button's dial show which way the front will face from the current camera. Place calls `Build.Place(type, position, rot)`. The server
		   charges the treasury (Treasury.Changed → the pills float the spend) and the new building
		   arrives through Build.Buildings (a construction chip). A toast confirms; a refusal keeps
		   build mode open with the reason.
		5. Cancel (or leaving build mode elsewhere) removes the ghost and returns to "explore".
	No CFrame crosses the wire (G8): the server builds CFrame.new(position) * CFrame.Angles(0, rot·π/2, 0).

	Moving a building (FL-0120, CONTRACTS G13.9 v0.4-g9j; FORGE-01's Build.CanMove / Move / MoveToSlot):
		build:startMove(buildingId) (the upgrade panel's Move) reuses the ghost, the bar and the input: the
		ghost starts where the building stands, tinted by `Build.CanMove(id, position, rot)`; R / Turn turn
		it. Over one of my kingdom's plots that is free (or the building's own) and that the type fits
		(`Fit.fits` at some turn, UI/Turns), the ghost snaps to the plot and Turn steps through the turns
		that fit; "Move here" then calls `Build.MoveToSlot(id, slotId, turn)`, elsewhere
		`Build.Move(id, position, rot)`. Moving is free (no costs on the bar). The building itself stays
		drawn, dimmed (LocalTransparencyModifier on its own parts, found by its BuildingId attribute; the
		model carries ForgeMoving = true meanwhile), until the move ends either way. A refusal keeps the move open with the reason (Text.reason,
		"move"). Input mode "edit" (FORGE-04, FL-0121) when InputModeController accepts it, else "build".
		On its own plot the snap starts at the turn it stands at; Move here where it already stands ends
		the move with no remote, toast or cooldown. build:moving() is true meanwhile: the upgrade panel
		and the plot picker then leave taps on my buildings and plots to the move (FORGE-07 B1 on #148).
		build.movedAt[buildingId] = env.clock() of my last accepted move (the panel's cooldown).

	Dragging a building (FL-0123, D-052 (1), CONTRACTS G13.9): besides Move → ghost → Move here, press and hold one of
	my buildings for DRAG_HOLD_SEC (longer than a tap, so the tap that opens the upgrade panel never also drags) and
	it is picked up: startMove, and FORGE-04's RulerCameraController:setEditDrag(true) (a drag no longer pans; the
	screen edge does). Moving the pointer moves the ghost; letting go drops it: Move here when the spot is good (or
	as soon as the pending check says so), else the move stays open with the reason on the bar. Moving more than
	DRAG_SLOP px before the hold is a camera pan, not a drag. The same checks as the Move button apply (mine, not
	the keep, not destroyed, Build.Move served, the move cooldown). setEditDrag(false) when the drag ends, the move
	ends or the controller goes. Live input: UI/DragInput (mouse and touch); specs drive dragPress / dragMove /
	dragRelease.

	Depends on KingdomHudController (store, remotes, menus, layout, notifications).
	Optional: InputModeController (FORGE-04). Live input: UI/PlacementInput (mouse, touch, R/Q keys).

	API (specs and the snapshot scenes drive these directly)
		build:selectCategory(id)  build:selectBuilding(type)  build:back()
		build:startPlacement(type)  build:aimAt(position: Vector3)  build:rotate(step?: 1 | -1)
		build:confirm()  build:cancel()
		build:startMove(buildingId)
		build:dragPress(buildingId, screen: Vector2) -> boolean   build:dragMove(screen: Vector2, world: Vector3?)
		build:dragRelease(world: Vector3?)   build.dragging   build:moveCooldownLeft(buildingId) -> seconds
		build.state = { category, selected, phoneView }   build.placing = { type, rot, position?,
		    status ("pending" | "ok" | "bad"), reason?, busy, footprint, room?,
		    move: { id, slot: { id, frame, allowed }?, turn, aim: Vector3? }? }?
		build.menu (UI/BuildMenu)  build.bar (UI/PlacementBar)  build.ghost (UI/Ghost)?
]]

local BuildModel = require("../UI/BuildModel")
local BuildMenu = require("../UI/BuildMenu")
local Buildings = require("../UI/Buildings")
local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local DragInput = require("../UI/DragInput")
local Ghost = require("../UI/Ghost")
local Placement = require("../UI/Placement")
local PlacementBar = require("../UI/PlacementBar")
local PlacementInput = require("../UI/PlacementInput")
local Slots = require("../UI/Slots")
local Text = require("../UI/Text")
local Turns = require("../UI/Turns")

local BuildMenuController = {}
BuildMenuController.__index = BuildMenuController

local Def = { name = "BuildMenuController", dependencies = { "KingdomHudController" } }

BuildMenuController.DRAG_HOLD_SEC = 0.45 -- above InputModeController's tapSec (0.4): a hold is never also a tap
BuildMenuController.DRAG_SLOP = 8 -- px, InputModeController's tapPixels: more before the hold is a camera pan
BuildMenuController.MOVE_COOLDOWN = 10 -- seconds, when config Buildings has no moveCooldown

-- Used when Kit has no footprint for a type (never for the G2 types; a guard, not a rule).
BuildMenuController.FALLBACK_FOOTPRINT = Vector2.new(16, 16)

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { category = "economy", selected = nil :: string?, phoneView = "list" },
		placing = nil :: any,
		ghost = nil :: any,
		movedAt = {} :: { [number]: number },
		dragging = false,
		_press = nil :: any,
	}, BuildMenuController)
end

function BuildMenuController:start()
	-- the back key (KingdomHudController:setBackStep): a phone detail goes back to its list first
	if self.hud.setBackStep ~= nil then
		self.hud:setBackStep("build", function()
			if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then
				return false
			end
			self:back()
			return true
		end)
	end
	local env = self._env
	local hud = self.hud
	self._inputMode = self._registry:find("InputModeController")
	self._connections = {
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end),
		hud.menuChanged:connect(function(menu)
			if menu ~= nil and self.placing then
				self:cancel()
			end
			if menu == "build" then
				self.state.phoneView = "list"
			end
		end),
	}
	local modeSignal = self._inputMode and self._inputMode.changed
	if modeSignal then
		pcall(function()
			local function onMode(mode)
				if mode ~= "build" and mode ~= "edit" and self.placing and not self._leaving then
					self:cancel()
				end
			end
			table.insert(
				self._connections,
				if modeSignal.connect then modeSignal:connect(onMode) else modeSignal:Connect(onMode)
			)
		end)
	end
	self._checker = Placement.Checker.new({
		invoke = function(buildingType, position, rot)
			local move = self.placing and self.placing.move
			if move then
				return hud.remotes:invoke("Build.CanMove", move.id, position, rot)
			end
			return hud.remotes:invoke("Build.CanPlace", buildingType, position, rot)
		end,
		onResult = function(key, ok, reason)
			self:_onVerdict(key, ok, reason)
		end,
		spawn = env.spawn,
		wait = env.wait,
		clock = env.clock,
	})
	self._disconnectInput = PlacementInput.connect(env, {
		active = function()
			return self.placing ~= nil
		end,
		aim = function(position)
			self:aimAt(position)
		end,
		rotate = function(step)
			self:rotate(step)
		end,
		confirm = function()
			self:confirm()
		end,
		cancel = function()
			self:cancel()
		end,
	}, function()
		return self:_exclude()
	end)
	self._disconnectDrag = DragInput.connect(env, {
		mine = function()
			local kingdom = hud.store:mine()
			return if kingdom then kingdom.id else nil
		end,
		press = function(buildingId, screen)
			return self:dragPress(buildingId, screen)
		end,
		move = function(screen, world)
			self:dragMove(screen, world)
		end,
		release = function(world)
			self:dragRelease(world)
		end,
		active = function()
			return self._press ~= nil
		end,
	}, function()
		return self:_exclude()
	end)
end

function BuildMenuController:destroy()
	if self.placing then
		self:cancel()
	end
	for _, connection in self._connections or {} do
		connection:disconnect()
	end
	if self._disconnectInput then
		self._disconnectInput()
	end
	if self._disconnectDrag then
		self._disconnectDrag()
	end
	self._press = nil
	self:_editDrag(false)
	if self.menu then
		self.menu:destroy()
	end
end

function BuildMenuController:_exclude(): { Instance }
	local list = {}
	if self.ghost then
		table.insert(list, self.ghost.folder)
	end
	local player = self._env.Players.LocalPlayer
	if player and player.Character then
		table.insert(list, player.Character)
	end
	return list
end

-- ------------------------------------------------------------------ menu

function BuildMenuController:selectCategory(id: string)
	self.state.category = id
	self.state.selected = nil
	self.state.phoneView = "list"
	self.hud:render()
end

function BuildMenuController:selectBuilding(buildingType: string)
	self.state.selected = buildingType
	self.state.phoneView = "detail"
	self.hud:render()
end

function BuildMenuController:back()
	self.state.phoneView = "list"
	self.hud:render()
end

-- ------------------------------------------------------------------ placement

function BuildMenuController:_setMode(mode: string): boolean
	local input = self._inputMode
	local accepted = false
	if input and input.set then
		self._leaving = mode ~= "build" and mode ~= "edit"
		local ok, result = pcall(function()
			return input:set(mode)
		end)
		accepted = ok and result ~= false
		self._leaving = false
	end
	return accepted
end

function BuildMenuController:startPlacement(buildingType: string)
	local detail = BuildModel.placeDetail(self.hud.store, buildingType)
	if detail == nil or detail.cta.state ~= "ready" then
		return
	end
	if self.placing then
		self:cancel()
	end
	self.placing = {
		type = buildingType,
		name = detail.name,
		rot = 0,
		position = nil :: Vector3?,
		key = nil :: string?,
		status = "pending",
		reason = nil :: string?,
		busy = false,
		footprint = detail.footprint or BuildMenuController.FALLBACK_FOOTPRINT,
		room = detail.room, -- largest level + gap: what the server keeps free (#62)
	}
	self.ghost = Ghost.new(self._env)
	if self.hud.state.menu == "build" then
		self.hud:setMenu(nil)
	end
	self:_setMode("build")
	self.hud:setPlacing(true)
	PlacementInput.aimAtScreenCentre(self._env, function(position)
		self:aimAt(position)
	end, function()
		return self:_exclude()
	end)
end

function BuildMenuController:_refreshGhost()
	local p = self.placing
	if p == nil or p.position == nil or self.ghost == nil then
		return
	end
	local slot = p.move and p.move.slot
	if slot then
		local turn = p.move.turn
		local frame = slot.frame
		-- the outline is the plot itself: it stays put while the building turns inside it
		local plot = if turn % 2 == 1 then Vector2.new(frame.size.Y, frame.size.X) else frame.size
		self.ghost:show(p.footprint, CFrame.new(frame.center) * CFrame.Angles(0, Turns.yaw(frame.yaw, turn), 0), plot)
	else
		self.ghost:show(p.footprint, Placement.cframe(p.position, p.rot), p.room)
	end
	self.ghost:tint(p.status)
end

function BuildMenuController:aimAt(position: Vector3)
	local p = self.placing
	if p == nil or p.busy then
		return
	end
	if p.move then
		p.move.aim = position
		local slot = self:_slotAt(position)
		p.move.slot = slot
		if slot then
			if not table.find(slot.allowed, p.move.turn) then
				p.move.turn = slot.allowed[1]
			end
			local key = `slot|{slot.id}|{p.move.turn}`
			if key == p.key then
				return
			end
			p.key = key
			p.position = slot.frame.center
			-- the client knows the plot is free and fits; the server answers the rest on Move here
			p.status = "ok"
			p.reason = nil
			self._checker:cancel()
			self:_refreshGhost()
			self.hud:render()
			return
		end
	end
	local snapped = Placement.snap(position)
	local key = Placement.key(p.type, snapped, p.rot)
	if key == p.key then
		return
	end
	p.position = snapped
	p.key = key
	p.status = "pending"
	p.reason = nil
	self:_refreshGhost()
	self._checker:request(p.type, snapped, p.rot)
	self.hud:render()
end

function BuildMenuController:rotate(step: number?)
	local p = self.placing
	if p == nil or p.busy then
		return
	end
	local back = step == -1
	local slot = p.move and p.move.slot
	if slot then
		local allowed = slot.allowed
		local i = table.find(allowed, p.move.turn) or 1
		p.move.turn = allowed[(i - 1 + (if back then -1 else 1)) % #allowed + 1]
		p.key = nil
		self:aimAt(p.move.aim or slot.frame.center)
		return
	end
	p.rot = Placement.nextRotation(p.rot, if back then -1 else 1)
	local position = p.position
	p.key = nil
	if position then
		self:aimAt(position)
	else
		self.hud:render()
	end
end

-- Pick a building up (FL-0120): the ghost starts where it stands; see the header.
function BuildMenuController:startMove(buildingId: any): boolean
	local store = self.hud.store
	local building = store:building(buildingId)
	local mine = store:mine()
	if building == nil or mine == nil or building.kingdom ~= mine.id or building.type == "keep" then
		return false
	end
	if building.state == "destroyed" or not self.hud:hasRemote("Build.Move") then
		return false
	end
	local info = Buildings.get(building.type)
	if info == nil then
		return false
	end
	if self.placing then
		self:cancel()
	end
	local cframe = if typeof(building.cframe) == "CFrame" then building.cframe else nil
	local rot, yaw = 0, nil
	if cframe then
		local look = cframe.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		rot = math.floor(yaw / (math.pi / 2) + 0.5) % 4
	end
	-- Where it stands now, so a move back to the same spot ends quietly (FORGE-07 L3 on #148), and, on its
	-- own plot, the turn it stands at there, so the plot snap starts as it is (FORGE-07 M1 on #148).
	local fromSlot, fromTurn = nil, 0
	for _, slot in store:slots() do
		local frame = if slot.occupiedBy == building.id then Slots.frame(slot.id) else nil
		if frame then
			fromSlot = slot.id
			if yaw then
				fromTurn = math.floor((yaw - frame.yaw) / (math.pi / 2) + 0.5) % 4
			end
			break
		end
	end
	local fromKey = if cframe then Placement.key(building.type, Placement.snap(cframe.Position), rot) else nil
	self.placing = {
		type = building.type,
		name = info.name,
		rot = rot,
		position = nil :: Vector3?,
		key = nil :: string?,
		status = "pending",
		reason = nil :: string?,
		busy = false,
		footprint = BuildModel.footprint(building.type, math.max(building.level, 1))
			or BuildMenuController.FALLBACK_FOOTPRINT,
		room = BuildModel.room(building.type),
		move = {
			id = building.id,
			slot = nil :: any,
			turn = fromTurn,
			aim = nil :: Vector3?,
			fromSlot = fromSlot,
			fromTurn = fromTurn,
			fromKey = fromKey,
		},
	}
	self.ghost = Ghost.new(self._env)
	if self.hud.state.menu ~= nil then
		self.hud:setMenu(nil)
	end
	if not self:_setMode("edit") then
		self:_setMode("build")
	end
	self.hud:setPlacing(true)
	self:_dim(building.id)
	if cframe then
		self:aimAt(cframe.Position)
	else
		PlacementInput.aimAtScreenCentre(self._env, function(position)
			self:aimAt(position)
		end, function()
			return self:_exclude()
		end)
	end
	return true
end

-- Seconds until `buildingId` may move again (config Buildings.moveCooldown, else MOVE_COOLDOWN); 0 when it may.
function BuildMenuController:moveCooldownLeft(buildingId: any): number
	local cooldown = (BuildingsConfig :: any).moveCooldown
	cooldown = if type(cooldown) == "number" then cooldown else BuildMenuController.MOVE_COOLDOWN
	local movedAt = self.movedAt[buildingId]
	return if movedAt then math.max(0, cooldown - (self._env.clock() - movedAt)) else 0
end

-- FORGE-04's edge-pan while a building is dragged (RulerCameraController:setEditDrag, G13.9); optional.
function BuildMenuController:_editDrag(on: boolean)
	if self.dragging == on then
		return
	end
	self.dragging = on
	local camera = self._registry:find("RulerCameraController")
	if camera ~= nil and type(camera.setEditDrag) == "function" then
		pcall(camera.setEditDrag, camera, on)
	end
end

-- Press on one of my buildings (FL-0123): it is picked up after DRAG_HOLD_SEC unless the pointer moved or let go.
function BuildMenuController:dragPress(buildingId: any, screen: Vector2): boolean
	if self.placing ~= nil or self._press ~= nil then
		return false -- a move under way keeps the Move flow's own pointer rules
	end
	local input = self._inputMode
	if input ~= nil and input.mode ~= nil and input.mode ~= "explore" then
		return false -- walking, a conversation, the arena: presses belong to them
	end
	local store = self.hud.store
	local building = store:building(buildingId)
	local mine = store:mine()
	if building == nil or mine == nil or building.kingdom ~= mine.id or building.type == "keep" then
		return false
	end
	if building.state == "destroyed" or not self.hud:hasRemote("Build.Move") then
		return false
	end
	if self:moveCooldownLeft(buildingId) > 0 then
		return false
	end
	local press = { id = buildingId, at = screen }
	self._press = press
	self._env.spawn(function()
		self._env.wait(BuildMenuController.DRAG_HOLD_SEC)
		if self._press == press then
			if self:startMove(press.id) then
				self:_editDrag(true)
			else
				self._press = nil
			end
		end
	end)
	return true
end

function BuildMenuController:dragMove(screen: Vector2, world: Vector3?)
	local press = self._press
	if press == nil then
		return
	end
	if not self.dragging then
		if (screen - press.at).Magnitude > BuildMenuController.DRAG_SLOP then
			self._press = nil -- a camera pan, not a drag
		end
		return
	end
	if world ~= nil then
		self:aimAt(world)
	end
end

-- Let go: drop the ghost (Move here when the spot is good, or when its pending check says so).
function BuildMenuController:dragRelease(world: Vector3?)
	local was = self.dragging
	self._press = nil
	if not was then
		return
	end
	if world ~= nil then
		self:aimAt(world)
	end
	self:_editDrag(false)
	local p = self.placing
	if p == nil or p.move == nil then
		return
	end
	if p.status == "ok" then
		self:confirm()
	elseif p.status == "pending" then
		p.dropWhenOk = p.key
	end
end

-- A building is picked up (FL-0120). Selection handlers leave edit-mode taps to the move (FORGE-07 B1).
function BuildMenuController:moving(): boolean
	return self.placing ~= nil and self.placing.move ~= nil
end

-- One of my kingdom's plots under `position` that this building can stand on: free or its own, a
-- plot type (walls and gates never stand on plots), and at least one turn that fits (UI/Turns).
function BuildMenuController:_slotAt(position: Vector3): any
	local p = self.placing
	if p == nil or p.move == nil or p.type == "wall" or p.type == "gate" then
		return nil
	end
	for _, slot in self.hud.store:slots() do
		if slot.occupiedBy == nil or slot.occupiedBy == p.move.id then
			local frame = Slots.frame(slot.id)
			if frame and Slots.contains(frame, position) then
				local allowed = Turns.allowed(p.type, slot.size)
				if #allowed > 0 then
					return { id = slot.id, frame = frame, allowed = allowed }
				end
			end
		end
	end
	return nil
end

-- The building being moved stays drawn, dimmed, until the move ends (FL-0120): LocalTransparencyModifier
-- on its own parts (client-only; the server's Transparency is untouched) and the attribute ForgeMoving on
-- its model while it is picked up (Lune has no LocalTransparencyModifier: specs read the attribute).
BuildMenuController.DIM = 0.6
function BuildMenuController:_dim(buildingId: number)
	self:_undim()
	local models, parts = {}, {}
	pcall(function()
		for _, d in self._env.Workspace:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("BuildingId") == buildingId then
				table.insert(models, d)
				d:SetAttribute("ForgeMoving", true)
				for _, part in d:GetDescendants() do
					if part:IsA("BasePart") then
						pcall(function()
							table.insert(parts, { part = part, was = part.LocalTransparencyModifier })
							part.LocalTransparencyModifier = BuildMenuController.DIM
						end)
					end
				end
			end
		end
	end)
	self._dimmed = { models = models, parts = parts }
end

function BuildMenuController:_undim()
	local dimmed = self._dimmed
	self._dimmed = nil
	if dimmed == nil then
		return
	end
	for _, entry in dimmed.parts do
		pcall(function()
			entry.part.LocalTransparencyModifier = entry.was
		end)
	end
	for _, model in dimmed.models do
		pcall(function()
			model:SetAttribute("ForgeMoving", nil)
		end)
	end
end

-- Where the building's front faces on screen now (degrees, 0 = away from the camera).
function BuildMenuController:facing(rot: number): number
	return self:screenFacing(rot * math.pi / 2)
end

function BuildMenuController:screenFacing(yaw: number): number
	local ok, camera = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame
	end)
	return Placement.screenAngle(yaw, if ok and typeof(camera) == "CFrame" then camera else nil)
end

function BuildMenuController:_onVerdict(key: string, ok: boolean, reason: string?)
	local p = self.placing
	if p == nil or p.key ~= key then
		return -- a reply for a spot the ghost already left
	end
	p.status = if ok then "ok" else "bad"
	p.reason = if ok then nil else Text.reason(reason, if p.move then "move" else nil)
	self:_refreshGhost()
	self.hud:render()
	if p.dropWhenOk == key then
		p.dropWhenOk = nil
		if ok then
			self:confirm() -- the drag was let go while this spot was being checked
		end
	end
end

function BuildMenuController:confirm()
	local p = self.placing
	if p == nil or p.busy or p.status ~= "ok" or p.position == nil then
		return
	end
	local hud = self.hud
	local move = p.move
	local slot = move and move.slot
	-- Put back where it stood: nothing to ask the server, no toast, no cooldown (FORGE-07 L3 on #148).
	if move and (if slot then slot.id == move.fromSlot and move.turn == move.fromTurn else p.key == move.fromKey) then
		self:cancel()
		return
	end
	p.busy = true
	self.hud:render()
	self._env.spawn(function()
		local called, result, reason = pcall(function()
			if move and slot then
				return hud.remotes:invoke("Build.MoveToSlot", move.id, slot.id, move.turn)
			elseif move then
				return hud.remotes:invoke("Build.Move", move.id, p.position, p.rot)
			end
			return hud.remotes:invoke("Build.Place", p.type, p.position, p.rot)
		end)
		if self.placing ~= p then
			return -- cancelled while waiting
		end
		p.busy = false
		local accepted = called and (if move then result == true else type(result) == "number")
		if accepted and move then
			self.movedAt[move.id] = self._env.clock()
			hud:notify({ kind = "success", title = `{p.name} moved`, body = "Its workers walk over" })
			self:_stop()
		elseif accepted then
			hud:notify({ kind = "success", title = `{p.name} placed`, body = "Builders are on their way" })
			self:_stop()
		else
			local context = if slot then "moveSlot" elseif move then "move" else nil
			local text = Text.reason(if called then reason else nil, context)
			p.status = "bad"
			p.reason = text
			self:_refreshGhost()
			hud:notify({
				kind = "error",
				title = if move then `Couldn't move the {p.name}` else `Couldn't place the {p.name}`,
				body = text,
			})
			hud:render()
		end
	end)
end

function BuildMenuController:cancel()
	if self.placing then
		self:_stop()
	end
end

function BuildMenuController:_stop()
	self._press = nil
	self:_editDrag(false)
	self._checker:cancel()
	self:_undim()
	if self.ghost then
		self.ghost:destroy()
		self.ghost = nil
	end
	self.placing = nil
	self:_setMode("explore")
	self.hud:setPlacing(false)
end

-- ------------------------------------------------------------------ rendering

function BuildMenuController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.menu = self.menu or BuildMenu.new(hud.roots.menus)
	self.bar = self.bar or PlacementBar.new(hud.roots.hud)
	if hud.state.menu == "build" then
		local view = BuildModel.menu(hud.store, { category = self.state.category, selected = self.state.selected })
		self.menu:render(view, metrics, {
			phoneView = self.state.phoneView,
			onCategory = function(id)
				self:selectCategory(id)
			end,
			onSelect = function(buildingType)
				self:selectBuilding(buildingType)
			end,
			onBack = function()
				self:back()
			end,
			onPlace = function(detail)
				self:startPlacement(detail.type)
			end,
			onClose = function()
				hud:setMenu(nil)
			end,
		})
	else
		self.menu:destroy()
	end
	local p = self.placing
	if p and hud.guis.hud and hud.guis.hud.Enabled then
		local info = Buildings.get(p.type)
		local detail = if p.move then nil else BuildModel.placeDetail(hud.store, p.type)
		local costs = {}
		for _, c in if detail then detail.costs else {} do
			table.insert(costs, { currency = c.currency, amount = c.amount, short = c.short })
		end
		local slot = p.move and p.move.slot
		local yaw = if slot then Turns.yaw(slot.frame.yaw, p.move.turn) else p.rot * math.pi / 2
		self.bar:render(
			{
				name = if p.move then `Move {p.name}` else p.name,
				confirm = if p.move then "Move here" else nil,
				clickVerb = if p.move then "moves" else nil,
				okText = if slot then `✓ {Turns.label(p.move.turn)}` else nil, -- the plot outline shows the snap
				icon = if info then info.icon else "build",
				category = if info then info.category else "economy",
				costs = costs,
				status = p.status,
				reason = p.reason,
				busy = p.busy,
				facing = self:screenFacing(yaw),
			},
			metrics,
			{
				onRotate = function()
					self:rotate(1)
				end,
				onCancel = function()
					self:cancel()
				end,
				onPlace = function()
					self:confirm()
				end,
			}
		)
	else
		self.bar:destroy()
	end
end

-- the drag constants on the definition too, for specs that hold before a controller exists
Def.DRAG_HOLD_SEC = BuildMenuController.DRAG_HOLD_SEC
Def.DRAG_SLOP = BuildMenuController.DRAG_SLOP

return Def
