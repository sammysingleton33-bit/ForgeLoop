--!strict
--[[
	UI/CitizenModel — pure view models for the citizen card (CitizenView, CONTRACTS G13.2) and the
	conversation panel (Kingdom.Converse / Kingdom.Choose, G13.3), plus the panel geometry. No
	instances, so specs check it headlessly. Prototype: games/game-001/design/ui/citizen.js.

	Server text is passed through untouched: names, occupation, traits, intent, memories, relations,
	the question, the answers, the reaction and every effect text. The only words made here are UI
	labels (Talk, Ask, Loyalty, Family, ...) and the mood band.

		CitizenModel.card(view) -> Card?                 nil when the view has no name (not a citizen)
		CitizenModel.conversation(payload, fallback?) -> Conversation?
			nil when the payload is nil or has no question, no scenarioId or no valid option;
			options keep the payload's order; duplicates and options without id or text are dropped;
			at most OPTION_LIMIT (the contract says 2-4).
			fallback = { name, occupation } names the speaker when the payload has no `speaker`.
			Option = { id, text, index, cost: { { id, amount, name, icon } }, risks: { Risk },
			hiddenRisks: number } from the payload's optional `cost` (ResourceBag) and `risks`
			({ { text, chance } }, ContentQuery.choicePreview, G13.3). Loose: cost entries that are
			not a known resource with a whole amount > 0 are ignored; a risk needs a text (`notice`
			is accepted for it); a chance outside 0..1 shows as "?" instead of hiding the risk. At most
			RISK_LIMIT risks are listed; `hiddenRisks` counts the rest ("+N more risks").
			Risk = { text, chance: number?, percent: number?, label ("30 %", UI/CitizenText.chance) }
		CitizenModel.price(option, balances?) -> { short: { [id]: true }, need: string? }
			which cost entries the treasury cannot cover and the reason ("Need 20 Wood", UI/Text.missing,
			the build menu's words); nothing is short while the treasury is unknown (balances nil)
		CitizenModel.key(entityId, scenarioId) -> string   one showing of a scenario (Choose is
			idempotent per showing on the server)
		CitizenModel.effect(e) -> Effect?                { kind, text, icon, tint, tone }
		CitizenModel.outcome(called, ok, result, reason) -> Outcome
			{ phase = "answered", reaction?, effects }  ok == true (at most EFFECT_LIMIT effects)
			{ phase = "refused", message, code? }        ok == false (or any other non-nil value)
			{ phase = "failed", message }               the call errored or the server dropped it (nil)
		CitizenModel.moodBand(mood) -> string
		CitizenModel.cardRect(metrics), CitizenModel.conversationRect(metrics) -> { x, y, width, height }
		CitizenModel.conversationHeight(state, rect, phone, balances?) -> number   a fitted panel height
		CitizenModel.conversationOverflows(state, rect, phone, balances?) -> boolean the body will scroll
		CitizenModel.lines(text, width, charWidth) -> number            greedy word wrap estimate

	Geometry (logical px, UI/Layout metrics):
		card          the drawer; on tablet and desktop at most CARD_HEIGHT tall (the content is short)
		conversation  tablet/desktop: the drawer's place; phone: from the left margin to the drawer's
		              right edge, just below the resource pills and the crest's Crown Points badge (the
		              pills and their spend badge stay visible, the reputation strip is covered whole),
		              left of the rail. Its height is fitted to the text (average glyph widths, greedy
		              word wrap); the body scrolls when the estimate falls short.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local CitizenText = require("./CitizenText")
local Layout = require("./Layout")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Text = require("./Text")

local CitizenModel = {}

CitizenModel.CARD_HEIGHT = 376
CitizenModel.CROWN_BADGE = 8 -- the crest's Crown Points badge hangs this far below the crest (UI/Crest)
CitizenModel.MEMORY_LIMIT = 8
CitizenModel.TRAIT_LIMIT = 6
-- Caps against a malformed or abusive payload (FORGE-05 L2): the contract says 2-4 answers; content
-- has at most 2 risks per answer today (handoff: keep it <= 3); effect chips wrap in rows.
CitizenModel.OPTION_LIMIT = 4
CitizenModel.RISK_LIMIT = 4
CitizenModel.EFFECT_LIMIT = 8

CitizenModel.JOBS = table.freeze({
	idle = "Idle",
	farmer = "Farmer",
	woodcutter = "Woodcutter",
	miner = "Miner",
	builder = "Builder",
	hauler = "Hauler",
	soldier = "Soldier",
})

CitizenModel.JOB_ICONS = table.freeze({
	idle = "house",
	farmer = "farm",
	woodcutter = "lumbercamp",
	miner = "quarry",
	builder = "build",
	hauler = "storehouse",
	soldier = "barracks",
})

-- Effect `kind` → icon and tint (a Theme colour name, or "resource:<id>"). The proposed vocabulary
-- is in the FORGE-01 handoff; an unknown kind gets the neutral chip. The chip text is the server's.
local REPUTATION = table.freeze({ icon = "laurel", tint = "vert" })
CitizenModel.EFFECTS = table.freeze({
	food = table.freeze({ icon = "food", tint = "resource:food" }),
	wood = table.freeze({ icon = "wood", tint = "resource:wood" }),
	stone = table.freeze({ icon = "stone", tint = "resource:stone" }),
	gold = table.freeze({ icon = "gold", tint = "resource:gold" }),
	loyalty = table.freeze({ icon = "heart", tint = "gules" }),
	reputation = REPUTATION,
	compassion = REPUTATION,
	honor = REPUTATION,
	competence = REPUTATION,
	courage = REPUTATION,
	authority = REPUTATION,
	fear = REPUTATION,
	happiness = table.freeze({ icon = "mood", tint = "gold400" }),
	stability = table.freeze({ icon = "keep", tint = "azure" }),
	morale = table.freeze({ icon = "banner", tint = "amber" }),
	work = table.freeze({ icon = "build", tint = "gold500" }),
	memory = table.freeze({ icon = "scroll", tint = "parchment300" }),
	consequence = table.freeze({ icon = "warning", tint = "amber" }),
})
CitizenModel.NEUTRAL_EFFECT = table.freeze({ icon = "info", tint = "ink500" })

-- Layout numbers shared by the views and the height estimate (logical px).
CitizenModel.CONVO = table.freeze({
	pad = 12,
	phonePad = 10,
	header = 46, -- kit Panel without a title: 38 px header row + 8 px gap
	canvasTop = 2, -- top padding of the scrolling body
	tail = 8, -- a speech box sits 8 px down in its holder: room for its tail
	scrollGutter = 6, -- right padding of the scrolling body (scroll bar)
	gap = 6,
	kicker = 14,
	speechPad = 10,
	phoneSpeechPad = 8,
	speechLine = 20,
	phoneSpeechLine = 18,
	optionMin = 44,
	optionPadY = 8,
	optionChrome = 58, -- 8 left + 24 number + 10 gap + 12 right + slack
	optionLine = 17,
	optionGap = 8,
	gridGap = 6,
	chip = 28,
	phoneChip = 24,
	chipGap = 6,
	chipChrome = 38, -- 4 + 20 icon + 4 + 10 padding
	footer = 52, -- 44 px button + 8 px gap
	errorLine = 22,
	-- What an answer costs and risks, under its text (UI/ConversationPanel).
	metaGap = 4, -- between the text, the cost row and each risk line
	costRow = 16, -- resource chips (16 px icon + amount) and "Need ..."
	costIcon = 16,
	costGap = 6,
	riskLine = 14, -- one line of risk text (11 px, LineHeight 1.15)
	riskIcon = 14,
	riskChance = 38, -- "30 %" column (">99 %" measures 34 px in the renderer; room for Studio)
	riskIndent = 58, -- 14 icon + 4 + 38 chance + 2: where the risk text starts
})

-- Average glyph widths (px) at the sizes the panel uses: Merriweather 14 / 13 (question, phone),
-- Montserrat Bold 13 (answers), Montserrat 12 (body), Montserrat Bold 12 (chips). Measured on the
-- headless renders: question at 14 px ≈ 6.6, answers ≈ 6.9-7.0, chips at 11 px ≈ 5.4; the others
-- are scaled from those. Each carries a little slack: a short estimate means a scroll.
-- Risk text is Montserrat SemiBold 11 (measured 5.5-5.6 in the renderer page), cost amounts and
-- "Need ..." Bold 12 / 11 (7.1-7.6 per digit, 6.3).
CitizenModel.CHAR = table.freeze({
	question = 7.0,
	phoneQuestion = 6.6,
	option = 7.1,
	body = 6.9,
	chip = 6.4,
	risk = 5.9,
	cost = 7.4,
	need = 6.6,
})

-- Line spacing of wrapped text (TextLabel.LineHeight): Merriweather's tall ascenders need air.
CitizenModel.SPEECH_LINE_HEIGHT = 1.25
CitizenModel.LINE_HEIGHT = 1.15

local function clampPercent(n: any): number?
	if type(n) ~= "number" or n ~= n then
		return nil
	end
	return math.clamp(math.floor(n + 0.5), 0, 100)
end

local function strings(list: any, limit: number?): { string }
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, s in ipairs(list) do
		if type(s) == "string" and s ~= "" then
			table.insert(out, s)
			if limit and #out >= limit then
				break
			end
		end
	end
	return out
end

local function text(s: any): string?
	return if type(s) == "string" and s ~= "" then s else nil
end

-- The first character of a name, upper-cased. Server text may be invalid UTF-8 (utf8.offset then
-- throws, FORGE-05 L1): fall back to its first ASCII letter or digit, else "?".
local function initial(name: string): string
	if utf8.len(name) == nil then
		local ascii = string.match(name, "%w")
		return if ascii then string.upper(ascii) else "?"
	end
	local stop = utf8.offset(name, 2)
	local first = if stop then string.sub(name, 1, stop - 1) else name
	return string.upper(first)
end

-- A ResourceBag from the payload as display entries in resource order. Loose: anything that is not
-- a known resource id with a whole amount > 0 is ignored (the treasury could not spend it either).
local function costEntries(raw: any): { any }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	local bag = {}
	for id, amount in raw do
		if type(id) == "string" and Resources.defs[id] ~= nil and Bundle.isAmount(amount) then
			bag[id] = amount
		end
	end
	for _, entry in Bundle.ordered(bag, Resources.ids) do
		local def = Resources.defs[entry.id]
		table.insert(out, { id = entry.id, amount = entry.amount, name = def.name, icon = def.icon })
	end
	return out
end

-- Risks keep the payload's order. A risk without text has nothing to show and is ignored; one with a
-- bad chance is still shown (label "?"): the rule is that every risk is visible before choosing.
local function riskEntries(raw: any): ({ any }, number)
	local out, hidden = {}, 0
	if type(raw) ~= "table" then
		return out, 0
	end
	for _, r in ipairs(raw) do
		if type(r) == "table" then
			local label = text(r.text) or text(r.notice)
			if label then
				if #out >= CitizenModel.RISK_LIMIT then
					hidden += 1
				else
					local c = r.chance
					local chance = if type(c) == "number" and c == c and c >= 0 and c <= 1 then c else nil
					table.insert(out, {
						text = label,
						chance = chance,
						percent = if chance then math.floor(chance * 100 + 0.5) else nil,
						label = CitizenText.chance(chance),
					})
				end
			end
		end
	end
	return out, hidden
end

function CitizenModel.moodBand(mood: number): string
	if mood < 20 then
		return "Miserable"
	elseif mood < 40 then
		return "Unhappy"
	elseif mood < 60 then
		return "Calm"
	elseif mood < 80 then
		return "Content"
	end
	return "Joyful"
end

function CitizenModel.card(view: any): any
	if type(view) ~= "table" then
		return nil
	end
	local name = text(view.name)
	if name == nil then
		return nil
	end
	local job = text(view.job)
	local jobLabel = if job then CitizenModel.JOBS[job] else nil
	local occupation = text(view.occupation) or jobLabel or "Citizen"
	local sub = occupation
	if jobLabel and string.lower(occupation) ~= job then
		sub = `{occupation} · {jobLabel}`
	end
	-- A G5-only view (before G13.2) has mood but no loyalty, obedience or traits: rows are left out.
	local stats = {}
	local loyalty = clampPercent(view.loyalty)
	if loyalty then
		table.insert(
			stats,
			{ id = "loyalty", label = "Loyalty", value = loyalty, text = tostring(loyalty), fill = "love" }
		)
	end
	local mood = clampPercent(view.mood)
	if mood then
		table.insert(stats, {
			id = "mood",
			label = "Mood",
			value = mood,
			text = tostring(mood),
			band = CitizenModel.moodBand(mood),
			fill = "gold",
		})
	end
	local obedience = clampPercent(view.obedience)
	if obedience then
		table.insert(
			stats,
			{ id = "obedience", label = "Obedience", value = obedience, text = tostring(obedience), fill = "cool" }
		)
	end
	local relations = {}
	for _, r in
		{
			{ id = "family", list = view.family, one = "Family", many = "Family" },
			{ id = "friends", list = view.friends, one = "Friend", many = "Friends" },
			{ id = "rivals", list = view.rivals, one = "Rival", many = "Rivals" },
		}
	do
		local names = strings(r.list)
		if #names > 0 then
			table.insert(relations, {
				id = r.id,
				label = if #names == 1 then r.one else r.many,
				names = names,
				rival = r.id == "rivals",
			})
		end
	end
	local lastMemory = text(view.lastMemory)
	local memories = {}
	for _, m in strings(view.memories) do
		if m ~= lastMemory and #memories < CitizenModel.MEMORY_LIMIT then
			table.insert(memories, m)
		end
	end
	local request = view.hasRequest == true
	return {
		entityId = view.entityId,
		name = name,
		firstName = string.match(name, "^(%S+)") or name,
		initial = initial(name),
		sub = sub,
		request = request,
		stats = stats,
		intent = text(view.intent),
		intentIcon = if job then CitizenModel.JOB_ICONS[job] or "citizens" else "citizens",
		traits = strings(view.traits, CitizenModel.TRAIT_LIMIT),
		relations = relations,
		lastMemory = lastMemory,
		memories = memories,
		talk = { text = if request then "Talk" else "Ask", variant = if request then "primary" else "secondary" },
	}
end

function CitizenModel.conversation(payload: any, fallback: any?): any
	if type(payload) ~= "table" then
		return nil
	end
	local scenarioId = text(payload.scenarioId)
	local question = text(payload.question)
	if scenarioId == nil or question == nil or type(payload.options) ~= "table" then
		return nil
	end
	local options = {}
	local seen: { [string]: boolean } = {}
	for _, o in ipairs(payload.options) do
		if #options >= CitizenModel.OPTION_LIMIT then
			break
		end
		if type(o) == "table" then
			local id, label = text(o.id), text(o.text)
			if id and label and not seen[id] then
				seen[id] = true
				local risks, hidden = riskEntries(o.risks)
				table.insert(options, {
					id = id,
					text = label,
					index = #options + 1,
					cost = costEntries(o.cost),
					risks = risks,
					hiddenRisks = hidden,
				})
			end
		end
	end
	if #options == 0 then
		return nil
	end
	local speaker = if type(payload.speaker) == "table" then payload.speaker else {}
	local fb = if type(fallback) == "table" then fallback else {}
	local name = text(speaker.name) or text(fb.name) or "Your citizen"
	return {
		entityId = payload.entityId,
		scenarioId = scenarioId,
		question = question,
		options = options,
		speaker = { name = name, occupation = text(speaker.occupation) or text(fb.occupation), initial = initial(name) },
	}
end

function CitizenModel.key(entityId: any, scenarioId: any): string
	return `{tostring(entityId)}:{tostring(scenarioId)}`
end

function CitizenModel.price(option: any, balances: { [string]: number }?): any
	local short = {}
	local cost = if type(option) == "table" and type(option.cost) == "table" then option.cost else {}
	if balances == nil or #cost == 0 then
		return { short = short, need = nil }
	end
	local bag = {}
	for _, c in cost do
		bag[c.id] = c.amount
		if (balances[c.id] or 0) < c.amount then
			short[c.id] = true
		end
	end
	return { short = short, need = Text.missing(bag, balances) }
end

function CitizenModel.effect(e: any): any
	if type(e) ~= "table" then
		return nil
	end
	local label = text(e.text)
	if label == nil then
		return nil
	end
	local kind = if type(e.kind) == "string" then e.kind else ""
	local style = CitizenModel.EFFECTS[kind] or CitizenModel.NEUTRAL_EFFECT
	local first = string.sub(label, 1, 1)
	local tone = if first == "+"
		then "up"
		elseif first == "-" or string.sub(label, 1, 3) == "\u{2212}" then "down"
		else "neutral"
	return { kind = kind, text = label, icon = style.icon, tint = style.tint, tone = tone }
end

function CitizenModel.outcome(called: boolean, ok: any, result: any, reason: any): any
	if not called or ok == nil then
		return { phase = "failed", message = CitizenText.unreachable() }
	end
	if ok == true then
		local effects = {}
		local reaction = nil
		if type(result) == "table" then
			reaction = text(result.reaction)
			if type(result.effects) == "table" then
				for _, e in ipairs(result.effects) do
					local effect = CitizenModel.effect(e)
					if effect and #effects < CitizenModel.EFFECT_LIMIT then
						table.insert(effects, effect)
					end
				end
			end
		end
		return { phase = "answered", reaction = reaction, effects = effects }
	end
	return { phase = "refused", message = CitizenText.reason(reason), code = reason }
end

-- ------------------------------------------------------------------ geometry

function CitizenModel.cardRect(m: any): { x: number, y: number, width: number, height: number }
	local d = m.drawer
	local height = if m.breakpoint == "phone" then d.height else math.min(d.height, CitizenModel.CARD_HEIGHT)
	return { x = d.x, y = d.y, width = d.width, height = height }
end

function CitizenModel.conversationRect(m: any): { x: number, y: number, width: number, height: number }
	local d = m.drawer
	if m.breakpoint ~= "phone" then
		return { x = d.x, y = d.y, width = d.width, height = d.height }
	end
	-- Just below the pills (their spend badge sits on the pill's top edge) and the crest's Crown
	-- Points badge. Not below `hud.bottom`: on phones that includes the reputation strip (FL-0089),
	-- and a conversation is worth covering it — the sheet needs the height for answers with costs
	-- and risks at 844 × 390. Starting above the strip covers it whole (no sliver, FORGE-05 L3).
	local y = math.max(m.hud.pills.y + Layout.PILL_HEIGHT, m.hud.y + m.hud.crest + CitizenModel.CROWN_BADGE) + 2
	return { x = m.margin, y = y, width = d.x + d.width - m.margin, height = m.height - y - m.margin }
end

function CitizenModel.lines(s: string, width: number, char: number): number
	local n, used = 1, 0
	for word in string.gmatch(s, "%S+") do
		local w = (utf8.len(word) or #word) * char
		if used > 0 and used + char + w > width then
			n += 1
			used = w
		else
			used += (if used > 0 then char else 0) + w
		end
	end
	return n
end

-- Height of the cost row and the risk lines under an answer's text (0 without either), for a text
-- column `width` px wide. The cost row wraps when the chips and "Need ..." do not fit one line.
function CitizenModel.optionMeta(o: any, width: number, balances: { [string]: number }?): number
	local C = CitizenModel.CONVO
	local K = CitizenModel.CHAR
	local h = 0
	if #o.cost > 0 then
		local rows, used = 1, 0
		local function place(w: number)
			if used > 0 and used + C.costGap + w > width then
				rows += 1
				used = w
			else
				used += (if used > 0 then C.costGap else 0) + w
			end
		end
		for _, c in o.cost do
			place(C.costIcon + 2 + #tostring(c.amount) * K.cost)
		end
		local need = CitizenModel.price(o, balances).need
		if need then
			place((utf8.len(need) or #need) * K.need)
		end
		h += C.metaGap + rows * C.costRow + (rows - 1) * C.metaGap
	end
	for _, r in o.risks do
		h += C.metaGap + CitizenModel.lines(r.text, width - C.riskIndent, K.risk) * C.riskLine
	end
	if o.hiddenRisks > 0 then
		h += C.metaGap + C.riskLine
	end
	return h
end

-- state = { phase = "asking" | "choosing" | "answered" | "refused", conversation, picked?, outcome?,
-- error? } (ConversationController.state). `balances` (the treasury) decides whether an answer shows
-- "Need ..." in its cost row.
function CitizenModel.conversationHeight(state: any, rect: any, phone: boolean, balances: { [string]: number }?): number
	local C = CitizenModel.CONVO
	local K = CitizenModel.CHAR
	local pad = if phone then C.phonePad else C.pad
	local inner = rect.width - 2 * pad - C.scrollGutter
	local speechPad = if phone then C.phoneSpeechPad else C.speechPad
	local function speech(s: string, char: number, line: number): number
		return CitizenModel.lines(s, inner - 2 * (speechPad + 2), char) * line + 2 * speechPad + C.tail
	end
	local questionChar = if phone then K.phoneQuestion else K.question
	local speechLine = if phone then C.phoneSpeechLine else C.speechLine
	local convo = state.conversation
	local h = C.canvasTop
	local outcome = state.outcome
	if (state.phase == "answered" or state.phase == "refused") and outcome then
		if state.phase == "answered" then
			if not phone and state.picked then
				for _, o in convo.options do
					if o.id == state.picked then
						h += CitizenModel.lines("You: " .. o.text, inner, K.body) * 16 + C.gap
					end
				end
			end
			if outcome.reaction then
				h += speech(outcome.reaction, questionChar, speechLine) + C.gap
			end
			if #outcome.effects > 0 then
				local rows, used = 1, 0
				for _, e in outcome.effects do
					local w = C.chipChrome + (utf8.len(e.text) or #e.text) * K.chip
					if used > 0 and used + C.chipGap + w > inner then
						rows += 1
						used = w
					else
						used += (if used > 0 then C.chipGap else 0) + w
					end
				end
				local chip = if phone then C.phoneChip else C.chip
				h += C.kicker + C.gap + rows * chip + (rows - 1) * C.chipGap
			end
		else
			h += CitizenModel.lines(outcome.message, inner - 50, K.body) * 18 + 2 * C.speechPad
		end
		h += C.footer
	else
		h += speech(convo.question, questionChar, speechLine) + C.gap + C.kicker + C.gap
		local function option(o: any, width: number): number
			local column = width - C.optionChrome
			local n = CitizenModel.lines(o.text, column, K.option)
			local meta = CitizenModel.optionMeta(o, column, balances)
			-- +4 slack for a wrapped answer; the cost and risk rows are already rounded up (14 px per
			-- risk line, 13 measured).
			return math.max(C.optionMin, n * C.optionLine + (if meta > 0 then meta else 4) + 2 * C.optionPadY)
		end
		local options = convo.options
		if phone then
			local colWidth = (inner - C.gridGap) / 2
			for i = 1, #options, 2 do
				local a = option(options[i], colWidth)
				local b = if options[i + 1] then option(options[i + 1], colWidth) else 0
				h += math.max(a, b) + (if i > 1 then C.gridGap else 0)
			end
		else
			for i, o in options do
				h += option(o, inner) + (if i > 1 then C.optionGap else 0)
			end
		end
		if state.error then
			h += C.gap + C.errorLine
		end
	end
	local total = 2 * pad + C.header + h + 6
	local minimum = if phone then 150 else 220
	return math.floor(math.min(rect.height, math.max(minimum, total)))
end

-- True when the estimated content is taller than the space: the body will scroll, so the panel says
-- so ("YOUR ANSWER · SCROLL FOR ALL 3") instead of hiding an answer below the fold without a cue.
function CitizenModel.conversationOverflows(
	state: any,
	rect: any,
	phone: boolean,
	balances: { [string]: number }?
): boolean
	local saved = rect.height
	local unbounded = CitizenModel.conversationHeight(
		state,
		{ x = rect.x, y = rect.y, width = rect.width, height = math.huge },
		phone,
		balances
	)
	return unbounded > saved
end

return table.freeze(CitizenModel)
