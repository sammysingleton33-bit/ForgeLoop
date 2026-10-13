# Handoff: FORGE-01 → FORGE-03, FORGE-04 · FL-0081 · 2026-10-13

## What I need / what I'm giving you
Build slots are live on the server (G13.5), and the ruler now sits on the keep throne after every spawn (G13.6).
- FORGE-03 can switch the plot picker and build menu to `Build.PlaceSlot`, `Build.GetSlots` and `Build.Slots`.
- FORGE-04's walk mode should unseat the ruler as described below.

## Done (with commits)
- FL-0081 (branch `forge/01-gameplay-fl0081`; PR into `main`, see agents/forge-01/STATUS.md):
  - **Slots:**
    - `Build.PlaceSlot(slotId, type)` → `(buildingId?, reason?)` builds on the player's own kingdom's slot.
    - The building takes the slot's centre and street-facing `rot`.
    - The type must fit (`Build/Fit`); then the same rules and price as `Build.Place` apply.
  - **Slot views:** `Build.GetSlots()` → `{ { id, size, occupiedBy? } }` for the asker's kingdom. `Build.Slots` sends the same list to the kingdom's members when they arrive and whenever a slot is taken or freed.
  - **Throne:** `KingdomService` seats the ruler on the keep's Kit `Throne` after spawn and after each respawn.
    - A co-ruler stands while the throne is taken.
    - A seated ruler is seated again within 0.5 s when a keep upgrade rebuilds the model.
  - **Simulation fixes found by the new upgrade-timing spec:**
    - A farmer building its own farm's upgrade now takes a builder slot.
    - A builder on a full site no longer walks away.
    - A slow gatherer (a builder chopping wood) now drops a partial load and goes to an open site.
    - Result: with 2 builders, a farm L2 upgrade took 23 s, against 39 s before.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (game-001 specs: 946 passed, 0 failed); ownership PASS; `forge.py validate` 0 errors; `pytest tools/tests` 345 passed.
- New specs:
  - `BuildingService.spec`: slots, refusals, `Build.Slots` push.
  - `MatchKingdomServices.spec`: seat on spawn and respawn, co-ruler, re-seat on rebuild, no re-seat after standing up.
  - `Simulation.spec`: builder scaling, claim kind, own full site, loaded gatherer.
- Mutations: 13 targeted, 12 caught. The one miss guarded unreachable code, which is now removed.
- **Unverified:** everything in Studio, including the engine behaviour of `Seat:Sit`, `Humanoid.SeatPart` and `Seat.Occupant`. Studio step K11 is in `roblox/studio-tests/gameplay.md`.

## Interfaces touched
- **Additive:**
  - `Build.PlaceSlot`, `Build.GetSlots`, `Build.Slots` (G13.5 exact shapes).
  - `MatchHost:buildingModel(buildingId)`.
  - `KingdomService` adapter fields `sit`, `seatOf`, `occupant`.

## Open issues and risks
- **Reasons:** PlaceSlot adds `unknown_slot` (not one of your kingdom's slots), `slot_occupied` and `does_not_fit`. Every `Build.Place` reason can also come back (`cannot_afford`, `out_of_territory`, ...).
- **Pacing:** upgrades now finish faster, because builders actually stay on site. Your PROVISIONAL `Costs` build times (e.g. barracks 8 / 18 / 35 / 60 s) now read as about "seconds ÷ builders on site". Up to 3 builders per site, 5 at the keep.
- **Co-rulers:** in VS-1 there is one throne per kingdom; the second ruler stands at the keep door.

## Next actions for the receiver
1. **FORGE-03:** replace the interim `UI/SlotFit` with `Build/Fit.typesFor`. Take slot occupancy from `Build.Slots` / `Build.GetSlots` and place with `Build.PlaceSlot`. Map the three new reasons to text.
2. **FORGE-04:**
   - Walk mode unseats with `Humanoid.Sit = false` (or a jump). The server then stops following that ruler, so the next keep rebuild does not seat them again.
   - Going back to the overview does not re-seat on its own. Either the player walks onto the throne (it can be touched), or ask me for a `Kingdom.Sit` remote if you want a button.

## Files to read
- `games/game-001/src/server/Services/BuildingService.luau` — slots section and API header.
- `games/game-001/src/server/Services/KingdomService.luau` — header "Throne (G13.6)" and `_seat` / `_checkThrones`.
- `roblox/studio-tests/gameplay.md` — K11.
