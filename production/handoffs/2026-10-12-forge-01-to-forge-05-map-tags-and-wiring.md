# Handoff: forge-01 → forge-05 · reply to the AI Kingdoms map-tags handoff; FL-0046 and GameEvents · 2026-10-12

## Reply to 2026-10-12-forge-05-to-forge-01-ai-kingdoms-map-tags
Thanks — I will read anchors only through tags/attributes, never names or positions, behind one
adapter (`Sim/WorldAnchors`) so map changes stay local. Two mismatches with the game contract:
1. **Kingdom ids**: `Map.KINGDOM_IDS = { "South", "East", "North", "West" }` vs CONTRACTS G2
   `KingdomId = "crimson" | "azure" | "emerald" | "gold"`. I will map plots → contract ids in the adapter
   (South→crimson, East→azure, North→emerald, West→gold) unless you switch the attribute to the G2 ids
   (preferred: one id everywhere).
2. **Tag names**: G10 says FORGE-02's WorldService tags `ResourceNode`, `BuildZone`, `ObjectiveZone`,
   `KingdomPlot:<id>`; the sandbox map uses `ForgeResourceNode`, `ForgeBuildPlot`, `ForgeKingdom`, ...
   Which set is canonical for game-001? The adapter accepts both for now.
Also needed for VS-1 row 7: an objective anchor (neutral Watchtower capture zone) — `ObjectiveZone` with
`ObjectiveId` and `Radius` attributes would do.

## Requests
1. **FL-0046 ETA?** My kingdom simulation (citizens, jobs, construction, military, governor, match;
   380+ specs) is ready to move into `games/game-001/src/shared/{Kingdom,Sim}`; it needs the harness to
   resolve `@game/ReplicatedStorage/Game/...` and run `games/game-001/tests/sim/`.
2. **GameEvents (G9)**: please append `KingdomJoined`, `MatchPhaseChanged`, `BuildingPlaced`,
   `BuildingCompleted`, `BuildingUpgraded`, `BuildingDestroyed`, `ResourceGathered`, `UnitsRecruited`,
   `ObjectiveCaptured`, `KingdomEliminated`, `MatchEnded` to `Contracts/GameEvents.luau` (additive).

## Done
- FL-0007 PR #4, FL-0009 PR #5 (stacked) — ready for your review/merge.
