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

## Round 6 — FL-0085 visual record: farm L1–2 fix and the level sheets — 2026-10-13
Branch `forge/02-blender-fl0085-record` (from main 8673907). Evidence: headless specs and Blender (`bpy`) renders
of the Lune dumps (`KitBuildingsDump.spec`, `KitDump.spec`) through `render_kit.py` from `forge/02-blender`, run
from a scratch copy. These are not Studio screenshots (D-034). Why: the round 3 table scored farm L1–2 silhouette 3
and variation 3, below the D-019 pass line of 4 ("wheat still a flat tan slab"; L1 → L2 only a small barn hidden
behind the cottage). Only the farm builder changed (`BUILDERS.farm` and its farm-only helper `wheatRows`).

**Farm changes:**
- **Crop rows:**
  - Rows run along Z (front to back), so every camera sees the dark soil furrows between them. Before, they ran along X, and from the front each row hid the furrow behind it.
  - Each row is a narrow olive stalk bed (46 % of the row pitch, so furrows are ≥ 0.8 studs) carrying three ear bunches. The bunches step in height (+0, +0.35 and +0.7), cycle three golden tones (wheat, light and a new deep amber), are tilted ±4–6° and turned ±2.5°, and sit with dips between them that show the olive stalks.
  - Row ends are ragged.
  - Cost: 4 parts per row.
- **L1 smallholding (34 × 28):**
  - 8 rows of shorter wheat (crop top 2.4–3.6) behind a harvested stubble strip, with the three stooks standing on it.
  - Unchanged: cottage, post-and-rail fence on three sides, vegetable patch, haystack, cart, scarecrow, kingdom flag.
