---
id: FL-0001
title: Shared operating contract and task tooling
track: infra
owner: forge-00
status: ACCEPTED
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 3
evidence:
  - "2026-10-12 tools/tests: 32 passed (forge-00, cloud session)"
---

# Shared operating contract and task tooling

## Outcome
FORGELOOP has shared rules, team/ownership map, interface contracts v0, git/integration procedure, decisions log and a stdlib-only task tool (validate, list, new, set-status, dashboard, prompt, check).

## Requirements
- AGENTS.md, CLAUDE.md, DECISIONS.md, docs/workflows/*, docs/architecture/interfaces.md
- tools/forge.py with tests

## Validation
python -m pytest -q tools/tests; python tools/forge.py validate

## Completion criteria
- [ ] Tool tests pass
- [ ] All task files validate

## Log
- 2026-10-12 forge-00: created (ACCEPTED).
