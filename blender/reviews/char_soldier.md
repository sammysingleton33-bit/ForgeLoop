# char_soldier — author review log (D-019)

Generator: `generators/char_soldier.py` (+ shared kit `generators/_char_common.py`), budget `character` (2500).
12 variants = 4 kingdoms x (spearman, archer, knight). Hero view az 30 / el 10, lineup gap 2.5, gameplay 40 studs.
Scores 1-5: silhouette / variation / readability / proportions / palette / detail / cohesion / tri cost.
Round sheets were copied to the worker scratchpad (`r1/char_soldier_r*.jpg`); the committed
`previews/char_soldier.jpg` is the final full build.

## Round 1 — first pass (quick build)
Images: `previews/char_soldier.jpg` (round 1 state), `renders/char_soldier/char_soldier_01_hero.png`, `_05_hero.png`, `_12_hero.png`, `_gameplay.png`.
Validation: 8/12 FAIL budget (2786-3298 tris), variation FAIL (min 0.036, spearman red vs yellow).
Scores: 4 / 2 / 4 / 4 / 3 / 4 / 3 / 2.
Seen:
- Overall look works: chunky Roblox-scale humans, big head/hands/boots, kingdom tabard + emblem + pennant read well even at 40 studs.
- Cream gambeson sleeves (`tunic_cream`) read as bare skin / marshmallow arms next to `skin_1`.
- Knights look like spearmen with a sword: same open helmets, no distinct mass.
- Same-role variants were near-identical silhouettes (only the helmet differed) -> variation check fails; also bad for colour-blind players.
- Over budget: 5-ring spheres for shoulders/hands/knees, 7-station tabard lofts, outlined emblems everywhere, 24-point sun.
Changes:
- Triangle diet: limb balls 3-4 rings, plain soles, 2-ring boot shafts, 5-station tabard lofts with 4 points across, sun 8 rays, oak leaf 11 samples/side, emblem outline only where the fill needs it (yellow), plain buckles.
- Per-kingdom SHIELD SHAPES (red kite, blue heater, green round, yellow almond) and spear styles/tilts (red upright leaf blade, blue tilted pike, green winged spear leaning in, yellow broad blade leaning forward).
- Knights: closed great helm is the head shell (no hidden face geometry), kingdom-shaped tops (red sugarloaf + gold crown, blue flat top + square pyramid crest, green bascinet + oak-leaf crest, yellow onion + gold point), plume, pauldrons with trim rings, cape, per-kingdom weapon (red sword down, blue sword up, green bearded axe, yellow flanged mace).
- Gambeson recoloured to `apron`, gloves `leather`, trousers grey/brown.
- Yellow archer carries a short composite bow slanted across the front; blue archer gets a calf-length travelling cloak.

## Round 2 (quick build)
Images: `previews/char_soldier.jpg` (round 2 state), `renders/char_soldier/char_soldier_03_hero.png`, `_10_hero.png`.
Validation: 12/12 PASS (2146-2442 tris), variation PASS (min 0.121, archer red vs blue).
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 3 / 4.
Seen:
- Knights now clearly a third class (big helm + crest + plume + pauldrons); blue knight with raised sword and star heater is the strongest asset.
- Spearmen: kingdom readable from tabard, shield shape and pennant; helmet shapes echo the tower roofs (spire / pyramid / wide brim / onion).
- Archers: the dagged capelet hides the tabard emblem (only half the star visible); back quiver fully hidden behind the hood from the front and hero views, so the kingdom fletching never shows.
- Dark skin tones (`skin_3/4`) make the black eye shapes low-contrast (acceptable: Roblox face decals replace them).
Changes:
- Archer capelet shortened (`cape_len` 0.5), tabard emblem moved down to the belly (z 2.98) and widened.
- Back quiver tilted further over the right shoulder so the kingdom-coloured fletchings stick out beside the head.

## Round 3 (quick build)
Images: `renders/char_soldier/char_soldier_05_hero.png`, `_07_hero.png`, `_gameplay.png`.
Validation: 12/12 PASS (2146-2442 tris), variation PASS (min 0.121, archer red vs green).
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 3 / 4.
Seen:
- Archer emblems (flame / star / leaf / sun) now readable on the belly under the shorter capelet; bycocket + red feather makes the green archer the most characterful.
- The quiver strap still cut across the top of the archer emblem.
- Quiver fletchings show in front/side views beside the right shoulder; still hidden in the az-30 hero (camera is on the left side).
Changes:
- Strap re-routed higher (left waist -> right shoulder) so it clears the emblem; emblem 0.62 at z 2.92; bowstring thickened to 0.1 studs.

