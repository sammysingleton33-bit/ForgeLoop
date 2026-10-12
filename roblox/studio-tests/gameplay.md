# Studio tests — Gameplay (FORGE-01)

Steps for engine behaviour that headless Lune specs cannot prove (gate G6). Run them on the integrated
build only, and quote the `ReplicatedStorage.Forge.BuildInfo` sha in every report. Paste the server
Output for any step that fails. Never mark a step as passed without a user run.

Which steps are runnable after which PR:

| Steps | Needs |
|---|---|
| K1, K2, K7 (party, spawn, regalia, phases, rejoin) | FL-0048 merged on `main` |
| K3, K4 (citizens at work, ruler gathering) | FL-0048; citizens render once FL-0049 lands (placeholder parts until then) |
| K5 (build, upgrade) | FL-0051 (`Build.Place`, `Build.Upgrade`) |
| K6 (recruit, capture) | FL-0052 (`Army.Recruit`, `Army.Command`); a ruler-only capture works with FL-0048 |
| K8 and performance capture | FL-0049 (entity replication and client rigs; `Kingdom perf` log line) |

Remote names are the CONTRACTS G8 names (`<Area>.<Action>`, under `ReplicatedStorage.ForgeRemotes.<Area>`).
The build runs the **VS-1 slice mode** (config `Match.mode = "slice"`, PROVISIONAL, CONTRACTS G3): Founding
starts on the first join and is untimed; the first watchtower capture ends the slice.

## Setup
1. Open the game-001 build: `rojo serve games/game-001/default.project.json`, or the CI `.rbxl`.
2. Open the Output window.
3. Use **Test → Start** with 2 players (local server) unless a step says Play Solo. For K1's party variant,
   use the Party Simulator (FL-0068 preset) so both players share a `Player.PartyId`.

## K1 — Join, spawn at the keep, regalia (VS-1 row 3; FL-0048)
1. Start a local server with 2 players **not** in a party.
2. Check the player list and each character.
3. Repeat with 2 players in one simulated party.

**Expected:**
- Without a party: two different kingdoms (balanced). With a party: both on the same kingdom team.
- Teams are Crimson, Azure, Emerald, Gold with distinct colours; no player is auto-assigned by the engine.
- Each character appears in front of its own keep door (world Layout `plots[k].spawn`), facing the valley,
  wearing a crown and a cape in the kingdom colour.
- Reset a character (Esc → Reset): it respawns after `Players.RespawnTime` at the same plot, again with
  regalia.
- No errors in Output; no `KingdomHost: tick failed` lines. If a line says
  `LoadCharacterAsync` is missing, note it: the service falls back to `LoadCharacter` (unverified engine API).

## K2 — Match phases in the slice (G3, G8)
1. Play Solo and watch Output.
2. From the client command bar, call `ReplicatedStorage.ForgeRemotes.Match.GetState:InvokeServer()`.

**Expected:**
- `Match.State` fires `Founding` within a quarter second of joining, with no deadline (`endsAtServerTime`
  nil) and a `startedAtServerTime` number.
- `Match.GetState` returns `"Founding", nil, <number>`.
- Only your kingdom has citizens; the other three keeps stand idle (no AI governors in the slice).

## K3 — Citizens at work and the stockpile rising (VS-1 row 4)
1. In Play Solo, stand at your keep for 60 s.
2. Watch the citizens (placeholder parts until FL-0049).

**Expected:**
- 12 citizens with jobs: farmer, woodcutter, miner, builder, hauler.
- They walk to farms, trees and rocks, work, then carry goods back to the keep or a storehouse.
- The treasury rises (FORGE-03's `Treasury.Changed` once FL-0058 lands; until then the server-side
  double, visible through the debug panel of FL-0068).

## K4 — Ruler gathering (VS-1 row 5)
1. Walk to a tree and call `Kingdom.Gather(nodeId)` from the client command bar with the node's
   `EntityId` attribute (the interaction prompt of FL-0051 replaces this).
2. Repeat it faster than once per 0.8 s.
3. Repeat it from 30 studs away.

**Expected:**
- An accepted gather returns `true, "wood", 2`.
- Calls faster than the cooldown return `false, "cooldown"`; from 30 studs away `false, "too_far"`.

## K5 — Build and upgrade (VS-1 row 6; needs FL-0051)
1. Place a House inside your territory with `Build.Place("house", position, 0)`.
2. Upgrade the keep once wood and stone allow it (`Build.Upgrade(keepId)`).

**Expected:**
- The treasury drops by exactly 40 wood; a site appears and builders finish it.
- Invalid spots return a reason and cost nothing.
- The keep upgrade shows a level-2 keep and a larger territory.

## K6 — Capture the watchtower (VS-1 row 7)
1. Walk your ruler onto the neutral watchtower near the valley centre and stay inside its ring.
2. With FL-0052: recruit soldiers (`Army.Recruit`) and press Send-to-capture (`Army.Command` with no ids).

**Expected:**
- Capture progress rises to 1 in 20 s while uncontested; a second kingdom in the zone freezes it.
- On capture: the kingdom owns the tower, gains +100 Crown Points and the `heartland` region
  (`Kingdom.State` shows it in `regions`).
- Slice mode: `Match.Ended` fires once with your kingdom as `winner`; the phase becomes `Results` and stays.

## K7 — Multiplayer integrity
1. With 2 players in the same kingdom (party), both act within one second (gather, set a job quota).
2. Leave with one player and rejoin.

**Expected:**
- Both actions apply; the treasury matches the sum.
- The rejoining player is back in the same kingdom, respawns at its keep with regalia, and
  `Kingdom.GetState` shows them in `rulers` with `mine` set.

## K8 — Citizens rendered on clients (FL-0049, G4)
1. Start a local server with 2 players. Join, so your kingdom's 12 citizens appear.
2. Watch the citizens from both clients for 60 s.
3. Open the debug panel (F8) and run `sim.spawn 50` once.
4. Repeat with Studio's Network Simulator at 200 ms latency and 5 % packet loss.

**Expected:**
- Citizens are part-built rigs (`Workspace.KingdomEntities`, no Humanoids) in kingdom colours. They walk,
  work, carry and idle with procedural animation, and they look the same on both clients.
- Movement is smooth, about 0.2 s behind the server, with no teleporting. Under loss, a citizen may
  hesitate briefly but never jumps back.
- Rigs further than 150 studs from your character disappear and come back when you approach.
- Long trips (soldiers sent to the watchtower) follow the road and cross the river at the bridge.
- No `EntityService` errors in Output.

## Performance capture (FL-0049, gate G7)
With the 4 × 12 citizens plus `sim.spawn 50` running for 5 minutes, record:
- the server Output line `Kingdom perf`, logged every 30 s: entities, bytesPerSecond (per player),
  simMsP99 (per 1/16 s host tick) and encodeMsP99 (per snapshot tick);
- Network → Data sent per client (KB/s), from the Studio stats panel.

The targets are ≤ 4 ms per frame and ≤ 20 KB/s per player (G4, VS-2 target; VS-1 sends everything).
Write the numbers into `games/game-001/tests/sim/PERF.md`, labelled "Studio, indicative".
