# Handoff: forge-04 → forge-01, forge-02, forge-03, forge-05 · aerial camera, selection, ruler controls, input modes · FL-0053 + FL-0090 · 2026-10-12

## What I'm giving you
FL-0053 and FL-0090 (D-030, CONTRACTS G4.1 and G13.6) add three client controllers in `games/game-001/src/client/Controllers/`:
- `InputModeController`: `set`, `mode`, `changed`, plus `selected` (G13.6);
- `RulerCameraController`: `setMode("overview" | "follow")`. The default is `overview`;
- `RulerController`.

### Keys and gestures (FORGE-05: for `STUDIO_PLAYTEST.md` row 2)
| Action | PC | Gamepad | Touch |
|---|---|---|---|
| **Overview (default): pan** | WASD / arrow keys, or left-drag | left stick | one-finger drag |
| Overview: zoom (40–220 studs) | mouse wheel | — | pinch |
| Overview: rotate | Q / E, or right-drag | right stick | two-finger twist |
| Select a citizen, building or plot | click | — | tap |
| Toggle overview ↔ walk | V | Y | on-screen "View" button |
| Walk mode: move / jump | WASD, Space | left stick, A | default thumbstick and jump |
| Walk mode: sprint | hold Left Shift | L3 (toggle) | on-screen "Sprint" button (toggle) |
| Leave build mode | X | B | FORGE-03's Cancel button |

- In the overview the ruler stays seated. Movement and jump keys are sunk, and the touch thumbstick is hidden.
- Q / E are not bound in build mode, because FORGE-03's placement rotates with Q / R.
- Build mode always uses the overview. Leaving it restores the previous view, unless the player picked one meanwhile.
- The camera's focus asks the server to stream around it (`Player:RequestStreamAroundAsync`, throttled to once per 128 studs and per second).

## What I need
### FORGE-01
- **Throne (G13.6):** seat the ruler on `Throne` after spawn. My overview starts focused on the ruler's root, which is the throne. Entering walk mode calls `RulerController:standUp()` (Humanoid.Jump); re-seating afterwards is yours if you want it.
- **`EntityController:pick(screenPos)`** (G4.1): InputModeController calls it first on every explore-mode tap, so a citizen wins over the ground behind it.
- **Taps:** don't raycast for selection yourself (G13.6). Listen to `InputModeController.selected` if you need it. Ruler gathering is optional in VS-1; if you keep it, act only when `accepts("explore")`.
- RulerController returns input to explore when the ruler dies, respawns or leaves.

### FORGE-02
- Building models need the attribute `BuildingId` on the model (or any ancestor of the hit part, at most 8 levels up). Slot markers need the `BuildSlot` tag and the `SlotId` attribute (G13.5). Tell me if the attribute sits elsewhere.
- Please make the throne dais readable from 40–220 studs at 38°–65° pitch, so the seated ruler is visible from the default view.

### FORGE-03
- **Selection (G13.6):** your citizen card, building panel and plot menu listen to `registry:find("InputModeController").selected:connect(function(kind, id) ... end)`.
  - kind: `citizen` (EntityId), `building` (BuildingId), `slot` (SlotId) or `none` (clear).
  - Entering build mode sends `none` first.
  - `input:select(kind, id)` is the programmatic path, for a list row or a "go to" button.
- `RulerCameraController:focusOn(position)` moves the overview to a position, clamped to the map.
- Your `set("build")` and `changed` handling (PR #19) need no change. Q / R stay yours in build mode.
- The touch buttons "View" and "Sprint" are ContextActionService buttons at their default positions. Tell me if they overlap your HUD.

### FORGE-05
- Please set `StarterPlayer.EnableMouseLockOption = false`. Left Shift is the shift-lock key, and shift lock fights smooth turning in walk mode.
- Please add the keys table above to `STUDIO_PLAYTEST.md` row 2. My Studio checklist is in the PR body.

## Evidence
- Specs in `games/game-001/tests/experience/`: InputMode 13, Ruler 12, RulerCamera 21. The camera specs use the real `world/Layout` for the map bounds.
- The game-001 boot gate boots all three controllers without a camera, character or input services.
- Mutation rows, all caught: 18 for FL-0053 and 15 for FL-0090.

## Unverified
- The feel of the aerial camera on PC and the phone emulator, and the seated ruler's visibility. That is the user's Studio check (BRIEF §4 row 2).
- Whether streaming keeps up when panning far.
- Smooth turning in walk mode. If it misbehaves, set `turn.mode = "engine"` in `RulerController.DEFAULTS`.

## Files to read
- `games/game-001/src/client/Controllers/InputModeController.luau`: arbitration and selection.
- `games/game-001/src/client/Controllers/RulerCameraController.luau`: overview, walk mode, build mode, shake.
- `games/game-001/src/client/Controllers/RulerController.luau`: sprint, turning, standUp.
