# Kit architecture review log (FL-0054 v0 + G13 / FL-0085) — FORGE-02

D-019 preview loop for `src/shared/Kit/{Buildings,Pieces}.luau`. Renders: `blender/scripts/render_kit.py`
over the Lune dumps (`KitDump.spec` → `building_*`, `stages`; `KitBuildingsDump.spec` → `house_variants`,
`stages_more`, `levels_*`, `standins`). The preview has no Roblox material textures (Studio decides the final
look, D-026). Scores 1–5: silhouette / variation / readability at gameplay distance / proportions / palette /
detail density / cohesion / part cost.

Starting point (before round 1): `kit_building_house.jpg`, `kit_building_keep.jpg`, `kit_building_watchtower.jpg`
at commit c772f96 — flat single-colour wedge roofs, one identical house, thin turrets, plain walls, door arch
rendering black. Scores ≈ 2 / 1 / 3 / 3 / 3 / 1 / 3 / 5.

## Round 1 — new piece language (quick renders, 21:09–21:22)
Images: `blender/previews/kit_building_{house,keep,watchtower,storehouse,barracks,farm,lumbercamp,quarry,wall,gate}.jpg`,
`kit_stages.jpg`, `kit_house_variants.jpg`, `kit_stages_more.jpg`; tiles in `blender/renders/kit/`.

Built: tile roofs from lapped courses (alternating shade, ridge cap, barge boards), thatch (thick slabs,
lighter upper layer, rolled eaves/ridge/verges), irregular stone plinths, timber framing with braces/posts/rails
placed around openings, windows (frame, glass, cross mullion, sill/flower box, kingdom shutters), arched doors
with stone voussoirs and keystone, gable and ridge chimneys, quoins, kingdom tower caps (stepped spire, slate
pyramid, timber hoarding, dome), banners with per-kingdom emblems, crests, scaffolding, material piles; four
house archetypes + mirrors; per-kingdom castle stone (warm grey / blue-grey / mossy / sandstone).

| model | sil | var | read | prop | pal | detail | coh | cost | notes |
|---|---|---|---|---|---|---|---|---|---|
| house | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | storybook townhouse reads; gable chimney hidden on the far side in the hero view |
| keep | 4 | 4 | 4 | 3 | 4 | 3 | 4 | 3 | kingdom caps distinct; facade cramped between fat turrets; walls plain in preview |
| watchtower | 3 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | caps too small and sunk behind merlons; emerald hoarding hidden |
| storehouse | 3 | 3 | 4 | 3 | 4 | 3 | 4 | 5 | staddles barely visible; plain sides |
| barracks | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 3 | gatehouse + turret read "military"; turret at the back hardly seen |
| farm | 3 | 3 | 3 | 4 | 2 | 3 | 4 | 4 | wheat rows read as planks; whole farm beige/yellow, no contrast |
| lumbercamp / quarry | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 5 | low detail, pale uniform quarry stone |
| wall / gate | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 | pointed gate arch reads; black seam on wall ends |
| stages | 4 | 3 | 4 | 4 | 3 | 3 | 4 | 5 | read as building sites; stage 1 sparse |

Problems found and fixed for round 2:
- Black bands on every arched door/window: coplanar disc + leaf faces (Cycles artifact, and a z-fight in Studio).
  Discs now sit 0.05 behind the leaf/frame plane; banner/crest tips, emblem layers, frame members and the wall's
  string course/batter ends were de-coplanarised the same way.
- Keep: broad facade (hall 25 × 20 instead of 24 × 24), projecting entrance bay, bay merlons, crest; spires get 8
  tiers on big caps; turret flare reduced to stay in the footprint.
- Watchtower: cap raised to the merlon tops and widened to w+0.4 (eave over the parapet); emerald hoarding replaces
  the parapet.
- Storehouse: granary lifted to 3 studs on staddles, cleated ramp, side lean-to store with goods.
- Farm: wheat = darker stalk rows + lighter, wider ears; darker soil; green vegetable patch; kingdom flag; kingdom
  coat on the scarecrow.
- House v1 chimney moved to the visible side; v4 lean-to moved to the visible side.
- Part trims: crown emblem 4 → 2 parts, bare arched castle windows, front-only jetty brackets.

## Round 2 — G13 scope (FL-0085): throne, visible levels, VS-2 stand-ins (quick renders, 21:34–21:37)
Images: `blender/previews/kit_levels_keep.jpg`, `kit_levels_barracks.jpg`, `kit_levels_house_farm.jpg`,
`kit_standins.jpg` (dump `KitBuildingsDump.spec`; the Seat is previewed as a block because render_kit only knows
primitive classes).

Built: keep redesign — broad hall pushed back, entrance bay, and an open front terrace with a three-step dais and
the `Throne` Seat (kingdom-colour back, gold arms/trim/finials, emblem, carpet) facing −Z, framed by two kingdom
standards; nothing roofs over it (spec-checked). Keep L1 5 caps → L2 + bartizans on the bay + turret banners (7
caps) → L3 + side towers (9 caps), height 57 → 67 → 77. Barracks L1 timber hall → L2 stone + jettied timber,
banners, two racks → L3 + corner tower + sand yard, dummies, target → L4 + crenellated gatehouse, crest, big flag,
second tower. House L2: v1 dormer + woodshed + taller storeys, v2/v3/v4 a second storey. Farm L2: barn with a
kingdom-tile roof. Thatch muted to 191,163,108 and every thatch house flies a ridge pennant. Six labelled stand-ins.

| sheet | sil | var | read | prop | pal | detail | coh | cost | notes |
|---|---|---|---|---|---|---|---|---|---|
| keep L1–3 | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 3 | throne + standards read in front of the door; each level adds caps/height |
| barracks L1–4 | 4 | 4 | 5 | 4 | 4 | 4 | 4 | 3 | four clearly different silhouettes at 73 studs |
| house / farm L1–2 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | v1 L1→L2 only a dormer (too subtle); wheat still a flat tan slab |
| stand-ins | 3 | 4 | 4 | 3 | 4 | 3 | 4 | 5 | blacksmith/market/shrine good; mine hill = two grey boxes; granary thatch reads as a cake |

