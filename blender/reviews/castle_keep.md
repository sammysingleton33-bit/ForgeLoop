# castle_keep: review log (FORGE-02 worker, D-019 author rounds)

Rubric: `reviews/README.md`. Author self-scores; the independent verdict goes to `castle_keep.json`.
Images: `previews/castle_keep.jpg` (final); per-round sheets in the worker scratchpad
(`castle/sheets/keep_rN.jpg`), heroes in `renders/castle_keep/` (git-ignored).

## Round 0 (validation only)
red 16.5k, green 18.1k, yellow 16.1k over the 16000 budget. Corner-turret ashlar (~970 tris
each) and the green keep's 14 shuttered front windows (2.6k) were the main costs.
Changes: turret ashlar uses bigger blocks and skips the quadrant buried inside the hall (below the
roof line); bigger blocks on the red donjon and the yellow drum; green front windows 14 -> 9,
lighter timber frames, 8-sided hoardings with struts on every other bay.

## Round 1 (first quick render)
Scores: silhouette 5, variation 5, readability 5, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Seen: each keep is the biggest mass and recognisable from its outline alone:
- red: a cluster of spires (four turret spires, a giant donjon spire with a dormer, a stair-turret needle);
- blue: square corner towers and a square donjon under steep slate pyramids with dormers;
- green: a stone hall carrying a jettied, timber-framed two-storey upper hall (the cottage language at
  castle scale), a big moss-green roof with dormers and a timber lantern, hoarded round corner towers;
- yellow: sandstone palace with a great onion dome on a windowed drum, domed corner belvederes, minarets.
All share the podium, grand stair with urns, arched door with segmented voussoirs, emblem shield,
balcony and twin banners.
Problems seen: blue corner towers end abruptly (string course straight into the pyramid); the podium
foot looked clinically clean next to the mossy walls and towers.

## Round 2
Changes: blue corner towers get a corbel table under the eaves on their two outward faces and wider
eaves; moss clumps along the podium foot on all keeps (same language as walls/towers).
Scores: silhouette 5, variation 5, readability 5, proportions 4, palette 4, detail 4, cohesion 5, tri cost 4.
Seen: blue tower tops now have a crisp shadow line; weathering is consistent across the castle set.
Tris 14.7k–15.2k / 16000, all PASS, min silhouette diff 0.109. Sizes 45-55 x 40-44 footprint, 64-84 tall.
Remaining weaknesses: back facades are simpler (one tall window, fewer details); keeps are seen
from the courtyard, so a later pass could add a rear door or stair turret detail.

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
Scores unchanged (5/5/5/4/4/4/5/4); palette now reads gold, not orange.
Tris red 15122, blue 15070, green 14848, yellow 14656 (of 16000); BUILD PASS (full build), min silhouette diff 0.107.

## Round 4 (fresh-context review follow-up)
Reviewer (fresh context): PASS. Lead asked for a rebuild on the final palette, removal of the dark
dome rib dashes (yellow_01) and budget headroom.
Shared changes (`_castle_common.py`): ashlar blocks are now 8-tri wedges (`stone`). The front face is
unchanged and the top and bottom slope back to a hidden ridge, giving a built-in chamfer and a deep
mortar joint. That wins back about 10% of the budget with the same outline. Dark dome rib dashes,
which read as cracks, are removed by default. Rebuilt on the final palette (emerald 23805F, gold
EBB910, goldenrod shutters).
Changes: yellow great dome without ribs (no crack-like dashes); emerald/gold from the final palette.
Scores unchanged (5/5/5/4/4/4/5/4).
Tris: red 13414, blue 13070, green 13644, yellow 12564 (of 16000; max 85%); min silhouette diff
0.108; full build BUILD PASS. Sheet: `previews/castle_keep.jpg`.

Final: full (non-quick) build, see `previews/castle_keep.jpg`.
