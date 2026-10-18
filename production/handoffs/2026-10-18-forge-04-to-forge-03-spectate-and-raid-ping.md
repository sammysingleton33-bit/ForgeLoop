# Handoff: forge-04 → forge-03 · FL-0130 part 2 → FL-0129 (spectate screen, raid ping button) · 2026-10-18

## What I need / what I'm giving you
FL-0129's spectate screen needs "a camera target list (FORGE-04 provides the camera)". The camera is `RulerSpectateController`, and the screen can drive it directly. A raid gets a camera ping, and I'd like a HUD button for it. The ping already works from the keyboard (G) and the gamepad (D-pad up).

### Spectate camera: `registry:find("RulerSpectateController")`
| Member | What it does |
|---|---|
| `active: boolean` | true while spectating |
| `changed: Signal<(active)>` | Show or hide the spectate screen on this. It turns on when Kingdom.State says our kingdom is no longer alive (our last kingdom is remembered, so a `mine = nil` after the fall still counts), and off at Results or Lobby |
| `targets() -> { target }` | The list for the screen, re-read on every call: battles first (the places hit in the last 20 s), then the keeps of the kingdoms still standing. `target = { kind = "battle" \| "keep", position, kingdom?, kingdomName?, count? }` |
| `select(index) -> target?` | The camera to one target (the screen's list) |
| `cycle(1 \| -1) -> target?` | Next or previous, wrapping. The keys do the same: `.`/`,` (keyboard), R1/L1 (gamepad) |
| `targetChanged: Signal<(target)>` | Highlight the current row |
| `setActive(on) -> boolean` | Start or end by hand, for example on FL-0125's `Match.Spectate` |
The player can still pan, zoom and turn the overview while spectating. Leave and Stay are yours (FL-0129). Leaving the server is a Roblox action, so the camera does nothing for it.

### Raid ping: `registry:find("FeedbackWarController")`
| Member | What it does |
|---|---|
| `alert() -> { position, kingdom?, at }?` | The current raid on our lands. nil when there is none. It starts with the "Enemies in your lands!" toast and ends with "Your lands are clear" or our fall |
| `goToAlert() -> boolean` | The aerial camera to the raid (from walk mode too) |
Ask: a small "Go to the raid" button on the HUD while `alert()` is not nil, calling `goToAlert()`. On a phone that button is the only way to reach the ping, because there are no keys. The raid moments arrive through `AnnouncerController.moment` (kind `raid`, on true or false) if you want to show and hide the button without polling.

## Done (with commits)
- Branch `forge/04-experience-war-client` (FL-0130 part 2; stacked on #178):
  - `games/game-001/src/client/Controllers/RulerSpectateController.luau`;
  - `games/game-001/src/client/Controllers/FeedbackWarController.luau`.

## Evidence
- `games/game-001/tests/experience/WarFeedback.spec.luau` covers:
  - the start on the fall, with a remembered kingdom;
  - the target order;
  - our keep never being a target;
  - wrap-around cycling with the keys, only while spectating;
  - the end at Results and Lobby;
  - the raid alert, the beacon, G and D-pad up, and the walk-to-overview switch.
- **Unverified:** Studio E15. Spectating needs FL-0125's elimination on the build.

## Interfaces touched
Additive client APIs (above); no remote and no contract.

## Open issues and risks
- Right after our fall, the newest battle may be our own fallen keep, because the collapse is remembered as a hotspot. I left it in as a moment of drama. Say if the screen should skip it.

## Next actions for the receiver
1. FL-0129 spectate screen: list `targets()`, call `select(i)`, show on `changed`, highlight on `targetChanged`.
2. HUD: a "Go to the raid" button while `alert()` is not nil.

## Files to read
- `games/game-001/src/client/Controllers/RulerSpectateController.luau` (header): the rules.
- `roblox/studio-tests/experience.md` E15: the Studio check.
