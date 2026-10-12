--[[
	Path — small POSIX-style path helpers for the Lune harness (backslashes are normalised to "/").

	API: normalize(p), join(a, b), dirname(p), basename(p), isAbsolute(p), relative(root, p)
]]

local Path = {}

-- "/x", "C:/x" and "C:\\x" (Windows: Lune reports chunk names with backslashes) are absolute.
function Path.isAbsolute(p: string): boolean
	p = string.gsub(p, "\\", "/")
	return string.sub(p, 1, 1) == "/" or string.match(p, "^%a:/") ~= nil
end

function Path.normalize(p: string): string
	p = string.gsub(p, "\\", "/")
	local prefix = ""
	if string.match(p, "^%a:/") then
		prefix = string.sub(p, 1, 3)
		p = string.sub(p, 4)
	elseif string.sub(p, 1, 1) == "/" then
		prefix = "/"
		p = string.sub(p, 2)
	end
	local parts = {}
	for part in string.gmatch(p, "[^/]+") do
		if part == "." then
			continue
		elseif part == ".." then
			if #parts > 0 and parts[#parts] ~= ".." then
				table.remove(parts)
			elseif prefix == "" then
				table.insert(parts, "..")
			end
		else
			table.insert(parts, part)
		end
	end
	local joined = prefix .. table.concat(parts, "/")
	return if joined == "" then "." else joined
end

function Path.join(a: string, b: string): string
	if Path.isAbsolute(b) then
		return Path.normalize(b)
	end
	return Path.normalize(a .. "/" .. b)
end

function Path.dirname(p: string): string
	p = Path.normalize(p)
	local dir = string.match(p, "^(.*)/[^/]*$")
	if dir == nil then
		return "."
	end
	if dir == "" then
		return "/"
	end
	return dir
end

function Path.basename(p: string): string
	return string.match(Path.normalize(p), "([^/]*)$") or p
end

-- Path of `p` relative to `root` when `p` is inside it; otherwise `p` unchanged.
function Path.relative(root: string, p: string): string
	root = Path.normalize(root)
	p = Path.normalize(p)
	if p == root then
		return "."
	end
	local prefix = if string.sub(root, -1) == "/" then root else root .. "/"
	if string.sub(p, 1, #prefix) == prefix then
		return string.sub(p, #prefix + 1)
	end
	return p
end

return Path
