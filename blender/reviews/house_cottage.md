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

## Round 5 — fresh-context reviewer (D-019), on v3
- Reviewer saw only `previews/house_cottage.jpg` and the 03/06 hero renders. Scores 3 / 3 / 4 / 3 / 3 / 3 / 4 / 3. Verdict **NEEDS-WORK**.
- Findings:
  - every line was ruler-straight (not storybook);
  - three thatch roofs looked identical at distance, and the thatch read thin;
  - 03 and 06 shared one plan;
  - the wing roof buried an upper window;
  - the chimneys were tiny stubs;
  - triangles weren't spent where they show.

## Round 6 — v4 (author response to the reviewer)
- Kit changes (shared by every timber building):
  - tile roofs are lofted slabs with a ridge/eave sag;
  - timbers wander ±0.09 (hand-cut);
  - chimneys are tapered, with a mid band, a flared two-step cap, clay pots and a lean;
  - thatch is thicker (2× eave thickness) with more bulge, a zig-zag "pinned" ridge band, and 2 layers on small roofs.
- Cottage: six distinct archetypes:
  1. porch cottage;
  2. stone-ground two-storey with woodshed;
  3. round stair-tower house with an exterior chimney breast;
  4. catslide cottage with a rear outshut and dormer;
  5. front-wing thatched house;
  6. steep two-storey with dormer and exterior chimney.
- The upper storey leans ~1°. Wing-side upper windows moved clear of the wing roof. Straw tone varies (thatch/hay).
- Result: all 6 PASS, 3,892–4,994 tris; min silhouette diff 0.184 (v3: 0.167; v2: 0.134).
- Author scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3.
- Remaining:
  - 05 has only ~6 tris of headroom (4,994/5,000);
  - the green-kingdom turret cone can still read as a small tree from far away;
  - side walls are plain on single-storey variants.
