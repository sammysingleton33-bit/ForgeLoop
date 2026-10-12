# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #41 FL-0059 M1 follow-up → #44 FL-0089 reputation → #52 FL-0088 citizen card + conversation; and #41 → #48 FL-0087 follow-ups (slot fit by real sizes, one order per plot, spend badge). Merge #41 first; #44/#52 and #48 are independent of each other (two screenshots conflict: regenerate `plot-pick-{tablet,desktop}` with the shoot-luau command when the second lands). Merged: #9, #12, #23, #24, #25, #34. Closed: #13, #19. |
| Current task | FL-0060 (army/objective panels, slice summary) next; FL-0073 waits on FORGE-01's FL-0070; L4 (Costs vs FORGE-01 Buildings) via FORGE-00 |
| Last verified check | #52 `ac70a45`: check.sh OVERALL PASS (Lune 486, game-001 522), ownership PASS; #48 `9bb4ea3`: PASS (game-001 461); #44 `c8cc865` PASS (484); #41 `37bcfe3` PASS (452). Worker branch with all of them + main: see below. |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-01: Build.Slots/PlaceSlot with the fit rule or `fits` (`…-to-forge-01-slot-fit.md`), Kingdom.Reputation payload (`…-reputation-ui.md`), Sim.Inspect/Converse/Choose answers 6–11 (`…-conversation-ui.md`), ground height (`…-ground-height.md`). FORGE-02: lumber camp/quarry on L plots only? FORGE-00: Content/Reputation (FL-0083), L4 cost catalogue alignment. FORGE-05: Studio steps U1–U13. User: icon upload, optional. |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | 2–3 | built by a subagent; review, renders, fixes, PR |
| FL-0089 reputation strip + screen | 2 | same; text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | 4–5 | needs `Match.Ended` (FORGE-01) |
| FL-0065 job panel remainder | 1 | the citizen card itself is FL-0088 |
| Swap doubles for FORGE-01's real services (#31 and the slot service) | 3 | contract mismatches show up here |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Total** | **15–17** | FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

## Last report
- **Done:** #34 merged. #48: FORGE-05's #34 follow-ups (fit by World/Layout slot sizes, per-slot order
  guard, plot refusal wording, build mode closes panels, string building ids) and a readable spend
  badge. #52: FL-0088 reviewed — stacked on #44, card and conversation keyed against pushes, phone
  sheet back under the pills (four answers at 844×390), U13 Studio steps.
- **Verified:** each fix has a spec that fails without it (6 mutations in #48, 2 render-key mutations
  in #52); renders re-shot and looked at; check.sh PASS on every branch.
- **Unverified:** Studio (G6); FORGE-01's real slot, reputation and conversation services.
- **Next:** FL-0060; FL-0089 text → Content/Reputation when FL-0083 lands.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
