---
id: FL-0074
title: Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff
track: build
owner: forge-04
status: BUILDING
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-18
depends_on: [FL-0071, FL-0072]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 16
evidence: []
---

# Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff

## Outcome
The crowd behind each ruler visibly and audibly reflects their leadership: Adoring stands chant and roar, Hostile stands boo and leave, key citizens step up when their perk fires, and the ending pays off the player's choices (design §7).

## Context
D-029; design §7; CONTRACTS G12.6 (client-only crowd from `ArenaState`, `Arena.Events`, population). **VS-1 experience tasks come first;** design the crowd director and chant list in slack time.

## Requirements
- `CrowdController` (client-only): fills stands from population (one figure per two citizens, ≤ 60 per stand, ≤ 120 total), key citizens at the rail, billboard fallback on low graphics levels; crowd frame time < 2 ms.
- Crowd director: tier behaviours (design §3 table), reactions to hit, parry, near-death, trigger, comeback, finish; at most one major reaction every 3 s; perk moments take priority; volume ducks under announcer lines.
- `ChantController` and config `Crowd.luau`: pre-written chants per kingdom; boos and turned backs as the strongest negative (no insults); subtitles for chants and announcer lines.
- Intro camera passes over both stands; music and stingers in `Sounds.luau`; four endings (win or loss × high or low support).
- Arena phase timings in `Pacing.luau` (design §2).

## Validation
Lune specs for director rationing and tier mapping. Studio video or screenshots of each tier and of a perk moment; MicroProfiler capture of crowd cost on a phone emulator.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-13 forge-00: READY → SPECIFIED. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): its dependencies are not built yet (FL-0018 economy core, or the Crown Arena FL-0070/FL-0071), so it is SPECIFIED, not READY.
- 2026-10-18 forge-00: SPECIFIED → READY. Operation Crownfall (D-053): arena work starts now; FORGE-01 order FL-0125 → FL-0069 → FL-0070 → FL-0071; defaults from crown-arena.md §11 apply
- 2026-10-18 forge-04: READY → BUILDING. Part 1 (pure, before FL-0071/FL-0072): Feedback/CrowdDirector (figures one per two citizens <= 60 a stand, <= 120 total; seats by tier; tier reactions per design §3; one major every 3 s, minor per stand every 0.75 s; perk moments and the ending always win and duck the crowd; near-death and comeback; full-hype chants for chanting tiers; four endings), config/Crowd.luau DRAFT (tiers, subtitles for every reaction, pre-written chants per kingdom, endings), Pacing.arena stage seconds (qualify 5, vote 10, loadout 20, intro 15, duel 120, crowning 20), 13 crowd sounds (P2, handoff 2026-10-18-forge-04-to-user-crowd-sounds.md). Part 2 (client crowd controller, intro camera, music) waits for FL-0071 and FL-0072.
