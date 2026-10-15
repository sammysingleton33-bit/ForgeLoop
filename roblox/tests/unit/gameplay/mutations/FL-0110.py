"""FL-0110 mutation rows, run by ../mutations.py (`mutations.py FL-0110`).

One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/. Add rows for
FL-0110 here only.
"""
CONV = G + "src/server/Services/ConversationService.luau"
TAGS = G + "src/shared/Kingdom/ConversationTags.luau"
M = [
 # --- Converse: the question and its presentation
 ("FL-0110", CONV, 'pcall(self._payload, self, c, still, userId, showing.question)', 'pcall(self._payload, self, c, still, userId, self:_question(c, still, ctx))', "ConversationPresentation", "keeps the variant of the first showing"),
 ("FL-0110", CONV, 'traits = if c.profile then c.profile.traits else nil,', 'traits = nil,', "ConversationPresentation", "sends the question variant its trait picks"),
 ("FL-0110", CONV, 'question = ContentQuery.fill(question.text, names),', 'question = ContentQuery.fill(scenario.question, names),', "ConversationPresentation", "sends the question variant its trait picks"),
 ("FL-0110", CONV, '(ContentQuery.presentation(scenario.id) or {}).urgency', 'nil', "ConversationPresentation", "sends the question variant its trait picks"),
 # --- Choose: the reaction band and its tags
 ("FL-0110", CONV, 'ContentQuery.reactionFor(response.id, loyaltyBefore)', 'ContentQuery.reactionFor(response.id, c.loyalty)', "ConversationPresentation", "picks the band from the loyalty when the citizen was asked"),
 ("FL-0110", CONV, 'ContentQuery.fill(if line then line.text else response.reaction, names)', 'ContentQuery.fill(response.reaction, names)', "ConversationPresentation", "sends the high band's text"),
 ("FL-0110", CONV, 'text = reaction, tone = tags.tone })', 'text = reaction, tone = (line and line.tone) or "neutral" })', "ConversationPresentation", "falls back to neutral tone and no tags"),
 # --- the vocabulary and its clamping
 ("FL-0110", TAGS, '	if next(out) == nil then\n		return nil\n	end\n	return out', '	return out', "ConversationTags", "is nil for an untagged question"),
 ("FL-0110", TAGS, 'if type(value) == "string" and values[value] == true then', 'if type(value) == "string" then', "ConversationTags", "drops words outside the vocabulary"),
 ("FL-0110", TAGS, 'ConversationTags.BUBBLE_MAX = 9', 'ConversationTags.BUBBLE_MAX = 99', "ConversationTags", "accepts a bubble from 2.5 to 9 seconds"),
 ("FL-0110", TAGS, '		band = allowed(ConversationTags.BANDS, r.band) or "base",\n', '', "ConversationTags", "keeps a tagged reaction whole"),
 ("FL-0110", TAGS, '		out.variantId = id', '		out.variantId = nil', "ConversationTags", "keeps allowed tags and the urgency"),
 ("FL-0110", TAGS, 'tone = allowed(ConversationTags.TONES, r.tone) or "neutral",', 'tone = allowed(ConversationTags.TONES, r.tone) or "happy",', "ConversationTags", "gives an untagged reaction a tone and a band"),
]
