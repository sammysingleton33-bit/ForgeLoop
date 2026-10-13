# siege_ram — author review log (D-019)

Images: `previews/siege_ram.jpg`, `renders/siege_ram/siege_ram_red_01_hero.png`, `renders/siege_ram/siege_ram_gameplay.png`.
Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Variants: red hide-roofed shed (lashed wet hides, drapes, pennant), blue open A-frame ram, green plank roof
(shared-kit tile roof in timber colours) with a planked gable hoarding + shield, yellow striped canvas roof
in kingdom cloth with gilded dome finials. All: 4 spoked iron-tyred wheels, log on rope slings, iron head
with kingdom emblem plates, pushing bars, side shields.

## Round 1 (first quick build)
Scores: 4 / 4 / 4 / 4 / 3 / 4 / 4 / 4
Problems seen:
- Hide roof coloured as a regular checkerboard: reads as a quilt, artificial.
- Side shields faced inwards (shared bug with the catapult).
Changes: hides as irregular seeded patches of 1-3 cells in leather tones, sagging between rafters, rope
lashings over them; shield rotation fixed.

## Round 2
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen: four distinct roofs read at 40 studs (hide / open frame / planks / striped canvas); the iron ram head
with emblem plates points front; tris 2672-3672 / 4000; min silhouette diff 0.106 (green vs yellow, same
frame, different roof).
Remaining weaknesses: green and yellow share the same shed frame; the ram log is partly hidden under the
roofed variants from high cameras.

## Fresh-review round 2 (FORGE-02 lead: NEEDS-WORK, palette 2 / variation 3 / readability 3)
Problems reported: red/green/yellow were one gable shed with different roofs; blue's open A-frame read as a
catapult; red shield flame; yellow sun a purple crescent and a pale gold/cream striped roof with purple trim.
Changes (one cover per kingdom, different pitch / drape / front):
- red: hides at 40 deg on posts, kingdom drapes, ridge pennant, crown shields and head plates.
- blue: Frostmere "tortoise", a 62 deg slate-shingle roof straight off the rails (no walls), A-trusses, star
  shield above an oversized steel head (x1.5) with a flared collar.
- green: steep 56 deg plank roof, planked gable hoarding with oak shield.
- yellow: low 24 deg roof of neutral hides cloaked far down the sides, gold-cloth hem band, gold ball
  finials, a tall sun pavise standing in front of the ram (no canvas stripes, no purple).
Seen (`siege_ram_blue_01_hero.png`, `siege_ram_yellow_01_hero.png`, sheet): four silhouettes (min diff 0.27),
none reads as a catapult. Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4. Tris 2744-3632 / 4000.

## Fresh-review round 3 (final; FORGE-02 lead notes)
Problems reported: blue roof almost all royal blue and an oversized pale head (boulder / face); green lacked
pennant and emerald shields; yellow sun gold-on-gold and no pennant.
Changes: blue tortoise roofed in neutral timber shingles with azure ridge cap, barge boards and eave hem
boards, 3.0 star shield on the gable, and the same dark iron head on a visible log as the others; green gets
an emerald pennant and emerald oak shields with ivory borders (3.0-3.2); yellow pavise 3.6 with the sun on an
ivory field plus a gold pennant; side shields 3.0 angled 45 deg toward the front camera.
Seen (`previews/siege_ram.jpg`): four covers read apart, kingdom colour now as trim/shields/pennants.
Tris 2740-3808 / 4000, min silhouette diff 0.27. Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4.

## Fresh review round 4

- Reviewer: fresh-context subagent (contact sheet `previews/siege_ram.jpg` only, incl. zoomed crops and grayscale check), 2026-10-13
- Verdict: **PASS**
- Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail_density 4, cohesion 4, triangle_cost 3
- Notes: Four roof forms (red open hide-covered gable, blue A-frame tortoise, green steep plank shed, yellow hide box with gold skirt) and large kingdom shields that read well at 40 and in grayscale. The sun shield is a clear sunburst. Weakness: the ram log barely protrudes past the front frame, and on blue/green/yellow the head reads as a grey boulder inside a shed, so the object reads as a covered wagon or hut on wheels before it reads as a ram. Extend the log 2-3 studs beyond the frame with a shaped iron head like red_01. green_01 is 3808/4000 (95%) of budget.