Changes for round 3: v1 L2 gets a side woodshed (roof count 1 → 3); wheat stalks olive, ears brighter; mine rocks
tilted, varied, moss cap; quarry face darker and varied (Rock material), rubble and a ladder; lumber camp firewood
stack and a log cart; wall string course/batter ends de-coplanarised.

## Round 3 — refinements + final renders (non-quick, 420 px / 28 samples, 22:00 →)
Images (final): `blender/previews/kit_building_{house,keep,watchtower,storehouse,barracks,farm,lumbercamp,quarry,wall,gate}.jpg`,
`kit_levels_{keep,barracks,house_farm}.jpg`, `kit_house_variants.jpg`, `kit_standins.jpg`, `kit_stages.jpg`,
`kit_stages_more.jpg`; tiles in `blender/renders/kit/`.

Changes: wheat ears are now a gabled golden ridge on an olive stalk row (light/shade per row — reads as a crop
field, no longer as planks); house v1 L2 woodshed; barracks L1–L2 get a tall kingdom standard (moved to the +X
corner after the first final render showed its flag flying into the roof); mine rocks tilted/varied with a moss
cap; quarry face in three darker stone tones (Rock) with rubble and a ladder; lumber camp firewood stack + log cart.

| sheet | sil | var | read | prop | pal | detail | coh | cost |
|---|---|---|---|---|---|---|---|---|
| house (calibration) | 4 | 4 | 5 | 4 | 4 | 4 | 5 | 4 |
| keep (calibration) | 5 | 5 | 4 | 4 | 4 | 4 | 4 | 3 |
| watchtower (neutral + kingdoms) | 4 | 4 | 5 | 4 | 4 | 4 | 4 | 4 |
| storehouse | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 5 |
| barracks L1–4 | 4 | 4 | 5 | 4 | 4 | 4 | 4 | 3 |
| farm L1–2 | 3 | 3 | 4 | 4 | 4 | 3 | 4 | 4 |
| house variants | 4 | 5 | 4 | 4 | 4 | 4 | 4 | 4 |
| lumber camp / quarry / mine | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 5 |
| wall / gate | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 |
| stages | 4 | 3 | 4 | 4 | 3 | 3 | 4 | 5 |
| stand-ins (G13.5) | 3 | 4 | 4 | 3 | 4 | 3 | 4 | 5 |

Remaining weaknesses (next pass): castle/hall walls are plain in the preview (Studio's Cobblestone texture carries
them — confirm in the calibration screenshot); crimson stepped spires read as stacked discs at close range;
ClayRoofTiles texture orientation on rotated courses is unverified (Studio check); lumber camp, quarry and mine are
the weakest silhouettes; stage 1 is sparse; the throne is small at 220 studs (the standards and carpet carry it).

## Round 4 — G13 contract rules: pinned footprints, strict containment, emerald calibration (22:30 →)
Images: `kit_levels_keep.jpg`, `kit_levels_barracks.jpg`, `kit_levels_house_farm.jpg` (non-quick, FORGE-01 G13
colours emerald 35,128,95 and gold 235,185,16 in `KitBuildingsDump`), then the `building_*` sheets.

Rule (FORGE-00/FORGE-02 lead): footprints never change and never grow per level; the slot picker, the server and
`Build/Fit.luau` read `Kit.footprint(type, maxLevel)`. Measured before the fix, parts poked out of the footprint by
up to 2.3 studs (keep turret flares and caps, barracks L3/L4 back towers, v1/v4 woodsheds, thatch eaves, farmhouse
verges, gate/wall plinths and buttresses, mine rocks, building-site piles). Fixes: keep hall sized from the
footprint (turret + widest cap reach = r + 1.3; back edge to last stair = fp + 1, the Door attachment 0.5 in
front of the stairs), terrace 5 deep, dais 4.4/3.6/3.0; barracks towers clamped 4.25 inside the corner; thatch
houses 0.6 shallower with 1.3 overhang, tile overhang 1.2, woodsheds 1.8 (v1 L2) / 2.7 (v4); farmhouse sized so
the thatch verge stays in; gate towers 0.6 narrower and 2.4 shallower; wall 2.8 thinner with 1.35-deep buttresses;
mine rocks pulled in; site ground, stakes, crane and material piles inside. The spec now pins every FOOTPRINTS
entry (all 16 types, levels 0–5 clamped) and fails if any part leaves the footprint (sides/back strictly; front ≤ 2
studs for entrance steps).

Emerald calibration (FORGE-00: emerald plots sit on green terrain): emerald banners, building flags and ridge
pennants use a lighter, high-saturation tint (KitTint 1.35, still recoloured by setKingdomColor) with an ivory
border and ivory trim band. Region-marker flags (Props → Pieces.flagpole without a style) keep the exact kingdom
colour that Kit.spec pins.

Critique of the level sheets: keep L1→L3 still reads as one family growing (5 → 7 → 9 caps, 57 → 67 → 77 studs),
the throne + standards stay legible in front of the door; the halls are narrower than round 3 (footprint-bound)
but the facade still holds bay, banners and windows. Barracks L1 now carries a tall standard (visible), L3/L4
towers sit on the hall's back corners. House/farm unchanged in read; the gold roof at 235,185,16 is a saffron
mustard and no longer competes with the muted thatch; the emerald pennant reads mint with a cream edge.

