# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12) |
| Open PRs | #12 FL-0058 Treasury/Production, #13 FL-0020 UI kit (kit now in `roblox/src/shared/UI`), #19 FL-0059 kingdom HUD + build menu (stacked on #12, #13). All gates green at push. #9 hour-0 stubs merged. |
| Current task | FL-0065 citizen card + job panel (needs a population remote: request in the FORGE-01 build-ui handoff) |
| Last verified check | FL-0059 branch `0a0fe44`: `check.sh` OVERALL PASS (Lune 331, game-001 82, both places); pytest 141; forge validate 77/0; ownership PASS |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's Kingdom/Match/Build remotes |
| Needs from others | FORGE-01: confirm the G8 assumptions and reason vocabulary, decide `Kingdom.Population` (`production/handoffs/2026-10-12-forge-03-to-forge-01-build-ui.md`). FORGE-04: skip explore taps in build mode (`…-to-forge-04-build-mode.md`). FORGE-05: Studio steps U1–U9 (`…-to-forge-05-fl0059-studio.md`). FORGE-00: interfaces §9 kit path is now `shared/UI` (PR #13). User: icon upload, optional (`…-to-user-ui-icons.md`). |

## Last report
- **Done:** FL-0059 — a player sees the kingdom (crest, name, keep level, regions, Crown Points,
  rulers, phase/clock), resources with spend/gain floats, picks a building with costs vs treasury,
  places it through a ghost checked by `Build.CanPlace`, gets a toast + construction chip; keep
  upgrade with large-spend confirmation. Prototype reviewed first; real Luau rendered at 3 sizes.
  Kit fixes found by the render (Panel header, pill delta without tweens) and the kit move to
  `shared/UI` (require policy) pushed to #13.
- **Verified:** 33 FL-0059 specs (17 end to end over the real RemoteService + TreasuryService);
  8 mutations each fail a spec.
- **Unverified:** Studio (G6); FORGE-01's real services (doubles only).
- **Next:** FL-0065 (citizen card, job panel) with a population double; FL-0060 (army/objective
  panels, slice summary from `Match.Ended`). P2 later: FL-0018, FL-0045, FL-0019.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services and FORGE-04 controllers; listed in each PR.
