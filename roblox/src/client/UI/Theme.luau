--!strict
--[[
	UI/Theme — design tokens for every FORGELOOP component (interfaces §9). Neutral defaults here;
	each game overrides them in games/<game>/config/UITheme.luau (merged per key, hex colours).

	API
		Theme.color(name) -> Color3          colors.<name> (ink950..ink500, gold700..gold300,
		                                     parchment*, text*, vert, gules, azure, amber, purpure, scrim)
		Theme.resource(id) -> Color3         resources.<id> (falls back to textPrimary)
		Theme.rarity(name) -> Color3         Common / Uncommon / Rare / Epic / Legendary
		Theme.tincture(name) -> Color3       kingdom colours (azure, gules, vert, purpure, or, sable)
		Theme.category(name) -> (Color3, Color3)   tile gradient top/bottom per building category
		Theme.font(role, weight?) -> Font    role: "display" | "heading" | "body"; weight: Enum.FontWeight
		Theme.textSize(name) -> number       caption small body label title heading display
		Theme.radius(name) -> UDim           sm md lg pill
		Theme.space(n) -> number             spacing scale step n (0..10): 0 2 4 6 8 12 16 20 24 32 40
		Theme.TOUCH -> number                minimum touch target (44)
		Theme.icon(name) -> { image: string, glyph: string }
		Theme.hex(s) -> Color3               "#RRGGBB"
		Theme.gradient(top, bottom, rotation?) -> ColorSequence   two-stop helper for UIGradient
		Theme.raw -> the merged token table (hex strings), for tools and parity specs
]]

local Config = require("@game/ReplicatedStorage/Forge/Config/UITheme")

local DEFAULTS = {
	colors = {
		ink950 = "#0E0F12",
		ink900 = "#15171C",
		ink800 = "#1C1F26",
		ink700 = "#252932",
		ink600 = "#30353F",
		ink500 = "#434A57",
		gold700 = "#7A6A45",
		gold600 = "#A08D5E",
		gold500 = "#C2AE7B",
		gold400 = "#D8C798",
		gold300 = "#EDE1BF",
		parchment100 = "#F5F3EE",
		parchment200 = "#E6E2D8",
		parchment300 = "#CFC8B8",
		inkText = "#1C1F26",
		textPrimary = "#F2F2F2",
		textSecondary = "#B8BCC6",
		textMuted = "#7E838E",
		vert = "#4FAE62",
		gules = "#D9534F",
		azure = "#4C8BD6",
		amber = "#E6A23C",
		purpure = "#9B6BD3",
		scrim = "#000000",
	},
	resources = {},
	rarity = {
		Common = "#B9B9B9",
		Uncommon = "#5DBB63",
		Rare = "#4C8DDB",
		Epic = "#A564D3",
		Legendary = "#F0B33C",
	},
	tinctures = {},
	categories = {},
	fonts = {
		display = "rbxasset://fonts/families/BuilderSans.json",
		heading = "rbxasset://fonts/families/BuilderSans.json",
		body = "rbxasset://fonts/families/BuilderSans.json",
	},
	textSize = { caption = 11, small = 12, body = 14, label = 15, title = 18, heading = 22, display = 30 },
	radius = { sm = 4, md = 8, lg = 12, pill = 999 },
	space = { 0, 2, 4, 6, 8, 12, 16, 20, 24, 32, 40 },
	touchTarget = 44,
	icons = {},
}

local function merge(base: { [string]: any }, over: { [string]: any }?): { [string]: any }
	local out = table.clone(base)
	for key, value in over or {} do
		if type(value) == "table" and type(base[key]) == "table" and #value == 0 then
			out[key] = merge(base[key], value)
		else
			out[key] = value
		end
	end
	return out
end

local raw = merge(DEFAULTS, Config :: any)

local Theme = {}
Theme.raw = raw
Theme.TOUCH = raw.touchTarget

local cache: { [string]: Color3 } = {}

function Theme.hex(s: string): Color3
	local cached = cache[s]
	if cached then
		return cached
	end
	local r, g, b = string.match(s, "^#(%x%x)(%x%x)(%x%x)$")
	assert(r and g and b, `Theme.hex: '{s}' is not #RRGGBB`)
	local color = Color3.fromRGB(tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number)
	cache[s] = color
	return color
end

function Theme.color(name: string): Color3
	local value = raw.colors[name]
	assert(value, `Theme.color: unknown colour '{name}'`)
	return Theme.hex(value)
end

function Theme.resource(id: string): Color3
	local value = raw.resources[id]
	return if value then Theme.hex(value) else Theme.color("textPrimary")
end

function Theme.rarity(name: string): Color3
	local value = raw.rarity[name]
	assert(value, `Theme.rarity: unknown rarity '{name}'`)
	return Theme.hex(value)
end

function Theme.tincture(name: string): Color3
	local value = raw.tinctures[name]
	return if value then Theme.hex(value) else Theme.color("azure")
end

function Theme.category(name: string): (Color3, Color3)
	local pair = raw.categories[name]
	if pair then
		return Theme.hex(pair[1]), Theme.hex(pair[2])
	end
	return Theme.color("ink600"), Theme.color("ink800")
end

function Theme.font(role: string, weight: any?): Font
	local family = raw.fonts[role]
	assert(family, `Theme.font: unknown role '{role}'`)
	return Font.new(family, weight or Enum.FontWeight.Regular)
end

function Theme.textSize(name: string): number
	local value = raw.textSize[name]
	assert(value, `Theme.textSize: unknown size '{name}'`)
	return value
end

function Theme.radius(name: string): UDim
	local value = raw.radius[name]
	assert(value, `Theme.radius: unknown radius '{name}'`)
	return UDim.new(0, value)
end

function Theme.space(n: number): number
	local value = raw.space[n + 1]
	assert(value, `Theme.space: no step {n}`)
	return value
end

function Theme.icon(name: string): { image: string, glyph: string }
	local icon = raw.icons[name]
	return icon or { image = "", glyph = "•" }
end

function Theme.gradient(top: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new(top, bottom)
end

return table.freeze(Theme)
