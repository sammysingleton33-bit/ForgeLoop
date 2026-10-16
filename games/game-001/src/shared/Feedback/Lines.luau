--!strict
--[[
	Feedback/Lines (game-001, FORGE-04, FL-0062): announcer text and presentation per moment kind.
	Titles are one line (≤ 60 characters, the toast limit); {field} placeholders come from the moment
	(Feedback/Moments). Citizen dialogue is not here: it lives in FORGE-00's content library (D-030);
	these are system announcements only.

	MOMENT[kind] = { kind (toast kind), title, body?, key? (coalescing), sound?, vfx?, celebrate? }
	   A moment with its own sound gets a silent toast (AnnouncerController), so nothing plays twice.
	   `celebrate` names a NotificationController celebration registered from CELEBRATIONS.
	   draw / watched (matchEnded without a win or a loss) toast only on a client without the slice
	   summary, which shows the result line itself (AnnouncerController.SUMMARY_OWNS).
	PHASE[phase] = { kind, title, body?, sound? }   -- MatchPhaseChanged announcements
	CONSEQUENCE[rule][start | stop] = { kind, title, plain?, body?, key, sound? }   -- G9 ConsequenceChanged
	   (FL-0091): a title or body whose {field} the moment lacks is not shown; `plain` is the title then.
	   {jobs} is JOBS[occupation] ("workers" without one), {place} the building's name in lower case.
	JOBS[occupation] = plural ("farmers"), CONTRACTS G2 JobIds
	CELEBRATIONS[kind] = NotificationController:registerCelebration spec (FL-0027)
	BUILDING[type] = display name (CONTRACTS G2 BuildingType)
]]

local Lines = {}

Lines.BUILDING = table.freeze({
	keep = "Keep",
	house = "House",
	farm = "Farm",
	storehouse = "Storehouse",
	lumbercamp = "Lumber camp",
	quarry = "Quarry",
	barracks = "Barracks",
	watchtower = "Watchtower",
	wall = "Wall",
	gate = "Gate",
	mine = "Mine",
	blacksmith = "Blacksmith",
	market = "Market",
	infirmary = "Infirmary",
	granary = "Granary",
	shrine = "Shrine",
})

Lines.MOMENT = table.freeze({
	kingdomFounded = table.freeze({ celebrate = "kingdomFounded" }),
	memberJoined = table.freeze({ kind = "info", title = "{actor} joined your kingdom", key = "joined:{actor}" }),
	buildingPlaced = table.freeze({
		kind = "success",
		title = "{building} placed",
		body = "Builders are on their way.",
		key = "placed:{buildingType}",
		sound = "kingdom.build.place",
		vfx = "kingdom.construction.place",
	}),
	buildingCompleted = table.freeze({
		kind = "success",
		title = "{building} complete",
		key = "built:{buildingType}",
		sound = "kingdom.build.complete",
		vfx = "kingdom.construction.complete",
	}),
	keepUpgraded = table.freeze({ celebrate = "keepUpgraded" }),
	buildingUpgraded = table.freeze({
		kind = "success",
		title = "{building} reached level {level}",
		key = "upgraded:{buildingType}",
		sound = "kingdom.build.complete",
		vfx = "levelup.column",
	}),
	rivalKeepUpgraded = table.freeze({
		kind = "info",
		title = "{kingdomName}'s keep reached level {level}",
		key = "rivalKeep:{kingdom}",
	}),
	buildingDestroyed = table.freeze({
		kind = "warning",
		title = "{building} destroyed",
		key = "destroyed:{buildingType}",
	}),
	unitsRecruited = table.freeze({
		kind = "success",
		title = "+{count} soldiers",
		body = "{actor} recruited at the Barracks.",
		key = "recruited",
		sound = "kingdom.recruit",
		vfx = "kingdom.army.recruit",
	}),
	objectiveCaptured = table.freeze({ celebrate = "objectiveCaptured" }),
	rivalCaptured = table.freeze({
		kind = "warning",
		title = "{kingdomName} took a watchtower",
		key = "rivalCaptured:{objectiveId}",
		sound = "kingdom.capture.lost",
	}),
	victory = table.freeze({ celebrate = "victory" }),
	defeat = table.freeze({ celebrate = "defeat" }),
	draw = table.freeze({ kind = "info", title = "A draw", body = "No kingdom took the crown.", key = "matchEnded" }),
	watched = table.freeze({ kind = "info", title = "{kingdomName} wins the match", key = "matchEnded" }),
})

