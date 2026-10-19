# resource_stone: review log (author rounds, D-019)

Generator: `generators/resource_stone.py` (v1) + `generators/_rock_common.py`. 6 assets `resource_stone_01..06`.
Images: `previews/resource_stone.jpg`, `renders/resource_stone/resource_stone_NN_hero.png`,
`renders/resource_stone/resource_stone_gameplay.png` (git-ignored, overwritten per build).

Rubric order: silhouette / variation / readability / proportions / palette / detail / cohesion / tris.

## Round 1: first build
Scores: 3 / 4 / 3 / 3 / 2 / 3 / 3 / 3.
Problems seen:
- Rough rock and cut faces almost the same value (rough tops took the light swatch) so the benches did not pop.
- Mass too shallow: the benches cut away most of it and left a sharp wedge ridge ("tombstone").
- Chisel marks (3-5 stroke clusters per riser) read as scribbles / tally marks and cost ~400 tris.
- Scaffold variant looked like a table standing on the rock.
- Variant 03 over budget (1780/1500).
Changes: deeper mass (11-12.5 D), shallower front cut, tread 1.9-2.6 studs, weathered top fracture facet,
1-2 chisel clusters per riser, scaffold rebuilt as a ground-standing frame with plank deck level with the upper
tread plus a ladder.

## Round 2
Scores: 4 / 4 / 4 / 4 / 3 / 4 / 4 / 4.
Problems: cut/rough contrast still weak in sun (rough tops lit up); no link to the boulder set.
Changes: rough rock sides take the dark swatch, tops the mid one; cut risers `stone_light`/`stone_pale`, treads
`stone_pale` (sandstone variants: sandstone -> path_sand); moss on the weathered top on 3 variants.

## Round 3 (final)
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4 (PASS on author scoring).
Changes: hoist tripod moved to the side and turned (two legs front, one back) and the sledge moved right so the
`harvest` spot in front of the bottom bench is clear of props; final full build.
Remaining weaknesses: the 4-bench variant (03) is busy; chisel strokes are still slightly "drawn on"; wedges read
as small orange beads at 60 studs.
Tris 806-1340 (budget 1500), all PASS, min silhouette diff 0.220.

## Technical note (all rock/resource generators)
Before the final build, `_rock_common.to_piece` was made order-independent (`canonical()` rebuilds each bmesh in
a geometry-sorted order before triangulating; moss vertices are offset in sorted order). Some bmesh operators
order their output by memory address, so the first build in a process triangulated differently from later ones
and the geometry hash changed between runs. Verified: identical hashes across repeated builds and processes.
Ground contact fix (same final build): grass tufts used to sink 0.05 studs and tilted props (tool handles,
ladder / tripod / sawhorse feet, root flares, the felled trunk) dipped up to 0.29 below z=0, which pushed the
pivot below the real ground line. Now rock pieces are clipped at z=0 in `to_piece`, tufts start at z=0, tool and
ladder bases are raised 0.14, and `rest_on_ground()` lifts any prop piece that still dips: every asset's lowest
point is exactly z=0 (checked per asset).

## Fix round after the fresh-context review (NEEDS-WORK: variation 3), v2
Reviewer findings: every variant had the same loose-block composition; 01/05 near-clones, 03/06 both tripods;
only two stone tones; the single "+" groove crossings on 01/05 could read as a cross.
Changes:
- One landmark per variant: 01 hand windlass on the upper tread with its rope down to a roped block; 02 ladder +
  sledgehammer; 03 tripod crane (block hanging, nothing on the ground); 04 scaffold + ladder; 05 a deep stepped PIT
  cut into the rock between two side walls that widen upwards, block on a sled; 06 a treadwheel crane (two rims,
  spokes, treads, jib over the face, block hanging).
- Loose blocks differ: roped single / scattered row of shrinking blocks / hanging only / stacked pair + one /
  on a sled / hanging; leaning tools only on 02 and 04 (no common "stack + leaning pick" layout).
- Tones: grey limestone, dark granite, blue-grey slate (new, `stone_cool*` with `slate` seams) and sandstone.
- Seams now run in brick bond: vertical joints stop at the bed joint and are staggered half a block above it,
  so every junction is a T; no "+" crossings anywhere.
- Moss on top is now 2 small surface-following plates (shared fix).
Quick-build scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4,
tris 4.
Final full build (v2): 776-1254 tris / 1500, all PASS, min silhouette diff 0.278.

## Round 3 (fresh-review round 2: NEEDS-WORK), v3
Reviewer findings: "+" crosses still visible on 01 / 03 / 06 where horizontal groove rods crossed vertical ticks;
rods ran past the face outline and poked below the base like stakes; tally marks; 01 / 03 / 06 undercut like a
keel (boat hulls); 05 read as a sofa (stepped seat between two armrests); 02 / 05 blue-grey too close to the ore
slate; flat green moss patches on 01 / 04 read as stickers.
Changes:
- Seams rebuilt as true running bond clipped to each cut face's actual outline (convex polygon of the cut, inset
  0.3): bed joints span the face at its real width at that height; head joints run only between two bed joints,
  touching both, staggered half a block per course, and are kept inside the face at both ends. Every junction is
  a T; no joint can leave the stone or reach below the base. Chisel "tally marks" removed. Side cut faces of the
  corner variants get the same treatment.
- Grounded bases: the lower half of the rough-mass point cloud flares out (up to +45 %) and the mass is sunk 22 %
  instead of 12 %, so the rock meets the ground wide instead of on a keel.
- 05 pit made asymmetric: one wall is broken down to a rough rubble slope at 38-50 % height, wall faces and step
  edges are skewed a few degrees, so it no longer reads as a symmetric seat.
- 02 / 05 moved from blue-grey slate to a pale warm limestone (rough stone / cobble / stone_light, cuts
  stone_light / stone_pale); moss dropped on the quarry tops (no stickers).
Quick-build scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Final full build (v3): 862-1174 tris / 1500, all PASS, min silhouette diff 0.238.
