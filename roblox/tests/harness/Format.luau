--[[
	Format — readable one-line rendering of Luau values for test failure messages.

	API: Format.value(v, maxDepth?) -> string
]]

local Format = {}

local function isArray(t: { [any]: any }): boolean
	local n = 0
	for _ in t do
		n += 1
	end
	for i = 1, n do
		if t[i] == nil then
			return false
		end
	end
	return true
end

local function keyText(k: any): string
	if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
		return k
	end
	return "[" .. Format.value(k, 0) .. "]"
end

local function render(v: any, depth: number, seen: { [any]: boolean }): string
	local kind = typeof(v)
	if kind == "string" then
		return string.format("%q", v)
	elseif kind == "number" then
		if v ~= v then
			return "NaN"
		end
		return tostring(v)
	elseif kind == "table" then
		if seen[v] then
			return "<cycle>"
		end
		if depth <= 0 then
			return "{...}"
		end
		seen[v] = true
		local parts = {}
		if isArray(v) then
			for _, item in ipairs(v) do
				table.insert(parts, render(item, depth - 1, seen))
			end
		else
			local keys = {}
			for k in v do
				table.insert(keys, k)
			end
			table.sort(keys, function(a, b)
				return tostring(a) < tostring(b)
			end)
			for _, k in keys do
				table.insert(parts, keyText(k) .. " = " .. render(v[k], depth - 1, seen))
			end
		end
		seen[v] = nil
		if #parts > 12 then
			local count = #parts
			parts = table.move(parts, 1, 12, 1, {})
			table.insert(parts, `... ({count - 12} more)`)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif kind == "Instance" then
		return `{v.ClassName}({v.Name})`
	end
	return tostring(v)
end

function Format.value(v: any, maxDepth: number?): string
	return render(v, maxDepth or 3, {})
end

return Format
