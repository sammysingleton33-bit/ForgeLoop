--[[
	Wire — value checks and copies used by mocks that cross a boundary (DataStores, remotes).

	DataStore rules imitate creator-docs content/en-us/cloud-services/data-stores/error-codes-and-limits.md
	(values are stored as JSON; 103 ValueNotAllowed / 104 CantStoreValue / 105 ValueTooLarge with a
	4,194,304-character limit measured with JSONEncode) and GlobalDataStore.yaml (strings must be
	valid UTF-8). Error codes are from the docs; message wording is approximate.

	Remote rules imitate content/en-us/scripting/events/remote.md#argument-limitations
	(non-string keys of dictionaries become strings, functions arrive as nil, tables are copies,
	metatables are dropped, Instances keep their identity).

	API
		Wire.checkStorable(value) -> (ok: boolean, err: string?)
		Wire.encodeForDataStore(value) -> json (errors with "10x: ..." when not storable)
		Wire.decodeFromDataStore(json) -> value (a fresh copy)
		Wire.copyForRemote(value) -> value
		Wire.estimateBytes(values: { any }) -> number   -- rough payload size (JSON length)
]]

local serde = require("@lune/serde")

local Wire = {}

Wire.MAX_VALUE_CHARS = 4194304

local function isArray(t): boolean
	local count = 0
	for _ in t do
		count += 1
	end
	for i = 1, count do
		if t[i] == nil then
			return false
		end
	end
	return true
end

local function check(value: any, path: string, seen: { [any]: boolean }): (boolean, string?)
	local kind = typeof(value)
	if kind == "nil" or kind == "boolean" then
		return true, nil
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, `104: Cannot store non-finite number (at {path}) in data store`
		end
		return true, nil
	elseif kind == "string" then
		if utf8.len(value) == nil then
			return false,
				`104: Cannot store string (at {path}) in data store. Data stores can only accept valid UTF-8 characters.`
		end
		return true, nil
	elseif kind == "table" then
		if seen[value] then
			return false, `104: Cannot store a table that contains itself (at {path}) in data store`
		end
		if getmetatable(value) ~= nil then
			return false, `103: Cannot store table with a metatable (at {path}) in data store`
		end
		seen[value] = true
		local array = isArray(value)
		for k, v in value do
			if not array and type(k) ~= "string" then
				seen[value] = nil
				return false, `104: Cannot store mixed or non-string-keyed table (at {path}) in data store`
			end
			local ok, err = check(v, path .. "." .. tostring(k), seen)
			if not ok then
				seen[value] = nil
				return false, err
			end
		end
		seen[value] = nil
		return true, nil
	end
	return false, `104: Cannot store {kind} (at {path}) in data store`
end

function Wire.checkStorable(value: any): (boolean, string?)
	return check(value, "value", {})
end

function Wire.encodeForDataStore(value: any): string
	local ok, err = Wire.checkStorable(value)
	if not ok then
		error(err, 0)
	end
	local json = serde.encode("json", { v = value })
	if #json - 6 > Wire.MAX_VALUE_CHARS then
		error(`105: Serialized value exceeds 4MB limit ({#json - 6} > {Wire.MAX_VALUE_CHARS} characters).`, 0)
	end
	return json
end

function Wire.decodeFromDataStore(json: string): any
	return serde.decode("json", json).v
end

local function copyRemote(value: any, seen: { [any]: any }): any
	local kind = typeof(value)
	if kind == "function" or kind == "thread" then
		return nil
	elseif kind ~= "table" then
		return value -- primitives, Instances, datatypes and EnumItems keep identity/value
	end
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	local array = isArray(value)
	for k, v in value do
		local key = if array or type(k) == "string" then k else tostring(k)
		out[key] = copyRemote(v, seen)
	end
	return out
end

function Wire.copyForRemote(value: any): any
	return copyRemote(value, {})
end

function Wire.estimateBytes(values: { any }): number
	local total = 0
	for _, value in values do
		local ok, json = pcall(serde.encode, "json", { v = Wire.copyForRemote(value) })
		total += if ok then #json - 6 else #tostring(value)
	end
	return total
end

return Wire
