# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-fl00xx` |
| Open PRs | #25 FL-0059 kingdom HUD + build menu (merged with main, ownership PASS) · #34 FL-0087 plot picker + upgrade panel (stacked on #25). In progress: FL-0088 conversation panel + citizen card v2, FL-0089 reputation strip + screen (PRs stacked on #25 when reviewed). Merged: #9, #12, #23, #24. Closed: #13, #19 (repo weight, D-007). |
| Current task | FL-0088 and FL-0089 (D-030 order: FL-0087 → FL-0088 → FL-0089, then FL-0073) |
| Last verified check | #34 head `434a5e5`: `check.sh` OVERALL PASS (Lune 485, game-001 151), forge validate 96/0, ownership PASS against main. #25 `2b24fcc`: ownership PASS, validate 96/0 (check.sh PASS at `7d1e35a`; the later main merge only changed ownership.json + its test). |
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
- **Done:** FL-0087 — tapping a free plot opens "Build here" with only the structures that fit its
  size, each with its cost against the treasury, build time and what it gives; "Build X here" calls
  `Build.PlaceSlot`, toasts, and the chip follows. Tapping a building opens the upgrade panel: level,
  next level's cost and time, "Now" vs "Lv N" benefits, one CTA (or why not); another kingdom's
  building is read-only. D-030 level costs in `config/Costs.luau`.
- **Verified:** 9 PlotUI specs (slot-size filter, affordability, PlaceSlot, refusals, pending guard,
  upgrade, foreign building) over the real RemoteService + TreasuryService and a slot double; Luau
  renders (plot-pick, building-upgrade at 3 sizes; plot-pick-list phone; building-foreign desktop)
  looked at.
- **Unverified:** Studio (G6); FORGE-01's real slot service and FORGE-04's real selection (doubles only).
- **Next:** review FL-0088 / FL-0089, PRs; then FL-0060, FL-0073.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
