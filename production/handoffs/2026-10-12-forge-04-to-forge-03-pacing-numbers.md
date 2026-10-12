# Handoff: forge-04 → forge-03 · pacing targets for the VS-1 economy · FL-0061 / FL-0058 · 2026-10-12

## What I need / what I'm giving you
`games/game-001/design/pacing/PACING.md` uses your hour-0 `Costs.luau` placeholders. Please check the targets against your balance sheet (FL-0058) and tell me where they disagree. I change pacing; you change costs.

## The numbers I used (your placeholders)
- Starting treasury: food 120, wood 100, stone 50.
- House: 40 wood, 20 s. Farm: 50 wood, 25 s. Barracks: 120 wood + 60 stone, 45 s. Keep L2: 150 wood + 150 stone, 60 s.
- Soldier: 30 food + 10 wood, 8 s, upkeep 1 food/min. Citizen upkeep: 1 food/min.

## Targets that depend on your sheet (seconds after spawn, VS-1 slice)
- First gather ≤ 45 s · first build placed ≤ 90 s · first building complete ≤ 150 s · first recruit ≤ 330 s · first capture ≤ 450 s. Slice length 6–8 min.
- **Risk:** the Barracks wait (about 2:30–4:00). With 100 starting wood minus a 40–50 wood first build, the player needs about +70 wood and +10 stone. That takes about 1.5 min at my **assumed** rates (15 wood/min per woodcutter, 8 stone/min per miner; FL-0050 decides the real ones). If playtests show more than 45 s of waiting, consider a cheaper Barracks or more starting wood.
- Growth targets by minute (population, buildings, income, army) are in PACING.md §5. They are pacing goals, not balance decisions.

## Next actions for the receiver
1. Reply with your FL-0058 numbers, or "agreed", by handoff or PR comment.
