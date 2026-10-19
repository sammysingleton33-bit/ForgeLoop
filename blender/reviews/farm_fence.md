# farm_fence — author review log (FORGE-02 farm worker)

Asset ids `farm_fence_01..06`, budget `prop_small` (800). One 16-stud segment along X; the identical,
deterministic end post (0.8 sq, 3.35 tall) sits at x = -8 and +8 so segments chain at a 16-stud pitch.
Styles: 01 split rail, 02 picket, 03 woven wattle, 04 open double gate, 05 dry-stone wall + timber rail,
06 rustic log fence with X braces.

## Round 1 — first pass (quick build)
Images: `previews/farm_fence.jpg` (r1, overwritten), `scratchpad/farm/m.png` (gate + wattle close-ups).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 2 | 4 | 4 | 3 | 3 | 4 | 4 |

Problems seen
- Variation check FAILED (picket vs wattle 0.018): both a solid band in front view, and the shared end
  posts make every side silhouette identical.
- Everything a uniform orange `wood_light`; gate path stones looked like floating paper tiles.
- Gate: one leaf reads edge-on from the hero angle (checked from above: both leaves present, open inwards).

Changes
- Picket: wider spacing (1.15) so the front silhouette has gaps, pickets in front of the rails (side
  silhouette differs), scalloped tops dipping between posts.
- Gate path stones: thicker, rotated, sunk into the ground.

## Round 2 — palette + accents
Images: `previews/farm_fence.jpg`, `scratchpad/farm/fence_r2.jpg`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |

Changes: weathered rail mix (`wood`/`bark_light`/`wood_light`) on `wood_dark` posts; accents (third
detail level): flowers + grass at the picket foot, rope lashings on the rail fence, withy ties on the
wattle, moss caps + fallen stones + weeds on the stone wall, iron bolts at the X-brace crossings.
First try put grass tufts beside both end posts: that pushed the X extent past the posts (pivot moves,
sockets no longer at +/-8) and made all side silhouettes identical again (variation 0.076) — removed.
Result: 520-762 tris, variation min 0.119 (rail vs picket), all PASS.

Remaining weaknesses: rails are plain jittered boxes (no split-log section); the end post is deliberately
plain so mixed styles chain cleanly.

## Round 3 — final (full build)
Images: `previews/farm_fence.jpg` (final), `renders/farm_fence/farm_fence_0N_hero.png`, `farm_fence_gameplay.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |

Collision switched to fidelity `None` with explicit boxes per style (the gate gets two wing boxes, so its
7.6-stud opening stays walkable). Final 512-730 tris / 800, variation min 0.119, BUILD PASS.
Gate leaves open inwards (+Y); from the hero azimuth the right leaf is seen edge-on.
