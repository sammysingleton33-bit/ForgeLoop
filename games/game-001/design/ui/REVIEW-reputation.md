# FL-0089 review — reputation strip, reputation screen, kingdom conditions

Self-review by FORGE-03, 2026-10-12. Sizes as FL-0059 (`REVIEW.md`): phone 844 × 390 (safe area
750 × 311), tablet 1024 × 768 (690 tall under the top bar), desktop 1920 × 1080. Contract:
CONTRACTS G13.4 (`Kingdom.Reputation`, `Kingdom.GetReputation`); design `design/living-kingdom.md` §3.
**No Studio evidence yet** — everything below is headless (HTML prototype, Lune specs, the
`design/ui/render` snapshot renderer). The Studio check is the user's (task completion criteria).

## 1. HTML prototype (reviewed first)
`reputation.html?size=…&scene=…` (`node shoot-reputation.js`) → `screenshots/prototype/rep-<scene>-<size>.png`.
Scenes: `hud` (+guides), `hud-change`, `screen` (+guides), `screen-detail`, `history`, `conditions`,
`fear` (fear-heavy ruler), `empty` (no history), `no-content` (no category text), `build` (overlap
check) — 36 shots. Committed (palette-compressed, D-007): `rep-hud-guides-phone`, `rep-hud-tablet`,
`rep-screen-guides-phone`, `rep-screen-tablet`, `rep-history-phone`. Category descriptions in the
prototype are SAMPLE text; the real text is the content library's (FL-0083).

Decisions the prototype settled:
- **Strip in the top-left stack.** Tablet/desktop: 3 × 2 under the rulers row, icon + name + number +
  bar per category (as wide as the pill row). Phones: one row of six under the crest, icon + number +
  bar, left of the phone drawer. Phone safe area is 311 px tall, so one 30 px row, not two.
- **Icons, not letters, on phones.** Three of the six categories start with C (Compassion,
  Competence, Courage), so a letter label is ambiguous. Each category got an icon (heart, scales,
  gear, sword-and-shield, sceptre, skull) plus its number; the screen names them. Colour is never
  the only signal: number everywhere, name on tablet/desktop, band word in the screen.
- **The drawer starts below the strip** on tablet/desktop (Layout `hud.bottom` now includes it).
  Desktop drawers keep their 480 px height; tablet drawers go from 466 to 398 px.
- **Screen = three tabs** (Reputation / History / Kingdom), the FL-0059 drawer pattern. Reputation:
  list + detail (tablet/desktop), 2 × 3 grid → detail with a back link (phones). Detail: value, band
  word (Low / Medium / High, presentation only), bar, "About" and "What affects it" **only when the
  content gives them**, then the category's latest three changes. History: signed delta chip
  (sign + colour), the cause in plain words, category, "2 min ago". Kingdom: happiness, stability,
  army morale with bars, numbers and band words, captioned as separate from reputation.
- **A push floats the change** on the strip (like the resource pills): a dark chip "+4" / "−2".

Changes made after looking at the prototype screenshots:
- The float deltas were green/red text on the green world: unreadable → dark chips with a coloured
  border, centred under the item (phones).
- On phones the detail bar collapsed to a hairline (flex shrink) → fixed height.
- The phone strip sat on the crest's Crown Points badge (it hangs 8 px below the crest) → strip y =
  crest bottom + 12.

## 2. Real Luau UI (headless render)
Scenes `scenes/rep-*.luau` on `scenes/_reputation.luau` (the FL-0059 spec world + the FORGE-01
ReputationService double `tests/economy/doubles/ReputationDoubles.luau`):
```
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=games/game-001/design/ui/screenshots/luau" \
  bash design/ui/render/shoot-luau.sh games/game-001/design/ui/scenes/rep-{hud,change,screen,nocontent,detail,history,conditions,fear,empty,build}.luau
```
30 renders, 0 snapshot errors. Committed (palette-compressed): `rep-hud-{phone,tablet,desktop}`,
`rep-change-{phone,tablet}`, `rep-screen-{phone,tablet}`, `rep-detail-phone`, `rep-history-phone`,
`rep-conditions-phone`, `rep-fear-desktop`, `rep-nocontent-tablet`, `rep-build-tablet`,
`rep-empty-phone`. `rep-screen`, `rep-detail` and `rep-fear` inject the SAMPLE texts (they read
"SAMPLE: …"); `rep-nocontent` is what ships until FL-0083.

Found by the Luau render, not by the prototype (fixed, re-rendered, looked at again):
- **Truncated names.** "Compassi…" / "Compete…" in the tablet/desktop strip and the phone grid: the
  prototype sizes names with flex, the Luau labels have fixed widths. Measured in the renderer's
  page (Montserrat SemiBold 11 px: "Competence" 73 px; a canvas estimate had said 58) → strip names
  10 px (like the pill sub-labels) in 118 px items with a 24 px number column; phone grid names
  12 px Merriweather with a 28 px number column; list numbers get 34 px ("100" is 27 px at 15 px).
- **Narrow phones.** A 640 × 360 safe area puts the phone drawer at x = 312, over a 323 px strip
  (Layout spec) → phone items shrink from 50 to 44–50 px to stay left of the drawer. Below ~640 px
  logical width the drawer covers part of the strip, as it already covers the pills (FL-0059).

Regression check of FL-0059 (Layout changed): all 27 FL-0059 renders re-shot and diffed with a
tolerance against the committed ones. Phones and every scene without a drawer (`hud`, `placing*`,
`placed`): identical. Drawer scenes on tablet/desktop moved down by the strip's height; looked at
`build` (tablet, desktop) and `build-short`, `upgrade`, `kingdom`, `confirm` (tablet): CTAs fully
visible, nothing cut; the Kingdom overview now scrolls to reach its 4th standing on tablet.
After stacking on #25/#34/#41 (FORGE-03 review): every Luau scene re-shot and pixel-compared with the
committed renders; the 15 that changed (all tablet/desktop drawer scenes of FL-0059 and FL-0087, plus
`rep-build-tablet`) are re-committed. `building-upgrade-tablet` and `plot-pick-tablet` looked at: the
Lv 2 line, the "Gives" line and the CTA still fit the 398 px tablet drawer. No render shows the old
drawer position any more.
The FL-0059 scenes do not load the reputation controller, so they show the gap without the strip;
`rep-build-*` shows the two together.

## 3. Checklist
| Check | Result |
|---|---|
| Never colour alone | number on every bar; names on tablet/desktop and in the screen; icons on phones; band words; signed deltas (+ / −) |
| Touch targets ≥ 44 px (phones) | strip hit area 44 px tall; close 44; phone tabs and the back link get 44 px hit areas over the kit's 34 px tabs; grid cells 48 |
| Strip never covered | phone: left of the drawer (spec, 640–750 wide); tablet/desktop: drawers start below it (spec + renders) |
| No invented prose | without a provider: no About / What affects it (spec; mutation M6) |
| Hidden without a kingdom | strip hidden, then filled after a late join (spec) |
| History order | newest first whatever the payload order (spec; mutation M1); ties: later list position first |
| Push → bar + history line | spec + `rep-change`, `rep-history` renders |

## 4. Prototype ↔ Luau differences (on purpose)
- Emoji fallbacks in Luau until the new icons are uploaded (`design/ui/icons/png/rep_*.png`,
  `happiness.png`, `stability.png`; morale reuses `banner`).
- History delta chips are top-aligned in Luau (automatic-height rows), centred in the prototype.
