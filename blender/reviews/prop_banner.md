# prop_banner — author review log (D-019)

Images: `previews/prop_banner.jpg` (contact sheet), `renders/prop_banner/prop_banner_red_01_hero.png`,
`renders/prop_banner/prop_banner_green_01_hero.png`, `renders/prop_banner/prop_banner_green_02_hero.png`,
`renders/prop_banner/prop_banner_gameplay.png` (overwritten each round; scores were taken from the images of that
round). Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Types (2 per kingdom, each type twice): pole (red, yellow), mast (red, blue), wall (blue, green),
standard (green, yellow). Emblems: red flame + crown, blue star, green oak leaf, yellow sun.

## Round 1 (first quick build)
Scores: 4 / 3 / 3 / 3 / 4 / 3 / 4 / 2
Problems seen:
- Pole banners: the cloth hung *behind* the pole, so the pole cut through the middle of the cloth and hid the
  emblem (red_01).
- Emblems too small (0.62 x width) and blobby: the flame read as a tulip; the oak leaf as a thin feather.
- Standards: two narrow streamers beside the gonfalon read as a three-panel screen; "tails" bottom with tassels
  on the green wall banner looked torn/ragged.
- 4 of 8 over the 800 budget (rope lashing alone 160 tris, emblems up to 432); degenerate faces on the oak
  topper (collinear cap triangles in the strip solid); green_02 vs yellow_01 silhouette diff 0.048 (FAIL).
Changes: cloth + crossbar moved in front of the pole with a forward lean; emblems 0.74 x width; new flame
outline with a glowing inner tongue; fan solids without the mid ring where they stay flat; one-turn lashing;
3-sided tassels; streamers removed; standards given different heights/cloth sizes; strip-solid caps fixed.

## Round 2
Scores: 4 / 4 / 4 / 4 / 4 / 3 / 4 / 4
Problems seen:
- Oak leaf still reads as a feather (lobes under-sampled by the 10-station strip); cream leaf on green is weak.
- Green standard gonfalon small for its 15-stud pole; mast flags a little small next to their 20+ stud masts.
Changes: oak leaf rebuilt as a hand-drawn 22-point lobed outline (fan solid), bronze leaf with cream midrib and
veins; green standard cloth 5.6-6.0 x 6.6-7.0; mast flags 8.4-10.4 long, 4.6-5.5 high.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen: every emblem reads at 43 studs (flame, crown, star, oak leaf, sun); pointed / swallow-tailed / three-tailed
cuts and trim bands give each banner its own outline; wall banners have pelmet, rod and brackets.
Change after review: thinner, fewer oak veins (the cream veins looked like a fishbone).
Remaining weaknesses: the two mast flags share one silhouette family; cloth thickness (0.3) shows as a dark rim
in close-ups (intended: solid geometry); the sun disc is purple (yellow trim) which reads heraldic, not literal.

## Round 4 (cross-set emblem legibility, FORGE-02 lead review at 80 studs)
Problems reported: the oak leaf read as a symmetric scalloped oval (rosette/egg); the sun read as a white
8-10 point burst that competes with the blue star.
Changes in `_kingdom_props_common.emblem()` (signature unchanged, also used by farm/props):
- Oak: elongated leaf with 4 rounded lobes per side staggered between the sides (no mirror symmetry), deep
  sinuses, midrib, a visible stem, whole leaf tilted ~14 deg; concave outline built as a prism.
- Sun: purple roundel field + 8 short broad orange rays + large solid 12-sided gold disc; fixed colours so it
  contrasts with yellow cloth and is never white.
Budget: green standard cairn base made a plain box (half hidden) to fit two new leaves (788/800).
Seen (`prop_banner_green_01_hero.png`, `prop_banner_yellow_02_hero.png`): leaf reads as an oak leaf, sun reads
as a sun disc with rays and is clearly different from the star at gameplay distance. Scores unchanged
(4 / 4 / 4 / 4 / 4 / 4 / 4 / 4); tris 560-788 / 800.

