---
id: FL-0130
title: "War feedback: hits, deaths, building damage and collapse, raid alarm, war and siege announcer moments, spectate camera"
track: build
owner: forge-04
status: BUILDING
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence:
  - "part 1: KingdomFeedback 48/48; mutations.py FL-0130 25/25 CAUGHT"
  - "unverified: Studio E14; war/siege/raid notices dormant until FORGE-01 fires the proposed G9 events"
  - "part 2: WarFeedback 14/14; FL-0130 rows 53 (part 2: 28), counts in the PR"
  - "unverified: Studio E15; hit flash needs the G4 hit cue; tracers not built (need a from/to event)"
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
- 2026-10-18 forge-04: READY → BUILDING. Started (FORGE-00 Crownfall mission 1, D-053). Plan: client hit flash and kneel-and-fade death on rigs, building hit shake and collapse (reduced motion respected), raid alarm (toast, horn, camera-ping), announcer moments for war/peace/siege/elimination keyed per start and end, full-match phase moments, spectate camera; built against the sim's existing Military/Diplomacy events, with elimination and spectate wiring checked against FL-0125 when it lands. New sounds go in a new pick-list handoff.
- 2026-10-18 forge-04: BUILDING → BUILDING. Part 1 (server moments) in review: G9 KingdomEliminated -> 'Your keep has fallen' (celebration), 'You conquered X!' (celebration), 'X has fallen' to everyone else; full-match phase lines with Pacing minutes (Conflict now reads 'The age of war begins': war is allowed, not declared); listeners for the proposed G9 WarChanged / SiegeChanged / RaidChanged (dormant until the bus declares them; handoff 2026-10-18-forge-04-to-forge-01-war-events.md); battle music while a raid or siege is on; two new P1 sounds (kingdom.alarm, kingdom.fallen) in handoff 2026-10-18-forge-04-to-user-war-sounds.md; E14. Part 2 next: hit flash, kneel-and-fade deaths, building hit shake and collapse, raid camera ping, spectate camera.
- 2026-10-18 forge-04: BUILDING → BUILDING. Part 2 (client) in review, stacked on #178: FeedbackWarController (hit flash on the G4 hit cue, kneel-and-fade deaths with LocalTransparencyModifier reset on release, building hit dust and shake from Build.Buildings hp drops (no shake with reduced motion, never on a burning building), collapse on destroyed after standing (cancelled sites and a new world never; at most 6 per batch, one crash), raid beacon and camera ping (G / DPadUp, goToAlert for a HUD button), battle hotspots); RulerSpectateController (starts on our fall, battles then standing keeps, . , / R1 L1, ends at Results/Lobby; API for FORGE-03's FL-0129 screen, handoff 2026-10-18-forge-04-to-forge-03-spectate-and-raid-ping.md); 4 war presets; war.hit and war.collapse sounds (handoff 2026-10-18-forge-04-to-user-war-sounds-2.md, 46 sounds); E15. Waiting on FORGE-01 for the G4 hit cue, tracers (shot) and the kneel pose.