- **L2 farmstead (40 × 32):**
  - **Barn:** a tall kingdom-tile barn in the back-left corner. It is 11.4 × 12, with walls 11, and its ridge reaches 21.9, 2.1 above the cottage's thatch ridge. Its gable end faces the front over the crop and carries the threshing doors under a timber lintel, a hayloft door and a hoist beam. The old L2 barn sat behind the cottage, below its ridge (14.9 vs 18.6), and the front views hid it.
  - **Crop:** 10 taller rows (crop top 3.6–4.8). They wrap round the barn: six short rows in front of it and four full-length rows beside it.
  - **Cottage:** taller and deeper (walls 8.4 → 9.2, depth 9 → 9.6), with a flower-box window beside the door.
  - **Yard:** a round hay rick (L1's haystack grown) stands mid-yard, with the vegetable patch (2 × 2 cabbages) and the cart.
  - **Boundary:** the front fence gets an open two-leaf gate, and dry-stone walls (kingdom stone) run on the left up to the barn and behind the long rows.
  - Every kingdom keeps its emblem flag (`KitEmblems.spec` green).
- The footprints are unchanged: G13.5 / `EXPECTED_FOOTPRINTS`.

**Part counts before → after** (`Kit.partCount`; budget 190; the four canonical colours, neutral and the two
off-palette tints of `KitBuildings.spec`):

| colour | L1 before → after | L2 before → after |
|---|---|---|
| crimson | 154 → 164 | 185 → 184 |
| azure | 156 → 166 | 187 → 186 |
| emerald | 157 → 167 | 188 → 187 |
| gold | 155 → 165 | 186 → 185 |
| neutral | 151 → 161 | 182 → 181 |
| emerald off-palette 40,127,71 | 157 → 167 | 188 → 187 |
| gold off-palette 245,205,48 | 155 → 165 | 186 → 185 |

- **L2 (emerald 188 → 187):**
  - Paid for by:
    - the post-and-rail fence on the left and back (posts 20 → 7, rails 8 → 4);
    - the stooks (6);
    - the barn's corner posts and door braces (6);
    - the barn haybale;
    - two cabbages;
    - two plinth stones (the cottage plinth facing is coarser);
    - one frame brace.
  - Spent on:
    - wheat (24 → 40);
    - the flower-box window (8);
    - the hayloft door, hoist beam and lintel (3);
    - the rick (2);
    - the gate (2);
    - the walls (2);
    - a second field slab for the soil round the barn.
- **L1 (+10):** wheat 21 → 32 and the stubble strip, less two plinth stones.

**Author rounds** (quick renders 300 px; tiles in scratch only):
1. **Rows turned to run along Z, two ear segments per row.**
   - The furrows began to show, but the ears overhung the stalks and filled the gaps, so the field still read as stacked planks.
   - The new barn behind the cottage was taller than before, but a street-level front render (60 studs, 12°) still showed nothing of it.
2. **Narrower rows, three bunches per row in three tones and heights.**
   - The field now read as crop rows from the 50° aerial checks (90 and 140 studs; front, side and rear) and from the hero view.
   - The barn was still hidden from the front.
3. **Barn moved to the back-left corner with its gable end to the front, and the rows wrapped round it.**
   - The front, hero and aerial views all show it, as a second, taller gable beside the cottage.
4. **Polish.**
   - Bunches tilted and turned a few degrees, which gives an uneven top at no part cost.
   - The gabled rick, which read as a small hut, became a round rick.
   - The vegetable patch is back at L2, so L2 contains everything L1 has.

Then final renders at 420 px and 28 samples.

**Author verdict at gameplay distance:** this is not the D-019 score; a fresh-context reviewer scores the committed images.
- **Gameplay strip (~90 studs, low front view):** farm L2 reads as clearly bigger and different from L1. It has a second, taller kingdom-roofed gable with barn doors beside the cottage, a wider and taller field, a larger cottage with a window box, and a gate.
- **Crop:** reads as golden rows with furrows and an uneven top. From the low angle the row ends still look somewhat blocky.
- **Studio's Grass material texture:** not seen yet. It should soften the bunches further.
- **Barn from straight in front:** the cottage covers about half of it.

**Spec:** a new `KitBuildings.spec` block, "Kit farm crop and levels (G13.5, D-019)", with 2 tests over 7 colours:
- **Rows:** ≥ 8 rows at L1 and ≥ 10 at L2; each runs along Z (length > 4 × width); furrows are ≥ 0.8; each row has ≥ 3 ear bunches above the stalks with a top range of ≥ 0.3.
- **Levels:** L2 has more rows than L1 and a crop ≥ 0.8 taller; there is a barn at L2 only, and its ridge is ≥ 1 stud over the thatch ridge.

All 9 mutations were caught:
- rows along X;
- no furrows;
- flat bunches;
- one bunch per row;
- the same row count at L1 and L2;
- an L2 crop that is not taller;
- a low barn;
- no barn;
- ears sunk below the stalks.

The coplanar probe, the budgets, the footprint containment and `KitEmblems.spec` stay green.

**Images** (`img/`; final renders 420 px / 28 samples; total 589 KB):
- `kit_levels_keep.jpg`: keep L1–3, azure, plus the gameplay strip. This is main's keep. The throne, emblem and pennant work in progress on another branch is not in it.
- `kit_levels_barracks.jpg`: barracks L1–4, crimson, plus the gameplay strip.
- `kit_levels_house_farm.jpg`: house L1–2 (v1 gold, v2 emerald) and farm L1–2 (azure), plus the gameplay strip at ~90 studs.
- `kit_throne.jpg`: the keep L1 throne close-up.
  - **Tiles:** the throne, dais, baldachin and standards in each of the four kingdoms (`KitDump` `building_keep` colours), with a 5.5-stud R15 proxy for scale.
  - **Strip:** azure keep L1 front at ~58 studs, Roblox 70° FOV.
  - **Seat:** previews as a block (render_kit knows primitive classes only).
  - **Renderer:** a scratch variant of `render_kit.py` with a close-up camera. It is not committed.

**Unverified:**
- Studio look: Grass material on the wheat, Slate walls, the gate leaves, and depth precision of the tilted bunches.
- Phone screens.
- The real azimuth of the aerial camera relative to each farm. From straight in front, the cottage covers about half the barn.

## Fresh-context D-019 scoring — FL-0085 record (2026-10-13)

**Reviewer:** a fresh-context subagent that did not build the kit. It read no author logs or Kit source before scoring.
**Inputs:** `img/kit_levels_keep.jpg`, `img/kit_levels_barracks.jpg`, `img/kit_levels_house_farm.jpg`, `img/kit_throne.jpg`. These are Blender approximations of the Lune Kit dump with no material textures.
**Method:** opened each sheet, then cropped and zoomed the gameplay strips and throne tiles with PIL and made grayscale versions to test colour-free readability.
**Evidence:** render review only. It is not a Studio play test.

**Part-cost scale:** the worst level's share of its budget. 5 = 75 % or less, 4 = 90 % or less, 3 = 100 % or less, 2 = over budget.

| type | sil | var | read | prop | pal | detail | coh | cost | verdict | notes |
|---|---|---|---|---|---|---|---|---|---|---|
| keep L1–3 | 4 | 4 | 4 | 3 | 4 | 3 | 4 | 3 | PASS | Real growth: 57 → 67 → 77 studs tall and 31 → 39 → 45 footprint. L3 adds a second ring of caps. Star banners read in grayscale at 79 studs. Weak points: fat front towers squeeze the door bay, the tower drums are plain, and L2 is at 244/260 parts. |
| barracks L1–4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 | PASS | Four distinct silhouettes at 73 studs: cottage, then two storeys, then a spire, then a crenellated gatehouse. Crowns read in grayscale. L2 → L3 is the weakest step: the body is identical, and in the iso view the spire seems to grow out of the roof ridge. In the iso view the L4 flag merges with the red left spire. L4 is at 237/260 parts. |
| house L1–2 | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 4 | NEEDS-WORK | v2 emerald L1 → L2 gains a clear second storey (+7 studs). v1 gold L1 → L2 adds only a dormer, +3 width and +2 height, and the two levels look the same at 90 studs and in grayscale. The gold v1 house carries no sun emblem anywhere, so gold is told by colour alone. The emerald leaf pennant is only a few pixels at 90 studs. |
| farm L1–2 | 3 | 4 | 3 | 3 | 3 | 3 | 4 | 3 | NEEDS-WORK | The azure-roof barn makes L2 read as bigger. The wheat reads as stacked planks or hay bales in a pen, which could be mistaken for a lumber yard. In grayscale, field, thatch, fence and haystack are one tan value. L1's silhouette is the house v2 cottage plus a low pen, and its haystack is hidden behind the cottage from the front. L2 is at 186/190 parts. |
| throne (keep L1, 4 kingdoms) | 3 | 4 | 3 | 2 | 3 | 4 | 4 | 3 | NEEDS-WORK | Close up, it reads as a high-backed throne on a dais, and the crown/star/leaf/sun set separates the kingdoms in grayscale. The canopy sits at 30.4 studs, about 24 studs (4.4 proxy heights) above the 6.2-stud seat, on hair-thin poles, so it reads as an entrance awning, not a baldachin. The throne back fills the dark door opening and vanishes in grayscale for crimson and emerald. In the off-axis gameplay views (keep strip L1 and L3), a pole cuts through the throne. No clipping is visible, but the back finials touch the arch voussoirs. The keep with throne is 218–236 parts, against a budget of 260. |

**Fixes for the NEEDS-WORK rows:**
- **Throne:**
  - Lower the baldachin to about 12–14 studs and deepen it so it visibly roofs the seat.
  - Hang a kingdom-colour back cloth with a valance behind the throne, so the throne stands against a light backdrop instead of the dark door. Move the shield above the canopy or onto that cloth.
  - Pull the throne 1–2 studs forward, clear of the arch.
  - Put the kingdom emblem on the throne back, and add a light trim edge so the throne reads in grayscale.
  - Thicken the poles, or move them to the dais corners at the new height, so they no longer cross the throne in three-quarter views.
  - All of this should fit within the 24 parts of headroom on the emerald keep L1 (236/260).
- **House:**
  - Give v1 L2 a front-visible change: a jettied third storey, a side wing or lean-to, or about +4–6 studs of height. It has 29 parts of headroom (161/190).
  - Add a sun pennant or plaque to gold v1.
  - Enlarge the ridge pennants so the emblem reads at 90 studs.
- **Farm:**
  - Rebuild the wheat as upright, thinner stalk clusters with dark soil furrows between the rows. This must stay part-neutral on L2 (186/190).
  - Separate the values: darker soil, more saturated gold wheat, and muted thatch.
  - Bring the L1 haystack, or a taller vertical prop, to the side or front of the cottage.
  - Offset the L2 barn so the cottage doesn't hide its lower half from the front.

**Cross-kit notes:**
- **Leaf emblem:** crown, star and sun survive grayscale. The leaf is the weakest emblem: at standard size it reads as a white cloud or blossom. Give it a lobed oak outline and a stem.
- **Thatch:** the thick slab with a log ridge reads as a cushion or loaf, and it causes the tan-on-tan problem on the house v2 and the farm.
- **Gameplay strips:** the models are packed too tightly. The keeps overlap and the two gold houses touch. Space them at least 8 studs apart so each level's silhouette can be judged on its own.
- **Kingdom coverage:** the level sheets show one kingdom per type. Combinations such as gold barracks L4 or emerald farm L2 are not reviewed.
- **Part headroom:** keep L2 has 16 parts left and farm L2 has 4.

**Unverified:**
- Studio materials and lighting.
- Phone-size screens.
- Whether the throne finials and the arch voussoirs actually intersect in 3D. The renders only show that they touch.

## Round 7 — farm L1–2, attempt 3: a new crop representation (after the fresh-context NEEDS-WORK) — 2026-10-13
Branch `forge/02-blender-fl0085-record`. Evidence: headless specs and Blender (`bpy`) renders of the Lune dumps.
These are not Studio screenshots (D-034). This is the farm's third attempt, so the approach changed instead of
tuning the round 6 rows. Only the farm builder, its helper `wheatRows`, the farm-only colour constants and
`PART_BUDGET.farm` changed; keep, throne, house and emblem code are untouched.

**Changes, by finding:**
1. **Stacked planks or hay bales → upright tufts.**
   - Each row is a low ochre stalk bed (40 % of the row pitch, so bed furrows are ≥ 1.1 studs) carrying upright gold ear tufts. A tuft is one `CornerWedgePart` (a spike with its apex over one corner), 56 % of the pitch wide, taller than wide, and about 3.4 studs long along the row.
   - The tufts overlap along the row and the apex alternates front and back, so the row is a zigzag. Neighbouring rows are out of phase, and each tuft is turned ±6°, leans ±4° and varies ±0.45 in height.
   - From the street the crop top is a band of spikes; from 50° it is rows of lit and shaded gold facets over dark soil strips. There are no flat-topped crop parts left.
   - Crop top: L1 3.5–4.6, L2 4.9–6.0.
2. **Values.** The value ladder runs dark soil < roof < ochre bed < saturated gold tufts, and it holds in the grayscale check.
   - Soil 104,74,46 → 74,52,34.
   - Tufts 244,182,30 / 252,204,58 / 230,156,22 (saturation ≥ 0.75).
   - The farm cottage moved from thatch to a dark shingle tile roof (104,80,64). This also gives it a crisp gable unlike the house v2 thatch.
   - Stubble 196,164,96.
3. **L1 outline.** The haystack moved from behind the cottage to the front-left corner of the field, on the stubble strip, 6 studs tall. The stooks moved right of it. From the front, L1 now reads as haystack | field | cottage.
4. **L2 barn.** It is narrower (10.4) and moved forward on the left edge: walls now z −5…7, previously 2.6…14.6.
   - It stands ≥ 10 studs to the side of the cottage, and its front is no deeper than the cottage's back.
   - A 3.5-stud bare threshing apron lies in front of its doors.
   - Its ridge is 21.5, against 17.9 for the cottage.
5. **Budget.** `PART_BUDGET.farm` is 190 → 200, justified in the `Buildings.luau` header. Farms are 3 per VS-2 kingdom, so the raise costs ≤ 120 parts across 4 kingdoms; the measured world stays ≈ 17.0k of the 25k budget.

**Part counts, round 6 → round 7** (budget 200):

| colour | L1 | L2 |
|---|---|---|
| crimson | 164 → 179 | 184 → 192 |
| azure | 166 → 181 | 186 → 194 |
| emerald | 167 → 182 | 187 → 195 |
| gold | 165 → 180 | 185 → 193 |
| neutral | 161 → 176 | 181 → 189 |
| emerald off-palette 40,127,71 | 167 → 182 | 187 → 195 |
| gold off-palette 245,205,48 | 165 → 180 | 185 → 193 |

- **L2 (emerald):**
  - Wheat 40 → 51: 9 beds and 42 tufts, replacing 10 beds and 30 ear blocks.
  - The thatch roof (17) became a tile roof (15).
  - One field slab was dropped.
- **L1 (emerald):** wheat 32 → 49 (7 beds and 42 tufts), and the roof is 2 parts cheaper.

**Author rounds** (quick renders, then a street view at 60 studs and 12°, and aerials at 50°):
1. **Tufts 4.4 long, 66 % of the pitch, barn at z 4.5.**
   - Values separated at once.
   - The crop read as a spiky gold field, but the tufts were long low ramps (shark fins) rather than upright.
   - The gameplay strip at 10-stud spacing cropped farm L2 at the frame edge.
2. **Tufts 3.4 long and 3.6 tall at L2, 56 % of the pitch; barn moved forward to z 1; strip widened.**
   - The strip now keeps the same 70° vertical FOV, widened to 2.09:1 so every model fits at the 90-stud cap. It is a scratch copy of `render_kit.py`; the `forge/02-blender` version has a 6-stud gap and a fixed 16:9 strip.
   - The barn's doors and body now read beside the cottage in the strip. The cottage eave still touches the barn roof's lower-left corner in that oblique view.

Final renders: 420 px and 28 samples for the sheet; 1920×1080 and 32 samples for the aerial.

**Images** (`img/`; total across the five FL-0085 images is 777 KB):
- `kit_levels_house_farm.jpg` (152 KB, re-rendered): house L1–2 and farm L1–2 azure. The gameplay strip is ~90 studs at 70° vertical FOV, 2.09:1, with models 10 studs apart.
- `kit_levels_farm_aerial.jpg` (192 KB, new): farm L1 and L2 in emerald (on green ground) and gold. Panels:
  - 1:1 crops of 1920×1080 renders at 50° pitch and 140 studs, from the front (azimuth 0) and from behind (azimuth 180, so the order is reversed);
  - a 2× zoom of the front for detail.
- Unchanged: `kit_levels_keep.jpg`, `kit_levels_barracks.jpg`, `kit_throne.jpg`.

**Author verdict at gameplay distance** (not the D-019 score; a fresh-context reviewer scores the images):
- **Strip:**
  - Farm L1 now has its own outline: a dark-roofed cottage, a bristly gold field, a haystack and stooks.
  - Farm L2 is wider and taller, with a kingdom-roofed barn showing its doors and hayloft beside the cottage.
- **Grayscale:** the dark roof, the bright crop and the dark furrows separate.
- **Aerial:** the crop reads as rows of gold tufts over dark furrows, and the L2 barn roof is the strongest element in both kingdoms.
- **Weak points:**
  - In the hero view the tufts are big flat-faced facets. They read as stylised crop but could still be called "gold paper".
  - The emerald L2 barn roof is the same green family as the ground.
  - In the oblique strip the cottage eave still overlaps a corner of the barn roof.

**Spec:** the farm block of `KitBuildings.spec` was rewritten as 3 tests over 7 colours.
- **Rows:** ≥ 7 rows at L1 and ≥ 9 at L2, each along Z; bed furrows ≥ 0.9, and no tuft closes its furrow; ≥ 2 tufts per row. Each tuft is an upright `CornerWedgePart` (taller than wide, up-vector > 0.99) rising ≥ 1.5 over its bed. Apexes alternate along the row, and tuft tops range ≥ 0.5.
- **Values:** tuft saturation > 0.75; tuft L\* > soil + 40 and > cottage roof + 25.
- **Levels:**
  - L1's haystack sits in the front half, ≥ 5 studs left of the cottage.
  - L2 has more rows than L1, and tufts ≥ 0.8 taller.
  - The barn exists at L2 only. Its ridge is ≥ 1 over the cottage ridge.
  - The barn stands ≥ 10 studs to the side of the cottage, and its front is ≤ 2 behind the cottage's back wall.

All 17 mutations were caught:
- rows along X;
- beds or tufts closing the furrows;
- tufts as flat blocks;
- no zigzag;
- tufts lying over;
- stubby tufts;
- uniform heights;
- tan tufts;
- light soil;
- a thatch-value roof;
- the haystack behind the cottage;
- the barn deep at the back;
- the same row count at L1 and L2;
- an L2 crop that is not taller;
- no barn;
- a low barn.

`KitBuildingsDump.spec` gains the `levels_farm` group (farm L1–L2 in emerald and gold, 37 → 41 models); a mutation dropping gold fails its count.

**Unverified:**
- Studio's Grass material on the tufts and how CornerWedge facets shade under Future lighting.
- Phone screens.
- The real aerial azimuth relative to each farm.
