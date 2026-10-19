# farm_barn — author review log (FORGE-02 farm worker)

Asset ids `farm_barn_01..04`, budget `building_medium` (8000). Gable end to the front: 9.2 x 10.6 double
doors (a real opening — walls are separate solid slabs, floor at 0.4), hayloft door in the gable with a
hoist beam, iron pulley, rope and hook, board-and-batten walls on an irregular stone plinth, steep (52-56
deg) kit roof, 4 kit windows down the long sides, trim boards, threshold ramp, bales, trough, wheel.
01 red barn paint + white trim, red tiles, doors open, loft closed (X-braced), cupola with rooster vane.
02 natural wood, thatch, doors closed, loft open with a bale on the hoist, lean-to woodshed.
03 blue barn paint, blue tiles, one door open, loft open, lean-to.  04 natural wood, green tiles, doors open,
loft open, cupola.

## Round 1 — first pass (quick build)
Images: `previews/farm_barn.jpg` (r1, overwritten).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 4 | 4 | 4 | 3 |

Problems seen
- Open doorways were **pitch black** voids: the interior hay sat at the back of the barn where no light
  reaches; nothing said "full of hay" from outside.
- Plinth cost ~1400 tris (bevelled stones) for something knee-high.
- Thatch variant failed the `roof >= 4` check (thatch is 2-3 pieces).

Changes
- Hay spilling out over the threshold + three bales stacked just inside the door; interior lining in
  `wood` instead of `wood_dark`; hayloft floor + loft hay at the back.
- Plinth stones unbevelled (saves ~600-900 tris); lantern (glowing glass) on the door post; pitchfork by the
  bales. Check changed to `roof >= 2`.

## Round 2
Images: `previews/farm_barn.jpg`, `scratchpad/farm/b1.png`, `scratchpad/farm/b3.png` (640 px heroes).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 4 | 4 | 4 | 4 |

5104-5916 tris. Variation min 0.10 (01 vs 04: same massing, differ by colour/roof/loft/cupola).
Remaining weaknesses: interior still dark in Cycles (Roblox ambient will light it more); the open leaves
show their back faces (braced on both sides to compensate); lean-to side is random so it is sometimes hidden
from the hero angle.

