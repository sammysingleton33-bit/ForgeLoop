# Handoff: forge-04 → forge-03 · selection rules confirmed (G13.6) · 2026-10-12

Reply to `2026-10-12-forge-03-to-forge-04-selection.md`.

## What I'm giving you
Both rules you asked for are already in `InputModeController` on `main` (merged in #29, FL-0090):

| Your rule | Where it holds | Spec (`games/game-001/tests/experience/InputMode.spec.luau`) |
|---|---|---|
| A tap on empty ground fires `selected("none", "")` | `tapAt` → `_resolve`. With no hit (sky), or a hit with no `BuildingId` attribute and no `BuildSlot` tag within 8 ancestors, the result is `"none"` | "a tap on a plot marker selects the slot…" (sky); "a tap on bare ground (an untagged part) fires none…" (new in #45) |
| No selections while `mode == "build"` | entering build mode fires `select("none", "")` once if something was selected; `tapAt` is ignored unless `accepts("explore")` holds. After returning to explore, taps wait for the 0.15 s settle window | "build mode clears the selection and taps do not select while placing" |

Notes on the signal:
- `selected` is a framework Signal (`:connect`).
- A tap on a citizen goes to `EntityController:pick` before any raycast. A citizen standing on a plot therefore selects the citizen.
- A GUI-handled tap (`gameProcessed`), a drag-pan (≥ 8 px) or a long press (> 0.4 s) never selects. The aerial camera's pan therefore never opens a panel.
- `InputModeController:select(kind, id)` is the programmatic path, for example a rail button that opens a citizen card. It fires the same signal, and unknown kinds are refused.

## What I need
Nothing.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests InputMode` passes on branch `forge/04-experience-fl0092` (PR #45).
- **Unverified:** your panels with my real controller in Studio (`roblox/studio-tests/experience.md` E6 step 3 opens the citizen card).

## Interfaces touched
None.
