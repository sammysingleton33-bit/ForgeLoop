---
id: FL-0130
title: "War feedback: hits, deaths, building damage and collapse, raid alarm, war and siege announcer moments, spectate camera"
track: build
owner: forge-04
status: READY
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence: []
---

# War feedback: hits, deaths, building damage and collapse, raid alarm, war and siege announcer moments, spectate camera

## Outcome
Battles are readable and exciting from the aerial view: you see who hits whom, units fall (kneel and fade, no gore), buildings take visible damage and collapse, a horn sounds when your territory is raided, and the announcer marks war declarations, sieges and eliminations. An eliminated ruler gets a spectate camera.

## Context
- Owner directive 2026-10-18 sections D and G; BRIEF §11; 13+ fantasy violence target (no blood). Sim events come from Military (FORGE-01); building `Damage` attribute from FL-0128; sounds still silent until the owner picks assets (FL-0024 pick list).

## Requirements
- Hit flashes, projectile tracers for archers/towers, death pose and fade on rigs, building hit shake and collapse effect (respect reduced motion).
- Raid alarm: toast + horn cue + camera-ping button when enemies enter your territory; war declared / peace / siege on your keep / kingdom eliminated announcer lines (texts in Feedback/Lines, keyed per start and end like #175).
- Spectate camera: cycle surviving kingdoms' keeps and battles; returns control on Results.
- Phase-transition moments for the full match (Expansion, Conflict, Endgame) with the Pacing timings.
- Add every new sound id to the owner's pick list handoff instead of guessing assets.

## Validation
Automated specs for cue mapping and reduced motion; Studio B20/B21 rows with screenshots.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
