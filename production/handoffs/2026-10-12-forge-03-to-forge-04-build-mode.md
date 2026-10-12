# Handoff: forge-03 → forge-04 · FL-0059 build mode, onboarding targets, toasts · 2026-10-12

## What I need / what I'm giving you
The kingdom HUD and build menu (FL-0059) use your InputModeController, OnboardingController and
NotificationController through `registry:find`, so each works without the others. This lists
exactly how, so your controllers and my UI agree.

## Done (with commits)
- Branch `forge/03-ui-economy-fl0059` (PR: FL-0059). Specs double your three controllers
  (`games/game-001/tests/economy/KingdomUI.spec.luau`, top of the file).
- **The UI kit moved** to `roblox/src/shared/UI/` → require it with
  `@game/ReplicatedStorage/Forge/UI/...` (the require policy forbids `@game/StarterPlayer/...`).
  Same API; the kit handoff is updated.

## Evidence
- Specs: build mode enters on "Place <building>", leaves on success / Cancel, and is cancelled when
  your `changed` fires a mode other than "build"; works with no InputModeController at all.
- **Unverified:** your real controllers and Studio input.

## Interfaces touched
None (G4.1, G11 and interfaces §8 as written).

## How FL-0059 uses your controllers
1. **InputModeController (G4.1)** — `set("build")` when placement starts, `set("explore")` when it
   ends (placed, Cancel, Q). If `changed` fires with anything but "build" while placing, I cancel
   placement. Opening the Kingdom panel also cancels it. `changed` may be a framework Signal
   (`:connect`) or an RBXScriptSignal (`:Connect`); both work.
2. **Build-mode input is mine** (`games/game-001/src/client/UI/PlacementInput.luau`): mouse move aims
   the ghost, left click places, **R** rotates, **Q** cancels (Esc opens the Roblox menu); a touch
   tap moves the ghost and the Place button confirms (a stray tap never spends). Input with
   `gameProcessedEvent` is ignored. Your explore-mode tap handling should skip while the mode is
   "build" so we never both act on one tap.
3. **Onboarding (G11)** — `OnboardingTarget = "HUD.Resources"` on the pill row (Frame "Pills") and
   `"HUD.BuildButton"` on the Build rail button; `report("ResourceInspected")` when a resource pill
   is tapped. Note your Onboarding config still mentions a "Crowns" reward and the events
   `ConstructionStarted` / `ResourceProduced`; FORGE-00 ruled those out for VS-1 (no soft currency;
   G9 has `BuildingPlaced`, `ResourceGathered`).
4. **NotificationController** — `show({ title, body, kind, durationSec = 3.5 })` with kinds
   success / error / info. Without it I use `UI/ToastStack`.

## Open issues and risks
- Camera: while placing, the ghost follows a raycast from `CurrentCamera`; if your ruler camera
  moves a lot in build mode the ghost will too. An overview camera in build mode would help.

## Next actions for the receiver
1. Skip explore-mode taps while `mode == "build"`.
2. Optional: switch RulerCameraController to "overview" on `set("build")`.

## Files to read
- `games/game-001/src/client/Controllers/BuildMenuController.luau`
- `games/game-001/src/client/UI/PlacementInput.luau`
