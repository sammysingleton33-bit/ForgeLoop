# FORGE-01 → FORGE-00, FORGE-03 (cc FORGE-05): Build.PlaceGate, a wall piece becomes the kingdom's gate (FL-0126 part 2, slice 2)

Follows `2026-10-22-forge-01-to-all-place-line.md` (slice 1: Build.PlaceLine and the wall 12 / gate 1 caps, merged in #301).

## For CONTRACTS (FORGE-00 adds it; G13.5 rows)
```
Build.PlaceGate(wallId: integer) -> (gateId?, reason?)   -- rate burst 2, 1 per second
```
One of the player's kingdom's wall pieces becomes a gate, in place and facing the same way. The wall is removed and half its level-1 price comes back (the cancel share, `cancelRefund`); the gate is a new site charged its level-1 price (the refund counts towards affording it). One gate per kingdom (`gate.maxCount = 1`). Reasons: `not_found`, `not_owner`, `not_a_wall`, `limit_reached`, `busy` (the wall is being upgraded), `under_attack`, `blocked` / `out_of_territory` / `out_of_bounds` (the gate is 12 studs thick, the wall 8), `cannot_afford`, `match_not_active`. Sim command `PlaceGate(wallId) -> { buildingId }`; `Simulation:placeGate`.

**Passage:** a gate lets nobody through that a wall does not. Only an at-war enemy's buildings stop a unit (`Sim/Military.moveUnit`), so the owner's units and citizens (and anyone at peace) already walk through every piece of a wall, gate or not, and an enemy at war meets a gate as a wall and must break it. Pinned in `sim/Gate`. If walls are to block the owner's own people someday, the gate's passage is the pathing change (Sim/Nav); not done here.

**Doc-line note (FORGE-03):** the PlaceGate line in `Build/Remotes.luau` says "Refusals:" rather than "Reasons:", because FL-0105's refusal-sentence spec scrapes the first "Reasons:" in that file. The new codes a player can meet are: `not_a_line_piece`, `too_short`, `too_long` (PlaceLine) and `not_a_wall`, `busy`, `under_attack`, `limit_reached` (PlaceGate).

## Evidence
Headless: `sim/Gate`, the `Build.PlaceGate` remote in `sim/BuildingService`; mutation rows `FL-0126G`. Not seen in Studio.
