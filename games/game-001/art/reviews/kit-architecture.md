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
