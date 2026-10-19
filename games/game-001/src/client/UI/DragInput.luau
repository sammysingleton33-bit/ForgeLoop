--!strict
--[[
	UI/DragInput — live mouse and touch input for dragging one of my buildings (FL-0123). Studio and clients only: the
	Lune harness has no UserInputService, so specs drive BuildMenuController:dragPress / dragMove / dragRelease and
	this adapter is in the Studio steps (ui-economy.md U30).

	DragInput.connect(env, handlers, exclude: () -> { Instance }) -> disconnect: () -> ()
		handlers = {
			mine: () -> KingdomId?,                          my kingdom (a building's KingdomId attribute must match)
			press: (buildingId, screen: Vector2) -> boolean, a press on one of my buildings (true = a drag may start)
			move: (screen: Vector2, world: Vector3?) -> (),  pointer moved (world = the ground under it, ghost excluded)
			release: (world: Vector3?) -> (),                left button up / finger lifted
			active: () -> boolean,                           a press or drag is under way (move/release are sent only then)
		}
		Press   MouseButton1 or a touch that the GUI did not take (gameProcessedEvent), on a model (or a part of one)
		        with a BuildingId attribute and KingdomId == mine() (InputModeController.resolveHit's walk, 8 levels)
		Move    MouseMovement, or the same touch moving
		Release MouseButton1 up, or that touch ending
	Returns a no-op disconnect when UserInputService or the camera is unavailable.
]]

local DragInput = {}

DragInput.RAY_LENGTH = 2000

local function camera(env: any): Camera?
	local ok, cam = pcall(function()
		return env.Workspace.CurrentCamera
	end)
	return if ok then cam else nil
end

local function cast(env: any, x: number, y: number, exclude: { Instance }): RaycastResult?
	local cam = camera(env)
	if cam == nil then
		return nil
	end
	local ok, result = pcall(function()
		local ray = cam:ViewportPointToRay(x, y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		return env.Workspace:Raycast(ray.Origin, ray.Direction * DragInput.RAY_LENGTH, params)
	end)
	return if ok then result else nil
end

-- The building (id) the hit belongs to when it is one of `mine`'s; nil otherwise.
function DragInput.buildingOf(hit: Instance?, mine: any): any
	local current: any = hit
	for _ = 1, 8 do
		if current == nil then
			return nil
		end
		local ok, id, kingdom = pcall(function()
			return current:GetAttribute("BuildingId"), current:GetAttribute("KingdomId")
		end)
		if ok and id ~= nil then
			return if mine ~= nil and kingdom == mine then id else nil
		end
		current = current.Parent
	end
	return nil
end

function DragInput.connect(env: any, handlers: { [string]: any }, exclude: () -> { Instance }): () -> ()
	local ok, uis = pcall(function()
		local service = env.UserInputService
		local _ = service.InputBegan -- the boot gate's unmocked guard errors here
		return service
	end)
	if not ok or uis == nil then
		return function() end
	end
	local touch: InputObject? = nil -- the finger that pressed (other fingers are the camera's pinch)
	local function ground(x: number, y: number): Vector3?
		local result = cast(env, x, y, exclude())
		return if result then result.Position else nil
	end
	local connections = {}
	local connected = pcall(function()
		table.insert(
			connections,
			uis.InputBegan:Connect(function(input: InputObject, processed: boolean)
				local kind = input.UserInputType
				if processed or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
					return
				end
				local result = cast(env, input.Position.X, input.Position.Y, {})
				local id = DragInput.buildingOf(result and result.Instance, handlers.mine())
				if id ~= nil and handlers.press(id, Vector2.new(input.Position.X, input.Position.Y)) then
					touch = if kind == Enum.UserInputType.Touch then input else nil
				end
			end)
		)
		table.insert(
			connections,
			uis.InputChanged:Connect(function(input: InputObject)
				if not handlers.active() then
					return
				end
				local kind = input.UserInputType
				if
					kind == Enum.UserInputType.MouseMovement or (kind == Enum.UserInputType.Touch and input == touch)
				then
					local x, y = input.Position.X, input.Position.Y
					handlers.move(Vector2.new(x, y), ground(x, y))
				end
			end)
		)
		table.insert(
			connections,
			uis.InputEnded:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind == Enum.UserInputType.MouseButton1 or (kind == Enum.UserInputType.Touch and input == touch) then
					touch = nil
					if handlers.active() or kind == Enum.UserInputType.MouseButton1 then
						handlers.release(ground(input.Position.X, input.Position.Y))
					end
				end
			end)
		)
	end)
	if not connected then
		env.log("warn", "DragInput: no input events; use Move on the building's panel", {})
	end
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return table.freeze(DragInput)
