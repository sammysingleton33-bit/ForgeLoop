# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-<task>` |
| Open PRs | #110 FL-0058 economy doc (D-045, 6–8 min slice), waiting on FORGE-07 · FL-0099 cinematic conversation UI (`forge/03-ui-economy-fl0099`, stacked on nothing; merges with #108, #84, #85 under FL-0101, D-046). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #63, #65, #66, #71, #74, #76, #79, #86, #88, #95, #103. Closed: #13, #19. |
| Current task | FL-0099 (P1, REVIEW): cinematic conversation UI (G13.8). Next: FL-0101 fixes after FORGE-05's Studio run; Talk as the primary action lights up when FORGE-01's #77 sends `hasRequest` (client done) |
| Last verified check | FL-0099 branch: check.sh exit 0 (see the PR); on a local merge with #108, #84 and #85: game-001 1263/0 and a real Converse → Kit.portrait contract check |
| Blockers | none; Studio checks (G6) need the user |
| Needs from others | FORGE-05: integrate the G13.8 set and run U16 (FL-0101). FORGE-04: phone framing above the stage (handoff 2026-10-13 FL-0099). FORGE-01: `not_on_plot` on the Reasons line; `hasRequest`. User: upload `gem.png` and `emblem_crown.png`. FORGE-07: verdicts (D-040). |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | done (#52); gate in #66 | costs and risks before choosing |
| FL-0089 reputation strip + screen | done (#44); 0.5 | text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | done (#63) | doubles until FORGE-01's #70 |
| FL-0105 refusal codes, crest, achievement toast | done (#86) | |
| FL-0087 plot picker on `Fit.typesFor` | 1 | |
| Swap doubles for FORGE-01's real services | 3 | contract mismatches show up here |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Remaining** | **7–8** | review rounds (0.5–1), FL-0087 switch (1), real-service swap (3), playtest fixes (3). FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

## Last report
- **Done:** FL-0099 cinematic conversations (G13.8). The citizen's portrait (`Kit.portrait`) rises
  from the bottom, with their question in a bubble and the answers beside it. Consequence chips show
  after an answer, and the stage closes by itself. The world stays visible (dim ≤ 18 %). opened/closed
  go to the camera, and `Kingdom.EndConversation` is called on every close. The FL-0088 panel is the
  fallback. The renderer now draws ViewportFrames.
- **Verified:** 32 specs, 30 mutations killed. On a local merge with #108/#84/#85: 1263/0, plus a real
  payload → real portrait check. Renders were looked at on three sizes (REVIEW-stage.md).
- **Unverified:** Studio (U16, FL-0101).
- **Next:** FL-0101 fixes; `Costs.luau` tuning only after the user plays.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`, `ArmyDoubles`,
  `CitizenDoubles` with #108's cinematic fields) and FORGE-02 (`PortraitDoubles` for #85), and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
