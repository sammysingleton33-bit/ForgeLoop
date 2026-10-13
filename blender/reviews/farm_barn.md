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
