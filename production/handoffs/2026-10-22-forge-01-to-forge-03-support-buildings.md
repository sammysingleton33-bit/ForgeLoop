# Handoff: FORGE-01 -> FORGE-03 — the four support buildings (FL-0149, D-060, D-061)

The type ids are fixed (as of `forge/01-support-buildings`, stacked on #315 and #323; they become real on main when this merges):

| type id | name | brings (key citizen: perk) | cost (level 1) | footprint (Kit) | hp |
|---|---|---|---|---|---|
| `blacksmith` | Blacksmith | the Blacksmith: Reforge | 80 wood + 60 stone, 30 s | 22x18 | 450 |
| `infirmary` | Infirmary | the Healer: Field Remedy | 90 wood + 40 stone, 30 s | 22x18 | 400 |
| `granary` | Granary | the Provisioner: Hearty Rations | 70 wood + 20 stone, 25 s | 18x18 | 450 |
| `shrine` | Shrine | the Elder: Rallying Hymn | 50 wood + 60 stone, 30 s | 16x16 | 350 |

- One of each per kingdom (`maxCount 1`), one level, no keep-level requirement, not a drop-off. They are ordinary `Build.PlaceBuilding` types (and `Build.PlaceSlot`), so the build menu can offer them like a house or a farm; `Fit.typesFor(size)` lists them for a slot.
- The gate is live: a role's perk is offered in the Crown Arena only while a FINISHED building of its type stands and its key citizen is alive; the perk itself needs the citizen's loyalty >= 80 (stronger at 95), which comes from the ruler's conversations and petitions (the citizen card already shows it).
- Menu / How-to-play text suggestions: "Blacksmith: brings the Blacksmith's support (Reforge) to your champion", "Infirmary: brings the Healer (Field Remedy)", "Granary: brings the Provisioner (Hearty Rations)", "Shrine: brings the Elder (Rallying Hymn)".
- NOT included (D-061): there is no Market, and the Barracks brings no Captain. The Captain and the Merchant do not appear in a real match's population, so Called Warning stays dormant; do not promise either in the menu.
- AI kingdoms build these too (RulerAI, after day 3 with a level-2 keep).

**Unverified:** how the new buildings look in the build menu in Studio; the Kit models are the existing G13.5 stand-ins.
