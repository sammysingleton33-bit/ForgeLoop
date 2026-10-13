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

## Round 5 (advisories from fresh review round 3)
Advisory (fresh review round 3, PASS): yellow_01's slim ringed turrets with tiny domes beside the
great dome read as minarets, so the keep risked reading as a religious building.
Changes:
- The two minarets are replaced by chunky square crenellated back towers (8.4 wide, stepped merlons,
  squat gold half-dome caps on a light plinth).
- The corner belvederes stand on four broad piers instead of eight slender posts. Gold identity =
  big onion domes on chunky drums.
- Emblems: castle banners, flags, shields and the gold gatehouse crest now use the shared helpers from
  `_kingdom_props_common.py` (`emblem`, `field`, `border`, `emblem_colors`). Emerald flies the bright
  cloth with an ivory border; gold gets a bronze border. The Sunspire sun always sits on an ivory
  roundel with a bronze rim, never on gold. Crown (red) and star (blue) are kept; the castle's own
  emblem outlines are deleted.
Scores unchanged from round 3 of the fresh review.
Tris: red_01 13566, blue_01 13306, green_01 14068, yellow_01 14144 (of 16000); min silhouette diff 0.1086; full build BUILD PASS.

Final: full (non-quick) build, see `previews/castle_keep.jpg`.

## Fresh review round 4

- Reviewer: fresh-context subagent (contact sheet `previews/castle_keep.jpg` only, incl. zoomed crops and grayscale check), 2026-10-13
- Verdict: **PASS**
- Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail_density 4, cohesion 4, triangle_cost 3
- Notes: Four distinct crowns at 115 studs: red needle-spire cluster, blue pyramid roofs with dormers, green half-timber manor with hipped roof (reads more manor/town hall than keep), yellow onion domes on chunky open drums. Grayscale: all four separable; red vs blue is the closest pair (cones vs pyramids). Door banners carry crown/star/oak/sun. Yellow sun = cream roundel with gold sunburst: not a C, not gold-on-gold, but at 115 studs the rays merge into a ringed dot/rosette. Yellow keep reads as a fantasy kremlin, not a mosque (no slender minarets), though the 1 big + 4 small dome pattern is church-like; consider squatter corner domes. The disc finial under the central-dome flag should get the same fix as tower/gatehouse (disc reads as a crescent in grayscale). Flags are colour-only stripes (identical in grayscale). 13.3-14.1k of 16k (83-88%), little headroom. Sheet: gameplay strip keeps overlap each other.

## Round 6 (fixes from fresh review round 4)
Reviewer advisory: the disc finial under the central-dome flag read as a crescent in grayscale (same issue as
tower/gatehouse).

Changes (only yellow_01; red/blue/green geometry hashes unchanged)
- The central onion dome uses `dome(fin="orb_pole")`: a solid `gold_dark` orb on a 1.2-stud gold stem, with
  the flagpole rising out of it (shared `_castle_common.orb_finial`, see castle_tower Round 7). The corner and back
  domes keep their "simple" spike finials.
- Two author rounds, shared with the tower: round 1 had the orb on the tip, round 2 added the stem so the flag keeps
  its height.

Tris: yellow_01 14120 -> 14088 / 16000. Variation min 0.1097 (blue vs yellow; was 0.1082). Full build: BUILD PASS.
Images: `previews/castle_keep.jpg`, `renders/castle_keep/castle_keep_gameplay.png`; crops
`/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_keep_gp_finials.png`, `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_keep_gp_finials_g.png` (grayscale, 115 studs), `/tmp/claude-0/-home-user/168e0311-22ac-55e3-a72d-3403925c3328/scratchpad/fix5/r2_yellow_heroes_tops_g.png`.
Author verdict: no crescent. At 115 studs the orb is a small dark knob under the flag. Not addressed (out of scope):
the "1 big + 4 small domes" church-likeness and colour-only flag stripes.
