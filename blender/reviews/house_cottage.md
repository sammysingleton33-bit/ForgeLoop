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

## Round 7 — v5 (cross-set rules from the fresh review and FORGE-00 calibration)
- Palette: thatch muted (`thatch` BFA36C) so straw never reads as the gold kingdom; gold kingdom made true gold
  (`yellow_roof` E0B12E, `yellow_cloth` E6B52A) instead of orange. Rules recorded in ART_DIRECTION §3.
- Thatch houses carry a kingdom ridge pennant (pole + flag at the ridge end away from the chimney); winged houses
  hang a kingdom banner on the wing in place of the flower box.
- Budget: the pennant pushed 03/05 over 5,000; trimmed the pennant tail, jetty joists 7 → 5 and the wing side-wall
  braces. Result: all 6 PASS, 3,870–4,976 tris; min silhouette diff 0.180.
- Looked at `previews/house_cottage.jpg`: thatch reads as pale straw next to the gold tile roof of 04; pennants are
  visible on 01/03/05 in the 80-stud strip. Remaining: the wing banner on 05 is small from the hero angle.

## Round 8 (D-033/D-039: kingdom emblem on the ridge pennant)
- Problem: the ridge pennant was plain kingdom cloth with no emblem, and only thatch houses (01, 03, 05: red and green) had one.
  Blue and gold cottages are always tiled, so they showed their kingdom by roof and shutter colour alone (D-033).
- Changes (`house_cottage.py` only; the shared helpers are unchanged):
  - The pennant is now a 3.6 × 3.4 square banner (was 4.2 × 1.9) on a 3-sided pole at the ridge end away from the
    chimney. It flies inward along the ridge and faces the street and the back. The old pennant faced the gable ends,
    so it was edge-on to the street.
  - The kit emblem fills the banner (0.24 margin). It is built as cheap prisms that pass through the cloth, so it
    reads from the front and the back:
    - crown: `crown_outlines`, gold, with the ivory band and three flat gems;
    - star: `emblem("star")`;
    - oak: `oak_outlines(lobe_pts=2)`, an ivory leaf with a bronze midrib and stem on the bright emerald field;
    - sun: `sun_outlines` on an ivory roundel with a bronze rim, on gold cloth (never gold on gold).
  - Tile cottages (02, 04, 06) now carry the pennant too. Its pole has a fixed tint, so the rng stream and the rest of
    the house are unchanged. The pole sinks 0.6 into a tile ridge and 1.5 into a thatch ridge. On houses with an
    exterior chimney, the pennant goes on the opposite gable.
  - 03 only: the side window was buried inside the exterior chimney breast, with one shutter edge poking out beside
    the stack. (Stair-tower houses move the breast to that gable.) The window is removed (−188 tris) to pay for the
    oak leaf. The rng draws are kept.
  - Scratch compare against HEAD: every other piece of all 6 variants is bit-identical.
- Result: all 6 PASS. Tris: 3,928 / 4,912 / 4,936 / 4,214 / **5,000** / 4,836 (budget 5,000). Min silhouette diff
  0.176 (was 0.180).
- Looked at:
  - `previews/house_cottage.jpg`;
  - the hero renders, cropped to the roof tops;
  - gameplay-strip crops, colour and grayscale. The strip is now at 82 studs because the newer `build.py` widens the
    strip to fit; each emblem is about 20 px across;
  - a back view of the lineup;
  - 03 from its chimney side.
- Author verdict: in grayscale at 82 studs, the crown, star and sun are clear by shape. The oak reads as a leaf with
  a stem, but it is the weakest: the lobes are about 1 px. The emblems also read from behind. From a gable end the
  banner is edge-on.
- Remaining:
  - 05 sits at exactly 5,000/5,000.
  - 05's wing banner still shows the plain diamond (left out of scope; a crown there needs budget 05 does not have).
  - The side-window pieces on every variant each get their own random y offset (pre-existing).
