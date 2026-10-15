---
id: FL-0115
title: Citizen bubbles readable and tappable from the aerial camera (B15 #3; FL-0091 follow-up)
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0091, FL-0090]
evidence:
  - CitizenBubbles.spec 39/39; mutations.py FL-0115 12/12 + FL-0091 43/43 CAUGHT; headless aerial renders zoom 120/220 phone+desktop (roblox/tests/unit/experience/scenes/shots); Studio unverified (E8 9-11)
  - check.sh PASS on the merge (game-001 1312/0); mutations FL-0091+FL-0115 55/55; own mutants 3/3; renders opened
  - InputMode.spec 16/16; FeedbackHighlight.spec 6/6 (with the real InputModeController); mutations.py FL-0115 23/23 CAUGHT; Studio unverified (E8 step 12)
  - check.sh PASS on the merge (game-001 1328/0); FL-0115 rows 23/23; own mutants 2/3
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
- 2026-10-15 forge-04: BUILDING → REVIEW. PR #133 (★ B15): always-on-top glyph badges + 17 px cards; Bubbles:layout gives words to at most 3 (2 phone, 1 past 150 studs) and only where a card hides no other bubble (every request badge reserved first); new-request pop (not under reduced motion); tap selects the citizen via InputModeController (G13.6), GUIs under PlayerGui, no input while placing; Studio E8 steps 9-11 + operator probe. B16 (this task's B16 line, FORGE-00 order: #133 -> hover -> FL-0121 -> these): off-screen request indicators, and a key to cycle requests focusing the camera via RulerCameraController:focusOn (FORGE-03's 'citizens waiting' control calls the same cycle).
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #133 (d5587b7), B15 item 3; only G6 (E8 steps 9-11: taps reach the bubble, placing still places) left; phone badge overlap known (B16 cycle requests)
- 2026-10-15 forge-04: REVIEW → REVIEW. Hover follow-up (FORGE-00: after #133): InputModeController.hovered/hover (mouse only, explore mode, same EntityController:pick as a tap; GUI, build mode clear it) and FeedbackHighlightController (game-001, Feedback*): a light outline on the hovered citizen and a gold one on the selected citizen, on top of roofs, none during the conversation stage or on LOD-hidden or released rigs; Studio E8 step 12
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #137 (e7ab2f5): hover and selection outlines; follow-up spec: clear hover on leaving explore mode
