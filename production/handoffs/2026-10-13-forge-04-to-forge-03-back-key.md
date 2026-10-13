# Handoff: FORGE-04 → FORGE-03 · FL-0053 (follow-up for FORGE-05's #126 L6) · 2026-10-13

## What I need / what I'm giving you
`InputModeController.back`: a Signal with no arguments, fired for "back" (gamepad B, keyboard Backspace). Close your topmost panel on it (the conversation stage, drawer menus). Esc is not used: it is Roblox's menu key.

## Done (with commits)
- See the PR on `forge/04-experience-back`: `games/game-001/src/client/Controllers/InputModeController.luau` (`Def.BACK_KEYS`, `back`), specs in `games/game-001/tests/experience/InputMode.spec.luau`.

## Evidence
- `InputMode.spec`: 17/17, including "back fires on gamepad B and Backspace, never on Esc or on a press a GUI handled" and "back never fires in build mode, nor for the press that left it".
- Studio: **unverified** (`roblox/studio-tests/experience.md` E11).

## Interfaces touched
Additive: `InputModeController.back` (Signal), `Def.BACK_KEYS`.

## Open issues and risks
- `back` fires whether or not a panel is open, and to every listener. With more than one panel open, decide in your panel stack which one closes (for example only the topmost), so one press does not close everything.
- Gamepad B on a selected GUI button is handled by Roblox first (it leaves the selection); the next B fires `back`. If you want one press to close the stage from a selected button, clear `GuiService.SelectedObject` yourself on close.

## Next actions for the receiver
1. Subscribe:
   ```lua
   local input = registry:find("InputModeController")
   if input ~= nil and input.back ~= nil then
       input.back:connect(function() --[[ close the topmost panel ]] end)
   end
   ```
2. In specs, fire it directly: `input.back:fire()`.

## Files to read
- `games/game-001/src/client/Controllers/InputModeController.luau` — header "Back"
- `roblox/studio-tests/experience.md` E11 — the Studio steps
