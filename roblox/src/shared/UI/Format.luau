--!strict
--[[
	UI/Format — text formatting shared by every screen. Pure.

		Format.amount(n) -> string      1234 -> "1.2k", 15300 -> "15k", 2500000 -> "2.5M"; < 1000 as is
		Format.signed(n) -> string      +12 / −50 (true minus sign)
		Format.clock(seconds) -> string 75 -> "1:15", 3725 -> "1:02:05"; negative -> "0:00"
		Format.rate(n) -> string        "+18/min"
		Format.list(words) -> string    { "a", "b", "c" } -> "a, b and c"
]]

local Format = {}

local function trim(s: string): string
	return (string.gsub(s, "%.0$", ""))
end

function Format.amount(n: number): string
	local a = math.abs(n)
	local sign = if n < 0 then "-" else ""
	if a < 1000 then
		return sign .. tostring(math.floor(a))
	elseif a < 10000 then
		return sign .. trim(string.format("%.1f", math.floor(a / 100) / 10)) .. "k"
	elseif a < 1000000 then
		return sign .. tostring(math.floor(a / 1000)) .. "k"
	elseif a < 10000000 then
		return sign .. trim(string.format("%.1f", math.floor(a / 100000) / 10)) .. "M"
	end
	return sign .. tostring(math.floor(a / 1000000)) .. "M"
end

function Format.signed(n: number): string
	if n > 0 then
		return "+" .. Format.amount(n)
	elseif n < 0 then
		return "−" .. Format.amount(-n)
	end
	return "0"
end

function Format.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

function Format.rate(n: number): string
	return "+" .. Format.amount(n) .. "/min"
end

function Format.list(words: { string }): string
	if #words <= 1 then
		return words[1] or ""
	end
	return table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
end

return table.freeze(Format)
