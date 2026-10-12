--[[
	ExtraDatatypes — stand-ins for Roblox datatypes that @lune/roblox does not provide, so modules
	that build them (often at load time) run under the harness. Behaviour beyond what is listed
	here is NOT emulated; a missing member errors like Roblox does ("X is not a valid member").

	Imitates (creator-docs content/en-us/reference/engine/datatypes/...):
	  TweenInfo.yaml      TweenInfo.new(time = 1, easingStyle = Quad, easingDirection = Out,
	                      repeatCount = 0, reverses = false, delayTime = 0); read-only fields
	                      Time, EasingStyle, EasingDirection, RepeatCount, Reverses, DelayTime
	  RaycastParams.yaml  RaycastParams.new() property bag (FilterDescendantsInstances, FilterType,
	                      IgnoreWater, CollisionGroup, RespectCanCollide, BruteForceAllSlow, Margin,
	                      SizeGradient, ExcludeInstances, IncludeInstances) + :AddToFilter
	  OverlapParams.yaml  OverlapParams.new() property bag (FilterDescendantsInstances, FilterType,
	                      MaxParts, CollisionGroup, Tolerance, RespectCanCollide, BruteForceAllSlow,
	                      ExcludeInstances, IncludeInstances) + :AddToFilter
	  DateTime.yaml       UTC only: fromUnixTimestamp, fromUnixTimestampMillis, fromUniversalTime,
	                      fromIsoDate (nil on bad input), .UnixTimestamp, .UnixTimestampMillis,
	                      :ToUniversalTime(), :ToIsoDate() ("2020-01-02T10:30:45Z"; ".mmm" is added
	                      only for non-zero milliseconds — unverified against Roblox).
	                      DateTime.now() errors: services take time from env.now() (interfaces §2).
	                      Local-time members and Format*Time error (not provided).
	Nothing here casts rays or plays tweens: raycasts and TweenService belong to Studio tests (G6).

	API: ExtraDatatypes.build(Enum) -> { TweenInfo, RaycastParams, OverlapParams, DateTime }
]]

local ExtraDatatypes = {}

local function readOnly(typeName: string, fields: { [string]: any })
	return setmetatable({}, {
		__index = function(_, key)
			local value = fields[key]
			if value == nil then
				error(`{tostring(key)} is not a valid member of {typeName}`, 2)
			end
			return value
		end,
		__newindex = function(_, key)
			error(`{tostring(key)} cannot be assigned to ({typeName} is read-only)`, 2)
		end,
		__tostring = function()
			return typeName
		end,
	})
end

-- A mutable property bag that only accepts the documented members.
local function propertyBag(typeName: string, defaults: { [string]: any }, nilable: { string })
	local valid = {}
	for key in defaults do
		valid[key] = true
	end
	for _, key in nilable do
		valid[key] = true
	end
	local values = table.clone(defaults)
	values.FilterDescendantsInstances = {}
	local bag = {}
	function bag.AddToFilter(_self, instances: any)
		local list = if typeof(instances) == "Instance" then { instances } else instances
		assert(type(list) == "table", `{typeName}:AddToFilter expects an Instance or an array of Instances`)
		for _, instance in list do
			table.insert(values.FilterDescendantsInstances, instance)
		end
	end
	return setmetatable({}, {
		__index = function(_, key)
			if key == "AddToFilter" then
				return bag.AddToFilter
			end
			if not valid[key] then
				error(`{tostring(key)} is not a valid member of {typeName}`, 2)
			end
			return values[key]
		end,
		__newindex = function(_, key, value)
			if not valid[key] then
				error(`{tostring(key)} is not a valid member of {typeName}`, 2)
			end
			values[key] = value
		end,
		__tostring = function()
			return typeName
		end,
	})
end

-- ------------------------------------------------------------------ DateTime (UTC, pure Luau)
-- Civil-date conversions after Howard Hinnant's days_from_civil / civil_from_days.
local function daysFromCivil(y: number, m: number, d: number): number
	y = if m <= 2 then y - 1 else y
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

local function civilFromDays(z: number): (number, number, number)
	z += 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	return (if m <= 2 then y + 1 else y), m, d
end

local function daysInMonth(y: number, m: number): number
	if m == 2 then
		local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
		return if leap then 29 else 28
	end
	return if m == 4 or m == 6 or m == 9 or m == 11 then 30 else 31
end

local MIN_MILLIS = -17987443200 * 1000
local MAX_MILLIS = 253402300799 * 1000 + 999

