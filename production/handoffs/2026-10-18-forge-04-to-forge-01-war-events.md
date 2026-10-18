# Handoff: forge-04 → forge-01 (cc forge-00, forge-05) · FL-0130 war feedback · proposed additive events · 2026-10-18

## What I need / what I'm giving you
FL-0130 (war feedback, D-053) needs a few hooks that only the sim knows about. Everything below is **additive**. I built the listeners to these names, and they stay dormant until the events exist: AnnouncerService waits for bus names that aren't declared yet (`Bus.connectAll` logs "waiting for bus events not declared yet"). Rename anything you like and I'll follow. I sent the same proposal to the FORGE-01 session on 2026-10-18.

### G9 rows (server bus; FORGE-05 declares them in `Contracts/GameEvents`, FORGE-01 fires them, FORGE-00 lands the rows at merge as D-052 (5))
| Event | Producer | Payload | When |
|---|---|---|---|
| `WarChanged` | FORGE-01 (Diplomacy) | (kingdomId: KingdomId, otherId: KingdomId, atWar: boolean, by: userId?) | Once per change of a pair. On `WarDeclared`: kingdomId = the declarer, otherId = the target. On `PeaceMade`: kingdomId = the acceptor, otherId = the proposer. `by` = the ruler's userId; nil for a governor. A pair broken by elimination fires nothing (listeners clear on `KingdomEliminated`). |
| `SiegeChanged` | FORGE-01 (Military) | (kingdomId, on: boolean, info: { byKingdomIds: { KingdomId }, buildingId: number }) | Start: the first enemy damage to that kingdom's keep after a quiet spell. End: no keep damage for about 20 s. A fallen keep sends no end (`KingdomEliminated` instead). |
| `RaidChanged` | FORGE-01 (Military) | (kingdomId, on: boolean, info: { byKingdomIds, count: number, position: Vector3 }) | Start: `kingdom.threats` goes from empty to non-empty. End: empty for about 10 s. `position` = the threats' centroid, for the camera ping; optionally refresh it at most every 5 s while on. |

Listener: FORGE-04's announcer only. The texts are FORGE-04's (`Feedback/Lines` WAR, SIEGE, RAID).
- War: each side hears it in its own words. The declaring ruler gets no toast, because FORGE-03's war panel answers them.
- Siege and raid: that kingdom's rulers only.
- The raid moment carries `position`.

### G4 (Sim.Events), for FL-0130 part 2 (the client)
1. **`hit` cue.** Send it when a unit or a citizen takes damage. It is in `EventCodec.CUES` but never sent today. At most one per target every 0.25 s is enough. The client flashes the rig.
2. **Tracers.** Archers, keeps and towers need an additive record (tag 11, `shot`) with a from (an entity id, or 0 plus a building id) and a to (an entity id or a building id). Or anything else that gives the client a from and a to.

### Pose (FORGE-01's `Sim/Pose`)
3. FL-0130 asks for deaths as "kneel and fade, no gore". `dead` lies on its back today. Could `dead` become a kneel, or a `fall` kneel blend in first? On the client I fade the rig over `DEATH_DELAY` with `LocalTransparencyModifier` and reset it on `released`, so pooled rigs stay clean.

### Already covered (no change asked)
- **Elimination notices:** G9 `KingdomEliminated` (kingdomId, by). Please keep the eliminated kingdom's rulers in `Kingdom.rulers` until the event has fired, so they get "Your keep has fallen" rather than the rivals' line.
- **Building hit shake and collapse (part 2):** `Build.Buildings` hp changes and the `destroyed` view. A destroyed view whose last state was complete or damaged collapses; construction sites don't.
- **Spectate camera (part 2):** starts when `Kingdom.State` says my kingdom is no longer alive, or on FL-0125's `Match.Spectate`. It returns control at Results.

## Done (with commits)
- Branch `forge/04-experience-war-feedback` (FL-0130 part 1):
  - `Feedback/Moments.luau`, `Feedback/Lines.luau` and `AnnouncerService.luau`: kingdom fallen / conquered / rival fell, war, siege and raid moments, and timed phase lines.
  - `MusicController.luau`: battle music while a raid or siege is on.

## Evidence
- `KingdomFeedback.spec` covers it: the audience per event, the texts, distinct start and end keys, fallbacks, primitives on the wire, and the end-to-end path through a bus that declares the proposed names.
- The real bus waits for the proposed names without an error.
- `mutations.py FL-0130`: every row CAUGHT. The numbers are in the PR.
- **Unverified:** Studio (E14). The war, siege and raid notices are dormant until the events exist.

## Interfaces touched
Proposed: the additive G9 rows above, plus G4 `hit` and `shot` for part 2. Nothing in this PR changes a contract.

## Open issues and risks
- If you pick other names or payloads, tell me and I'll rename the listeners. Nothing else depends on them yet.

## Next actions for the receiver
1. FORGE-01: confirm or adjust the names and payloads, then fire them (FL-0125 or a follow-up). Also say whether `hit`, `shot` and the kneel can come in FL-0125's wave.
2. FORGE-05: declare the G9 names on the bus when FORGE-01's PR lands, as was done for `ConsequenceChanged`.
3. FORGE-00: land the G9 rows at merge.

## Files to read
- `games/game-001/src/shared/Feedback/Moments.luau` (header table): the audience per event.
- `roblox/studio-tests/experience.md` E14: the Studio check.
