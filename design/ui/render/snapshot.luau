--[[
	snapshot.luau — serialise the GUI built by REAL Luau UI code to JSON (FORGE-03 headless renderer).

		lune run design/ui/render/snapshot.luau <scenePath> <device> [outJson]

	<device>: phone | tablet | desktop (design/ui/render/devices.json, same as the HTML prototypes) or
	<width>x<height> (no device insets; same top bar). Default output:
	design/ui/render/out/<sceneName>-<device>.json. Then: node design/ui/render/render.js

	The scene runs exactly like one spec file under roblox/tests/harness/run.luau: Globals.build +
	ModuleLoader.new over the Rojo project (same root, preloaded Test/LuneInstances, Lune's require
	for "@lune/..."), MockRandom loaded first and installed as the global Random, Core/Signal's
	error reporter routed to the harness. So a scene can require("@game/ReplicatedStorage/Forge/..."),
	require("@game/StarterPlayer/StarterPlayerScripts/Forge/UI/..."), relative helpers and
	MockEnv (roblox/tests/mocks/MockEnv). The harness files are imported, never modified.

	Scene contract (design/ui/render/scenes/<name>.luau):
		return function(ctx) -> { guis: { ScreenGui }, settle: (() -> ())? }
		ctx.device     = { name, width, height, inset = { left, right, top, bottom }, topbar, controls }
		ctx.core       = { width, height }   CoreUISafeInsets area (what Layout.compute takes)
		ctx.topbarArea = { width, height }   TopbarSafeInsets area
		ctx.deviceArea = { width, height }   DeviceSafeInsets area
		ctx.root       = repository root (absolute)
	settle() (optional) runs after the scene returns and before serialisation, e.g. to advance a
	MockEnv clock so tweens/timers reach a steady state.

	Output: { tool, version, scene, scenePath, device, areas, guis, errors, warnings, modules }.
	Every GuiObject / UI modifier records ClassName, Name and its properties as plain JSON
	(UDim2 {xs,xo,ys,yo}; UDim {s,o}; Vector2 {x,y}; Color3 "#rrggbb"; EnumItem name; Font
	{family,weight,style}; ColorSequence [{t,c}]; NumberSequence [{t,v,e}]; Rect
	{minX,minY,maxX,maxY}; infinite numbers "inf"/"-inf"). Properties are read with pcall:
	what Lune cannot read is listed in `unread`; three properties Lune cannot read until they
	are set get the documented Roblox default instead and are listed in `defaulted`
	(UICorner.CornerRadius = UDim(0, 8), Image = "", ScreenGui.IgnoreGuiInset = false).
	Children keep instance order. Exit code 1 if the scene failed or a spawned thread errored
	(the JSON is still written in the second case, with `errors`).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local Globals = require("../../../roblox/tests/harness/Globals")
local LuneInstances = require("../../../roblox/tests/harness/LuneInstances")
local ModuleLoader = require("../../../roblox/tests/harness/ModuleLoader")
local Path = require("../../../roblox/tests/harness/Path")
local Test = require("../../../roblox/tests/harness/Test")

local function scriptDir(): string
	local source = string.gsub(debug.info(1, "s"), "^@", "")
	if not Path.isAbsolute(source) then
		source = Path.join(process.cwd, source)
	end
	return Path.dirname(source)
end

local RENDER_DIR = Path.normalize(scriptDir())
local ROOT = Path.normalize(RENDER_DIR .. "/../../..")
local HARNESS_DIR = ROOT .. "/roblox/tests/harness"
local TEST_MODULE = HARNESS_DIR .. "/Test.luau"
local LUNE_INSTANCES_MODULE = HARNESS_DIR .. "/LuneInstances.luau"
local MOCK_RANDOM_MODULE = ROOT .. "/roblox/tests/mocks/MockRandom.luau"
local SIGNAL_SUFFIX = "/roblox/src/shared/Core/Signal.luau"

local function fail(message: string)
	stdio.ewrite("snapshot: " .. message .. "\n")
	process.exit(1)
end

-- ---------------------------------------------------------------- arguments and device

local USAGE = "usage: lune run design/ui/render/snapshot.luau <scenePath> <phone|tablet|desktop|WxH> [outJson]"
local scenePath = process.args[1]
local deviceName = process.args[2]
if scenePath == nil or deviceName == nil then
	fail(USAGE)
end
if not Path.isAbsolute(scenePath) then
	scenePath = Path.join(process.cwd, scenePath)
end
scenePath = Path.normalize(scenePath)
if not fs.isFile(scenePath) then
	fail(`no scene file at {scenePath}`)
end
local sceneName = string.gsub(Path.basename(scenePath), "%.luau?$", "")

local devices = serde.decode("json", fs.readFile(RENDER_DIR .. "/devices.json"))
local spec = devices[deviceName]
if deviceName == "_comment" then
	spec = nil
end
if spec == nil then
	local w, h = string.match(deviceName, "^(%d+)x(%d+)$")
	if not w then
		fail(`unknown device '{deviceName}' (phone, tablet, desktop or WxH)\n{USAGE}`)
	end
	spec = {
		width = tonumber(w),
		height = tonumber(h),
		inset = { left = 0, right = 0, top = 0, bottom = 0 },
		topbar = devices.desktop.topbar,
		controls = devices.desktop.controls,
	}
end

local inset = spec.inset
local device = {
	name = deviceName,
	width = spec.width,
	height = spec.height,
	inset = { left = inset.left, right = inset.right, top = inset.top, bottom = inset.bottom },
	topbar = spec.topbar,
	controls = spec.controls,
}
local coreTop = math.max(inset.top, spec.topbar)
local ctx = {
	device = device,
	core = { width = spec.width - inset.left - inset.right, height = spec.height - coreTop - inset.bottom },
	topbarArea = {
		width = spec.width - inset.left - inset.right - spec.controls,
		height = math.max(0, spec.topbar - inset.top),
	},
	deviceArea = { width = spec.width - inset.left - inset.right, height = spec.height - inset.top - inset.bottom },
	root = ROOT,
}

local outPath = process.args[3]
if outPath == nil then
	outPath = `{RENDER_DIR}/out/{sceneName}-{deviceName}.json`
elseif not Path.isAbsolute(outPath) then
	outPath = Path.join(process.cwd, outPath)
end

-- ---------------------------------------------------------------- harness (as run.luau, one "spec file")

local display = Path.relative(ROOT, scenePath)
local threadErrors: { string } = {}
-- Errors from spawned threads (task.*, MockEnv.spawn, Signal handlers, mock signals) are reported
-- through Test.reportUnhandledError, looked up at call time; collect them here instead of a test.
Test.reportUnhandledError = function(message: string, _origin: any?)
	table.insert(threadErrors, tostring(message))
end
Test._beginFile(display) -- this thread drives MockEnv virtual time (env.wait advances at once)

local globals, _globalsControl = Globals.build({
	onUnhandledError = function(message: string, origin: any?)
		Test.reportUnhandledError(message, origin)
	end,
	captureOrigin = Test.captureOrigin,
})
-- PROJECT=<file> (relative to the repository root) renders over another Rojo project, e.g.
-- PROJECT=games/game-001/default.project.json so Config is the game's (its UITheme, Costs, ...).
local projectEnv = process.env.PROJECT
local projectFile = if projectEnv and projectEnv ~= "" then Path.join(ROOT, projectEnv) else nil
if projectFile and not fs.isFile(projectFile) then
	fail(`PROJECT={projectEnv}: no such project file`)
end
local loader = ModuleLoader.new({
	root = ROOT,
	projectFile = projectFile,
	globals = globals,
	preloaded = { [TEST_MODULE] = Test, [LUNE_INSTANCES_MODULE] = LuneInstances },
	nativeRequire = require,
})
local loadProblems: { string } = {}
loader.onLoad = function(loadedFile: string, value: any)
	if string.sub(loadedFile, -#SIGNAL_SUFFIX) == SIGNAL_SUFFIX and type(value) == "table" then
		if type(value.setErrorReporter) == "function" then
			value.setErrorReporter(function(message: string)
				Test.reportUnhandledError("Signal handler error: " .. message)
			end)
		else
			table.insert(loadProblems, "Core/Signal no longer exports setErrorReporter(fn)")
		end
	end
end
local randomOk, randomOrErr = pcall(loader.requireFile, loader, MOCK_RANDOM_MODULE)
if not randomOk then
	fail("could not load MockRandom: " .. tostring(randomOrErr))
end
globals.Random = randomOrErr

-- ---------------------------------------------------------------- run the scene

local sceneOk, sceneFn = pcall(loader.requireFile, loader, scenePath)
if not sceneOk then
	fail(`scene failed to load: {sceneFn}`)
end
if type(sceneFn) ~= "function" then
	fail(`scene {display} must return function(ctx) -> {"{"} guis = {"{"} ScreenGui {"}"} {"}"}, got {typeof(sceneFn)}`)
end
local runOk, result = xpcall(sceneFn, function(err)
	return debug.traceback(tostring(err), 2)
end, ctx)
if not runOk then
	fail(`scene errored:\n{result}`)
end
if typeof(result) == "Instance" then
	result = { guis = { result } }
elseif type(result) == "table" and result.guis == nil and #result > 0 then
	result = { guis = result }
end
if type(result) ~= "table" or type(result.guis) ~= "table" then
	fail("scene must return { guis = { ScreenGui, ... }, settle = fn? }")
end
if result.settle ~= nil then
	if type(result.settle) ~= "function" then
		fail("scene `settle` must be a function")
	end
	local settleOk, settleErr = xpcall(result.settle, function(err)
		return debug.traceback(tostring(err), 2)
	end)
	if not settleOk then
		fail(`scene settle() errored:\n{settleErr}`)
	end
end

-- ---------------------------------------------------------------- serialisation

local GUIOBJECT = {
	"Size",
	"Position",
	"AnchorPoint",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderColor3",
	"BorderMode",
	"BorderSizePixel",
	"Visible",
	"ZIndex",
	"LayoutOrder",
	"ClipsDescendants",
	"Rotation",
	"AutomaticSize",
	"SizeConstraint",
}
local TEXT = {
	"Text",
	"TextColor3",
	"TextTransparency",
	"TextSize",
	"FontFace",
	"TextXAlignment",
	"TextYAlignment",
	"TextWrapped",
	"TextScaled",
	"TextTruncate",
	"RichText",
	"LineHeight",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"MaxVisibleGraphemes",
}
local IMAGE = {
	"Image",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"SliceCenter",
	"SliceScale",
	"TileSize",
	"ImageRectOffset",
	"ImageRectSize",
	"ResampleMode",
}
local SCROLL = {
	"CanvasSize",
	"AutomaticCanvasSize",
	"ScrollingDirection",
	"ScrollBarThickness",
	"CanvasPosition",
	"ScrollBarImageColor3",
	"ScrollBarImageTransparency",
	"VerticalScrollBarInset",
	"HorizontalScrollBarInset",
	"VerticalScrollBarPosition",
	"ScrollingEnabled",
}
local LAYER = {
	"Enabled",
	"DisplayOrder",
	"ScreenInsets",
	"IgnoreGuiInset",
	"ZIndexBehavior",
	"ClipToDeviceSafeArea",
	"SafeAreaCompatibility",
}
local function concat(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #out + 1, out)
	end
	return out
end
local CLASS_PROPS: { [string]: { string } } = {
	ScreenGui = LAYER,
	Frame = GUIOBJECT,
	TextLabel = concat(GUIOBJECT, TEXT),
	TextButton = concat(GUIOBJECT, TEXT),
	TextBox = concat(GUIOBJECT, TEXT, { "PlaceholderText", "PlaceholderColor3" }),
	ImageLabel = concat(GUIOBJECT, IMAGE),
	ImageButton = concat(GUIOBJECT, IMAGE),
	ScrollingFrame = concat(GUIOBJECT, SCROLL),
	CanvasGroup = concat(GUIOBJECT, { "GroupTransparency", "GroupColor3" }),
	UICorner = { "CornerRadius" },
	UIStroke = {
		"Color",
		"Thickness",
		"Transparency",
		"ApplyStrokeMode",
		"LineJoinMode",
		"Enabled",
		"BorderStrokePosition",
		"StrokeSizingMode",
		"BorderOffset",
	},
	UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled", "Type", "Scale", "TileMode" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIListLayout = {
		"FillDirection",
		"Padding",
		"HorizontalAlignment",
		"VerticalAlignment",
		"SortOrder",
		"Wraps",
		"HorizontalFlex",
		"VerticalFlex",
		"ItemLineAlignment",
	},
	UIGridLayout = {
		"CellSize",
		"CellPadding",
		"FillDirection",
		"FillDirectionMaxCells",
		"HorizontalAlignment",
		"VerticalAlignment",
		"SortOrder",
		"StartCorner",
	},
	UIScale = { "Scale" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
	UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
	UIFlexItem = { "FlexMode", "GrowRatio", "ShrinkRatio", "ItemLineAlignment" },
}
-- Unknown classes: whatever of these is readable (pcall), without reporting the rest as unread.
local UNKNOWN_GUI = concat(GUIOBJECT, TEXT, IMAGE)
local UNKNOWN_MODIFIER = {
	"Enabled",
	"FillDirection",
	"Padding",
	"HorizontalAlignment",
	"VerticalAlignment",
	"SortOrder",
	"Animated",
	"Circular",
	"EasingStyle",
	"TweenTime",
}
-- Properties Lune 0.11 cannot read until they are set ("missing default value"): the Roblox
-- default (creator-docs / Studio) is recorded instead and the name listed in `defaulted`.
local ROBLOX_DEFAULTS: { [string]: { [string]: any } } = {
	UICorner = { CornerRadius = roblox.UDim.new(0, 8) },
	ImageLabel = { Image = "" },
	ImageButton = { Image = "" },
	ScreenGui = { IgnoreGuiInset = false },
}

local function encodeNumber(v: number): any
	if v ~= v then
		return nil
	elseif v == math.huge then
		return "inf"
	elseif v == -math.huge then
		return "-inf"
	end
	return v
end

local function encode(v: any): any
	local t = typeof(v)
	if t == "number" then
		return encodeNumber(v)
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "UDim2" then
		return { xs = v.X.Scale, xo = v.X.Offset, ys = v.Y.Scale, yo = v.Y.Offset }
	elseif t == "UDim" then
		return { s = v.Scale, o = v.Offset }
	elseif t == "Vector2" then
		return { x = encodeNumber(v.X), y = encodeNumber(v.Y) }
	elseif t == "Color3" then
		return "#" .. string.lower(v:ToHex())
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "Font" then
		return { family = v.Family, weight = v.Weight.Name, style = v.Style.Name }
	elseif t == "ColorSequence" then
		local out = {}
		for _, kp in v.Keypoints do
			table.insert(out, { t = kp.Time, c = "#" .. string.lower(kp.Value:ToHex()) })
		end
		return out
	elseif t == "NumberSequence" then
		local out = {}
		for _, kp in v.Keypoints do
			table.insert(out, { t = kp.Time, v = kp.Value, e = kp.Envelope })
		end
		return out
	elseif t == "Rect" then
		return { minX = v.Min.X, minY = v.Min.Y, maxX = v.Max.X, maxY = v.Max.Y }
	elseif t == "NumberRange" then
		return { min = v.Min, max = v.Max }
	end
	return nil
end

local function kindOf(instance: Instance): string
	if instance:IsA("LayerCollector") then
		return "layer"
	elseif instance:IsA("GuiObject") then
		return "gui"
	elseif instance:IsA("UIComponent") then
		return "modifier"
	elseif instance.ClassName == "Folder" then
		return "folder"
	end
	return "other"
end

local warnings: { string } = {}
local counts = { instances = 0 }

local function serialize(instance: Instance): { [string]: any }
	counts.instances += 1
	local className = instance.ClassName
	local kind = kindOf(instance)
	local node: { [string]: any } = { class = className, name = instance.Name, kind = kind }
	local known = CLASS_PROPS[className]
	local list = known
	if list == nil then
		list = if kind == "gui" or kind == "layer"
			then UNKNOWN_GUI
			elseif kind == "modifier" then UNKNOWN_MODIFIER
			else {}
	end
	local props = {}
	local unread, defaulted = {}, {}
	for _, prop in list do
		local ok, value = pcall(function()
			return (instance :: any)[prop]
		end)
		if ok then
			local encoded = encode(value)
			if encoded ~= nil then
				props[prop] = encoded
			elseif known then
				table.insert(unread, prop)
			end
		else
			local fallback = ROBLOX_DEFAULTS[className] and ROBLOX_DEFAULTS[className][prop]
			if fallback ~= nil then
				props[prop] = encode(fallback)
				table.insert(defaulted, prop)
			elseif known then
				table.insert(unread, prop)
			end
		end
	end
	node.props = props
	if #unread > 0 then
		node.unread = unread
	end
	if #defaulted > 0 then
		node.defaulted = defaulted
	end
	if kind ~= "other" then
		local children = {}
		for _, child in instance:GetChildren() do
			table.insert(children, serialize(child))
		end
		node.children = children
	end
	return node
end

local guis = {}
for index, gui in result.guis do
	if typeof(gui) ~= "Instance" then
		fail(`guis[{index}] is a {typeof(gui)}, expected a ScreenGui`)
	end
	if gui.ClassName ~= "ScreenGui" then
		table.insert(warnings, `guis[{index}] '{gui.Name}' is a {gui.ClassName}; only ScreenGui is placed on screen`)
	end
	table.insert(guis, serialize(gui))
end

local modules = {}
for _, file in loader:loadedFiles() do
	table.insert(modules, Path.relative(ROOT, file))
end
local errors = table.clone(threadErrors)
for _, problem in loadProblems do
	table.insert(errors, problem)
end

local snapshot = {
	tool = "forgeloop-luau-snapshot",
	version = 1,
	scene = sceneName,
	scenePath = display,
	device = device,
	areas = { core = ctx.core, topbarArea = ctx.topbarArea, deviceArea = ctx.deviceArea },
	guis = guis,
	errors = errors,
	warnings = warnings,
	modules = modules,
}

fs.writeDir(Path.dirname(outPath))
fs.writeFile(outPath, serde.encode("json", snapshot, true))
print(`snapshot {Path.relative(ROOT, outPath)}  ({#guis} gui(s), {counts.instances} instances, {#errors} error(s))`)
for _, w in warnings do
	print("  warning: " .. w)
end
for _, e in errors do
	print("  ERROR: " .. e)
end
process.exit(if #errors > 0 then 1 else 0)
