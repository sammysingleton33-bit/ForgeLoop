--!strict
--[[
	UI/Signature — a deterministic string for view data, so a view can tell "same layout, new
	values" from "new layout" and keep its instances (FORGE-05 review M1 on PR #25: rebuilding a
	drawer on every push lost taps and reset scroll).

	Signature.of(value) -> string
		Tables are written with sorted keys; functions are skipped (callbacks change every render);
		Roblox values use tostring. Nesting deeper than MAX_DEPTH is written as "…".
]]

local Signature = {}

Signature.MAX_DEPTH = 8

local function write(out: { string }, value: any, depth: number)
	local kind = typeof(value)
	if kind == "table" then
		if depth >= Signature.MAX_DEPTH then
			table.insert(out, "…")
			return
		end
		local keys = {}
		for key, v in value do
			if type(v) ~= "function" then
				table.insert(keys, key)
			end
		end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then
				return ta < tb
			end
			return if ta == "number" or ta == "string" then a < b else tostring(a) < tostring(b)
		end)
		table.insert(out, "{")
		for _, key in keys do
			table.insert(out, tostring(key))
			table.insert(out, "=")
			write(out, value[key], depth + 1)
			table.insert(out, ";")
		end
		table.insert(out, "}")
	elseif kind == "function" then
		return
	elseif kind == "string" then
		table.insert(out, string.format("%q", value))
	else
		table.insert(out, kind)
		table.insert(out, ":")
		table.insert(out, tostring(value))
	end
end

function Signature.of(value: any): string
	local out = {}
	write(out, value, 0)
	return table.concat(out)
end

return table.freeze(Signature)
