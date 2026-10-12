# Studio tests — Gameplay (FORGE-01)

Steps for engine behaviour that headless Lune specs cannot prove (gate G6). Run them on the integrated
build only, and quote the `ReplicatedStorage.Forge.BuildInfo` sha in every report. Paste the server
Output for any step that fails.

**Status:** these steps need the AI Kingdoms services on `main`. That requires two things: FL-0046
(game tree wiring, FORGE-05) and the FORGE-01 kingdom PRs (FL-0048 → FL-0052). Until both land there
is nothing to run. Never mark a step as passed without a user run.

## Setup
1. Open the game-001 build: `rojo serve games/game-001/default.project.json`, or the CI `.rbxl` once FL-0046 lands.
2. Open the Output window.
3. Use **Test → Start** with 2 players (local server) unless a step says Play Solo.

## K1 — Join a kingdom and spawn at home (VS-1 row 3)
1. Start a local server with 2 players.
2. Check the player list: each player is on a kingdom team (Crimson, Azure, Emerald or Gold).
3. Check where each character spawns: next to its own keep, on the side facing the map centre.

**Expected:** two different kingdoms (balanced assignment). No errors in Output.

**Shared-kingdom variant:** the second player calls `Gameplay.ChooseKingdom` with the first player's
kingdom while in the Lobby. Both are then on one team and both see the same treasury.

## K2 — Match phases (VS-1 / G3)
1. Play Solo and watch Output.
2. Wait for the countdown (10 s), then Founding.

**Expected:**
- `Gameplay.MatchPhase` fires `Founding` with a deadline about 8 minutes ahead.
- The citizens start moving only after the countdown ends.

## K3 — Citizens at work and the stockpile rising (VS-1 row 4)
1. In Play Solo, stand at your keep for 60 s.
2. Watch the citizens.

**Expected:**
- At least 12 citizens with visible jobs: farmer, woodcutter, miner, builder, hauler.
- They walk to farms, trees and rocks, work, then carry goods back to the keep or a storehouse.
- `Gameplay.KingdomSnapshot` totals rise. Food rises from the farm, wood from trees and stone from rocks.
- At night (after 90 s of each 120 s day) the citizens go home to sleep. In the morning they go back to work.

## K4 — Ruler gathering (VS-1 row 5)
1. Walk to a tree and trigger `Gameplay.Gather(nodeId)`. For now, call it from the client command bar with the node's `EntityId` attribute.
2. Repeat it faster than once per 0.8 s.
3. Repeat it from 30 studs away.

**Expected:**
- Each accepted gather adds 2 wood to the treasury.
- Calls faster than the cooldown return `cooldown`.
- From 30 studs away the call returns `too_far`.

## K5 — Build and upgrade (VS-1 row 6)
1. Place a House inside your territory with `Gameplay.PlaceBuilding("house", x, z)`. The build menu (FORGE-03) replaces this call later.
2. Watch the site.
3. Upgrade the keep once wood and stone allow it (`Gameplay.UpgradeBuilding(keepId)`).

**Expected:**
- The treasury drops by exactly 40 wood.
- A translucent site appears and grows.
- Builders walk there and hammer, and the house completes in about 15 builder-seconds.
- Population capacity rises by 4.
- Invalid spots return a reason and cost nothing: on the keep → `blocked`; outside your land → `out_of_territory`.
- The keep upgrade shows a level-2 keep and a larger territory.

## K6 — Recruit and capture (VS-1 row 7)
1. Build a Barracks.
2. Recruit 3 soldiers (`Gameplay.Recruit("soldier", 3)`).
3. Move them onto the neutral watchtower near the map centre with `Gameplay.ArmyOrder("Move", x, z)`.

**Expected:**
- The treasury is charged 90 food and 30 wood.
- The soldiers appear next to the Barracks after 8 s each.
- On the watchtower the capture progress rises to 1 in 20 s when uncontested. Then the kingdom owns it, gains +100 Crown Points, and the territory around it lets you build there.
- A second kingdom's units in the zone freeze the progress (contested).

## K7 — Multiplayer integrity
1. With 2 players in the same kingdom, both place a building within one second.
2. Leave with one player and rejoin.

**Expected:**
- Both buildings exist and the treasury drops by the sum of both costs.
- The rejoining player is back in the same kingdom and sees the current state at once (`Gameplay.GetKingdomState`).

## Performance capture (FL-0049, gate G7)
With 4 kingdoms × 12 citizens running for 5 minutes, record:
- server sim time per tick (Output line `KingdomHost: sim`, logged every 30 s);
- Network → Data sent per client (KB/s).

The targets are ≤ 4 ms per frame and ≤ 50 KB/s per player.
