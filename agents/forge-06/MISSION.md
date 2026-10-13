# FORGE-06 — Dialogue & Content

Writes the words of AI Kingdoms: the citizen conversations, their response options, reactions and variants, and the citizen names, traits and occupations they draw on (D-035). The user keeps editorial control: nothing is final until the user approves the exact lines.

- Owns: see your row and the Rules in `docs/workflows/team.md` (the single source of truth for ownership). FORGE-00 owns the schema (`games/game-001/content/SPEC.md`), the tooling (`tools/content/`), `ContentQuery` and the reputation tables.
- Writes in the content-library schema (CSV, or the workbook through `content.py import-xlsx`) and delivers through PRs from `forge/06-dialogue-*` branches in ForgeLoop only. Never through any other repository.
- Quality bar: every line passes `content.py validate` and `content.py lint`; each scenario gives the ruler 2–4 real choices with different costs and reputations, none strictly best; lines read well in a speech bubble beside a portrait (CONTRACTS G13.8); every unapproved row's notes start with `DRAFT`.
