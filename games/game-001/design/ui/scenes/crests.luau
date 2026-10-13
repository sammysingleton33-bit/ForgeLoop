-- D-033 / FORGE-05 on #79 scene "crests": the four kingdom crests (UI/Crest) in the canonical
-- config/Kingdoms.luau colours at the HUD badge (58 px), large (120 px) and the standings (22 px)
-- sizes, each with its name: the emblem must read on every tile (gold takes a dark emblem).
-- Render with a custom size: DEVICES="900x420" ... shoot-luau.sh <this scene>.
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Crest")
local HudModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/HudModel")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

return function(ctx)
	Create.useTestConnector()
	local gui = Create("ScreenGui", { Name = "Crests" })
	local sheet = Create("Frame", {
		Name = "Sheet",
		BackgroundColor3 = Theme.color("ink900"),
		Size = UDim2.fromOffset(ctx.core.width, ctx.core.height),
		Parent = gui,
	}, {
		Padding = Style.padding(20),
		List = Style.list("x", 24, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	for i, k in KingdomsConfig.identities do
		local color = Color3.fromRGB(k.color[1], k.color[2], k.color[3])
		local emblem = HudModel.EMBLEMS[k.id]
		local column = Create("Frame", {
			Name = "Kingdom_" .. k.id,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(170, 360),
			LayoutOrder = i,
			Parent = sheet,
		}, {
			List = Style.list("y", 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		})
		for j, size in { 120, 58, 22 } do
			local crest = Crest.new(size, color, emblem)
			crest.LayoutOrder = j
			crest.Parent = column
		end
		Style.text({
			text = k.name,
			weight = Enum.FontWeight.Bold,
			size = 16,
			color = Theme.color("parchment100"),
			xAlign = "Center",
			extra = { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4 },
		}).Parent =
			column
	end
	return { guis = { gui } }
end
