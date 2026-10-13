---
id: FL-0078
title: "Generated population: names, traits, looks, relationships, chemistry, loyalty (G13.2)"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0083]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence:
  - check.sh OVERALL PASS (game-001 764/0); People.spec 7, CitizenService +4, EventCodec look cases; 16/16 mutations caught
  - "#61 ad71b3e; integration-log.md"
---

# "Generated population: names, traits, looks, relationships, chemistry, loyalty (G13.2)"

## Outcome
Every match fills each kingdom with a new population of individuals. Each citizen has a name, family, 2–3 traits, a distinct look, a chemistry with the ruler, a loyalty, and friends and rivals. The same seed always gives the same people (VS-1 rows 4 and 4b).

## Requirements
- CitizenService generates the starting population from the match seed using Content `Names`, `Traits` and `Occupations` (G13.1, G13.2):
  - VS-1 size is 12 per populated kingdom;
  - traits never include an opposite pair;
  - households share a family name;
  - each citizen has 1–3 friends and 0–1 rival;
  - chemistry is −20..+20;
  - loyalty starts at 50 + chemistry/4.
- Obedience is derived from rep.authority, rep.fear and trait obedience_bias. It is never stored.
- `inspect` returns `CitizenView`, a superset of G5. The look travels once in the reliable spawn entity event.
- Extend what exists (utility AI, memory, jobs). Do not rewrite it.

## Validation
Lune specs:
- same seed gives the same population, and a different seed a different one;
- no opposite traits;
- relationship symmetry (friends are mutual, family share a household);
- the ranges hold;
- inspect returns the right shape.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-12 forge-01: READY → BUILDING. CitizenService generates the population (Sim/People on Sim/Population + Content)
- 2026-10-12 forge-01: BUILDING → REVIEW. Generated population per world seed; inspect returns CitizenView; look in the spawn event; Kingdom.Population/GetPopulation
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending, plus a tracked follow-up (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main. Follow-ups from FORGE-05's #61 review (Low): GetEntities over 900 B at 50+ entities (G4), ids vs display names, raw look key; quotaRev for co-ruler quota changes (#71 Low).
