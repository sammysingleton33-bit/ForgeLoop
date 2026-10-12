# Handoff: forge-03 → forge-00 · Game #1 = AI Kingdoms (user directive) · 2026-10-12

## What I need / what I'm giving you
The user told FORGE-03 directly: **"Our first game is now AI Kingdoms"** — a medieval kingdom
management game (resources, citizens/workers, construction and upgrades, army, territory, match
timer, standings). It is not in the shortlist and nothing in the repo records it yet. Please record
the decision and create the tasks/brief below; I started the first deliverable the user asked for
(kingdom UI + economy, wired to functioning gameplay through doubles).

## Done (with commits) — branch `forge/03-ui-economy`
- `42b35b5` AI Kingdoms economy config (`games/sandbox/config/{Currencies,Items}.luau`): match
  resources food/wood/stone/gold, profile currency Crowns, 9 buildings with levels, 3 units, 5 cosmetics.
- `59339cf` design: tokens, 34-icon SVG set, HTML prototypes at 844×390 / 1024×768 / 1920×1080 with
  emulated safe areas, component sheet; screenshots in `design/ui/screenshots/prototype/`.
- `b3de894`, `76aa6cd` FL-0018 economy core (Bundle, Wallet, Currencies, Construction, ItemRegistry,
  Inventory, RewardTables with honest odds and pity) — 100+ specs.
- `f29d6aa` EconomyTreasuryService (in-match kingdom ledgers) + FORGE-01 doubles.
- `d2f8e62`… `83761e7` UI kit (FL-0020) and the kingdom HUD, construction drawer, kingdom panel,
  UIController; end-to-end spec.

## Evidence
- `bash roblox/scripts/check.sh` at `83761e7`: OVERALL PASS — 348 Lune specs, Selene 0 errors/0
  warnings, StyLua 120 files, Rojo build, place check. **Studio: not run** (gate G6, user).

## Decisions requested (please record in DECISIONS.md; I did not edit it)
1. **Game #1 = AI Kingdoms** (supersedes the FL-0035 shortlist recommendation). Needs a game brief.
2. **Config location:** AI Kingdoms config currently lives in `games/sandbox/config/` (my files only)
   because that is what Rojo maps. Proposal: create `games/game-001/` with the brief, then FORGE-05
   remaps `Config` to it and I move my files in one PR.
3. **Ownership split for kingdom data** (proposal in the FORGE-01 handoff): economics of buildings
   and units (cost, levels, requirements, limits, production, housing, storage) stay in `Items.luau`
   (FORGE-03); gameplay stats (footprint, model, hit points, combat) go to a FORGE-01 config keyed by
   the same item id. The game brief may confirm or reassign.
4. **Balance numbers** in `Items.luau` / `Currencies.luau` are proposals for the user's approval.

## Tasks to create (suggested)
| For | Task | Notes |
|---|---|---|
| FORGE-01 | KingdomService + KingdomController + Gameplay kingdom remotes | API in `2026-10-12-forge-03-to-forge-01-kingdom-api.md`; doubles exist |
| FORGE-01 | Placement mode (ghost preview, plots) | build menu hands off to it |
| FORGE-01 | Army: recruitment, unit control, combat | economy side (unit costs) is ready in `Construction:checkUnit` |
| FORGE-01 | Territory + standings + match results payload | UI slots exist (rank teaser, timer) |
| FORGE-03 | AI Kingdoms first playable UI (this work) — review/accept | PR stacked on FL-0018/FL-0020 |
| FORGE-03 | Army recruitment + military command screens | after FORGE-01's army API |
| FORGE-03 | Territory, standings, results/victory screens | after FORGE-01's payloads (FL-0043 covers round screens) |
| FORGE-02 | Medieval building kit (town hall, house, farm, lumber camp, quarry, gold mine, storehouse, barracks, watchtower) | the jungle kit tasks FL-0014..16 no longer match Game #1 |
| FORGE-04 | Onboarding: first build, first upgrade; NotificationController | UI falls back to its own ToastStack until then |
| user | Upload the 34 UI icons | `2026-10-12-forge-03-to-user-ui-icons.md` |

## Open issues and risks
- No FORGE-01 code exists yet for kingdoms; everything gameplay-side is a test double. The place
  boots without it (UIController keeps the HUD hidden until a kingdom exists).
- The skeleton (FL-0003) is not on `main`, so my PRs are drafts (D-016).
- FL-0014..FL-0016 (jungle foliage), FL-0011 (flood hazard) and the C2-oriented shortlist work may
  need re-scoping for AI Kingdoms.

## Next actions for the receiver
1. Record the decisions above; create `games/game-001/` and the brief.
2. Create/assign the tasks above (FORGE-00 owns `production/tasks/`).
3. Confirm with the user the provisional balance numbers and the 4 resources (any others?).

## Files to read
- `design/ui/REVIEW.md` — design review note with screenshot paths
- `agents/forge-03/STATUS.md` — branch, PRs, blockers
