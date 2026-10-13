--!strict
--[[
	UITheme (ReplicatedStorage.Forge.Config.UITheme) for game-001 AI Kingdoms. Owned by FORGE-03.

	The AI Kingdoms look: a heraldic palette (Or, Azure, Gules, Vert, Purpure, Sable/ink,
	Argent/parchment) on dark ink panels with gold trim. Source of truth for the colours is
	design/ui/tokens.json (the HTML prototypes); games/game-001/tests/economy/UIThemeParity.spec.luau
	fails if the two drift. shared/UI/Theme.luau (ReplicatedStorage.Forge.UI.Theme) merges this over its neutral defaults, so another game
	only overrides what it needs.

	Icons: `image` is an uploaded asset id ("" until the user uploads design/ui/icons/png — handoff
	production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md); `glyph` is the text fallback.
	Kingdom colours follow CONTRACTS G2 ids (crimson, azure, emerald, gold). D-033: the four kingdom
	tinctures ARE the canonical colours of config/Kingdoms.luau (FORGE-01; crimson 190,40,50, azure
	40,110,210, emerald 35,128,95, gold 235,185,16), not variants: UIThemeParity.spec fails if they
	drift. The HUD shows the colour the server sends in Kingdom.State (the same values) and falls back
	to these. A kingdom is never shown by colour alone: crest emblem + name (HUD, standings, match
	summary), swatch + name (objective tracker, owner pills).
]]

return table.freeze({
	colors = {
		ink950 = "#0B0F18",
		ink900 = "#111725",
		ink800 = "#18202F",
		ink700 = "#212B3F",
		ink600 = "#2C3953",
		ink500 = "#3D4C6B",
		gold700 = "#8F6A26",
		gold600 = "#B48A38",
		gold500 = "#D6A84A",
		gold400 = "#EAC46C",
		gold300 = "#F6DE9C",
		parchment100 = "#F7EFDC",
		parchment200 = "#EADCBA",
		parchment300 = "#D6C295",
		inkText = "#2A2116",
		textPrimary = "#F4ECD8",
		textSecondary = "#BDB5A3",
		textMuted = "#867F72",
		vert = "#5BAE5F",
		gules = "#D9573F",
		azure = "#4E8BD0",
		amber = "#E8A23A",
		purpure = "#9A62C9",
		scrim = "#05070C",
	},
	resources = {
		food = "#8DBF4B",
		wood = "#C4844C",
		stone = "#9FB0C4",
		gold = "#F2C447",
		citizens = "#E6D7B5",
		crowns = "#EAC46C",
	},
	rarity = {
		Common = "#B9B8AE",
		Uncommon = "#5DBB63",
		Rare = "#4C8DDB",
		Epic = "#A564D3",
		Legendary = "#F0B33C",
	},
	tinctures = {
		crimson = "#BE2832",
		azure = "#286ED2",
		emerald = "#23805F",
		gold = "#EBB910",
		purpure = "#7B4AA8",
		sable = "#2B2B33",
	},
	categories = {
		economy = { "#4F7A3A", "#2F4D26" },
		civic = { "#44679A", "#283F62" },
		military = { "#8F3B2C", "#5A2219" },
	},
	fonts = {
		display = "rbxasset://fonts/families/GrenzeGotisch.json",
		heading = "rbxasset://fonts/families/Merriweather.json",
		body = "rbxasset://fonts/families/Montserrat.json",
	},
	textSize = { caption = 11, small = 12, body = 14, label = 15, title = 18, heading = 22, display = 30 },
	radius = { sm = 4, md = 8, lg = 12, pill = 999 },
	touchTarget = 44,
	icons = {
		food = { image = "", glyph = "🍞" },
		wood = { image = "", glyph = "🪵" },
		stone = { image = "", glyph = "🪨" },
		gold = { image = "", glyph = "🪙" },
		citizens = { image = "", glyph = "👥" },
		crown = { image = "", glyph = "👑" },
		gem = { image = "", glyph = "💎" }, -- Crown Points: never a crown, which is Emberhold's emblem (D-039)
		-- FORGE-04's settings panel on the HUD rail (FL-0103, #123): sliders, not a cog (⚙ is Competence)
		settings = { image = "", glyph = "🎚" },
		build = { image = "", glyph = "🔨" },
		kingdom = { image = "", glyph = "🏰" },
		army = { image = "", glyph = "⚔" },
		standings = { image = "", glyph = "🏆" },
		timer = { image = "", glyph = "⏳" },
		lock = { image = "", glyph = "🔒" },
		check = { image = "", glyph = "✔" },
		cross = { image = "", glyph = "✖" },
		close = { image = "", glyph = "✕" },
		plus = { image = "", glyph = "+" },
		minus = { image = "", glyph = "−" },
		info = { image = "", glyph = "ℹ" },
		warning = { image = "", glyph = "⚠" },
		townhall = { image = "", glyph = "🏛" },
		house = { image = "", glyph = "🏠" },
		storehouse = { image = "", glyph = "📦" },
		farm = { image = "", glyph = "🌾" },
		lumbercamp = { image = "", glyph = "🪓" },
		quarry = { image = "", glyph = "⛏" },
		goldmine = { image = "", glyph = "⚒" },
		barracks = { image = "", glyph = "🛡" },
		watchtower = { image = "", glyph = "🗼" },
		militia = { image = "", glyph = "🗡" },
		archer = { image = "", glyph = "🏹" },
		knight = { image = "", glyph = "🐴" },
		banner = { image = "", glyph = "🚩" },
		crest = { image = "", glyph = "🛡" },
		chest = { image = "", glyph = "🧰" },
		keep = { image = "", glyph = "♜" },
		wall = { image = "", glyph = "🧱" },
		gate = { image = "", glyph = "🚪" },
		rotate = { image = "", glyph = "⟳" },
		emblem_crown = { image = "", glyph = "♛" }, -- Emberhold (drawn by UI/Crest unless an image is uploaded)
		emblem_star = { image = "", glyph = "★" },
		emblem_oak = { image = "", glyph = "🌳" },
		emblem_sun = { image = "", glyph = "☀" },
		-- FL-0088 citizen card and conversation (design/ui/icons.js)
		talk = { image = "", glyph = "💬" },
		heart = { image = "", glyph = "❤" },
		mood = { image = "", glyph = "🙂" },
		scroll = { image = "", glyph = "📜" },
		laurel = { image = "", glyph = "🏅" },
		-- FL-0089: reputation categories (living-kingdom §3) and kingdom conditions
		rep_compassion = { image = "", glyph = "❤" },
		rep_honor = { image = "", glyph = "⚖" },
		rep_competence = { image = "", glyph = "⚙" },
		rep_courage = { image = "", glyph = "🦁" },
		rep_authority = { image = "", glyph = "⚜" },
		rep_fear = { image = "", glyph = "💀" },
		happiness = { image = "", glyph = "😊" },
		stability = { image = "", glyph = "🏛" },
	},
})
