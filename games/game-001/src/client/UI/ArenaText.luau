--!strict
--[[
	UI/ArenaText — the Crown Arena's words and icons (FL-0073; design crown-arena.md §3-§5, CONTRACTS G12.1).
	Pure; no instances. The loadout picker, the intro card and the arena HUD share it.

		ArenaText.WEAPONS / ARMOUR    ordered rows { id, name, short, icon, blurb }: every option is a sidegrade
		                              (design §5), so the blurbs say what each is good at, never that one is better
		ArenaText.TIERS[tier]         { name, color (Theme token), slots, blessing } (design §3 table)
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

local ArenaText = {}

local function row(id: string, name: string, short: string, icon: string, blurb: string)
	return table.freeze({ id = id, name = name, short = short, icon = icon, blurb = blurb })
end

-- Order: the default first (DuelModel's own defaults are swordShield and medium).
ArenaText.WEAPONS = table.freeze({
	row("swordShield", "Sword and shield", "Sword", "weapon_swordShield", "Quick strikes, the steadiest block"),
	row("greatsword", "Greatsword", "Greatsword", "weapon_greatsword", "The heaviest blows, slower swings"),
	row("spear", "Spear", "Spear", "weapon_spear", "The fastest light attack"),
	row("mace", "Mace", "Mace", "weapon_mace", "Breaks guards: blocked hits cost more stamina"),
})

ArenaText.ARMOUR = table.freeze({
	row("light", "Light armour", "Light", "armour_light", "Cheap dodges, stamina returns fastest"),
	row("medium", "Medium armour", "Medium", "armour_medium", "Balanced protection and stamina"),
	row("heavy", "Heavy armour", "Heavy", "armour_heavy", "Takes the least damage, tires sooner"),
})

ArenaText.SIDEGRADES = "Every weapon and armour is a sidegrade: none is stronger overall."

ArenaText.TIERS = table.freeze({
	adoring = table.freeze({ name = "Adoring", color = "gold400", slots = 3, blessing = "Blessing +2%" }),
	loyal = table.freeze({ name = "Loyal", color = "vert", slots = 3, blessing = "Blessing +1%" }),
	divided = table.freeze({ name = "Divided", color = "parchment300", slots = 2, blessing = nil }),
	restless = table.freeze({ name = "Restless", color = "amber", slots = 1, blessing = nil }),
	hostile = table.freeze({ name = "Hostile", color = "gules", slots = 0, blessing = nil }),
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
