# AI Kingdoms — VS-1 economy balance sheet (FORGE-03, FL-0058)

Status: **first pass, provisional.** The numbers live in `games/game-001/config/Costs.luau`; this
sheet explains them and states what the other workers' rates must deliver. Pacing (how long the
slice should take) is FORGE-04's (FL-0061); gather and trip rates are FORGE-01's (`Jobs.luau`,
`Citizens.luau`). Change the numbers here and in `Costs.luau` together. Nothing here is a user
decision yet; the final balance needs the user's playtest (FL-0064).

## Resources and rules (CONTRACTS G7)
- Food, Wood, Stone, Gold in one shared kingdom treasury; no storage cap in VS-1.
- Sources: citizen deposits (one per carry trip) and ruler gathering. Sinks: buildings, upgrades,
  soldiers, upkeep. ProductionService is the only food consumer.
- Upkeep every 60 s: 1 food per citizen, 1 food per soldier (`Costs.upkeep`, `Costs.unit("soldier").upkeepFood`).
  The fed ratio (food taken / food owed) drives hunger (FORGE-01).
- Births are not a food sink (D-045, G7 v0.4-g9d). While ProductionService runs, a birth takes no
  treasury food. A kingdom grows when it is well fed (fed ratio ≥ `Society.food.wellFedAtLeast`,
  0.9) and has a free bed. Without ProductionService (specs and the meal-double path),
  `Citizens.birthFood` (25) is still charged. PROVISIONAL until the user plays.

## Starting stockpile (per kingdom, at Founding)
| Food | Wood | Stone | Gold |
|---:|---:|---:|---:|
| 120 | 100 | 50 | 0 |

## Costs (placeholders shared with FORGE-01's simulation)
| Building | Level | Cost | Build (builder-seconds) |
|---|---:|---|---:|
| Keep | 1 | starting building | — |
| Keep | 2 | 150 wood, 150 stone | 60 |
| Keep | 3 | 250 wood, 300 stone, 60 gold | 120 |
| House | 1 / 2 | 40 wood / 40 wood + 30 stone | 20 / 30 |
| Farm | 1 / 2 / 3 | 50 wood / 60 wood + 20 stone / 80 wood + 40 stone | 25 / 35 / 45 |
| Storehouse | 1 | 60 wood | 30 |
| Lumber camp | 1 / 2 / 3 | 40 wood / 50 wood + 20 stone / 70 wood + 40 stone | 25 / 30 / 40 |
| Quarry | 1 / 2 / 3 | 60 wood / 70 wood + 10 stone / 90 wood + 30 stone | 30 / 35 / 45 |
| Barracks | 1 / 2 / 3 / 4 | 120 wood + 60 stone / 100 wood + 80 stone / 150 wood + 120 stone + 20 gold / 200 wood + 180 stone + 50 gold | **8 / 18 / 35 / 60** (user proposal, D-030) |
| Watchtower | 1 / 2 | 60 wood + 80 stone / 60 wood + 100 stone | 40 / 40 |
| Wall | 1 / 2 / 3 | 20 stone / 40 stone / 60 stone + 10 gold | 15 / 20 / 25 |
| Gate | 1 / 2 / 3 | 40 wood + 30 stone / 40 wood + 60 stone / 60 wood + 90 stone + 10 gold | 25 / 30 / 35 |

Levels follow the D-030 catalogue (`design/living-kingdom.md` §4); everything above level 1 is
PROVISIONAL until the user plays it. The VS-1 path (level 1 and keep level 2) is unchanged except
the barracks time (45 → 8 builder-seconds).

| Unit | Cost | Train | Upkeep |
|---|---|---:|---:|
| Soldier | 30 food, 10 wood | 8 s | 1 food/min |

## What the VS-1 path costs
The slice (BRIEF §4 rows 6–7) asks the player to place at least one building, upgrade the keep to
level 2, build a barracks and recruit 3 soldiers.

| Step | Food | Wood | Stone |
|---|---:|---:|---:|
| One house (row 6) | | 40 | |
| Barracks | | 120 | 60 |
| 3 soldiers | 90 | 30 | |
| Keep level 2 | | 150 | 150 |
| **Total** | **90** | **340** | **210** |
| Starting stockpile | 120 | 100 | 50 |
| **Must be earned** | **0** (plus upkeep) | **240** | **160** |

## Rates the slice needs (targets for FORGE-01 and FORGE-04)
Goal: a first-time player finishes the whole slice, from spawn to the capture, in **6–8 minutes**
(D-044 (1), `design/pacing/PACING.md` §3). The capture walk takes about 2 minutes, so rows 6–7 must
fit in roughly the first **5.5 minutes**. Keep level 2 is optional in the slice (D-044 (1)). The
wood and stone targets below are for a player who also upgrades the keep before sending soldiers,
which is how BRIEF §4 row 6 is checked in Studio.
- Wood: 240 in ~5.5 min → **≈ 44 wood/min** from 3 woodcutters (+ ruler gathering) → about
  **13–15 wood/min per woodcutter**. PACING §3 assumes ≈ 15.
- Stone: 160 in ~5.5 min → **≈ 29 stone/min** from 2 miners → about **14 stone/min per miner**.
  PACING §3 assumes ≈ 8, which leaves keep level 2 about 70 stone short at 5:30. The slice can still
  end, because keep level 2 is optional, but the row 6 keep check then comes later.
- Without keep level 2 the slice needs only 90 more wood and 10 more stone (house, barracks,
  3 soldiers). PACING's assumed rates earn that in about 2 minutes of gathering.
- Measured: FORGE-05's headless pacing probe (`production/quality-gates/pacing-probe.md`) found
  that an idle kingdom earns about 76–86 wood, 52 stone and 86 food per minute over its first
  5 minutes, which is above every target here. The 70-stone shortfall holds only at PACING's assumed
  rates. This is headless evidence, not a play test; tuning waits for the user's play (D-043).
- Food: 12 starting citizens eat 12 food/min; 3 soldiers add 3. 3 farmers must bring **≥ 5 food/min
  each** so the kingdom stays fed with a small surplus (the 120 starting food covers ~10 minutes of
  upkeep if farms stall, but only ~2 minutes once 3 soldiers are bought). Staying at a fed ratio of
  0.9 or more is also what lets the kingdom grow (D-045), so a food shortfall now costs growth as
  well as hunger.
- Ruler gathering: 5–10 per harvest with a short cooldown, so a player who gathers feels it but the
  citizens remain the main source (the AI-citizen hook).

## Open questions
- Gold has no source or sink in VS-1 except keep level 3: fine for the slice; VS-2 needs a gold use.
- Storage caps, trade and production chains (VS-2) are not modelled.
- Whether soldiers count in `getPopulation().total` (assumed yes, G5) — ProductionService charges
  citizens = total − soldiers, soldiers separately.
