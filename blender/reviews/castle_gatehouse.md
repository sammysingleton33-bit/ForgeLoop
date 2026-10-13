# castle_gatehouse: review log (FORGE-02 worker, D-019 author rounds)

Rubric: `reviews/README.md`. Author self-scores; the independent verdict goes to `castle_gatehouse.json`.
Images: `previews/castle_gatehouse.jpg` (final); per-round sheets in the worker scratchpad
(`castle/sheets/gate_rN.jpg`), heroes in `renders/castle_gatehouse/` (git-ignored).

## Round 0 (validation only)
First version: 9.4k–10.7k / 9000, min silhouette diff 0.052 (green vs yellow) and later 0.043
(red vs blue: square and round towers with pointed roofs project almost the same). Flank wall-walk
doors and tower batters poked past x = +-16.
Changes: rear turrets get a light crown (string course + roof, no corbels/merlons); per-kingdom
massing so silhouettes differ structurally:
- red: tall twin spires and a machicolated gate front;
- blue: a central square gate tower with a steep pyramid over the passage, lower flanking towers;
- green: squat towers with hoardings and a timber bretèche over the gate (wide, low outline);
- yellow: a stepped crest with a gold sun between onion-domed towers, striped voussoirs, frieze.
The gate block's flank face is inset to x = 15.75 so its ashlar ends at x = 16, the walk doors are
recessed, and the tower batter is slimmer. Ground footprint is exactly 32; only roofs overhang
above wall height (<= 1 stud).

## Round 1 (first quick render)
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Seen: four distinct gate silhouettes. The raised portcullis reads in the top of the arch, the oak
leaves stand open in the gate hall, and the emblem shield and banners on the front towers carry the
kingdom. The road strip through the passage tells "this is the way in".
Problems seen: tower feet clinically clean compared with walls/towers (no moss); yellow at
8982/9000 and a slight X asymmetry (batter blocks at 16.37 vs 16.27) that would offset the pivot.

## Round 2
Changes: moss clumps at the front tower feet; removed hidden gate-hall wall blocks (budget); slimmer
tower batter, so the bounds are symmetric (pivot on the wall axis, gate centre at x = 0).
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Tris 8.6k–8.9k / 9000, all PASS, min silhouette diff 0.093.
Remaining weaknesses: the passage interior is mostly dark (hall ceiling, side walls plain); little
budget headroom; green roof overhang reaches x = +-17 at height 33+ (above the adjoining wall).

Collision: the visual mesh is exported with fidelity "None" (CanCollide = false). Solid masses come
as 9 collision boxes (two side masses, four towers, lintel over the passage, two top parapets;
blue adds a 10th for its central gate tower),
so the 14.5 x 17.7 passage is guaranteed open for carts and armies, and the gate-block walk at z = 31
is walkable.

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
Tris red 8838, blue 8646, green 8846, yellow 8902 (of 9000); BUILD PASS (full build), min silhouette diff 0.093.

## Round 4 (fresh-context review follow-up)
Reviewer (fresh context): PASS. Lead asked for a rebuild on the final palette and about 10% budget headroom
(all gatehouses were at 96-99%).
Changes: ashlar blocks are now 8-tri wedges (`stone` in `_castle_common.py`: same front outline, built-in
chamfer); tower domes have no rib dashes; emerald / saturated gold from the final palette.
Scores unchanged (4 across the board).
Tris: red 7738, blue 7378, green 7842, yellow 7858 (of 9000; max 87%); min silhouette diff 0.092;
full build BUILD PASS. Sheet: `previews/castle_gatehouse.jpg`.

## Round 5 (advisories from fresh review round 3)
Advisory: no slim gold shafts; shared emblems.
Changes:
- Gold front towers: wide squat drum (r 3.7, h 2.4) under a broad onion instead of a slim drum
  with a ring.
- The shield over the arch uses `field` / `border` and the shared emblem; the gold crest carries the
  sun on an ivory roundel.
- Emblems: castle banners, flags, shields and the gold gatehouse crest now use the shared helpers from
  `_kingdom_props_common.py` (`emblem`, `field`, `border`, `emblem_colors`). Emerald flies the bright
  cloth with an ivory border; gold gets a bronze border. The Sunspire sun always sits on an ivory
  roundel with a bronze rim, never on gold. Crown (red) and star (blue) are kept; the castle's own
  emblem outlines are deleted.
Scores unchanged from round 3 of the fresh review.
Tris: red_01 7906, blue_01 7558, green_01 8202, yellow_01 8594 (of 9000); min silhouette diff 0.0994; full build BUILD PASS.

Final: full (non-quick) build, see `previews/castle_gatehouse.jpg`.
