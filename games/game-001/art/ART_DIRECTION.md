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
| Crimson kingdom | 190, 40, 50 | roofs, banners, shutters, tabards |
| Azure kingdom | 40, 110, 210 | 〃 |
| Emerald kingdom | 35, 128, 95 (jewel emerald, bluer than foliage) | 〃 |
| Gold kingdom | 235, 185, 16 (saturated gold, never hay-tan or orange) | 〃 |
| Neutral (`Kit.NEUTRAL_COLOR`) | 208, 200, 184 | uncaptured watchtower, neutral banners |
| Plaster | 239, 227, 200 | house walls |
| Timber | 75, 48, 32 | framing, beams, eaves |
| Stone / light / dark | 150,145,136 / 184,178,168 / 111,106,99 | plinths, keeps, walls |
| Thatch | 191, 163, 108 (muted, so it never reads as the gold kingdom) | peasant roofs |
| Grass / leafy / ground / sand (terrain) | `world/Lighting.luau` `terrainColors` | terrain |

- The kingdom colours above are canonical in `config/Kingdoms.luau` (D-033); Kit stand-ins and WorldService read them from there, never hard-coded.
- **Never colour alone (D-033).** Each kingdom is told apart by tower silhouette (crimson spires, azure pyramids, emerald hoardings, gold domes), its emblem (crown, star, oak leaf, sun) and its name. Crimson and emerald get close under protanopia, so banners, flags and shields always carry the emblem.
- **Emblems (D-039; colour-vision finding 3).** One builder, `Pieces.emblem`, puts the emblem on every banner, flag, pennant, shield, prop banner and slot sign; the kind follows the colour with the same hue map as the tower caps (`Kit.emblemKind`), so emblem and silhouette always agree, and a neutral colour carries none.
  - Shapes, a few primitive parts each: **crown** (3: two tall wedges and a diamond, three points), **star** (5 wedges, the exact five-pointed star), **oak leaf** (5: three round lobes, a diamond base, a darker midrib and stem; the leaf lies in bend, tilted 35°, because upright and foreshortened it read as a lollipop tree), **sun** (4: a disc, a ring and two squares for 8 pointed rays; 9 with separate wedge rays on the aerial plaques).
  - Colour: ivory (240, 232, 212) on the kingdom field, except the sun, which is deep gold (`shade(colour, 0.42)`) because ivory on the light gold field has no contrast — the same choice as the Blender bible's deep-gold sun. Every emblem differs from its field by ΔL* ≥ 25 (`KitEmblems.spec`).
  - As large as the field allows: 80 % of a banner's width, 64 % of a shield.
  - **Aerial plaques on the keep.** The overview camera (40–220 studs, 38–65° down) sees roofs and caps, not hanging banners, so the keep carries two large plaques (kingdom field, ivory border, emblem): one on the hall roof in front of the donjon, facing up and raised 2.4 so the merlons never hide it, and one on the donjon's windowless back face for views from behind.
- Rules shared with the Blender bible (§3 there): walls are never painted in the kingdom colour; straw, hay and wheat stay desaturated tan; kingdom green stays clearly bluer than grass and leaves. Emerald banners and flags use a lighter, high-saturation tint of the kingdom colour with an ivory border, because from the aerial camera the emerald plot sits on green terrain.
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
  Part-built Kit soldiers given their kingdom (CONTRACTS G13.2, D-033(3)) wear a one-part helmet crest in the same style, so they read apart without colour: crimson a tall spire, azure a flat square plate overhanging the helm, emerald a plume swept back, gold a dome knob.
- **Job silhouettes (citizens, after the first Studio playtest).** Jobs read without colour, at gameplay distance and from the overview camera, where a citizen is a 6–10 px blob and only the hat and the tool still carry a shape. Each working job gets one hat in a different primitive, one tool in a different primitive and value, a trouser and panel accent, and a body width:

  | Job | Hat (KitHeadwear) | Tool | Accent (trousers / panel) | Torso width |
  |---|---|---|---|---|
  | farmer | wide flat straw disc, 3.1, with a kingdom-red crown (`strawhat`) | 5.2 handle with a steel blade at its top (hoe) | olive / cream | 1.95 lean |
  | woodcutter | small charcoal knit beanie, a 1.5 ball sitting high, with a kingdom-red pompom (`knitcap`) | 3.9 haft with a bearded steel head (axe) | black-brown / umber | 2.3 stocky |
  | miner | small dark-ochre iron pot, 1.9, with a lamp (`hardhat`) | 3.7 handle with a 3.6 double-sided iron bar (pick) | coal / soot grey | 2.2 |
  | builder | cream hard hat: a squat drum that sits on the head with a visor (`buildercap`) | 3.0 handle with a fat wooden mallet head (hammer) | dusty navy / tan canvas | 2.3 |
  | hauler | none: the look's hair | sackcloth sack 2.7, low on the back, with a tied neck and a kingdom-red strap across the chest | russet / sackcloth | 2.3 |
  | idle | the look's hair, plus a headband or scarf on about two looks in three (`Accessory`, the free 9th part) | nothing | the outfit's own | 1.9 lean |

  The governor wears a wide gold crown disc (1.9) and carries a 6.4 × 0.5 gold staff, in a 2.4 body; the soldier's spire crest is low (1.55 above the helm, no taller than the helm).

  Rules: the woodcutter's charcoal beanie is the only ball hat and never a hair colour (balls are hair), the four hats' value ranges never overlap in grayscale, the kingdom tint stays on the torso or the sleeves, and idle or hauler citizens never wear a job hat (hair style 6 is `curls`, not a straw hat). The hat takes the Hair slot, so a working citizen's `look.hair` picks a variant of the hat (roll tilt and shade) and the hair colour is hidden under it; it dyes the clothes instead (shirt tone, trousers and panel; an odd hair colour keeps the job panel on neutral sleeves, an even one makes them kingdom-red, for red shoulders from above). A hat sits ON the head (the head enters its lower face by 0.15-0.4, nothing of the head shows through it) with the face clear (below +0.33 from the head centre); the sack sits behind the back, clear of the head and both arms in every pose; nothing rises past the soldier's spear (Kit spec `clearance`). **Detail parts (D-048, phase 2):** each hand tool is a cylinder handle with its head as a detail part, and every job carries two rigid detail parts welded to the Head or the Tool (`KitDetail = true`, droppable beyond the rig's LOD distance, never a joint): crown, pompom, lamp, visor, hoe blade, axe head, pick bar, mallet, strap, tie, spearhead, pennant, velvet cap, orb. The soldier wears a kingdom pennant on the spear and the governor a kingdom velvet cap, so kingdom red shows from above on every working rig.
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
- **Rigs:** at most `Character.MAX_PARTS` parts: 11 = the 9 of D-032 (Root, Torso, Head, 2 arms, 2 legs, Tool, welded headwear) plus at most 2 rigid detail parts (D-048).
- **Props:** stand-ins of 3–25 parts. They are replaced by single imported MeshParts once the Blender batch is uploaded (FL-0057), which share the same asset ids.

## 7. How looks are judged
1. **Lune dump to bpy contact sheets:**
   - Kit: `tests/world/KitDump.spec.luau` → `blender/scripts/render_kit.py`.
   - World: `tests/world/WorldDump.spec.luau` → `blender/scripts/render_world.py`.
2. **Fresh-reviewer D-019 scoring.**
3. **Calibration (D-026):** FORGE-00 or the user judges the first keep and house sheet. The user then takes a Studio screenshot from the same camera, and that screenshot decides the final look. The preview cannot show Roblox's material textures or the Future lighting exactly.