Lines.PHASE = table.freeze({
	Expansion = table.freeze({
		kind = "info",
		title = "The realm grows",
		body = "New lands and buildings are within reach.",
	}),
	Conflict = table.freeze({
		kind = "warning",
		title = "War is declared",
		body = "Rival kingdoms may now attack your lands.",
		sound = "kingdom.horn.war",
	}),
	Endgame = table.freeze({ kind = "warning", title = "The final hours", body = "Hold your towers to the end." }),
	Results = table.freeze({ kind = "info", title = "The match is over" }),
})

-- The kingdom's consequences (FORGE-01's ConsequenceService, G9 ConsequenceChanged v0.4-g10c), to that
-- kingdom's rulers: one notice per start and per end. A rebellion has only a start (VS-2; off in VS-1).
Lines.JOBS = table.freeze({
	farmer = "farmers",
	woodcutter = "woodcutters",
	miner = "miners",
	builder = "builders",
	hauler = "haulers",
})
Lines.CONSEQUENCE = table.freeze({
	strike = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "The {jobs} are on strike",
			body = "{count} stopped work over a grievance. Win back their loyalty.",
			key = "consequence:strike:{jobs}",
		}),
		stop = table.freeze({
			kind = "success",
			title = "The {jobs} are back at work",
			key = "consequence:strike:{jobs}",
		}),
	}),
	shortage = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "Food is running out",
			body = "Your people go hungry. Put more of them on the farms.",
			key = "consequence:shortage",
		}),
		stop = table.freeze({ kind = "success", title = "Your people have food again", key = "consequence:shortage" }),
	}),
	riot = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "Riot at the {place}!",
			plain = "A riot breaks out!",
			body = "{count} rioters set it alight. Nobody works there while it burns.",
			key = "consequence:riot",
			sound = "kingdom.horn.war",
		}),
		stop = table.freeze({
			kind = "success",
			title = "The riot is over",
			body = "The {place} slowly mends.",
			key = "consequence:riot",
		}),
	}),
	rebellion = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "Your people rise in rebellion!",
			body = "Win back their loyalty before it spreads.",
			key = "consequence:rebellion",
			sound = "kingdom.horn.war",
		}),
	}),
})

Lines.CELEBRATIONS = table.freeze({
	kingdomFounded = table.freeze({
		sound = "kingdom.founded",
		vfx = "reward.burst",
		toast = table.freeze({
			kind = "achievement",
			title = "{kingdomName} is yours",
			body = "Your citizens are already at work.",
		}),
	}),
	keepUpgraded = table.freeze({
		sound = "kingdom.keep.upgrade",
		vfx = "levelup.column",
		toast = table.freeze({ kind = "achievement", title = "Keep level {level}", body = "Your citizens cheer." }),
	}),
	objectiveCaptured = table.freeze({
		sound = "kingdom.capture",
		vfx = "kingdom.territory.claim",
		toast = table.freeze({
			kind = "achievement",
			title = "Watchtower captured",
			body = "Its region now flies your banner.",
		}),
	}),
	victory = table.freeze({
		vfx = "reward.burst",
		toast = table.freeze({ kind = "achievement", title = "Victory!", body = "{kingdomName} rules the valley." }),
	}),
	defeat = table.freeze({
		toast = table.freeze({ kind = "info", title = "Defeat", body = "{kingdomName} won this time." }),
	}),
})

return table.freeze(Lines)
