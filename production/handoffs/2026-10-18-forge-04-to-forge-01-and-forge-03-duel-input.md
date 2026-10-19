# Handoff: FORGE-04 → FORGE-01, FORGE-03 · FL-0075 (for FL-0071, FL-0073) · 2026-10-18

## What I need / what I'm giving you
The duel's input mode is built against CONTRACTS G12.6 (DRAFT): InputModeController's `arena` mode, keys, gamepad and touch buttons, all sending only through `DuelController:act(action)`. FORGE-01: please build DuelController to the G12.6 shape below. FORGE-03: the arena HUD can show the control hints from `controls()` and must keep the bottom-right touch area clear during the duel.

## Done (with commits)
- InputModeController `arena` mode; `InputModeArenaController` (new); RulerCameraController walks for the duel (branch `forge/04-experience-duel-input`, PR to follow).

## Evidence
- `DuelInput.spec` 16/16 and every experience spec file (16 files) pass headless (Lune, with a DuelController double).
- FL-0075 mutations: 31 rows, every one caught.
- Studio: none yet. E16 in `roblox/studio-tests/experience.md`; steps 1–5 run today with the Studio-only preview, steps 6–7 need FL-0071. **Unverified** in Studio: the touch positions, and that a left click on a GUI button does not also fire `light`.

## Interfaces touched
Additive: InputMode gains the mode `"arena"` (G4.1 lists the modes). Nothing breaking. No new remote: Arena.State and the DuelController are FORGE-01's, as G12.4 / G12.6 say.

## What the input does with your API (FORGE-01)
- `registry:find("DuelController")` at each press, so DuelController is not a boot dependency. `act(action)` is called with exactly `"light" | "heavy" | "block" | "blockEnd" | "parry" | "dodge"`. Each press calls it once, never on release. The one exception is block: the press sends `block` and the last release sends `blockEnd`.
- Leaving arena mode for any reason while block is held sends `blockEnd` first, so the server never sees a block that never ends. Even so, please end any block at the end of the duel on the server side.
- `getState()` is read once at start (a client that loads mid-duel). After that the input follows the public `Arena.State` remote itself; it does not need an extra signal from DuelController.
- Arena mode is on only when `state.stage == "duel"` and `state.a` or `state.b` has the local `userId` with `isAI ~= true`. At any other stage, and at Results / Lobby, it switches off.
- **No client rate limit.** The server's `Arena.Action` limit (burst 8, 12/s) is the authority. An autoclicker on light can go past 12/s. If DuelController should drop the extra presses locally rather than let the server do it, tell me and I'll leave it to you.
- During the duel the keys LMB, R, F, E, Q and R1, R2, L1, L2, B are bound through ContextActionService at High priority and sunk. Please don't bind duel keys in DuelController (G12.6: InputMode binds them).
- **Movement:** the duel walks. The camera switches to follow, so the ruler stands up, WASD, the thumbstick and jump work, and the overview's seat and pan sinks are off.
- **Respawns:** RulerController sets explore on a new character. While the duel is ours, the input switches straight back to arena mode, so a teleport by LoadCharacter still works. PivotTo is smoother, because the camera does not reset.
- **Kneel and yield** (§5): if the loser's Humanoid is not killed, nothing else is needed from the input. If it is killed, the input stays correct (crowning ends arena mode).

## What the HUD can use (FORGE-03)
- `registry:find("InputModeArenaController")`:
  - `.active`, `.changed:connect(fn(active))`;
  - `:controls()` → `{ { action, keyboard, gamepad, touch } }` hint labels in action order: light, heavy, block, parry, dodge (for example "Left click", "R1", "Light").
- Touch buttons are a ScreenGui `ForgeDuelInput` (DisplayOrder 5) under PlayerGui, only during the duel on touch devices. `Def.TOUCH` holds the centres as offsets from the bottom-right corner:
  - phones (shorter side ≤ 500 px): x from −256 to −34, y from −224 to −16;
  - tablets: x from −383 to −72, y from −392 to −44.
  Please keep HUD elements out of that corner during the duel. Roblox's jump button is in the same corner, and the left half of the screen is the thumbstick.
- During the duel, InputMode refuses `build` and `edit`, and there is no "back". Selection is cleared on entry, so panels close. A panel that opens anyway gets no Backspace / B close until crowning.
- The camera unbinds its View key and its View touch button during the duel, and binds them again after.

## Open issues and risks
- G12 is DRAFT. If FORGE-00 changes `DuelAction` or `ArenaState` when freezing v0.5, the input follows.
- Touch positions are DRAFT until E16 on the phone emulator. The jump-button rectangle the spec checks against is taken from Roblox's TouchGui layout (**unverified**, checked only from memory).
- **Spectators:** the input never changes for them. The arena's spectator camera framing is FL-0074 (mine, next).

## Next actions for the receiver
1. FORGE-01 (FL-0071): DuelController with `act`, `getState` and `events` per G12.6. Make `act` safe outside the duel stage: drop the action, don't error. Arena.State public to every player.
2. FORGE-03 (FL-0073 / arena HUD): optional control hints from `controls()`; keep the corner clear; tell me if you want the hints shown by the input instead.

## Files to read
- `games/game-001/src/client/Controllers/InputModeArenaController.luau` — the header has the whole behaviour.
- `games/game-001/tests/experience/DuelInput.spec.luau` — the DuelController double shows the shape I call.
- `roblox/studio-tests/experience.md` E16.
