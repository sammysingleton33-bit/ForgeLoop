# building_workshop — review log (author rounds, D-019)

Rubric: reviews/README.md. Scores are the author's self-assessment from the rendered images.
Reference for cohesion: previews/house_cottage.jpg (v4 storybook kit).

## Round 1 (v1, --quick, 6 variants)
Images: previews/building_workshop.jpg (round-1 state), renders/building_workshop/building_workshop_01_hero.png, _02_hero.png
Tris 6154–6794 / 8000. Validation PASS, variation min diff 0.075 (02 vs 05) FAIL.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 3 | 2 | 3 | 3 | 4 | 3 | 4 | 4 |

Problems seen:
- 02 and 05 are the same building (house left, jib crane, same massing) -> variation fail.
- The open shed interior is in deep shadow; the log on sawhorses and the tool wall vanish in the hero view.
- Plank stacks read as low pallets (4 thin layers).
- The jib crane stands behind the shed, so its jib barely shows; the jib timber is thin.
Changes: new params `bays` (2 or 3 shed bays, 15–24 studs) and `storeys` (1 or 2 for the house, framed
upper floor); taller shed (posts 9.3–9.8); larger plank stacks; thicker jib and bigger pennant; crooked
timber wander in the framing helper (kit storybook pass); trimmed stone pads and stack spacers for budget.

## Round 2 (v1, --quick)
Images: previews/building_workshop.jpg (round-2 state), renders/building_workshop/building_workshop_03_hero.png, _06_hero.png
Tris 6578–7518, variation min diff 0.191 PASS.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 3 | 4 | 4 | 3 | 4 | 3 |

Problems seen: variants now clearly differ (2- vs 3-bay shed, 1- vs 2-storey house, wheel vs jib), but the
sawing job is still hidden under the shed roof, and the jib-crane variants show the jib foreshortened
behind the shed. Stacks sit in front of the shed bay and crowd the open front.
Changes: log-on-sawhorses with the crosscut saw moved to the open yard in front of the open bay; plank
stacks turned front-to-back beside the shed under the jib tip (deposit point in front of them); mast moved
to the shed corner with a longer jib swinging out sideways over the stacks; treadwheel beside it; shed
front overhang reduced and posts raised to 9.8–10.3; larger dirt yard pad.

## Round 3 (v1, --quick)
Images: previews/building_workshop.jpg (round-3 state), renders/building_workshop/building_workshop_04_hero.png, _01_hero.png
Tris 6602–7502 / 8000, validation PASS 6/6, variation min diff 0.177.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 |

Seen: at 80 studs each reads as open shed on posts + plank stacks + crane mast/jib (or treadwheel) + small
house; the sawhorse job is now in the light. Problem left: in 04 the house and shed both carried yellow
tiles and merged into one roof -> 04 house switched to thatch. Remaining weaknesses: shed interior (tool
wall, bench) stays dark at gameplay distance; when the crane is on +X the jib points at the hero camera
and foreshortens; tris up to 94% of building_medium.

## Final build (v1, full renders, after the kit storybook pass)
Images: previews/building_workshop.jpg, renders/building_workshop/building_workshop_05_hero.png
04 house switched to thatch (no more merged yellow roofs); sawhorse/rack/A-frame/strut legs and the
jittered sawdust mound clamped to z>=0 so the pivot sits on the ground.
Tris 6602–7502 / 8000, validation PASS 6/6, variation min diff 0.180 (01 vs 03).

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 |

Remaining weaknesses: shed interior (tool wall, bench) is dark at distance; jib foreshortened in the hero
view when the crane is on +X (02/04/05); tris up to 94% of building_medium.
