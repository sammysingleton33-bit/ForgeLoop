--!strict
--[[
	Experience/Cues — the kingdom feedback matrix: what the player sees and hears for each gameplay
	signal. Resolved on the client by Experience/CueDirector; played by AudioController,
	VFXController (VFX, floating text, citizen reactions) and NotificationController.

	CUES[eventName] = { Variant, ... }; the first variant whose `relation` (and `outcome`, `band`,
	`eventKind` when set) matches is used:
		relation   "mine"    the local player's kingdom acted (info.kingdomId)
		           "against" the local kingdom is the defender / loser (info.defenderKingdomId, info.fromKingdomId)
		           "others"  anyone else
		outcome    "won" | "lost"            BattleEnded / SiegeEnded, from the local kingdom's side
		band       "joyful" | "unhappy" | "recovered"   MoraleChanged, only when morale enters a band
		           (MORALE_BANDS): above high, below low, or back from below low
		eventKind  "good" | "bad"            KingdomEventStarted (GOOD_EVENTS)
	Variant fields (all optional):
		sound: sound id (Experience/Sounds)          vfx: preset id (Experience/VfxPresets)
		notify: { kind, title, body?, important? }   title/body may use {field} from info
		float: "+{amount} {resource}"                floating text at info.position
		react: citizen reaction id (Experience/CitizenReactions)
		music: "combat" | "calm"                     input to Experience/MusicDirector
		celebrate: kind for NotificationController:celebrate (FL-0027)
		coalesce: { key: "{resource}", windowSec } merges repeats: one sound, summed float/notify
	Accessibility rule (creator-docs production/publishing/accessibility.md: players with sound off
	"will be confused by in-game events that are **only** conveyed with sound"): every variant
	with a sound also has a vfx, notify, float or react. A spec enforces it.

	Event names: Experience/KingdomSignals (proposed bus events, mirrored to clients by FORGE-01's
	proposed Gameplay.KingdomEvent remote) plus SiegeImpact (client-only, high-frequency, proposed
	Gameplay.SiegeImpact unreliable remote).
]]

local Cues = {}

Cues.MORALE_BANDS = table.freeze({ low = 30, high = 70 }) -- morale < low = unhappy, > high = joyful
Cues.GOOD_EVENTS = table.freeze({ Festival = true, Harvest = true, Blessing = true })

local RESOURCE_SOUND = table.freeze({
	Food = "kingdom.farm.harvest",
	Wood = "kingdom.wood.chop",
	Stone = "kingdom.stone.mine",
	Gold = "kingdom.gold.collect",
})
local RESOURCE_VFX = table.freeze({
	Food = "kingdom.harvest.food",
	Wood = "kingdom.harvest.wood",
	Stone = "kingdom.harvest.stone",
	Gold = "kingdom.harvest.gold",
})
Cues.RESOURCE_SOUND = RESOURCE_SOUND
Cues.RESOURCE_VFX = RESOURCE_VFX

