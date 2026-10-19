--!strict
--[[
	The Crown Arena crowd (ReplicatedStorage.Forge.Config.Crowd). Owner FORGE-04 (FL-0074; design
	games/game-001/design/crown-arena.md §3 tier table and §7). DRAFT: G12 is a VS-2 draft and every
	number here is PROVISIONAL until Studio playtests. Read by Feedback/CrowdDirector (pure) and the
	client crowd controller; the server sends no crowd data (G12.6).

	figures: one figure per `citizensPerFigure` living citizens, at most `maxPerStand` per stand and
	  `maxTotal` in the arena (design §7: <= 60 per stand, <= 120 total).
	rationing: at most one major reaction every `majorGapSec` (both stands together); a minor one at
	  most every `minorGapSec` per stand. Perk moments and the ending always play (they win priority).
	duck: the crowd's volume drops to `volume` while the announcer speaks (`announcerSec` per line)
	  and while a perk stinger plays (`perkSec`).
	moments: `bigHit` = a hit taking at least this share of max HP is major; `nearDeath` = a
	  champion's HP share first falling below it; `comeback` = a champion who trailed by at least this
	  HP share takes the lead.
	highSupport: the tiers that count as high support for the four endings (§7); the others are low.
	tiers: what each stand does in that tier (design §3 table): `fill` = the share of its figures
	  in their seats (the rest have left or never came), `idle` between moments, `good` when its own
	  champion does well, `bad` when they do badly, `chants` = whether it chants on full hype.
	reactions: every reaction's sound (config/Sounds.luau; all "needed", silent until the owner picks
	  assets) and subtitle (accessibility, design §7: every crowd sound has text).
	chants: pre-written lines per kingdom style, never user text; {ruler} is the champion's Roblox
	  display name (platform-filtered). `any` is used for a kingdom without its own list. Boos and
	  turned backs are the strongest negative; no line insults anyone.
	endings: the four endings (§7): win or loss x high or low support; `calledOff` closes a duel
	  with no winner (Arena.Events `ended` with side "draw", cancelled or both champions dropped: no
	  crowd payoff, FORGE-00 2026-10-19).
	triggerNames: the perk names a `triggerFired` caption shows, by TriggerId (design §4 table; G12.1).
	intro: the intro's camera pass over the stands (CrowdStageController, design §7 "Intro"): each stand
	  shot at `standZoom` studs for `standSec`, then the ring at `ringZoom` for `ringSec`; the pass
	  shrinks to fit a shorter intro (Pacing.arena.intro at most), never below `minShotSec` a shot.
]]

return table.freeze({
	citizensPerFigure = 2,
	maxPerStand = 60,
	maxTotal = 120,
	majorGapSec = 3,
	minorGapSec = 0.75,
	duck = table.freeze({ volume = 0.35, announcerSec = 2.5, perkSec = 1.5 }),
	moments = table.freeze({ bigHit = 0.12, nearDeath = 0.2, comeback = 0.25 }),
	highSupport = table.freeze({ adoring = true, loyal = true }),
	tiers = table.freeze({
		adoring = table.freeze({ fill = 1, idle = "chant", good = "roar", bad = "gasp", chants = true }),
		loyal = table.freeze({ fill = 1, idle = "cheer", good = "cheer", bad = "gasp", chants = true }),
		divided = table.freeze({ fill = 0.9, idle = "murmur", good = "mixed", bad = "mutter", chants = false }),
		restless = table.freeze({ fill = 0.7, idle = "quiet", good = "scattered", bad = "boo", chants = false }),
		hostile = table.freeze({ fill = 0.5, idle = "boo", good = "silence", bad = "turnBack", chants = false }),
	}),
	reactions = table.freeze({
		roar = table.freeze({ sound = "crowd.roar", caption = "(The crowd roars)" }),
		cheer = table.freeze({ sound = "crowd.cheer", caption = "(The crowd cheers)" }),
		mixed = table.freeze({ sound = "crowd.mixed", caption = "(Half the stand cheers)" }),
		scattered = table.freeze({ sound = "crowd.scattered", caption = "(A few people clap)" }),
		silence = table.freeze({ sound = nil, caption = "(The stand stays silent)" }),
		gasp = table.freeze({ sound = "crowd.gasp", caption = "(The crowd gasps)" }),
		mutter = table.freeze({ sound = "crowd.mutter", caption = "(The stand mutters)" }),
		boo = table.freeze({ sound = "crowd.boo", caption = "(The crowd boos)" }),
		turnBack = table.freeze({ sound = "crowd.boo", caption = "(The stand turns its back)" }),
		murmur = table.freeze({ sound = "crowd.murmur", caption = "(The crowd murmurs)" }),
		quiet = table.freeze({ sound = nil, caption = "(The stand is quiet)" }),
		chant = table.freeze({ sound = "crowd.chant", caption = nil }), -- the chant line is the subtitle
		perk = table.freeze({ sound = "crowd.perk", caption = "{citizen} steps up: {trigger}!" }),
		rally = table.freeze({ sound = "crowd.rally", caption = "(The whole stand roars for its ruler)" }),
	}),
	chants = table.freeze({
		crimson = table.freeze({ "Crimson! Crimson!", "Burn bright, {ruler}!", "Fire in our hearts!" }),
		azure = table.freeze({ "Azure rises!", "Steady as the tide, {ruler}!", "Blue skies, blue banners!" }),
		emerald = table.freeze({ "Emerald stands!", "Strong as the oak, {ruler}!", "Roots deep, heads high!" }),
		gold = table.freeze({ "Gold! Gold! Gold!", "Shine, {ruler}!", "Our crown, our gold!" }),
		any = table.freeze({ "For the kingdom!", "{ruler}! {ruler}!" }),
	}),
	endings = table.freeze({
		flood = table.freeze({
			sound = "crowd.flood",
			caption = "(The stand floods the arena to crown its ruler)",
		}),
		thinCrowning = table.freeze({
			sound = "crowd.scattered",
			caption = "(A thin crowd watches the crowning)",
		}),
		salute = table.freeze({ sound = "crowd.salute", caption = "They fought for us! (The stand salutes)" }),
		empty = table.freeze({ sound = nil, caption = "(The stand empties)" }),
		calledOff = table.freeze({ sound = nil, caption = "(The duel was called off)" }),
	}),
	intro = table.freeze({ standZoom = 55, ringZoom = 80, standSec = 4, ringSec = 4, minShotSec = 1 }),
	triggerNames = table.freeze({
		reforge = "Reforge",
		fieldRemedy = "Field Remedy",
		calledWarning = "Called Warning",
		heartyRations = "Hearty Rations",
		rallyingHymn = "Rallying Hymn",
		fineWares = "Fine Wares",
		crowdRally = "Crowd Rally",
	}),
})
