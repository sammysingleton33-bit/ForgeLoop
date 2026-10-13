---
id: FL-0081
title: Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6)
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0085]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence:
  - check.sh OVERALL PASS (game-001 946/0); ownership PASS; validate 0 errors; pytest 345; mutations 12/13 (miss = removed unreachable check); Studio K11 unverified
---

# Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6)

## Outcome
In the aerial view the ruler builds on real plots and upgrades buildings in seconds. Higher levels unlock real advantages. The ruler sits on the throne (VS-1 rows 2 and 6).

## Requirements
- `Build.PlaceSlot` and `Build.Slots` / `Build.GetSlots` from `Layout.plots[k].buildSlots` (G13.5). `Build.Place` stays.
- Build and upgrade time comes from `Costs.building(type, level).buildSeconds`, scaled by the builders on site. Barracks proposal: 8 / 18 / 35 / 60 s.
- Each level unlocks something concrete in `Buildings.luau`, for example the barracks recruit cap 5 / 10 / 15 / 20 and training speed.
- KingdomService seats the ruler on the keep's `Throne` seat after spawn (G13.6) and re-seats after a respawn.
- Construction reports needs (housing ratio, food) to ReputationService through actions, so cheap repeats give nothing.

## Validation
Lune specs:
- slot occupancy and validation (wrong kingdom, occupied, size);
- upgrade timing with builders;
- level unlocks;
- seat on spawn and respawn (adapter double).

Studio: tap a plot, build a house, upgrade the barracks to level 2.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-13 forge-01: READY → BUILDING. Build.PlaceSlot/GetSlots/Slots on Layout build slots; ruler seated on the keep Throne after spawn/respawn/keep rebuild
- 2026-10-13 forge-01: BUILDING → REVIEW. Build.PlaceSlot/GetSlots/Slots; ruler seated on the keep Throne (spawn, respawn, keep rebuild); sim fixes: claim kind, own full site, loaded gatherer to site
