--!strict
--[[
	Experience/SoundRegistry — validation and lookup for sound entries (Experience/Sounds.luau holds
	the factory entries and merges each game's games/<game>/config/Sounds.luau).

	Entry (one per logical sound; code plays sounds only by `id`):
		id: string             "<area>.<name>" lowercase, e.g. "kingdom.build.complete"
		category: Category     "music" | "ambience" | "sfx" | "ui" | "voice"
		volume: number         default volume, 0 < volume <= 1 (multiplied by master x category setting)
		licence: string        licence / permission note (who may use it and why)
		source: string         where it comes from (Creator Store asset + creator, commission, original upload)
		description: string    what it should sound like (the brief for choosing or recording it)
		status: Status         "needed" (no asset chosen) | "candidate" (asset chosen, not yet heard in Studio) | "ready"
		asset: string?         "rbxassetid://<n>" (required unless status = "needed")
		loop: boolean?         music and ambience beds loop
		priority: number?      1 (low) .. 3 (high): who keeps a voice when the budget is full (default 2)
		maxInstances: number?  concurrent plays of this id (default 2)
		cooldown: number?      minimum seconds between plays of this id (default 0.05)
		pitchVariance: number? random +/- playback speed, 0..0.2 (variety for repeated sounds)
		rollOff: { min: number, max: number }?   studs, for positional sounds (Sound.RollOffMin/MaxDistance)

	A play request for a "needed" entry is skipped and counted (the game runs before assets exist).
	Every entry must declare a licence and a source; the registry rejects entries without them.

	API
		SoundRegistry.CATEGORIES, SoundRegistry.STATUSES
		SoundRegistry.validate(entries) -> { string }              -- problems (empty = valid)
		SoundRegistry.build(...lists) -> Registry                  -- later lists override earlier ids; errors if invalid
		registry:get(id) -> Entry?    registry.entries: { [id]: Entry }    registry:ids() -> { string }
		registry:needed() -> { Entry }                             -- entries still without an asset
]]

local SoundRegistry = {}

SoundRegistry.CATEGORIES = table.freeze({ "music", "ambience", "sfx", "ui", "voice" })
SoundRegistry.STATUSES = table.freeze({ "needed", "candidate", "ready" })

local ID_PATTERN = "^[a-z][a-z0-9_]*%.[a-z0-9_%.]+$"
local ASSET_PATTERN = "^rbxassetid://%d+$"

local function nonEmpty(value: any): boolean
	return type(value) == "string" and string.match(value, "%S") ~= nil
end

local function checkEntry(entry: any, where: string, problems: { string })
	if type(entry) ~= "table" then
		table.insert(problems, `{where}: must be a table`)
		return
	end
	local id = entry.id
	if type(id) ~= "string" or not string.match(id, ID_PATTERN) then
		table.insert(problems, `{where}: id must look like "area.name" (lowercase)`)
	end
	if not table.find(SoundRegistry.CATEGORIES, entry.category) then
		table.insert(problems, `{where}: category must be one of {table.concat(SoundRegistry.CATEGORIES, ", ")}`)
	end
	if type(entry.volume) ~= "number" or entry.volume <= 0 or entry.volume > 1 then
		table.insert(problems, `{where}: volume must be a number in (0, 1]`)
	end
	if not nonEmpty(entry.licence) then
		table.insert(problems, `{where}: licence note required`)
	end
	if not nonEmpty(entry.source) then
		table.insert(problems, `{where}: source note required`)
	end
	if not nonEmpty(entry.description) then
		table.insert(problems, `{where}: description required`)
	end
	if not table.find(SoundRegistry.STATUSES, entry.status) then
		table.insert(problems, `{where}: status must be needed | candidate | ready`)
	end
	if entry.asset ~= nil and (type(entry.asset) ~= "string" or not string.match(entry.asset, ASSET_PATTERN)) then
		table.insert(problems, `{where}: asset must be "rbxassetid://<number>"`)
	end
	if entry.status ~= "needed" and entry.asset == nil then
		table.insert(problems, `{where}: status '{tostring(entry.status)}' needs an asset`)
	end
	if entry.status == "needed" and entry.asset ~= nil then
		table.insert(problems, `{where}: has an asset, so status cannot be 'needed'`)
	end
	if entry.priority ~= nil and (type(entry.priority) ~= "number" or entry.priority < 1 or entry.priority > 3) then
		table.insert(problems, `{where}: priority must be 1..3`)
	end
	if
		entry.maxInstances ~= nil
		and (type(entry.maxInstances) ~= "number" or entry.maxInstances < 1 or entry.maxInstances % 1 ~= 0)
	then
		table.insert(problems, `{where}: maxInstances must be a positive integer`)
	end
	if entry.cooldown ~= nil and (type(entry.cooldown) ~= "number" or entry.cooldown < 0) then
		table.insert(problems, `{where}: cooldown must be >= 0`)
	end
	if
		entry.pitchVariance ~= nil
		and (type(entry.pitchVariance) ~= "number" or entry.pitchVariance < 0 or entry.pitchVariance > 0.2)
	then
		table.insert(problems, `{where}: pitchVariance must be 0..0.2`)
	end
	if entry.rollOff ~= nil then
		local r = entry.rollOff
		if type(r) ~= "table" or type(r.min) ~= "number" or type(r.max) ~= "number" or r.min <= 0 or r.max <= r.min then
			table.insert(problems, `{where}: rollOff needs min > 0 and max > min`)
		end
	end
	if (entry.category == "music" or entry.category == "ambience") and entry.loop ~= true then
		table.insert(problems, `{where}: {entry.category} entries loop (loop = true)`)
	end
end

function SoundRegistry.validate(entries: { any }): { string }
	local problems: { string } = {}
	if type(entries) ~= "table" then
		return { "entries must be a list" }
	end
	local seen = {}
	for i, entry in entries do
		local where = `sound[{i}] ({tostring(type(entry) == "table" and entry.id or "?")})`
		checkEntry(entry, where, problems)
		if type(entry) == "table" and type(entry.id) == "string" then
			if seen[entry.id] then
				table.insert(problems, `{where}: duplicate id in one list`)
			end
			seen[entry.id] = true
		end
	end
	return problems
end

local Registry = {}
Registry.__index = Registry

function Registry:get(id: string): any
	return self.entries[id]
end

function Registry:ids(): { string }
	local ids = {}
	for id in self.entries do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function Registry:needed(): { any }
	local out = {}
	for _, id in self:ids() do
		local entry = self.entries[id]
		if entry.status == "needed" then
			table.insert(out, entry)
		end
	end
	return out
end

function SoundRegistry.build(...: { any }): any
	local entries = {}
	local lists = table.pack(...)
	for index = 1, lists.n do
		local list = lists[index]
		local problems = SoundRegistry.validate(list)
		if #problems > 0 then
			error(`SoundRegistry: list {index} invalid: {table.concat(problems, "; ")}`, 2)
		end
		for _, entry in list do
			entries[entry.id] = table.freeze(table.clone(entry))
		end
	end
	return setmetatable({ entries = entries }, Registry)
end

return table.freeze(SoundRegistry)
