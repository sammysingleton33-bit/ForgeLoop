---
id: FL-0115
title: Citizen bubbles readable and tappable from the aerial camera (B15 #3; FL-0091 follow-up)
track: build
owner: forge-04
status: BUILDING
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0091, FL-0090]
evidence: []
---

# Citizen bubbles readable and tappable from the aerial camera (B15 #3; FL-0091 follow-up)

## Outcome
From the default aerial zoom a player notices a citizen's request bubble at once and can tap it to select that citizen, on desktop and phone.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- Today: a fixed 180×46 BillboardGui, AlwaysOnTop false (`CitizenBubbleController`, FORGE-04's file; D-049 ownership ruling: FORGE-03 does not edit it and contributes text style via its UI kit only).

## Requirements
- A minimum on-screen size with distance scaling.
- Icon-first, with a pulse when new.
- Not hidden by roofs (AlwaysOnTop or equivalent).
- Tap or click on the bubble selects the citizen; hit area ≥ 44 px on phone.
- B16 (not required for B15): off-screen edge indicators and a key to cycle requests with the camera focus.

## Validation
Automated: specs and mutations; aerial renders at default and maximum zoom looked at. Studio: B15 checklist bubble rows (the local Studio MCP session).

## Completion criteria
- [ ] PR merged after review.
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
