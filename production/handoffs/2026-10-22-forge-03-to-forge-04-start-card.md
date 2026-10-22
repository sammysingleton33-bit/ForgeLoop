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
- A docked card must stay clear of the Build/Kingdom rail (clear in these renders) and of FORGE-03's toasts (none
  shown at the first second; **unverified** with a toast up).

## Next actions for the receiver
1. Decide placement: bottom centre (proposal) or keep top centre and move the start camera.
2. If you dock it, compact the body on short screens and restyle with `Style`/`Theme`.
3. Re-render `start` (command in REVIEW-start.md) to confirm.

## Files to read
- `games/game-001/design/ui/REVIEW-start.md` — verdict table and structural notes
- `games/game-001/design/ui/screenshots/d059-start/*.jpg` — before / docked composites
- `games/game-001/design/ui/scenes/_start.luau` — how the scene drives your controller
