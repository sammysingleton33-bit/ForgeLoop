# Handoff: forge-04 → forge-01, forge-03, forge-05 · ruler controls, camera modes, input-mode arbitration · FL-0053 · 2026-10-12

## What I'm giving you
FL-0053 adds three client controllers in `games/game-001/src/client/Controllers/`:
- `InputModeController` (G4.1);
- `RulerController`;
- `RulerCameraController` (G4.1).

The contract API is unchanged (`set`, `mode`, `changed`, `setMode`). The additions below are optional conveniences.

### Keys and buttons (FORGE-05: for `STUDIO_PLAYTEST.md` §3, "exact keys filled in by FL-0053")
| Action | PC | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrow keys (Roblox default) | left stick | default thumbstick (G4.1) |
| Jump | Space | A | default jump button |
| Sprint | hold Left Shift | press L3 (toggle) | on-screen "Sprint" button (toggle) |
| Toggle view (follow ↔ overview) | V | Y | on-screen "View" button |
| Zoom | mouse wheel (follow: Roblox camera; overview: height) | Roblox default in follow; none in overview (VS-1) | pinch |
| Leave build mode | X | B | FORGE-03's Cancel button |

- A toggled sprint ends when the ruler stops.
- Entering build mode switches the camera to overview. Leaving build mode restores the previous view, unless the player picked a view themselves while building.

## What I need
### FORGE-01 (InteractionController, or wherever world taps are handled)
- Act on a tap or click only in explore mode. Use `registry:find("InputModeController")`, then either `mode == "explore"` or, better, `accepts("explore")`.
- `accepts(mode)` is false for 0.15 s after a mode change. So the tap that ends build mode (a placement confirm) is not also taken as a gather.
- RulerController returns input to explore when the ruler dies, respawns or leaves. KingdomService's `LoadCharacterAsync` respawn (G3) triggers that through `Player.CharacterAdded`.
- RulerController exposes `characterChanged`, `getRoot()` and `getHumanoid()` if your client code needs the local ruler.

### FORGE-03 (BuildMenuController, PR #19)
- No change is needed. Your `set("build")` and your `changed` → cancel already match.
- X or gamepad B now also leaves build mode. Your `changed` handler cancels the ghost, as your spec "leaving build mode elsewhere" expects.
- Optional: check `accepts("build")` before you take a world tap as a placement.
- The camera goes to overview (a top-down view at 55°) while in build mode, which makes ghost placement easier on phones. Tell me if your placement ghost assumes the follow camera.
- The touch buttons "Sprint" and "View" are ContextActionService buttons at their default positions near the jump button. If they overlap your HUD on a phone, tell me and I'll move them with `SetPosition`.

### FORGE-05 (project file, `games/game-001/default.project.json`)
- Please set `StarterPlayer.EnableMouseLockOption = false`. Left Shift is Roblox's default shift-lock key. RulerController binds sprint at High priority and sinks the key, but shift lock would also fight smooth turning (Humanoid.AutoRotate is off). It is not needed with this camera.
- Please add the keys table above to `STUDIO_PLAYTEST.md` §3. My Studio checklist for the same row is in the FL-0053 PR body.

## Evidence
- `games/game-001/tests/experience/{InputMode,Ruler,RulerCamera}.spec.luau`: 6 + 11 + 14 specs.
- The game-001 boot gate boots the three controllers without a camera, character or input services.
- 18 mutation rows, all caught (listed in the PR).

## Unverified
- How any of this feels, on PC or the phone emulator. That is the user's Studio check (BRIEF §4 row 2).
- Smooth turning uses an AlignOrientation on the root. If it misbehaves in Studio (jumping, slopes, seats), set `turn.mode = "engine"` in `RulerController.DEFAULTS`; that restores Roblox's AutoRotate.

## Files to read
- `games/game-001/src/client/Controllers/InputModeController.luau`: arbitration rules.
- `games/game-001/src/client/Controllers/RulerController.luau`: sprint and turning.
- `games/game-001/src/client/Controllers/RulerCameraController.luau`: modes, build mode, shake.
