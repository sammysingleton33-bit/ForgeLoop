# FL-0060 review — army drawer, objective tracker, slice summary

Self-review by FORGE-03, 2026-10-12. Sizes as FL-0059 (`REVIEW.md`): phone 844 × 390 (safe area
750 × 311), tablet 1024 × 768 (scale 1.095, 935 × 630 logical), desktop 1920 × 1080. Contracts: G8
(`Army.Recruit`, `Army.Command`, `Army.Objectives` / `Army.GetObjectives`, `Match.Ended`, "VS-1
command"), G9 (`MatchEnded` payload; server-only, the UI uses the remote), G3 (the first capture ends
the slice), G13.2 (`Kingdom.Population`: soldiers = `byJob.soldier`). FORGE-01's FL-0052 is not built:
everything runs against `tests/economy/doubles/ArmyDoubles.luau`. **No Studio evidence yet** — all of
this is headless (HTML prototype, Lune specs, the `design/ui/render` snapshot renderer); the Studio
steps are U14 in `roblox/studio-tests/ui-economy.md`.

## 1. HTML prototype (first)
`army.html?size=…&scene=…` (`node shoot-army.js`) → `screenshots/prototype/army-<scene>-<size>.png`.
Scenes: `hud` (+guides), `hud-open`, `army` (+guides), `army-short`, `army-none`, `army-sent`,
`army-nobarracks`, `upgrade-tab`, `summary` (+guides), `summary-win`, `summary-none` (36 shots).

What the prototype settled:
- **One army drawer, two ways in.** A third rail button **Army** opens it for my barracks (the one
  tapped last, else the first finished one); tapping my barracks in the world opens its upgrade panel
  (FL-0087), which gains an **Army** tab into the same drawer, and the drawer's "Barracks · Lv N" tab
  goes back. One state (ArmyPanelController), one view (UI/ArmyPanel). The drawer also works with no
  barracks ("Build a Barracks to recruit soldiers"), because Send to capture is not tied to one.
- **Phone drawer = one column without scrolling**: your army (count + Send to capture) on top — the
  action that matters in the slice — then a status line, then recruit: unit line, − count + with the
  cost lines (cost × count, ✓ or "have N"), and the Recruit CTA. Tablet/desktop: two cards, Recruit
  (unit, time, upkeep, how many, cost rows, CTA) and Your army (count, upkeep, what Send does, the
  target objective, Send CTA).
- **Send to capture without a target.** CONTRACTS: empty `unitIds` = all my idle soldiers and
  `targetId` is optional, so VS-1 sends `Army.Command({}, "capture")` and the server picks the tower
  ("the nearest tower you don't hold" — FORGE-01 to confirm in the handoff). No picker (VS-2).
- **Objective tracker under the top-left stack** (crest → pills → rulers → reputation strip →
  tracker), left of every drawer. The top-right is taken by toasts, the bottom-left by Roblox's
  touch thumbstick, the bottom centre by the construction chips, the top centre by the timer. It is
  not part of `hud.bottom`, so no drawer loses height. Each objective: name (a number when there are
  several), owner chip (swatch + kingdom name, "Neutral", "Yours"), one bar per contesting kingdom with
  its name and percentage, mine first as "You" in gold. Collapsed: the objective that matters most
  with at most two bars and "+N more"; a tap expands the list.
- **Slice summary** on the modal layer: scrim over everything, a centred panel; phones two columns
  (600 × 262, so it stays clear of the 58 px top bar on a 390 px screen), tablet/desktop one column
  (460 wide). Kicker ("Victory" / "Match over"), winner crest and name or "No winner", "Lasted m:ss",
  standings with Crown Points (winner crowned, mine highlighted and tagged "you", AI tagged), Continue.
  The scrim does not close it: the end of the slice must not vanish on a stray tap.

Changed after looking at the prototype screenshots:
- "Thornwood" truncated in the expanded list → the bar-label column went from 62 to 70 px (72 in Luau).
- Tablet/desktop "Your army" card: the default status line repeated the description and overflowed the
  card → the status line shows there only after sending or when there are no soldiers (phones keep it:
  they have no description).
- Desktop summary had a dead gap above Continue → height fitted to the content.
- Phone "Your kingdom wins the match" wrapped under the crest → "Your kingdom wins".

## 2. Real Luau UI (headless render)
Scenes `scenes/{objectives-hud,objectives-open,army-panel,army-short,army-none,army-sent,army-nobarracks,
army-tab,summary-lost,summary-win,summary-none}.luau` on `scenes/_army.luau` (the spec world with
ArmyDoubles, PopulationDoubles and ReputationDoubles, so the HUD stack is the real one) and
`scenes/_summary.luau`:
```
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=games/game-001/design/ui/screenshots/luau" \
  bash design/ui/render/shoot-luau.sh games/game-001/design/ui/scenes/{objectives-hud,objectives-open,army-panel,army-short,army-none,army-sent,army-nobarracks,army-tab,summary-lost,summary-win,summary-none}.luau
```
33 renders, 0 snapshot errors (round 1 and round 2).

