---
id: FL-0081
title: Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6)
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0085]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence:
  - check.sh OVERALL PASS (game-001 946/0); ownership PASS; validate 0 errors; pytest 345; mutations 12/13 (miss = removed unreachable check); Studio K11 unverified
  - "main 297eac5: check.sh PASS (game-001 1087/0 on ab70493+#89); ownership PASS 13 files; review specs R89Server 8/8, R89E2E 1/1, R89Throne 5/6 (L1 repro); 12/12 mutations"
  - BuildingService 11, MatchKingdomServices 41, Simulation 37, Catalog 15 specs; mutations 9/9 caught (1 equivalent removed); Studio unverified
  - "main aecd245: check.sh PASS on 2570c47+#106 (game-001 1107/0); combined 1111/0; CI 3/3 on f975532; whole plot fills 10/10; rail-on-slot -> slot_occupied; 3/3 mutations"
  - check.sh OVERALL PASS (game-001 1155/0); MatchKingdomServices 45/0 (3 new L2 specs); throne mutations 6/6 caught
  - "main 1c48149: check.sh PASS on 8357596+#112 (game-001 1171/0); ownership PASS 4 files; CI 3/3 on 5633e4d; 2/2 mutations"
---

# Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6)

## Outcome
In the aerial view the ruler builds on real plots and upgrades buildings in seconds. Higher levels unlock real advantages. The ruler sits on the throne (VS-1 rows 2 and 6).

## Requirements
- `Build.PlaceSlot` and `Build.Slots` / `Build.GetSlots` from `Layout.plots[k].buildSlots` (G13.5). `Build.Place` stays.
- Build and upgrade time comes from `Costs.building(type, level).buildSeconds`, scaled by the builders on site. Barracks proposal: 8 / 18 / 35 / 60 s.
- Each level unlocks something concrete in `Buildings.luau`, for example the barracks recruit cap 5 / 10 / 15 / 20 and training speed.
- KingdomService seats the ruler on the keep's `Throne` seat after spawn (G13.6) and re-seats after a respawn.
- Construction reports needs (housing ratio, food) to ReputationService through actions, so cheap repeats give nothing.

## Validation
Lune specs:
- slot occupancy and validation (wrong kingdom, occupied, size);
- upgrade timing with builders;
- level unlocks;
- seat on spawn and respawn (adapter double).

Studio: tap a plot, build a house, upgrade the barracks to level 2.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-13 forge-01: READY → BUILDING. Build.PlaceSlot/GetSlots/Slots on Layout build slots; ruler seated on the keep Throne after spawn/respawn/keep rebuild
- 2026-10-13 forge-01: BUILDING → REVIEW. Build.PlaceSlot/GetSlots/Slots; ruler seated on the keep Throne (spawn, respawn, keep rebuild); sim fixes: claim kind, own full site, loaded gatherer to site
- 2026-10-13 forge-05: REVIEW → BUILDING. Merged #89 (297eac5, D-040 fallback verdict on 9558386). Merged code with work left = BUILDING (D-038 (5)): M1 slot reservation (rail building over a slot leaves it free), M3 lumber camp/quarry L2/L3 rate bonus (config/Buildings.luau:99,112) or split it out. Then REVIEW with G6 (K11, STUDIO_PLAYTEST rows 2 and 6). M2 reason codes are FORGE-03 FL-0105. L1 _seat before onDied; L2 anyone can sit; L3 walls/gates on plots (FORGE-00).
- 2026-10-13 forge-01: BUILDING → REVIEW. #89 follow-ups: M1 a slot is occupied by any standing building of the kingdom over it (rail placements too); G13.5 v0.4-g9a PlaceSlot refuses wall/gate with not_on_plot; M3 lumber camp and quarry levels give gatherBonus 0/+20%/+40% (PROVISIONAL, best camp counts); L1 onDied connected before the throne seat, which is pcalled; L2 (Kit Seat not Disabled) deferred, L3 ruled by FORGE-00 (done here). Waits G6: K11, STUDIO_PLAYTEST rows 2 and 6
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #106 (aecd245, FORGE-05 D-040 fallback verdict on f975532; star by FORGE-00): #89 M1 slot reservation, M3 camp gatherBonus 0/0.2/0.4 (PROVISIONAL), L1 respawn never blocked by the seat, v0.4-g9a not_on_plot on the server. REVIEW, only G6 pending (K11, STUDIO_PLAYTEST rows 2 and 6). L2 (anyone can sit) deferred past VS-1.
- 2026-10-13 forge-01: REVIEW → REVIEW. #89 L2 fix-forward (star, FORGE-00): a keep's throne is its kingdom's rulers' only. KingdomService unseats anyone else (another kingdom's ruler, a spectator, any humanoid) within THRONE_CHECK and a respawning ruler takes a throne an outsider holds at once; co-rulers share it. Same status: adds the L2 fix on forge/01-gameplay-throne.
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #112 (1c48149, FORGE-05 D-040 fallback verdict on 5633e4d; star by FORGE-00): #89 L2, a throne is for its kingdom's rulers only (server-side unseat, co-rulers share). REVIEW, only G6 pending (K11 incl. step 9, STUDIO_PLAYTEST rows 2 and 6).
