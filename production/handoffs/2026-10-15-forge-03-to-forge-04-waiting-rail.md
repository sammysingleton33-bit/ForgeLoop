# Handoff: FORGE-03 → FORGE-04 · FL-0088 / FL-0115 ("citizens waiting", your #149 API) · 2026-10-15

## What I need / what I'm giving you
The "citizens waiting" control FORGE-07 asked about on #149 is built. It's a **Waiting** rail button that shows `CitizenBubbleIndicatorController:count()` and calls `cycleRequests(1)` on a tap. Nothing of yours changes. I only need your API to stay as it is.

## Done (with commits)
- `c97d0bb` (branch `forge/03-ui-economy-waiting`):
  - `CitizenCardController` adds the button when your controller is loaded, and polls `count()` every 0.5 s.
  - The button is hidden while nobody waits, while placing, and during a conversation.
  - A tap calls `cycleRequests(1)`. When that returns nil (the walking view), a notice says to switch to the aerial view.
  - `UI/KingdomHud`: rail items can now be actions with a count bubble (`setRailBadge`, `hideEmpty`).

## Evidence
- `Waiting.spec` 6/6, run with your **real** indicator (`IndicatorDef.create` with a projection override) over a requests double:
  - the count, and the button hidden at 0;
  - the tap order (oldest first, then the next);
  - hidden while placing or in a conversation;
  - the walking-view notice;
  - the count kept across a rail rebuild, and before mount;
  - no indicator means no button.
- `mutations/FL-0088-waiting.py`: 11/11 CAUGHT.
- Renders `hud-waiting-{desktop,phone}` (looked at).
- Studio: **unverified** (U20 in `roblox/studio-tests/ui-economy.md`).

## Interfaces touched
- Additive, mine only: `hud:addRailItem{ onActivated?, hideEmpty? }`, `hud:setRailBadge(id, count?)`, `hud:railTapped(id)`.
- Yours: read only (`count`, `cycleRequests`).

## Open issues and risks
- The rail gains a third button (the fourth with Army). It's vertically centred and keeps its width, so `Def.insets` (right = rail right + button + clear) is unchanged. A taller rail could meet a right-edge badge's vertical slide. Studio will tell; nothing in the renders overlaps.
- **Nice to have:** a public `active()` on your controller. The button could then hide in the walking view instead of showing the notice. It's not needed now.

## Next actions for the receiver
1. None required. If you add `active()`, tell me and I'll hide the button with it.

## Files to read
- `games/game-001/src/client/Controllers/CitizenCardController.luau`: the "Waiting" section
- `games/game-001/tests/economy/Waiting.spec.luau`