local function newDateTime(millis: number)
	millis = math.floor(millis)
	if millis < MIN_MILLIS or millis > MAX_MILLIS then
		error("DateTime: the timestamp is outside the supported range (years 1400 to 9999)", 3)
	end
	local methods = {}
	function methods.ToUniversalTime(_self)
		local days = millis // 86400000
		local rest = millis - days * 86400000
		local y, m, d = civilFromDays(days)
		return {
			Year = y,
			Month = m,
			Day = d,
			Hour = rest // 3600000,
			Minute = (rest // 60000) % 60,
			Second = (rest // 1000) % 60,
			Millisecond = rest % 1000,
		}
	end
	function methods.ToIsoDate(self)
		local t = methods.ToUniversalTime(self)
		local base = string.format("%04d-%02d-%02dT%02d:%02d:%02d", t.Year, t.Month, t.Day, t.Hour, t.Minute, t.Second)
		if t.Millisecond ~= 0 then
			base ..= string.format(".%03d", t.Millisecond)
		end
		return base .. "Z"
	end
	local function notProvided(name: string)
		return function()
			error(`DateTime:{name} is not provided under the Lune harness (UTC-only stand-in)`, 2)
		end
	end
	methods.ToLocalTime = notProvided("ToLocalTime")
	methods.FormatUniversalTime = notProvided("FormatUniversalTime")
	methods.FormatLocalTime = notProvided("FormatLocalTime")
	return readOnly("DateTime", {
		UnixTimestamp = millis // 1000,
		UnixTimestampMillis = millis,
		ToUniversalTime = methods.ToUniversalTime,
		ToIsoDate = methods.ToIsoDate,
		ToLocalTime = methods.ToLocalTime,
		FormatUniversalTime = methods.FormatUniversalTime,
		FormatLocalTime = methods.FormatLocalTime,
	})
end

local function fromUniversalTime(
	year: number?,
	month: number?,
	day: number?,
	hour: number?,
	minute: number?,
	second: number?,
	millisecond: number?
)
	local y = math.floor(year or 1970)
	local m = math.floor(month or 1)
	local d = math.floor(day or 1)
	if m < 1 or m > 12 or d < 1 or d > daysInMonth(y, m) then
		error(`DateTime.fromUniversalTime: invalid date {y}-{m}-{d}`, 2)
	end
	local millis = daysFromCivil(y, m, d) * 86400000
		+ math.floor(hour or 0) * 3600000
		+ math.floor(minute or 0) * 60000
		+ math.floor(second or 0) * 1000
		+ math.floor(millisecond or 0)
	return newDateTime(millis)
end

local DateTime = table.freeze({
	now = function()
		error(
			"DateTime.now() is not available under the Lune harness: take time from the injected env "
				.. "(env.now(), env.serverTimeNow(); interfaces §2) so specs control the clock",
			2
		)
	end,
	fromUnixTimestamp = function(seconds: number)
		assert(type(seconds) == "number", "DateTime.fromUnixTimestamp expects a number")
		return newDateTime(math.floor(seconds) * 1000)
	end,
	fromUnixTimestampMillis = function(millis: number)
		assert(type(millis) == "number", "DateTime.fromUnixTimestampMillis expects a number")
		return newDateTime(millis)
	end,
	fromUniversalTime = fromUniversalTime,
	fromIsoDate = function(iso: string)
		if type(iso) ~= "string" then
			return nil
		end
		local y, mo, d, h, mi, s, rest = string.match(iso, "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(.*)$")
		if not y then
			return nil
		end
		local millis = 0
		local fraction, zone = string.match(rest, "^%.(%d+)(.*)$")
		if fraction then
			millis = math.floor(tonumber(string.sub(fraction .. "00", 1, 3)) :: number)
			rest = zone
		end
		if rest ~= "Z" then
			return nil -- only UTC ("Z") strings are accepted
		end
		local ok, result = pcall(
			fromUniversalTime,
			tonumber(y),
			tonumber(mo),
			tonumber(d),
			tonumber(h),
			tonumber(mi),
			tonumber(s),
			millis
		)
		return if ok then result else nil
	end,
	fromLocalTime = function()
		error("DateTime.fromLocalTime is not provided under the Lune harness (UTC-only stand-in)", 2)
	end,
})

function ExtraDatatypes.build(Enum: any)
	local TweenInfo = {
		new = function(
			time: number?,
			easingStyle: any?,
			easingDirection: any?,
			repeatCount: number?,
			reverses: boolean?,
			delayTime: number?
		)
			return readOnly("TweenInfo", {
				Time = if time == nil then 1 else time,
				EasingStyle = easingStyle or Enum.EasingStyle.Quad,
				EasingDirection = easingDirection or Enum.EasingDirection.Out,
				RepeatCount = repeatCount or 0,
				Reverses = reverses == true,
				DelayTime = delayTime or 0,
			})
		end,
	}
	local RaycastParams = {
		new = function()
			return propertyBag("RaycastParams", {
				FilterDescendantsInstances = {},
				FilterType = Enum.RaycastFilterType.Exclude,
				IgnoreWater = false,
				CollisionGroup = "Default",
				RespectCanCollide = false,
				BruteForceAllSlow = false,
				Margin = 0,
				SizeGradient = 0,
			}, { "ExcludeInstances", "IncludeInstances" })
		end,
	}
	local OverlapParams = {
		new = function()
			return propertyBag("OverlapParams", {
				FilterDescendantsInstances = {},
				FilterType = Enum.RaycastFilterType.Exclude,
				MaxParts = 0,
				CollisionGroup = "Default",
				Tolerance = 0,
				RespectCanCollide = false,
				BruteForceAllSlow = false,
			}, { "ExcludeInstances", "IncludeInstances" })
		end,
	}
	return {
		TweenInfo = table.freeze(TweenInfo),
		RaycastParams = table.freeze(RaycastParams),
		OverlapParams = table.freeze(OverlapParams),
		DateTime = DateTime,
	}
end

return ExtraDatatypes
