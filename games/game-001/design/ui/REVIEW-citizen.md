# FL-0088 review — citizen card v2 and conversation panel

Self-review by FORGE-03, 2026-10-12. Sizes: phone 844 × 390 (CoreUISafeInsets 750 × 311), tablet
1024 × 768, desktop 1920 × 1080. Contracts: G13.2 (CitizenView via `Sim.Inspect`), G13.3
(`Kingdom.Converse` / `Kingdom.Choose`), G13.6 (`InputModeController.selected`). Studio evidence is
still the user's (one full conversation, per the task); everything below is headless.

## 1. HTML prototype (first)
`citizen.html?size=…&scene=…` (`node shoot-citizen.js`), scenes `card`, `card-quiet`, `card-asking`,
`talk-2`, `talk-3`, `talk-4`, `talk-long`, `choosing`, `answered`, `refused` (30 shots when shot).

What the prototype settled:
- **The card lives in the drawer** (the citizen is a "menu" like Build and Kingdom: one panel at a
  time, the rail stays). Tablet/desktop: two columns (how they see you, now, traits | people,
  memories); phone: one scrolling column with Talk pinned at the bottom.
- **Talk vs Ask.** `hasRequest` → a gold Talk button and an amber "!" on the avatar (the same cue as
  FORGE-04's thought bubble); otherwise a plain Ask. Nil from Converse → "Nothing on their mind
  right now" as a notice; the card stays.
- **Where the conversation shows.** Tablet/desktop: in the drawer's place (the left two thirds of the
  world stay visible). Phone: the 338 px drawer is too narrow for a question and its answers, so a
  wide sheet from the left margin to the drawer's right edge, *below the resource pills* (a spend or
  gain must stay visible) and left of the rail. Answers: full-width rows on tablet/desktop, two
  columns on phones, each ≥ 44 px and wrapping.
- **Speech metaphor.** The citizen's words (question, reaction) sit in a parchment speech box with a
  tail toward the avatar; the ruler's answers are dark numbered buttons. After a pick: the pick is
  marked gold with an hourglass, the rest dim (answer once).
- **"What changed"** = effect chips: icon + coloured border by `kind`, the server's text, the text
  coloured by its leading sign (+ green, − red); unknown kinds get a neutral ⓘ chip.

Changes made after looking at the prototype screenshots:
- Desktop/tablet panels had 150–250 px of empty space under short content → fitted heights: the
  card is at most 376 px; the conversation height is estimated from the text (greedy word wrap with
  average glyph widths, `CitizenModel.conversationHeight`), and the body scrolls if the estimate is short.
- Phone card: the request banner duplicated the Talk button and pushed the traits off screen →
  removed; the "!" moved onto the avatar; the opinion box lost its title on phones.
- Phone sheet covered the pills' spend float (−20 under Wood) → the sheet starts 16 px lower.
- Phone "answered" cut the second row of chips → the echo of your answer is dropped on phones, the
  speech box and chips are tighter (24 px chips).

## 2. Real Luau UI (headless render)
Scenes `scenes/citizen-*.luau` drive the real controllers on the spec world with the FORGE-01
doubles (`scenes/_citizen.luau`):
```
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=games/game-001/design/ui/screenshots/luau" \
  bash design/ui/render/shoot-luau.sh games/game-001/design/ui/scenes/citizen-*.luau
```

Found by the Luau render, not by the prototype (fixed):
- **Wrapped Merriweather lines overlapped** (question, reaction): `LineHeight` 1 is too tight for its
  ascenders → `LineHeight` 1.25 on speech text and 1.15 on other wrapped text (`CitizenModel`).
- **The height estimate over-shot on phones** (a 40 px hole under four short answers) → glyph widths
  calibrated on the renders (question ≈ 6.6 px per character at 14 px, answers ≈ 7.0 px at 13 px
  bold, chips ≈ 5.4 px at 11 px; the others scaled from those), with a little slack kept.
- **A very long question hides the third answer below the fold on phones** (it scrolls, but only a
  thin bar said so) → the kicker reads "YOUR ANSWER · SCROLL FOR ALL 3" when the estimate overflows.
  Proposed content limits to FORGE-01/FORGE-00 in the handoff (question ≤ 200, answer ≤ 90 chars).
