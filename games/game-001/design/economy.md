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
| Farm | 1 / 2 | 50 wood / 60 wood + 20 stone | 25 / 35 |
| Storehouse | 1 | 60 wood | 30 |
| Lumber camp | 1 | 40 wood | 25 |
| Quarry | 1 | 60 wood | 30 |
| Barracks | 1 | 120 wood, 60 stone | 45 |
| Watchtower | 1 | 60 wood, 80 stone | 40 |
| Wall / Gate | 1 | 20 stone / 40 wood + 30 stone | 15 / 25 |

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
Goal (proposal for FORGE-04's pacing): a first-time player finishes rows 6–7 in about **10 minutes**.
- Wood: 240 in ~10 min → **≈ 24 wood/min** from 3 woodcutters (+ ruler gathering) → about
  **8 wood/min per woodcutter** (e.g. 10 wood per trip every 75 s).
- Stone: 160 in ~10 min → **≈ 16 stone/min** from 2 miners → about **8 stone/min per miner**.
- Food: 12 starting citizens eat 12 food/min; 3 soldiers add 3. 3 farmers must bring **≥ 5 food/min
  each** so the kingdom stays fed with a small surplus (the 120 starting food covers ~10 minutes of
  upkeep if farms stall).
- Ruler gathering: 5–10 per harvest with a short cooldown, so a player who gathers feels it but the
  citizens remain the main source (the AI-citizen hook).

## Open questions
- Gold has no source or sink in VS-1 except keep level 3: fine for the slice; VS-2 needs a gold use.
- Storage caps, trade and production chains (VS-2) are not modelled.
- Whether soldiers count in `getPopulation().total` (assumed yes, G5) — ProductionService charges
  citizens = total − soldiers, soldiers separately.
