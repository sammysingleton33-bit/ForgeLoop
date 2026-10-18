---
id: FL-0029
title: PR review and merge pipeline with identifiable integration builds
track: qa
owner: forge-05
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0028]
estimate_h: 3
evidence:
  - PR #3 merged 3a7b983 (ownership gate, 139 pytest incl. team.md + game-001 consistency tests); worker PRs #4 (1e27297) and #5 (fb5c086) merged through merge-checklist.md with merge-result checks, security review and integration-log lines; CI artifacts forgeloop-main-<sha> uploaded for every merge, BuildInfo sha checked in the CI log (artifact download from the sandbox is blocked by the proxy)
  - integration-log rows #17, #40, #57; main CI green
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
- 2026-10-12 forge-05: BUILDING → REVIEW. Pipeline live: ownership gate (G8) in CI, PR template, merge checklist, integration log; first worker PRs (#4, #5) merged through the full procedure. G6 pending: user checks the BuildInfo sha in Studio (S2).
- 2026-10-13 forge-05: REVIEW → REVIEW. D-046 log: pipeline follow-ups merged: #17 (db58aa8) the G8 ownership gate diffs PRs against the test merge commit's first parent; #40 (1ba711b) merge checklist: PR base must be main, confirm main moved after the merge; #57 (4a67058) the CI tools job installs openpyxl so the content workbook tests run. REVIEW, only G6 pending (the user's branch-protection check).
