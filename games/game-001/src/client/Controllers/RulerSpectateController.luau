--!strict
--[[
	RulerSpectateController (game-001, FORGE-04, FL-0130 part 2; D-053 (3) "eliminated rulers spectate"):
	the camera of a ruler whose kingdom has fallen. It drives RulerCameraController's overview through its
	public API (setMode, focusOn); FORGE-03's spectate screen (FL-0129) shows the target list and calls this.

	When
		- starts on FORGE-01's `Match.Spectate(true, info)` (FL-0125: our kingdom fell, or every kingdom
		  is full), or when Kingdom.State (G8) says our kingdom is no longer alive; the last kingdom we had
		  is remembered, so a state whose `mine` is nil after the fall still counts. setActive(true)
		  starts it by hand.
		- ends on `Match.Spectate(false)` (seated again), at Results or Lobby (Match.State, G8): the
		  match is over and control returns to the player; setActive(false) ends it by hand.
	Targets, in this order (re-read on every cycle, so they follow the war):
		1. battles: FeedbackWarController:hotspots(), the places hit in the last 20 s, newest first
		2. the keeps of the kingdoms still standing (their `Kind = "keep"` model under
		   Workspace.ForgeKingdoms/<kingdom>/Buildings), in Kingdom.State order
	Cycling: . (period) or ButtonR1 for the next target, , (comma) or ButtonL1 for the previous one,
	only while spectating, wrapping. On start the camera goes to the first target. The player can still
	pan, zoom and turn the overview freely; cycling simply moves the focus again.

	API
		controller.active: boolean
		controller.changed: Signal<(active: boolean)>
		controller.targetChanged: Signal<(target)>    target = { kind = "battle" | "keep", position,
		                                               kingdom?, kingdomName?, count? }
		controller:setActive(on) -> boolean
		controller:targets() -> { target }
		controller:cycle(direction) -> target?         +1 next, -1 previous
		controller:select(index) -> target?            for the screen's list
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Controller = {}
Controller.__index = Controller

local Def = { name = "RulerSpectateController", dependencies = { "RulerCameraController" } }

Def.NEXT_KEYS = table.freeze({ Enum.KeyCode.Period, Enum.KeyCode.ButtonR1 })
Def.PREVIOUS_KEYS = table.freeze({ Enum.KeyCode.Comma, Enum.KeyCode.ButtonL1 })
Def.END_PHASES = table.freeze({ Results = true, Lobby = true })

function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_userInputOverride = options.userInput,
		_connections = {},
		_links = {},
		_kingdoms = {} :: { any },
		_mine = nil :: string?,
		_index = 0,
		active = false,
		changed = Signal.new(),
		targetChanged = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:start()
	self._camera = self._registry:find("RulerCameraController")
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Kingdom.State", function(state)
			self:onKingdomState(state)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Match.State", function(phase)
			self:onPhase(phase)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Match.Spectate", function(spectating, info)
			self:onSpectate(spectating, info)
		end)
	)
	RemoteLink.request(self._env, "Kingdom.GetState", function(state)
		if not self._destroyed then
			self:onKingdomState(state)
		end
	end)
	self:_bindKeys()
end

function Controller:destroy()
	self._destroyed = true
	for _, link in self._links do
		pcall(function()
			link:disconnect()
		end)
	end
	table.clear(self._links)
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
end

function Controller:onKingdomState(state: any)
	if type(state) ~= "table" then
		return
	end
	if type(state.kingdoms) == "table" then
		self._kingdoms = state.kingdoms
	end
	if type(state.mine) == "string" then
		self._mine = state.mine
	end
	local mine = self:_kingdom(self._mine)
	if mine ~= nil and mine.alive == false and not self.active then
		self:setActive(true)
	end
end

-- FL-0125's Match.Spectate(spectating, info?: { reason, kingdomId?, by?, standing })
function Controller:onSpectate(spectating: any, info: any)
	if type(info) == "table" and type(info.kingdomId) == "string" then
		self._mine = info.kingdomId -- our fallen kingdom: never a target
	end
	if spectating == true then
		self:setActive(true)
	elseif spectating == false then
		self:setActive(false)
	end
end

