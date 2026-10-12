--[[
	RequirePath — parse and resolve require-by-string paths with Roblox semantics.

	Shared by the Lune module loader (tests) and roblox/scripts/check_place.luau (built place),
	so both apply exactly one set of rules.

	Roblox semantics (creator-docs content/en-us/reference/engine/globals/LuaGlobals.yaml, `require`):
	  - "./"     begins resolution at script.Parent
	  - "../"    begins resolution at script.Parent.Parent
	  - "@self/" begins resolution at script
	  - "@game/" begins resolution at game (the DataModel root)
	  - every further component is a child by name; ".." is the parent of the previous component
	  - resolution never waits for instances (non-blocking)

	FORGELOOP policy (DECISIONS.md D-017, roblox/README.md): game code may use only relative paths
	inside one source tree and "@game/..." to reach another tree. "@self" and every other alias are
	rejected. Test-only code (roblox/tests, roblox/scripts) may additionally use "@lune/...".

	API
		RequirePath.parse(path) -> Parsed | (nil, err)
			Parsed = { kind: "relative" | "game" | "lune", up: number, components: { string }, raw: string }
			relative: up = 1 for "./", 2 for "../" (number of parents above the script to start at)
		RequirePath.apply(base: { string }, components: { string }) -> ({ string }?, string?)
			walks components from base (a DataModel path as a list of names); ".." pops one level
		RequirePath.scan(source) -> { { path: string?, line: number, depth: number, text: string } }
			every require in a chunk of Luau source, found by tokenizing it (comments and the
			contents of string literals are never mistaken for code). path = nil when the argument
			is not one plain string literal (require(instance), require(x), a bare `require`
			reference). depth = number of enclosing blocks (function, if, do, while, for, repeat);
			0 means top level of the module. Luau if-expressions do not count as blocks.
		RequirePath.checkPolicy(parsed, fromMount, toMount, target) -> string?
			the D-017 rule for code inside the project trees (nil = allowed); mounts are the Rojo
			"$path" nodes (Project.mountForFile / mountForDataModel), compared by identity:
			  - relative paths stay inside the requiring file's own mount;
			  - "@game/..." only crosses into another mount, and only to ReplicatedStorage/Forge/...
			    (shared code, Config, Assets): server and client trees cannot see each other, and
			    ServerScriptService never replicates to clients (interfaces §1).
]]

local RequirePath = {}

local function splitComponents(rest: string): ({ string }?, string?)
	local components = {}
	if rest == "" then
		return nil, "path has no module name after its prefix"
	end
	for component in string.gmatch(rest .. "/", "([^/]*)/") do
		if component == "" then
			return nil, "empty path component (double or trailing '/')"
		end
		if component == "." then
			return nil, "'.' is only allowed as the './' prefix"
		end
		if string.match(component, "%.luau?$") then
			return nil, `component '{component}' has a file extension; require paths name instances, not files`
		end
		table.insert(components, component)
	end
	return components, nil
end

function RequirePath.parse(path: string): (any, string?)
	if type(path) ~= "string" then
		return nil, "require path must be a string"
	end
	local up: number? = nil
	local kind: string
	local rest: string
	if string.sub(path, 1, 2) == "./" then
		kind, up, rest = "relative", 1, string.sub(path, 3)
	elseif string.sub(path, 1, 3) == "../" then
		kind, up, rest = "relative", 2, string.sub(path, 4)
	elseif string.sub(path, 1, 6) == "@game/" then
		kind, rest = "game", string.sub(path, 7)
	elseif string.sub(path, 1, 6) == "@lune/" then
		kind, rest = "lune", string.sub(path, 7)
	elseif string.sub(path, 1, 5) == "@self" then
		return nil,
			"'@self' is not an allowed require form (D-017: relative paths inside a tree, '@game/...' across trees)"
	elseif string.sub(path, 1, 1) == "@" then
		return nil,
			`unknown alias in '{path}'; the only allowed alias is '@game/...' (D-017), plus '@lune/...' in test tooling`
	else
		return nil, `'{path}' must start with './', '../' or '@game/'`
	end
	local components, err = splitComponents(rest)
	if not components then
		return nil, `bad require path '{path}': {err}`
	end
	return { kind = kind, up = up or 0, components = components, raw = path }, nil
end

function RequirePath.apply(base: { string }, components: { string }): ({ string }?, string?)
	local out = table.clone(base)
	for _, component in components do
		if component == ".." then
			if #out == 0 then
				return nil, "path walks above the DataModel root"
			end
			table.remove(out)
		else
			table.insert(out, component)
		end
	end
	return out, nil
end

