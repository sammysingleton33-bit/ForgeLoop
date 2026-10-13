# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-<task>` |
| Open PRs | `forge/03-ui-economy-docs` (FL-0058 doc: D-045 births, 6–8 min slice; this file). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #63, #65, #66, #71, #74, #76, #79, #86, #88, #95, #103. Closed: #13, #19. |
| Current task | FL-0058 economy doc (D-045, D-044 (1)). Next: FL-0099 cinematic conversation UI (G13.8) once FL-0097/FL-0098 exist; Talk as the primary action lights up when FORGE-01's #77 sends `hasRequest` (client done) |
| Last verified check | docs PR: check.sh exit 0, validate, ownership (see the PR) · #103 check.sh exit 0 before merge |
| Blockers | none; Studio checks (G6) need the user |
| Needs from others | FORGE-01: `not_on_plot` on the Reasons line once served (the client words it already). User: upload `gem.png` and `emblem_crown.png` (handoff 2026-10-13-forge-03-to-user-icons-d039). FORGE-07: post-merge reviews (D-040). |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | done (#52); gate in #66 | costs and risks before choosing |
| FL-0089 reputation strip + screen | done (#44); 0.5 | text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | done (#63, #95) | runs against FORGE-01's real Army server (#70) |
| FL-0105 refusal codes, crest, achievement toast | done (#86, #103) | emblems per D-039 |
| FL-0087 plot picker on `Fit.typesFor` | done (#88) | |
| Swap doubles for FORGE-01's real services | done | FORGE-05 ran Army (#70), conversation (#77) and plots (#89) end to end |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Remaining** | **3–4** | playtest fixes (3), review rounds (0.5–1). FL-0099 (P1) and FL-0073 Crown Arena UI (P2, 18 h) are outside VS-1 |

## Last report
- **Done:** every FORGE-03 VS-1 PR is merged (#63, #66, #86, #88, #95, #103). The economy doc now
  records D-045 (a birth needs a well-fed kingdom and a free bed, no treasury food) and the 6–8 minute
  slice (D-044 (1)), with the rate targets re-derived for it.
- **Verified:** check.sh exit 0 on each branch; mutations listed per PR; renders looked at.
- **Unverified:** Studio (G6); the drawn emblems and the 💎/★/🏅 glyphs on each platform.
- **Next:** FL-0099 once FL-0097/FL-0098 exist; `Costs.luau` tuning only after the user plays.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`,
  `ArmyDoubles`, `CitizenDoubles`) and FORGE-04 controllers (`InputModeController.selected`); listed
  in each PR.