function Controller:onPhase(phase: any)
	if type(phase) == "string" and Def.END_PHASES[phase] and self.active then
		self:setActive(false)
	end
	if phase == "Lobby" then
		self._mine = nil -- a new match: the next Kingdom.State says where we rule
	end
end

function Controller:_kingdom(id: string?): any
	if id == nil then
		return nil
	end
	for _, kingdom in self._kingdoms do
		if type(kingdom) == "table" and kingdom.id == id then
			return kingdom
		end
	end
	return nil
end

function Controller:setActive(on: boolean): boolean
	if on == self.active then
		return false
	end
	self.active = on
	self._index = 0
	self.changed:fire(on)
	if on then
		local camera = self._camera
		if camera ~= nil and camera.mode ~= "overview" and camera.setMode ~= nil then
			pcall(camera.setMode, camera, "overview") -- no character to walk with any more
		end
		self:cycle(1)
	end
	return true
end

local function keepOf(workspace: any, kingdomId: string): Vector3?
	local ok, position = pcall(function()
		local root = workspace:FindFirstChild("ForgeKingdoms")
		local folder = root and root:FindFirstChild(kingdomId)
		local buildings = folder and folder:FindFirstChild("Buildings")
		for _, model in (if buildings then buildings:GetChildren() else {}) do
			if model:GetAttribute("Kind") == "keep" then
				if model.PrimaryPart then
					return model.PrimaryPart.CFrame.Position
				end
				local okPivot, pivot = pcall(function()
					return model:GetPivot().Position
				end)
				if okPivot then
					return pivot
				end
				local part = model:FindFirstChildWhichIsA("BasePart", true)
				return if part then part.CFrame.Position else nil
			end
		end
		return nil
	end)
	return if ok and typeof(position) == "Vector3" then position else nil
end

function Controller:targets(): { { [string]: any } }
	local out = {}
	local war = self._registry:find("FeedbackWarController")
	if war ~= nil and war.hotspots ~= nil then
		local ok, spots = pcall(war.hotspots, war)
		for _, spot in (if ok and type(spots) == "table" then spots else {}) do
			if typeof(spot.position) == "Vector3" then
				table.insert(out, { kind = "battle", position = spot.position, count = spot.count })
			end
		end
	end
	for _, kingdom in self._kingdoms do
		if type(kingdom) == "table" and kingdom.alive ~= false and kingdom.id ~= self._mine then
			local position = keepOf(self._env.Workspace, kingdom.id)
			if position ~= nil then
				table.insert(out, {
					kind = "keep",
					position = position,
					kingdom = kingdom.id,
					kingdomName = if type(kingdom.name) == "string" then kingdom.name else nil,
				})
			end
		end
	end
	return out
end

function Controller:select(index: number): { [string]: any }?
	if not self.active then
		return nil
	end
	local list = self:targets()
	local target = list[index]
	if target == nil then
		return nil
	end
	self._index = index
	local camera = self._camera
	if camera ~= nil and camera.focusOn ~= nil then
		pcall(camera.focusOn, camera, target.position)
	end
	self.targetChanged:fire(target)
	return target
end

function Controller:cycle(direction: number): { [string]: any }?
	if not self.active then
		return nil
	end
	local count = #self:targets()
	if count == 0 then
		return nil
	end
	local step = if direction < 0 then -1 else 1
	local index = ((self._index - 1 + step) % count) + 1
	return self:select(index)
end

function Controller:_bindKeys()
	local env = self._env
	local userInput = self._userInputOverride
	if userInput == nil then
		local ok, found = pcall(function()
			local uis = env.UserInputService
			local _ = uis.InputBegan -- the boot gate's unmocked guard errors here
			return uis
		end)
		userInput = if ok then found else nil
	end
	if userInput == nil then
		return
	end
	local ok, connection = pcall(function()
		return userInput.InputBegan:Connect(function(input, processed)
			if processed or not self.active then
				return
			end
			if table.find(Def.NEXT_KEYS, input.KeyCode) then
				self:cycle(1)
			elseif table.find(Def.PREVIOUS_KEYS, input.KeyCode) then
				self:cycle(-1)
			end
		end)
	end)
	if ok then
		table.insert(self._connections, connection)
	end
end

return Def
