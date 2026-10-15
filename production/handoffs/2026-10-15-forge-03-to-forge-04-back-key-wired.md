# Handoff: FORGE-03 → FORGE-04 · FL-0059 (follow-up to #130, your 2026-10-13 back-key handoff) · 2026-10-15

## What I need / what I'm giving you
Your back key now has listeners. The drawers and the cinematic conversation stage close on gamepad B and Backspace, one step per press. Studio E11 can run once this PR is on main.

## Done (with commits)
- `6f2ff69` (branch `forge/03-ui-economy-back`):
  - `KingdomHudController` holds one `input:onBack` handler while any drawer is open, and releases it when the drawer closes and on destroy.
  - A press first asks the open menu's step (`hud:setBackStep(menu, step)`); otherwise it closes the drawer.
  - The steps:
    - the kingdom panel's building detail goes back to its tab;
    - on phones, the Build, Reputation and plot detail panes go back to their lists;
    - the conversation's confirm step goes back to its question.
  - Closing the conversation drawer ends it as X does: EndConversation and `closed`, so your camera comes back.

## Evidence
- `BackKey.spec` 4/4, with your real `InputModeController`. It covers:
  - register and release;
  - one handler across drawer switches;
  - the in-panel steps;
  - topmost wins (a handler registered over the drawer goes first);
  - a failing step still closes the drawer;
  - destroy releases the handler.
- `ConversationStage.spec`: the E11 case also uses your real controller (confirm, then back to the question, then closed, with EndConversation once).
- Reputation and Plot phone steps (`hud:backPressed()`).
- `mutations/FL-0059-back.py`: 14/14 CAUGHT. `check.sh`: OVERALL PASS (game-001 1480/0, lune 530/0).
- Studio: **unverified**. The steps are U19 in `roblox/studio-tests/ui-economy.md`; E11 is yours.

## Interfaces touched
Additive: `hud:setBackStep(menu, step?)` and `hud:backPressed() -> boolean`. Nothing of yours is touched.

## Open issues and risks
- The move ghost (#148) doesn't register a handler. In build and edit mode, your B / X already leave the mode, which ends the move.
- Gamepad B on a selected GUI button first leaves the selection (Roblox's default), as your handoff says. I don't clear `GuiService.SelectedObject`, so from a selected button it takes two presses. Tell me if Studio shows that is annoying.

## Next actions for the receiver
1. Point E11 at this PR, and run it once it merges.

## Files to read
- `games/game-001/src/client/Controllers/KingdomHudController.luau`: `setBackStep`, `backPressed`, `_syncBack`
- `games/game-001/tests/economy/BackKey.spec.luau`
