---
id: FL-0083
title: "Content library: editable CSV, spreadsheet round-trip, generated Content modules, ContentQuery, DRAFT starter content"
track: design
owner: forge-00
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence:
  - "PR #53 head 721d488: check.sh OVERALL PASS (Lune 486/0, game-001 596/0), pytest 251, content validate 0 errors, xlsx round-trip byte-identical, ownership PASS"
  - "content-followups-2: pytest 384 passed; check.sh OVERALL PASS (game-001 953/0); content validate 0 errors; adversarial verify found 3 issues (1 major), all repaired and re-verified"
---

# "Content library: editable CSV, spreadsheet round-trip, generated Content modules, ContentQuery, DRAFT starter content"

## Outcome
The user controls the dialogue and the citizen and reputation data in a spreadsheet: questions, answers, reactions, traits, names and effects. The game imports it safely, with text kept separate from mechanics (D-030).

## Requirements
- CSV sources in `games/game-001/content/` with the schema in `content/SPEC.md` and an editor guide in `content/README.md`.
- `tools/content/content.py` commands:
  - `validate`
  - `lint`
  - `build`
  - `check`
  - `export-xlsx`
  - `import-xlsx` (round-trip)
- Generated `src/shared/Content/*` modules and the pure `ContentQuery`.
- DRAFT starter content: 12 scenarios with about 36 responses, 18 traits, names, occupations, the six categories and about 25 ruler actions.
- Tests: pytest and Lune specs. An adversarial review covers dominance, farming, editorial usability and contract compatibility.

## Validation
`python3 tools/content/content.py validate` reports 0 errors. `pytest tools/tests` and `check.sh` pass. The spreadsheet round-trip is byte-identical, and a text-only edit changes only text.

## Completion criteria
- [ ] User has the workbook and has reviewed the DRAFT (FL-0095)

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (BUILDING).
- 2026-10-12 forge-00: PR #53 (REVIEW). A 3-lens adversarial review raised 31 findings, all reproduced: 29 fixed in full, 2 partly (sheet protection and two event rows skipped). Workbook DRAFT v1 sent to the user (FL-0095).
- 2026-10-13 forge-00: REVIEW → REVIEW. Stays REVIEW. Round 2 of the #67 review follow-ups (#2 choiceRisks/choicePreview fillNames, #3 multi-ruler fireAction, #5-#11) in PR forge/00-content-followups-2; CONTRACTS v0.4-g7. Remaining acceptance: the user's review of the DRAFT text (FL-0095).
