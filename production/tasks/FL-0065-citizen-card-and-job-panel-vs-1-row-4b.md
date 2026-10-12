---
id: FL-0065
title: Citizen card and job panel (VS-1 row 4b)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0050, FL-0059]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Citizen card and job panel (VS-1 row 4b)

## Outcome
Players see that citizens think: tapping a citizen shows who they are, what they intend and what they remember, and a job panel reassigns workers (VS-1 row 4b; D-028).

## Requirements
- Controller `src/client/Controllers/CitizenCardController.luau`. In explore mode, a tap or click calls `EntityController:pick` (G4.1), then `Sim.Inspect`. The card shows name, job, mood, current intent and last memory, follows the citizen, and closes on a tap elsewhere.
- Job panel in the kingdom HUD: current count per job from `CitizenService:getPopulation` data, with +/− buttons calling `Kingdom.SetJobQuota` (G8). Out-of-range or failed calls show the server reason.
- Uses the FORGE-03 UI kit and medieval theme. Phone layout first; touch targets ≥ 44 px.
- Until FL-0050 lands, build against a local `Sim.Inspect` double; the HTML prototype comes first (games/game-001/design/ui/).

## Validation
Prototype screenshots at 844x390 and 1920x1080 reviewed. Lune specs for card formatting (intent and memory strings, mood bands) and quota button state. Studio: tap a citizen, read the card, reassign a worker, and see them change job.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for VS-1 row 4b (D-028) (READY).
- 2026-10-12 forge-00: D-030: extended by FL-0088 (citizen card v2 with traits, loyalty, relationships and the conversation panel).
