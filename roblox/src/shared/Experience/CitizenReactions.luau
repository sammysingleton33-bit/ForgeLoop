--!strict
--[[
	Experience/CitizenReactions — how nearby citizens visibly react to what happens in their kingdom
	(barks in a speech bubble + an emote id for FORGE-01's citizen animation). Pure: the caller passes
	the candidate citizens, a Random and the clock.

	Citizens are found by the CollectionService tag "Citizen" with attributes KingdomId and CitizenId
	(proposed to FORGE-01); VFXController draws the bubble. The emote names are a request to FORGE-01
	/ FORGE-02 (animations); a citizen without that animation still shows the bubble.

		CitizenReactions.REACTIONS[id] = { lines, emote, radius, maxCitizens, chance, durationSec }
		local memory = CitizenReactions.newMemory()
		CitizenReactions.pick(id, citizens, position, kingdomId, rng, now, memory) -> { Bark }
			citizens: { { id: string, position: Vector3, kingdomId: string } }
			Bark = { citizenId, line, emote, durationSec }
	Rules: only citizens of `kingdomId` within `radius` of `position` (all of the kingdom's citizens
	when position is nil, nearest first); at most maxCitizens; each citizen at most once per
	CITIZEN_COOLDOWN seconds; a line is not repeated twice in a row per reaction.
]]

local CitizenReactions = {}

CitizenReactions.CITIZEN_COOLDOWN = 8

CitizenReactions.REACTIONS = table.freeze({
	cheer = table.freeze({
		lines = table.freeze({ "Huzzah!", "Long live the crown!", "A fine day!", "Well built!", "Hooray!" }),
		emote = "cheer",
		radius = 45,
		maxCitizens = 3,
		chance = 0.75,
		durationSec = 2.5,
	}),
	work = table.freeze({
		lines = table.freeze({ "To work!", "Right away!", "Fetch the hammers!", "On it!" }),
		emote = "work",
		radius = 35,
		maxCitizens = 2,
		chance = 0.6,
		durationSec = 2,
	}),
	acknowledge = table.freeze({
		lines = table.freeze({ "Aye!", "As you command.", "Yes, my liege.", "Consider it done." }),
		emote = "nod",
		radius = 60,
		maxCitizens = 1,
		chance = 1,
		durationSec = 1.8,
	}),
	grumble = table.freeze({
		lines = table.freeze({ "My belly's empty...", "Times are hard.", "Is anyone listening?", "Not again..." }),
		emote = "slump",
		radius = 50,
		maxCitizens = 2,
		chance = 0.6,
		durationSec = 2.5,
	}),
	panic = table.freeze({
		lines = table.freeze({ "Raiders!", "To the keep!", "Run!", "Protect the town!" }),
		emote = "flee",
		radius = 70,
		maxCitizens = 4,
		chance = 0.8,
		durationSec = 2,
	}),
})

export type Citizen = { id: string, position: any, kingdomId: string }
export type Bark = { citizenId: string, line: string, emote: string, durationSec: number }

function CitizenReactions.newMemory(): { [string]: any }
	return { citizens = {}, lastLine = {} }
end

function CitizenReactions.pick(
	reactionId: string,
	citizens: { Citizen },
	position: any,
	kingdomId: string?,
	rng: any,
	now: number,
	memory: { [string]: any }
): { Bark }
	local reaction = CitizenReactions.REACTIONS[reactionId]
	if reaction == nil or kingdomId == nil then
		return {}
	end
	local candidates = {}
	for _, citizen in citizens do
		if citizen.kingdomId == kingdomId then
			local last = memory.citizens[citizen.id]
			if last == nil or now - last >= CitizenReactions.CITIZEN_COOLDOWN then
				local distance = if position ~= nil and citizen.position ~= nil
					then (citizen.position - position).Magnitude
					else 0
				if position == nil or distance <= reaction.radius then
					table.insert(candidates, { citizen = citizen, distance = distance })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.distance == b.distance then
			return a.citizen.id < b.citizen.id
		end
		return a.distance < b.distance
	end)
	local barks: { Bark } = {}
	for _, candidate in candidates do
		if #barks >= reaction.maxCitizens then
			break
		end
		if reaction.chance >= 1 or rng:NextNumber() < reaction.chance then
			local lines = reaction.lines
			local index = rng:NextInteger(1, #lines)
			local previous = memory.lastLine[reactionId]
			if #lines > 1 and index == previous then
				index = index % #lines + 1
			end
			memory.lastLine[reactionId] = index
			memory.citizens[candidate.citizen.id] = now
			table.insert(barks, {
				citizenId = candidate.citizen.id,
				line = lines[index],
				emote = reaction.emote,
				durationSec = reaction.durationSec,
			})
		end
	end
	return barks
end

return table.freeze(CitizenReactions)
