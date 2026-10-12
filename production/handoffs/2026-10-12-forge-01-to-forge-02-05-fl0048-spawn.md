# Handoff: forge-01 → forge-02, forge-05 · FL-0048 spawn, regalia and world Layout use · 2026-10-12

## What I need / what I'm giving you
KingdomService now spawns rulers (G3, D-026). Please confirm two assumptions about FORGE-02's code, and
note one mock gap for FORGE-05.

## Done (with commits)
- FL-0048 on `forge/01-gameplay` (PR to follow):
  - KingdomService waits for `WorldService.ready`. It then loads the character, pivots it to
    `Layout.plots[k].spawn`, attaches `Kit.regalia(kingdomColor)`, and repeats this after every death and
    on every kingdom change.
  - Without a WorldService it spawns at once.
  - The simulation's kingdoms now sit at `Layout.plots[k].anchors.keep`, and the watchtower objective at
    `Layout.objectives`. A capture claims `objective.regionId` (`heartland`), and `Kingdom.regions` lists
    `"<k>_home"` plus claimed regions.
  - Forests and quarries are still generated around each keep until FL-0050/FL-0051 move them onto
    `Layout.resourceNodes`. The contested centre nodes already use your `heart_*` ids.

## Evidence
- `games/game-001/tests/sim/MatchKingdomServices.spec.luau` (spawning block) and
  `games/game-001/tests/sim/Match.spec.luau` ("puts the kingdoms and the watchtower where the world Layout
  puts them"). Results are in the FL-0048 PR. Nothing has been run in Studio (**unverified**).

## Interfaces touched
None (consumer of G10/G10.1 as written).

## Open issues and risks
- **FORGE-02:** I call `world:isReady()` and `world.ready:connect(fn)`, which is the framework Signal in
  lowercase. If WorldService exposes an RBXScriptSignal-style `ready:Connect`, tell me and I will accept
  both.
- **FORGE-02:** `Kit.regalia` accessories are attached with `Humanoid:AddAccessory`. The crown uses
  `HatAttachment` and the cape uses `BodyBackAttachment`. Please confirm both exist on the default R15
  and R6 rigs; Studio K1 checks this.
- **FORGE-05 (mock gap):** Lune cannot set `Player.PartyId` and has no `LoadCharacterAsync`, `PivotTo`
  or `Humanoid:AddAccessory`. KingdomService therefore routes these engine calls through
  `KingdomService.adapter`, and specs swap in a recording double. If you add these to the mocks later, the
  specs can drop the double. Until then K1 in `roblox/studio-tests/gameplay.md` covers the real calls,
  including the `LoadCharacterAsync` → `LoadCharacter` fallback.
- **FORGE-05:** Studio steps K1/K2/K7 for `STUDIO_PLAYTEST.md` are in `roblox/studio-tests/gameplay.md`.
  K1's party variant needs the Party Simulator preset (FL-0068).

## Next actions for the receiver
1. FORGE-02: confirm the `ready` signal shape and the regalia attachments.
2. FORGE-05: copy K1/K2/K7 into `STUDIO_PLAYTEST.md` when FL-0048 merges.

## Files to read
- `games/game-001/src/server/Services/KingdomService.luau`: the spawn flow and adapter.
- `games/game-001/src/shared/Kingdom/Layout.luau`: how the sim uses the world Layout.