Round 1 — found by the Luau render, not by the prototype (fixed):
- **Tablet target chip**: "WatchtowerNeutral · you 64…" — the name and the status shared one 28 px line
  in a ~200 px card → two lines (name; owner and my progress), 40 px.
- **Tablet tracker touched the drawer**: 272 px wide from x = 16 ends at 288; the tablet drawer starts
  at x = 289 → Layout clamps the tracker to 12 px left of the drawer (261 px on tablets); a Layout spec
  checks six screen sizes.
- **Truncated sentences**: "Recruit soldiers to capture towe…" (tablet card) → "Recruit soldiers first";
  "The match ended witho…" (phone summary) → "Nobody won the match".

Found by the specs (fixed): the tracker rebuilt on every render — its `_build` calls `destroy()`, which
cleared the render key set just before (the M1 identity spec caught it; `docs/lessons-learned`); the
stepper label and the soldier-count row were both named "Count".

Round 2: re-rendered all 33 and looked at the changed ones (`army-panel-tablet` — chip and tracker gap,
`army-none-tablet`, `summary-none-phone`): fixed, nothing new.

Regression check (Layout, KingdomHud, KingdomHudController and UpgradePanel changed): 27 committed
renders of FL-0059 / FL-0087 / FL-0088 / FL-0089 (`hud`, `building-upgrade`, `building-foreign`,
`plot-pick`, `rep-hud`, `rep-build`, `kingdom`, `confirm`, `citizen-card`, `citizen-answered`,
`placed`) re-shot, palette-compressed the same way and compared: all 27 pixel-identical. The rail gets
its third button only where ArmyPanelController runs, and the upgrade panel's Army tab only for my
barracks with ArmyPanelController running.

Prototype ↔ Luau differences that remain (on purpose): emoji fallbacks until the icons are uploaded
(the army/watchtower/banner/militia/standings icons exist in `design/ui/icons.js` already); the Luau
tracker draws a fixed 72 px name column (prototype: flex).

## 3. Screenshots committed (palette-compressed, 19 files, 0.64 MB; largest 60 KB)
Prototype (`screenshots/prototype/`): `army-hud-guides-phone`, `army-army-phone`, `army-army-tablet`,
`army-army-sent-phone`, `army-summary-phone`.
Luau (`screenshots/luau/`): `objectives-hud-phone`, `objectives-hud-desktop`, `objectives-open-phone`,
`army-panel-phone`, `army-panel-tablet`, `army-short-phone`, `army-none-tablet`, `army-sent-phone`,
`army-nobarracks-phone`, `army-tab-phone`, `summary-lost-phone`, `summary-lost-desktop`,
`summary-win-phone`, `summary-none-phone`. The rest are regenerated with the commands above.

## 4. Checklist
| Check | Result (headless) |
|---|---|
| Server-authoritative | the client sends `Army.Recruit` / `Army.Command` intents only; counts, costs paid, bars, owners and the winner come from replies and pushes (specs; the double spends through the real TreasuryService) |
| Every refusal explained | CTA text for shortfalls ("Need 30 Food"), no barracks, unfinished barracks, no soldiers, every tower mine; server reasons as sentences (`UI/ArmyText`), unknown → generic, never the code (spec; mutation M4) |
| One request in flight / no spam | Recruit shows "Recruiting…" and ignores taps (M3); Send is "Sent" for 3 s (M5); one `Army.Command` per tap |
| Malformed pushes | objectives push not a table → ignored; bad entries dropped; malformed `Match.Ended` ignored; never an error (specs; M11) |
| FORGE-05 M1 | Recruit and Send faces, the count, tracker rows and bars, and the summary keep their instances across a treasury push, another kingdom's building push, a population push and an objective push; the kept buttons still act (spec; M1, M2) |
| Colour never the only signal | bars carry the kingdom name and a percentage; owner chip = swatch + name; "you" / "AI" tags; winner crown |
| Phone ≥ 44 px | Recruit, Send, −, +, close, tab hit areas (44 px on phones, also the upgrade panel's Army tab), the tracker, Continue, the rail button (spec) |
| Phone fit | 844 × 390: drawer without scrolling, tracker left of the drawer, toasts below the tracker when a drawer is open (spec; M10), summary 262 px tall (≤ 390 − 2 × 58) |
| Studio | **unverified**: U14 (`roblox/studio-tests/ui-economy.md`) |

## 5. Open (handoff `production/handoffs/2026-10-12-forge-03-to-forge-01-army-ui.md`)
- FORGE-01 to confirm: the target rule for a capture order without `targetId`, the Army.Recruit reason
  vocabulary, when `byJob.soldier` rises (on recruit or when training ends), the push rate of
  `Army.Objectives`, and `Match.Ended` to every player.
- No training queue in the contract: the drawer shows no queue (toast "They train at the barracks").
  An additive `Army.Training` push is proposed for VS-2; the UI degrades without it.
- BuildingLevels says "Recruit up to 5 soldiers" at barracks Lv 1 while the contract allows count
  1..10 per request: the client does not enforce a cap (server-authoritative); FORGE-01 decides.
