--!strict
--[[
	AI Kingdoms (game-001) sounds — owner FORGE-04. Added to the factory registry
	(roblox/src/shared/Experience/Sounds.luau); fields and rules: Experience/SoundRegistry.luau.
	BRIEF §11: chopping, mining, building hammer, coin and resource pickups, construction complete
	fanfare, horn for raids, capture sting, ambience (birds, river, wind), simple medieval music loops.
	Which signal plays which sound: games/game-001/src/shared/Feedback/Cues.luau (FL-0062).
	The selection/upload list for the user: production/handoffs/2026-10-12-forge-04-to-user-sounds.md.

	All entries are "needed": no asset has been chosen or heard yet. Positional sounds (rollOff) play
	at the event, so a player hears their own kingdom clearly and a rival's faintly.
]]

local STORE = "Creator Store (Toolbox > Audio) search: "
local LICENCE =
	"Creator Store audio, free to use in experiences (audio/assets.md @af5f853); record asset id, title and creator in source when chosen, confirm it plays in our place (privacy.md)."

local near = { min = 8, max = 90 }
local far = { min = 20, max = 260 }

local function sound(fields: { [string]: any }): { [string]: any }
	fields.status = fields.status or "needed"
	fields.licence = fields.licence or LICENCE
	return fields
end

