---
id: FL-0083
title: "Content library: editable CSV, spreadsheet round-trip, generated Content modules, ContentQuery, DRAFT starter content"
track: design
owner: forge-00
status: BUILDING
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 6
evidence: []
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
