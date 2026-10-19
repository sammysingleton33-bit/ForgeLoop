--[[
	PluginProps: finds assignments, in Luau source text, to properties a game script may not write.

	Roblox refuses these writes in a live game ("lacking capability Plugin"); a pcall around them hides the error,
	so the code silently takes its fallback. Lune's roblox library lets the same writes through, so no spec of the
	game code can see them (FORGE-00, 2026-10-19: the Kit's MeshPart.CollisionFidelity write made every mesh rig and
	env mesh fall back to part-built in a real server while every Lune gate passed).

	The list comes from Roblox's API dump (MaximumADHD/Roblox-Client-Tracker API-Dump.json, read 2026-10-19):
	properties whose write Capabilities are PluginOrOpenCloud or whose write Security is not None, on the classes
	game code touches (parts and meshes, surface/material appearance, Workspace, Lighting, scripts, HttpService).
	A name that is also freely writable on another class (MeshId on SpecialMesh, ColorMap on Decal, Source on
	CustomEventReceiver) is still listed: such a line carries `-- plugin-context` with the reason.

	What counts as a write (on code, with comments and long strings removed):
	  obj.Prop = v          obj . Prop\n= v (split over two lines)       obj["Prop"] = v / obj['Prop'] = v
	  { Prop = v } / { a = 1, Prop = v } and a constructor line that starts with `Prop = v`
	  rawset(obj, "Prop", v)
	Not seen (documented limits): a key held in a variable or built by concatenation (obj[key] = v), and setters
	that take the property name as a value. `==` is a comparison, never a write.
	A line whose comment contains `plugin-context` is skipped (code that only ever runs inside a plugin).

	PluginProps.scan(source) -> { { line: number, prop: string } }
]]

local PluginProps = {}

PluginProps.PROPERTIES = table.freeze({
	-- TriangleMeshPart (MeshPart, PartOperation): write capability PluginOrOpenCloud / PluginSecurity
	"CollisionFidelity",
	"FluidFidelity",
	"CollisionPrecision",
	-- MeshPart / PartOperation
	"RenderFidelity",
	"MeshId", -- MeshPart: NotAccessibleSecurity (SpecialMesh.MeshId is writable: waive with plugin-context)
	"MeshContent",
	"SmoothingAngle",
	-- SurfaceAppearance / MaterialVariant / Decal PBR maps: PluginSecurity
	"ColorMap",
	"MetalnessMap",
	"NormalMap",
	"RoughnessMap",
	"ColorMapContent",
	"MetalnessMapContent",
	"NormalMapContent",
	"RoughnessMapContent",
	"EmissiveMaskContent",
	-- Model
	"LevelOfDetail",
	-- Workspace: PluginOrOpenCloud
	"StreamingEnabled",
	"StreamingAdaptiveRadius",
	"FallenPartsDestroyHeight",
	"FallHeightEnabled",
	-- Lighting
	"Technology", -- RobloxScriptSecurity
	"LightingStyle",
	"PrioritizeLightingQuality",
	-- Script / ModuleScript / BaseScript: PluginOrOpenCloud
	"Source",
	"RunContext",
	-- HttpService: LocalUserSecurity
	"HttpEnabled",
})

local function longBracketAt(s: string, i: number): number?
	-- `[` `=`* `[` at i: returns the level (count of `=`), else nil
	if s:sub(i, i) ~= "[" then
		return nil
	end
	local j = i + 1
	while s:sub(j, j) == "=" do
		j += 1
	end
	if s:sub(j, j) == "[" then
		return j - i - 1
	end
	return nil
end