## Round 3 — final (full build)
Images: `previews/farm_barn.jpg` (final), `renders/farm_barn/farm_barn_0N_hero.png`, `farm_barn_gameplay.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 4 | 4 | 4 | 4 |

Collision switched to fidelity `None` + boxes (side/back walls, two front piers, door header, floor, bale
stack, lean-to) so the 9.2 x 10.6 doorway is walkable. Final 5104-5916 tris / 8000, 33-34 studs tall,
variation min 0.101, BUILD PASS. At 72 studs: unmistakable barns (gable doors, X-braced leaves, hoist, cupola).

## Round 4 — fix round after the fresh-context review (NEEDS-WORK) + ART_DIRECTION 3 (v2)
Reviewer issues: barn_01/03 read as solid red/blue blocks (painted walls); identical massing on all four; no
clearly gold-kingdom barn.
Images: `previews/farm_barn.jpg` (final), `scratchpad/farm/barn_fix_quick.jpg`.

Changes (VERSION 2)
- Walls are neutral on every variant (natural `wood` / `wood_light`, or whitewash `plaster` on 03); the kingdom
  colour is only on the roof, door frame + braces, the closed loft door brace and window shutters.
- Massing now differs per variant:
  01 red **gambrel roof** (custom: 62 deg lower / 27 deg upper slopes in stepped courses, barge boards, pentagon gable)
  + cupola; 02 thatch + **side lean-to woodshed** with log stack + loft hoist with a hanging bale + **blue star banner**
  beside the doors; 03 **gold kingdom**: saturated gold tile roof, goldenrod braces, whitewashed walls and an
  **attached round fieldstone silo** with iron hoops, gold dome + finial, ladder, slit windows and a gold sun banner;
  04 green **catslide roof** (kit `gable_roof(extend=...)`) sweeping down over a 5.2-wide side aisle with its own
  arched door and two windows (wider footprint) + cupola.
- Fixed a bug where the lean-to collision box reused the lantern's x.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 5 | 5 | 4 | 4 | 4 | 4 | 4 |

Quick build: 5220-6036 tris, variation min 0.154 (03 vs 04), BUILD PASS. Final full-build numbers in the report.
Final full build: 5220-6036 tris / 8000, variation min 0.154, BUILD PASS.

## Fresh review round 4

- Reviewer: fresh-context subagent (contact sheet `previews/farm_barn.jpg` only, incl. zoomed crops and grayscale check), 2026-10-13
- Verdict: **NEEDS-WORK**; per-asset overrides: farm_barn_02=PASS
- Scores: silhouette 4, variation 4, readability 3, proportions 4, palette 4, detail_density 4, cohesion 3, triangle_cost 4
- Notes: Distinct roofs (red gambrel, blue thatch gable + woodshed, yellow plastered gable + domed silo, green gable + cupola + bake oven), good doors and props. FAIL readability: kingdom identity is colour-only for 3 of 4. barn_01 (red) and barn_04 (green) carry no emblem in either view. barn_03 (yellow) has its sun banner only on the silo side, which is hidden at the gameplay camera. In grayscale only barn_02 (blue, star banner by the door) can be assigned to a kingdom. Fix: put a kingdom banner or shield beside the main doors on every barn (crown/oak/sun), matching barn_02. Cohesion 3: the gambrel roof, rooster weathervane and cylindrical domed silo read as American farm rather than medieval; consider a gable/hipped roof for 01 and a wattle granary or haystack in place of the silo for 03. 5.2-6.0k of 8k.

## Round 5 (fixes from fresh review round 4)
Reviewer issues: readability 3 (kingdom shown by colour only on 01/03/04; barn_03's sun banner was on the hidden silo
side) and cohesion 3 (gambrel roof, rooster weathervane and domed cylindrical silo read as an American farm).

Changes (barn_02 geometry hash unchanged: fedb9b8f00a1b234)
- **Kingdom banner beside the main doors on every barn**, facing the gameplay camera: the same
  `_farm_common.kingdom_banner(k, 6.2, 2.6)` + iron brackets barn_02 already had (crown / star / sun on its ivory
  roundel / oak), at barn_02's spot (right pier) on 02, 03 and 04 and mirrored to the left pier on 01 (plan key
  `banner: "left"`). barn_03's silo banner is gone with the silo. `_farm_common` was not touched.
- Door states, so that no leaf covers or hides a banner: 01 `open_r` (left leaf shut beside its banner, right leaf
  swung back flat), 04 `open_l` (mirror), 03 `half` (unchanged), 02 `closed` (unchanged).
- 01: the gambrel is replaced with a **half-hipped (jerkinhead) red tile roof** (new `half_hip_roof`: 55 deg sides
  in 6 stepped courses, 60 deg hips clipped at 70 % of the rise, ridge and hip caps, hip fascias, barge boards).
  The gable wall is a trapezoid up to the clip line, and the loft hoist beam drops 0.4 to clear the hip eave.
- 03: the domed silo is replaced with a **raised timber granary on six mushroom staddle stones** next to the barn
  front (+X), visible from the gameplay camera: whitewashed timber frame with braces, a gold tile gable roof, a
  goldenrod plank door with iron strap hinges, a gable hatch, detached stone steps (the classic rat gap) and two
  burlap sacks.
- 01/04: the rooster + compass arms on the ridge louvre become a **swallowtail pennant vane** in the kingdom cloth
  with an iron knob.
- Author round 1 (`/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r1_barn_gp_g.png`, `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r1_barn04_gp.png`, `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r1_barn03_granary.png`,
  `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r1_barn01_hip.png`): the right leaf propped at 92 deg hid barn_04's banner from the gameplay camera, and would
  do the same to barn_01 from the left. The granary's diagonal door brace read as a letter "Z", its sacks read as
  white jugs, the staddles were too short to read, and the barge boards poked up as "ears" at the hip corners.
- Author round 2: the one-leaf-shut door states above, a plank door with strap hinges, `cloth_brown` sacks,
  staddles 2.1 -> 2.7, the granary moved to the front half, and barge boards ending under the hip eave.

Tris (budget 8000): 01 5220 -> 5012, 02 5276 (same), 03 6016 -> 6340, 04 6036 -> 6292.
Variation min 0.1204 (03 vs 04; threshold 0.08). Full build: BUILD PASS.
Images: `previews/farm_barn.jpg`, `renders/farm_barn/farm_barn_0N_hero.png`, `farm_barn_gameplay.png`; crops
`/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_barn_gp_g.png` and `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_banners_gp_g.png` (grayscale gameplay: crown / star / sun roundel / oak all read),
`/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_barn03_gp.png`, `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_barn03_granary.png`, `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_barn01_hip.png`.
Author verdict: each barn's kingdom reads in grayscale at 75 studs. Cohesion now reads as a medieval farmstead (half
hip, granary on staddles, pennant vane). Known nit: tiny tile-corner tabs at the hip eave corners of barn_01 show in
the hero close-up but not at gameplay distance. The ridge louvre on 01/04 is kept; it is plausible for medieval but
still the most "farm-generic" element.

## Fresh review round 5

- Reviewer: fresh-context subagent (contact sheet `previews/farm_barn.jpg` only, zoomed PIL crops incl. grayscale; manifest tris), 2026-10-13
- Verdict: **PASS**; per-asset overrides: none
- Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail_density 4, cohesion 3, triangle_cost 4
- Notes: Every barn now has an emblem banner beside its doors, and all four emblems read in grayscale at 75 studs: crown (01), star (02), sun in a cream roundel (03, not gold-on-gold) and ivory oak leaf (04). Four distinct roofs: red half-hip with kicked eaves + cupola, blue thatch + lean-to woodshed, yellow steep gable + half-timbered granary on staddles, green long gable + cupola + stone bread oven. Medieval vs American: 02 and 03 read European. 01 and 04 still carry American cues in the kingdom-colour X-braced double doors plus a cupola with weathervane flag; 01 in particular reads as a classic red barn at a glance. Cohesion is held at 3 for that reason. Advisory: plank doors with iron strap hinges (ART_DIRECTION section 4) and a louvre or ridge vent instead of the cupola. Tris 5012-6340/8000.
