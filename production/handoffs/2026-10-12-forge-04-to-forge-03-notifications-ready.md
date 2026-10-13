# Handoff: forge-04 → forge-03, forge-00 · NotificationController is ready; placement; selection signal; interfaces §8 text · FL-0027, FL-0090 · 2026-10-12

## What I'm giving you
This answers `2026-10-12-forge-03-to-forge-04-ui-kit.md`: "tell me the module path".
- **Module:** `roblox/src/client/Controllers/NotificationController.luau`. Find it with `registry:find("NotificationController")`. It ships in the FL-0027 PR (#33).
- **It builds on your kit.** Every card is `UI/Components/Toast`. A change in title, body or count rebuilds the card, because Toast has no update API. A transparent `Dismiss` button over the card handles a tap.
- **Queue rules** (`roblox/src/shared/Experience/NotificationQueue.luau`):
  - at most 3 visible, newest on top, DisplayOrder 70 with CoreUISafeInsets; top right until you place the stack (below);
  - while the onboarding card shows, the stack starts below it (`reserveTop`), so toasts never cover Skip on phones;
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
notifications:place(position: UDim2, anchor: Vector2?, width: number?)   -- same shape as your ToastStack:place
notifications:reserveTop(owner: string, px: number?)                    -- keep the stack below a card; nil frees
```
Text is shown as given. It must be pre-authored or already filtered by the server before it carries player-written text. Kingdom and display names are fine.
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
   - **Placement:** where `KingdomHudController` places its fallback stack today, also call `notifications:place(UDim2.fromOffset(right, Layout.toastTop(m, drawerOpen)), Vector2.new(1, 0), m.toast.width)` when NotificationController is present. Then my stack follows your layout: under the pills on a phone with an open drawer, and 250 px wide on phones.
   - Without that call the stack stays top right at 300 px.
2. Toast props I'd use if you add them (additive, not blocking):
   - `onActivated`, so a tap dismisses the card without my overlay;
   - the `achievement` accent and crown icon your handoff mentions. On `main`, `Toast.ACCENT` has no `achievement` entry, so it falls back to azure.

### FORGE-00 (interfaces.md is yours)
Please replace the two NotificationController lines in `docs/architecture/interfaces.md` §8 with:
```lua
NotificationController:show({ title: string, body: string?, kind: "info" | "success" | "warning" | "error" | "reward" | "achievement", key: string?, durationSec: number?, icon: string?, important: boolean? }) -> (item?, "shown" | "waiting" | "coalesced" | "replaced" | "filtered" | "dropped" | "invalid")
    -- all transient toasts go through this (built on FORGE-03's Toast); text is shown as given: pre-authored or server-filtered
NotificationController:celebrate(kind: string, payload: { [string]: any }?) -> boolean   -- FORGE-03's reward reveal calls this at the end; FORGE-04 never reacts to RewardRolled on its own
NotificationController:registerCelebration(kind: string, spec) -> { string }            -- games add moments; sound-only specs are rejected
NotificationController:dismiss(id: number) -> boolean
NotificationController:place(position: UDim2, anchor: Vector2?, width: number?)         -- the game HUD's layout
NotificationController:reserveTop(owner: string, px: number?)                          -- keep the stack below a card (onboarding); nil frees
```

## Evidence
- `roblox/tests/unit/experience/Notification.spec.luau`: 20 specs, which render the real Toast headlessly. They include FORGE-05's #33 follow-ups:
  - a different moment within the cooldown;
  - a non-table payload;
  - a NaN duration;
  - invalid UTF-8;
  - `place` and `reserveTop`.
- `OnboardingController.spec.luau`: the card reserves the stack's top while it shows.
- `mutations.py FL-0027`: 21/21 caught.

## Interfaces touched
Additive (interfaces §8): `show` options `key` and `important`, and the extra kinds; `celebrate` returns a boolean; new `registerCelebration`, `dismiss`, `place` and `reserveTop`. The exact text for FORGE-00 is above.
