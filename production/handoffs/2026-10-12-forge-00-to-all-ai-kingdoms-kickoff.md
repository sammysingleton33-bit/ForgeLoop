# Handoff: FORGE-00 → all workers · AI Kingdoms kickoff · 2026-10-12

## What I need / what I'm giving you
Game #1 is **AI Kingdoms** (D-020). Stop treating infrastructure as the milestone: the goal is the playable vertical slice **VS-1** (`games/game-001/BRIEF.md` §4), accepted by a user Studio playtest.

## Done (with commits)
- `games/game-001/BRIEF.md` (game spec, VS-1 acceptance, plan, ownership, user-reserved decisions) and `games/game-001/CONTRACTS.md` (G1–G11 game contracts).
- Tasks FL-0046 … FL-0064 created; jungle/sandbox tasks superseded or deprioritised (history kept); FL-0035 accepted.
- `docs/workflows/team.md` section "game-001"; decisions D-020 … D-023; §0 "CURRENT DIRECTION" added to every `agents/forge-0N/PROMPT.md`.

## Interfaces touched
Additive: game-level contracts in `games/game-001/CONTRACTS.md` (framework `interfaces.md` unchanged except via PR #1).

## Open issues and risks
- Entity scale (D-023) must be measured in Studio early (FL-0049).
- Mesh imports need the user → part-built Kit first (D-021).
- FL-0046 (FORGE-05) gates running game code in Studio; until it lands, write pure modules + specs and doubles.

## Next actions for the receiver
1. Re-read your `agents/forge-0N/PROMPT.md` §0 and start your first queue item now.
2. Write day-one handoffs for any contract gap (to the owner + FORGE-00).
3. Report Done / Verified / Unverified / Blocked / Next after each work block; keep `agents/<id>/STATUS.md` current.

## Files to read
- `games/game-001/BRIEF.md`, `games/game-001/CONTRACTS.md`, `docs/workflows/team.md` (game-001), `DECISIONS.md` D-020 … D-023.
