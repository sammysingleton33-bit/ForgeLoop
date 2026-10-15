# Handoff: FORGE-04 → FORGE-03, FORGE-05 · FL-0115 (B15 bubble readability; FL-0091 follow-up) · 2026-10-15

## What I need / what I'm giving you
The world citizen bubbles are readable and tappable from the aerial view (the user's first live Studio feedback; FORGE-00's B15 target). A tap on a bubble selects its citizen through `InputModeController:select("citizen", id)` (G13.6), so FORGE-03's card opens exactly as for a tap on the citizen. Nothing changes in FORGE-03's files.

## Done (with commits)
- Branch `forge/04-experience-bubbles` (PR: see the PR list), in `CitizenBubbleController`, `Feedback/Bubbles` and `config/Vfx.luau` (`bubbles`):
  - always on top (roofs and trees never hide a bubble); the bubble's bottom edge sits above the head;
  - a request is a round glyph badge (46 px: "!" gold, "?" blue, "…" green; the glyph carries the meaning) and, where there is room, a 260 × 66 card with 17 px words (2 lines, then "…");
  - `Bubbles:layout`: at most 3 bubbles show words (2 on a phone, 1 zoomed out past 150 studs), only where the card covers no other bubble on screen; every request's badge is reserved first, so a request is never hidden; a reaction without room is not drawn (pose, sound and effect still play);
  - a new request's badge pops twice (UI/Motion), never under reduced motion;
  - the BillboardGuis live under PlayerGui (Roblox gives BillboardGui input only there), `ResetOnSpawn` off, `Active` only in explore mode, so a click while placing still places.

## Evidence
- `CitizenBubbles.spec` 39/39 (layout, text limit, pulse, tap through the real InputModeController, build mode, pooled GUIs).
- `mutations.py FL-0115` 12/12 CAUGHT (new rows); `mutations.py FL-0091` 43/43 CAUGHT (2 retargeted).
- Headless renders (not Studio): `roblox/tests/unit/experience/scenes/shots/bubbles-{start,max}-{phone,desktop}.png`, a kingdom projected through the real overview camera at zoom 120 (start) and 220 (max), with the real layout rules.
- Studio: **unverified** (`roblox/studio-tests/experience.md` E8 steps 9–11 and the operator probe).

## Interfaces touched
Additive: `CitizenBubbleController:tap(entityId)`, `Def.paint`, `Def.SIZE`, `Def.BADGE`, `Def.PULSE`; `Bubbles:layout`, `Bubbles:textLimit`, `Bubbles.SIZES`; `Vfx.bubbles.{withText, withTextPhone, withTextFar, farZoom, gapPixels}`.

## Open issues and risks
- On a phone at full zoom-out, badges of requests a few studs apart still overlap each other (none is hidden by a card). Finding requests in a crowd is FORGE-00's B16 item (cycle requests with `focusOn`; FORGE-03's "citizens waiting" control).
- Roblox's draw order between AlwaysOnTop billboards is the engine's: where two badges touch, which is in front is not controlled.
- Hover outline on citizens: next, in `InputModeController` (FORGE-03's proposal); not in this change.

## Next actions for the receiver
1. FORGE-03: when the selected citizen has a request, make **Talk** the card's primary action (your proposal), so bubble → Talk is two taps.
2. FORGE-05: gate as ★ B15; Studio E8 steps 9–11 with the operator probe in E8.

## Files to read
- `games/game-001/src/client/Controllers/CitizenBubbleController.luau` — header "View"
- `games/game-001/src/shared/Feedback/Bubbles.luau` — Rules: layout(), textLimit()
