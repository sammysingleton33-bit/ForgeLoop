# AI Kingdoms — in-game art direction (Kit, world, characters)

Owner: FORGE-02 · v0 · 2026-10-12. This is the sheet for everything FORGE-02 builds in Luau at run time:
- the Kit (`src/shared/Kit/`);
- the world (`world/Layout.luau`, `world/Lighting.luau`, WorldService);
- rigs.

The Blender meshes follow the matching bible in `blender/ART_DIRECTION.md`. Both describe one world.

## 1. Target
A **storybook-stylized medieval valley**: warm sunlit greens, saturated kingdom colours, chunky readable silhouettes, timber-and-plaster houses, stone keeps with banners, golden wheat, deep green forests, a blue river (BRIEF §6).

It must read at RTS-ish camera distances and on phones. Nothing shown to players may look grey or like a placeholder.

## 2. Palette
| Role | Colour (RGB) | Where |
|---|---|---|
| Crimson kingdom | 196, 40, 28 | roofs, banners, shutters, tabards |
| Azure kingdom | 13, 105, 172 | 〃 |
| Emerald kingdom | 40, 127, 71 | 〃 |
| Gold kingdom | 245, 205, 48 | 〃 |
| Neutral (`Kit.NEUTRAL_COLOR`) | 208, 200, 184 | uncaptured watchtower, neutral banners |
| Plaster | 239, 227, 200 | house walls |
| Timber | 75, 48, 32 | framing, beams, eaves |
| Stone / light / dark | 150,145,136 / 184,178,168 / 111,106,99 | plinths, keeps, walls |
| Thatch | 207, 166, 81 | peasant roofs |
| Grass / leafy / ground / sand (terrain) | `world/Lighting.luau` `terrainColors` | terrain |

- The kingdom colours above are FORGE-02's recommendation; FORGE-01's `Kingdoms.luau` is the source.
- Kit derives every shade from the colour it is given and marks those parts with `KitTint`, so `Kit.setKingdomColor` recolours in place.
- Every Kit colour lives in `Kit/Parts.luau` `C`, with the same values as `blender/lib/palette.py`.

## 3. Materials (Roblox)
| Material | Use it for | Avoid |
|---|---|---|
| SmoothPlastic | plaster, painted trims, roofs | large stone masses (they read as toy plastic) |
| Wood | timber, posts, beams, tools | |
| WoodPlanks | floors, doors, crates, sheds | |
| Cobblestone | plinths, keeps, walls | small trims |
| Slate | dressed stone, steps, merlons, quarry faces | |
| Fabric | banners, canvas, cloth | |
| Grass | thatch, foliage, crops | |
| Metal | iron straps, finials, tools, armour | large areas |
| Glass | dark window panes | |
| Neon | crystals only | glow everywhere |

## 4. Shape language
- **Silhouette first.** Every building type is identifiable as a black shape at 60 studs:
  - keep: largest mass, corner turrets, flag;
  - house: gable roof and chimney;
  - storehouse: big doors and a hoist;
  - barracks: long hall, banners, racks;
  - watchtower: tall shaft and a crenellated top;
  - farm: golden rows and a farmhouse;
  - lumber camp: shed and log piles;
  - quarry: stepped cut stone and a crane.
- **Kingdom identity (Kit picks it from the colour's hue):**

  | Kingdom | Tower caps |
  |---|---|
  | crimson | tall stepped spires with gold finials |
  | azure | crisp pyramids |
  | emerald | timber hoardings under low pyramids |
  | gold | domes with gold finials |

  The same caps appear on keep turrets, barracks turrets, the gatehouse, soldiers' helmets in the Blender set, and the watchtower once it is captured.
- **Chunky and slightly exaggerated:** thick roofs with 1.2-stud overhangs, oversized doors (4.4 × 7.6, walkable), chamfered or stepped edges, banners hanging below the eaves.
- **Human scale:** 5.5-stud characters, storeys of about 10–11 studs, sills 3.4 above the floor, fences and parapets 3–3.4 high.
- **Front faces −Z** (the Model's LookVector). The pivot is at the base centre (PrimaryPart `Root` plus `PivotOffset`).

## 5. Do / don't
**Do:**
- three levels of detail on every building: mass, then roofs/towers/trim, then props such as barrels, crates, flowers and log piles;
- kingdom colour on roofs, shutters, banners and flags;
- warm neutral walls;
- shades of one colour for depth (darker eaves and ridge, lighter tops);
- props that tell what a building does (sacks at the storehouse, logs at the lumber camp, dummies at the barracks).

**Don't:**
- untextured grey boxes;
- single-colour roofs with no ridge or eave;
- identical repeated houses (use `variant`);
- kingdom colour on more than about 35 % of a building's visible surface besides the roof;
- thin parts under 0.25 studs (they shimmer on phones);
- Neon outside crystals;
- CSG or PartOperation, or anything that yields (D-026).

## 6. Budgets (BRIEF §14)
- **World:** at most 25k parts at VS-2. WorldService logs the part count it builds.
- **Per building:** budgets are documented in `Kit/Buildings.luau` and enforced by `tests/world/`.
- **Rigs:** at most 8 parts.
- **Props:** stand-ins of 3–25 parts. They are replaced by single imported MeshParts once the Blender batch is uploaded (FL-0057), which share the same asset ids.

## 7. How looks are judged
1. **Lune dump to bpy contact sheets:**
   - Kit: `tests/world/KitDump.spec.luau` → `blender/scripts/render_kit.py`.
   - World: `tests/world/WorldDump.spec.luau` → `blender/scripts/render_world.py`.
2. **Fresh-reviewer D-019 scoring.**
3. **Calibration (D-026):** FORGE-00 or the user judges the first keep and house sheet. The user then takes a Studio screenshot from the same camera, and that screenshot decides the final look. The preview cannot show Roblox's material textures or the Future lighting exactly.
