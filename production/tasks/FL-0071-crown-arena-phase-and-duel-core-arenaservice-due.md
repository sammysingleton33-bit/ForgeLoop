---
id: FL-0071
title: Crown Arena phase and duel core (ArenaService, DuelModel, DuelService, AI champion)
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-18
depends_on: [FL-0070, FL-0077]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 22
evidence: []
---

# Crown Arena phase and duel core (ArenaService, DuelModel, DuelService, AI champion)

## Outcome
At the end of Endgame the match moves to the Crown Arena: the qualified kingdoms' champions are chosen, pick loadout and triggers, and fight a readable, server-authoritative duel in which earned support fires at the right moments, and the winner is crowned (design §2, §5).

## Context
D-029; design §2, §5, §6; CONTRACTS G12.1–G12.6. Qualification, champion choice and what the duel decides follow the PROVISIONAL defaults in config `Arena.luau` until the user decides (FL-0077, BRIEF §16.9).

## Requirements
- `MatchPhase` gains `"Arena"` (G12.1); MatchService enters it after Endgame and asks PacingService for its duration.
- `ArenaService`: qualification (top-2 by Crown Points by default; last keep standing → coronation), champion vote (10 s, leadership fallback), loadout and trigger pick (20 s; `Arena.Choose` validated against offers and slots), intro, duel, crowning; `Arena.State`/`Arena.GetState`, `Arena.Vote`.
- `src/shared/Arena/DuelModel.luau`: pure deterministic step model (light, heavy with wind-up, block, parry window, dodge, stamina, HP; 120 s cap; HP-percentage tiebreak and sudden death). Weapons and armour are sidegrades from config `Duel.luau`.
- `DuelService`: teleports champions to `Layout.arena` spawns, derives `inRange`/`facing` from real positions, validates and rate-limits `Arena.Action`, evaluates trigger conditions from model events, applies modifiers only after `Caps.check`, sends batched `Arena.Events`, fires G12.5 events.
- `src/client/Controllers/DuelController.luau` (G12.6): `act`, `getState`, `events`; client animation prediction only.
- AI champion for AI kingdoms: scripted duellist with skill from governor difficulty.
- Defeat is a kneel and yield; no blood or gore.

## Validation
Lune specs: DuelModel determinism and each action's rules; trigger conditions fire once at the right event; caps refusal path; Arena stage flow with fake clock; remote validation (wrong stage, non-champion, triggers not offered). Studio: two-client Local Server duel with debug presets (FL-0076).

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS
- [ ] FL-0076 fairness harness within the G12.3 outcome bounds
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (SPECIFIED).
- 2026-10-18 forge-00: SPECIFIED → READY. Operation Crownfall (D-053): arena work starts now; FORGE-01 order FL-0125 → FL-0069 → FL-0070 → FL-0071; defaults from crown-arena.md §11 apply
