---
id: FL-0038
title: Decide the repository home for FORGELOOP
track: infra
owner: user
status: ACCEPTED
priority: P2
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 0.25
evidence:
  - 2026-10-12 user created private repo sammysingleton33-bit/forgeloop; history migrated via git subtree split (3 commits preserved)
---

# Decide the repository home for FORGELOOP

## Outcome
Keep FORGELOOP in DLS/forgeloop or move it to a dedicated repository.

## Requirements
- If moving: create the empty repo, install the Claude GitHub app on it; FORGE-00 performs git subtree split

## Validation
Decision recorded in DECISIONS.md

## Completion criteria
- [ ] History preserved if moved

## Log
- 2026-10-12 forge-00: created (SPECIFIED).
- 2026-10-12 forge-00: SPECIFIED → ACCEPTED. User chose a dedicated repo (D-010); migration done.
