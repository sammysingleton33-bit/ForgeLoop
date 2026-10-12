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

## 3. Screenshots committed (palette-compressed, 0.55 MB for 15)
Prototype (`screenshots/prototype/`): `citizen-card-phone.png`, `citizen-talk-4-phone.png`,
`citizen-answered-phone.png`, `citizen-talk-3-desktop.png`.
Luau (`screenshots/luau/`): `citizen-card-phone.png`, `citizen-card-desktop.png`,
`citizen-card-quiet-tablet.png`, `citizen-talk-4-phone.png`, `citizen-talk-long-phone.png`,
`citizen-talk-3-desktop.png`, `citizen-talk-long-desktop.png`, `citizen-choosing-desktop.png`,
`citizen-answered-phone.png`, `citizen-answered-tablet.png`, `citizen-refused-phone.png`.
The rest are regenerated with the two commands above.

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
| Studio | **unverified**: one full conversation in Studio per `games/game-001/STUDIO_PLAYTEST.md` |
