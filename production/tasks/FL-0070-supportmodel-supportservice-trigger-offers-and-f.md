---
id: FL-0070
title: SupportModel, SupportService, trigger offers and fairness caps
track: build
owner: forge-01
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0069]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 10
evidence: []
---

# SupportModel, SupportService, trigger offers and fairness caps

## Outcome
Each ruler has a support score and tier that the HUD can show at any time, and a list of trigger offers from loyal key citizens, all computed by one pure, deterministic model that respects the fairness caps (design §3, §4, §6).

## Context
D-029; design §3, §4, §6; CONTRACTS G12.1–G12.3, G12.4 (`Kingdom.Support`, `Kingdom.GetSupport`).

## Requirements
- `src/shared/Arena/Types.luau` exactly G12.1; `src/shared/Arena/Caps.luau` with the G12.3 numbers and `Caps.check`.
- `src/shared/Arena/SupportModel.luau`: pure `score` (time-weighted, later samples weighted more per config) and `offers` (tier slots, pledged/empowered at 80/95, dead citizens excluded, Crowd Rally for Adoring only).
- `SupportService`: `getView(kingdom, userId)`; pushes `Kingdom.Support` to the ruler when tier or score changes by ≥ 2 points (rate-limited); `Kingdom.GetSupport` on request.
- Weights, tier bands and perk numbers in config `Support.luau`; every value within G12.3 (FORGE-05's caps spec asserts it).

## Validation
Lune specs: score from synthetic sample histories (last-minute deed cannot jump more than one tier; early mistake recoverable); tier boundaries; offers per tier and loyalty; `Caps.check` accepts and rejects at the limits. Determinism: same inputs, same output.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS
- [ ] FORGE-05 caps spec (FL-0076) passes against `Caps.luau` and `Support.luau`

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (SPECIFIED).
- 2026-10-12 forge-00: D-030: at VS-2, re-base support on spectators' loyalty and obedience (living-kingdom §6), so fear-led rulers have a dutiful crowd; the G12.3 caps are unchanged.
