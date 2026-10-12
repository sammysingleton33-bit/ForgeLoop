--!strict
--[[
	Experience/Sounds — the sound registry every game uses (interfaces §8: AudioController:play ids).

	FACTORY entries (UI, notifications, reward tiers, celebrations, onboarding) are shared by every
	game; each game adds its own in games/<game>/config/Sounds.luau (owner FORGE-04), which may
	override a factory id. Rules and fields: Experience/SoundRegistry.luau.

	No asset ids are filled in yet: choosing Creator Store sounds or uploading originals needs the
	user's Roblox account (handoff production/handoffs/2026-10-12-forge-04-to-user-sounds.md).
	Until then AudioController skips "needed" sounds and counts them, so the game runs silently
	instead of failing, and every cue also has a visual (CueDirector.validate rejects sound-only cues).

		local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
		Sounds.registry:get("ui.click")         Sounds.FACTORY    Sounds.LICENCE
]]

local ConfigSounds = require("@game/ReplicatedStorage/Forge/Config/Sounds")
local SoundRegistry = require("./SoundRegistry")

local LICENCE = table.freeze({
	creatorStore = "Creator Store audio: 'free-to-use audio assets made by Roblox and the Roblox community for creators to use within their games' (creator-docs audio/assets.md @af5f853). Record asset id, title and creator in source; check it plays in our place (privacy.md: restricted assets need a permission grant).",
	original = "Original audio owned by the project, imported from the owner's account (audio/assets.md: 100 free imports per 30 days unverified, 2,000 ID-verified; mp3/ogg/wav/flac, < 20 MB, < 7 min).",
})

local STORE = "Creator Store (Toolbox > Audio) search: "

