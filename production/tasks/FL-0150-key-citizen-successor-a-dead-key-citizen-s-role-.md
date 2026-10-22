---
id: FL-0150
title: "Key-citizen successor: a dead key citizen's role passes to a living citizen at loyalty 50"
track: build
owner: forge-01
status: READY
priority: P2
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Key-citizen successor: a dead key citizen's role passes to a living citizen at loyalty 50

## Outcome
When a key citizen dies, their role does not vanish for the rest of the match. A living citizen of the same job takes it over at loyalty 50, as `design/crown-arena.md` §4 and FL-0069 promise.

## Context
- D-061 (4): new arrivals are generated as single-person populations and always get the base occupation, so a dead key citizen's role is lost for good today (People.luau:131, Population.luau:256; FORGE-00's headless check on 8b2cb7fd showed 0 key roles across 2,500 arrivals).
- The design says a dead key citizen is mourned (a crowd moment), offers no perk, and a successor appears with loyalty 50 (crown-arena.md §4).

## Requirements
- On a key citizen's death, promote one living plain citizen of the same job, or the next arrival of that job if there is none, to the role at loyalty 50. Keep it deterministic per seed.
- The role still needs its building (the FL-0149 gate).
- Same rule for AI and human kingdoms.
- No contract break: KeyCitizen stays as in G12.2, with an additive row if needed.

## Validation
- Specs: kill a key citizen and check the successor, its loyalty 50, determinism, and the gate.
- FullMatch over 8 seeds: report role counts at Endgame before and after.
- Studio (owner): unverified until seen.

## Completion criteria
- [ ] The successor rule is merged with specs, and FORGE-07 has reviewed it.
- [ ] The FullMatch role counts are in the PR.

## Log
- 2026-10-22 forge-00: filed from D-061 (4). Starts after FL-0149.
- 2026-10-22 forge-00: SPECIFIED → READY. Filed from D-061 (4); after FL-0149
