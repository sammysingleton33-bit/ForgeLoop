--!strict
--[[
	Validate — argument validators for remotes and other untrusted input (interfaces §6).

	API (each constructor returns a Validator: (value: any) -> (ok: boolean, reason: string?))
		Validate.string(min, max)       string whose byte length (#s) is in [min, max] and that is
		                                valid UTF-8 (utf8.len); length is checked first
		Validate.integer(min, max)      number with no fractional part in [min, max] (finite)
		Validate.number(min, max)       finite number in [min, max] (rejects NaN, math.huge, -math.huge)
		Validate.boolean()              true or false
		Validate.enum({ ... })          one of the listed values (compared with ==, e.g. strings)
		Validate.optional(validator)    nil, or a value `validator` accepts
		Validate.array(validator, maxLen)
		                                plain table (no metatable) whose keys are exactly 1..n with
		                                n <= maxLen, every element accepted by `validator`
		Validate.vector3(maxMagnitude)  Vector3 with finite components and Magnitude <= maxMagnitude
		Validate.instanceOf(className)  Instance for which :IsA(className) is true
		Validate.check(validators, ...) -> (ok, reason?)
		                                validates positional arguments: at most #validators of them,
		                                argument i checked by validators[i] (missing ones are nil, so
		                                optional() works)
		Validate.MAX_DEPTH = 8          deepest array nesting accepted

	Semantics
		- Validators never throw on any input: wrong types, NaN, ±inf, huge or cyclic tables all
		  return false with a short reason ("expected string, got number", "[3] too long", ...).
		- Constructors check their own arguments and error at once on programmer mistakes
		  (e.g. Validate.string(5, 1)), so bad declarations fail at boot, not on the first call.
		- array() stops reading keys as soon as the table has more than maxLen of them, rejects
		  holes, non-integer keys and string keys, and refuses to descend into a table that is
		  already being validated (cyclic) or deeper than MAX_DEPTH nested arrays. An element
		  validator that throws counts as a rejection.
		- Validation is synchronous: validators must not yield.
]]

export type Validator = (value: any) -> (boolean, string?)

local Validate = {}

Validate.MAX_DEPTH = 8

-- Shared by every array validator: how many arrays are open on the current validation path and
-- which tables they are. Validation never yields, so one path is active at a time.
local depth = 0
local onPath: { [any]: boolean } = {}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function describeNumber(n: number): string
	if n ~= n then
		return "NaN"
	elseif n == math.huge then
		return "inf"
	elseif n == -math.huge then
		return "-inf"
	end
	return tostring(n)
end

local function assertBounds(fnName: string, min: any, max: any, integerOnly: boolean)
	if type(min) ~= "number" or type(max) ~= "number" or not isFinite(min) or not isFinite(max) then
		error(`Validate.{fnName}(min, max): min and max must be finite numbers`, 3)
	end
	if min > max then
		error(`Validate.{fnName}(min, max): min ({min}) is greater than max ({max})`, 3)
	end
	if integerOnly and (min % 1 ~= 0 or max % 1 ~= 0) then
		error(`Validate.{fnName}(min, max): min and max must be integers`, 3)
	end
end

local function assertValidator(fnName: string, validator: any)
	if type(validator) ~= "function" then
		error(`Validate.{fnName}: expected a validator function, got {typeof(validator)}`, 3)
	end
end

local function wrongType(expected: string, value: any): (boolean, string?)
	return false, `expected {expected}, got {typeof(value)}`
end

function Validate.string(min: number, max: number): Validator
	assertBounds("string", min, max, true)
	if min < 0 then
		error("Validate.string(min, max): min must be >= 0", 2)
	end
	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return wrongType("string", value)
		end
		local length = #value
		if length < min then
			return false, `string too short ({length} < {min} bytes)`
		end
		if length > max then
			return false, `string too long ({length} > {max} bytes)`
		end
		if utf8.len(value) == nil then
			return false, "string is not valid UTF-8"
		end
		return true, nil
	end
end

local function numberIn(value: any, min: number, max: number, integerOnly: boolean): (boolean, string?)
	if type(value) ~= "number" then
		return wrongType(if integerOnly then "integer" else "number", value)
	end
	if not isFinite(value) then
		return false, `number is not finite ({describeNumber(value)})`
	end
	if integerOnly and value % 1 ~= 0 then
		return false, `expected integer, got {value}`
	end
	if value < min or value > max then
		return false, `number out of range ({value} not in [{min}, {max}])`
	end
	return true, nil
end

function Validate.integer(min: number, max: number): Validator
	assertBounds("integer", min, max, true)
	return function(value: any): (boolean, string?)
		return numberIn(value, min, max, true)
	end
end

function Validate.number(min: number, max: number): Validator
	assertBounds("number", min, max, false)
	return function(value: any): (boolean, string?)
		return numberIn(value, min, max, false)
	end
end

function Validate.boolean(): Validator
	return function(value: any): (boolean, string?)
		if type(value) ~= "boolean" then
			return wrongType("boolean", value)
		end
		return true, nil
	end
end

function Validate.enum(values: { any }): Validator
	if type(values) ~= "table" or #values == 0 then
		error("Validate.enum(values): expected a non-empty list of allowed values", 2)
	end
	local allowed: { [any]: boolean } = {}
	for i, v in values do
		if type(i) ~= "number" then
			error("Validate.enum(values): values must be a list", 2)
		end
		if v ~= v then
			error("Validate.enum(values): NaN cannot be an allowed value", 2)
		end
		allowed[v] = true
	end
	return function(value: any): (boolean, string?)
		if value ~= nil and value == value and allowed[value] then
			return true, nil
		end
		return false, `{typeof(value)} value is not one of the allowed values`
	end
end

function Validate.optional(validator: Validator): Validator
	assertValidator("optional", validator)
	return function(value: any): (boolean, string?)
		if value == nil then
			return true, nil
		end
		return validator(value)
	end
end

function Validate.array(validator: Validator, maxLen: number): Validator
	assertValidator("array", validator)
	if type(maxLen) ~= "number" or not isFinite(maxLen) or maxLen < 0 or maxLen % 1 ~= 0 then
		error("Validate.array(validator, maxLen): maxLen must be a non-negative integer", 2)
	end
	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return wrongType("array", value)
		end
		if getmetatable(value) ~= nil then
			return false, "array must be a plain table (has a metatable)"
		end
		if onPath[value] then
			return false, "array is cyclic (contains itself)"
		end
		if depth >= Validate.MAX_DEPTH then
			return false, `arrays nested deeper than {Validate.MAX_DEPTH}`
		end
		local count = 0
		for key in value do
			if type(key) ~= "number" then
				return false, `array has a {typeof(key)} key`
			end
			if key < 1 or key % 1 ~= 0 then
				return false, `array has a non-positive-integer key ({describeNumber(key)})`
			end
			count += 1
			if count > maxLen then
				return false, `array too long (more than {maxLen} elements)`
			end
		end
		for i = 1, count do
			if rawget(value, i) == nil then
				return false, `array has holes (index {i} is nil)`
			end
		end
		depth += 1
		onPath[value] = true
		local ok, reason = true, nil
		for i = 1, count do
			local ran, good, why = pcall(validator, rawget(value, i))
			if not ran then
				ok, reason = false, `[{i}] validator error`
				break
			elseif not good then
				ok, reason = false, `[{i}] {why or "invalid"}`
				break
			end
		end
		onPath[value] = nil
		depth -= 1
		return ok, reason
	end
end

function Validate.vector3(maxMagnitude: number): Validator
	if type(maxMagnitude) ~= "number" or not isFinite(maxMagnitude) or maxMagnitude < 0 then
		error("Validate.vector3(maxMagnitude): maxMagnitude must be a finite number >= 0", 2)
	end
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Vector3" then
			return wrongType("Vector3", value)
		end
		if not (isFinite(value.X) and isFinite(value.Y) and isFinite(value.Z)) then
			return false, "Vector3 has a non-finite component"
		end
		local magnitude = value.Magnitude
		if not (magnitude <= maxMagnitude) then
			return false, `Vector3 too long ({describeNumber(magnitude)} > {maxMagnitude})`
		end
		return true, nil
	end
end

function Validate.instanceOf(className: string): Validator
	if type(className) ~= "string" or className == "" then
		error("Validate.instanceOf(className): className must be a non-empty string", 2)
	end
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Instance" then
			return wrongType(className, value)
		end
		if not value:IsA(className) then
			return false, `expected {className}, got {value.ClassName}`
		end
		return true, nil
	end
end

function Validate.check(validators: { Validator }, ...: any): (boolean, string?)
	local count = select("#", ...)
	local expected = #validators
	if count > expected then
		return false, `too many arguments ({count} > {expected})`
	end
	for i = 1, expected do
		local ran, good, why = pcall(validators[i], (select(i, ...)))
		if not ran then
			return false, `argument {i}: validator error`
		elseif not good then
			return false, `argument {i}: {why or "invalid"}`
		end
	end
	return true, nil
end

return Validate
