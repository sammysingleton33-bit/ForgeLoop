# Review log — house_cottage

Rubric and thresholds: `reviews/README.md`. Scores: silhouette / variation / readability / proportions /
palette / detail density / cohesion / triangle cost.

## Round 1 — v1 (FORGE-02 author review)
- Images: first renders came out **black**: `Image.pack()` wiped the generated palette (fixed: palette saved as a PNG and loaded from disk).
- Then the first contact sheet (v1, 4 variants): scores 3 / 3 / 3 / **2** / 3 / 3 / 3 / **2**.
- Problems: doors (4.6) shorter than the 5.5-stud character, so the whole scale was wrong; the thatch was one flat plastic slab; the lighting was dull; 7,068 tris on the 2-storey variant (bevels on every small box).
- Changes: human-scale standard in `lib/kit.py` (door 4.4 × 7.6, storey ~11, timber 0.62); bevels only on big parts; warmer, stronger sun.

## Round 2 — v2
- Sheet `previews/house_cottage.jpg` (v2). Scores 4 / 3 / 4 / 4 / 4 / 4 / 4 / 4.
- Problems: thatch rows read as striped planks; the lean-to roof was rotated the wrong way (it stuck out sideways on 05); the gameplay lineup overflowed the frame; 05 was 5,116 tris (over the 5,000 budget).
- Changes: thatch rebuilt as one lofted profile (stepped bulges, rounded eave lip, rolled ridge, sag, wavy eaves, smooth shading); lean-to rotation sign fixed; lineup fitted into the 40–80 stud band.

## Round 3 — v2 (lofted thatch)
- Hero renders at 900 px checked (`house_cottage_05`, `house_cottage_02`). Scores 4 / **3** / 4 / 4 / 4 / 4 / 4 / 4.
- Good: the thatch now reads as soft straw; tile rows, barge boards, jetty joists, quoins and woodshed sell the style at 80 studs.
- Problem: **variation 3**: every variant is the same rectangle with a gable roof (closest pair diff 0.134).

## Round 4 — v3
- Changes: L-plan front-gabled wing (03, 06), attic dormers on tile roofs (04, 06), gabled porch (01); upper windows move clear of the wing roof; a triangle diet (bigger plinth blocks, single-box wing plinth, 4-row main roof on the busiest variant, no crate on winged houses).
- Result: all 6 PASS validation, 3,628–4,992 tris (budget 5,000); min silhouette diff 0.167 (was 0.134).
- Scores (author): 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3 (06 sits at 4,992/5,000, so it has no headroom).
- Remaining weaknesses: plain chimneys; side walls have little detail; the yellow kingdom roof reads orange next to the thatch.
- Next: fresh-context reviewer (D-019) and user calibration.
