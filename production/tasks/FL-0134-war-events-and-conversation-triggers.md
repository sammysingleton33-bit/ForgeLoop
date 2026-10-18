---
id: FL-0134
title: "Fire G9 WarChanged, SiegeChanged and RaidChanged, and raise the matching conversation triggers (war, siege, raid, strike, riot, objective lost)"
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence: []
---

# Fire G9 WarChanged, SiegeChanged and RaidChanged, and raise the matching conversation triggers (war, siege, raid, strike, riot, objective lost)

## Outcome
War, sieges and raids reach every listener the moment they happen. FORGE-04's war, siege and raid notices and the raid ping go live (#178 and #183 are already on main, dormant). Citizens raise the conversations that belong to those moments: the library's raid, riot and strike scenes, which today validate but can never fire, and FORGE-06's VS-2 war, siege and outpost-lost scenes once the owner approves them.

## Context
- FORGE-04's handoff `production/handoffs/2026-10-18-forge-04-to-forge-01-war-events.md` holds the exact G9 rows:
  - `WarChanged(kingdomId, otherId, atWar, by?)`;
  - `SiegeChanged(kingdomId, on, {byKingdomIds, buildingId})`;
  - `RaidChanged(kingdomId, on, {byKingdomIds, count, position})`.

  FORGE-00 approved them as additive.
- FORGE-06 (2026-10-18): ConversationService raises only `building_completed`, `keep_upgraded`, `objective_captured`, `shortage` and `soldiers_recruited`. `event.raid`, `event.strike` and `event.riot` are in the vocabulary but never raised. The new flags needed are `event.war_declared`, `event.siege` and `event.objective_lost`.
- The G4 `hit`/`shot` event and a kneeling death pose for FORGE-04 can ride along here if they are small; otherwise they go in their own PR.

## Requirements
- Fire the three G9 events exactly once per start and once per end, the same rule as `ConsequenceChanged`. FORGE-05 declares the names in `Contracts/GameEvents`.
- ConversationService `_raise` for:
  - `war_declared` (on WarChanged atWar = true, both kingdoms);
  - `siege` (SiegeChanged on);
  - `raid` (RaidChanged on);
  - `strike` and `riot` (ConsequenceChanged on);
  - `objective_lost` (G13.4 ObjectiveLost).

  Each holds for `Society.conversation.eventSeconds`, as the existing tags do.
- Specs:
  - each tag is raised by its event and expires;
  - one library scene per tag becomes eligible;
  - no tag is raised for the wrong kingdom.
- Write the G9 rows and the trigger vocabulary in your handoff; FORGE-00 lands them in CONTRACTS.

## Validation
Automated specs as above, and a mutation row per tag. Studio: B21 rows (a raid raises a raid petition; war declared raises a war scene).

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created from FORGE-04's war-events handoff and FORGE-06's FL-0133 interface requests (Operation Crownfall, D-053).
