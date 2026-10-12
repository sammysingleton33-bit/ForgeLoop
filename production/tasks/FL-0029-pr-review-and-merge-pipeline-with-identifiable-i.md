---
id: FL-0029
title: PR review and merge pipeline with identifiable integration builds
track: qa
owner: forge-05
status: BUILDING
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0028]
estimate_h: 3
evidence: []
---

# PR review and merge pipeline with identifiable integration builds

## Outcome
Worker PRs are reviewed, validated on the merge result and merged into main with a merge commit (D-011); every integration commit yields a stamped .rbxl artifact.

## Requirements
- Follow docs/workflows/git-and-integration.md
- BuildInfo stamp visible in Studio

## Validation
First worker PR merged with evidence; artifact downloaded and BuildInfo checked

## Completion criteria
- [ ] Merge checklist recorded in production/quality-gates/

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-05: READY → BUILDING. First integration done (PR #1). Building PR template, ownership gate (G8), integration log, merge checklist, branch-protection handoff.
