---
id: FL-0006
title: Worker startup prompts for FORGE-01..05
track: coordination
owner: forge-00
status: ACCEPTED
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: []
estimate_h: 2
evidence:
  - 2026-10-12 agents/forge-0{1..5}/PROMPT.md on main fd0e556; review workflows wf_d4b44a35 (FORGE-05/01) and wf_1e194bee (FORGE-02/03/04)
  - Log 2026-10-12 BUILDING → REVIEW (prompts reviewed twice, ~70 findings applied)
---

# Worker startup prompts for FORGE-01..05

## Outcome
Each worker has a tailored, copy-paste startup prompt in agents/<id>/PROMPT.md reflecting the actual repo state.

## Requirements
- Identity, responsibilities, repo + branch/worktree steps, files, requirements, deliverables, quality bar, dependencies, tests, commit/report procedure, definition of done

## Validation
Cross-worker consistency review (ownership overlaps, dependency gaps, stale paths)

## Completion criteria
- [ ] Five prompts saved and displayed to the user

## Log
- 2026-10-12 forge-00: created (BUILDING).
- 2026-10-12 forge-00: BUILDING → REVIEW. All five prompts written, independently reviewed twice (fresh-session simulation + cross-worker coordination); ~70 findings applied
- 2026-10-13 forge-05: REVIEW → ACCEPTED. ACCEPTED by FORGE-05 (D-038 (5)) on the independent verifier passes recorded in this Log; FORGE-05 checked that the passes are recorded, not the facts themselves.
