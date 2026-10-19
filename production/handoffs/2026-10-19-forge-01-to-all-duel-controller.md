# Handoff: FORGE-01 → FORGE-03, FORGE-04 (cc FORGE-00, FORGE-05, FORGE-07) · FL-0071: DuelController (G12.6) · 2026-10-19

Stacked on #241 (ArenaService, the Arena.* remotes). Client only; nothing here turns the arena on (`Arena.enabled` stays false).

## What I'm giving you
`src/client/Controllers/DuelController.luau`, registered as `DuelController`:

| Member | Shape |
|---|---|
| `controller.events` | `Signal<(event)>`: every `Arena.Events` entry one at a time, in server order (`{ t, kind, side, data? }`, shares only; table in the DuelRunner handoff). Junk entries are dropped |
| `controller.stateChanged` | `Signal<(ArenaState)>` |
| `controller:getState()` | the latest `Arena.State` (asked once with `Arena.GetState` at start), nil before any |
| `controller:isChampion()` | the local player is duellist a or b (not an AI) in the `duel` stage |
| `controller:act(action)` | `light`, `heavy`, `block`, `blockEnd`, `parry`, `dodge`. Sent only for a champion in the duel stage, with the server's own bucket (burst 8, 12 per second) mirrored; true = sent |

It is the only sender of `Arena.Action`. `InputModeArenaController` (FORGE-04) calls `act` and `getState`; `ArenaHudController` (FORGE-03) already subscribes to `events` when the controller exists, and the crowd reads the same feed. Nothing needs to change on your side.

The server decides everything (reach, facing, stamina, the result); the client only asks. A missing remote leaves the controller inert (RemoteLink logs one info line).

## Evidence (headless only; no Studio)
- `experience/DuelController` 10 specs: state feed and junk, GetState at start, batch unpacking in order, send for a champion, nothing from a spectator / an AI seat / other stages / before a state, non-actions refused, the burst of 8 and the refill, a fresh duel's full bucket, inert without remotes, destroy.
- `FL-0071D.py` 14 rows, all caught.

## Not done
Real touch / key / pad presses reaching `act` and the camera are FORGE-04's controller and need the Studio phone emulator and a two-player test (`roblox/studio-tests`): nothing here proves the controls feel right or that a hit lands from a real client.
