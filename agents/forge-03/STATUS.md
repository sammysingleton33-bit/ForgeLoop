# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session); one PR branch per task: `forge/03-ui-economy-<task>`; Crownfall: `forge/03-ui-economy-crownfall` |
| Open PRs | FL-0073d support meter + breakdown (`forge/03-ui-economy-support`, 2026-10-19). Merged this week: #185, #188, #192, #210, #214, #215. |
| Current task | FL-0073 (BUILDING) against SupportModel on main (CONTRACTS v0.4-g11e), three PRs, all dark until FORGE-01 serves the remotes: (d) support meter + breakdown, in PR; (e) citizen-card perk previews + petitions (`Kingdom.FulfilPetition`); (f) Results recap: five moments, triggers fired, crowd outcome. Later: FL-0129c wall tool + Gate after FL-0126 part 2 |
| Last verified check | support branch: full Lune suite 2115/0 (136 files), SupportUI 20/0, mutations FL-0073-support.py (see PR), selene 0/0, stylua clean, phone-audit 0 issues; renders looked at (desktop + phone-se) |
| Blockers | none; the meter shows nothing until FORGE-01 declares `Kingdom.Support` / `Kingdom.GetSupport` (SupportService, FL-0071) |
| Needs from others | FORGE-01: SupportService serving Kingdom.Support / GetSupport (SupportView G12.1) and Kingdom.FulfilPetition; `role` / `petition` on CitizenService:inspect. FORGE-05: review the FL-0073d PR. User: Studio U24, U25 once served. |

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
