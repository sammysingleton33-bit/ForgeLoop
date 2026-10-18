---
id: FL-0133
title: "DRAFT VS-2 dialogue: war, raid, siege, famine, arena petitions and key-citizen pledge lines (isolated until the owner approves)"
track: design
owner: forge-06
status: READY
priority: P2
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0102]
evidence: []
---

# DRAFT VS-2 dialogue: war, raid, siege, famine, arena petitions and key-citizen pledge lines (isolated until the owner approves)

## Outcome
A DRAFT set of citizen lines for the full match (war declared, after a raid, under siege, famine, an outpost lost, before the arena, key-citizen pledges with loyalty variants) ready for the owner to review. Nothing becomes final content without the owner's approval.

## Context
- The owner told FORGE-06 to keep work isolated and commit nothing until approved; that still holds. D-035/D-036 conventions; content pipeline FL-0083 (CSV → generated modules).

## Requirements
- Draft in FORGE-06's isolated workspace in the existing CSV shapes (scenarios, responses, decisions, consequences), with trait/loyalty variants and the real effect each choice has.
- Key-citizen pledge lines for the six arena key citizens (crown-arena.md §4), each at loyalty ≥ 80 and a refusal line below.
- Flag any line that needs the owner's wording; never edit owner-authored lines.

## Validation
content.py check passes on the draft locally; the owner reviews the draft.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
