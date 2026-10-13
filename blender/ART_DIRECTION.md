# AI Kingdoms — art direction (FORGE-02)

Game #1 is **AI Kingdoms**: four competing medieval kingdoms in one shared world. Target look:
a professionally art-directed, **storybook-stylized medieval** Roblox world. Warm, colourful,
inviting, readable from a third-person camera on a phone.

Status: v1, 2026-10-12, FORGE-02. Kingdom names below are *working names* for FORGE-00/user to confirm.

## 1. Pillars
1. **Silhouette first.** Every asset is identifiable as a black shape at 60 studs. Build the big
   mass, then secondary forms (roofs, towers, trim), then accents. Rough budget of visual weight: 70/20/10.
2. **Chunky and slightly exaggerated.** Thick roofs with deep overhangs, oversized doors and chimneys,
   chamfered edges everywhere. Nothing paper-thin: all geometry is solid (Roblox culls backfaces and
   wants watertight meshes), no alpha cards.
3. **Hand-made, not procedural noise.** Small irregularities (jitter 0.05–0.15 studs, blocks of
   varied length, slight sags) — never random chaos. Straight lines are allowed on architecture; organic
   shapes (trees, rocks, thatch) are soft and lumpy.
4. **Warm neutral world, saturated accents.** Plaster cream, warm stone, wood browns, straw and grass make
   up most of every view; kingdom colours and flowers are the accents.
5. **One palette texture for everything** (`lib/palette.py`, 512 px). Every swatch is a soft vertical
   gradient (darker at the bottom): use it — dark bases, light tops read as painted light and fake AO.

## 2. Human scale (5.5-stud Roblox character)
| Element | Studs |
|---|---|
| Character proxy | 5.5 tall |
| Door opening (walkable) | 4.4 × 7.6 (arched) |
| Window opening | 2.6 × 3.4, sill 3.4 above floor |
| Storey (floor to floor) | ~11; plinth 1.2–1.6 |
| Timber member | 0.62 wide, 0.2 proud of plaster |
| Fence / parapet height | 3.0–3.4 (chest height) |
| Castle curtain wall | 22–28 tall, wall-walk ≥ 6 wide, merlons 2.6 wide × 3 tall, gaps 1.8 |
| Gate passage | ≥ 12 wide × 15 tall |
| Road | 12–16 wide; bridge deck ≥ 12 wide |
| Trees | oak 24–38 tall, pine 28–48, bushes 3–7 |
| Crop rows | 3–4 tall wheat; fields in 24–40 stud plots |

Front of every asset faces **Blender −Y** (exports to Roblox −Z, the Model's LookVector). Pivot at base centre.

## 3. Kingdoms: same world, instantly different
Every kingdom shares the base materials (plaster, timber, thatch, wood) and the kit (`lib/kit.py`).
Identity comes from **four levers**, used on castles/military always and on village buildings partly:

| Lever | Red — *Emberhold* | Blue — *Frostmere* | Green — *Thornwood* | Yellow — *Sunspire* |
|---|---|---|---|---|
| Roof colour (`<k>_roof*`) | brick red | slate blue | jewel emerald | rich gold |
| Stone (`<k>_stone*`) | warm grey | cool blue-grey | mossy grey-green | sandstone |
| Trim metal (`<k>_trim*`) | gold | silver | bronze | deep bronze + ivory |
| Tower roof shape | tall **conical spires** with finials | **square pyramid** roofs, crisp | **timber hoardings** (wooden fighting galleries) + low cones | **domes / onion domes** with gold finials |
| Emblem (banners, shields) | crown | star | oak leaf | sun disc |

Rules (tuned after the first reviews, 2026-10-12):
- Straw thatch is deliberately **muted** (`thatch*`) so it never reads as the gold kingdom; every thatch
  building carries its kingdom on a large element that reads at 80 studs (ridge pennant, gable banner, door banner).
- The gold kingdom is **gold, not orange** (`yellow_roof*`, `yellow_cloth*`, saturation ≥ 0.85); straw, hay, wheat and
  thatch stay desaturated tan (saturation ≤ 0.55), so gold never reads as hay. gold-kingdom shutters are dark goldenrod. **No purple anywhere on the gold kingdom** (three fresh reviews read it as a fifth faction or a crescent); its trim is deep bronze `yellow_trim` + ivory `yellow_accent`.
- The green kingdom is a **jewel emerald** (hue ~160°, `green_roof*`, `green_cloth*`), clearly bluer than foliage and
  grass (hue 95–115°), so green roofs never melt into trees.
  On green terrain from the aerial camera, emerald identity rests on silhouette (timber hoardings) and cloth:
  emerald banners and flags use the bright `green_cloth_light` field with an ivory border and oak leaf, never the
  dark roof green (FORGE-00 calibration, 2026-10-12; check the emerald plot in the Studio aerial view).
- One emblem per kingdom everywhere (banners, shields, flags): crimson **crown**, azure **star**, emerald **oak leaf**,
  gold **sun**. (The flame is retired.)
- Every building sits on a stone plinth or kit plinth; no flat dirt decals under buildings.
- Kingdom colour covers at most ~35 % of a building's visible surface besides the roof: walls are neutral (plaster,
  natural wood, stone), never painted in the kingdom colour (this applies to barns, sheds and windmills too). Village
