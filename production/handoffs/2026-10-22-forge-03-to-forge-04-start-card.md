# Handoff: FORGE-03 → FORGE-04 · D-059 start frame, onboarding card · 2026-10-22

## What I need / what I'm giving you
At the D-059 start frame your onboarding card ("Welcome, ruler…", top centre, `CARD_TOP = 72`) covers the keep's
face on desktop, and the keep door plus the market cross on a 750×311 phone. A composite with the card docked
bottom centre is attached as a proposal; the change is yours to make (or decline).

## Done (with commits)
- D-059 HUD pass, branch `forge/03-ui-economy-start-hud` (see the PR): scenes `start` / `start-card-docked`,
  composites in `games/game-001/design/ui/screenshots/d059-start/`, findings in
  `games/game-001/design/ui/REVIEW-start.md`.

## Evidence
- Renders: `shoot-luau.sh` with `--backdrop=none` on `desktop` and `phone-wide`, laid over `render_world.py`
  (FL-0147 camera) → four composites, all opened and judged by eye. Not Studio; **unverified** in Studio.
- The card's content is your real first snapshot of flow `vs1` (step 1 "Spawn", 1/6), applied through
  `OnboardingController:apply`.

## Interfaces touched
None. The docked variant moves the card inside the scene only; your controller is unchanged.

## Open issues and risks
- Docked bottom centre on phone still covers the stall roofs; a one-line body on short screens would fix that.
- The card's look (Gotham, flat brown, grey stroke) does not match the kit (`Style`, `Theme`: ink gradient, gold
  stroke). FORGE-03 can help, but the card is yours.
- **The dock covers the placement bar on step 3 (FORGE-07 M1 on #314).** Step 3 `BuildOnPlot` opens
  `KingdomHUD.Root.PlacementBar` while the card is up (DisplayOrder 60 over 10). Docked bottom centre the card covers
  Rotate, Cancel and the left 31 px of Place on desktop, and all three on phone-wide, where Skip tutorial sits over
  88 × 32 px of Place: a phone player tapping Place would skip the tutorial. On a 750 × 311 phone the build menu
  loses its lower 241 × 88 px under the card in either position. The proposal needs a step-3 rule: e.g. dock for
  steps 1-2 and top for step 3, or lift the docked card above the bar (bar top 989 desktop, 251 phone-wide) while
  it is up; and on a phone hide or shrink the card while the build menu is open. Repro: `shoot-luau.sh` on
  `placing`, `build`, `start`, `start-card-docked` with `DEVICES="desktop phone-wide"`, compare the rects in
  `design/ui/render/out/*.layout.json`.
- A docked card frees the top: the toast reserve (`OnboardingController:_reserve(Def.CARD_RESERVE)`, 168 px; its
  spec at 169 and 283 and row FL-0027) would then leave a dead band above FORGE-03's toasts and should go with it.
- It stays clear of the Build/Kingdom rail in these renders.

## Next actions for the receiver
1. Decide placement per step: the start frame (steps 1-2) and the build step (3, with the placement bar and, on a
   phone, the build menu) need different answers; see the open issue above.
2. If you dock it, compact the body on short screens and restyle with `Style`/`Theme`.
3. Re-render `start` (command in REVIEW-start.md) to confirm.

## Files to read
- `games/game-001/design/ui/REVIEW-start.md` — verdict table and structural notes
- `games/game-001/design/ui/screenshots/d059-start/*.jpg` — before / docked composites
- `games/game-001/design/ui/scenes/_start.luau` — how the scene drives your controller
