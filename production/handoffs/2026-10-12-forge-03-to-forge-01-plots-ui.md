# Handoff: forge-03 → forge-01 · FL-0087 plot picker and upgrade panel on G13.5 · 2026-10-12

## What I need / what I'm giving you
The plot picker and the building upgrade panel (FL-0087) consume CONTRACTS G13.5 as written. Below is
every assumption, plus three small additive proposals, so your `Build.PlaceSlot` / `Build.Slots` and
`Buildings.luau` match the UI on the first integration.

## Done (with commits)
- Branch `forge/03-ui-economy-fl0087` (PR: FL-0087, stacked on #25 → #24):
  `games/game-001/src/client/Controllers/{PlotPicker,UpgradePanel}Controller.luau`,
  `UI/{SlotFit,BuildingLevels,UpgradePanel}.luau`, `KingdomStore:applySlots`.
- Config `Costs.luau` (mine): the D-030 levels — farm, lumber camp, quarry 1–3, barracks 1–4 with the
  user's **8 / 18 / 35 / 60 s**, watchtower 1–2, wall and gate 1–3. Level 1 and keep L2 (the VS-1 path)
  are unchanged except barracks L1 45 → 8 s. Balance sheet: `design/economy.md`.
- Your plot server is doubled in `games/game-001/tests/economy/doubles/SlotDoubles.luau` (my path).

## Evidence
- 9 specs (4 model, 5 end to end through the real RemoteService and TreasuryService); 7 mutations each
  fail a spec. **Unverified:** your real services and Studio.

## Interfaces touched
None (G13.5 consumed as written). Proposals 3–5 are additive.

## What the client assumes (confirm or correct)
1. `Build.GetSlots` → my kingdom's plots `{ { id, size = "S"|"M"|"L", occupiedBy = buildingId? } }`;
   `Build.Slots` pushes the same full list to the kingdom's members whenever one changes (fire per
   member, not fireAll: the list is per kingdom).
2. `Build.PlaceSlot(slotId, type)` → `buildingId` (number) or `(nil, reason)`. Reasons shown as
   sentences: `territory` (not your plot), `overlap` (already built on), `zone` (does not fit),
   `cost`, `phase`, `no_kingdom`; anything else gets a generic line.
3. After a successful `PlaceSlot` you push the new building (`Build.Buildings`) and the slot with
   `occupiedBy` (`Build.Slots`). Tapping a built-on plot opens the upgrade panel for `occupiedBy`.
4. Upgrades go through `Build.Upgrade(buildingId)` as before (same confirmation and toasts as the
   Kingdom panel).

## Proposals (additive)
3. **Which types fit which plot.** Until you decide, the client uses `UI/SlotFit`: a type's class is
   the largest side of its biggest `Kit.footprint` over its levels — ≤ 18 studs S, ≤ 26 M, else L —
   and a plot takes its size and every smaller one (S watchtower; M house, storehouse, lumber camp,
   quarry; L farm, barracks). Walls and gates stay free-placed. If you prefer to decide per plot, add
   `fits: { BuildingType }` to each slot record; the client then uses it as is.
4. **Benefits per level.** The panel shows "Now: …" and "Lv N: …" from a display copy of the D-030
   table (`UI/BuildingLevels.luau`). Please give `Buildings.luau` per-level stats or a short
   `benefits` text per level; I will read it instead.
5. **Build time with builders.** The panel shows `Costs.building(type, level).buildSeconds` as
   "0:18 with builders". If your scaling shows a different number in game, tell me the formula and I
   show the expected time for the current builders.

## Next actions for the receiver
1. Confirm 1–4; decide 3–5.

## Files to read
- `games/game-001/tests/economy/doubles/SlotDoubles.luau` — the server behaviour I assume.
- `games/game-001/src/client/UI/SlotFit.luau`, `UI/BuildingLevels.luau`.
