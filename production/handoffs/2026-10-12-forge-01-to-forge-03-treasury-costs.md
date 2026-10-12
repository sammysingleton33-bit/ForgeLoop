# Handoff: forge-01 → forge-03 · Treasury/Costs as I consume them (G6, G7, G9) · 2026-10-12

## What I need / what I'm giving you
I code against `TreasuryService` (G7) and `Costs` (G6) through local doubles until FL-0058 lands.
Please confirm or correct the points below.

## How FORGE-01 calls you
- Citizen deposits: `TreasuryService:deposit(kingdom, resource, amount, "dep:<entityId>:<tripSeq>", "citizen:<job>")`
  — one call per completed carry trip (amount 1..10 typically).
- Ruler gathering: `deposit(kingdom, resource, amount, "gather:<userId>:<seq>", "ruler")`.
- Building placement/upgrade: `spend(kingdom, Costs.building(type, level).cost, "build:<buildingId>:<level>", "building:<type>")`.
- Recruiting: `spend(kingdom, cost, "recruit:<barracksId>:<seq>", "unit:soldier")`.
- Cancelled construction refund: `deposit(..., "refund:<buildingId>:<level>", "refund")` per resource (50% today).
- Population for upkeep: `CitizenService:getPopulation(kingdom)` → `{ total, byJob, cap }` (G5).

## Requests
1. **Unit costs**: G8 says recruit "spends via treasury" but Costs has only `building`. Please add
   `Costs.unit(unitType) -> { cost: ResourceBag, trainSeconds: number }` (I use soldier = food 30, wood 10, 8 s until then).
2. **Storage capacity**: do storehouses raise a treasury cap? My simulation had one (keep 400 per
   resource, +300 per storehouse). Until you decide, I treat the treasury as uncapped.
3. **Starting treasury**: who seeds it at match start? I assume you do on `MatchPhaseChanged("Founding")`;
   my double seeds food 120, wood 100, stone 50, gold 0.

## Numbers I currently use (double only; yours win when Costs.luau lands)
House 40 wood · Farm 50 wood · Storehouse 60 wood · Barracks 120 wood + 60 stone · Watchtower 60 wood + 80 stone ·
Keep L2 150 wood + 150 stone (build 60 s). Build seconds = builder-seconds of work (2–3 builders work in parallel).

## Events you can use (G9, fired by FORGE-01, exactly once)
`ResourceGathered(player?, kingdom, resource, amount, "ruler" | "citizen")` once per deposit;
`BuildingPlaced/Completed/Upgraded/Destroyed(Building, player?)`; `UnitsRecruited(player, kingdom, count)`.
