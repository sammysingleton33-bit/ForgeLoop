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

## Round: world dressing trim and plot clearance (FL-0116, D-047 amendment; D-019 renders; four author rounds)

**What changed** (`WorldPlan`, `world/Layout`, `WorldService`; buildings, nodes, tags and gameplay untouched):
- **Density knob** `world/Layout` `features.density = { forest = 0.75, props = 0.5 }` (share kept). `WorldPlan.FULL_DENSITY`
  (1 / 1) and `service.density` override it. 1.0 rebuilds the untrimmed valley exactly (pinned in `WorldService.spec`).
- **Plot showcase, never thinned:** within 60 studs of a plot's crop fields, starting buildings and build slots, plus the
  farm's view (190 studs behind the keep, 100 to either side: where the aerial and plot-back-edge cameras look from).
  Scatter props (lone trees, bushes, rocks, flowers) also keep the plot framing, road bands and the heartland.
- **Forests thin radially, stand by stand:** a stand with more than 25 % of its trees in the showcase, or on average within
  15 studs of what the cameras look at, stays whole; the others lose up to 40 %, outermost trees first, all around, so
  what stays is centred. Each thinned stand's ground disc (terrain `forest_floor`, `WorldPlan.forestFloors`) is the smaller of
  the circle around the kept trees' centroid and around the stand centre, plus the same 5 % pad (one op per stand;
  untouched stands keep today's disc exactly).
- **Plot clearance** (`PlotClearance.spec`, a guard): no tree, bush, rock, flower or prop within 4 studs of a field, a starting
  building's largest footprint, a slot, a build zone or a road, measured with each prop's live `Kit.prop` bounds. Blocked
  trees, bushes and flowers move to the nearest legal spot within 12 studs instead of going; boulders against a trunk or bush
  go. Hand-placed dressing that sits inside a building, slot or field (the crate stack beside the storehouse) moves too.
  The gate banners are exempt: they flank the road by design and stay exactly where the generator puts them.

**Parts** (WorldService at ready, `MockEnv` seed 1): 8,412 on main d78d9cb -> 8,328 at density 1.0 on current main (env-polish props
and relocated decor included) -> 6,569 (trim). Forests 3,853 -> 3,184 (222 -> 184 trees, -17 %; only the four far stands
thin), lone trees 848 -> 527, bushes 905 -> 475, rocks 685 -> 346; flowers (279) and kingdom dressing untouched.

**Images** (`img/`, Cycles 32 samples, Roblox 70 deg FOV; both sides rendered on the same current props: before = the generator's
untrimmed plan, `FORGE_WORLD_UNTRIMMED=1`, after = this branch):
- `world_trim_aerial_plot_*`: crimson plot, 50 deg, 170 studs. `world_trim_throne_*`: eye height at the keep door, looking out.
- `world_trim_aerial_valley_*`: valley centre, 50 deg, 170 studs. `world_trim_top_*`: whole valley from above.
- `world_trim_farm_aerial_*`, `world_trim_farm_ground_*`: gold's starting farm from the air and from the plot's back edge.

**Verdict, looked at by FORGE-02** (round 3):
- Farm views: the foreground is back (the oak that stood against the cabbage field is moved clear, the pines behind the fields stay);
  the right half of the farm aerial was empty grass in the untrimmed plan too.
