--!strict
--[[
	UI/ArenaText — the Crown Arena's words and icons (FL-0073; design crown-arena.md §3-§5, CONTRACTS G12.1).
	Pure; no instances. The loadout picker, the intro card and the arena HUD share it.

		ArenaText.WEAPONS / ARMOUR    ordered rows { id, name, short, icon, blurb }: every option is a sidegrade
		                              (design §5), so the blurbs say what each is good at, never that one is better
		ArenaText.TIERS[tier]         { name, color (Theme token), slots, blessing } (slots and blessing from config
		                              Support.tiers; design §3 table)
		ArenaText.blessing(passive) -> "Blessing +1%"?   the largest passive fraction as a percent
		ArenaText.TRIGGERS[id]        { name, icon, short } (design §4 table; the server's TriggerOffer carries the
		                              exact effect and condition text)
		ArenaText.weapon(id) / armour(id) / tier(tier) / trigger(id)   a row, or a neutral fallback for an
		                              unknown id (a newer server never breaks the screen)
		ArenaText.triggerFromSource(source) -> TriggerId?   DuelModel's triggerFired data.source
		                              ("perk:reforge", "crowdRally") back to the trigger
		ArenaText.ROLES[role]         "Blacksmith", ...
		ArenaText.POWER[power]        "Pledged" / "Empowered"
		ArenaText.REASONS[code]       Arena.Choose refusals in words
		ArenaText.SIDEGRADES          the one line that says no loadout is stronger overall
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")

local ArenaText = {}

-- `shortBlurb`: the phone tile's two lines (667x375 fit, FL-0138); the blurb otherwise.
local function row(id: string, name: string, short: string, icon: string, blurb: string, shortBlurb: string?)
	return table.freeze({ id = id, name = name, short = short, icon = icon, blurb = blurb, shortBlurb = shortBlurb })
end

-- Order: the default first (DuelModel's own defaults are swordShield and medium).
ArenaText.WEAPONS = table.freeze({
	row(
		"swordShield",
		"Sword and shield",
		"Sword & shield",
		"weapon_swordShield",
		"Quick strikes, the steadiest block"
	),
	row("greatsword", "Greatsword", "Greatsword", "weapon_greatsword", "The heaviest blows, slower swings"),
	row("spear", "Spear", "Spear", "weapon_spear", "The fastest light attack"),
	row(
		"mace",
		"Mace",
		"Mace",
		"weapon_mace",
		"Breaks guards: blocked hits cost more stamina",
		"Breaks guards by draining stamina"
	),
})

ArenaText.ARMOUR = table.freeze({
	row("light", "Light armour", "Light", "armour_light", "Cheap dodges, stamina returns fastest"),
	row("medium", "Medium armour", "Medium", "armour_medium", "Balanced protection and stamina"),
	row("heavy", "Heavy armour", "Heavy", "armour_heavy", "Takes the least damage, tires sooner"),
})

ArenaText.SIDEGRADES = "Every weapon and armour is a sidegrade: none is stronger overall."

-- The blessing text and slots come from FORGE-01's config Support (tiers[t].passive, .slots), so a tuning change never
-- leaves the screen saying an old number (FORGE-07 L2 on #214; trim C made Adoring's +2 % a +1 %).
function ArenaText.blessing(passive: any): string?
	local best = 0
	for _, v in if type(passive) == "table" then passive else {} do
		if type(v) == "number" and v > best then
			best = v
		end
	end
	if best <= 0 then
		return nil
	end
	return `Blessing +{math.floor(best * 100 + 0.5)}%`
end

local function tierRow(id: string, name: string, color: string): any
	local t = Support.tiers[id] or {}
	return table.freeze({
		name = name,
		color = color,
		slots = if type(t.slots) == "number" then t.slots else 0,
		blessing = ArenaText.blessing(t.passive),
	})
end

ArenaText.TIERS = table.freeze({
	adoring = tierRow("adoring", "Adoring", "gold400"),
	loyal = tierRow("loyal", "Loyal", "vert"),
	divided = tierRow("divided", "Divided", "parchment300"),
	restless = tierRow("restless", "Restless", "amber"),
	hostile = tierRow("hostile", "Hostile", "gules"),
})

ArenaText.TRIGGERS = table.freeze({
	reforge = table.freeze({ name = "Reforge", icon = "trigger_reforge", short = "Armour hammered back" }),
	fieldRemedy = table.freeze({ name = "Field Remedy", icon = "trigger_fieldRemedy", short = "Healing herbs" }),
	calledWarning = table.freeze({
		name = "Called Warning",
		icon = "trigger_calledWarning",
		short = "Heavy attacks called early",
	}),
	heartyRations = table.freeze({ name = "Hearty Rations", icon = "trigger_heartyRations", short = "Stamina returns" }),
	rallyingHymn = table.freeze({ name = "Rallying Hymn", icon = "trigger_rallyingHymn", short = "The stand sings" }),
	fineWares = table.freeze({ name = "Fine Wares", icon = "trigger_fineWares", short = "Finer steel all duel" }),
	crowdRally = table.freeze({ name = "Crowd Rally", icon = "trigger_crowdRally", short = "The whole stand roars" }),
})

ArenaText.ROLES = table.freeze({
	blacksmith = "Blacksmith",
	healer = "Healer",
	captain = "Captain",
	provisioner = "Provisioner",
	elder = "Elder",
	merchant = "Merchant",
})

ArenaText.POWER = table.freeze({ pledged = "Pledged", empowered = "Empowered" })

ArenaText.REASONS = table.freeze({
	not_champion = "Only the champion picks the loadout",
	stage = "The loadout pick is over",
	not_offered = "That perk is not offered to you",
	too_many = "Too many perks for your slots",
	invalid_args = "That choice was not accepted",
})

local UNKNOWN = table.freeze({ id = "", name = "Unknown", short = "?", icon = "info", blurb = "" })

local function find(list: { any }, id: any): any
	for _, r in list do
		if r.id == id then
			return r
		end
	end
	return nil
end

function ArenaText.weapon(id: any): any
	return find(ArenaText.WEAPONS, id) or UNKNOWN
end

function ArenaText.armour(id: any): any
	return find(ArenaText.ARMOUR, id) or UNKNOWN
end

function ArenaText.tier(tier: any): any
	return ArenaText.TIERS[tier] or table.freeze({ name = "Unknown", color = "textMuted", slots = 0 })
end

function ArenaText.trigger(id: any): any
	return ArenaText.TRIGGERS[id] or table.freeze({ name = tostring(id), icon = "info", short = "" })
end

function ArenaText.triggerFromSource(source: any): string?
	if type(source) ~= "string" then
		return nil
	end
	local id = string.match(source, "^perk:(.+)$") or source
	return if ArenaText.TRIGGERS[id] then id else nil
end

return table.freeze(ArenaText)
