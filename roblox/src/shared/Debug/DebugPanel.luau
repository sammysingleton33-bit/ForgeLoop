--!strict
--[[
	Debug/DebugPanel — the Studio debug panel on the client (FL-0068, D-028). Owned by FORGE-05.

	Main.client calls DebugPanel.start(env). Outside Studio it returns nil and builds nothing. In
	Studio it waits (up to 10 s, in its own thread) for ReplicatedStorage.ForgeDebug (Debug/DebugServer),
	asks the server for the command list and builds a small panel in PlayerGui:

		[Debug F8]  toggle button (top left); F8 toggles too
		Presets     one button per preset (e.g. "vs1.row4 — Row 4: citizens at work")
		Commands    one button per command without arguments; commands with arguments are listed
		            with their argument count (run them from code or a preset)
		Result      the server's answer to the last press

		DebugPanel.start(env) -> Handle?     Handle = { ready: boolean, press(kind, name) -> (ok, message),
		                                               refresh(), gui: ScreenGui?, stop() }
	The panel only sends names; the server validates and runs everything (DebugServer/DebugCommands).
]]

local DebugPanel = {}

export type Handle = {
	ready: boolean,
	gui: any?,
	press: (kind: string, name: string) -> (boolean, string),
	refresh: () -> (),
	stop: () -> (),
}

local WAIT_SECONDS = 10

-- Connects fn to a GUI event when the engine provides it (Roblox); headless harnesses have no
-- input events, and specs drive the panel through handle.press instead.
local function connect(instance: any, eventName: string, fn: (...any) -> ()): any?
	local ok, signal = pcall(function()
		return instance[eventName]
	end)
	if ok and typeof(signal) == "RBXScriptSignal" then
		return signal:Connect(fn)
	end
	return nil
end

local function makeButton(env: any, parent: any, text: string, order: number): any
	local button = env.newInstance("TextButton")
	button.Name = "Button"
	button.Text = text
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 26)
	button.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	button.TextColor3 = Color3.fromRGB(235, 235, 235)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 14
	button.Parent = parent
	return button
end

function DebugPanel.start(env: any): Handle?
	if not env.RunService:IsStudio() then
		return nil
	end
	local connections = {}
	local handle: Handle = {
		ready = false,
		gui = nil,
		press = function(_kind: string, _name: string): (boolean, string)
			return false, "debug panel not ready (no ReplicatedStorage.ForgeDebug yet)"
		end,
		refresh = function() end,
		stop = function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}

	env.spawn(function()
		local remotes = env.ReplicatedStorage:WaitForChild("ForgeDebug", WAIT_SECONDS)
		if remotes == nil then
			env.log("warn", "debug panel: ReplicatedStorage.ForgeDebug not found (server not in Studio?)")
			return
		end
		local listRemote = remotes:WaitForChild("List", WAIT_SECONDS)
		local runRemote = remotes:WaitForChild("Run", WAIT_SECONDS)
		local player = env.Players.LocalPlayer
		local playerGui = player and player:WaitForChild("PlayerGui", WAIT_SECONDS)
		if listRemote == nil or runRemote == nil or playerGui == nil then
			env.log("warn", "debug panel: remotes or PlayerGui missing")
			return
		end

		local gui = env.newInstance("ScreenGui")
		gui.Name = "ForgeDebugPanel"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 1000
		local toggle = makeButton(env, gui, "  Debug (F8)", 0)
		toggle.Name = "Toggle"
		toggle.Size = UDim2.fromOffset(110, 28)
		toggle.Position = UDim2.fromOffset(8, 8)
		local frame = env.newInstance("ScrollingFrame")
		frame.Name = "Panel"
		frame.Size = UDim2.fromOffset(340, 420)
		frame.Position = UDim2.fromOffset(8, 42)
		frame.BackgroundColor3 = Color3.fromRGB(24, 26, 31)
		frame.BackgroundTransparency = 0.1
		frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		frame.CanvasSize = UDim2.new()
		frame.Visible = false
		frame.Parent = gui
		local layout = env.newInstance("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 3)
		layout.Parent = frame
		local result = env.newInstance("TextLabel")
		result.Name = "Result"
		result.Size = UDim2.fromOffset(340, 48)
		result.Position = UDim2.fromOffset(8, 466)
		result.BackgroundTransparency = 0.2
		result.BackgroundColor3 = Color3.fromRGB(24, 26, 31)
		result.TextColor3 = Color3.fromRGB(255, 220, 120)
		result.TextWrapped = true
		result.TextXAlignment = Enum.TextXAlignment.Left
		result.Text = ""
		result.Visible = false
		result.Parent = gui

		local function press(kind: string, name: string): (boolean, string)
			local answer = runRemote:InvokeServer(kind, name)
			local ok = type(answer) == "table" and answer.ok == true
			local message = if type(answer) == "table" then tostring(answer.message) else "no answer"
			result.Text = (if ok then "OK  " else "FAIL  ") .. message
			result.Visible = true
			return ok, message
		end
		handle.press = press

		local function refresh()
			for _, child in frame:GetChildren() do
				if child:IsA("TextButton") or child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local listing = listRemote:InvokeServer()
			local order = 1
			local function header(text: string)
				local label = env.newInstance("TextLabel")
				label.Name = "Header"
				label.Text = text
				label.LayoutOrder = order
				label.Size = UDim2.new(1, 0, 0, 22)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.fromRGB(150, 200, 255)
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = frame
				order += 1
			end
			header("Presets")
			for _, preset in (listing and listing.presets) or {} do
				local button = makeButton(env, frame, `  {preset.name} — {preset.label}`, order)
				order += 1
				local connection = connect(button, "Activated", function()
					press("preset", preset.name)
				end)
				if connection then
					table.insert(connections, connection)
				end
			end
			header("Commands")
			for _, command in (listing and listing.commands) or {} do
				if command.argCount == 0 then
					local button = makeButton(env, frame, `  {command.name} — {command.label}`, order)
					order += 1
					local connection = connect(button, "Activated", function()
						press("command", command.name)
					end)
					if connection then
						table.insert(connections, connection)
					end
				else
					header(`  {command.name} ({command.argCount} args: run from a preset or code)`)
				end
			end
		end
		handle.refresh = refresh

		local toggled = connect(toggle, "Activated", function()
			frame.Visible = not frame.Visible
			if frame.Visible then
				refresh()
			end
		end)
		if toggled then
			table.insert(connections, toggled)
		end
		local input = env.UserInputService
		if input then
			local keyed = connect(input, "InputBegan", function(inputObject: any, processed: boolean)
				if not processed and inputObject.KeyCode == Enum.KeyCode.F8 then
					frame.Visible = not frame.Visible
					if frame.Visible then
						refresh()
					end
				end
			end)
			if keyed then
				table.insert(connections, keyed)
			end
		end

		refresh()
		gui.Parent = playerGui
		handle.gui = gui
		handle.ready = true
	end)
	return handle
end

return DebugPanel
