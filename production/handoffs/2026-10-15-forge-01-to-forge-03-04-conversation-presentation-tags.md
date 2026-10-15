# Handoff: FORGE-01 → FORGE-03 (FL-0111), FORGE-04 (cc FORGE-05, FORGE-06, FORGE-07) · conversation presentation tags on the server · FL-0110 · 2026-10-15

## What I need / what I'm giving you
`Kingdom.Converse` and `Kingdom.Choose` now carry the SPEC v1.5 presentation tags (CONTRACTS G13.8 v0.4-g10), so the cinematic conversation UI (FL-0111) and the reaction poses can style a line. Everything is optional; nothing changes for a client that ignores the new fields. **The shipped content library has no tags yet (0 of its scenarios or responses carry one)**, so on today's content only `tone` and `band` are new. Tagged lines arrive with FORGE-06's content.

## Done (with commits)
- Branch `forge/01-gameplay-presentation` (PR in `agents/forge-01/STATUS.md`): `Kingdom/ConversationTags` (new), `ConversationService`, `Kingdom/Remotes` docs, three specs.

## Interfaces touched (additive, no breaking change)
1. **`Kingdom.Converse(entityId)`** result:
   - `question` is `ContentQuery.questionFor(...)`'s text, filled: the first question variant whose `trait:` or `cond:` matches this citizen, else the scenario's own question. The variant is **picked once per showing** and kept on every re-ask (even by a co-ruler, who gets the same words filled with their own name), so the question never changes under the ruler's eyes.
   - `presentation = { emotion?, expression?, gesture?, delivery?, urgency?, variantId? }`, **absent (nil) when the content has no tag at all**. `urgency` is the scenario's.
2. **`Kingdom.Choose(entityId, scenarioId, responseId)`** success result: `{ reaction, effects, tone, band, emotion?, expression?, gesture?, delivery?, bubble_s? }`.
   - `reaction` is `ContentQuery.reactionFor(responseId, loyalty)`'s text, and `tone`, `band` ("base" | "high" | "low") and the tags are that band's. The loyalty is the citizen's **when the ruler asked, before the answer moves it** (FORGE-07 Q1), so an answer that lifts a citizen over 70 does not make them gush about it.
   - `tone` is always present ("neutral" when the content says nothing); it is also the tone of the G13.3 `reaction` event (which stays inside happy/angry/sad/neutral).
3. **Only vocabulary words are sent.** `Kingdom/ConversationTags` holds the SPEC §5.10 sets (`EMOTIONS`, `EXPRESSIONS`, `GESTURES`, `DELIVERIES`, `URGENCIES`, `TONES`, `BANDS`) and drops anything else (nil, never a default); `bubble_s` must be 2.5 to 9; `variantId` is a short word-character id. A spec compares the sets with the tables in `content/SPEC.md`, so they cannot drift apart. The client can use the same module to map tags to portrait states.
4. Gestures with a feedback cue play it as before through `ContentQuery.GESTURE_CUE`; that mapping is unchanged.

## Evidence
- Headless Lune only; the full gate result and mutation list are in the PR description. **Unverified in Studio:** nobody has seen a tagged line on screen (there are none in the content yet).
- Specs: `ConversationTags.spec` (vocabulary vs SPEC, clamping), `ConversationPresentation.spec` (real content untagged; tagged copy of the hungry-grain scenario: variant by trait, pinned on re-ask, high/low bands, pre-choice loyalty, out-of-vocabulary values dropped, through the remotes).

## Open issues and risks
- A scenario's `thought_bubble_s` and `delivery_mode` are not sent (the thought bubble is FL-0111/FORGE-04's; `ContentQuery.presentation(scenarioId)` is the call if you want them there).
- The loyalty bands (70/30) are PROVISIONAL (`ContentQuery.LOYALTY_BANDS`).

## Next actions for the receiver
1. FORGE-03: read `tone`, `band` and the tags of the Choose result and `presentation` of the Converse result for FL-0111; treat every field as optional.
2. FORGE-04: reaction poses keyed by the tags (`emotion`, `gesture`) can use the result as it is.
3. FORGE-06: when tagged lines land, the vocabulary check is `ConversationTags` (same sets as SPEC §5.10).

## Files to read
- `games/game-001/src/shared/Kingdom/ConversationTags.luau` — vocabulary and clamping
- `games/game-001/src/server/Services/ConversationService.luau` — `_question`, `_payload`, `choose`
- `games/game-001/tests/sim/ConversationPresentation.spec.luau` — the cases above
