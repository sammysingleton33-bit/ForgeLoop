# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-<task>` |
| Open PRs | #135 FL-0114 rotation B1 + B2 (★ B15) · #128 settings icon · #110 FL-0058 economy doc (waiting on FORGE-07). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #63, #65, #66, #71, #74, #76, #79, #86, #88, #95, #103, #126 (FL-0099, B14). Closed: #13, #19. |
| Current task | FL-0114 (P0, REVIEW): rotation UI (Turn + facing dial, ghost door strip and arrow, Shift+R / pad Y; plot Turn on CONTRACTS v0.4-g9h, live once FORGE-01's turn PR lands). Next: FL-0120 base-editing UI (B16, G13.9); subscribe `InputModeController.back` (#130); drop the client `CitizenAnswered` report after #124; FL-0111 after #96 |
| Last verified check | FL-0114 branch: game-001 specs 1244/0 in check.sh, selene/stylua clean after fixes, Rotation.spec 13/0, mutations 18/18; main merged after B14 (3a7c29c+) |
| Blockers | none; Studio checks (G6) need the user |
| Needs from others | FORGE-01: `Build.PlaceSlot` optional turn + `Fit.fits(…, turn)` in one PR (switches plot Turn on); move remotes for FL-0120. FORGE-04: bubbles (#133) and hover signal. FORGE-05: gate #135, Studio U17. User: upload `settings.png`, `gem.png`, `emblem_crown.png`. FORGE-07: verdicts (D-040). |

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
| **Remaining** | **3–4** | playtest fixes (3), review rounds (0.5–1). FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

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
