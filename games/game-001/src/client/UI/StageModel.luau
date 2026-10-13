--!strict
--[[
	UI/StageModel — pure geometry of the cinematic conversation (CONTRACTS G13.8, FL-0099;
	UI/ConversationStage draws it). No instances, so specs check it headlessly.

	The stage sits at the bottom of the screen, centred in the space left of the rail, so the world
	(and the citizen the camera frames above the centre, FORGE-04 #84) stays visible:
		portrait  a square at the stage's bottom left, the citizen's name plate inside its lower edge
		column    right of the portrait: the speech bubble (its tail points left at the portrait) with
		          the close button at its right, then the answers (two columns when they fit, else
		          one), the confirm step, or the reaction and its consequence chips, and a footer
		dim       a band from DIM_FADE above the stage to the bottom edge, at most DIM_OPACITY dark
		          (the contract allows 20 %); nothing else covers the world
	The stage never rises above the top-left HUD stack (`hud.bottom`) and never reaches the rail.

		StageModel.rects(metrics) -> Rects
			{ breakpoint, phone, x, width, bottom, maxHeight, portrait (side), gap, tail, close,
			  column = { x, width }, body = { x, width } (the scrolling body: the column plus the
			  tail's room on its left), columns (1 | 2), answerWidth, bubbleWidth, dim = { y } }
		StageModel.height(state, rects, balances?) -> number
			the stage height: the taller of the portrait and the estimated column, at most
			rects.maxHeight (the body scrolls when the estimate falls short)
		StageModel.columnHeight(state, rects, balances?) -> number   the unbounded column estimate
		StageModel.overflows(state, rects, balances?) -> boolean      the column will scroll
		StageModel.answerHeight(option, width, balances?, phone) -> number
		StageModel.showsBubble(state, phone) -> boolean   the confirm step on phones hides the question
		StageModel.hasHead(state, phone) -> boolean       the column starts with a head row beside the
			close button (when the first thing is not a bubble)
		StageModel.readSeconds(outcome) -> number         how long the answered stage stays before it
			closes by itself: READ_BASE + READ_PER_CHAR per character of the reaction and the chips,
			between READ_MIN and READ_MAX

	state = ConversationController.state ({ phase, conversation, picked?, outcome?, error? }).
	Text widths use UI/CitizenModel's average glyph widths and greedy word wrap.
]]

local CitizenModel = require("./CitizenModel")

local StageModel = {}

StageModel.GEO = table.freeze({
	maxWidth = 920,
	portrait = table.freeze({ phone = 112, tablet = 172, desktop = 196 }),
	gap = table.freeze({ phone = 8, tablet = 14, desktop = 16 }), -- portrait to column
	railGap = table.freeze({ phone = 6, tablet = 12, desktop = 12 }),
	close = table.freeze({ phone = 36, tablet = 32, desktop = 32 }),
	closeGap = 6,
	tail = 10, -- the bubble's tail reaches this far left of the column
	bubblePad = table.freeze({ phone = 8, tablet = 12, desktop = 12 }),
	bubbleLine = table.freeze({ phone = 18, tablet = 21, desktop = 21 }),
	bubbleText = table.freeze({ phone = 13, tablet = 15, desktop = 15 }),
	gap6 = 6,
	kicker = 14,
	answerMin = table.freeze({ phone = 44, tablet = 48, desktop = 48 }),
	answerColumnMin = 240, -- below this an answer column gets one answer per row
	answerPadY = 8,
	answerChrome = 54, -- 8 left + 24 number + 10 gap + 12 right
	answerLine = 17,
	chipRow = 18,
	chipGap = 4,
	chipIcon = 14,
	answerGap = 6,
	footer = 52, -- a 44 px button + 8 px gap
	errorLine = 22,
	nameplate = table.freeze({ phone = 30, tablet = 40, desktop = 42 }),
	hudGap = 6,
	slack = 4,
	dimFade = 48,
	dimOpacity = 0.18,
	rise = 0.35,
})

StageModel.READ_BASE = 4
StageModel.READ_PER_CHAR = 0.045
StageModel.READ_MIN = 6
StageModel.READ_MAX = 12

-- Average glyph widths (px) of the stage's text: the bubble is Merriweather 15 / 13 (phone), the
-- answers Montserrat Bold 13, the chips Bold 11; scaled from UI/CitizenModel.CHAR's measurements.
StageModel.CHAR = table.freeze({
	bubble = 7.4,
	phoneBubble = 6.6,
	answer = CitizenModel.CHAR.option,
	chip = 6.0,
	body = CitizenModel.CHAR.body,
})

export type Rects = {
	breakpoint: string,
	phone: boolean,
	x: number,
	width: number,
	bottom: number,
	maxHeight: number,
	portrait: number,
	gap: number,
	tail: number,
	close: number,
	column: { x: number, width: number },
	body: { x: number, width: number },
	columns: number,
	answerWidth: number,
	bubbleWidth: number,
	dim: { y: number },
}

function StageModel.rects(m: any): Rects
	local G = StageModel.GEO
	local bp = m.breakpoint
	local phone = bp == "phone"
	local railLeft = m.width - m.rail.right - m.rail.button
	local left = m.margin
	local right = railLeft - G.railGap[bp]
	local width = math.min(G.maxWidth, right - left)
	local x = left + math.floor((right - left - width) / 2)
	local portrait = G.portrait[bp]
	local gap = G.gap[bp]
	local columnX = x + portrait + gap + G.tail
	local columnW = x + width - columnX
	local columns = if columnW >= 2 * G.answerColumnMin + G.answerGap then 2 else 1
	local bottom = m.height - m.margin
	local top = m.hud.bottom + G.hudGap
	local close = G.close[bp]
	return {
		breakpoint = bp,
		phone = phone,
		x = x,
		width = width,
		bottom = bottom,
		maxHeight = bottom - top,
		portrait = portrait,
		gap = gap,
		tail = G.tail,
		close = close,
		column = { x = columnX, width = columnW },
		body = { x = columnX - G.tail, width = columnW + G.tail },
		columns = columns,
		answerWidth = if columns == 2 then math.floor((columnW - G.answerGap) / 2) else columnW,
		bubbleWidth = columnW - close - G.closeGap,
		dim = { y = 0 }, -- set by height(): DIM_FADE above the stage's top
	}
end

-- Wraps chips of the given widths into rows `width` wide; returns the number of rows.
local function chipRows(widths: { number }, width: number, gap: number): number
	local rows, used = 1, 0
	for _, w in widths do
		if used > 0 and used + gap + w > width then
			rows += 1
			used = w
		else
			used += (if used > 0 then gap else 0) + w
		end
	end
	return rows
end

-- The chips under an answer: one per cost entry, "Need ..." when the treasury is short, one per risk
-- ("30 %") and "+N" for risks without text.
local function answerChipWidths(o: any, balances: { [string]: number }?): { number }
	local G = StageModel.GEO
	local K = StageModel.CHAR
	local out = {}
	for _, c in o.cost do
		table.insert(out, G.chipIcon + 2 + #tostring(c.amount) * CitizenModel.CHAR.cost)
	end
	local need = CitizenModel.price(o, balances).need
	if need then
		table.insert(out, (utf8.len(need) or #need) * CitizenModel.CHAR.need)
	end
	for _, r in o.risks do
		table.insert(out, 10 + G.chipIcon + 3 + (utf8.len(r.label) or #r.label) * K.chip)
	end
	if o.hiddenRisks > 0 then
		table.insert(out, 10 + G.chipIcon + 3 + 3 * K.chip)
	end
	return out
end

function StageModel.answerHeight(o: any, width: number, balances: { [string]: number }?, phone: boolean): number
	local G = StageModel.GEO
	local text = width - G.answerChrome
	local h = CitizenModel.lines(o.text, text, StageModel.CHAR.answer) * G.answerLine + 2 * G.answerPadY
	local chips = answerChipWidths(o, balances)
	if #chips > 0 then
		local rows = chipRows(chips, text, G.chipGap)
		h += G.chipGap + rows * G.chipRow + (rows - 1) * G.chipGap
	else
		h += 4 -- slack for a wrapped answer
	end
	return math.max(G.answerMin[if phone then "phone" else "tablet"], h)
end

-- The picked answer in the confirm step: the panel's full card (cost row and every risk line).
local function confirmHeight(o: any, width: number, balances: { [string]: number }?): number
	local C = CitizenModel.CONVO
	local column = width - C.optionChrome
	local n = CitizenModel.lines(o.text, column, CitizenModel.CHAR.option)
	return math.max(C.optionMin, n * C.optionLine + CitizenModel.optionMeta(o, column, balances) + 2 * C.optionPadY)
end

-- A head row (as tall as the close button, beside it) starts the column when the first thing is
-- not a speech bubble: the "You: ..." echo of an answer (tablet/desktop), the confirm step's kicker
-- on phones, or nothing (an answer without a reaction, a refusal on phones).
function StageModel.hasHead(state: any, phone: boolean): boolean
	if state.phase == "answered" then
		return (not phone and state.picked ~= nil) or not StageModel.showsBubble(state, phone)
	end
	return not StageModel.showsBubble(state, phone)
end

function StageModel.showsBubble(state: any, phone: boolean): boolean
	if state.phase == "confirming" then
		return not phone
	end
	if state.phase == "answered" then
		return state.outcome ~= nil and state.outcome.reaction ~= nil
	end
	if state.phase == "refused" then
		return not phone
	end
	return true
end

local function bubbleHeight(s: string, r: Rects): number
	local G = StageModel.GEO
	local bp = r.breakpoint
	local pad = G.bubblePad[bp]
	local char = if r.phone then StageModel.CHAR.phoneBubble else StageModel.CHAR.bubble
	return CitizenModel.lines(s, r.bubbleWidth - 2 * pad - 4, char) * G.bubbleLine[bp] + 2 * pad
end

function StageModel.columnHeight(state: any, r: Rects, balances: { [string]: number }?): number
	local G = StageModel.GEO
	local convo = state.conversation
	local outcome = state.outcome
	local h = 0
	local function add(n: number)
		h += (if h > 0 then G.gap6 else 0) + n
	end
	local finished = (state.phase == "answered" or state.phase == "refused") and outcome ~= nil
	-- The first row leaves room for the close button: the bubble (bubbleWidth), else a head row
	-- as tall as the button (StageModel.hasHead).
	if StageModel.hasHead(state, r.phone) then
		add(r.close)
	end
	if finished and state.phase == "answered" then
		if outcome.reaction then
			add(bubbleHeight(outcome.reaction, r))
		end
		if #outcome.effects > 0 then
			local widths = {}
			for _, e in outcome.effects do
				table.insert(
					widths,
					CitizenModel.CONVO.chipChrome + (utf8.len(e.text) or #e.text) * CitizenModel.CHAR.chip
				)
			end
			local rows = chipRows(widths, r.column.width, CitizenModel.CONVO.chipGap)
			local chip = if r.phone then CitizenModel.CONVO.phoneChip else CitizenModel.CONVO.chip
			if not r.phone then
				add(G.kicker)
			end
			add(rows * chip + (rows - 1) * CitizenModel.CONVO.chipGap)
		end
		add(G.footer)
	elseif finished then
		if StageModel.showsBubble(state, r.phone) then
			add(bubbleHeight(convo.question, r))
		end
		add(CitizenModel.lines(outcome.message, r.column.width - 50, StageModel.CHAR.body) * 18 + 20)
		add(G.footer)
	elseif state.phase == "confirming" then
		if StageModel.showsBubble(state, r.phone) then
			add(bubbleHeight(convo.question, r))
			add(G.kicker)
		end
		for _, o in convo.options do
			if o.id == state.picked then
				add(confirmHeight(o, r.column.width, balances))
			end
		end
		add(G.footer)
	else
		add(bubbleHeight(convo.question, r))
		if not r.phone then
			add(G.kicker)
		end
		local options = convo.options
		local rows = 0
		for i = 1, #options, r.columns do
			local tallest = 0
			for j = i, math.min(i + r.columns - 1, #options) do
				tallest = math.max(tallest, StageModel.answerHeight(options[j], r.answerWidth, balances, r.phone))
			end
			rows += tallest + (if i > 1 then G.answerGap else 0)
		end
		add(rows)
		if state.error then
			add(G.errorLine)
		end
	end
	-- + slack: the body's 1 px bottom padding and rounding at UI scales (an exact fit showed a
	-- scroll bar on tablets)
	return math.ceil(h + G.slack)
end

function StageModel.height(state: any, r: Rects, balances: { [string]: number }?): number
	local column = StageModel.columnHeight(state, r, balances)
	return math.floor(math.min(r.maxHeight, math.max(r.portrait, column)))
end

function StageModel.overflows(state: any, r: Rects, balances: { [string]: number }?): boolean
	return StageModel.columnHeight(state, r, balances) > r.maxHeight
end

function StageModel.readSeconds(outcome: any): number
	local chars = 0
	if outcome and type(outcome.reaction) == "string" then
		chars += utf8.len(outcome.reaction) or #outcome.reaction
	end
	if outcome and type(outcome.effects) == "table" then
		for _, e in outcome.effects do
			chars += utf8.len(e.text) or #e.text
		end
	end
	return math.clamp(StageModel.READ_BASE + chars * StageModel.READ_PER_CHAR, StageModel.READ_MIN, StageModel.READ_MAX)
end

return table.freeze(StageModel)