local FACTORY = {
	-- UI (2D, short, quiet; mobile speakers have a limited frequency range, test-on-hardware.md)
	{
		id = "ui.click",
		category = "ui",
		volume = 0.5,
		status = "needed",
		source = STORE .. "'ui click soft' / 'wood tap'",
		licence = LICENCE.creatorStore,
		description = "Soft, dry tap under 80 ms; must not tire after 500 presses.",
		maxInstances = 2,
		cooldown = 0.04,
		pitchVariance = 0.03,
	},
	{
		id = "ui.open",
		category = "ui",
		volume = 0.45,
		status = "needed",
		source = STORE .. "'parchment unroll' / 'book open'",
		licence = LICENCE.creatorStore,
		description = "Panel opens: short paper/leather swish, 150-250 ms.",
		maxInstances = 1,
		cooldown = 0.1,
	},
	{
		id = "ui.close",
		category = "ui",
		volume = 0.4,
		status = "needed",
		source = STORE .. "'parchment close' / 'book close'",
		licence = LICENCE.creatorStore,
		description = "Panel closes: softer, lower mirror of ui.open.",
		maxInstances = 1,
		cooldown = 0.1,
	},
	{
		id = "ui.error",
		category = "ui",
		volume = 0.45,
		status = "needed",
		source = STORE .. "'wooden thud' / 'denied soft'",
		licence = LICENCE.creatorStore,
		description = "Not allowed / not enough resources: low muted knock, never a harsh buzzer.",
		maxInstances = 1,
		cooldown = 0.3,
	},
	-- Notifications (NotificationController kinds, interfaces §8)
	{
		id = "notify.info",
		category = "ui",
		volume = 0.45,
		status = "needed",
		source = STORE .. "'soft bell single'",
		licence = LICENCE.creatorStore,
		description = "Small hand bell, one strike, 300 ms tail.",
		maxInstances = 1,
		cooldown = 0.5,
	},
	{
		id = "notify.reward",
		category = "ui",
		volume = 0.6,
		status = "needed",
		source = STORE .. "'coins pouch' / 'gold coins'",
		licence = LICENCE.creatorStore,
		description = "Coins dropping into a pouch, bright and short (under 600 ms).",
		maxInstances = 1,
		cooldown = 0.3,
		pitchVariance = 0.04,
	},
	{
		id = "notify.warning",
		category = "ui",
		volume = 0.6,
		status = "needed",
		source = STORE .. "'war drum hit' / 'low horn short'",
		licence = LICENCE.creatorStore,
		description = "Attention without panic: one low drum hit or short low horn.",
		maxInstances = 1,
		cooldown = 1,
	},
	{
		id = "notify.achievement",
		category = "ui",
		volume = 0.7,
		status = "needed",
		source = STORE .. "'fanfare short' / 'trumpet flourish'",
		licence = LICENCE.creatorStore,
		description = "Two-second brass flourish; the most rewarding UI sound, used sparingly.",
		maxInstances = 1,
		cooldown = 1,
	},
	-- Reward tiers: one audio identity per tier across every game (intelligence/retention/variable-rewards.md §2)
	{
		id = "reward.common",
		category = "ui",
		volume = 0.5,
		status = "needed",
		source = STORE .. "'pickup soft'",
		licence = LICENCE.creatorStore,
		description = "Short tick; the baseline every other tier rises above.",
		maxInstances = 2,
		cooldown = 0.1,
	},
	{
		id = "reward.uncommon",
		category = "ui",
		volume = 0.55,
		status = "needed",
		source = STORE .. "'chime two notes'",
		licence = LICENCE.creatorStore,
		description = "Two rising notes.",
		maxInstances = 1,
		cooldown = 0.2,
	},
	{
		id = "reward.rare",
		category = "ui",
		volume = 0.6,
		status = "needed",
		source = STORE .. "'magic chime' / 'sparkle'",
		licence = LICENCE.creatorStore,
		description = "Three-note sparkle with a short shimmer tail.",
		maxInstances = 1,
		cooldown = 0.3,
	},
	{
		id = "reward.epic",
		category = "ui",
		volume = 0.7,
		status = "needed",
		source = STORE .. "'epic reveal' / 'choir hit'",
		licence = LICENCE.creatorStore,
		description = "Distinct sting: choir or brass swell, about 1.5 s.",
		maxInstances = 1,
		cooldown = 0.5,
	},
	{
		id = "reward.legendary",
		category = "ui",
		volume = 0.8,
		status = "needed",
		source = STORE .. "'legendary reveal' / 'royal fanfare'",
		licence = LICENCE.creatorStore,
		description = "Unique, story-worthy reveal, 2-3 s; never reused for anything else.",
		maxInstances = 1,
		cooldown = 1,
	},
	-- Celebrations and onboarding
	{
		id = "celebrate.levelup",
		category = "ui",
		volume = 0.7,
		status = "needed",
		source = STORE .. "'level up medieval' / 'harp gliss'",
		licence = LICENCE.creatorStore,
		description = "Upward harp/brass gesture, 1-2 s.",
		maxInstances = 1,
		cooldown = 1,
	},
	{
		id = "celebrate.streak",
		category = "ui",
		volume = 0.65,
		status = "needed",
		source = STORE .. "'bell sequence' / 'chime cascade'",
		licence = LICENCE.creatorStore,
		description = "Daily streak: short ascending bell run; pitch can rise with streak length.",
		maxInstances = 1,
		cooldown = 1,
	},
	{
		id = "onboarding.step",
		category = "ui",
		volume = 0.5,
		status = "needed",
		source = STORE .. "'soft success chime'",
		licence = LICENCE.creatorStore,
		description = "Tutorial step done: warm, quiet two-note chime (heard once per tutorial step, several times in the first minutes).",
		maxInstances = 1,
		cooldown = 0.3,
	},
	{
		id = "onboarding.complete",
		category = "ui",
		volume = 0.65,
		status = "needed",
		source = STORE .. "'quest complete medieval'",
		licence = LICENCE.creatorStore,
		description = "Tutorial finished: a bigger version of onboarding.step with a short flourish.",
		maxInstances = 1,
		cooldown = 1,
	},
}

local Sounds = {}

Sounds.LICENCE = LICENCE
Sounds.FACTORY = table.freeze(FACTORY)
Sounds.registry = SoundRegistry.build(FACTORY, ConfigSounds)

return table.freeze(Sounds)
