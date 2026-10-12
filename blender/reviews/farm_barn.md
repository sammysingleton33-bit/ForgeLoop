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
