# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #66 FL-0088 gate + B1 confirm step (`256ad31`, main merged, CI running) · #86 crest plate for light tinctures (D-033 follow-up) · #63 FL-0060 (`184796f`: review fixes, #74 merge, #70 codes), held for FORGE-01's #70. Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #65, #71, #74, #76, #79. Closed: #13, #19. |
| Current task | Review rounds on #66 (Converse gate), #76, #79; #63 after #70. Next: FL-0099 cinematic conversation UI (D-036, G13.8) once FL-0088 merges and FL-0097/FL-0098 exist (reuse ConversationController); SlotFit → Fit.typesFor; doubles → FORGE-01's real services as they land |
| Last verified check | #66 `256ad31` check.sh PASS (967/0) · #63 `184796f` PASS (971/0) · #86 PASS (938/0), 4 mutations killed |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-01: Converse/Choose server (risk `text` = filled sentence, Choose re-checks cost), #70 (army), Fit.typesFor (#56). FORGE-04: `limit` on NotificationController:place() (asked). FORGE-00: choiceRisks content PR. FORGE-05: Studio steps U4.5, U5.5, U13, U15. |

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
- **Done:** #71 and #74 merged. #66: main merged, then FORGE-05's B1 (confirm step for answers with a
  cost or a risk, fits the 750 × 311 safe area), M1, L1-L5 and CitizenAnswered (#45). #63: FORGE-05's
  M1/M2 destroy paths, lows 4-7, destroy specs; held for #70. D-033 (#79) approved by FORGE-00.
- **Verified:** check.sh PASS on each branch; 13 + 13 mutations killed; renders looked at (builder
  bug and confirm fix on phone, army-sent toast).
- **Unverified:** Studio; FORGE-01's real Converse/Choose and army services.
- **Next:** FL-0099 after FL-0088 merges and FL-0097/FL-0098 exist.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
