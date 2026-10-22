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
