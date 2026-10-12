--!strict
--[[
	Experience/Validators — remote argument validators for Experience/Remotes.luau.

	TEMPORARY: the same shape as FORGE-01's shared/Core/Validate (interfaces §6: each validator is
	(value) -> (boolean, string?)). Core/Validate is not on main yet (FL-0007), and a require of a
	missing module fails the place check, so Experience keeps this minimal subset until it lands;
	then Remotes.luau switches to Core/Validate and this file is deleted (handoff to FORGE-01).
	Servers still re-check every value in the handler (defence in depth).
]]

local Validators = {}

export type Validator = (value: any) -> (boolean, string?)

function Validators.string(min: number, max: number): Validator
	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return false, "expected string"
		end
		if #value < min or #value > max then
			return false, `length {#value} outside {min}..{max} bytes`
		end
		if utf8.len(value) == nil then
			return false, "invalid UTF-8"
		end
		return true, nil
	end
end

function Validators.enum(options: { string }): Validator
	local allowed = table.clone(options)
	return function(value: any): (boolean, string?)
		if type(value) == "string" and table.find(allowed, value) then
			return true, nil
		end
		return false, "not an allowed value"
	end
end

-- A setting value: a finite number in 0..1, a boolean, or a short string (enum settings).
function Validators.settingValue(): Validator
	return function(value: any): (boolean, string?)
		local kind = type(value)
		if kind == "boolean" then
			return true, nil
		elseif kind == "number" then
			if value ~= value or value < 0 or value > 1 then
				return false, "number outside 0..1"
			end
			return true, nil
		elseif kind == "string" then
			if #value < 1 or #value > 16 then
				return false, "string length outside 1..16"
			end
			return true, nil
		end
		return false, "expected boolean, number or string"
	end
end

return table.freeze(Validators)
