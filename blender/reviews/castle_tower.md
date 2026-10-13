# castle_tower: review log (FORGE-02 worker, D-019 author rounds)

Rubric: `reviews/README.md`. Scores are the author's honest self-scores. The independent verdict
(`castle_tower.json`) is written by the fresh-context reviewer, not here.
Images: `previews/castle_tower.jpg` (committed, final); per-round sheets were kept in the worker
scratchpad (`castle/sheets/tower_rN.jpg`) and heroes in `renders/castle_tower/` (git-ignored).

## Round 1 (first quick build)
Scores: silhouette 3, variation 4, readability 4, proportions 2, palette 4, detail 4, cohesion 4, tri cost 2.
Problems seen:
- Crowns far too small: the spires, pyramids and domes sat on narrow drums like little hats on slender
  shafts. Not storybook, and the kingdom roof (the identity lever) was weak at 60+ studs.
- The red_01 drum was hidden behind the merlons; the yellow_02 kiosks were tiny clutter.
- 5 of 8 variants were over the 6000 budget (7.3k–9.6k). The kit-door voussoirs (~540 tris per
  door) and bevelled merlons (88 tris each) were the main costs.
- Pivot was off the tower axis because moss clumps and batter blocks made the bounds asymmetric
  (a tower must sit exactly on a wall joint).
Changes:
- Rewrote the crowns. red_01 and blue_01 now carry a full-width roof (spire / pyramid) resting on the
  merlons, like a roofed fighting gallery, with a gabled dormer. red_02 has a drum + spire + stair
  turret with a needle spire. yellow_01 has a big onion dome on a windowed drum.
- Cheaper shared parts in `_castle_common.py`: segmented voussoir arches (12 tris per stone), plain-box
  merlons with bevelled caps, 2-step corbels, 4-box arrow slits, cheap finials/domes for small turrets.
- Foundation apron (radius R+2.5) defines symmetric bounds; moss is clamped inside it.

## Round 2
Scores: silhouette 4, variation 4, readability 5, proportions 3, palette 4, detail 4, cohesion 4, tri cost 3.
Problems seen:
- Big roofs work: red_01 and blue_01 read instantly, green hoardings read well.
- red_02 drum + spire still smallish; yellow_02 central dome too low; green_02 lookout too subtle.
- red_02 and yellow_02 still slightly over budget.
Changes: red_02 drum r4.7→5.3 and spire 19→21; yellow_02 dome r5.0→5.2, h6→7.6; green_02 lookout
r2.5→3.0 with 8 posts, breastwork panels and a bigger cone; cheaper stepped merlons, kiosk domes (6 seg),
half-dome ribs; dropped one side slit on square towers.

## Round 3
Scores: silhouette 4, variation 4, readability 5, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Seen: every kingdom's roof language reads at 80 studs: red spires (with a stair-turret needle on
_02), blue crisp pyramids / corner bartizans, green timber hoardings with low cones, yellow onion
dome / domed kiosks. Masonry courses, corbel tables with machicolation slots, banners and shuttered windows
give three levels of detail. An assembly render (castle front with walls, towers on the joints,
keep and two cottages; scratch only) confirmed the towers cover wall ends and sit with the village.
Tris 4.5k–5.9k / 6000, all PASS, min silhouette diff 0.090.
Remaining weaknesses: shafts share one body design across kingdoms (identity is in the crown and
stone colour); red_02 / blue_02 / yellow_02 have little budget headroom (<200 tris).

## Round 4 (FORGE-02 lead review fixes)
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
Scores unchanged (4/4/5/4/4/4/4/4); palette now reads gold, not orange.
Tris red 4568/5876, blue 4552/5900, green 4624/5144, yellow 5582/5950 (of 6000); BUILD PASS (full build), min silhouette diff 0.089.

## Round 5 (fresh-context review follow-up)
Reviewer (fresh context): NEEDS-WORK, palette 2 (green roofs measured as grass #457c40, gold
domes at saturation 0.5; both from the stale palette).
Shared changes (`_castle_common.py`): ashlar blocks are now 8-tri wedges (`stone`). The front face is
unchanged and the top and bottom slope back to a hidden ridge, giving a built-in chamfer and a deep
mortar joint. That wins back about 10% of the budget with the same outline. Dark dome rib dashes,
which read as cracks, are removed by default. Rebuilt on the final palette (emerald 23805F, gold
EBB910, goldenrod shutters).
Changes:
- Rebuilt: green hoardings and cones read emerald, domes read saturated gold.
- yellow_02: the central dome is a true onion (bulb, pinched neck, pointed tip) on a tall slim raised
  drum (11 high), so it stands clear above the corner kiosks at eye level; body walk 31 -> 29. Kiosk
  lintels are ivory with only a thin purple band.
- yellow_01: broader onion bulb on a shorter drum, so the two yellow towers diverge (they briefly failed
  variation at 0.071 once both had onions).
- red_02 vs red_01: red_02 is now a spire cluster. The stair-turret needle spire is taller (tip near
  the main spire) and two corbelled front turrets with needle cones stand in the parapet ring (merlons
  skipped there). Small spires use a lighter finial.
Scores: silhouette 4, variation 4, readability 5, proportions 4, palette 4, detail 4, cohesion 4, tri cost 4.
Tris: red 4164/5708, blue 4104/5400, green 4260/4784, yellow 4770/5442 (of 6000); min silhouette
diff 0.091; full build BUILD PASS. Sheet: `previews/castle_tower.jpg`.
Remaining: red_02 sits at 95% of budget because of the added turret cluster.

## Round 6 (advisories from fresh review round 3)
Advisory: no slim-shaft + small-dome + ring silhouettes in the gold kingdom; shared emblems.
Changes:
- yellow_02: the raised drum is chunky (r 4.9, h 8.4) under a true onion (r 5.1), not a slim
  shaft. Kiosk posts are 0.85 thick.
- Emblems: castle banners, flags, shields and the gold gatehouse crest now use the shared helpers from
  `_kingdom_props_common.py` (`emblem`, `field`, `border`, `emblem_colors`). Emerald flies the bright
  cloth with an ivory border; gold gets a bronze border. The Sunspire sun always sits on an ivory
  roundel with a bronze rim, never on gold. Crown (red) and star (blue) are kept; the castle's own
  emblem outlines are deleted.
Scores unchanged from round 3 of the fresh review.
Tris: red_01 4228, red_02 5772, blue_01 4172, blue_02 5468, green_01 4388, green_02 4912, yellow_01 4966, yellow_02 5614 (of 6000); min silhouette diff 0.09; full build BUILD PASS.

Final: full (non-quick) build, see `previews/castle_tower.jpg`.
