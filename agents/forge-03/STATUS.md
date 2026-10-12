# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12) |
| Open PRs | #12 FL-0058 Treasury/Production (`forge/03-ui-economy-fl0058`), #13 FL-0020 UI foundation (`forge/03-ui-economy-fl0020`); both CI green, no review yet. #9 hour-0 stubs merged. |
| Current task | FL-0059 Kingdom HUD and build menu (game-001, G8 remotes) |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS on the worker branch after the cleanup: 431 Lune specs, Selene 0/0, StyLua 135 files, sandbox + game-001 build and place check, game-001 specs 29 |
| Blockers | none; Studio checks (G6) need the user |
| Needs from others | FORGE-00/01: a G8 remote carrying population/citizens to clients (FL-0065 citizen card). FORGE-02: `Kit.footprint` on main (placement ghost falls back to a fixed footprint). FORGE-04: NotificationController, InputModeController (toasts fall back to UI/ToastStack). User: icon uploads (`production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`). |

## Last report
- **Done:** hour-0 config stubs (merged); FL-0058 TreasuryService, ProductionService, Treasury
  remotes, VS-1 balance sheet (PR #12); FL-0020 UI kit, medieval theme, design tokens, icons,
  prototypes and Luau snapshot renderer (PR #13). Worker branch: pre-contract framework kingdom code
  removed (EconomyTreasuryService, Economy remotes, Construction, UIController, UI/Kingdom); framework
  economy modules no longer require game config (`setDefault`); sandbox config generic.
- **Verified:** check.sh green on the worker branch and both PR branches; mutation checks recorded in
  the PR bodies.
- **Unverified:** anything in Roblox Studio (G6); icons (glyph fallbacks until uploaded).
- **Next:** FL-0059 (prototypes in `games/game-001/design/ui/`, controllers `KingdomHud*`,
  `BuildMenu*`), then FL-0065, FL-0060. P2 later: FL-0018, FL-0045, FL-0019.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services and FORGE-04 controllers; listed in each PR.