buildings: roofs ~50/50 thatch vs kingdom tiles, shutters and doors always in the kingdom colour, plus banners.
Castles and military buildings: always kingdom roofs, stone and banners.

## 4. Building language (shared kit)
- Stone plinth of irregular blocks under every building; quoins on stone corners; string courses under eaves.
- Timber framing on plaster: sole plate, top plate, posts, diagonal braces (alternating), mid rails on long walls.
- Windows: dark glass recess, timber frame, cross mullion, sill, open shutters (kingdom colour).
- Doors: arched plank door with iron straps, stone jambs + voussoir arch, threshold step.
- Roofs: `tile` (stepped shingle rows, ridge cap, barge boards) or `thatch` (puffy layered loft, rolled ridge).
  Pitch 40–55°, overhang 1.2–1.6, gable overhang ~1.
- Props that tell a story at the door: barrels, crates, flower boxes, log piles, tools.

## 5. Nature
- **Trees**: recursive tapered branches (depth ≥ 2), visible trunk flare/roots, canopy of ≥ 8 overlapping
  clumps with lighter tops and darker undersides, varied silhouettes. Never one sphere on a cylinder.
- **Rocks**: faceted, bevelled, noise-displaced masses in clusters (one big + smaller satellites), optional
  moss caps; quarry nodes show cut faces and chisel marks; ore nodes show coloured veins/crystals.
- **Ground cover**: bushes from clustered clumps, flower patches, grass tufts as small solid blades.

## 6. Readability at gameplay distance (60 studs)
Each type must be identifiable by silhouette: cottage (gable + chimney), market stall (striped canopy),
blacksmith (open front + forge chimney + anvil), barracks (long hall + banners + racks), granary (raised on
staddle stones), windmill (sails), towers (vertical + kingdom roof shape), keep (largest mass + flag).

## 7. Budgets and technical rules
LOD0 triangle budgets per class are in `budgets.json` (fail the build if exceeded; Roblox hard limit 20k per mesh).
One material, one UV map in 0–1, palette texture ≤ 512 px, closed shells, no n-gons, pivot at base centre.

## 8. Preview rig (how assets are judged)
Cycles CPU, AgX + Punchy, warm sun at 46°, cool sky fill, neutral ground, 5.5-stud proxy, backfaces
transparent (Roblox single-sided). Hero 3/4 view per variant + gameplay strip at 40–80 studs with the
Roblox default 70° vertical FOV.

## Placement rules from calibration
- Autumn oaks (`tree_oak_06`, `tree_oak_08`) read close to Sunspire's gold at distance (FORGE-00 calibration, #90): keep them out of the gold kingdom's plot and below about 25 % of any one forest.