-- Splits source into lines of { code, kept, comment }:
--   code    - short-string contents blanked (quotes kept), comments and long strings/comments removed
--   kept    - like code but short-string contents kept (for ["Prop"] and rawset(..., "Prop"))
--   comment - the text of every comment on that line
function PluginProps.lex(source: string): { { code: string, kept: string, comment: string } }
	local lines = {}
	local code, kept, comment = {}, {}, {}
	local function newline()
		table.insert(lines, { code = table.concat(code), kept = table.concat(kept), comment = table.concat(comment) })
		code, kept, comment = {}, {}, {}
	end
	local state = "code" -- "code" | "short" | "long" | "longcomment" | "linecomment"
	local quote = ""
	local level = 0
	local n = #source
	local i = 1
	while i <= n do
		local c = source:sub(i, i)
		if c == "\n" then
			if state == "short" or state == "linecomment" then
				state = "code" -- an unterminated short string ends at the line (invalid Luau; keep scanning)
			end
			newline()
			i += 1
		elseif state == "code" then
			if c == "-" and source:sub(i + 1, i + 1) == "-" then
				local lv = longBracketAt(source, i + 2)
				if lv then
					state, level = "longcomment", lv
					i += 4 + lv
				else
					state = "linecomment"
					i += 2
				end
			elseif c == "[" and longBracketAt(source, i) then
				level = longBracketAt(source, i) :: number
				state = "long"
				table.insert(code, " ")
				table.insert(kept, " ")
				i += 2 + level
			elseif c == '"' or c == "'" or c == "`" then
				state, quote = "short", c
				table.insert(code, c)
				table.insert(kept, c)
				i += 1
			else
				table.insert(code, c)
				table.insert(kept, c)
				i += 1
			end
		elseif state == "short" then
			if c == "\\" then
				table.insert(code, "  ")
				table.insert(kept, source:sub(i, i + 1))
				i += 2
			elseif c == quote then
				state = "code"
				table.insert(code, c)
				table.insert(kept, c)
				i += 1
			else
				table.insert(code, " ")
				table.insert(kept, c)
				i += 1
			end
		elseif state == "linecomment" then
			table.insert(comment, c)
			i += 1
		else -- "long" or "longcomment": look for the closing bracket of the same level
			local close = "]" .. string.rep("=", level) .. "]"
			if source:sub(i, i + #close - 1) == close then
				if state == "long" then
					table.insert(code, " ")
					table.insert(kept, " ")
				end
				state = "code"
				i += #close
			else
				if state == "longcomment" then
					table.insert(comment, c)
				end
				i += 1
			end
		end
	end
	newline()
	return lines
end

local function notEquals(code: string, e: number): boolean
	return code:sub(e + 1, e + 1) ~= "="
end

local function find(code: string, pattern: string): boolean
	local s, e = code:find(pattern)
	while s do
		if notEquals(code, e :: number) then
			return true
		end
		s, e = code:find(pattern, (e :: number) + 1)
	end
	return false
end

local function writesOnLine(line, prop: string): boolean
	local code, kept = line.code, line.kept
	return find(code, "%.%s*" .. prop .. "%s*=") -- obj.Prop = v
		or find(code, "[{,;]%s*" .. prop .. "%s*=") -- { Prop = v } / { a = 1, Prop = v }
		or find(code, "^%s*" .. prop .. "%s*=") -- a constructor line `Prop = v,` (or a global of that name)
		or find(kept, "%[%s*[\"'`]" .. prop .. "[\"'`]%s*%]%s*=") -- obj["Prop"] = v
		or kept:find("rawset%s*%(.-,%s*[\"'`]" .. prop .. "[\"'`]%s*,") ~= nil -- rawset(obj, "Prop", v)
end

function PluginProps.scan(source: string): { { line: number, prop: string } }
	local found = {}
	local lines = PluginProps.lex(source)
	for n, line in lines do
		if line.comment:find("plugin%-context") then
			continue
		end
		for _, prop in PluginProps.PROPERTIES do
			local hit = writesOnLine(line, prop)
			if not hit and line.code:find("%.%s*" .. prop .. "%s*$") then
				-- obj.Prop\n= v: the `=` opens the next line that has code
				local nextLine = lines[n + 1]
				hit = nextLine ~= nil and nextLine.code:find("^%s*=[^=]") ~= nil
					or nextLine ~= nil and nextLine.code:find("^%s*=$") ~= nil
			end
			if hit then
				table.insert(found, { line = n, prop = prop })
			end
		end
	end
	return found
end

return PluginProps
