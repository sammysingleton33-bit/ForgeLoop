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

	Layout.compute(width, height, { reputation: boolean?, support: boolean? }?) -> Metrics
		reputation = false: the strip is hidden (no reputation from the server yet), so `bottom` and
		everything placed under it ignore its room; omitted means shown
		support = true: the support meter chip sits under the strip (hud.support = { x, y, width, height }) and
		`bottom` under it; omitted means none (FL-0073: dark until Kingdom.Support is served)
		{ breakpoint, scale, width, height (logical), margin, touch,
		  hud = { x, y, crest, compact, pills = { x, y }, members = { x, y }?,
		          reputation = { x, y, width, height, columns, item = { width, height }, gap = { x, y }, pad },
		          bottom,                                  bottom of the whole top-left stack
		          objectives = { x, y, width, maxHeight } },   objective tracker under the stack (FL-0060)
		  rail = { right, button, gap },                   right-edge menu buttons (vertical centre)
		  drawer = { x, y, width, height, single },        menu drawer (left of the rail)
		  toast = { width },                               notification stack width
		  place = { height, bottom },                      placement bar (bottom centre)
		  queue = { bottom } }                             construction chips (bottom centre)
	Layout.freeArea(metrics, drawerOpen) -> { x, width }   the part of the screen not covered by the
		rail or an open drawer: toasts, chips and the placement bar centre in it
	Layout.toastTop(metrics, drawerOpen, stackBottom?) -> number   phone + open drawer: below the
		pills and the reputation strip, or below `stackBottom` (the objective tracker's bottom edge
		while it shows: hud:setStackBottom)
	Layout.sheetToast(metrics) -> { right, y, width }      phone + a wide sheet open (the
		conversation, which starts just below the pills): toasts go in the band right of the pills,
		above the sheet, right-aligned with the sheet's right edge (the drawer's)

	Reputation strip (FL-0089, UI/ReputationStrip; prototype games/game-001/design/ui/reputation.js):
		phone           one row of six (icon + number + bar) under the crest, clear of its Crown
		                Points badge (y + crest + 8) and left of the phone drawer
		tablet/desktop  three columns by two rows (icon + name + number + bar) under the rulers
	It is part of the top-left stack, so `hud.bottom` (and with it the tablet/desktop drawer top and
	the phone toast top) sits below it.

	Objective tracker (FL-0060, UI/ObjectiveTracker; prototype games/game-001/design/ui/army.js):
		under the top-left stack, at most 224 px wide on phones and 272 px on tablet/desktop, and 12 px
		clear of the drawer (tablets: 261 px). It is NOT part of `hud.bottom`, so drawers keep their
		size; its height follows the capture state, so the phone toast top follows it through
		`toastTop(m, drawerOpen, stackBottom)`.
		`maxHeight` keeps it clear of the construction chips at the bottom.
]]

export type Strip = {
	x: number,
	y: number,
	width: number,
	height: number,
	columns: number,
	item: { width: number, height: number },
	gap: { x: number, y: number },
	pad: number,
}

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
		reputation: Strip,
		bottom: number,
		objectives: { x: number, y: number, width: number, maxHeight: number },
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
-- Reputation strip (FL-0089): six items; phones one row, tablet/desktop three columns.
Layout.REPUTATION_ITEMS = 6
Layout.REPUTATION_ITEM_HEIGHT = 22
-- Support meter (FL-0073): one chip under the reputation strip.
Layout.SUPPORT_HEIGHT = 30
Layout.SUPPORT_HEIGHT_PHONE = 26
Layout.SUPPORT_WIDTH = 220
Layout.SUPPORT_WIDTH_PHONE = 150
-- Objective tracker (FL-0060): width per breakpoint; it keeps clear of the bottom chips (36 px + gap).
Layout.OBJECTIVES_WIDTH_PHONE = 224
Layout.OBJECTIVES_WIDTH = 272
Layout.CHIPS_CLEARANCE = 44
-- Narrow phones (667 × 375; release checklist L7): when one pill row would leave the drawer narrower than this, the
-- pills wrap to two rows and the reputation strip to three columns, so the drawer starts right of a narrower stack.
Layout.PHONE_DRAWER_MIN = 300
-- Phone toasts above a wide sheet: wider than the usual 250 px so titles wrap less (one fits).
Layout.SHEET_TOAST_WIDTH = 330

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

-- The strip's box at (x, top): phones one row of 6 items (50 px, narrower — down to 44 — when
-- `maxWidth` is less, so it stays left of the phone drawer), tablet/desktop 3 × 2 items of 118 px.
function Layout.reputationStrip(phone: boolean, x: number, top: number, maxWidth: number?, columns_: number?): Strip
	local columns = columns_ or (if phone then Layout.REPUTATION_ITEMS else 3)
	local rows = math.ceil(Layout.REPUTATION_ITEMS / columns)
	local gap = if phone then { x = 3, y = 3 } else { x = 8, y = 6 }
	local pad = if phone then 4 else 6
	local itemWidth = 118
	if phone then
		local fit = math.floor(((maxWidth or math.huge) - 2 * pad - (columns - 1) * gap.x) / columns)
		itemWidth = math.clamp(fit, 44, 50)
	end
	local item = { width = itemWidth, height = Layout.REPUTATION_ITEM_HEIGHT }
	return {
		x = x,
		y = top,
		width = columns * item.width + (columns - 1) * gap.x + 2 * pad,
		height = rows * item.height + (rows - 1) * gap.y + 2 * pad,
		columns = columns,
		item = item,
		gap = gap,
		pad = pad,
	}
