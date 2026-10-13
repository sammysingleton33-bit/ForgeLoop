# castle_wall: review log (FORGE-02 worker, D-019 author rounds)

Rubric: `reviews/README.md`. Author self-scores; the independent verdict goes to `castle_wall.json`.
Images: `previews/castle_wall.jpg` (final); per-round sheets in the worker scratchpad
(`castle/sheets/wall_rN.jpg`), heroes in `renders/castle_wall/` (git-ignored).

## Round 0 (validation only, before any render)
- First design (one A/B pair shared by all kingdoms) failed the variation check (red_01 vs yellow_01
  0.070); 3 bastion variants were over 3000. Bounds leaked: the stair overshot +16, bartizan roofs
  overshot -8.4, and the kit ridge cap overshot the module ends.
- Redesign: the KINGDOM sets the cross-section, identical at both module ends so a kingdom's
  two variants tile: red machicolations + swallowtails, blue slate pentice, green timber hoarding,
  yellow sandstone talus + tall stepped merlons + purple/ivory frieze. The VARIANT adds features
  between the ends: _01 curtain (slit gallery, banner), _02 bastion (buttresses, bartizan in the
  kingdom roof language, banners, inner 20-step stair). All features are clamped inside the two-step
  foundation apron (y = +-8.4), so every variant's pivot is the wall axis.

## Round 1 (first quick render)
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tri cost 3.
Problems seen:
- Blue pentice read as a flat lid (3 deg slope), so blue_01 looked unfinished.
- Moss at the foot invisible (flat discs).
- red_02 at 3000/3000.
Changes: pentice raised to a 28-deg lean-to with three stepped slate courses, dark fascia and ridge
board; moss clumps taller, placed on the batter; kit `gable_roof` sag disabled on the tiling hoarding
roof (otherwise the ridge would scallop at every joint after the kit update).

## Round 2
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Seen: each kingdom's wall is recognisable from 80 studs by its top profile (crenels on corbels / slate
roof / timber gallery / sandstone talus with stepped merlons). Bastions add buttresses, bartizans
and banners. Courses, string courses, slits and moss give three levels of detail. Assembly test
(scratch): modules tile flush, towers hide the joints, the gatehouse ends meet the wall walks at z 24.
Changes: trimmed moss (5-seg) and stair-side blocks; red_02 2952/3000.
Tris 1.8k–3.0k / 3000, all PASS, min silhouette diff 0.094.
Remaining weaknesses: an isolated module shows its cut end (dark core cross-section) in the hero view,
which is intended for tiling but reads as a slice. Bastion variants have <150 tris headroom.

## Round 3 (FORGE-02 lead review fixes)
Lead review: kingdom identity reads clearly; two fixes requested.
Problems: (1) the cross-shaped arrow slits read as religious crosses at gameplay distance; (2) gold
(yellow) domes/roofs looked orange.
Changes (shared `_castle_common.py`):
- `arrow_slit` is now a plain vertical slit with a small round oillet at its foot (no cross arm).
- Cross shapes removed everywhere: every shuttered kit window uses `window_v` (one vertical mullion,
  no cross bar), dormers included; emblems stay crown / star / oak leaf / sun; flags keep a
  horizontal stripe.
- Yellow roofs, domes and cloth come only from `kingdom_color("yellow", ...)`, now the palette's
  true gold (E0B12E). Nothing is hard-coded orange. Wide purple rings on drums, belvederes and
  dome collars became ivory (`yellow_accent`) or `gold_dark`; purple remains only on thin friezes,
  banner bands, kiosk lintels and shutters.
Scores unchanged (4 across the board); palette now reads gold, not orange.
Tris red 2120/2968, blue 1856/2624, green 2280/2876, yellow 1944/2596 (of 3000); BUILD PASS (full build), min silhouette diff 0.096.

## Round 4 (fresh-context review follow-up)
Reviewer (fresh context): NEEDS-WORK, silhouette 3, variation 3. red_01 and yellow_01 lacked their
kingdom shape. Blue (both) and green_01 read as a box with a flat sloped lid. Banners sat on slits
(red_01, green_01, blue_02).
Shared changes (`_castle_common.py`): ashlar blocks are now 8-tri wedges (`stone`). The front face is
unchanged and the top and bottom slope back to a hidden ridge, giving a built-in chamfer and a deep
mortar joint. That wins back about 10% of the budget with the same outline. Dark dome rib dashes,
which read as cracks, are removed by default. Rebuilt on the final palette (emerald 23805F, gold
EBB910, goldenrod shutters).
Changes:
- red_01 / yellow_01: a corbelled corner turret (red cone / gold onion) at x = -11. All 8 variants now
  carry the kingdom roof shape.
- blue: the slate pentice is gone. Every merlon gets a small slate square pyramid on a light coping
  (the Frostmere pyramid language), so there is no overhang and the profile stays identical at both
  module ends.
- green_01: two gabled dormers on the hoarding roof break the long roofline (they rise above the
  ridge).
- Slits re-spaced: curtain slits at x = +-5.5 / +-12 with the banner centred between them; blue_02 and
  green_02 slits moved off their banners.
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Tris: red 2248/2632, blue 1550/2370, green 2612/2660, yellow 2064/2348 (of 3000; max 89%); min
silhouette diff 0.089; full build BUILD PASS. Sheet: `previews/castle_wall.jpg`.

## Round 5 (advisories from fresh review round 3)
Advisory: gold wall turrets read as slim ringed shafts; blue_01 is the weakest silhouette;
shared emblems.
Changes:
- Gold turrets (yellow_01 corner, yellow_02 bastion) are chunky drums (r 2.9, no mid ring, lower)
  under a broad onion.
- blue_01: one strong square turret with a tall slate pyramid over the merlon row at x = +10.
- Emblems: castle banners, flags, shields and the gold gatehouse crest now use the shared helpers from
  `_kingdom_props_common.py` (`emblem`, `field`, `border`, `emblem_colors`). Emerald flies the bright
  cloth with an ivory border; gold gets a bronze border. The Sunspire sun always sits on an ivory
  roundel with a bronze rim, never on gold. Crown (red) and star (blue) are kept; the castle's own
  emblem outlines are deleted.
Scores unchanged from round 3 of the fresh review.
Tris: red_01 2312, red_02 2760, blue_01 2030, blue_02 2438, green_01 2740, green_02 2788, yellow_01 2240, yellow_02 2524 (of 3000); min silhouette diff 0.0991; full build BUILD PASS.

Final: full (non-quick) build, see `previews/castle_wall.jpg`.
