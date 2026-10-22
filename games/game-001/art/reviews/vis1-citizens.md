# Visual upgrade pass 1, stream C: citizens at the start frame (FORGE-02, 2026-10-22)

Owner: "citizens are barely recognisable at the default aerial camera". Branch `forge/02-blender-visual-citizens`. Preview renders are Blender
(Cycles), not Studio; the lighting is the preview's approximation of `world/Lighting.luau`.

## What I measured (`blender/scripts/citizen_screen.py`, from the dump; rest pose; the sim's 13 crimson citizens)
Camera = the real start view: the dump's `start` {zoom 70, fov 55, pitch 42.5, ahead 20, turn 180}; far = zoom 220 (pitch 65); legacy = the B22 camera
(zoom 120, FOV 70, pitch 50, focus on the throne). `figure` includes hat and tool, `body` is head + torso + arms + legs.

| view | studs / px at the focus | figure h (median, min-max) | body h (median) |
|---|---|---|---|
| start, desktop 1920 x 1080 | 0.067 | 65.9 (46-85) px | 57.4 px |
| start, phone 750 x 311 | 0.234 | 19.0 (13-24) px | 16.5 px |
| far (zoom 220), desktop 1080p | 0.212 | 27.3 (20-30) px | 19.3 px |
| far, phone | 0.736 | 7.9 (6-9) px | 5.6 px |
| legacy (zoom 120), desktop 1080p | 0.156 | 34.1 (31-56) px | 30.6 px |
| legacy, phone | 0.540 | 9.8 (9-16) px | 8.8 px |

11 of the 13 crimson citizens are inside the start frame (13 of 13 at zoom 220). The camera change (FL-0147) is the big win: about 1.9 x the legacy
pixels on desktop and on the phone. The brief's thresholds (12 px phone / 24 px desktop): the start view passes both (16.5 / 57); the far view
fails both (5.6 phone / 19.3 desktop), and no scale in the 1.15 to 1.3 range changes that (see the handoff for the arithmetic).

## What the citizens were (before, on the real start positions)
Brown on brown: the hauler's sleeves and sack were dE 2 and 4 (CIELAB) from the field colour (`Ground`), idle trousers 0 from `Mud`, the miner's ochre
pot 25 and the farmer's straw 31 from the fields, builder tan 18, woodcutter umber 9 from the mud. Every working citizen carries the kingdom torso
(red in crimson) so jobs were told apart by a small hat and a tool only. In the 1:1 crops the haulers were two brown blobs on a brown road.

