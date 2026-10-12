--!strict
--[[
	UI/PlacementInput — live mouse, touch and keyboard input for placing a building (Studio and
	clients only: the Lune harness has no UserInputService, so specs drive BuildMenuController's
	methods directly and this adapter is listed in the Studio steps).

	PlacementInput.connect(env, handlers, exclude: () -> { Instance }) -> disconnect: () -> ()
		handlers = { active: () -> boolean, aim: (Vector3) -> (), rotate: () -> (),
		             confirm: () -> (), cancel: () -> () }
		Desktop   mouse move aims the ghost; left click places; R rotates; Q cancels (Esc belongs to
		          the Roblox menu)
		Touch     a tap on the ground moves the ghost there; the Place button confirms (a stray tap
		          never spends resources)
		Input the GUI already handled (gameProcessedEvent) is ignored, so taps on the HUD and the
		placement bar never move the ghost.
	PlacementInput.aimAtScreenCentre(env, aim, exclude)   first ghost spot when placing starts
	Returns a no-op disconnect when UserInputService or the camera is unavailable.
]]

local PlacementInput = {}

PlacementInput.RAY_LENGTH = 600

local function cast(env: any, ray: Ray, exclude: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = env.Workspace:Raycast(ray.Origin, ray.Direction * PlacementInput.RAY_LENGTH, params)
	return if result then result.Position else nil
end

local function camera(env: any): Camera?
	local ok, cam = pcall(function()
		return env.Workspace.CurrentCamera
	end)
	return if ok then cam else nil
end

function PlacementInput.aimAtScreenCentre(env: any, aim: (Vector3) -> (), exclude: () -> { Instance })
	local cam = camera(env)
	if cam == nil then
		return
	end
	local ok = pcall(function()
		local size = cam.ViewportSize
		local hit = cast(env, cam:ViewportPointToRay(size.X / 2, size.Y * 0.62), exclude())
		if hit then
			aim(hit)
		end
	end)
	if not ok then
		env.log("warn", "PlacementInput: could not aim at the screen centre", {})
	end
end

function PlacementInput.connect(env: any, handlers: { [string]: any }, exclude: () -> { Instance }): () -> ()
	local ok, uis = pcall(function()
		return env.UserInputService
	end)
	if not ok or uis == nil then
		return function() end
	end
	local function aimAt(x: number, y: number)
		local cam = camera(env)
		if cam then
			local hit = cast(env, cam:ScreenPointToRay(x, y), exclude())
			if hit then
				handlers.aim(hit)
			end
		end
	end
	local connections = {}
	local connected = pcall(function()
		table.insert(
			connections,
			uis.InputChanged:Connect(function(input: InputObject, processed: boolean)
				if handlers.active() and not processed and input.UserInputType == Enum.UserInputType.MouseMovement then
					aimAt(input.Position.X, input.Position.Y)
				end
			end)
		)
		table.insert(
			connections,
			uis.InputBegan:Connect(function(input: InputObject, processed: boolean)
				if processed or not handlers.active() then
					return
				end
				local kind = input.UserInputType
				if kind == Enum.UserInputType.Touch then
					aimAt(input.Position.X, input.Position.Y)
				elseif kind == Enum.UserInputType.MouseButton1 then
					aimAt(input.Position.X, input.Position.Y)
					handlers.confirm()
				elseif kind == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.R then
						handlers.rotate()
					elseif input.KeyCode == Enum.KeyCode.Q then
						handlers.cancel()
					end
				end
			end)
		)
	end)
	if not connected then
		env.log("warn", "PlacementInput: no input events; use the placement bar buttons", {})
	end
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return table.freeze(PlacementInput)
