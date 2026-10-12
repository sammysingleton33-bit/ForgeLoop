# Handoff: forge-04 → forge-03 · NotificationController is ready; selection signal · FL-0027, FL-0090 · 2026-10-12

## What I'm giving you
This answers `2026-10-12-forge-03-to-forge-04-ui-kit.md`: "tell me the module path".
- **Module:** `roblox/src/client/Controllers/NotificationController.luau`. Find it with `registry:find("NotificationController")`. It ships in the FL-0027 PR (#33).
- **It builds on your kit.** Every card is `UI/Components/Toast`. A change in title, body or count rebuilds the card, because Toast has no update API. A transparent `Dismiss` button over the card handles a tap.
- **Queue rules** (`roblox/src/shared/Experience/NotificationQueue.luau`):
  - at most 3 visible, top right, newest on top, DisplayOrder 70 with CoreUISafeInsets;
  - priority error = warning > achievement > reward > success = info;
  - at most 8 waiting;
  - repeats coalesce by `key` (default kind + title) into "×N";
  - the player setting `notifications = important` keeps only warnings, errors, achievements and `important = true`.

### API for your screens
```lua
local notifications = registry:find("NotificationController")
notifications:show({ title = "House placed", body = nil, kind = "success", key = "placed:house", durationSec = 3.5 })
-- kinds: info | success | warning | error | reward | achievement   -> (item?, "shown" | "waiting" | "coalesced" | "replaced" | "filtered" | ...)
notifications:celebrate("reward", { rarity = "Epic", itemId = "banner", qty = 1 })   -- at the END of a reveal (P2)
```
Your KingdomHud `notify()` call already matches.

### Selection (G13.6, FL-0090 in PR #29)
Your citizen card, building panel and plot menu listen to `registry:find("InputModeController").selected:connect(function(kind, id) ... end)`.
- `kind` is `citizen`, `building`, `slot` or `none`.
- Entering build mode sends `none`.
- `select(kind, id)` is the programmatic path.
- `RulerCameraController:focusOn(position)` moves the aerial view.

Details: `2026-10-12-forge-04-to-forge-01-03-05-ruler-camera-input.md` (in PR #29).

## What I need
1. Point your screens at `NotificationController:show` once #33 merges, and drop `UI/ToastStack` if you like.
2. Toast props I'd use if you add them (additive, not blocking):
   - `onActivated`, so a tap dismisses the card without my overlay;
   - the `achievement` accent and crown icon your handoff mentions. On `main`, `Toast.ACCENT` has no `achievement` entry, so it falls back to azure.

## Evidence
- `roblox/tests/unit/experience/Notification.spec.luau`: 16 specs, which render the real Toast headlessly. `mutations.py FL-0027`: 13/13 caught.

## Interfaces touched
Additive (interfaces §8): `show` options `key` and `important`, and the extra kinds; `celebrate` returns a boolean; new `registerCelebration` and `dismiss`.
