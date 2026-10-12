# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #25 FL-0059 kingdom HUD + build menu (flaky-spec fix `db89bd0`, ownership PASS; FORGE-05 merges when green 3/3) → #34 FL-0087 plot picker + upgrade panel → #41 FL-0059 M1 follow-up (menus keep their instances; L5–L8) → #44 FL-0089 reputation strip + screen. Each contains the ones before it; merge in that order. In progress: FL-0088 conversation panel + citizen card v2. Merged: #9, #12, #23, #24. Closed: #13, #19. |
| Current task | FL-0088 review (subagent), then FL-0060; FL-0073 waits on FORGE-01's FL-0070 |
| Last verified check | #44 head `56b6629`: `check.sh` OVERALL PASS (Lune 486, game-001 190), pytest 142, forge validate 96/0, ownership PASS. #41 `ddd1ad6`: PASS (game-001 158). #25 `db89bd0`: PASS (Lune 486, game-001 142); full game-001 suite 10/10 green after the connector fix (old code: 1 failure in 3). |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-01: `Build.Slots`/`GetSlots`/`PlaceSlot` as in `production/handoffs/2026-10-12-forge-03-to-forge-01-plots-ui.md` (the double's reason vocabulary and fit rule). FORGE-04: `InputModeController.selected` for slots and buildings (`…-to-forge-04-selection.md`). FORGE-05: Studio steps U1–U11 (`roblox/studio-tests/ui-economy.md`). FORGE-00: content library (FL-0083) for FL-0088/89 text. User: icon upload, optional (`…-to-user-ui-icons.md`). |

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
- **Done:** #25 blockers — ownership (log append) and the flaky ResourceInspected spec. The flaky spec
  was the UI kit's test connector (weak keys + Lune recycling instance userdata after GC), not the HUD.
  #41: M1 (open menus keep their instances; costs, CTA, progress, verdict patched in place; Modal per
  request) and L5–L8. #44: FL-0089 reviewed, stacked, drawer scenes re-shot, U12 Studio steps.
- **Verified:** specs fail before / pass after (connector, M1 5/5, L5, L6); 10 M1 mutations and 7
  FL-0089 mutations each fail a spec; 35 committed Luau renders pixel-identical after M1.
- **Unverified:** Studio (G6) for all of it; scroll restore on a rebuilt list in real Roblox; FORGE-01's
  real services (doubles only).
- **Next:** FL-0088 review + PR; FL-0060; switch FL-0089 text to `Content/Reputation` when FL-0083 lands.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
