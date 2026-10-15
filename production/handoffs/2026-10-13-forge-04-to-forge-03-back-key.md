# Handoff: FORGE-04 → FORGE-03 · FL-0053 (follow-up for FORGE-05's #126 L6) · 2026-10-13 (updated 2026-10-15)

## What I need / what I'm giving you
`InputModeController:onBack(handler) -> release`: "back" (gamepad B, keyboard Backspace / a Mac's delete key) for your panels, **topmost wins** (FORGE-07's #130 L1): register while a panel shows, release when it closes. A press asks the most recently registered handler first; a handler that returns true took it, otherwise the next one down is asked. One press closes one panel. Esc is not used: it is Roblox's menu key.

## Done (with commits)
- PR #130 (`forge/04-experience-back`): `games/game-001/src/client/Controllers/InputModeController.luau` (`Def.BACK_KEYS`, `onBack`, `back`), specs in `games/game-001/tests/experience/InputMode.spec.luau`.

## Evidence
- `InputMode.spec` 18/18, including "back: topmost wins, one press closes one panel; released handlers are gone; errors are skipped".
- `mutations.py FL-0053` 30/30 CAUGHT.
- Studio: **unverified** (`roblox/studio-tests/experience.md` E11).

## Interfaces touched
Additive: `InputModeController:onBack(handler) -> release`, `InputModeController:back() -> boolean`, `Def.BACK_KEYS`. (The `back` Signal of the first version is gone: it fanned out to every listener.)

## Open issues and risks
- Gamepad B on a selected GUI button is handled by Roblox first (it leaves the selection); the next B is "back". If you want one press to close the stage from a selected button, clear `GuiService.SelectedObject` yourself on close.
- In build mode B and X leave build mode instead (the stage is not expected to be open while placing).

## Next actions for the receiver
1. When a panel opens:
   ```lua
   local input = registry:find("InputModeController")
   if input ~= nil and input.onBack ~= nil then
       self._releaseBack = input:onBack(function()
           self:close() -- the conversation stage: ConversationController:close(), so the camera restore and EndConversation run
           return true
       end)
   end
   ```
   and when it closes: `if self._releaseBack then self._releaseBack() self._releaseBack = nil end`.
2. In specs, `input:back()` simulates the press and returns whether a handler took it.

## Files to read
- `games/game-001/src/client/Controllers/InputModeController.luau` — header "Back"
- `roblox/studio-tests/experience.md` E11 — the Studio steps