- The mood band ("Unhappy") touched the end of its bar → the bar is 10 px shorter.
- The name's descender ("Thornbury") was clipped by a 20 px label → 22 px.

Seen, not changed here (not this task's files):
- **Desktop/tablet: the HUD's spend float under the Wood pill overlaps the "Mira" ruler chip**
  (`citizen-answered-tablet.png`). Pre-existing FL-0059 HUD layout (`CurrencyPill` Delta vs the
  members row); `KingdomHud.luau`/`Layout.luau` are being changed by FL-0089 right now, so it is a
  follow-up for whoever lands last.
- The renderer draws emoji glyphs until the icons are uploaded (5 new icons in `design/ui/icons.js`:
  talk, heart, mood, scroll, laurel; sheet `design/ui/screenshots/icons-sheet.png`).

## 3. Screenshots committed (palette-compressed; first round 0.55 MB for 15)
Prototype (`screenshots/prototype/`): `citizen-card-phone.png`, `citizen-talk-4-phone.png`,
`citizen-answered-phone.png`, `citizen-talk-3-desktop.png`.
Luau (`screenshots/luau/`): `citizen-card-phone.png`, `citizen-card-desktop.png`,
`citizen-card-quiet-tablet.png`, `citizen-talk-4-phone.png`, `citizen-talk-long-phone.png`,
`citizen-talk-3-desktop.png`, `citizen-talk-long-desktop.png`, `citizen-choosing-desktop.png`,
`citizen-answered-phone.png`, `citizen-answered-tablet.png`, `citizen-refused-phone.png`; since the
FORGE-05 fixes (section 5) also `citizen-talk-risks-phone.png`, `citizen-talk-risks-desktop.png` and
`citizen-toast-phone.png`. The rest are regenerated with the two commands above.

## 4. Checklist
| Check | Result (headless) |
|---|---|
| Dialogue text only from the server | question, answers, reaction, effect texts and every CitizenView string pass through `CitizenModel` untouched; specs compare them with the payload; mutations M2, M5, M6 fail the specs |
| Answer once | every answer disabled at the first pick; a double tap and a second answer send one `Kingdom.Choose` (spec; mutation M1) |
| Refusals explained | reason codes → sentences (`UI/CitizenText`), unknown → a generic sentence, never the raw code (spec; mutation M8); a dropped call re-opens the answers with "Couldn't reach the server" |
| Long text | `TextWrapped` + `AutomaticSize.Y` on the question, answers and reaction; buttons grow; the body scrolls (spec; mutation M7) |
| Phone fit | 844 × 390: the card in the drawer, the sheet below the pills and left of the rail; answers ≥ 44 px (specs) |
| World visible on desktop | the panels take the drawer's place (≤ 620 × 480 logical); the world's left two thirds stay clear |
| Closes on selection | "none", a building or a slot closes the card and the conversation; another menu replaces them (specs; mutations M3, M4) |
| Colour is never the only signal | chip texts carry the sign; loyalty, mood and obedience show numbers and a mood word |
| Costs and risks before choosing | every answer's cost as chips against the treasury (short: red **and** "Need 25 Gold", disabled) and every risk with its whole-percent chance, before the pick (specs at desktop and 750 × 311; mutations 1-7) |
| Late replies | a Converse or Sim.Inspect reply after the menu changed is ignored; a Choose reply after a close/reopen lands on the reopened panel or becomes a notice, and is never re-sent (specs; mutations 8-12) |
| Studio | **unverified**: one full conversation in Studio per `games/game-001/STUDIO_PLAYTEST.md` and `roblox/studio-tests/ui-economy.md` U13 (costs and every risk) |

## 5. FORGE-05 review of #52 — fixes (2026-10-12, branch `forge/03-ui-economy-fl0088-gate`)
| Finding | Fix | Specs |
|---|---|---|
| **M1** cost and risks not shown | `CitizenModel.conversation` keeps each option's `cost` (known resources, whole amounts > 0, resource order) and `risks` (text, or the content `notice`; a chance outside 0..1 shows "?" rather than hiding the risk; at most 4 listed, then "+N more risks"). Each answer shows resource chips; an amount the treasury can't cover is red and the answer says "Need 25 Gold" (`Text.missing`, the build menu's words) and is disabled (`choose` refuses it too). Each risk is a line "⚠ 40 % · the server's sentence", wrapping, never truncated. A treasury push patches in place: only an answer whose affordability changed is rebuilt (`ConversationPanel:patch`). The height estimate counts the cost row and risk lines. | `CitizenModel.spec` (parsing, loose validation, caps, chance labels, price, height), `CitizenUI.spec` "Answer costs and risks…" (desktop, phone 750 × 311 without scroll, talk-3, push patch) |
| **M2** a late reply takes the drawer back | Both controllers bump their request token on any `menuChanged` away from their menu (the conversation also clears its loading state). | "Late replies never take the drawer back" (Talk→close, Talk→Build, tap→Build) |
| **M3** Choose guard per showing | `ConversationController.inflight[entityId:scenarioId]` survives close/reopen: a reopened in-flight showing shows the pick as waiting (answers disabled); the reply lands on the reopened panel, or, when nothing of that showing is on screen, becomes a notice (speaker + reaction / reason). Never re-sent. | "Kingdom.Choose in flight is guarded per showing" (2 specs) |
| L1 invalid UTF-8 | `initial()` checks `utf8.len` first; falls back to the first ASCII letter/digit, else "?". | `CitizenModel.spec` |
| L2 caps | 4 answers, 4 risks per answer (+N more), 8 effect chips. | `CitizenModel.spec` |
| L3 strip sliver | The phone sheet starts just under the pills and the Crown Points badge (y 50 at 750 × 311, was 58): the spend badge sits on the pill's top edge now (CurrencyPill), so the old 16 px gap was no longer needed; the sheet starts above the reputation strip (y 52) and covers it whole. 8 px more for answers. | geometry spec |
| L4 toasts over the sheet | `hud:setSheet("conversation")`; while it is open on a phone, toasts sit in the band right of the pills above the sheet (`Layout.sheetToast`, 330 px wide), one at a time (`ToastStack:place(…, limit)`). | "L4 phone: toasts…" |
| L5 10 s wait on main | `hud:hasRemote(name)` (FindFirstChild on ReplicatedStorage.ForgeRemotes, never yields); no `Kingdom.Converse` → "Conversations aren't available yet" at once; no `Kingdom.Choose` → the same as the answer's error. | "L5 …today's main" (inspect-only double) |
| L6 destroy leaves the menu | Both controllers close their own menu in `destroy()`. | "L6 …" |
| L7 foreign tap leaves the card | A non-refresh Sim.Inspect nil closes the open card, with the notice. | "L7 …" |
| L8 conversation after despawn | Every 4 s while open (not while a Choose is in flight) `Sim.Inspect`; nil closes it with "They're no longer here." | "L8 …" |

Render rounds (`scenes/citizen-*.luau`; `_citizen.luau` now runs the reputation strip too, as the game does):
1. New `citizen-talk-risks` (Wulf, "Need 25 Gold" + two risks) and `citizen-toast`, plus talk-2/3, all
   sizes. Seen: everything fits on the phone; the toast touched the sheet's top edge → the toast band
   moved to the top of the safe area (2 px gap). ">99 %" measures 34 px in the renderer page, the
   column was 34 → 38 px (Studio slack). The phone panel had 26 px of empty space: a 37-character
   risk line was estimated as two lines and every answer kept the old +4 px slack.
2. Every citizen scene with the strip on. Seen: the sheet covers the strip whole (no sliver; before
   y 52-58 showed); the −20 spend badge stays visible above the sheet (answered, phone); talk-3 and
   talk-long scroll on phones with an honest "SCROLL FOR ALL 3". Measured the risk font in the
   renderer page (Montserrat SemiBold 11: 5.5-5.6 px per character → 5.9 with slack) and dropped the
   +4 px for answers with costs/risks.
3. Slack between the content and the panel bottom, from `out/*.layout.json`: answers with costs or
   risks 12-13 device px on tablet/desktop (was 21-28); phone talk-risks 22 px, kept on purpose: the
   second risk fits its line by 3 px in the renderer and may wrap in Studio.

Seen, not changed:
- **Phones with 3-4 answers scroll** (allowed by the review). The second row can sit across the fold, so
  an answer's top can be tappable while its risk line is still below the fold; the kicker says
  "SCROLL FOR ALL N". A first-line risk marker is a possible follow-up; content with risks has 2-3
  answers today.
- The phone header's X is the kit's 36 px IconButton (below 44 px), same as the card (pre-existing).
