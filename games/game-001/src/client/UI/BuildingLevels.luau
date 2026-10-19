--!strict
--[[
	UI/BuildingLevels — what each level of a building gives, as one short line per level for the
	plot picker and the upgrade panel ("Now: Recruit up to 5 soldiers", "Lv 2: Recruit up to 10").

	A DISPLAY COPY of the D-030 catalogue (design/living-kingdom.md §4), PROVISIONAL like it. The
	gameplay numbers belong to FORGE-01 (config `Buildings.luau`); when that config carries per-level
	stats or a `benefits` text, this module reads it instead (handoff:
	production/handoffs/2026-10-12-forge-03-to-forge-01-plots-ui.md).

		BuildingLevels.benefit(type, level) -> string?
]]

local LINES: { [string]: { string } } = {
	keep = {
		"The seat of your rule",
		"More storage and people · unlocks level 2 buildings",
		"Even more storage and people · unlocks level 3 buildings",
	},
	house = { "Homes 4 citizens", "Homes 8 citizens" },
	farm = { "Grows food", "Food +50 %", "Food +100 %" },
	lumbercamp = { "Woodcutters fell trees nearby", "More wood", "Even more wood" },
	quarry = { "Miners cut stone nearby", "More stone", "Even more stone" },
	storehouse = { "Drop-off point for haulers" },
	barracks = {
		"Recruit up to 5 soldiers",
		"Recruit up to 10 · faster training",
		"Recruit up to 15 · faster training",
		"Recruit up to 20 · veterans (+ morale)",
	},
	watchtower = { "Vision over your land", "Archers" },
	wall = { "Defence", "Stronger defence", "Strongest defence" },
	gate = { "Closes the gap in your walls", "Stronger gate", "Strongest gate" },
}

local BuildingLevels = {}

function BuildingLevels.benefit(buildingType: string, level: number): string?
	local lines = LINES[buildingType]
	return if lines then lines[level] else nil
end

return table.freeze(BuildingLevels)
