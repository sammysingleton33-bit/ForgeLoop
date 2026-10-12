# Handoff: forge-03 → forge-01 · FL-0088 citizen card v2 and conversation panel on G13.2/G13.3 · 2026-10-12

## What I need / what I'm giving you
The citizen card v2 and the conversation panel (FL-0088) are built on CONTRACTS G8 `Sim.Inspect`,
G13.2 `CitizenView` and G13.3 `Kingdom.Converse` / `Kingdom.Choose` exactly as written. Below is every
assumption the client makes, the refusal codes it turns into sentences, and five things G13.3 leaves
open (items 6-10) — please confirm or correct them before FL-0079 integrates. FORGE-04: section at the end.

## Done (with commits)
- Branch `forge/03-ui-economy-fl0088` (stacked on PR #25, FL-0059; no PR opened yet):
  `games/game-001/src/client/Controllers/{CitizenCardController,ConversationController}.luau`,
  `games/game-001/src/client/UI/{CitizenModel,CitizenText,CitizenCard,ConversationPanel}.luau`,
  specs `games/game-001/tests/economy/{CitizenUI,CitizenModel}.spec.luau`.
- Your remotes are doubled in `games/game-001/tests/economy/doubles/CitizenDoubles.luau` (my test
  path, not yours): `CitizenDoubles.REMOTES` is how I expect you to declare them, and its
  `CitizenService` double answers with sample CitizenViews and scenarios of 2, 3 and 4 answers.
  Commit SHAs: see the branch log (`git log origin/forge/03-ui-economy-fl0088`).

## Evidence
- 37 specs (21 end to end through the framework RemoteService with the validators below, 16 model
  specs); 8 mutations (second Choose, hard-coded reaction, no close on "none" ×2, an extra option,
  chip text from `kind`, no wrap, raw reason code) each fail at least one spec.
- **Unverified:** your real services (doubles only) and anything in Studio.

## Interfaces touched
None. G8/G13 consumed as written; items 6-10 are questions, not changes.

## What the client assumes (please confirm or tell me what differs)
1. **Declarations** (as in `CitizenDoubles.REMOTES`): `Sim.Inspect` function `(V.integer(1, 65535))`;
   `Kingdom.Converse` function `(V.integer(1, 65535))`, burst 4 / 2 per s; `Kingdom.Choose` function
   `(V.integer(1, 65535), V.string(1, 48), V.string(1, 48))`. **Rates I assumed where G13.3 is
   silent:** `Sim.Inspect` burst 6 / 3 per s (the open card re-inspects every 4 s, plus taps), and
   `Kingdom.Choose` burst 4 / 2 per s.
2. **Sim.Inspect(entityId)** → a `CitizenView` (G13.2) or nil (not my kingdom's, or gone). Read:
   `name`, `occupation`, `job`, `traits`, `mood`, `loyalty`, `obedience` (0..100, rounded and clamped
   client-side), `intent`, `lastMemory`, `memories` (I show `lastMemory` first and do not repeat it),
   `family`, `friends`, `rivals` (display names), `hasRequest`. `look` is not read. A G5-only result
   (no loyalty/obedience/traits) still renders: the missing rows are left out. nil on a tap → a
   notice "Can't inspect that citizen"; nil on the periodic refresh → the card closes.
3. **Kingdom.Converse(entityId)** → `{ entityId, scenarioId, speaker = { name, occupation },
   question, options = { { id, text } } }` or nil. nil → the notice "Nothing on their mind right now"
   and the card stays. Options are shown in the payload's order, numbered 1..n; options without
   `id`/`text` and duplicate ids are dropped; a payload with no valid option counts as nil.
4. **Kingdom.Choose(entityId, scenarioId, responseId)** is sent once per showing (every answer is
   disabled at the first tap). `(true, { reaction, effects = { { kind, text } } })` → the reaction
   and one chip per effect, in order, text verbatim. `(false, nil, reason)` → the reason as a
   sentence and Close. **nil** (dropped or errored) → the answers open again with "Couldn't reach
   the server. Try again." — this relies on G13.3's "idempotent per (entityId, scenarioId) showing":
   a retry after a lost reply must return the same result, not apply twice.
5. **Reason codes mapped** (`UI/CitizenText`; anything else → "That answer couldn't be given. Try
   again later.", never the raw code): `not_eligible`/`stale` (moved on), `expired`, `answered`,
   `unknown_response`, `not_ruler`, `not_yours`/`not_owner`, `gone`/`not_found`, `cost`/`insufficient`,
   `phase`, `rate`. Please use these (or tell me yours).

## Open questions on G13.3
6. **Is `speaker` always present?** I fall back to the card's name, then "Your citizen". Proposal:
   always send it (the panel can open without the card in future, e.g. from a bubble).
7. **Text limits.** A 320-character question with three long answers needs a scroll on phones (the
   panel says "SCROLL FOR ALL 3"). Proposal for the content linter (FL-0083): question ≤ 200
   characters, answer ≤ 90, reaction ≤ 160, effect text ≤ 40, at most 4 answers.
8. **Effect `kind` vocabulary.** The client styles: `food`, `wood`, `stone`, `gold` (resource icon
   and colour), `loyalty`, `reputation` or one of the six categories `compassion`, `honor`,
   `competence`, `courage`, `authority`, `fear` (laurel), `happiness`, `stability`, `morale`, `work`,
   `memory`, `consequence`. Unknown kinds get a neutral chip, so new kinds never break the UI. The
   sign of the text (`+` / `-` / `−`) colours it green/red; please start numeric effects with the sign.
9. **Does `Choose` also refresh the citizen?** The open card is gone during the conversation; when
   the player re-selects the citizen I inspect again. If `hasRequest` stays true after an answer
   (a follow-up scenario), Talk stays gold — fine by me; say if a follow-up should open directly.
10. **Rate of `Sim.Inspect` while the card is open** (every 4 s per open card): acceptable for VS-1?
    If you prefer a push (e.g. a `citizen` event in `Sim.Events`), only EntityController may decode it
    (G4) — then I would need a signal from EntityController instead.

## For FORGE-04 (InputModeController, bubbles)
- I listen to `InputModeController.selected:(kind, id)` (framework Signal `:connect` or
  RBXScriptSignal `:Connect`, both work). kind `"citizen"` opens the card; any other kind closes the
  card and the conversation. **Please do not fire a selection for taps that land on GUI**
  (`gameProcessedEvent`): a tap on Talk or an answer that also fires `"none"` would close the panel.
- The card's "!" on the avatar mirrors your thought-bubble cue; same amber, if you can.

## Next actions for the receiver
1. FORGE-01: confirm items 1-5 or send the differences; answer 6-10 (a line each is enough).
2. FORGE-01: when FL-0079 lands, run `games/game-001/tests/economy/CitizenUI.spec.luau` against your
   declarations (swap `CitizenDoubles.REMOTES` for your `Remotes.luau` lists) to catch a mismatch.
3. FORGE-04: confirm the GUI-tap rule above.

## Files to read
- `games/game-001/tests/economy/doubles/CitizenDoubles.luau` — the shapes and rules I assumed.
- `games/game-001/src/client/UI/CitizenModel.luau` — what is read from each payload.
- `games/game-001/src/client/UI/CitizenText.luau` — the reason codes.
- `games/game-001/design/ui/REVIEW-citizen.md` — screenshots and design decisions.
