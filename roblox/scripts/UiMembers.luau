--[[
	UiMembers: finds, in Luau source text, engine members a live client would refuse though every Lune spec passes.

	Lune's roblox library rejects a property name its class does not have, so a misspelt property already fails any
	spec that runs it. It lets other things through that a real Roblox client refuses (FORGE-00, B22 HUD P0,
	2026-10-22):
	  - a write to a property a script may not write: read-only (AbsoluteSize, TextBounds) or not scriptable;
	  - a GetPropertyChangedSignal("X") whose X no class has (it errors live; mocks hand back a signal);
	  - an Enum.X.Y that does not exist (only checked live on the paths a spec runs).
	The truth is Lune's reflection database (the API dump Lune ships; roblox.getReflectionDatabase()).

	A property write is flagged only when its name is read-only or not scriptable on a class in scope (GUI classes, UI
	components and the client services in SCOPE_CLASSES) and freely writable on no class at all: the scan does not
	know the receiver's class, so a name writable anywhere (Shape on a Part, Transparency on a UIStroke) passes.
	Lines come from PluginProps.lex (one lexer for both scanners): comments, long strings and string contents are not
	code, so a `--` inside a string and a write inside a block comment are both handled. Write shapes: `obj.X = v`,
	`obj["X"] = v`, rawset(obj, "X", v) and a table key `X = v` (Create property tables).
	Limits:
	  - one-letter names are not flagged (data tables `{ A = ..., B = ... }` and module fields `Parts.C`);
	  - the blocked set holds names that are plausible data-table or children-table keys (Content, Terrain, Plugin,
	    Resolution, LocalPlayer, IsLoaded, HasFocus, ...): such a line takes a `member-ok` waiver, and more will as
	    code lands (FORGE-05's L3 on #291);
	  - not seen: event names (the database has no events), beta-flag members (listed like any other), a key held in
	    a variable or built by concatenation.
	A line whose comment contains `member-ok` is skipped (give the reason after it).

	UiMembers.index(db) -> Index                    built once from the reflection database
	UiMembers.scan(source, index) -> { { line, kind ("write" | "signal" | "enum"), name } }
]]

local PluginProps = require("./PluginProps")

local UiMembers = {}

UiMembers.SCOPE_BASES = table.freeze({ "GuiBase", "UIComponent" })
UiMembers.SCOPE_CLASSES =
	table.freeze({ "GuiService", "UserInputService", "StarterGui", "Players", "Player", "Camera", "Workspace" })

export type Index = {
	blocked: { [string]: boolean }, -- read-only or not scriptable on a class in scope, writable on no class at all
	properties: { [string]: boolean }, -- every property name of every class
	enums: { [string]: boolean }, -- "EnumName.Item"
}

local function isA(db: any, className: string, base: string): boolean
	local c = db:GetClass(className)
	while c ~= nil do
		if c.Name == base then
			return true
		end
		c = if c.Superclass then db:GetClass(c.Superclass) else nil
	end
	return false
end

function UiMembers.index(db: any): Index
	local writable, notWritable, properties, enums = {}, {}, {}, {}
	for _, className in db:GetClassNames() do
		local class = db:GetClass(className)
		local inScope = table.find(UiMembers.SCOPE_CLASSES, className) ~= nil
		if not inScope then
			for _, base in UiMembers.SCOPE_BASES do
				if isA(db, className, base) then
					inScope = true
					break
				end
			end
		end
		for name, prop in class.Properties do
			properties[name] = true
			if prop.Scriptability == "ReadWrite" then
				writable[name] = true -- on any class: the scan does not know the receiver's class
			elseif inScope then
				notWritable[name] = true
			end
		end
	end
	local blocked = {}
	for name in notWritable do
		-- one-letter names (Color3-like A, B, C on a few classes) are data-table keys far more often than writes
		if not writable[name] and #name > 1 then
			blocked[name] = true
		end
	end
	for _, enumName in db:GetEnumNames() do
		for item in db:GetEnum(enumName).Items do
			enums[`{enumName}.{item}`] = true
		end
	end
	return { blocked = blocked, properties = properties, enums = enums }
end

function UiMembers.scan(source: string, index: Index): { { line: number, kind: string, name: string } }
	-- PluginProps' lexer (one lexer for both scanners): `code` has comments, long strings and short-string contents
	-- removed; `kept` keeps short-string contents (for ["X"], rawset and GetPropertyChangedSignal("X")).
	local hits = {}
	for n, line in PluginProps.lex(source) do
		if string.find(line.comment, "member-ok", 1, true) then
			continue
		end
		local c, kept = line.code, line.kept
		local seen = {}
		local function hit(kind: string, name: string)
			if not seen[kind .. name] then
				seen[kind .. name] = true
				table.insert(hits, { line = n, kind = kind, name = name })
			end
		end
		local function write(name: string?)
			if name and index.blocked[name] then
				hit("write", name)
			end
		end
		for name in string.gmatch(c .. " ", "%.%s*(%u[%w_]*)%s*=[^=]") do
			write(name)
		end
		for name in string.gmatch(kept .. " ", "%[%s*[\"'`](%u[%w_]*)[\"'`]%s*%]%s*=[^=]") do
			write(name)
		end
		for name in string.gmatch(kept, "rawset%s*%(.-,%s*[\"'`](%u[%w_]*)[\"'`]%s*,") do
			write(name)
		end
		write(string.match(c .. " ", "^%s*(%u[%w_]*)%s*=[^=]")) -- a constructor line `X = v,` (gmatch cannot anchor)
		for name in string.gmatch(c, "[{,]%s*(%u[%w_]*)%s*=[^=]") do
			write(name)
		end
		for name in string.gmatch(kept, "GetPropertyChangedSignal%(%s*[\"'`]([%w_]+)[\"'`]%s*%)") do
			if not index.properties[name] then
				hit("signal", name)
			end
		end
		for enumName, item in string.gmatch(c, "Enum%.([%w_]+)%.([%w_]+)") do
			if not index.enums[`{enumName}.{item}`] then
				hit("enum", `{enumName}.{item}`)
			end
		end
	end
	return hits
end

return table.freeze(UiMembers)