## What I changed (Kit/Character.luau, colours only: no part added, no size, no scale)
Every hat, panel, trouser and sack colour is now dE >= 32 from Grass, LeafyGrass and Ground and >= 22 from Mud and Cobblestone in every dyed variant
(`KitCitizenAerial.spec`, reading the live `terrainColors`): farmer golden straw hat, white shirt, blue trousers; woodcutter ink beanie, slate
flannel, ink trousers; miner safety-orange pot, steel-blue panel, slate trousers; builder white hard hat, hi-vis orange canvas, deep blue trousers;
hauler blue smock, plum trousers, pale grain-yellow sack (white merged with the builder's hat); outfit neutrals: tunic / sleeveless / apron /
jerkin trousers and the vest are blue, plum, teal, white or slate instead of the browns; linen and the apron are near white (the new, paler cobble made
cream only dE 18 to 21 from the court). The hat value bands (woodcutter < miner < farmer < builder, gaps 0.15 or more) and every KitCharacter rule hold.
The mesh kit (`CharacterMeshData`, the owner's pending import) is untouched: its fixed hat and sack colours (`blender/generators/_charkit_style.py`,
BURLAP 146,108,70 etc.) still carry the old browns; its cloth pieces take the new panel colours through `Character.clothColor`.

## What I saw (opened): `img/vis1-citizens-{before,after}-{default_crimson,default_phone_crimson,default_azure,far_crimson}.jpg`
and the true-size crop sheets (`...-crops-start-1080-1to1.jpg`: the 13 crimson citizens, 128 px tiles at 1:1 for a 1080p desktop; `...-crops-start-phone-x3.jpg` and
`...-crops-far-phone-x3.jpg`: 750 x 311 scale, tiles shown 3 x nearest; `blender/scripts/citizen_crops.py` renders each citizen with the start camera centred on it)
- Start frame, desktop (`default_crimson`): the citizens are 45 to 60 px figures at 1600 x 900. After: the keep-door hauler's
  sack is a yellow disc instead of a brown lump, the storehouse builder and hauler have white hat / orange sleeves / blue smock, the miners' pots read
  orange; the three farmers on the crop beds are still a column of three gold hats with red crowns (the sim stands them 3.5 studs apart in depth, so the
  camera stacks them; they read as three hats, not one blob, at 1080p, and as a small gold cluster at 750 x 311).
- Phone (`default_phone_crimson`): the figures are 13 to 24 px; hats are 4 to 6 px dots. The yellow sack at the keep door is the one citizen that is
  clearly new; most others are red-and-dark dots in both pictures. Honest reading: on the phone the pass helps hauler, miner and builder, hardly the woodcutter
  (ink beanie, slate sleeves: the red torso is what shows) and not the farmers.
- Far (`far_crimson`): figures are dots (5.6 px body on a phone); colours differ a little, shapes do not. Not fixable by colour.
- Azure: same wins (white builder hat, orange sleeves, gold hats on blue/white buildings).
Defects: the woodcutter is the job that changed least (dark on the grass, the kingdom red dominates); at 128 px 1:1 tiles every job reads, at the
phone scale only by hat and sleeve colour.

## Not done, and why
- No scale: the start view already meets the thresholds; a global bump belongs to EntityController (FORGE-01/04): proposal in the handoff.
- No outline / under-shadow disc: needs a part per citizen (the rig caps at 11 parts, MAX_PARTS, D-032/D-048); Roblox's shadows ground them already.
- `Kit.characterLod` (one part) is not used by the game: EntityController unparents rigs beyond LOD_HIDE = 150 studs (line 94; `math.max(Def.LOD_HIDE,
  Def.LOD_ZOOM * zoom)` at line 593), i.e. 150 studs at the start zoom and 275 at zoom 220, so every citizen in view is the full rig.
- The carried-goods pose (`Kit.carried`, PR #312) is not merged here: the gold hauler's `carry` row is drawn as `walk`.

## Blind D-019 review (fresh reviewer, image-only; two contact sheets of start crimson, start azure, far crimson; key kept by FORGE-02: A = after, B = before)
- **Verdict: no meaningful difference. Both sets NEEDS-WORK for "citizens readable"** (recognisability 2 of 5 at the default camera, 1 of 5 far). The reviewer picked about 4 to 6 people per view as specks 10 to 20 px tall, could not name any job (the red / blue clothing says the kingdom, not the work), and if forced preferred A (the after set) "marginally, low confidence": the castle-door figure is darker and higher-contrast, and there may be one more small figure at the top right. Its one change: "make citizens roughly twice as large at the default camera, and give each job a distinct high-contrast tunic or hat colour that differs from the kingdom colour."
- So the colour pass is real (the hauler's sack and the builder's hat and sleeves read where they did not; 1:1 crops confirm) but **it does not solve "barely recognisable"**: at the pixel size a citizen has at the start frame (about 57 px desktop, 16.5 px phone, body), colour cannot carry a job. The lever is size (and the head / hat / tool silhouette), not palette. See the handoff's scale proposal.

## Silhouette pass 2 (2026-10-22): bigger head, hat, tool and sack at the same part count
After the blind verdict above ("no meaningful difference"), `Character.luau` draws a citizen's silhouette parts bigger: head x1.3 (1.6 -> 2.08, sits 0.07 higher), hats x1.3 (the farmer's straw
disc x1.1 so neighbours 3.5 apart do not overlap), hand tools x1.3 about the butt (the mallet x1.15, leaning 24 degrees), the hauler's sack x1.15 (3.1 across); torso, arms, legs,
joints, Pose and the part count are unchanged (idle 8, working 11). Measured with `citizen_screen.py` on the sim's 13 crimson citizens, body (head + torso + arms + legs):
start 1080p 57.4 -> 62.8 px (x1.25 ScaleTo: 79.1), start phone 16.5 -> 18.1 px (x1.25: 22.8), far 1080p 19.3 -> 20.0 (25.0), far phone 5.6 -> 5.7 (7.2). The pass alone does not
reach 75 / 22 (only the head grew: +9 % in body height); with the x1.25 FORGE-04 will add it does. Renders `img/vis1-citizens2-{before,after}-*.jpg` (and `after-x125-*`), crops
`...-crops-start-1080-1to1.jpg` and `...-crops-start-phone-x3.jpg` (opened): at 1:1 on a 1080p desktop the heads and hats are visibly bigger and every job still reads (gold
disc with red crown, ink beanie with red pompom, orange pot, white hard hat, yellow sack); the figures look chibi (a 2.1 head on a 1.9 to 2.3 torso). On the full 750 x 311 frame
the figures are still specks (about 20 px, 26 px with x1.25): the keep-door hauler's sack and the gold farmer stack are the only ones you notice, so on the phone the change is small
and a larger camera or scale is still the real lever. Defects: the three farmers stand in a column in depth and their discs read as one stacked tower at phone size; with x1.25 the
farmer's disc (4.3) is wider than the 3.5-stud work slot spacing (handoff).

## Scale comparison for FORGE-00 (same crimson start frame, FL-0147 camera, sim citizens, silhouette pass 2; Blender preview, citizens scaled about their feet in the dump)
`img/vis1-citizens-scale-desktop.jpg` (1:1 crops of the 1600 x 900 render around the keep door, the farm and the quarry), `img/vis1-citizens-scale-phone.jpg` (750 x 311 at 1:1), `img/vis1-citizens-scale-house.jpg` (the storehouse with two builders and a hauler). Body height (head + torso + arms + legs), crimson sim set:

| scale | start 1080p | start phone | what I see |
|---|---|---|---|
| x1.0 (this PR alone) | 62.8 px | 18.1 px | specks; farmers' discs and the keep-door hauler's sack register |
| x1.25 (FORGE-04's ScaleTo, approved) | 79.1 | 22.8 | both numeric targets met; figures read as people, jobs still mostly a guess except farmer (disc) and hauler (sack) |
| x1.6 | 100.5 | 29.0 | clearly readable: hats, tools and sacks all register at the start frame; the hauler is about two thirds of the keep door's height; farmers' discs (5.5 studs wide) overlap their 3.5-stud work-slot neighbours in plan |
| x2.0 | 125.6 | 36.2 | tips into toy giants: the hauler's head is level with the keep door's top, its sack as big as the door arch, a builder as tall as the storehouse's eaves |

The numbers for x1.6 and x2.0 are the x1.0 measure times the factor (the measure is linear in the scale). Not Studio: ScaleTo scales about the model pivot, EntityController decides the feet (root height) and the bubbles.
