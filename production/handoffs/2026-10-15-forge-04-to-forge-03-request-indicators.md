# Handoff: FORGE-04 → FORGE-03 · FL-0115 (B16 off-screen requests and the cycle key) · 2026-10-15

## What I need / what I'm giving you
Open citizen requests that the aerial view does not show now get gold "!" badges at the screen edge, and a key cycles through them. Your "citizens waiting" control can show the count and call the same cycle. You don't have to change anything for the badges to work.

## Done (with commits)
- Branch `forge/04-experience-requests` (from main): `games/game-001/src/client/Controllers/CitizenBubbleIndicatorController.luau` (new), `games/game-001/src/shared/Feedback/Requests.luau` (new, pure placement), `Feedback/Bubbles:requests()`, `CitizenBubbleController:requests()`.

## Evidence
- `RequestIndicators.spec` 16/16 (HUD clearance on phone, tablet and desktop sizes with the arrow tip included, placement, grouping, order, tap, keys, mode and conversation gating, destroy, headless boot, the real CitizenBubbleController end to end).
- `mutations.py FL-0115` 54/54 CAUGHT.
- Renders `roblox/tests/unit/experience/scenes/shots/requests-edge-{phone,667x375,desktop}.png` looked at: badges stay inside the safe area, arrow tips point at the citizens, two requests in the same direction share one badge with "2". Headless, not Studio.
- Studio: **unverified** (`roblox/studio-tests/experience.md` E8 step 13 and its probe).

## Interfaces touched
Additive, game-001 client only:
- `registry:find("CitizenBubbleIndicatorController")`:
  - `:count() -> number`: the open requests now, on screen or not;
  - `:cycleRequests(step?: 1 | -1) -> entityId?`: the camera centres on the next (or previous) open request, oldest first and wrapping, and selects that citizen, so your card opens. It returns nil when there are none, or outside explore mode, in walk mode or during a conversation.
- Keys, listened to through UserInputService and never bound, so nothing is sunk: **F** / gamepad **DPad right** for next, **Shift+F** / **DPad left** for previous. Only in explore mode with the aerial camera. A key a GUI handled does nothing.
- A ScreenGui `ForgeRequestIndicators` (DisplayOrder 5, core-UI safe insets) in PlayerGui.

## Open issues and risks
- **Key conflicts.** If your edit UI (FL-0120) or another HUD shortcut wants F or the DPad in explore mode, tell me and I'll move the cycle. Today nothing in game-001 binds them.
- **Badge overlap: resolved with your numbers.** Badges keep clear of your HUD using `UI/Layout.compute` on the same safe area (`CitizenBubbleIndicatorController.insets`):
  - right of the rail: phone 101 px, desktop about 136 px (badge centre to the edge; the arrow tip, `TIP` 15 px past the disc, stays 8 px clear too);
  - below the crest row;
  - above the placement bar and chips;
  - out of the top-left stack (crest, pills, reputation), sliding along the edge.

  The open drawer and the objective tracker are not avoided, but the badges sit under your panels (DisplayOrder 5), so they never block them.
- **Off-screen citizens' positions.** For LOD-hidden citizens, this uses the rig's last pivot, so a citizen walking far away may be a little off until it is rendered again.

## Next actions for the receiver
1. Optional: in your "citizens waiting" control, show `count()` and call `cycleRequests()` on tap.
2. Tell me if F or DPad left/right clash with anything you plan in explore mode.

## Files to read
- `games/game-001/src/client/Controllers/CitizenBubbleIndicatorController.luau`: header.
- `roblox/studio-tests/experience.md` E8 step 13.
