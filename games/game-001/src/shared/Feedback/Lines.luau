--!strict
--[[
	Feedback/Lines (game-001, FORGE-04, FL-0062): announcer text and presentation per moment kind.
	Titles are one line (≤ 60 characters, the toast limit); {field} placeholders come from the moment
	(Feedback/Moments). Citizen dialogue is not here: it lives in FORGE-00's content library (D-030);
	these are system announcements only.

	MOMENT[kind] = { kind (toast kind), title, body?, bodyPlain?, key? (coalescing), sound?, vfx?, celebrate? }
	   A body whose {field} the moment lacks is not shown; `bodyPlain` is the body then (FL-0130).
	   A moment with its own sound gets a silent toast (AnnouncerController), so nothing plays twice.
	   `celebrate` names a NotificationController celebration registered from CELEBRATIONS.
	   draw / watched (matchEnded without a win or a loss) toast only on a client without the slice
	   summary, which shows the result line itself (AnnouncerController.SUMMARY_OWNS).
	PHASE[phase] = { kind, title, body?, timed?, sound? }   -- MatchPhaseChanged announcements; `timed`
	   replaces body when the phase has a length ({minutes}, from Pacing for the match's mode; FL-0130)
	CONSEQUENCE[rule][start | stop] = { kind, title, plain?, body?, key, sound? }   -- G9 ConsequenceChanged
	   (FL-0091): a title or body whose {field} the moment lacks is not shown; `plain` is the title then.
	   {jobs} is JOBS[occupation] ("workers" without one), {place} the building's name in lower case.
	JOBS[occupation] = plural ("farmers"), CONTRACTS G2 JobIds
	WAR[role][start | stop], SIEGE[start | stop], RAID[start | stop] (FL-0130, war feedback): the same
	   shape as CONSEQUENCE, plus `bodyPlain`, the body when the filled one would miss a field.
	   WAR roles: self (your kingdom declared, or accepted the peace), other (it was declared on you, or
	   your proposal was accepted), rival (two other kingdoms). {kingdomName} is the kingdom that acted,
	   {otherName} the other one; {byName} the attacking kingdom when there is exactly one.
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
	-- G9 KingdomEliminated (FL-0130): the fallen kingdom's rulers, the conqueror's, and everyone else
	kingdomFell = table.freeze({ celebrate = "fallen" }),
	kingdomConquered = table.freeze({ celebrate = "conquest" }),
	rivalFell = table.freeze({
		kind = "warning",
		title = "{kingdomName} has fallen",
		body = "{byName} took its keep.",
		bodyPlain = "Its keep was destroyed.",
		key = "fell:{kingdom}",
		sound = "kingdom.fallen",
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
		timed = "{minutes} minutes to grow before kingdoms may go to war.",
	}),
	Conflict = table.freeze({
		kind = "warning",
		title = "The age of war begins",
		body = "Kingdoms may now declare war on each other.",
		timed = "For {minutes} minutes, kingdoms may declare war on each other.",
		sound = "kingdom.horn.war",
	}),
	Endgame = table.freeze({
		kind = "warning",
		title = "The final hours",
		body = "Hold your towers to the end.",
		timed = "{minutes} minutes left. Every Crown Point counts.",
	}),
	Results = table.freeze({ kind = "info", title = "The match is over" }),
})

-- The kingdom's consequences (FORGE-01's ConsequenceService, G9 ConsequenceChanged v0.4-g10c), to that
-- kingdom's rulers: one notice per start and per end. A rebellion has only a start (VS-2; off in VS-1).
-- A start and its end have different keys: the queue coalesces a repeated key into the shown toast and keeps
-- its title (NotificationQueue), so an end sharing the start's key would read "<start> ×2".
-- bodyOne, when present, replaces body for a count of 1.
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
			key = "consequence:strike:{jobs}:on",
		}),
		stop = table.freeze({
			kind = "success",
			title = "The {jobs} are back at work",
			key = "consequence:strike:{jobs}:off",
		}),
	}),
	shortage = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "Food is running out",
			body = "Your people go hungry. Put more of them on the farms.",
			key = "consequence:shortage:on",
		}),
		stop = table.freeze({
			kind = "success",
			title = "Your people have food again",
			key = "consequence:shortage:off",
		}),
	}),
	riot = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "Riot at the {place}!",
			plain = "A riot breaks out!",
			body = "{count} rioters set it alight. Nobody works there while it burns.",
			bodyOne = "A rioter set it alight. Nobody works there while it burns.", -- count 1: the instigator alone
			key = "consequence:riot:on",
			sound = "kingdom.horn.war",
		}),
		stop = table.freeze({
			kind = "success",
			title = "The riot is over",
			body = "The {place} slowly mends.",
			key = "consequence:riot:off",
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

-- War and peace (G9 WarChanged, proposed in FL-0130's handoff): one notice per declaration and per peace,
-- in the words of each side; start and end keys differ (see CONSEQUENCE).
Lines.WAR = table.freeze({
	self = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "You declared war on {otherName}",
			body = "Your soldiers may now attack its lands.",
			key = "war:{other}:on",
			sound = "kingdom.horn.war",
		}),
		stop = table.freeze({ kind = "success", title = "Peace with {otherName}", key = "war:{other}:off" }),
	}),
	other = table.freeze({
		start = table.freeze({
			kind = "warning",
			title = "{kingdomName} declares war on you!",
			body = "Its soldiers may now attack your lands.",
			key = "war:{kingdom}:on",
			sound = "kingdom.horn.war",
		}),
		stop = table.freeze({ kind = "success", title = "Peace with {kingdomName}", key = "war:{kingdom}:off" }),
	}),
	rival = table.freeze({
		start = table.freeze({
			kind = "info",
			title = "{kingdomName} declares war on {otherName}",
			key = "war:{kingdom}:{other}:on",
		}),
		stop = table.freeze({
			kind = "info",
			title = "{kingdomName} and {otherName} make peace",
			key = "war:{kingdom}:{other}:off",
		}),
	}),
})

