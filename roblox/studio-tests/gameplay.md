# Studio tests — Gameplay (FORGE-01)

Steps for engine behaviour that headless Lune specs cannot prove (gate G6). Run them on the integrated
build only, and quote the `ReplicatedStorage.Forge.BuildInfo` sha in every report. Paste the server
Output for any step that fails. Never mark a step as passed without a user run.

Which steps are runnable after which PR:

| Steps | Needs |
|---|---|
| K1, K2, K7 (party, spawn, regalia, phases, rejoin) | FL-0048 merged on `main` |
| K3, K4 (citizens at work, ruler gathering) | FL-0048; citizens render once FL-0049 lands (placeholder parts until then) |
| K5 (build, upgrade) | the FL-0051 Build-remotes PR (`Build.CanPlace/Place/Upgrade/Buildings/GetBuildings`) |
| K6 (recruit, capture) | FL-0052 (`Army.Recruit`, `Army.Command`); a ruler-only capture works with FL-0048 |
| K8 and performance capture | FL-0049 (entity replication and client rigs; `Kingdom perf` log line) |
| K9 (Kit buildings, upkeep-fed citizens) | the living-kingdom groundwork PR (stacked on FL-0049) |
| K11 (build slots, throne) | FL-0081; the plot picker and build menu on slots are FORGE-03's |

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

## K5 — Build and upgrade (VS-1 row 6)
1. Place a House inside your territory with FORGE-03's build menu, or from the client command bar with
   `ForgeRemotes.Build.Place:InvokeServer("house", position, rot)` (rot 0..3 turns it in 90° steps).
2. Upgrade the keep once wood and stone allow it (`Build.Upgrade(keepId)`).

**Expected:**
- The treasury drops by exactly 40 wood; a site appears and builders finish it.
- Invalid spots return a reason and cost nothing.
- The keep upgrade shows a level-2 keep and a larger territory.

## K6 — Capture the watchtower (VS-1 row 7)
1. Walk your ruler onto the neutral watchtower near the valley centre and stay inside its ring.
2. With FL-0052 (fresh server): build a barracks. No house is needed: soldiers sleep in the barracks' bunks
   (4 at level 1, D-041), not in the keep's 12 beds that the starting citizens fill. The barracks and 3
   soldiers cost 150 wood, 60 stone and 90 food (`Costs.luau`) against a start of 100 wood and 50 stone, so
   gather or let the citizens work first. Recruit 3 soldiers at it
   (`Army.Recruit(barracksId, "soldier", 3)`, or the army panel), wait about 24 s, and press Send-to-capture
   (`Army.Command({}, "capture", nil, "watchtower")`).

**Expected:**
- The tower stands neutral (`Workspace.KingdomObjectives.watchtower`, Kit neutral colour) from the start.
- Recruiting charges `Costs.unit("soldier")` × 3 once (`Treasury.Changed`); a 5th soldier at one level 1
  barracks answers `recruit_cap` (no free bunk). Each soldier appears in front of
  the barracks door (the Kit `Rally`), then walks to the keep.
- After Send-to-capture, every idle soldier walks the road over the bridge and stands in a ring around the
  tower, inside the zone. `Army.Objectives` reports the progress at most twice a second.
- Capture progress rises to 1 in 20 s while uncontested; a second kingdom in the zone freezes it.
- On capture: the kingdom owns the tower, the tower's trims and banners turn the kingdom colour, the kingdom
  gains +100 Crown Points and the `heartland` region (`Kingdom.State` shows it in `regions`).
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

## K9 — Kingdoms built from the Kit, citizens fed by upkeep (FL-0051 visuals, FL-0050 core)
1. Play Solo and look at your plot from the air (or walk around it).
2. Place a House with the build menu (FORGE-03) or `Build.Place` when FL-0051's remotes land.
3. Wait two minutes with the treasury above 50 food, then reset your food to 0
   (`treasury.grant` / FORGE-03's debug commands) and wait another two minutes.

**Expected:**
- Each kingdom has a keep, storehouse, farm, lumber camp and quarry built from Kit models (not grey
  blocks), standing on the plot's anchors and facing the plot's front yard; no building overlaps another.
- A new site shows Kit stages 1 → 2 → 3, then the finished building.
- While fed, citizens never walk to the keep to eat; food drops once per upkeep interval instead
  (FORGE-03's ProductionService). With no food, citizens' hunger rises: `Sim.Inspect` on a citizen
  shows mood falling.

## K11 — Build on a slot, upgrade, sit on the throne (FL-0081; VS-1 rows 2 and 6; G13.5, G13.6)
1. Play Solo. Watch your ruler right after spawning, from the aerial camera and up close.
2. Reset the character (Esc → Reset) and watch the respawn.
3. Tap a free plot (`BuildSlot` marker) and build a House with FORGE-03's menu, or call
   `ForgeRemotes.Build.GetSlots:InvokeServer()` and then `Build.PlaceSlot:InvokeServer(slotId, "house")`
   with an `S` slot's id.
4. Try the same slot again, a Barracks on an `S` slot, and a Wall on any slot
   (`Build.PlaceSlot:InvokeServer(slotId, "wall")`).
5. Upgrade the keep (`Build.Upgrade(keepId)`) once wood and stone allow it, and stay seated meanwhile.
6. Press Space to stand up (walk mode), then let the keep upgrade again.
7. Build a House with the Build rail (`Build.Place`) right on a free `L` slot, then open the plot picker on
   that slot.
8. Upgrade the lumber camp to level 2 (`Build.Upgrade(lumbercampId)`) and note the wood on the HUD for a
   minute before and after.

**Expected:**
- After spawning (and after every respawn) the ruler sits on the keep's throne, wearing crown and cape.
  A co-ruler in the same kingdom stands at the keep door while the throne is taken.
- The house stands on the plot, facing its street; the treasury drops by the house price once;
  `Build.Slots` arrives with that slot `occupiedBy` the new building's id.
- The taken slot answers `nil, "slot_occupied"`; the barracks answers `nil, "does_not_fit"`; the wall
  answers `nil, "not_on_plot"`; none of them costs anything.
- A slot with a rail-placed building on it shows as taken (`Build.Slots` `occupiedBy` that building), and
  `PlaceSlot` there answers `slot_occupied`, never `blocked`.
- With the lumber camp at level 2 the woodcutters bring wood in noticeably faster (about +20 % while they
  work the trees; walking time is unchanged).
- Builders walk to the site and work it together (two or three at once); the upgrade finishes in about its
  `Costs` build time divided by the builders on site.
- When the keep upgrade completes, the seated ruler sits on the new keep's throne within half a second.
  A ruler who stood up stays standing after the next upgrade.
- No errors in Output (`KingdomService: throne check failed` would be one).

## Performance capture (FL-0049, gate G7)
With the 4 × 12 citizens plus `sim.spawn 50` running for 5 minutes, record:
- the server Output line `Kingdom perf`, logged every 30 s: entities, bytesPerSecond (per player),
  simMsP99 (per 1/16 s host tick) and encodeMsP99 (per snapshot tick);
- Network → Data sent per client (KB/s), from the Studio stats panel.

The targets are ≤ 4 ms per frame and ≤ 20 KB/s per player (G4, VS-2 target; VS-1 sends everything).
Write the numbers into `games/game-001/tests/sim/PERF.md`, labelled "Studio, indicative".
