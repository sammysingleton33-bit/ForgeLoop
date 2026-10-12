--!strict
--[[
	UI/Layout — breakpoints, scale and HUD zones of the AI Kingdoms screens (interfaces §9), as pure
	maths so specs check it headlessly. It matches the FL-0059 prototype
	(games/game-001/design/ui/kingdom.js, function `layout`).

	Input is the size of the CoreUISafeInsets area (the HUD ScreenGui's AbsoluteSize: device notches
	and the Roblox top bar are already removed). Everything returned is in logical pixels; a UIScale
	of `scale` under each ScreenGui maps logical to screen pixels.

	Breakpoints (on the safe area)
		phone    height < 420 or width < 640         scale 1      compact pills, single-pane drawer
		desktop  width >= 1400 and height >= 760     scale = clamp(height / 850, 1, 1.5)
		tablet   otherwise                           scale = clamp(height / 630, 1, 1.25)

	Layout.compute(width, height) -> Metrics
		{ breakpoint, scale, width, height (logical), margin, touch,
		  hud = { x, y, crest, compact, pills = { x, y }, members = { x, y }?, bottom },
		  rail = { right, button, gap },                   right-edge menu buttons (vertical centre)
		  drawer = { x, y, width, height, single },        menu drawer (left of the rail)
		  toast = { width },                               notification stack width
		  place = { height, bottom },                      placement bar (bottom centre)
		  queue = { bottom } }                             construction chips (bottom centre)
	Layout.freeArea(metrics, drawerOpen) -> { x, width }   the part of the screen not covered by the
		rail or an open drawer: toasts, chips and the placement bar centre in it
	Layout.toastTop(metrics, drawerOpen) -> number         phone + open drawer: below the pills
]]

export type Metrics = {
	breakpoint: "phone" | "tablet" | "desktop",
	scale: number,
	width: number,
	height: number,
	margin: number,
	touch: number,
	hud: {
		x: number,
		y: number,
		crest: number,
		compact: boolean,
		pills: { x: number, y: number },
		members: { x: number, y: number }?,
		bottom: number,
	},
	rail: { right: number, button: number, gap: number },
	drawer: { x: number, y: number, width: number, height: number, single: boolean },
	toast: { width: number },
	place: { height: number, bottom: number },
	queue: { bottom: number },
}

local Layout = {}

-- Phone pill geometry (crest + 4 compact pills): the phone drawer starts right of them.
Layout.PHONE_CREST = 34
Layout.PHONE_PILL = 66
Layout.PHONE_PILL_GAP = 6
Layout.PHONE_PILLS = 4
Layout.PILL_HEIGHT = 34
Layout.MEMBERS_HEIGHT = 22

local function clamp(v: number, lo: number, hi: number): number
	return math.min(hi, math.max(lo, v))
end

function Layout.breakpoint(width: number, height: number): "phone" | "tablet" | "desktop"
	if height < 420 or width < 640 then
		return "phone"
	elseif width >= 1400 and height >= 760 then
		return "desktop"
	end
	return "tablet"
end

function Layout.compute(width: number, height: number): Metrics
	assert(width > 0 and height > 0, "Layout.compute: size must be positive")
	local bp = Layout.breakpoint(width, height)
	local scale = if bp == "desktop"
		then clamp(height / 850, 1, 1.5)
		elseif bp == "tablet" then clamp(height / 630, 1, 1.25)
		else 1
	-- Whole logical pixels: UDim2 offsets are integers in the engine (and strict in Lune).
	local W, H = math.floor(width / scale), math.floor(height / scale)
	local phone = bp == "phone"
	local margin = if phone then 8 else 16
	local railButton = if phone then 48 else 58
	local x, y = margin, if phone then 6 else margin
	local crest = if phone then Layout.PHONE_CREST else 52
	local pills = if phone then { x = x + crest + 8, y = y + 2 } else { x = x, y = y + crest + 8 }
	local members = if phone then nil else { x = x, y = pills.y + Layout.PILL_HEIGHT + 6 }
	local bottom = if members then members.y + Layout.MEMBERS_HEIGHT else y + 36
	local drawerRight = margin + railButton + 12
	local drawer
	if phone then
		local left = x
			+ Layout.PHONE_CREST
			+ 8
			+ Layout.PHONE_PILLS * Layout.PHONE_PILL
			+ (Layout.PHONE_PILLS - 1) * Layout.PHONE_PILL_GAP
			+ 12
		local w = math.max(260, W - drawerRight - left)
		drawer = { x = W - drawerRight - w, y = y, width = w, height = H - y - margin, single = true }
	else
		local w = if bp == "tablet" then 560 else 620
		local maxH = if bp == "tablet" then 470 else 480
		local top = bottom + 10
		drawer =
			{ x = W - drawerRight - w, y = top, width = w, height = math.min(maxH, H - top - margin), single = false }
	end
	return {
		breakpoint = bp,
		scale = scale,
		width = W,
		height = H,
		margin = margin,
		touch = 44,
		hud = { x = x, y = y, crest = crest, compact = phone, pills = pills, members = members, bottom = bottom },
		rail = { right = margin, button = railButton, gap = 10 },
		drawer = drawer,
		toast = { width = if phone then 250 else 300 },
		place = { height = if phone then 52 else 60, bottom = margin },
		queue = { bottom = margin },
	}
end

function Layout.freeArea(m: Metrics, drawerOpen: boolean): { x: number, width: number }
	if drawerOpen then
		return { x = 0, width = math.floor(m.drawer.x) }
	end
	return { x = 0, width = m.width - m.rail.right - m.rail.button }
end

function Layout.toastTop(m: Metrics, drawerOpen: boolean): number
	if drawerOpen and m.breakpoint == "phone" then
		return m.hud.bottom + 8
	end
	return m.hud.y
end

return table.freeze(Layout)