Cues.CUES = table.freeze({
	KingdomFounded = {
		{
			relation = "mine",
			sound = "kingdom.founded",
			vfx = "kingdom.territory.claim",
			notify = {
				kind = "info",
				title = "Your kingdom is founded",
				body = "Farms feed your citizens; citizens build your kingdom.",
				important = true,
			},
			react = "cheer",
			music = "calm",
		},
	},
	CitizenTaskChanged = {
		{
			relation = "mine",
			sound = "kingdom.citizen.assign",
			react = "acknowledge",
			float = "{task}",
			coalesce = { key = "task", windowSec = 1 },
		},
	},
	ResourceProduced = {
		-- sound and vfx depend on info.resource (RESOURCE_SOUND / RESOURCE_VFX)
		{
			relation = "mine",
			sound = "@resource",
			vfx = "@resource",
			float = "+{amount} {resource}",
			coalesce = { key = "{resource}", windowSec = 1.5 },
		},
	},
	ConstructionStarted = {
		{ relation = "mine", sound = "kingdom.build.place", vfx = "kingdom.construction.place", react = "work" },
		{ relation = "others", vfx = "kingdom.construction.place" },
	},
	BuildingCompleted = {
		{
			relation = "mine",
			sound = "kingdom.build.complete",
			vfx = "kingdom.construction.complete",
			notify = { kind = "info", title = "{buildingType} complete" },
			react = "cheer",
			coalesce = { key = "built", windowSec = 2 },
		},
		{ relation = "others", vfx = "kingdom.construction.complete" },
	},
	BuildingUpgraded = {
		{
			relation = "mine",
			sound = "kingdom.build.complete",
			vfx = "levelup.column",
			notify = { kind = "info", title = "{buildingType} upgraded to level {level}" },
			react = "cheer",
		},
	},
	KingdomUpgraded = {
		{
			relation = "mine",
			sound = "kingdom.upgrade.fanfare",
			vfx = "kingdom.upgrade",
			notify = { kind = "achievement", title = "Your kingdom reached tier {tier}", important = true },
			react = "cheer",
			celebrate = "kingdomTier",
		},
		{ relation = "others", notify = { kind = "info", title = "A rival kingdom reached tier {tier}" } },
	},
	UnitsRecruited = {
		{
			relation = "mine",
			sound = "kingdom.army.recruit",
			vfx = "kingdom.army.recruit",
			float = "+{count} {unitType}",
			coalesce = { key = "{unitType}", windowSec = 2 },
		},
	},
	BattleStarted = {
		{ relation = "mine", sound = "kingdom.combat.clash", vfx = "kingdom.combat.clash", music = "combat" },
		{
			relation = "against",
			sound = "kingdom.alarm.bell",
			notify = { kind = "warning", title = "Your lands are under attack!", important = true },
			react = "panic",
			music = "combat",
		},
	},
	BattleEnded = {
		{
			relation = "mine",
			outcome = "won",
			sound = "kingdom.citizen.cheer",
			notify = { kind = "reward", title = "Battle won" },
			react = "cheer",
			music = "calm",
		},
		{ relation = "mine", outcome = "lost", notify = { kind = "warning", title = "Battle lost" }, music = "calm" },
		{
			relation = "against",
			outcome = "won",
			sound = "kingdom.citizen.cheer",
			notify = { kind = "reward", title = "Attack repelled!" },
			react = "cheer",
			music = "calm",
		},
		{
			relation = "against",
			outcome = "lost",
			notify = { kind = "warning", title = "Your army was defeated", important = true },
			react = "grumble",
			music = "calm",
		},
	},
	SiegeStarted = {
		{
			relation = "mine",
			sound = "kingdom.siege.launch",
			notify = { kind = "info", title = "The siege has begun" },
			music = "combat",
		},
		{
			relation = "against",
			sound = "kingdom.alarm.bell",
			notify = { kind = "warning", title = "Your town is under siege!", important = true },
			react = "panic",
			music = "combat",
		},
	},
	SiegeImpact = {
		{ relation = "mine", sound = "kingdom.siege.impact", vfx = "kingdom.siege.impact" },
		{ relation = "against", sound = "kingdom.siege.impact", vfx = "kingdom.siege.impact", react = "panic" },
		{ relation = "others", vfx = "kingdom.siege.impact" },
	},
	SiegeEnded = {
		{
			relation = "mine",
			outcome = "won",
			sound = "kingdom.siege.breach",
			vfx = "kingdom.siege.impact",
			notify = { kind = "reward", title = "The walls are breached!", important = true },
			music = "calm",
		},
		{ relation = "mine", outcome = "lost", notify = { kind = "info", title = "The siege failed" }, music = "calm" },
		{
			relation = "against",
			outcome = "won",
			sound = "kingdom.citizen.cheer",
			notify = { kind = "reward", title = "Siege repelled!", important = true },
			react = "cheer",
			music = "calm",
		},
		{
			relation = "against",
			outcome = "lost",
			sound = "kingdom.siege.breach",
			notify = { kind = "warning", title = "Your walls were breached!", important = true },
			react = "panic",
			music = "calm",
		},
	},
	TerritoryChanged = {
		{
			relation = "mine",
			sound = "kingdom.territory.gain",
			vfx = "kingdom.territory.claim",
			notify = { kind = "info", title = "Territory claimed" },
		},
		{
			relation = "against",
			sound = "kingdom.territory.lost",
			notify = { kind = "warning", title = "You lost territory", important = true },
		},
	},
	MoraleChanged = {
		{
			relation = "mine",
			band = "joyful",
			sound = "kingdom.morale.up",
			vfx = "kingdom.morale.up",
			notify = { kind = "info", title = "Your citizens are joyful" },
			react = "cheer",
		},
		{
			relation = "mine",
			band = "unhappy",
			sound = "kingdom.morale.down",
			vfx = "kingdom.morale.down",
			notify = {
				kind = "warning",
				title = "Your citizens are unhappy",
				body = "Food, safety and festivals raise morale.",
				important = true,
			},
			react = "grumble",
		},
		{
			relation = "mine",
			band = "recovered",
			sound = "kingdom.morale.up",
			vfx = "kingdom.morale.up",
			notify = { kind = "info", title = "Your citizens are calmer" },
		},
	},
	KingdomEventStarted = {
		{
			relation = "mine",
			eventKind = "good",
			sound = "kingdom.event.festival",
			vfx = "kingdom.festival",
			notify = { kind = "info", title = "{eventId}!" },
			react = "cheer",
		},
		{
			relation = "mine",
			eventKind = "bad",
			sound = "kingdom.event.threat",
			notify = { kind = "warning", title = "{eventId} strikes your kingdom", important = true },
			react = "grumble",
		},
	},
})

return table.freeze(Cues)
