--!strict
--[[
	Kingdom/ConversationTags — the presentation tags the server may put on Kingdom.Converse and Kingdom.Choose
	(CONTRACTS G13.8 v0.4-g10; content SPEC §5.10). Pure: no requires, no Roblox APIs.

	Content is validated when it is generated, but the server still sends only values it knows: a hand-edited
	module, a stale build or a bad fixture must never put an unknown word, a free text or an absurd number on the
	wire (FORGE-07 review of FL-0110). A value outside its vocabulary is dropped (nil); nothing is replaced by a
	default, because "no tag" is a legal answer and a default would pretend the writer chose it.

	API
		ConversationTags.EMOTIONS, EXPRESSIONS, GESTURES, DELIVERIES, URGENCIES, TONES, BANDS
			frozen { [value]: true } sets: the SPEC §5.10 vocabulary (TONES and BANDS as in reactionFor)
		ConversationTags.BUBBLE_MIN, BUBBLE_MAX     2.5, 9 seconds (SPEC "Bubble seconds")
		ConversationTags.question(question, urgency?): { emotion?, expression?, gesture?, delivery?, urgency?,
		                                                 variantId? }?
			the Converse `presentation` of a questionFor result (and the scenario's urgency): nil when it has no
			allowed tag at all, so an untagged scenario adds no field
		ConversationTags.reaction(reaction): { tone: string, band: string, emotion?, expression?, gesture?,
		                                       delivery?, bubble_s? }
			the Choose fields of a reactionFor result; an unknown tone is "neutral", an unknown band "base"
		ConversationTags.bubble(seconds): number?
			a finite number from BUBBLE_MIN to BUBBLE_MAX, else nil
]]

local ConversationTags = {}

local function set(values: { string }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, value in values do
		out[value] = true
	end
	return table.freeze(out)
end

ConversationTags.EMOTIONS = set({
	"determination",
	"frustration",
	"gratitude",
	"relief",
	"joy",
	"excitement",
	"worry",
	"suspicion",
	"anger",
	"fear",
	"contempt",
	"sadness",
	"neutral",
	"hope",
	"amusement",
	"curiosity",
	"defiance",
	"pride",
	"embarrassment",
	"grief",
})
ConversationTags.EXPRESSIONS = set({
	"smile",
	"frown",
	"smirk",
	"beam",
	"neutral",
	"grin",
	"raised_brow",
	"scowl",
	"eye_roll",
	"wide_eyed",
	"downcast",
	"teary",
	"sheepish",
})
ConversationTags.GESTURES = set({
	"nod",
	"shrug",
	"hand_on_heart",
	"cross_arms",
	"none",
	"point",
	"fist_pump",
	"head_down",
	"throw_up_hands",
	"wring_hands",
	"salute",
	"scratch_head",
	"lean_in",
	"hold_up",
	"glance_around",
	"hands_on_hips",
	"rub_neck",
	"bow",
	"wave",
	"step_back",
	"raise_hand",
})
ConversationTags.DELIVERIES = set({
	"warm",
	"blunt",
	"deadpan",
	"cheerful",
	"excited",
	"grumbling",
	"sarcastic",
	"solemn",
	"urgent",
	"proud",
	"hushed",
	"nervous",
	"formal",
	"pleading",
	"playful",
})
ConversationTags.URGENCIES = set({ "low", "normal", "high", "critical" })
ConversationTags.TONES = set({ "happy", "angry", "sad", "neutral" })
ConversationTags.BANDS = set({ "base", "high", "low" })

ConversationTags.BUBBLE_MIN = 2.5
ConversationTags.BUBBLE_MAX = 9

local ID_MAX = 64 -- a variant id is a content id: short, word characters, dots and dashes

local function allowed(values: { [string]: boolean }, value: any): string?
	if type(value) == "string" and values[value] == true then
		return value
	end
	return nil
end

function ConversationTags.bubble(seconds: any): number?
	if
		type(seconds) == "number"
		and seconds == seconds
		and seconds >= ConversationTags.BUBBLE_MIN
		and seconds <= ConversationTags.BUBBLE_MAX
	then
		return seconds
	end
	return nil
end

function ConversationTags.question(question: any, urgency: any?): { [string]: any }?
	local q = if type(question) == "table" then question else {}
	local out: { [string]: any } = {
		emotion = allowed(ConversationTags.EMOTIONS, q.emotion),
		expression = allowed(ConversationTags.EXPRESSIONS, q.expression),
		gesture = allowed(ConversationTags.GESTURES, q.gesture),
		delivery = allowed(ConversationTags.DELIVERIES, q.delivery),
		urgency = allowed(ConversationTags.URGENCIES, urgency),
	}
	local id = q.variantId
	if type(id) == "string" and #id >= 1 and #id <= ID_MAX and string.match(id, "^[%w_%.%-]+$") ~= nil then
		out.variantId = id
	end
	if next(out) == nil then
		return nil
	end
	return out
end

function ConversationTags.reaction(reaction: any): { [string]: any }
	local r = if type(reaction) == "table" then reaction else {}
	return {
		tone = allowed(ConversationTags.TONES, r.tone) or "neutral",
		band = allowed(ConversationTags.BANDS, r.band) or "base",
		emotion = allowed(ConversationTags.EMOTIONS, r.emotion),
		expression = allowed(ConversationTags.EXPRESSIONS, r.expression),
		gesture = allowed(ConversationTags.GESTURES, r.gesture),
		delivery = allowed(ConversationTags.DELIVERIES, r.delivery),
		bubble_s = ConversationTags.bubble(r.bubble_s),
	}
end

return table.freeze(ConversationTags)