-- Your keep under attack (G9 SiegeChanged, proposed in FL-0130's handoff), to that kingdom's rulers.
Lines.SIEGE = table.freeze({
	start = table.freeze({
		kind = "warning",
		title = "Your keep is under siege!",
		body = "{byName} soldiers attack your keep.",
		bodyPlain = "Enemy soldiers attack your keep.",
		key = "siege:on",
		sound = "kingdom.horn.war",
	}),
	stop = table.freeze({ kind = "success", title = "The siege is lifted", key = "siege:off" }),
})

-- Enemies inside your territory (G9 RaidChanged, proposed in FL-0130's handoff), to that kingdom's rulers.
-- The moment carries the raid's position, for the camera ping.
Lines.RAID = table.freeze({
	start = table.freeze({
		kind = "warning",
		title = "Enemies in your lands!",
		body = "{count} {byName} soldiers crossed your border.",
		bodyOne = "A {byName} soldier crossed your border.",
		bodyPlain = "Enemy soldiers crossed your border.",
		key = "raid:on",
		sound = "kingdom.alarm",
	}),
	stop = table.freeze({ kind = "success", title = "Your lands are clear", key = "raid:off" }),
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
	-- G9 KingdomEliminated (FL-0130)
	fallen = table.freeze({
		sound = "kingdom.fallen",
		toast = table.freeze({
			kind = "info",
			title = "Your keep has fallen",
			body = "You can watch the rest of the match.",
		}),
	}),
	conquest = table.freeze({
		sound = "kingdom.capture",
		vfx = "reward.burst",
		toast = table.freeze({
			kind = "achievement",
			title = "You conquered {otherName}!",
			body = "Half its treasury is yours.",
		}),
	}),
})

return table.freeze(Lines)