## Fresh-review round 2 (FORGE-02 lead: NEEDS-WORK, cohesion 3 / palette 3 / readability 3)
Problems reported: red_01 flame (retired, reads as a fifth faction); yellow sun on a heavy purple roundel
(medallion / rosette) with butter-yellow cloth and purple trim.
Changes:
- red_01 now carries the crown (one emblem per kingdom); spear finial kept for red, pointed cut kept.
- Sun redesigned in `_kingdom_props_common.emblem()`: no roundel, no purple. 8 short broad dark-gold rays,
  a bright gold disc with a thin deep-bronze rim that covers the ray roots, so it reads as a sun, not a star.
- Gold cloth now comes from the palette's saturated `yellow_cloth`; trim / fringe deep bronze; gold finials.
- New helpers `field(k)` / `border(k)`: emerald banners use the bright `green_cloth_light` field with an ivory
  border (ART_DIRECTION 3); shared by every cloth/shield in this family.
Seen (`prop_banner_red_01_hero.png`, `prop_banner_yellow_01_hero.png`, `prop_banner_yellow_02_hero.png`):
crown / star / oak / sun each read at 43 studs; no purple anywhere; gold is saturated, not butter.
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4. Tris 560-788 / 800.

## Fresh review round 3

- Reviewer: fresh-context subagent (contact sheet `previews/prop_banner.jpg` only, zoomed PIL crops incl. grayscale; manifest tris), 2026-10-13
- Verdict: **NEEDS-WORK**; per-asset overrides: prop_banner_red_01=PASS, prop_banner_red_02=PASS, prop_banner_blue_01=PASS, prop_banner_blue_02=PASS, prop_banner_yellow_01=PASS, prop_banner_yellow_02=PASS
- Scores: silhouette 4, variation 4, readability 3, proportions 4, palette 3, detail_density 4, cohesion 3, triangle_cost 3
- Notes: FAIL green_01 and green_02: the oak leaf is orange-tan on the emerald field with an ivory midrib, and leaf and field have the same luminance (sampled L 115-119 vs 110-118). In grayscale the leaf disappears, leaving only the ivory midrib, a stick that reads as a feather, arrow or sword. This also breaks the kit: ART_DIRECTION and every building use an ivory oak leaf with an orange midrib (castle_gatehouse is the reference). The green_02 leaf finial has the same problem. Fix: invert to an ivory leaf with an orange or bronze midrib on both the banner and the finial. The other six pass: the crown, star and sun read at 43 studs. The sun is one design (gold disc + 8 rays in a cream 12-sided roundel on the cloth; bare sun as the yellow_01 finial), never gold-on-gold, and distinct from the bare 5-point star. Tris: yellow_02 790/800, yellow_01 780/800 and green_02 788/800 sit at about 99% of budget for a flat prop placed in numbers.

## Round 5 (fixes from fresh review round 3)
- The `FROZEN` mechanism and the legacy `oak_tilted` leaf are removed. Green 01 and 02 use the shared
  `emblem("oak")` (`_kingdom_props_common.oak_outlines`), as on the castle_gatehouse banners.
- Colours: `emblem_cols` now gives the oak an ivory leaf (`green_emblem`) with a bronze midrib and stem
  (`green_trim`), on the cloth and on the green_02 standard topper. Only the crown keeps gold with ivory accents.
  The dead `flame` branch is gone.
- Budget: the green_02 topper uses the flat-topped lobe version (`lobe_pts=2`), so the standard stays at 788/800.
Tris: green_01 628 -> 644, green_02 788 -> 788 (of 800). Red, blue and yellow keep their geometry hashes. The crown
helper now reads from `crown_outlines`, and the output is bit-identical.
Seen (`renders/prop_banner/prop_banner_green_01_hero.png`, `_green_02_hero.png`, and a gameplay crop at 43 studs
with a grayscale copy): the ivory leaf is far lighter than the emerald field in grayscale. It reads as a lobed leaf
with a dark midrib and stem, not a stick or feather. The ivory topper reads in colour. In grayscale it is lighter
than the sky but has low contrast against it (outline visible, weaker than the old orange topper).
Self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 3.
