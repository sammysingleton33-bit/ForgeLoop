--[[
	Settings panel scene (FL-0103) for FORGE-03's headless renderer: the real Experience/SettingsPanel
	in game-001's menu drawer (UI/Layout, scaled like KingdomHudController's roots), with a few
	settings changed from their defaults and the device's Reduce Motion on.
		PROJECT=games/game-001/default.project.json DEVICES="phone desktop" \
			RENDER_FLAGS="--shots=<dir>" bash design/ui/render/shoot-luau.sh roblox/tests/unit/experience/scenes/settings.luau
	A headless approximation, not the Studio check (E2).
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local SettingsModel = require("@game/ReplicatedStorage/Forge/Experience/SettingsModel")
local SettingsPanel = require("@game/ReplicatedStorage/Forge/Experience/SettingsPanel")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")

return function(ctx)
	Create.useTestConnector()
	local m = Layout.compute(ctx.core.width, ctx.core.height)
	local gui = Create("ScreenGui", {
		Name = "KingdomMenus",
		DisplayOrder = 20,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		IgnoreGuiInset = false,
	})
	local root = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1 / m.scale, 1 / m.scale),
		Parent = gui,
	}, { Scale = Create("UIScale", { Scale = m.scale }) })
	local d = m.drawer
	local panel = SettingsPanel.new(root)
	panel:render(
		SettingsModel.sections({
			musicVolume = 0.4,
			sfxVolume = 0.8,
			ambienceVolume = 0,
			cameraShake = false,
			notifications = "important",
		}, { platformReducedMotion = true }),
		{ x = d.x, y = d.y, width = d.width, height = d.height, compact = m.breakpoint == "phone" },
		{}
	)
	return { guis = { gui } }
end