Final sheets after round 4 (non-quick): `kit_building_{house,keep,watchtower,barracks,farm,storehouse}.jpg`,
`kit_levels_{keep,barracks,house_farm}.jpg`, `kit_standins.jpg`. Not re-rendered after round 4 (stopped at the
coordinator's wrap-up; geometry changed only to stay inside the footprint): `kit_house_variants.jpg`,
`kit_stages*.jpg`, `kit_building_{lumbercamp,quarry,wall,gate}.jpg`.

## FL-0085 integration follow-ups (FORGE-05 review: L1, L2, L5, L6) — 2026-10-13
- L2 throne vs door: the throne now stands 0.4 in front of the bay face; its back, trim, finials and emblem
  sit 0.85+ in front of it (clear of the door leaf, straps and voussoirs), and the dais is 5.8 wide (inside the
  jambs). Spec: no KitThrone part intersects EntranceBay/Door/DoorArch/DoorStrap/DoorJamb/Voussoir/Keystone at
  any keep level or kingdom colour.
- L1 throne visibility: a 5-part baldachin (two tall posts, a gabled kingdom-cloth canopy with KitTint, a gold
  finial) stands over the throne with its canopy above the bay merlons and the hall's front parapet; the canopy
  is ≥ 8 studs above the seat (the seat stays open to oblique views; spec-checked). Renders (scratch copies of
  render_kit, hero at 22° and a rear-oblique 50° aerial): from the front it reads as a royal canopy on lances;
  from behind at 22° the hall and donjon hide it; at 50° rear-oblique it shows as a kingdom-colour patch at the
  parapet line, partly behind the donjon. Keep counts: L1 198–218, L2 230–258, L3 261–292 (≤ 300).
- L5: Kit.spec documents and asserts the keep-L3 exception (≤ 300 = Buildings.PART_BUDGET.keep).
- L6 z-fighting: new probe in KitBuildings.spec (axis-aligned blocks, same-facing coplanar faces within 0.005 and
  > 0.05 stud² shared; ground-contact bottoms skipped). Before: 4,027 face pairs (130 distinct type/part-pair/face
  combinations) over every type, level, house archetype and kingdom colour; after: 0. Fixes: timber walls, corner
  posts and plates inset 0.02–0.03; sole plate narrowed; stone walls and tower shafts lifted 0.03 off the floor
  (door leaves/jambs); plinth side stones stop short of the corners and never sit flush with the core; stoops
  0.03 under the floor; transoms, rack bars, porch beams and well beams thinner than their posts; arched window
  glass shorter than its frame; banner borders below the cloth top; farm fences share corner posts; barn walls
  and posts inset; gate passage merlons inside the passage; quarry tiers offset; market counters lifted 0.03;
  keep terrace raised 0.03 with its walls inset.


## Round 5 — kingdom emblems from the overview camera (FORGE-05 colour-vision finding 3) — 2026-10-13
Branch `forge/02-blender-aerial-emblems`. Evidence: headless specs (`KitEmblems.spec`, budgets, coplanar probe)
and Blender (`bpy`) renders of a scratch Lune dump. These are not Studio screenshots (D-034).

**Inventory (before):**
- Every kingdom-identity element the Kit or world builds:
  - keep: crest, two terrace standards, two hall banners, two turret banners (L2+), the throne back, the donjon flag;
  - barracks: jetty banners (L2–L4), the gatehouse's banners, crest and flag (L4), the yard flag (L1–L2);
  - watchtower, wall, gate: banners, caps' flags, crest;
  - farm, lumber camp, quarry, mine, market, building sites: flags;
  - thatch-house and granary ridge pennants;
  - `prop_banner_*`, slot-marker pennants and sign, region-marker flags;
  - kingdom roofs and tower caps.
- Banners, crests and the throne carried a 2-part emblem in the kingdom's trim metal. Azure's was an 8-point star, not D-039's five. Crimson's read as a house.
- Flags, pennants and the slot sign had no emblem. The `prop_banner_*` emblem was the same gold diamond for every kingdom. These were colour only.
- **Visible from above (50°, 120–220 studs):**
  - roofs and caps (colour and silhouette);
  - flags (a few pixels);
  - the baldachin canopy.
- Hanging banners and shields are foreshortened to cos 50° ≈ 0.64 and are 7–12 px at 170 studs, so no emblem read from the overview camera.

**Design (one builder, `Pieces.emblem`):**
- **Mapping:**
  - The kind follows the colour through the tower-cap hue map (`Kit.emblemKind`): crimson crown, azure star, emerald oak leaf, gold sun. Neutral gets none.
  - Each emblem part carries `KitEmblem` = kind and `KitEmblemSlot`.
  - Each field (cloth, flag, pennant, shield, plaque, sign) records the slot: `KitEmblemCF` (relative to the field), `KitEmblemSize` and `KitEmblemDetail`.
- **Shapes** (anchored, no collide/touch/query, no shadow):
  - **crown 3**: two tall wedges and a diamond.
  - **star 5**: five 36-54-90 wedges in a pinwheel, whose union is exactly the regular star.
  - **oak 5**: three disc lobes, a diamond base, and a darker midrib and stem, tilted 35° (in bend).
  - **sun 4**: two squares for 8 points, a field-colour ring and the disc. On the plaques, 9: a disc and 8 wedge rays.
- **Colour:** ivory on the kingdom field. The sun is deep gold (`shade(colour, 0.42)`) on the light gold field.
- **Size:** 80 % of a banner's width.
- **Aerial plaques on the keep** (kingdom field, ivory border, full emblem):
  - **Roof plaque:** on the hall roof in front of the donjon, facing up, raised 2.4 on its border block. 6.7 / 9 / 10.5 studs at L1 / L2 / L3; the L1 donjon moved one stud back.
  - **Donjon-back plaque:** on the donjon's windowless back face, 6 / 7.5 / 8.5 studs, for views from behind, where the donjon hides the roof plaque.
- **Recolour:** `Kit.setKingdomColor` re-forms every slot to the new colour's kind on the stored anchor.
  - Works after the model has moved.
  - A neutral colour removes the emblem; neutral → kingdom adds it.
  - Other parts keep their identity.
  - Tower caps, stone and trim stay as built; a style change needs `Kit.build`.

**Iterations:**
1. **2D prototypes** (same primitives, at 12–40 px, normal, CVD and grayscale):
   - An ivory sun on a dark roundel read as a gear in grayscale. The deep-gold sun on gold read best.
   - An upright oak read as a lollipop tree.
2. **First render:** the star had a black pentagon centre. Five coplanar wedges overlapping make Cycles' shadow rays self-intersect, and the same overlap could z-fight in Studio. Every emblem part now sits 0.015 in front of the one before it.
3. **Visibility probe** (new spec: rays toward the camera at the controller's 50 / 57.5 / 65° pitches, exact wedge and corner-wedge shapes):
   - The L1 roof plaque was 84 % visible head-on and 63–65 % from the front diagonals at 50°: the front merlons and the turret hoardings and spires hid it.
   - Raised 2.4 and enlarged, it is now 100 % head-on and ≥ 84 % on the diagonals. The donjon-back plaque is 100 % from behind and from the rear diagonals.
   - Pure side views at 50° stay at 69 % for L1 (turrets on both sides). They are reported in the spec, not gated.
4. **The oak still read as a tree at 120 studs** (foreshortening). It is now in bend.

**Images** (`img/`, 1:1 crops of 1920×1080, Roblox 70° FOV, grass ground, Cycles 32 samples):
- `kit_emblems_aerial_distances.jpg`: own keep L1, centred, at 120 / 170 / 220 studs.
- `kit_emblems_aerial_170.jpg`: four keeps in one frame at 170 studs, front and rear; the outer two are seen from about 45°.
- `kit_emblems_aerial_plots.jpg`: own plot at 170 studs.
- `kit_emblems_aerial_170_cvd.jpg`: `cvd.py`'s simulation (normal, protanopia, deuteranopia, tritanopia) plus grayscale.

**Verdict at 170 studs (own keep, 1:1), looked at by FORGE-02:**
- Normal: crown, star, oak leaf and sun all read on the roof plaques; banners and flags carry them too (small).
- Protanopia / deuteranopia: crimson and emerald fields go olive and grey, but crown and leaf stay distinct shapes;
  star and sun unaffected.
- Tritanopia: azure and emerald are both teal; star vs oak separates them.
- Grayscale: all four read. Weakest is the oak (a tilted lobed leaf with a dark midrib; at 220 studs it is a
  diagonal leaf blob), strongest star and sun. From behind, the donjon-back plaques read; a crimson spire clips
  a corner from the rear diagonal.

**Part cost:** every model stays within budget (keep L2 emerald at 260/260). Ranges before → after across the
four canonical colours, neutral and two off-palette tints: keep L1 198–218 → 182–236, L2 230–258 → 204–260,
L3 261–292 → 234–292; barracks L4 236–252 → 221–248; watchtower L2 106–122 → 113–125; `prop_banner` 8 → 11–13;
slot marker 17 → 15–20. Paid for by: banner trim bands, the throne-back emblem, the keep's L2+ turret banners
(the roof plaque replaces them), standard finials, the hall's low side/back slits, barracks L4 jetty banners, and
fewer, larger plinth facing stones.

**Specs:** `KitEmblems.spec` (12) plus the existing budget and coplanar specs; 15 mutations all caught.

**Unverified:**
- Studio: SmoothPlastic emblems on Fabric cloth, Future lighting, and depth precision of the 0.015 stacking at 220 studs.
- Phone screens (fewer pixels per stud).
- The aerial camera's real azimuth relative to each keep (Layout yaw).

## Environment props polish (FL-0117; the user's first live Studio playtest) — FORGE-02

Feedback: "Trees are too blocky and primitive. Rocks and environment props feel too simple. Starting kingdom farm
areas visually conflict with rocks and trees." Scope here: the prop art in `Kit/Props.luau` (`oak`, `pine`, `birch`,
`bush`, `flowers`, boulders, `quarryNode`, `oreNode`, `woodNode`, `cropField`, `fence`, `haystack`). Placement and
density belong to the world-trim / FL-0112 work and are untouched. Hard rule: part-neutral or cheaper per prop (the
world sits at its D-047 ceiling).

Renders: `kit_*` pipeline as above, via the aerial-emblem scratch dump (every model placed in world space) and
`render_aerial.py`. Gameplay camera 62–80 studs / 20–26° down; aerial 170 studs / 50° down; 1280 × 720, Cycles 24
samples, grass ground, no Roblox material textures (Studio decides the final look). Before = main 0160bd3.
Images (`img/`): `env_polish_trees_gameplay.jpg` (30-tree cluster at the world's 13-stud centre spacing, before | after),
`env_polish_trees_aerial.jpg`, `env_polish_rocks_nodes.jpg` (S/M/L boulders, wood / crystal / gold / iron / quarry),
`env_polish_farm.jpg` (wheat + cabbage field, fence, haystacks, cart, well, farm building; gameplay + aerial),
`env_polish_bushes.jpg` (bushes, flowers, cart, well, goods).

**What changed (part counts incl. Root, before → after):**

| family | parts | shape change |
|---|---|---|
| oak (8) | 18,18,16×6 → 16×8 | ten overlapping canopy balls of 6.4–12.6 studs (core, two hanging skirt lobes, four shoulders, three crowns) coloured by height on a five-stop ramp (shaded underside → sunlit top); root flare + straight foot + a stem leaning 3.5–8°; two thick limbs (1.6 dia, was 0.9) reaching under the skirts; canopy hides the joins |
| pine (6) | 22 → 22 | the 5 pyramid tiers (4 corner wedges each) became 7 whorls of 3 or 2 drooping wedge boughs (18), each turned against the last, narrowing to a two-wedge pointed tip, the whole tree leaning slightly |
| birch (6) | 9 → 9 | slender leaning white trunk, one bark mark, six larger clumps in an airy crown with a light ramp; no shadow cast by the crown |
| bush (8) | 5/10 → 5/10 | one broad sunlit dome with three darker lobes tucked round the foot; berries/blooms 1.0 (was 0.7) sit on the dome surface |
| flowers (6) | 9 → 9 | a leafy mound (2 balls) with six 1.0 blooms standing on it |
| boulder S / M / L | 4 / 4 / 4 → 3 / 4 / 5 (cliff 4) | family 36 → 36. Tipped, flatter lumps (a block tipped on two axes reads as an angular rock; corner wedges read as shards and were dropped): S two lumps; M a dark foot under a light cap + pebble; L foot, mid mass, leaning lump + moss tuft. Cool dark foot (106,110,118) under a warm light top (172,170,162) |
| quarry node | 8 → 8 | three stepped strata (dark / pale / mid) with flat cut faces, rubble wedge, two stacked cut blocks, pick |
| ore node (6) | 10 → 10 | angular host rock (3 lumps + pebble), five 2.4-stud nuggets proud of the faces: gold (242,194,48) on 3–4, rust on 1–2, Neon crystals on 5–6 (the only Neon) |
| wood node | 14 → 14 | five stacked logs with pale cut-wood end rings, chopped stump with a pale top, axe stuck in it (unused by the Layout, which uses trees as wood nodes) |
| wheat field | 17 → 17 | exactly 38 × 28 (`Props.FIELD_SIZE`): soil bed, six uniform 1.7-stud flat-topped rows (+ 0.22 lighter top slab), 1.8-stud brown furrows, three sheaves on the soil border |
| cabbage field | 66 → 65 | same 38 × 28 bed, seven soil ridges, eight cabbages per ridge |
| fence | 7 / 8 → 7 / 8 | 2.7 high (was 3.4), pale rails; rows (top 2.4) stay below it |
| haystack | 4 → 4 | hay drum under a dome (was two stacked balls = a snowman) + pitchfork |

Soil colour: bed (96,70,44) luminance 74, ridges (112,82,52) luminance 86 — brown, not black (the FL-0085 reviewer's 60–90).
The bed is 0.5 high because the terrain field's top is 0.2 above ground: lower and it z-fights the terrain.

**Bounds (Layout and placement use them):** oak height 24.5–26.2 (was 25.2 for all), radius ≤ 12.2 (11.5); pine
27.9–32.6 (28.0), radius ≤ 8.2 (9.3); birch 21.5–23.8 (21.2–26.1), radius ≤ 7.0 (6.8); boulders S 3.3 / M 5.6 / L 9.1
high (2.7 / 5.0 / 9.0); stone node radius 9.0, ore 7.2, wood 6.4 (the layout keeps radius 9 clear); crop fields 38 × 28
(was 38 × 28.6), maxY 2.4 wheat / 3.1 cabbage (was 3.6 / 2.0).

**One find on the way:** `standIn` seeds the generator with the asset id's hash, and neighbouring ids give
neighbouring seeds whose first draw is nearly identical, so every oak had the same trunk height. `standIn` now burns
four draws first (spec: `KitProps` "same asset id, same model; different variants differ").

**Honest verdict (looked at the images, FORGE-02):**
- **Pine: clearly better.** Layered, drooping, leaning, pointed; no longer a stacked pyramid. Reads as a dark conifer at both cameras.
- **Oak: better, not transformed.** Fuller and more irregular, with a dark underside and light crowns, flared leaning trunk. It is still a cluster of balls; from the gameplay camera it reads as a broad rounded tree, but it is darker and heavier than before, and the gradient is modest because the preview has even light.
- **Birch: marginal.** More clumps, slimmer, lighter crown, but the clumps still read as a bunch of balls.
- **Boulders: better.** Angular, two-tone, three distinct shapes, moss on L; still flat, low-poly slabs.
- **Quarry / gold / iron / wood: clearly more readable.** The old gold ore was an unreadable speck on a grey box; the nuggets read as gold at 80 studs. The quarry reads as stepped cut stone.
- **Fields: clearly better.** Brown beds, tidy uniform rows, no spikes; consistent with the farm building's own rows. Wheat rows still read as golden slabs rather than grain from close up.
- **Bushes / flowers: better.** Rounder, fuller; accents readable at gameplay distance, tiny at the aerial camera.
- **Still placeholder quality (needs imported Blender meshes):** every tree canopy (a ball cluster, no leaf texture, no real bark), rocks (no faceted or fractured surface), wood logs (no real rings or bark), crops (no stalks or ears).

**Unverified:** Studio (SmoothPlastic and Grass material textures, Future lighting and shadows; the crowns'
`CastShadow = false` saves cost but was only checked headless); phone screens; the in-world look with the world-trim
density and FL-0112 placement; `Metal` ore nuggets render darker here than Roblox's Metal will.

**Specs:** `KitProps.spec` (26 tests: part-count ceilings per id, hygiene, determinism and variation, bounds, tree / rock
/ node / field shape and colour rules); 28 mutations of `Props.luau`, all caught.

## Fresh-context D-019 scoring — FL-0117 environment polish

Reviewer: fresh-context visual reviewer (did not build these assets), 2026-10-15. Evidence: the five Blender renders `img/env_polish_{trees_gameplay,trees_aerial,rocks_nodes,farm,bushes}.jpg` (before | after pairs; an approximation of Studio, no material textures, **not a Studio play test**). I opened each image, then cropped, up-scaled 2-5x, shrank (distance simulation) and greyscaled the ore-node strip with PIL. Scored before reading any author log or the Kit source. Afterwards I read the author's part-count table only, to fill the part-cost column (the renders cannot show part counts); no image-based score was changed by it.

Rubric (1-5): PASS needs silhouette >= 4, variation >= 4, readability at gameplay distance >= 4, and proportions, palette, detail density, cohesion and part cost each >= 3. Family rows are split where the sub-items differ enough to matter; a family passes only if all its rows do.

| item | sil | var | read | prop | pal | detail | cohes | cost | verdict | note |
|---|---|---|---|---|---|---|---|---|---|---|
| Trees (oak / pine / birch) | 4 | 3 | 4 | 3 | 4 | 3 | 3 | 4 | NEEDS-WORK | Visible improvement, still sphere-pile and plate-stack. All three species identify at the 170-stud aerial (dark spiky = pine, big lobed green = oak, small pale clusters on white poles = birch). Pine is the big win (spire tip, drooping whorls, uneven height). Oak crowns are now lobed with a lit top, but the four oaks in the cluster are near-identical clover shapes (variation 3). Birch crown is six balls floating off a thin pole. Part-neutral (oak 16, pine 22, birch 9 per the author table). |
| Rocks and nodes: boulders S / M / L | 2 | 3 | 3 | 3 | 4 | 2 | 3 | 4 | NEEDS-WORK | Barely better, still boxes. Two-tone slate-on-limestone helps value and palette, and they are flatter and squatter, but every boulder is still a set of parallel-faced rectangular blocks stacked and tipped, which reads as concrete blocks or crates. The moss ball on top of the L rocks reads as a green ball resting on a block, not moss. |
| Rocks and nodes: resource nodes (wood, ore: crystal / gold / iron, quarry) | 3 | 3 | 3 | 3 | 4 | 4 | 4 | 4 | NEEDS-WORK | Clear, real improvement. Ore hosts now carry coloured nuggets (cyan crystal, yellow gold, rust iron), the quarry is three stepped strata with a pick, wood is a log pile with end rings. At a simulated 80 studs the three ores still separate by hue, but all three are the same lumpy grey silhouette, the nuggets are only ~8 px, and in greyscale gold / iron / crystal do not separate. Gold nuggets are cubes. Quarry and wood read well. |
| Crop fields: wheat field | 2 | 2 | 2 | 3 | 4 | 2 | 3 | 4 | NEEDS-WORK | **Does not read as a grain crop.** It is still six long, identical, flat-topped tan slabs; they read as planks, bread loaves or bleacher seats at both cameras (from the aerial they look like the same tan boards as the farm building at the right edge of the frame). The only change is a soil border and gaps between rows. No stalk, no ear, no height or tilt variation. |
| Crop fields: cabbage field | 3 | 3 | 4 | 3 | 4 | 3 | 4 | 3 | NEEDS-WORK | Clear improvement and the best of the family. Soil bed with raised ridges anchors the rows, spheres vary in size and shade; reads as a cabbage or lettuce patch at both cameras. Silhouette is still a rectangle of regular dots (var 3), and it is ~65 parts for one field (cost 3, unchanged). It is a vegetable field, not the grain crop. |
| Bushes and flowers | 3 | 3 | 3 | 3 | 4 | 3 | 4 | 4 | NEEDS-WORK | Slight improvement on the bushes: a lit dome over darker foot lobes is a more natural value order, and white blossom / red berry dots now sit on the surface so the three bush types separate. Silhouette is still the same three-ball blob in all eight. The flower patches got smaller and lost their green ground disc, so at gameplay distance they are specks (arguably worse than before). Readability: bushes 4, flowers 2. |

### Answers to the specific checks

- **Fuller, more natural trees, species recognisable at the aerial?** Fuller and less blocky: yes for pine (clearly), moderately for oak, slightly for birch. Species recognisable at the aerial camera: yes, all three, by colour value and silhouette. Not yet natural: oaks look cloned from one recipe and the birch crown looks like balloons on a stick.
- **Rocks better?** Marginally. Colour is better, the form is not (still boxes). **Nodes read as wood / stone / gold at 80 studs?** Wood (log pile) and stone (stepped quarry): yes. Gold: yes by yellow, but only by hue. Crystal vs iron: by hue only, and small.
- **Crop field a grain crop, not slabs or spikes?** No. The wheat field is still slabs. The cabbage field reads as a vegetable crop, not grain.
- **Still primitive-looking?** Yes. This is a real improvement and not a pass: the trees are the closest, then the nodes; boulders and wheat still look like first-pass primitives.

### Fixable problems (all NEEDS-WORK rows)

Trees
1. Oak variation: the cluster shows one crown recipe (four or five lobes plus a lit cap). Give the 8 variants visibly different masses (wide and flat, tall and narrow, lopsided with a gap showing a branch fork, two-lobe young tree), not only different ball sizes.
2. Pine lower boughs read as loose, flat, tilted paper squares (clear in the gameplay camera). Keep the whorl rhythm but make each whorl a coherent ring of drooping wedges with a bounded tilt, so the lower tiers read as a skirt and not scattered tiles.
3. Birch: the crown balls sit apart from the trunk. Overlap them into the trunk top, and add one or two branch stubs; the trunk is a bare thin tube with a single dark band.
4. Oak trunk shows a collar ring at the base that reads as a separate stump; blend the flare.

Rocks and nodes
5. Boulders: stop using parallel-faced boxes. Use wedges or angled slabs so no two faces are orthogonal to the camera, vary the footprint (low and wide / tall and narrow / leaning), and replace the moss ball with a flat moss tuft sitting on a ledge. Light cap / dark foot is worth keeping.
6. Ore nodes: differentiate by form as well as hue so they survive greyscale: crystal = tall pointed vertical shards (brightest value), gold = rounded nuggets on a mid host, iron = chunky dark ore with rust bands (darkest). Enlarge nugget features about 1.3x so they read at 80 studs.

Crop fields
7. Wheat (blocker for this family): replace the six slab rows with something that reads as grain: thin, tapered, slightly leaning stalks or small tufts in rows, ear-heads in a lighter gold on top, variable heights, and a green-to-gold gradient. 17 parts cannot do this; either decide a bigger part budget for the wheat field with FL-0112 or find a cheaper trick, but a flat-topped slab will not pass.
8. Cabbage field: break the dot grid a little (a few missing or smaller plants, a leaf-ring hint on the larger ones). Consider counting the parts: 65 for one field is the most expensive prop in the kit.

Bushes and flowers
9. Flowers: restore a visible leaf mound and raise bloom size to about 1.4+ studs so a patch reads at gameplay distance; vary colour per patch.
10. Bushes: vary the recipe (two to five lobes, different sizes, a flattened base) so the eight do not share one three-ball silhouette.

### Verdict

- Visible improvement on "before": **yes** for trees, resource nodes and the cabbage field; **marginal** for boulders, the bushes and the wheat field; **flowers are arguably a step back** at distance.
- Passes: none of the four families (trees: variation 3; rocks and nodes: boulder silhouette 2; crop fields: wheat silhouette, variation and readability 2; bushes and flowers: silhouette 3, variation 3, flower readability 2). Nothing here is a Studio result.
- Still reads as placeholder: boulders (stacked boxes), wheat field (planks), birch crown (balloons on a pole), pine lower boughs (loose flat plates), oak crowns (one recipe, ball pile), bush recipe (three balls), gold nuggets (cubes).

### Visible-defect scan and open list for round 2 (FORGE-02, 2026-10-15, before #141 merges under D-051)

- **Scan:** every prop id (72: trees, bushes, flowers, boulders, nodes, fields, fence, haystack, cart, well, goods) checked headless for parts that float (bounding box touches neither the ground nor any other part, 0.05 margin), parts buried under the ground, and ground clipping deeper than 1.4 studs. **One finding, fixed:** the quarry's pick hung 0.13 above the ground touching nothing; it now leans on the cut-block stack. `KitProps.spec` guards it ("leaves no part floating ... and none buried"; mutation: the old pick position fails it). Bounding boxes are loose for wedges and balls, so this catches gaps, not every thin sliver; it is not a Studio check.
- **Not mine:** prop-vs-prop overlap in the world is placement (WorldPlan scatter, FL-0112 / FL-0116). Crown radii are unchanged from main (oak <= 12.2, pine <= 8.2, birch <= 7.0 against the 13-stud centre spacing).
- **Still NEEDS-WORK after round 1** (rubric 1-5; PASS = silhouette, variation, readability >= 4 and proportions, palette, detail, cohesion, cost >= 3; no family passes):

| family | sil | var | read | prop | pal | detail | cohes | cost | below threshold |
|---|---|---|---|---|---|---|---|---|---|
| trees (oak / pine / birch) | 4 | 3 | 4 | 3 | 4 | 3 | 3 | 4 | variation: oaks cloned, birch crown balloons on a pole, pine lower boughs loose plates, oak base collar |
| boulders S / M / L | 2 | 3 | 3 | 3 | 4 | 2 | 3 | 4 | silhouette, variation, readability, detail: still parallel-faced boxes, moss ball |
| resource nodes | 3 | 3 | 3 | 3 | 4 | 4 | 4 | 4 | silhouette, variation, readability: ores separate by hue only, gold nuggets are cubes |
| wheat field | 2 | 2 | 2 | 3 | 4 | 2 | 3 | 4 | silhouette, variation, readability, detail: six flat slabs read as planks |
| cabbage field | 3 | 3 | 4 | 3 | 4 | 3 | 4 | 3 | silhouette, variation: regular dot grid; 65 parts |
| bushes and flowers | 3 | 3 | 3 | 3 | 4 | 3 | 4 | 4 | silhouette, variation, readability: one three-ball recipe; flowers 2 at distance |

Round 2 (branch `forge/02-blender-env-polish-r2`, stacked on #141): wheat first within 17 parts, then boulders from angled wedges and slabs with a flat moss tuft, then oak and birch variety by silhouette; 2 author rounds, then a fresh-context re-score.

## Environment props polish, round 2 (FL-0117; branch `forge/02-blender-env-polish-r2`, stacked on #141) — FORGE-02

Scope from FORGE-00 after the round-1 fresh review: wheat, boulders (chunky, a flat moss tuft, silhouette distinct from the ore
crystal, S3 / M4 / L5 at most), then oak / birch variety by silhouette. Part counts stay at or below the #141 numbers per id, except
wheat, which D-047's 2026-10-15 amendment raises to 44.
Renders as in round 1 (Blender preview, no Roblox material textures, **not a Studio play test**): gameplay 62–80 studs
and aerial 170 studs / 50°, 1280 × 720, Cycles 24 samples. Images in `img/`: `env_polish_r2_trees_gameplay.jpg` and
`env_polish_r2_trees_aerial.jpg` (#141 | round 2), `env_polish_r2_oaks_pines_birches.jpg` (line-ups), `env_polish_r2_boulders.jpg` (main | the shipped boulders, which are #141's),
`env_polish_r2_boulders_rejected.jpg` (main | #141 | the rejected chunky pass), `env_polish_r2_wheat.jpg` (#141's slabs | the tuft field) and
`env_polish_r2_wheat_attempts.jpg` (the 17-part attempts and the over-budget references).

**1. Wheat: 44 parts per field under the D-047 amendment (own commit `926edd5`, droppable).** At 17 parts nothing worked: two attempts and six
designs (combed rows, stepped patches, ridges, ridges plus stooks, stooks on stubble, sparse block tufts) all read as planks, crates or tents
(`env_polish_r2_wheat_attempts.jpg`, which also shows the over-budget tuft references). FORGE-00 then ruled that a wheat field may use **up to 44 parts
(6 × 7 tapered tufts, +27 per field, +216 in the world), conditional on FL-0116's rebuilt-world measurement leaving at least 600 parts under 27k**
(otherwise the dressing density knob pays). Implemented: the 38 × 28 soil bed plus **42 `WedgePart` tufts**, one part each, six rows of seven,
alternate rows shifted half a tuft, every tuft leaning the same way (a field combed by the wind) by a different amount, 1.6–2.2 studs high,
3.4–4.2 wide; colour runs from olive green (124,148,52) at the west end to ripe gold (246,214,108) at the east with noise per tuft, so the field reads as
growing grain from both cameras and every tuft stands out from the soil (luminance ≥ soil + 50). About 1 stud of soil shows between the rows. Fence and
haystack are unchanged. `Props.WHEAT_PARTS` = 44 and `KitProps.spec` pins it (`WHEAT_PARTS`, citing the amendment). Honest limit: close up the tufts still read as
leaning tiles, a mat of straw rather than stalks; a real crop row is a one-mesh Blender asset. Two earlier tuft layouts (random flips, narrow upright)
read as scattered plates or a checkerboard and were dropped. Images: `env_polish_r2_wheat.jpg` (#141's slabs | the tuft field, gameplay and aerial).

**2. Boulders: two passes, neither clearly better than #141; reverted to #141's boulders (unchanged).** Pass 1 rebuilt every rock
from tipped wedges (S: two facing wedges, M: three, L: foot, cap and leaning wedge with a flush moss patch). At gameplay distance
the S and M rocks read as sharp angular shards, close to the ore crystals, and the L as a ramped tent: worse than #141's chunky
rocks. Pass 2 went broad and chunky as asked (a block or two tipped 10-25 degrees plus a smaller wedge, nothing thinner than 25 % of its
longest side, height at most 0.6 of width, L with a flat moss patch on a flat top). Rendered against main and #141 at gameplay and aerial
distance (`env_polish_r2_boulders.jpg`, main | #141 | pass 2), it is a darker, flatter version of the same stacked blocks: the moss
patch reads a little better than the ball, but the silhouette is no better and at 170 studs the moss is invisible. Not clearly better, so
`lump` and `boulder` are back to #141's code, byte for byte, and the spec to #141's boulder tests. The ball moss on L stays (the flat patch
was only judged on a block foot); a real fix for boulders needs faceted meshes (the Blender batch), not more primitives.

**3. Oak and birch variety by silhouette; pine skirt.** Oak variants pick an archetype by id: dome, tall ovoid, wide flat spreading,
lopsided (a heavy side, a gap, a bare limb carrying one small lobe), twin (two crowns on a forked trunk) and repeats; every oak is still
10 lobes + 2 limbs + 3 trunk parts = 16 parts. Lobe colour follows height within each archetype. The root flare is now the trunk's own bark colour and a
smaller step (the collar read as a stump). Birch: five clumps stacked up and wound through the trunk top (no balloons on a pole) and one
thin branch stub carrying a fifth clump out to the side: trunk + bark mark + stub + 5 clumps = 9 parts, as before. Pine: six whorls of
4, 4, 3, 3, 2, 2 boughs (18, as before): the lowest two are four-bough skirts with bough width set from the whorl's circumference so
neighbours meet, instead of three loose plates.

**Part counts (Root included), #141 → round 2:** oak 16 → 16 (all 8), pine 22 → 22, birch 9 → 9, boulders S 3 / M 4 / L 5 / cliff 4 → unchanged (reverted to
#141's); **wheat 17 → 44 per field** under the D-047 amendment (6 × 7 tufts; the cabbage field stays 65). **Specs:** `KitProps.spec` 28 tests (round 2 adds
oak silhouettes spread over aspect ratio and sideways offset, birch crown wound into the trunk with a side stub, the pine skirt, and the wheat as 42 tilted wedge
tufts in six rows with a green-to-gold gradient and the 44-part constant `WHEAT_PARTS`); 39 mutations of `Props.luau`, all caught.

**Unverified:** Studio (SmoothPlastic / Grass / Slate textures, Future lighting), phone screens, the in-world look with FL-0116's density and FL-0112's
placement, and whether FL-0116's measured headroom (at least 600 parts under 27k) actually holds; if not the wheat commit is the one to drop or the
density knob pays.

### Fresh-context image-only D-019 re-score of round 2 (2026-10-15)

Reviewer: a fresh Claude Code session (`session_01PtRhY6SNSMufurC4qvRb26`, claude-sonnet-5-5) started on this branch with only the five images named
below, told not to read any source, markdown, log or history, and to score the right-hand (round 2) panels strictly; its reply is recorded here
as given, not edited. Images: `env_polish_r2_trees_gameplay.jpg`, `env_polish_r2_trees_aerial.jpg`, `env_polish_r2_oaks_pines_birches.jpg`,
`env_polish_r2_boulders.jpg`, `env_polish_r2_wheat.jpg`. Blender previews, **not a Studio play test**. Rubric 1-5; PASS needs silhouette, variation,
readability >= 4 and proportions, palette, detail, cohesion, cost >= 3.

| family | sil | var | read | prop | pal | detail | cohes | cost | verdict |
|---|---|---|---|---|---|---|---|---|---|
| trees (oak / pine / birch) | 4 | 4 | 4 | 3 | 4 | 4 | 4 | 3 | **PASS** (reviewer: borderline; weakest species birch, then pine) |
| boulders S / M / L (the #141 boulders, reverted) | 2 | 3 | 3 | 3 | 4 | 3 | 3 | 4 | NEEDS-WORK |
| wheat field (44-part tufts) | 2 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | NEEDS-WORK |

Round 1 for comparison (#141's own review): trees 4/3/4/3/4/3/3/4, boulders 2/3/3/3/4/2/3/4, wheat 2/2/2/3/4/2/3/4.

Reviewer's answers (summarised): the eight oaks show genuinely different silhouettes (a wide dome, a tall one, a wide one, a clearly leaning lopsided one, a
twin-lobed one) on one sphere-cluster recipe; variants 1 and 6 (both dome) are the most alike. Pine skirts read as layered conifer boughs (a little crunchy
and very dark at gameplay distance). Birch crowns are better than round 1 but still look like balloons on a thin pole (the side stub is barely visible, the
black bands read as tape). The boulders mostly do not read as rocks but as stacked slabs or crates, the moss ball looks like a ball on a table, and the three variants of
a size are nearly identical. The wheat no longer reads as planks but is not a grain crop either: crate-like blocks or hay bales from gameplay, pavers or tiles on dirt from the
aerial camera; no stalks, heads or ragged top edge. Defects named: a tiny cube beside one M boulder looks detached (it is the M pebble, resting on the ground), and some birch
crowns at the cluster edge look slightly detached from their poles; no clipping.

Reviewer's top fixes: **trees** thicken the birch trunk about 1.5x and lower and merge its crown, replace the black bands with thinner irregular marks, lighten the pine
skirt a few shades and reduce plate overlap, differentiate oaks 1 and 6; **boulders** faceted tapered shapes with a narrower top, a flat irregular moss patch, three genuinely different profiles
per size, no stray pebble; **wheat** thinner, taller, closer-packed stalk clusters with a ragged top and a smooth gradient, less squareness.

**Status after round 2:** trees pass the image-only rubric (borderline) and are a modest, real step over #141; boulders stay at #141's NEEDS-WORK level (two primitive passes did not help;
this needs a mesh or a different primitive vocabulary); the wheat at 44 parts is better than slabs (var, read, detail up from 2 to 3) but still not a pass, and part cost is the limit:
the reviewer's own fix (thin, close-packed stalk clusters) needs more parts, not fewer.