return {
	-- Music (one track at a time; Experience/MusicDirector states, crossfaded by AudioController)
	sound({
		id = "music.calm",
		category = "music",
		volume = 0.5,
		loop = true,
		source = STORE .. "'medieval village peaceful' (lute, recorder, 2-4 min loop)",
		description = "Founding: warm, unhurried folk; no percussion.",
	}),
	sound({
		id = "music.build",
		category = "music",
		volume = 0.5,
		loop = true,
		source = STORE .. "'medieval town busy' / 'celtic folk upbeat'",
		description = "Expansion: busier rhythm, light percussion; sounds like growth.",
	}),
	sound({
		id = "music.tension",
		category = "music",
		volume = 0.5,
		loop = true,
		source = STORE .. "'medieval tension' / 'war drums distant'",
		description = "Conflict and Endgame when not fighting: low strings, distant drums.",
	}),
	sound({
		id = "music.battle",
		category = "music",
		volume = 0.55,
		loop = true,
		source = STORE .. "'medieval battle epic' / 'war drums'",
		description = "While our soldiers fight or our lands are attacked: driving drums and brass.",
	}),
	sound({
		id = "music.victory",
		category = "music",
		volume = 0.6,
		loop = true,
		source = STORE .. "'victory fanfare medieval' (with a calm loopable tail)",
		description = "Our kingdom won (or captured the slice objective): fanfare settling into a loop.",
	}),
	sound({
		id = "music.defeat",
		category = "music",
		volume = 0.5,
		loop = true,
		source = STORE .. "'medieval sad' / 'lament'",
		description = "Match lost: dignified lament, not punishing.",
	}),
	-- Ambience beds (loop; at most 2 at once)
	sound({
		id = "ambience.birds",
		category = "ambience",
		volume = 0.4,
		loop = true,
		source = STORE .. "'forest birds daytime' / 'countryside birds'",
		description = "The valley by day; under everything.",
	}),
	sound({
		id = "ambience.river",
		category = "ambience",
		volume = 0.35,
		loop = true,
		source = STORE .. "'river stream gentle'",
		description = "Played near the river (positional bed placed by FeedbackController).",
		rollOff = far,
	}),
	sound({
		id = "ambience.wind",
		category = "ambience",
		volume = 0.3,
		loop = true,
		source = STORE .. "'wind fields' / 'countryside wind'",
		description = "Open ground and the overview camera.",
	}),
	-- Work (citizens and the ruler)
	sound({
		id = "kingdom.chop",
		category = "sfx",
		volume = 0.45,
		source = STORE .. "'axe chop wood'",
		description = "Axe into wood, single hit; plays on a woodcutter's swing near the camera and on ruler gathering.",
		rollOff = near,
		maxInstances = 3,
		cooldown = 0.25,
		pitchVariance = 0.1,
	}),
	sound({
		id = "kingdom.mine",
		category = "sfx",
		volume = 0.45,
		source = STORE .. "'pickaxe stone'",
		description = "Pickaxe on stone, single hit.",
		rollOff = near,
		maxInstances = 3,
		cooldown = 0.25,
		pitchVariance = 0.1,
	}),
	sound({
		id = "kingdom.harvest",
		category = "sfx",
		volume = 0.45,
		source = STORE .. "'scythe' / 'wheat harvest'",
		description = "Wheat cut and gathered (farmers).",
		rollOff = near,
		maxInstances = 2,
		cooldown = 0.4,
		pitchVariance = 0.08,
	}),
	sound({
		id = "kingdom.hammer",
		category = "sfx",
		volume = 0.4,
		source = STORE .. "'hammer nails wood construction'",
		description = "Construction in progress: short hammering bursts while builders work.",
		rollOff = near,
		maxInstances = 3,
		cooldown = 0.8,
		pitchVariance = 0.1,
	}),
	sound({
		id = "kingdom.pickup",
		category = "sfx",
		volume = 0.55,
		source = STORE .. "'wood pickup' / 'item pickup soft'",
		description = "The ruler gathered a resource: quick satisfying pickup; pairs with the +N float.",
		maxInstances = 2,
		cooldown = 0.15,
		pitchVariance = 0.06,
	}),
	sound({
		id = "kingdom.deposit",
		category = "sfx",
		volume = 0.4,
		source = STORE .. "'coins clink' / 'crate drop'",
		description = "A citizen dropped goods at the storehouse: small clink; coalesced so many deposits do not chatter.",
		rollOff = near,
		maxInstances = 2,
		cooldown = 0.5,
		pitchVariance = 0.06,
	}),
	-- Construction and upgrades
	sound({
		id = "kingdom.build.place",
		category = "sfx",
		volume = 0.55,
		source = STORE .. "'wood plank drop' / 'place building'",
		description = "Building placed: solid wooden thunk; confirms the click landed.",
		rollOff = near,
		maxInstances = 2,
		cooldown = 0.2,
	}),
	sound({
		id = "kingdom.build.complete",
		category = "sfx",
		volume = 0.65,
		source = STORE .. "'construction complete' / 'medieval success'",
		description = "Building finished: bright wooden/brass flourish under 1.5 s.",
		rollOff = far,
		maxInstances = 2,
		cooldown = 0.5,
	}),
	sound({
		id = "kingdom.keep.upgrade",
		category = "sfx",
		volume = 0.75,
		priority = 3,
		source = STORE .. "'royal fanfare short' / 'trumpets'",
		description = "Keep reached a new level: full royal trumpets, 2-3 s; the biggest moment before a capture.",
		maxInstances = 1,
		cooldown = 2,
	}),
	sound({
		id = "kingdom.cheer",
		category = "voice",
		volume = 0.5,
		source = STORE .. "'crowd cheer small' / 'villagers cheer'",
		description = "A few citizens cheer (keep level 2, a capture).",
		rollOff = near,
		maxInstances = 1,
		cooldown = 2,
		pitchVariance = 0.05,
	}),
	-- Military and objectives
	sound({
		id = "kingdom.recruit",
		category = "sfx",
		volume = 0.6,
		source = STORE .. "'war horn short' / 'soldiers ready'",
		description = "Soldiers recruited: short horn plus armour rattle.",
		rollOff = far,
		maxInstances = 1,
		cooldown = 1,
	}),
	sound({
		id = "kingdom.capture",
		category = "sfx",
		volume = 0.75,
		priority = 3,
		source = STORE .. "'capture flag sting' / 'victory sting short'",
		description = "Objective captured by us: bright sting with bell; tower recolours at the same moment.",
		maxInstances = 1,
		cooldown = 2,
	}),
	sound({
		id = "kingdom.capture.lost",
		category = "sfx",
		volume = 0.6,
		source = STORE .. "'low horn' / 'defeat sting short'",
		description = "A rival captured an objective: short descending horn.",
		maxInstances = 1,
		cooldown = 2,
	}),
	sound({
		id = "kingdom.horn.war",
		category = "sfx",
		volume = 0.7,
		priority = 3,
		source = STORE .. "'war horn long' / 'battle horn'",
		description = "Conflict begins, or our lands are raided: long horn; always paired with a warning toast.",
		maxInstances = 1,
		cooldown = 8,
	}),
	sound({
		id = "kingdom.founded",
		category = "sfx",
		volume = 0.65,
		priority = 3,
		source = STORE .. "'kingdom horn' / 'coronation fanfare'",
		description = "We joined our kingdom: horn call that says 'this is yours'.",
		maxInstances = 1,
		cooldown = 5,
	}),
}
