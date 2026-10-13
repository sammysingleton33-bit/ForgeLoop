-- FL-0020: the game-001 UITheme (Luau) must match design/ui/tokens.json (the HTML prototypes the
-- design was reviewed on). Fails when one side changes without the other.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local UITheme = require("@game/ReplicatedStorage/Forge/Config/UITheme")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local tokens = serde.decode("json", fs.readFile(T.root .. "/design/ui/tokens.json"))

describe("game-001 UITheme parity with design/ui/tokens.json", function()
	it("has the same colours, resources, rarities and kingdom tinctures", function()
		for _, pair in
			{ { "color", "colors" }, { "resource", "resources" }, { "rarity", "rarity" }, { "tincture", "tinctures" } }
		do
			local fromTokens, fromTheme = tokens[pair[1]], UITheme[pair[2]]
			for key, hex in fromTokens do
				if string.upper(fromTheme[key] or "") ~= string.upper(hex) then
					error(`{pair[2]}.{key}: UITheme {tostring(fromTheme[key])} vs tokens {hex}`)
				end
			end
			for key in fromTheme do
				expect(fromTokens[key]).toBeTruthy()
			end
		end
	end)

	it("uses the Roblox font families the prototypes were drawn with", function()
		expect(UITheme.fonts).toEqual(tokens.robloxFont)
		expect(UITheme.textSize).toEqual(tokens.textSize)
		expect(UITheme.touchTarget).toBe(tokens.touchTarget)
	end)

	it("D-033: the kingdom tinctures are config/Kingdoms.luau's canonical colours, not variants", function()
		local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
		expect(#KingdomsConfig.identities).toBe(4)
		for _, k in KingdomsConfig.identities do
			local canonical = Color3.fromRGB(k.color[1], k.color[2], k.color[3])
			if Theme.tincture(k.id) ~= canonical then
				error(`tinctures.{k.id} {UITheme.tinctures[k.id]} vs Kingdoms.luau {table.concat(k.color, ",")}`)
			end
		end
	end)

	it("resolves through shared/UI/Theme for the four G2 kingdoms", function()
		for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
			expect(Theme.tincture(kingdom)).toEqual(Theme.hex(UITheme.tinctures[kingdom]))
		end
	end)
end)