end

function Layout.compute(width: number, height: number, options: { reputation: boolean?, support: boolean? }?): Metrics
	assert(width > 0 and height > 0, "Layout.compute: size must be positive")
	-- The strip's room is reserved only while it shows (it is hidden until the server sends
	-- reputation): otherwise tablet/desktop drawers and phone toasts would sit under an empty gap.
	local strip = options == nil or options.reputation ~= false
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
	local pills: any = if phone
		then { x = x + crest + 8, y = y + 2, columns = Layout.PHONE_PILLS }
		else { x = x, y = y + crest + 8 }
	local members = if phone then nil else { x = x, y = pills.y + Layout.PILL_HEIGHT + 6 }
	local drawerRight = margin + railButton + 12
	local drawer, reputation
	if phone then
		local function leftOf(columns: number): number
			return x + Layout.PHONE_CREST + 8 + columns * Layout.PHONE_PILL + (columns - 1) * Layout.PHONE_PILL_GAP + 12
		end
		local narrow = W - drawerRight - leftOf(Layout.PHONE_PILLS) < Layout.PHONE_DRAWER_MIN
		pills.columns = if narrow then 2 else Layout.PHONE_PILLS
		pills.rows = math.ceil(Layout.PHONE_PILLS / pills.columns)
		pills.height = pills.rows * Layout.PILL_HEIGHT + (pills.rows - 1) * Layout.PHONE_PILL_GAP
		-- a narrow phone keeps the objective tracker at its usual width beside the drawer (its names need it)
		local left = if narrow
			then math.max(leftOf(pills.columns), x + Layout.OBJECTIVES_WIDTH_PHONE + 12)
			else leftOf(pills.columns)
		local w = math.max(260, W - drawerRight - left)
		drawer = { x = W - drawerRight - w, y = y, width = w, height = H - y - margin, single = true }
		local stripTop = math.max(y + crest + 12, pills.y + pills.height + 8)
		reputation = Layout.reputationStrip(true, x, stripTop, drawer.x - x - margin, if narrow then 3 else nil)
	else
		reputation = Layout.reputationStrip(false, x, (members :: any).y + Layout.MEMBERS_HEIGHT + 6)
	end
	local bottom = if strip
		then reputation.y + reputation.height
		elseif members then members.y + Layout.MEMBERS_HEIGHT
		elseif phone then math.max(y + 36, pills.y + pills.height)
		else y + 36
	-- The support meter (FL-0073, SupportMeterController): one chip under the stack while the server sends a
	-- SupportView (dark until Kingdom.Support is served); `bottom` moves under it only then.
	local support = nil
	if options ~= nil and options.support == true then
		local h = if phone then Layout.SUPPORT_HEIGHT_PHONE else Layout.SUPPORT_HEIGHT
		local w = if phone then Layout.SUPPORT_WIDTH_PHONE else Layout.SUPPORT_WIDTH
		support = { x = x, y = bottom + 6, width = w, height = h }
		bottom = support.y + h
	end
	if not phone then
		local w = if bp == "tablet" then 560 else 620
		local maxH = if bp == "tablet" then 470 else 480
		local top = bottom + 10
		drawer =
			{ x = W - drawerRight - w, y = top, width = w, height = math.min(maxH, H - top - margin), single = false }
	end
	-- The tracker keeps 12 px clear of the drawer (tablet: the drawer starts at x = 289).
	local objectivesY = bottom + (if phone then 8 else 10)
	local objectives = {
		x = x,
		y = objectivesY,
		width = math.max(
			160,
			math.min(if phone then Layout.OBJECTIVES_WIDTH_PHONE else Layout.OBJECTIVES_WIDTH, drawer.x - x - 12)
		),
		maxHeight = math.max(44, H - objectivesY - margin - Layout.CHIPS_CLEARANCE),
	}
	return {
		breakpoint = bp,
		scale = scale,
		width = W,
		height = H,
		margin = margin,
		touch = 44,
		hud = {
			x = x,
			y = y,
			crest = crest,
			compact = phone,
			pills = pills,
			members = members,
			reputation = reputation,
			support = support,
			bottom = bottom,
			objectives = objectives,
		},
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

function Layout.sheetToast(m: Metrics): { right: number, y: number, width: number }
	local pillsRight = m.hud.pills.x
		+ Layout.PHONE_PILLS * Layout.PHONE_PILL
		+ (Layout.PHONE_PILLS - 1) * Layout.PHONE_PILL_GAP
	local right = m.drawer.x + m.drawer.width
	-- At the top of the safe area: a toast with a title and one line of body (48 px) ends 2 px above
	-- the sheet.
	return { right = right, y = 0, width = math.min(Layout.SHEET_TOAST_WIDTH, right - pillsRight - 8) }
end

function Layout.toastTop(m: Metrics, drawerOpen: boolean, stackBottom: number?): number
	if drawerOpen and m.breakpoint == "phone" then
		return math.max(m.hud.bottom, stackBottom or 0) + 8
	end
	return m.hud.y
end

return table.freeze(Layout)
