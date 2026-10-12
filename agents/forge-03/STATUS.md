# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #48 FL-0087 follow-ups (main merged, plot-pick re-shot) · #52 FL-0088 citizen card + conversation → #55 FL-0065 job panel (+ population plumbing) · #58 follow-ups of the #41/#44 reviews (from main). In progress: FL-0060 (subagent, stacks on #55). Merged: #9, #12, #23, #24, #25, #34, #41, #44. Closed: #13, #19. |
| Current task | FL-0060 review when the subagent finishes; FL-0073 waits on FORGE-01's FL-0070; L4 (Costs vs FORGE-01 Buildings) asked of FORGE-00 |
| Last verified check | #58 `fe32a4a`: check.sh OVERALL PASS (game-001 569), 11 mutations killed; #48 `d7b06dc` PASS (565); #55 `1236577` PASS (532); #52 `ac70a45` PASS (522). Worker branch (main + all of them + FL-0018 work): OVERALL PASS (Lune 586, game-001 770). |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-01: Build.Slots/PlaceSlot with the fit rule or `fits` (`…-to-forge-01-slot-fit.md`), Kingdom.Reputation payload (`…-reputation-ui.md`), Sim.Inspect/Converse/Choose answers 6–11 (`…-conversation-ui.md`), ground height (`…-ground-height.md`). FORGE-02: lumber camp/quarry on L plots only? FORGE-00: Content/Reputation (FL-0083), L4 cost catalogue alignment. FORGE-05: Studio steps U1–U13. User: icon upload, optional. |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | done (#52) | |
| FL-0089 reputation strip + screen | done (#44); 0.5 | text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | 4–5 | needs `Match.Ended` (FORGE-01) |
| FL-0065 job panel | done (#55) | the citizen card itself is FL-0088 |
| Swap doubles for FORGE-01's real services (#31 and the slot service) | 3 | contract mismatches show up here |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Remaining** | **9–11** | FL-0060 review (2–3, built by a subagent), FL-0089 content switch (0.5), real-service swap (3), playtest fixes (3). FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

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