- Plot and throne views: the gate banners are exactly where "before" has them (spec-pinned to the generator's positions).
- Top view: the four far stands are lighter and their dark discs follow them; the stands near the plots and the mid-valley
  stands are unchanged.
- Known and by design: the plot-facing rim trees of one thinned stand (at the right edge of the plot aerial) are gone. Keeping them
  would hold that stand's disc at full size, which was the worse defect. The dark patch at the right edge is the shadow of the tree
  at the frame edge, in both versions.

**Unverified:** Studio (real mesh bounds against `WorldPlan.CLEAR.radius`, StreamingEnabled, phone frame rate); a phone test decides
whether the knob goes back up. The render uses the world dump, which has no sim-generated nodes.

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

**Wheat tufts withdrawn from PR #151 (FORGE-05, D-051 (a)).** FORGE-05 opened `env_polish_r2_wheat.jpg` and judged the 6 x 7 tufts not *clearly* better than #141's
slabs (tiles or crates in a checker at gameplay and aerial distance; the slabs at least read as rows) for about 27 more parts per field. Commit `926edd5` is reverted on
this branch (`5bc05cb`), so the wheat field is #141's 17-part slabs again and `Props.WHEAT_PARTS` / the wheat specs are back to #141's. The tuft work is kept as-is on
branch `forge/02-blender-env-wheat` (head `3138825`) for a later FL-0117 wheat PR with another approach (FORGE-05's suggestion: rows of thin tapered blades along furrows, as
in the cabbage bed; the reviewer's thin close-packed stalk clusters). The 44-part allowance (D-047 amendment) stays available; that PR needs FL-0116's measured headroom first. The wheat images above
stay as the record of what was tried.

## FL-0124 — world resource nodes out of the farms (D-052 (4); the user's first-playtest complaint)

The sim's own nodes were cleared by FORGE-01 (#131, #152). The grey rocks and berry bushes still standing on the starting farms were the 20 per-plot **world**
resource nodes (`world/Layout.luau` `addNode`, drawn by WorldService as Kit models): `<k>_stone1/2` on crop field 3 of each plot, `<k>_gold1` on build slot 10,
`<k>_food1/2` inside the east build zone, plus `<k>_wood2` whose canopy covered the lumber camp (18 studs from it).

**Rule (tests/world/NodeKeepOut.spec.luau):** every world node's *drawn* extent — the horizontal reach of what `Kit.prop(assetId)` really draws around its pivot
(stone 9.6, ore 7.0, bush 3.6, trees 8.5-12.6), measured live, not the sim footprint or a guessed radius — stays at least 8 studs off every crop field, build zone and
build slot of every plot, and at least 5 studs off every starting building's footprint (the real `Kit.footprint` at the largest level, turned with the building). The first
version of this fix used 4 studs and a 12-stud building circle; a fresh image-only review saw rocks butting into the quarry wall and a tree cluster crowding a build rectangle, so the buffers
were raised and the buildings became real footprints. The areas come from the world layout turned with the plot as FORGE-01's LayoutZones spec reads
them; TODO: read them from FORGE-01's `Kingdom/Layout.keepOutAreas()` once it is on main (no second copy of the geometry). The plots stay rotated copies of each other
(per-kingdom fairness, #94): the spec compares each kingdom's nodes to crimson's in the keep frame. The WorldPlan decor (deterministic, no seed) is checked against the crop fields by
drawn extent as well. The sim's generated nodes are seed-dependent and are FORGE-01's LayoutZones spec (seeds 1..20); the world layout has nothing to loop seeds over.

**Moved, not deleted** (keep-frame offsets, x/z; the same in all four plots): stone1 (70,66) → (40,28); stone2 (40,72) → (80,60); gold1 (90,40) → (70,34);
food1 (74,−44) → (40,−24); food2 (70,−32) → (74,14); wood2 (−66,58) → (−66,74) (its canopy covered the lumber camp); wood4 (−38,58) → (−42,58) (too close to the first crop field).
The stone and ore form an arc around the quarry building (north-west, north-east, east), the berries flank the farm building; every node is also >= 0.6 x its reach + 3 studs off every nav edge (no rock
on a walking path) and clear of its neighbours. Found with a Lune solver over the live geometry (grid step 2, nearest legal spot to the node's natural anchor, greedy), starting from FORGE-01's
checked candidates. The node ids, resources, amounts and nav links are unchanged.

**Evidence:** NodeKeepOut.spec 8 tests; Layout.luau mutations killed (round 1: stone2 back in field 3, berries back in the zone, gold back on slot 10, wood2 back over the camp, stone1 nudged
onto field 3's corner, one kingdom's berry offset different, a node deleted; round 2 at the stricter gaps: stone beside the quarry wall, berries at the farm wall, wood4 at its old spot, gold on the quarry corner);
a stone nudged 10 studs toward the field survived correctly in round 1: it was still legal at 4 studs. Renders (Blender, not Studio): `fl0124_farmside_{crimson,azure,emerald,gold}_{before,after}.jpg`
(55 degrees from behind the farm, 210 studs): before, every plot has a rock pile on or touching its right-hand wheat field; after, the three fields and every build rectangle are clean with a visible buffer.

**Fresh image-only review (reviewer saw only the eight renders; strict):** round 1 (4-stud buffers) — crop beds clear but "buffer thin": rocks butting the quarry wall, the lumber-camp trees under half a tree-width
from a build rectangle → buffers raised to 8 / 5 studs and the buildings became real footprints. Round 2 (this head) — nothing stands on or touches a crop bed or build rectangle from the world nodes in any of the
four kingdoms, nothing butts into the quarry or the farm building, no new defect, the four plots are identical copies. Remaining, honestly: (a) two **terrain-scatter** trees (WorldPlan decor, not nodes) touch a plot corner in these renders
(crimson at the right build rectangle's corner, gold at the cabbage bed's corner): the decor clearance of FL-0116 (PR #159, which this branch does not contain) moves them; the two PRs together are the whole fix;
(b) the lumber-camp trees stand about one tree-width from the left build rectangle (the forest edge behind the camp, by design; the spec guarantees ≥ 8 studs); (c) the lumber camp "overlapping" that rectangle in
the render is perspective: the starting buildings' footprints at both levels overlap no slot and no field (probe). Verdict by the reviewer: farms clean **no** (a, b); by the spec and the author's reading of the renders: the world nodes are out. Studio unverified.

## FL-0127 part 1 — three neutral outposts (Operation Crownfall, D-053)

`world/Layout.luau` gains `outpost_n` (40, −330), `outpost_s` (30, 315) and `outpost_w` (−430, 10) next to the watchtower: capture points of radius
20, each with a neutral region, a nav node linked into the road network, and a dirt road spur (flagged `spur`). FORGE-01's FL-0126 gives them config rows and
builds their neutral towers. Placement: north and south on the valley's north and south edges between the two kingdoms of each side, the west one on the
west bank to balance the river the two western kingdoms must cross for the watchtower; every kingdom has a neutral objective 330–365 studs away. All clear
of forest stands, hills, the river and plots (`Outposts.spec`). The world trim protects only 70 studs around an outpost and a 20-stud band around a spur
(`TRIM.outpostRadius`, `TRIM.spurBand`): protecting each like the heartland (170) cost +631 parts; the trimmed world is 6,570 (was 6,569). Details and
numbers in `production/handoffs/2026-10-18-forge-02-to-forge-01-fl0127-outposts.md`.

Renders (Blender, not Studio; the world dump now places a neutral tower at every objective): `fl0127_world_top.jpg` (the whole valley, the top view is mirrored east-west by the
preview's axes: the river is on the right) and `fl0127_outpost_{n,s,w}.jpg` (each outpost from the valley-centre side, 45 degrees, 170 studs). I looked at the top view and the
west outpost: each outpost stands at the end of its spur on open meadow with the mountain ring behind, clear of forest stands. Honest: a lone tower on empty meadow is plain;
outpost yard dressing (banners, crates, a fence, tied to the kingdom style table) belongs to FL-0127 part 2.

## FL-0127 part 2A — per-kingdom architecture styles (Operation Crownfall)
Author: FORGE-02. `Kit/KingdomStyle.luau` (one table per hue style, consulted by `Pieces` through `ctx.style` and applied to the
neutral palette once at the end of `Kit.build`). Renders are Blender approximations of the part dumps (no Roblox material
textures, no Future lighting), the camera of `RulerCameraController` for the overview views (170 studs, 50 deg down) and a
30 deg gameplay view. In every image the kingdoms run left to right Sunspire (gold), Thornwood (emerald), Frostmere (azure),
Emberhold (crimson). Part counts are printed on each row: BEFORE (main) and AFTER are identical for every model.

Images (`img/`): `kit_fl0127_keeps.jpg` (the four keeps at gameplay and overview distance), `kit_fl0127_plots_aerial.jpg` (four
small bases from the overview camera), `kit_fl0127_grid_aerial.jpg` (types x kingdoms from the overview camera),
`kit_fl0127_rows_a.jpg` (house, farm, barracks) and `kit_fl0127_rows_b.jpg` (lumber camp, quarry, watchtower), each before / after.

What changed (colour value, material, proportion; never a part): dark basalt stone and steep tight red roofs (Emberhold), pale
cool stone and slate-blue roofs with a snow course and ridge (Frostmere), mossy stone, ochre daub, dark oak framing and
moss-striped green roofs (Thornwood), sandstone, whitewash and low gold roofs with a terracotta ridge (Sunspire); per-kingdom
thatch and crop colours, merlon proportions, banner tails (diamond / pennon wedge / half disc), plinth accent stones.
The stone L* values are 41 / 82 / 54 / 71, so the value order also separates the kingdoms for colour-blind players, on top of
the unchanged tower caps and emblems.

D-019 status: self-review only. The fresh-context image-only review was not run (the worker has no subagent tool); the images above
are the evidence for it. My own reading, not a score: keeps, barracks, houses, watchtowers and farms read as four places;
the lumber camp changes least (a lean-to roof, wood tones; the storehouse and the VS-2 stand-ins were not rendered); Emberhold's
dark stone lowers the contrast of the dark windows and slits; Frostmere's frosted thatch reads close to white. Studio materials (Slate, ClayRoofTiles, Grass for
moss) are unchecked.

## FL-0128 — the war kit: walls, gates, war-ready tower, ram, soldier kinds, damage states (Operation Crownfall)
Author: FORGE-02. Part-built (D-026), all kingdom-tinted through `KingdomStyle`. Renders are Blender Cycles approximations of
the Lune part dumps (no Roblox material textures, no Future lighting). Close rows are shot front on (azimuth 0) with a narrow
field of view and the four kingdoms on one line across the view, so every piece in a sheet has the same scale and nothing
recedes in depth or is cropped; the 170-stud sheets use the game's camera (170 studs, 50 deg down, 70 deg field of view) at
1:1 pixels. In the close rows the kingdoms run left to right Emberhold (crimson), Frostmere (azure), Thornwood (emerald),
Sunspire (gold); in the damage rows Damage runs 0 / 0.3 / 0.6 / 0.9 left to right. Nothing here was seen in Studio.

Images (`img/`): close, equal scale: `kit_fl0128_walls.jpg` (wall L1-3), `kit_fl0128_gates.jpg` (gate L1-3 closed and open),
`kit_fl0128_tower_ram.jpg` (watchtower L1 and L2; the ram from the side, 3/4, thrust 1, front), `kit_fl0128_units.jpg` (soldier, knight,
archer, front and 3/4), `kit_fl0128_damage.jpg` (wall, tower, gate, house, keep) and `kit_fl0128_damage_kingdoms.jpg` (wall and gate in
pale Frostmere stone). At 170 studs: `kit_fl0128_damage_170.jpg` (wall, gate, tower, house, keep at 0 / 0.3 / 0.6 / 0.9),
`kit_fl0128_towers_170.jpg` (plain L1 against war-ready L2), `kit_fl0128_walls_170.jpg` (wall L1 / L2 / L3), `kit_fl0128_gates_open_170.jpg`
(gate L1 / L2 / L3 open), `kit_fl0128_units_170.jpg` (true scale, not enlarged: units and ram, rendered at 4K and shown 1:1 and as a
1080p screen would show it) and `kit_fl0128_before_after_170.jpg` (what origin/main shows today, against this branch, for the walls,
the gate, the towers and the keep, two kingdoms, same camera).

Part counts (Kit.partCount, all four kingdoms): wall L1 / L2 / L3 26-30 / 36-40 / 52-60 (caps 30 / 45 / 60), gate 72-77 /
102-113 / 120-131 (caps 90 / 120 / 150), watchtower L1 107-116 and L2 105-122 (cap 130), ram 37-42 (cap 45), soldier / knight /
archer 11 with the crest (cap 11), damage at most 14 extra parts and none at Damage 0. All-built worst case (D-047): 26,322 of
27,000 (`tests/world/KitCeiling.spec.luau`: WorldService 6,869 + four kingdoms 19,117 + three neutral towers 336).

What was built:
- **Wall:** L1 timber palisade (the same dark timber in every kingdom), L2 crenellated stone curtain on a batter with a banner and
  slits, L3 its own outline: end piers with slits a tier above the walkway, two stepped buttresses beside them, two wider banners, a
  big brazier on a plinth that rests on the walkway. Footprint 32 x 8 as before.
- **Gate:** two towers and a pointed arch whose span reaches the tower tops, arch stones flush on its face, a recessed tympanum over the
  leaves (all three levels; at L3 it sits behind the portcullis bars), timber leaves (L1), banded leaves, tower banners and a crest (L2),
  a portcullis and two braziers at the foot (L3), a MID-tone passage floor in every kingdom (sand or earth, never near-black). `Kit.setGateOpen` swings
  the leaves 65 degrees into the passage (both visible, the middle clear) and raises the portcullis 7 studs into the lintel, by CFrame
  only. Footprint 32 x 12 as before.
- **Watchtower L2:** hoarding galleries under the parapet, arrow slits instead of arched windows, two braziers at the door.
- **Ram:** the pale log with its iron wedge head is the silhouette, projecting 7 studs past a low open-sided pent roof in the kingdom
  colour on four posts and four wheels; one `Motor6D "Log"`.
- **Soldier kinds:** spear (1.3x the body's height, carried at the fist) with a hanging pennant / bulky knight, sword rising outward from the
  fist, large kingdom-coloured shield with a flat light emblem, broad helm and a bigger crest / archer with a round head and a short curved
  three-part bow with a string held below the chin.
- **Damage:** a bite of merlons or roof tiles gone from 0.25, a gate leaf knocked out (and a broken leaf left standing at 0.75 and above),
  broken stone on the front face (a shadowed recess in the wall's own stone, a hairline crack, pale stone chips round the rim: no black,
  nothing overhanging), bigger rubble, from 0.75 the collapsed corner top (a tower cap falls whole or not at all) with a stump slab.
  No translucent smoke.

Specs (headless): `KitWarKit.spec` (levels, wall L3 outline and brazier seat, gate shape, gate poses incl. both open leaves in view and
the raised portcullis, tower, ram shape, mutants), `KitUnitKinds.spec` (kinds, pose clearance, silhouettes, mutants), `KitDamage.spec`
(states, real geometry loss, determinism, repair, Burning, recolour, mutants), `KitCeiling.spec`; `KitBuildings`, `KitEmblems`,
`KitStyles`, `KitCharacter` extended for the new levels and kinds.

D-019 history: round 1 (first author pass) was scored NEEDS-WORK by a fresh image-only reviewer for every family (walls 3/3/3, gates
4/3/3, tower L2 4/3/3, ram 2/2/2, soldier kinds 3/3/3, damage 3/3/3: silhouette / variation / readability), with defects: a brazier in a
merlon gap, a missing open leaf, portcullis bars hanging in the open gap, a floating A-frame over the gate door and a saddle span, a black
shield disc, translucent smoke balls through roofs, jutting crack shards, a 2.5x spear beside the body and floating swords, a cannon-like
plume, a ball on a box. This is the ONE fix round: all of the above were addressed (see the handoff and the list below); the
coordinator runs the second fresh review. My own reading of the new sheets, not a score:
- walls: L1 timber, L2 stone and L3 (piers, buttresses, brazier on top) separate by outline in the close rows and at 170 studs;
- gates: open against closed reads at 170 studs (two brown leaves inside the arch, a light floor, the portcullis gone); closed L3 shows the grille;
- ram: the pale log with a dark wedge head is the silhouette from the side, the 3/4 and the front, and at 170 studs; it still carries a
  cannon-like reading from the side for a moment because the log is thick and its head is dark;
- soldier kinds: knight against soldier is clear at close range (width, shield, helm, crest); at 170 studs the unit is about 25-40 pixels
  tall and the knight's shield and width still show, the archer reads as a smaller brown figure, but the weapons do not;
- damage: at 0.3 a wall, a gate (one leaf gone), a house (roof tiles) and a tower (the front merlons and soot) are visibly different from 0
  at 170 studs; the keep at 0.3 is still almost identical to 0 (cracks on the donjon only);
- weak: the sword is still a plain slab at the fist, soot streaks are plain rectangles, the ram head reads as a drill bit from some
  angles, tower L2 against L1 at 170 studs is mostly the braziers and the gallery shadow, Thornwood's watchtower L2 has fewer parts
  than its L1 (its hoarded roofs replace merlons).

### FL-0128 defect-only round (after the second fresh review)
Author: FORGE-02. Scope fixed by FORGE-00: defects only, no new features, no score chasing. Every image below was opened and judged by
me; headless evidence only (Lune specs, Blender Cycles previews of Lune dumps), Studio unverified. New or changed sheets (`img/`):
`kit_fl0128_walls.jpg`, `kit_fl0128_gates.jpg`, `kit_fl0128_units.jpg`, `kit_fl0128_damage.jpg`, `kit_fl0128_damage_kingdoms.jpg` (wall,
gate in all four kingdoms, Frostmere tower), all close, front on, equal scale; `kit_fl0128_damage_170.jpg`, `kit_fl0128_walls_170.jpg`,
`kit_fl0128_units_170.jpg`, and `kit_fl0128_gates_open_170.jpg` (now with the closed-against-open pair for all four kingdoms at 170 studs).
Unchanged: `kit_fl0128_tower_ram.jpg`, `kit_fl0128_towers_170.jpg`, `kit_fl0128_before_after_170.jpg` (the tower caps look the same whole).

| # | Defect | Result | What I saw |
|---|---|---|---|
| 1 | Gate L1/L2 closed shows grass through a triangular gap | fixed | a recessed stone tympanum fills the point of the arch in all four kingdoms; no sky (a spec samples the arch) |
| 1 | Open gate tan-on-tan on Frostmere and Sunspire | fixed | dark earth floor on the three lighter stones, light sand on Emberhold; the closed-against-open pair reads at 170 studs in all four (the spec pins a value gap of 0.22 or more to the wall) |
| 2 | Black rectangles and slash cracks on wall, tower, gate | fixed | lit dark browns in Slate (every channel above 40 / 255, a spec), pale chips of broken stone beside them; on pale Frostmere stone they are still strong dark patches |
| 3 | Tower cone floats over the flattened platform | fixed | a stone seat under the cap; no ring or gap at 0.3 to 0.9 (a spec walks the tower axis for a gap) |
| 3 | Gate: right roof changes shape or rotation | partly | no half or turned roof any more (a cap falls whole or not at all); at 0.3 and 0.6 the bite starts mid-span and alternates sides; at 0.75 and above the corner tower loses its merlon ring on purpose, so its roof base shows wider, seated and un-rotated |
| 4 | Gate at 0.9 loses both leaves, reads open | fixed | one broken leaf (a short board at the hinge) stays at 0.75 and above, shut or open; small at 170 studs |
| 5 | Sword crosses arm and torso, not in a hand | partly | rises from the fist outward and forward, clear of the torso; from the 3/4 view it still passes in front of the lower arm |
| 5 | Spear floats beside the head; pennant a thin stick | fixed for the grip and the pennant | carried at the fist, butt off the ground, leaning; the pennant hangs under the head; the head still stands beside the helm |
| 5 | Thornwood shield boss a glossy sphere | fixed | a flat slanted bar, the same metal as the other marks (a spec forbids round marks) |
| 5 | Thornwood archer's bow crosses the face | fixed | a short bow held below the chin (a spec) |
| 6 | Wall L3 buttresses read as pickets | fixed | two stepped buttresses beside the end piers, three courses each, each narrower and shallower than the one below |
| 6 | L1 palisade grey on Frostmere | fixed | the same dark timber in all four (a spec compares the colours); the banner carries the kingdom |
| - | Tall grey slab beside the damaged house | not mine | it is the house's own gable wall (`Gable`, base geometry on main), visible once the roof tiles are gone; left alone |

Not chased (per FORGE-00): units at 170 studs, tower L2 against L1 at 170, keep damage at 0.3, the ram at 170. The all-built worst case
grew from 26,217 to 26,322 (the tympanum, the tower seats and the wall L3 courses), under the 27,000 ceiling (not a 26,900 pin: see the errata handoff).

### FL-0128 defects round B (after the "any visible defects?" review; branch `forge/02-blender-fl0128-defects`, stacked on the war branch)
Author: FORGE-02. Scope fixed by FORGE-00: three items only (breach marks, gate L3 closed, open-gate floor). Every image below was opened
and judged by me; headless evidence only (Lune specs, Blender Cycles previews of Lune dumps), Studio unverified. Re-rendered sheets
(`img/`): `kit_fl0128_gates.jpg`, `kit_fl0128_damage.jpg`, `kit_fl0128_damage_kingdoms.jpg`, `kit_fl0128_damage_170.jpg`,
`kit_fl0128_gates_open_170.jpg`, `kit_fl0128_before_after_170.jpg` (its gate is L1 closed; only the render was refreshed), equal scale, nothing cropped.

| # | Defect | Result | What I saw |
|---|---|---|---|
| 1 | Breach marks read as stickers or holes | fixed at close range, subtle at 170 | no black and no nail-like stick: a recess in the wall's own stone at 0.64 of its value, a hairline crack at 0.8 of it, 2 to 5 stone chips at 1.25 of it round the rim; all on the front face, inside the wall block's face outline in x and y and standing proud of the face by about 0.015 to 0.46 studs (FORGE-00's measure; the spec pins x, y and the front face, not that depth), so no silhouette is overhung sideways or above (a spec). At 170 studs the marks are small, pale-edged notches, not dark patches; on Frostmere and Sunspire they are no longer strong dark patches. Caveat: the recess is still a flat rectangle with sharp corners, the chips are what break its outline |
| 2 | Gate L3 closed shows grass between the portcullis bars | fixed | a dark stone panel (the tympanum, now at every level) sits just behind the bars (bars at z = -d/2 + 0.8, panel at -d/2 + 1.35, inside the lintel's depth, so the raised-bar rule holds); in all four kingdoms the grille reads dark on dark with the leaves below it, no grass. The closed-arch sampling spec now covers L3 |
| 3 | Open-gate floor near-black (Frostmere, Thornwood, Sunspire) reads as a void at 170 | fixed | every kingdom gets a MID-tone floor: sand (160,144,118) on the darkest stone, earth (112,98,84) or dark earth (96,84,72) on the rest, luminance 0.34 to 0.57, at least 0.15 from the wall (a spec). The closed-against-open pair and the open row at 170 read as a floor under the arch in all four kingdoms; the passage still shades darker towards its back, as an interior does |

Rule change in `KitDamage.spec`: marks no longer have to be "dark" (the old rule pinned lit dark browns). The rule is now: a breach mark
stays within a band of the wall's own value (breach 0.5 to 0.9 of the supporting wall's luminance, crack 0.65 to 0.92, chip 1.05 to 1.6 or
within 0.06 of it), luminance at least 0.1 and not Neon, lies inside a wall block's face outline (x and y) on the front face, standing proud of it by about 0.015 to 0.46 studs, and the shapes are thin boxes.
Mutants killed (KitDamage): a translucent breach, a pure black breach, a dark-brown sticker at a third of the wall's value, black cracks, a
Neon breach, a thick dark stick for a crack, no chips, chips as dark as the recess, a breach overhanging the wall's edge, a breach turned
onto the side face. KitWarKit: no tympanum at the closed L1/L2 arch, no panel behind the L3 bars, a near-black, white or wall-valued floor.

Numbers: parts per piece unchanged except the L3 gate, +1 for the tympanum (gate L1 72-77, L2 102-113, L3 121-132 against the 90 / 120 /
150 caps; wall 26-30 / 36-40 / 52-60; watchtower L1 107-116, L2 105-122); the breach, crack and chip marks add 4 / 6 / 8 / 9 parts at state 1 to 4 (12 with rubble at state 4) within the 14
extra-part budget. All-built worst case 26,326 of 27,000 (it was 26,322; the four L3 tympana), under the 27,000 ceiling.
Not chased (per FORGE-00): shield and bow grip (FL-0135), keep damage, framing, units at 170, tower L2 against L1, the ram at 170.

### FL-0128 damage frames (P1 before FL-0143 makes damage live; branch `forge/02-blender-damage-frames`, stacked on defects round B)
Author: FORGE-02. FORGE-00's list: `Kit/Damage.luau` worked on world axes and absolute CFrames, all dormant until `Kit.applyDamage` is called
on placed buildings (FL-0143). Headless evidence only (Lune specs, Blender Cycles previews of Lune dumps); Studio unverified. I opened every
re-rendered sheet (`img/`): `kit_fl0128_damage.jpg`, `kit_fl0128_damage_kingdoms.jpg`, `kit_fl0128_damage_170.jpg` (same cameras and scale as
before) and the new `kit_fl0128_damage_frames.jpg` (the L1 palisade at 0 / 0.3 / 0.6 / 0.9 / 0.97 in two kingdoms; a wall L2 and a gate L2 built
turned 0 / 90 / 180 / 270 degrees).

| # | Defect | Result | Evidence |
|---|---|---|---|
| a | world axes: a turned building was damaged on its back, the parts lost changed with its position | fixed | everything is chosen in the model's own frame (the pivot) and turned into world CFrames only when a part is made; spec "frames": every wall and gate level in the four kingdoms, every state, built turned 90 / 180 (and 270 for the footprint) at another height and place: part for part the damage of the model at the origin (tolerance 0.002, CFrames are 32-bit floats) |
| b | removed parts stashed at absolute CFrames: a move left them behind | fixed | stored relative to the PrimaryPart, restored at its CFrame as it is then (untouched, bit for bit, when the model has not moved); gate leaves and bands return in the gate's current pose; spec: damaged, moved to a new place AND yaw, repaired = a pristine copy moved the same way, every part (world CFrames), none doubled, none parked; then damaged again at another state = a pristine moved copy damaged at that state |
| c | rubble at world y = size / 2 - 0.2 | fixed | stands on the model's base plane (y = 0 of its frame); spec: a model at y 40 and y 3.5 has the rubble bottom at base - 0.2 |
| d | L1 palisade: every mark on the -X post, soot overhanging it and above the top | fixed | no wall block exists there, so the marks are spread (a stride across the standing logs and the two posts) over at least two logs / posts at every state, each narrower than its support, wholly inside it and below its top (spec, four kingdoms, states 1..4); wood marks on wood |
| - | `KitLevel` stored the level asked for (a wall asked for at level 5 stored 5, and the damage was seeded by it) | fixed | `Kit.build` clamps to `Kit.MAX_LEVEL[type]` and stores/names the clamped level; Kit.spec and KitDamage pin it, with mutants |
| - | (FORGE-00 addition) re-dressing a turned model dropped rubble outside the keep's footprint | fixed | spec: keep L1..L3, wall, gate, watchtower, house re-dressed at seven states turned 90 / 180 / 270: every damage part inside the footprint in the Root's frame; rubble may reach 2 studs in front of it (the Kit's own entrance-step allowance: strictly inside would hide it in most buildings); the keep's stump is shrunk to fit |

What changed for the eye, compared with the previous sheets (same cameras). I dumped every damaged variant (every type at every level, four
kingdoms, four states: 592) with the old and the new code. 96 are the stand-ins' second level, which no longer exists (they are level 1: the
same damage as their level 1, bit for bit). Of the other 496: 115 are identical, bit for bit; 331 differ only in where the rubble lies (it is
now up to 2 studs in front of the footprint instead of up to 5.6: closer to the foot, partly against the wall); 50 differ otherwise: the 16 L1
palisade variants (marks on logs and posts), 30 watchtower L1 / L2 and storehouse L1 variants where the bite or the marks pick another of two
equally distant parts (those ties were decided by float noise of 1e-6 before and are decided by the part order now) and the 4 keep L1
variants whose stump slab is shrunk to fit its footprint. On the re-rendered sheets the walls, gates, houses, towers and the keep read as
before; the 0.3 / 0.6 / 0.9 marks, bites and collapsed corners are where they were except in those 50 variants (the sheets show two
of them: the Frostmere watchtower L2's bite at 0.3 / 0.6 / 0.9 takes another of two equally distant merlons, the Emberhold one's chips at 0.6
lie elsewhere on the face; the rest is unchanged).

Not done here: the order the damage walks a model's parts in is now the part attribute `KitOrder`, written once by `Kit.build`; a model
built by anything else, or a part re-formed by a recolour, is ordered by position (robust except at a rounding edge). The ceiling is
unchanged (26,326 of 27,000: no part was added); farms are built at level 2 by the ceiling spec (level 3: +3 parts each).

## FL-0072 — Crown Arena venue, crowd figures, armour and weapons (G12.6; FORGE-02; Blender previews, not Studio)

**Built** (`Kit/Arena.luau`, `Kit/Crowd.luau`, `Kit/Gear.luau`, `Kit.luau` exports, `world/Layout.luau` `arena`, `WorldPlan` keep-out and trim protection, `WorldService` places the neutral `CrownArena`):
`Kit.arena(colorA?, colorB?)` is a warm-travertine venue 75 x 74 studs with a painted duel ring (radius 21), two facing stands of four rows (72 seat attachments each, `StandA_Row<r>_Seat<s>`; the design caps a stand at 60 figures), royal tribunes with
banner-ready fronts, `GateA` / `GateB`, eight braziers and `SpawnA` / `SpawnB` marks that face each other. Everything that carries a kingdom is a per-side *dress* (`Kit.arenaDress`): tower caps in the kingdom's silhouette, emblems on banners, plaques,
flags, crest and the rug under the champion. `Kit.crowdFigure(color, role?, variant?)` is 4 primitive parts, client-only, deterministic, eight variants; `Kit.armour(armour, color)` returns Accessories (light 9 parts, medium 12, heavy 17) and
`Kit.weapon(weapon, color)` a Tool (spear 7, greatsword 8, mace 9, sword and shield 10 parts), both primitives only, no scripts, G12.1 names (FORGE-01's `Arena/Types.luau` was not on main when this was built).

**Site (a deviation to know about).** The brief's "neutral map centre, at least 20 studs from tower, plaza, roads, nodes, outposts" has no solution at the exact centre (the hub plaza, the watchtower and the road crossing sit on it). A solver over the live geometry
(`world/Layout.luau`, comment above `ARENA_AT`) put the arena at (141, -27): at least 20 studs from the watchtower zone, plaza, roads, nodes and outposts (nav edges 19.9 at the nearest, spec threshold 15), flat ground, inside the heartland's east edge; spawn B (x = 154) is
4 studs outside the heartland polygon (x <= 150) and the east gate up to 28 studs outside (the spec says "centre inside, east edge within 30 studs"). The WorldPlan keep-out moved 37 of 618 decor placements (20 trees, 5 bushes, 12 rocks); the density-1.0 pins were re-pinned with that one-line reason.

**Part budget** (target 700, hard cap 900; the brief's 1,500 is not affordable under D-047): neutral 339 (205 structure + 2 x 67 neutral dress); dressed pairs crimson x2 411, azure x2 459, gold x2 449, emerald x2 499 (worst). Crowd figure 4 parts for every role, variant and colour.

**Evidence (headless, not Studio).** Specs under `tests/world`: KitArena 30, KitCrowdFigure 18, KitGear 23, ArenaLayout 20 tests, plus WorldService and the dump specs; one full `bash roblox/scripts/check.sh` exit 0 (551 + 5 + 140 + 361 + 256 + 15 + 15 + 425 + 326 + 299 tests, 0 failed).
Mutation checks: 34 hand-made mutants (spawn yaw, stand mirror, gate misnamed, cap shape, budget junk, yielding dress, crowd part count and pivot, variants, grip, weapon shaft, layout site, keep-out, trim, round-body pivot, round bodies, scales width, spear head orientation, mace studs,
sword blade, light cloak, pale sleeves ...) all killed, after three that first survived got new tests (floating-part probes, a direct `WorldPlan.clear()` test, an emblem-field count).

**Renders** (Blender Cycles from Lune dumps of the real Kit parts; roblox materials only approximated: Metal is a soft 0.35 metallic here): `img/fl0072_aerial_crimson_azure.jpg`, `fl0072_aerial_emerald_gold.jpg` (native 1080p pixels at 170 studs / 50 deg, 960 x 540 crops), `fl0072_ruler_crimson_azure.jpg`,
`fl0072_ruler_emerald_gold.jpg` (low camera just inside a gate), `fl0072_stands_crowd.jpg` (one stand per kingdom, 60 figures each), `fl0072_roles.jpg` (the six role figures, two kingdoms), `fl0072_gear_sheet.jpg` (3 armours x 4 weapons 3/4 view plus R6 fit), `fl0072_armour_close.jpg`,
`fl0072_world_aerial.jpg`, `fl0072_world_centre.jpg` (the arena in the valley). All under 250 KB. I looked at every one before sending it to the reviewer.

### D-019 fresh-context image-only review, round 1 (head d048b249; reviewer saw only the ten images)
Scores sil/var/read (prop, pal, detail, cohes, cost >= 3 everywhere except where noted): arena aerial 4/4/4 PASS (marginal; emerald caps read like azure's), arena ruler 4/3/3 NEEDS-WORK (camera inside the gate tunnel: pillars and foreground torches filled the frame),
crowd 3/3/4 NEEDS-WORK (identical bodies, white wedge arms read as shards), role props 3/3/2 NEEDS-WORK (4 of 6 readable), light/medium/heavy armour 4/4/3 each (pauldron clipped the arm, chrome medium helm, dark heavy set on dark legs, stray cream bits under the cap brim),
sword and shield 3/4/3 (thin blade), greatsword 4/4/4, spear 4/4/4 (head read as a fork), mace 4/4/4 (a bomb on a stick). Verdict NEEDS-WORK.
What the author checked and changed for round 2: the stray cream bits were the stand-in avatar's box head poking out of the cap (the stand-in now has a round R15 head; the cap sits higher); the spear head's two wedges had their tall edges facing outward (a fork), now facing the centre
(a leaf); the ruler camera moved inside the ring; crowd and prop changes below.

### Round 2 (head 9e5037c6): what changed
Crowd: square tabards and round robes, heights 0.82 - 1.07, tabard shades 0.84 - 1.2 of the kingdom colour, sleeves in kingdom cloth or bare skin (no pale shards); props bigger: sledge 2.2 x 1.3, satchel 1.9 x 1.8, basket tray 2.9 wide, stout staff, brass scales with a 4.4-stud tilted beam.
Gear: sword blade 0.62 wide with a dark fuller, leaf spear head, studded morning-star mace, a short kingdom cape for the light set (it was the plain set), lighter heavy plate, smaller medium cops, tighter heavy spaulders; the preview avatar wears linen and brown so dark plate reads; the gear sheet is now 3/4 with the weapon in the forward-raised hand.

**Round 2 scores (fresh reviewer; sil / var / read; every other column >= 3 except pal/detail where noted):**

| family | sil | var | read | result | reviewer's note |
|---|---|---|---|---|---|
| arena at the aerial camera | 4 | 4 | 4 | PASS | cap shapes, banners and floor tiles carry the kingdoms; the emerald crowd is the weak spot |
| arena at the ruler / ring level | 4 | 4 | 4 | PASS | the crown tile reads like an envelope; the sand floor is a large blank |
| crowd figures | 4 | **3** | **3** | NEEDS-WORK | hats differ strongly between kingdoms; "identical boxes" within a stand; at 170 studs a colour mass |
| key-citizen props | **3** | 4 | **2** | NEEDS-WORK | hammer and tablet read, three of the six not named with confidence; none findable from the aerial camera |
| light armour | **3** | 4 | **3** | NEEDS-WORK | "close to the bare avatar", weakest silhouette |
| medium armour | 4 | 4 | 4 | PASS | pauldrons intersect the arm blocks |
| heavy armour | 4 | 4 | 4 | PASS | the strongest silhouette; shoulder plates splay like wings |
| sword and shield | 4 | 4 | 4 | PASS | the round shield identifies it |
| greatsword | 4 | 3 | 4 | PASS | differs from the sword mainly by size |
| spear | 5 | 4 | 5 | PASS | tallest, most readable |
| mace | **2** | 3 | **2** | NEEDS-WORK | a small spiked head that overlaps the avatar's head in the 3/4 view; "reads as a horned hat" |

Reviewer verdict: NEEDS-WORK; the venue, medium and heavy armour, sword and shield, greatsword and spear pass.
**Rule applied: at most two author rounds, then stop and report the failing criteria.** Failing after round 2 (stated plainly, not argued away): crowd variation 3 and readability 3 (need 4); key-citizen props silhouette 3 and readability 2; light armour silhouette 3 and readability 3; mace silhouette 2 and readability 2.

**Remaining weaknesses, honestly.** (1) Key citizens: the reviewer read the satchel as a tablet, the plume as a red slab, the staff as a plain pole, the basket as a drum and could not find them from the aerial camera; they need either more parts than the 4-part budget allows
(a banner on the staff, a cross on the satchel, hanging pans on the scales) or a world-space cue (a ground ring or a small flag) that is not a Kit figure. (2) Crowd variety is bounded by 4 parts: bodies are two shapes in four shades and several heights; the reviewer still saw "identical boxes", and from 170 studs a stand is a colour mass with a hat-shape texture.
(3) The mace's head sits at the avatar's face height in a 3/4 view because the arm is raised forward and the mace is short; it needs a longer haft or a lower grip. (4) The light set is the plain one by design (7 -> 9 parts); a hood or a tall cape would give it a silhouette. (5) Heavy's spaulders splay like wings and the medium cops intersect the arm blocks (a worn pauldron
always overlaps the shoulder; the avatar in the preview is a block stand-in, a real R15 rig is unverified). (6) Emerald is the least readable kingdom: dark green on dark green, and the timber-hoarding cap reads as a pyramid at 170 studs. (7) The crown emblem (the shared D-039 piece) reads as an envelope on the rug at that size; changing it re-pins every building that carries it.
(8) No road leads to the arena and the plinth meets the grass without a blend. (9) All of this is Blender, not Studio: lighting, materials (Roblox Metal and Fabric are only approximated), real R15 and R6 fit and the arena's look in the engine's lighting are unverified.

### Round 3 (authorised by FORGE-00 after CONTRACTS v0.4-g11a; code head 62c68e10, images head 7d0690c1) — supersedes the numbers above where they differ

G12.6 now lets the six key citizens use up to 8 parts (`Kit.CROWD_ROLE_MAX_PARTS`, the specs read it); every other figure stays at 4 (`Kit.CROWD_MAX_PARTS`).
**What changed.** Key citizens (7 - 8 parts): sledge with peen and a dark apron (blacksmith); satchel with a red cross and a strap (healer); steel helm, tall plume, cape, sash and scabbard (captain); basket with a bridge handle and a loaf (provisioner);
staff with a crossbar, a kingdom banner, a finial and a white beard (elder); brass scales held out in front with a pan under each beam end (merchant). Crowd: 12 variants (was 8) with round robes and square tabards, three head shapes (ball, block, drum), crest scale 0.9 - 1.15,
five arm poses (level, waving, thrown up, one arm straight up, folded at the waist), heights 0.82 - 1.07. Mace: 5-stud haft, studded ball head held 2 studs clear above the wearer's head (reach 5.5). Light armour: long swept cape, wider mantle, a taller feather. Heavy spaulders hug the arm
(no more than 0.45 stud past its outer edge); medium cops sit on the shoulder. Emerald's gate and royal-roof caps are an overhanging timber hoarding under a flat kingdom roof (`kingdomCap` in `Kit/Arena.luau`; the Kit's `towerCap` is unchanged). Ground blend: 10 parts (a sloped skirt on four sides,
a sand ramp and a short path at each gate, never above the apron, at most 4 studs past the plate, clear of the decor by the existing keep-out).
**Exact part counts now:** arena neutral 349 (215 structure including the 10-part ground blend + 2 x 67 neutral dress); dressed pairs crimson x2 421, azure x2 469, gold x2 459, emerald x2 487 (worst; was 499 with the pyramid caps). Crowd figure 4; key citizens: blacksmith 8, healer 8, captain 7, provisioner 8, elder 8, merchant 8.
Armour: light 9, medium 12, heavy 17. Weapons: spear 7, greatsword 8, sword and shield 10, mace 10.
**Evidence (headless):** KitArena 32, KitCrowdFigure 19, KitGear 23, ArenaLayout 21 tests; 44 mutants killed of 44 (10 new: crossed bars, no drum heads, no arm thrown up, tiny banner, scales without pans, mace head at face height, winged spaulders, the Kit pyramid on emerald, no ground blend, a skirt facing away).

**Round 3 scores (fresh image-only reviewer, ten images plus the new ground-blend image; sil / var / read; every other column >= 3):**

| family | sil | var | read | result |
|---|---|---|---|---|
| arena, aerial camera | 4 | 4 | 4 | PASS (marginal; emerald's side is dark) |
| arena, ruler camera | 4 | 4 | 5 | PASS |
| **crowd figures** | 4 | **3** | **3** | NEEDS-WORK |
| key-citizen props (was 3 / 4 / 2) | 4 | 4 | 4 | PASS (marginal): all six told apart at ring level, none at the aerial camera; the captain is the weakest read |
| light armour (was 3 / 4 / 3) | 4 | 4 | 4 | PASS (marginal): "cowboy hat", a floating red rod, a flat cape plank |
| medium armour | 4 | 4 | 4 | PASS: the cops look detached at neck height |
| heavy armour | 4 | 4 | 4 | PASS (marginal): shoulder plates "wing out" |
| sword and shield | 4 | 4 | 4 | PASS |
| **greatsword** | 4 | **3** | **3** | NEEDS-WORK: differs from the sword mainly by length, confusable with the spear as a thin vertical line |
| spear | 5 | 4 | 4 | PASS |
| **mace (was 2 / 3 / 2)** | **3** | 4 | **3** | NEEDS-WORK: a small cross-shaped head on a thin pole, gone at 45 studs |
| ground blend and fit in the valley | 3 | 3 | 3 | NEEDS-WORK: the skirt is barely visible, the sand ramp a small low-contrast patch leading nowhere |

Reviewer verdict: NEEDS-WORK overall; the arena venue and the key citizens pass, and so do all three armours and sword and shield and spear.
**Rule applied: one more round, then stop.** Failing criteria after round 3, stated plainly: **crowd** variation 3 and readability 3 (at the aerial camera a stand is a single-colour regimented mass; emerald is the darkest and its swept plumes read as pipes; the crimson and emerald crowds merge by value in greyscale);
**greatsword** variation 3 and readability 3; **mace** silhouette 3 and readability 3; the ground blend 3 / 3 / 3 (not a gating family).
Other things the reviewer flagged, not argued away: the floor crown still reads as an envelope and the oak leaf as a cloud (the shared D-039 emblems), no hand visibly grips a weapon (the stand-in avatar has block arms), the armours form a visual ladder light < medium < heavy ("the opposite of a sidegrade"), the gate-front walls are blank planes, and no road leads to the arena.
Where I read the images differently: the "cowboy hat" is the light cap's brim and feather (a leather cap with a plume is what the set is); "floating" weapons are the stand-in's raised forearm seen end-on. Fit on a real R15 or R6 avatar and every Roblox material are Studio-unverified.
