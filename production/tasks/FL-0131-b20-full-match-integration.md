---
id: FL-0131
title: "B20 full-match integration build, gates and Studio rows; release-candidate checklist started"
track: qa
owner: forge-05
status: BUILDING
priority: P0
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence: []
---

# B20 full-match integration build, gates and Studio rows; release-candidate checklist started

## Outcome
FORGE-05 ships B20, the first build where a real four-kingdom match starts, progresses and ends, with a truthful works/doesn't-yet list, Studio rows for the owner's local Studio session, and the open review queue cleared.

## Context
- Owner directive 2026-10-18 section 6 (integration loop). Open PRs at audit: #177, #176, #118, #100 (held), #90. D-053.

## Requirements
- Clear the queue: gate and merge #177, #176, #118 once FORGE-07's re-reviews land; decide #100 with FORGE-01 (rebase or close); #90 Blender pipeline per FORGE-07's review.
- Integrate FL-0125 as soon as it is gated; cut B20 from it with studio-runs rows: start match, AI war in Conflict, elimination + spectate, reach Results, debug `match.mode slice` still runs the VS-1 rows.
- Measure and record: server tick ms at peak entities (headless and Studio indicative), part count, entity count. Keep check.sh inside its step limits (shards).
- Start `production/quality-gates/release-checklist.md` from FL-0032: launch-ready criteria from the directive section 7, each with its evidence owner and status.

## Validation
check.sh PASS on the cut sha, CI artifact, studio-runs row, release checklist file.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
- 2026-10-18 forge-05: READY → BUILDING. FORGE-05 started Operation Crownfall integration: queue first (#176, #177, #118 on FORGE-07's re-reviews; #90; #100 with FORGE-01), then FL-0125 → B20 cut, tick/part/entity measurement, release-checklist.md from FL-0032
- 2026-10-18 forge-05: BUILDING → BUILDING. B20 cut = main 9b688ec (#194, #186, #187 FL-0125): full four-kingdom match by default; studio-runs B20 row + asks; artifact pending main CI. Next: B20.1 ride-alongs (#195 human war/peace, #185 spectate screen, others)
