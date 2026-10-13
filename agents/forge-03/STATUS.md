# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #65 #55 M1/M2 + lows + #58 follow-ups (from main; FORGE-05 holds FORGE-01's #61 on it) · #66 FL-0088 gate: answer cost + every risk before choosing, M2, M3, L1–L8 (from main; gates FORGE-01's Kingdom.Converse) · #63 FL-0060 army drawer, objective tracker, slice summary (main merged at `568dbdc`). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58. Closed: #13, #19. |
| Current task | Answer FORGE-05 on #65 / #66 / #63; merge main into whichever is still open after each merge. Then switch SlotFit to Fit.typesFor (FORGE-01's #56) and the doubles for FORGE-01's real services as they land; FL-0073 when FL-0070 lands |
| Last verified check | #65 `5f0862b`: check.sh OVERALL PASS (game-001 808/0), 25 mutations killed. #66 `0432c2c`: PASS (817/0), 21 mutations caught. #63 `568dbdc`: PASS (874/0), 78 renders pixel-compared after the main merge. |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-01: Build.Slots/PlaceSlot with the fit rule or `fits` (`…-to-forge-01-slot-fit.md`), Kingdom.Reputation payload (`…-reputation-ui.md`), Sim.Inspect/Converse/Choose answers 6–11 (`…-conversation-ui.md`), ground height (`…-ground-height.md`). FORGE-02: lumber camp/quarry on L plots only? FORGE-00: Content/Reputation (FL-0083), L4 cost catalogue alignment. FORGE-05: Studio steps U1–U13. User: icon upload, optional. |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | done (#52); gate in #66 | costs and risks before choosing |
| FL-0089 reputation strip + screen | done (#44); 0.5 | text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | done (#63) | doubles until FORGE-01's FL-0052 |
| FL-0065 job panel | done (#55); M1/M2 in #65 | |
| Swap doubles for FORGE-01's real services (#31 and the slot service) | 3 | contract mismatches show up here |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Remaining** | **6–7** | review rounds on #63/#65/#66 (0.5–1), real-service swap as FORGE-01 lands Converse/Army/Slots/Population (3), playtest fixes (3). FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

## Last report
- **Done:** #65: FORGE-05's #55 M1 (job requests step from the newest target; promised adds reserved
  against the free pool) and M2 (refetch and clear population on a kingdom change), #55 lows,
  #58 follow-ups 1-6. #66: FL-0088 gate: cost chips and every risk ("40 %" + sentence) before
  choosing, unaffordable answers disabled, late-reply tokens, Choose in flight per showing, L1-L8;
  handoff to FORGE-01 with the option shape. #63: main (#58) merged, tracker follows the strip flag.
- **Verified:** check.sh PASS on each branch (808 / 817 / 874); every fix has a spec that fails
  without it (25 + 21 + 1 mutations); renders re-shot and looked at.
- **Unverified:** Studio (U13, U15); FORGE-01's real Population, Converse/Choose and slot services.
- **Next:** FORGE-05 review rounds; real-service swaps as FORGE-01 lands them.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