## Final (full build)
Images: `previews/char_soldier.jpg`, `renders/char_soldier/*_hero.png`, `renders/char_soldier/char_soldier_gameplay.png`.
Extra readability check (scratchpad, not committed): lineup rendered from 60 studs at 960x540 — all 12 kingdoms identifiable
by tabard + shield colour, roles by silhouette (spear + pennant / bow / grey plate + plume).
Validation: 12/12 PASS, 2146-2442 tris (budget 2500), variation PASS (min 0.121).
Final self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 3, tri cost 4.
Remaining weaknesses: black eye shapes are low-contrast on `skin_3/4`; spearman hero tiles are small because the spear sets
the framing; back quiver only visible from the side/back; hands are mittens (no fingers); little triangle headroom (~60-350)
for further detail on spearmen/knights.

## Fresh review round 5

- Reviewer: fresh-context subagent (contact sheet `previews/char_soldier.jpg` only, zoomed PIL crops incl. grayscale; manifest tris), 2026-10-13
- Verdict: **NEEDS-WORK**; per-asset overrides: char_soldier_02=PASS, char_soldier_03=PASS, char_soldier_04=PASS, char_soldier_06=PASS, char_soldier_07=PASS, char_soldier_08=PASS, char_soldier_10=PASS, char_soldier_12=PASS
- Scores: silhouette 4, variation 4, readability 3, proportions 4, palette 4, detail_density 4, cohesion 2, triangle_cost 3
- Notes: FAIL red 01, 05 and 09: the tabard and shield emblem is a gold FLAME. ART_DIRECTION retires the flame, and every red building, banner and flag in the kit uses the crown. 09 has a crown circlet on its helm, but its chest and shield still show the flame. Fix: the kit crown (three points + band, gold on red) on tabard and shield. FAIL 11: the orange shield boss sits on the centre of the ivory oak leaf and turns it into a flower (orange centre, ivory petals). Fix: move the boss or drop it on emblem shields. Kit note: the soldier oak leaf is a symmetric ivory lozenge with no stem or midrib, a third oak design that reads as a leaf only up close. At 40 studs in grayscale the red flame and green lozenge are both light blobs. Star (blue) and sun (yellow: cream roundel on tabard, gold sun on an ivory shield) are consistent and read correctly. Class silhouettes (spear, archer, knight) are clear; red and blue archers share an identical hood. Tris up to 2490/2500 (99.6%).

## Round 4 (fixes from fresh review round 5)
Fixes (D-039: crown, star, oak leaf, sun; the flame is retired everywhere):
- Red 01, 05 and 09: the gold flame on tabards and shields is replaced by the kit crown (three points on a band,
  gold with an ivory band and three ivory gems, as on the castle banners). `_char_common.crown()` builds cheap
  prisms from the shared outline `_kingdom_props_common.crown_outlines` (shared like `sun_outlines`, not copied).
  The flame outline is deleted from `_char_common.py` and the `flame` kind from `_kingdom_props_common.emblem`.
- Green 03, 07 and 11: the plain symmetric lozenge (no stem or midrib) is replaced by the kit oak leaf from
  `_kingdom_props_common.oak_outlines`: an ivory leaf with a bronze midrib and stem. `_char_common.oak()` uses the
  flat-topped lobe version (`lobe_pts=2`, same lobes, sinuses and proportions, 32 tris cheaper) to stay inside
  2500. The green knight's helm crest is the same leaf. Crown and oak drop the dark outline slab: they read on
  their fields. The star keeps its outline, so blue is unchanged.
- 11: the shield boss is gone. `shield()` only draws a boss on a shield without an emblem.
Tris: 01 2380 -> 2348, 03 2442 -> 2470, 05 2276 -> 2288, 07 2352 -> 2412, 09 2274 -> 2242, 11 2368 -> 2424
(of 2500). Blue and yellow (02, 04, 06, 08, 10, 12) keep their geometry hashes.
Seen (`renders/char_soldier/char_soldier_09_hero.png`, `_11_hero.png`, `_01`, `_05`, `_03`, `_07`, and the gameplay
render at 40 studs zoomed x3 with a grayscale copy): the crown reads as three points on a band, the same as the
castle crown. The oak reads as a lobed light leaf with a dark midrib line, not a flower. In grayscale at 40 studs,
crown, star, leaf and sun are four different shapes. On the archers (05, 07) the quiver strap still crosses the top
corner of the tabard emblem, as it did before.
Self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 3.
