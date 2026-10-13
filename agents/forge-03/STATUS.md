# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #71 job ack beats stale payload quota (unblocks FORGE-01's #61) · #74 HUD places NotificationController (#33 M1) · #76 ghost shows upgrade room + gap (#62 M-2) · #79 D-033 canonical kingdom colours · #66 FL-0088 gate + CitizenAnswered (#45), stacked on #74 · #63 FL-0060 (main merged at `4d1881a`). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #65. Closed: #13, #19. |
| Current task | FORGE-05 review rounds on #71/#74/#76/#79/#66/#63; merge main into what is left after each merge. Then SlotFit → Fit.typesFor and the doubles → FORGE-01's real services as they land; FL-0073 when FL-0070 lands |
| Last verified check | #71 `83bf46a` check.sh PASS (868/0), 6 mutations killed · #74 PASS (866/0), 3 killed · #76 PASS (865/0), 6 killed · #79 PASS (891/0), parity mutation · #66 `dc9ed86` PASS (913/0) · #63 `4d1881a` PASS (917/0) |
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
- **Done:** #65 merged. FORGE-05's #61 measurement → #71 (ack before the payload's quota; forget it
  when a later push shows it or after 3 s). #33 M1 → #74 (NotificationController placed, × scale,
  only on change). #62 M-2 → #76 (ghost room outline, "Leave room for upgrades"). #45 →
  CitizenAnswered in #66. D-033 → #79 (tinctures = Kingdoms.luau, enforced; spec world sends them).
- **Verified:** check.sh PASS on every branch; each fix has a spec that fails without it; renders
  looked at (notify-drawer with FORGE-04's real controller, placing-room, standings/HUD colours).
- **Unverified:** Studio; FORGE-01's real Population (#61) and Converse; the ghost outline's look.
- **Next:** review rounds; merges of main into what is left.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