-- Start of resolution for a relative path, given the full DataModel path of the requiring script.
function RequirePath.relativeBase(scriptPath: { string }, up: number): ({ string }?, string?)
	if #scriptPath < up then
		return nil, "relative path walks above the DataModel root"
	end
	local base = table.clone(scriptPath)
	for _ = 1, up do
		table.remove(base)
	end
	return base, nil
end

-- ------------------------------------------------------------------ tokenizer
local KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local SYMBOLS =
	{ "...", "..=", "//=", "..", "::", "->", "==", "~=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "^=" }

-- Tokens: { kind = "name" | "keyword" | "string" | "number" | "symbol", value, line, plain }
-- (plain = a string literal without interpolation). Comments are skipped.
function RequirePath.tokenize(source: string): { any }
	local tokens = {}
	local i, n, line = 1, #source, 1
	local function longBracketLevel(at: number): number?
		local eqs = string.match(source, "^%[(=*)%[", at)
		return if eqs then #eqs else nil
	end
	local function countLines(from: number, to: number)
		for _ in string.gmatch(string.sub(source, from, to), "\n") do
			line += 1
		end
	end
	-- Skips a quoted string starting at `at` (quote char q); returns the index of the closing quote.
	local function skipQuoted(at: number, q: string): number
		local j = at + 1
		while j <= n do
			local d = string.sub(source, j, j)
			if d == "\\" then
				j += 2
			elseif d == q or d == "\n" then
				return j
			else
				j += 1
			end
		end
		return n
	end
	-- Skips an interpolated string `...{expr}...` (nested braces/strings inside {}); returns its end.
	local function skipInterpolated(at: number): (number, boolean)
		local j = at + 1
		local interpolated = false
		while j <= n do
			local d = string.sub(source, j, j)
			if d == "\\" then
				j += 2
			elseif d == "`" then
				return j, interpolated
			elseif d == "{" then
				interpolated = true
				local depth = 1
				j += 1
				while j <= n and depth > 0 do
					local e = string.sub(source, j, j)
					if e == "{" then
						depth += 1
					elseif e == "}" then
						depth -= 1
					elseif e == '"' or e == "'" then
						j = skipQuoted(j, e)
					elseif e == "`" then
						j = skipInterpolated(j)
					end
					j += 1
				end
			else
				j += 1
			end
		end
		return n, interpolated
	end
	while i <= n do
		local c = string.sub(source, i, i)
		if c == "\n" then
			line += 1
			i += 1
		elseif string.match(c, "%s") then
			i += 1
		elseif c == "-" and string.sub(source, i, i + 1) == "--" then
			local level = longBracketLevel(i + 2)
			local stop
			if level then
				local _, e = string.find(source, "]" .. string.rep("=", level) .. "]", i + 2, true)
				stop = e or n
			else
				local e = string.find(source, "\n", i, true)
				stop = if e then e - 1 else n
			end
			countLines(i, stop)
			i = stop + 1
		elseif c == '"' or c == "'" then
			local stop = skipQuoted(i, c)
			table.insert(
				tokens,
				{ kind = "string", value = string.sub(source, i + 1, stop - 1), line = line, plain = true }
			)
			countLines(i, stop)
			i = stop + 1
		elseif c == "`" then
			local stop, interpolated = skipInterpolated(i)
			table.insert(tokens, {
				kind = "string",
				value = string.sub(source, i + 1, stop - 1),
				line = line,
				plain = not interpolated,
			})
			countLines(i, stop)
			i = stop + 1
		elseif c == "[" and longBracketLevel(i) then
			local level = longBracketLevel(i) :: number
			local _, e = string.find(source, "]" .. string.rep("=", level) .. "]", i + 2 + level, true)
			local stop = e or n
			table.insert(tokens, {
				kind = "string",
				value = string.sub(source, i + 2 + level, stop - 2 - level),
				line = line,
				plain = true,
			})
			countLines(i, stop)
			i = stop + 1
		elseif string.match(c, "[%a_]") then
			local word = string.match(source, "^[%w_]+", i) :: string
			table.insert(tokens, { kind = if KEYWORDS[word] then "keyword" else "name", value = word, line = line })
			i += #word
		elseif string.match(c, "%d") or (c == "." and string.match(source, "^%.%d", i)) then
			local stop = i
			while stop <= n do
				local d = string.sub(source, stop, stop)
				local exponentSign = (d == "+" or d == "-")
					and string.match(string.sub(source, stop - 1, stop - 1), "[eE]") ~= nil
				if string.match(d, "[%w_%.]") or exponentSign then
					stop += 1
				else
					break
				end
			end
			table.insert(tokens, { kind = "number", value = string.sub(source, i, stop - 1), line = line })
			i = stop
		else
			local symbol = c
			for _, candidate in SYMBOLS do
				if string.sub(source, i, i + #candidate - 1) == candidate then
					symbol = candidate
					break
				end
			end
			table.insert(tokens, { kind = "symbol", value = symbol, line = line })
			i += #symbol
		end
	end
	return tokens
end

-- After these tokens an `if` starts an if-expression (no `end`), not an if-statement.
local EXPRESSION_BEFORE = {
	["="] = true,
	["("] = true,
	[","] = true,
	["{"] = true,
	["["] = true,
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["//"] = true,
	["%"] = true,
	["^"] = true,
	[".."] = true,
	["=="] = true,
	["~="] = true,
	["<"] = true,
	[">"] = true,
	["<="] = true,
	[">="] = true,
	["#"] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["//="] = true,
	["%="] = true,
	["^="] = true,
	["..="] = true,
	["return"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
	["in"] = true,
	["until"] = true,
	["while"] = true,
	["if"] = true,
	["elseif"] = true,
}

-- Finds every require in a chunk of Luau source, with its block depth (see the API above).
function RequirePath.scan(source: string): { { path: string?, line: number, depth: number, text: string } }
	local tokens = RequirePath.tokenize(source)
	local lines = string.split(source, "\n")
	local found = {}
	local stack = {} -- entries: "function" | "if" | "ifexpr" | "do" | "loop" | "loopdo" | "repeat"
	local exprNext = false -- the previous token puts the next `if` in expression position
	local function blockDepth(): number
		local depth = 0
		for _, entry in stack do
			if entry ~= "ifexpr" then
				depth += 1
			end
		end
		return depth
	end
	for index, token in tokens do
		local value = token.value
		local nextExpr = false
		if token.kind == "keyword" then
			local top = stack[#stack]
			if value == "function" then
				table.insert(stack, "function")
			elseif value == "if" then
				table.insert(stack, if exprNext then "ifexpr" else "if")
				nextExpr = true
			elseif value == "then" then
				nextExpr = top == "ifexpr"
			elseif value == "else" then
				if top == "ifexpr" then
					table.remove(stack)
					nextExpr = true
				end
			elseif value == "while" or value == "for" then
				table.insert(stack, "loop")
				nextExpr = value == "while"
			elseif value == "do" then
				if top == "loop" then
					stack[#stack] = "loopdo"
				else
					table.insert(stack, "do")
				end
			elseif value == "repeat" then
				table.insert(stack, "repeat")
			elseif value == "until" then
				if top == "repeat" then
					table.remove(stack)
				end
				nextExpr = true
			elseif value == "end" then
				while stack[#stack] == "ifexpr" do
					table.remove(stack)
				end
				table.remove(stack)
			else
				nextExpr = EXPRESSION_BEFORE[value] == true
			end
		elseif token.kind == "symbol" then
			nextExpr = EXPRESSION_BEFORE[value] == true
		elseif token.kind == "name" and value == "require" then
			local before = tokens[index - 1]
			local isMember = before ~= nil and before.kind == "symbol" and (before.value == "." or before.value == ":")
			local isDeclaration = before ~= nil
				and before.kind == "keyword"
				and (before.value == "local" or before.value == "function")
			if not isMember and not isDeclaration then
				local after, argument, closing = tokens[index + 1], tokens[index + 2], tokens[index + 3]
				local path = nil
				if after and after.kind == "string" and after.plain then
					path = after.value -- require "x"
				elseif
					after
					and after.kind == "symbol"
					and after.value == "("
					and argument
					and argument.kind == "string"
					and argument.plain
					and closing
					and closing.kind == "symbol"
					and closing.value == ")"
				then
					path = argument.value
				end
				table.insert(found, {
					path = path,
					line = token.line,
					depth = blockDepth(),
					text = (string.gsub(lines[token.line] or "", "^%s+", "")),
				})
			end
		end
		exprNext = nextExpr
	end
	return found
end

-- ------------------------------------------------------------------ policy (D-017, interfaces §1)
function RequirePath.checkPolicy(parsed: any, fromMount: any, toMount: any, target: { string }): string?
	local sameTree = fromMount ~= nil and fromMount == toMount
	if parsed.kind == "relative" then
		if not sameTree then
			return `crosses into another source tree; use "@game/{table.concat(target, "/")}" (D-017)`
		end
	elseif parsed.kind == "game" then
		if sameTree then
			return "stays inside its own source tree; use a relative path (D-017)"
		end
		if target[1] ~= "ReplicatedStorage" or target[2] ~= "Forge" then
			return `reaches {table.concat(target, ".")}; "@game/" may only reach ReplicatedStorage/Forge/... `
				.. "(shared code, Config, Assets): server and client trees cannot see each other and "
				.. "ServerScriptService never replicates to clients (interfaces §1)"
		end
	end
	return nil
end

return RequirePath
