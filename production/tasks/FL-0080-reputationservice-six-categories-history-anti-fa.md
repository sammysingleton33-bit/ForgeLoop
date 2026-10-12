---
id: FL-0080
title: ReputationService (six categories, history, anti-farming) and kingdom conditions (G13.4)
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0083]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence: []
---

# ReputationService (six categories, history, anti-farming) and kingdom conditions (G13.4)

## Outcome
Each ruler has six reputation values (Compassion, Honor, Competence, Courage, Authority, Fear) with a readable history. Kingdom happiness, stability and morale are tracked separately. Personalities react differently, and reputation cannot be farmed (VS-1 rows 8 and 9).

## Requirements
- `ReputationService:get` and `:apply` (G13.4):
  - values are clamped 0..100, with start values from Content `Reputation.categories`;
  - history entries hold time, category, delta, plain text and source.
- Anti-farming uses `ContentQuery.repeatMultiplier` per `farm_key`. Construction counts only when its `condition` (need) holds.
- `content/reputation/actions.csv` hooks fire on G9 events with audience and audience_condition (direct vs indirect effects). Example: barracks funding raises soldiers' loyalty, and civilians resent it only while fed ratio < 0.6.
- `Kingdom` gains happiness, stability and morale. Rates and thresholds go in config `Society.luau`.
- Remotes `Kingdom.Reputation` and `Kingdom.GetReputation`.
- Rules (user):
  - fighting enemies is not a compassion loss;
  - peacekeeping is not rewarded by itself;
  - one decision never triggers a kingdom-wide rebellion.

## Validation
Lune specs:
- clamps and history;
- the decay window;
- need conditions;
- audience conditions;
- trait-weighted loyalty differences between two citizens with opposite traits;
- an attack action leaves compassion unchanged.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
