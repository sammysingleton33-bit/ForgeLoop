# building_barracks — review log (author rounds, D-019)

Rubric: reviews/README.md. Scores are the author's honest self-assessment from the rendered images,
not from the code. Reference for cohesion: previews/house_cottage.jpg.

## Round 1 (v1, --quick, 4 variants)
Images: previews/building_barracks.jpg, renders/building_barracks/building_barracks_01_hero.png, _02_hero.png
Tris 9028–11728 / 12000. Validation PASS, variation min diff 0.171.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 3 | 4 | 4 | 4 | 3 |

Problems seen:
- Reads as a big manor / town hall, not a barracks: hall is too tall for its length (27 tall vs 40 long),
  and the cross-gabled entrance bay is a civic/house motif. Nothing says "fortified".
- Training dummies and archery butt stand far off the gable ends: they widen the frame to 56 studs, so the
  hall renders small, and at 80 studs the dummies are specks; the turret sometimes hides them.
- Turrets barely clear the main ridge (yellow onion dome is squat and reads as a blob).
- Weapon racks read as small fences; OK but low contrast.
- Triangle cost close to budget (11.7k): rack shields carry full emblems (sun/leaf ~100 tris each),
  plinth blocks are many small bevelled boxes.
- 01 and 03 (both timber upper floors) look alike apart from colour and turret corner.

Changes for round 2:
- Lower, longer proportions (stone hall 13–13.6, timber 10.4 + 8.4); hall length 40–43.
- New `bay` param: `keep` = crenellated stone gatehouse block rising above the eaves with a flagpole and
  big kingdom flag (military read), alternating with the cross `gable` bay across variants.
- Training yard moved to the front: dirt parade ground, dummies on one side, archery butt on the other.
- Taller turrets (walls to ~0.95 of the roof rise); taller onion dome.
- Cheaper rack shields (stripe instead of emblem), plain dummy feet, larger plinth blocks; ashlar accents.

## Round 2 (v2, --quick, 4 variants)
Images: previews/building_barracks.jpg (round-2 state), renders/building_barracks/building_barracks_03_hero.png, _04_hero.png
Tris 9368–11792 / 12000. Validation PASS, variation min diff 0.099.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 3 | 4 | 4 | 3 |

What improved: crenellated gatehouse + flag now says "military" at a glance; parade ground in front keeps
the hero frame on the hall; onion dome reads as a dome; turrets clear the ridge.
Problems seen:
- Parade ground in `dirt` is a saturated orange slab that reads like a carpet.
- Gatehouse flag too small at 80 studs (5.2 x 3).
- The big door reads as a single leaf (kit centre batten is the same dark brown as the leaf).
- Rack shields still carried full emblems (with_emblem default) — 03 at 11.8k tris.

Changes for round 3: pad in muted `road`; flag 6.4 x 3.8 on an 11-stud pole; iron centre seam + two ring
handles on the door; rack shields use the cheap pale/chief stripes; larger plinth blocks; back windows
without mullions; 6 variants (adds red hall+keep, blue timber+gable with a front turret).

## Round 3 (v2, --quick, 6 variants)
Images: previews/building_barracks.jpg, renders/building_barracks/building_barracks_02_hero.png
Tris 8612–11304 / 12000. Validation PASS (6/6), variation min diff 0.110 (01 vs 03).

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 |

Seen: at 80 studs every variant reads as long hall + flag/turret + banners + racks + dummies; kingdom identity
is unmistakable (roof, stone, banners, flag emblem, turret roof shape). The pad now grounds the yard quietly.
Remaining weaknesses: weapon racks still read partly as low fences at distance; dummies are human-scale so
small in the strip; the timber variants (01/03/06) share a facade rhythm. Tris 94% of budget on 03.

## Final build (v2, full renders, after the kit storybook pass)
Images: previews/building_barracks.jpg, renders/building_barracks/building_barracks_01_hero.png
Rebuilt against the updated kit (sagging lofted tile roofs, banded chimney with clay pots). My framing
helper now uses the same ±0.09 hand-cut wander as kit.wall_face_frame. Tilted legs of racks, easels and
dummies are clamped to z>=0 so the pivot sits exactly on the ground (sockets at Roblox y=0).
Tris 8734–11426 / 12000, validation PASS 6/6, variation min diff 0.111 (01 vs 03).

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 |

Remaining weaknesses: racks partly read as low fences at 80 studs; 03 uses 95% of the budget.

## Fresh review round 5

- Reviewer: fresh-context subagent (contact sheet `previews/building_barracks.jpg` only, zoomed PIL crops incl. grayscale; manifest tris), 2026-10-13
- Verdict: **PASS**; per-asset overrides: none
- Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail_density 4, cohesion 3, triangle_cost 4
- Notes: Each variant carries its kingdom's tower language, so grayscale identity holds even at 144 studs: red cone turret (01, 05), blue pyramid tower (02, 06), green hoarded lantern/cupola (03), yellow onion turret (04, ball + spike finial, no crescent). Two massing families (crenellated gatehouse front for 02, 03 and 05; half-timbered hall for 01, 04 and 06), and the same-kingdom pairs differ. The sun on 04 is the kit design (cream roundel), not gold-on-gold. Cohesion 3: the green emblem on 03's flag, banners and door shield is the symmetric ivory lozenge, which reads as a rosette or flower, not the kit oak leaf with a midrib. At 144 studs it is the same light dot as the yellow sun roundel. Use the castle_gatehouse oak leaf. Training dummies, targets and weapon racks give good function reads. Tris 8734-11426/12000.

## Round 4 (fixes from fresh review round 5)
- 03 (green): the symmetric ivory lozenge (a rosette) on the flag, banners and door/gable shields is replaced by the
  kit oak leaf: `_village_large_common.emblem("green")` now merges `_kingdom_props_common.emblem("oak")` (ivory leaf,
  bronze midrib, visible stem), the castle_gatehouse design. The two big wall banners use the full round lobes. The
  shields and flag use the flat-topped version (`lobe_pts=2`) to keep headroom.
- Other variants keep their geometry hashes. tavern and workshop do not use these emblems, and verify passes.
Tris: 03 11426 -> 11698 / 12000. Variation min diff 0.111 (01 vs 03), PASS.
Seen (`renders/building_barracks/building_barracks_03_hero.png`, zoomed crop, and the gameplay strip at 144 studs in
grayscale): in the hero, the banners, door shield and flag show an ivory lobed leaf with an orange midrib and stem,
the same as the castles. At 144 studs every emblem is a few pixels. Kingdom identity there still rests on the
tower language.
Remaining: the red crown here (01, 05) is still the village single-colour cream outline, not `crown_outlines`.
Self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 3.
