# Kit characters, looks and regalia review log (FL-0056 + FL-0085) — FORGE-02

D-019 preview loop for `src/shared/Kit/Character.luau` (VS-1 rows 2 and 4; CONTRACTS G4 rendering, G10, G13.2).
Renders: `blender/scripts/render_kit.py` over two Lune dumps — `KitDump.spec` → `characters` (5 jobs × 4 kingdoms +
soldiers, default look) and `KitCharacterDump.spec` (`FORGE_KIT_CHAR_DUMP`) → `characters_lineup`,
`characters_looks`, `characters_aerial`, `characters_turn`, `characters_lod`, `regalia_fit`. The preview has no
Roblox material textures and no decals (the face decal is invisible here); Studio decides the final look (D-026).
Scores 1–5: silhouette / variation / readability at gameplay distance / proportions / palette / detail density /
cohesion / part cost.

Starting point (c772f96): R6-style blocks — 2×2×1 torso, block head, iron box head on soldiers, tools hidden
inside the arm, invisible Root. Sheet `kit_characters.jpg` (since overwritten). Scores ≈ 2 / 1 / 2 / 3 / 3 / 1 / 3 / 5.

## Round 1 — first design (quick, `kit_characters_lineup.jpg`)
Ball heads (1.7), chibi torso, per-job sleeve/trouser colours, tool table, governor (gold sleeves, robe legs,
gold staff), LOD, crown with points + cape.
- Ball heads too big and bald ("eggs"); tools almost invisible: hoe/spear/staff ran through the arm, axe/pick/
  hammer heads hung below the fist edge-on to the camera; hauler's sack invisible from the front.
- Soldier: steel drum helm read as a tin can. Scores ≈ 3 / 2 / 2 / 3 / 3 / 2 / 3 / 5.

## Round 2 — variant lab (quick, `kit_characters_lab.jpg`, temporary lab spec since deleted)
Compared drum / ball / block heads, three axes (hatchet wedge, tall wedge, plain handle), two picks, two
mallets, box vs ball helm. Findings: shafts must sit in front of the fist (GRIP −0.55 Z); a one-part tool
cannot show handle + head, and in a swing the arm reads as the handle, so swing tools become oversized heads at
the fist; box helm reads "knight", ball helm reads "ball"; drum heads look like cans when tall.

## Round 3 — chibi proportions and tools (quick, `kit_characters_lineup.jpg`, `kit_characters_turn.jpg`)
Legs 1.8 / torso 2.0 / ball head; arms splayed 7°; swing tools turned 40° outwards (visible from front and
side); axe = bearded steel wedge, pick = tapering iron spike, hammer = big wooden mallet drum; sack = burlap ball
over the right shoulder (a cream ball read as a second head; a block read as a crate); stocky torsos for
woodcutter/builder/hauler. Turnaround checked side and back: axe, pick and sack read from behind.
Scores ≈ 3 / 3 / 3 / 4 / 3 / 2 / 4 / 5.

## Round 4 — regalia and LOD (quick, `kit_regalia_fit.jpg`, `kit_characters_lod.jpg`)
Regalia on stand-in R15 and R6 avatars, front and back. Crown (gold band, five points, kingdom jewel) sat well;
added a kingdom velvet cap so it reads from above. Cape: the ermine roll looked like a scroll rod and floated on
R15 → removed; now a 2.5-wide kingdom panel hanging from +0.85 above BodyBackAttachment, flared 9° back, gold
hem, yoke and back emblem disc. LOD slab → kept as a Block (a cylinder Root would need a non-identity Root
rotation that BulkMoveTo would drop).

## FL-0085 looks, round L1 (quick, `kit_characters_looks.jpg`, `kit_characters_aerial.jpg`)
Structure change: the anchored **Root is now the visible torso** and the freed slot is `Hair` (jointed to the
Head), so a skin face and hair coexist within 8 parts. Checked first: no EntityController on main (335fb16) or in
PR #29 (FORGE-04 ruler/camera only), so nothing consumed the old invisible Root or a Torso motor.
Looks: 8 skin tones (later 6, see L3), 6 hair styles (short bowl, long, crop, bald + beard, kingdom hood, straw hat), 8 hair
colours, 6 outfits (tunic, sleeveless, vest, apron, robe, jerkin), each keeping the kingdom colour on the torso,
the sleeves or both. Soldiers: skin face under a steel kettle helm (a steel disc from above); governor: gold
circlet, ermine sleeves.
| model | sil | var | read | prop | pal | detail | coh | cost | notes |
|---|---|---|---|---|---|---|---|---|---|
| citizens (12 looks) | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 5 | straw hat, hood, beard, bowl read at once; long hair (block) read as a box |
| soldiers | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 | face + kettle helm + spear: friendlier than the box helm |
| governor | 3 | — | 3 | 4 | 2 | 3 | 4 | 5 | tall gold drum read as a fez; gold sleeves on the gold kingdom = all yellow |
| aerial (tilted 55°) | 4 | 4 | 4 | — | 4 | — | 4 | — | hair colour, hats and hoods dominate from above; kingdom shows on shoulders |

## FL-0085 looks, round L2 (quick, same sheets)
- Long hair: block → upright drum (read as a can) → a large ball set low and back, over the ears to the
  shoulders: now reads as long hair framing the face.
- Governor: crown → low gold circlet (gold ring from above), sleeves → ermine, so the gold kingdom no longer goes
  all yellow.
| model | sil | var | read | prop | pal | detail | coh | cost |
|---|---|---|---|---|---|---|---|---|
| citizens | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 5 |
| soldiers | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 |
| governor | 4 | — | 4 | 4 | 4 | 3 | 4 | 5 |
| regalia | 4 | — | 4 | 4 | 4 | 4 | 4 | — |

## FL-0085 looks, round L3 — contract ranges
FORGE-00 fixed `Kit.LOOK_RANGES = { skin = 6, hair = 6, hairColor = 8, outfit = 6 }`. Skin cut from 8 to 6 tones
that still run light to dark (1 = Kit default, 2 lightest, 6 darkest; luminance strictly decreasing 2 → 6, spec).
Preview looks re-indexed to 1–6.

## FL-0085 looks, round L4 — D-032 rig (full render `kit_characters_looks.jpg`; quick `kit_characters_aerial.jpg`, `kit_characters_turn.jpg`)
D-032 (main d559c9e) reverts the visible-Root idea: FORGE-04's Sim/Pose and EntityController drive a `Torso` motor
(walk bob, work lean, death fall). Rig now: invisible anchored Root (centre 3.2), Motor6D `Torso` at the hips,
Head/arms/legs off the Torso, Tool off the RightArm (sack off the Torso), and `Hair` **welded** to the Head (a
Weld, no motor). Hips back at 2.2 (Pose's death fall drops them 1.7), torso 1.7, head 1.6. Hair styles:
bald (no part, the default, so look-less rigs keep ≤ 8 parts and the old Kit.spec holds), short, long, beard,
hood, straw hat (crop dropped). Soldiers wear a steel great helm as their Head (8 parts, look ignored);
governors keep the skin head, ermine sleeves and gold staff (the circlet would have been a 9th part on every
governor). LOD: one block, 6.4 tall, centred at 3.2 with its feet on the ground.
Smoke test: KitCharacter.spec walks and kills every rig through Pose (the real module when present, else a copy
of its walk/dead samples); on an origin/main snapshot with these Kit files the real Pose was used (20/20), and
main's `EntityController.spec` (20/20) and `Pose.spec` (11/11) pass with the new rig.
- Critique: longer legs make the figures a touch less chibi but the big head still carries the charm; bald
  default reads as the classic Roblox head; the steel box helm keeps the soldier read; the governor without a
  crown relies on ermine sleeves + gold staff (weaker regal read).

## FL-0085 looks, round L5 — lead follow-ups (quick `kit_characters.jpg`, `kit_characters_looks.jpg`)
- Default look has short brown hair again (style 1 = short, 2 = bald; EntityController does not pass looks
  yet), so a look-less citizen is a 9-part rig.
- Governors get the gold circlet back as welded headwear (`Hair`, attribute `KitHeadwear = "crown"`): 9 parts.
  Soldiers stay at 8 (helm is the Head). `Kit.spec` updated to D-032 (≤ 9 parts; motors = parts − 1 − welded
  headwear; headwear welded, never motored).
- Critique: default citizens read as people with hair again (brown bowl from above); the circlet restores
  the governor's regal read; bald stays available as a look.

## Final (full-quality renders)
Images: `blender/previews/kit_characters_looks.jpg` (full, L4: 12 citizen looks + 3 soldiers + governor, strip ≈71
studs; quick re-render after L5); `kit_characters.jpg` (quick, L5: default short-hair look, 5 jobs × 4 kingdoms +
soldiers, strip ≈90 studs); `kit_regalia_fit.jpg` (full; regalia unchanged by L4); `kit_characters_lod.jpg` (full, pre-L4: 5.5-tall
block; now 6.4 tall at the 3.2 Root). Tiles in `blender/renders/kit/characters*_NN.png`.
| model | sil | var | read | prop | pal | detail | coh | cost | notes |
|---|---|---|---|---|---|---|---|---|---|
| soldier | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 | spear + steel helm + kingdom tabard read at 70–90 studs |
| citizens (looks) | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 5 | hats/hoods/beards/hair colours vary a crowd; kingdom colour in every outfit |
| citizens (job read) | 3 | 3 | 3 | 4 | 4 | 3 | 4 | 5 | hoe and sack clear; axe/pick/mallet need the swing or ≤ 60 studs |
| governor | 4 | — | 4 | 4 | 4 | 3 | 4 | 5 | gold circlet (welded headwear), ermine sleeves, gold staff |
| regalia | 4 | — | 4 | 4 | 4 | 4 | 4 | — | crown reads from above (velvet cap); gold cape on gold kingdom is low contrast |
| LOD | 3 | — | 4 | 4 | 4 | 1 | 4 | 5 | one tinted block; colour is the only read beyond 150 studs |

## Soldier kingdom crests (CONTRACTS G13.2, D-033(3))
`Kit.character(kind, job, kingdomColor, look?, kingdom?)`: a soldier given its KingdomId wears one primitive welded
to the helm as `Hair` (9 parts), in the kingdom colour, KitHeadwear `crest_<shape>`. Without a kingdom it keeps
the plain helm (8 parts). Renders: `KitCharacterDump` groups `characters_crests` (front) and `characters_crests_side`
(yaw 90), plus `characters_aerial`; gameplay strips about 40 studs away at 1280×720, also checked as grayscale (PIL "L").
- Lab (8 variants): spire 0.8×1.75 read as a party hat, so it became 0.95×2.1. A swept wedge-fin plume read
  as a mirrored spire from the side in grayscale, and a thick cylinder read as a cannon, so the plume is a
  0.7×2.5 cylinder tilted back 55°. The dome is raised (a 1.3 ball 0.4 above the helm) so it bulges like an onion.
- First final (superseded by the CVD follow-up below), outline above the helm (height × width × depth): spire 2.05 × 1.34 × 1.34 (CornerWedge turned 45°,
  point over the front corner); square 0.46 × 1.95 × 1.95 (flat Block plate); plume 1.62 × 0.70 × 2.45 (Cylinder,
  1.2 past the helm back); dome 1.05 × 1.30 × 1.30 (Ball).
- Grayscale verdict, 40 studs: front view reads point / flat cap / upright stick / round knob, and the side view
  reads fin / plate / diagonal tail / knob. All four tell apart. The dome is the smallest, and the gold dome is
  close in tone to the steel helm, so it reads by its outline only. Unverified: the aerial strip at about 77 studs
  (too small to judge in the preview), and Studio (STUDIO_PLAYTEST step 5).

## Soldier crests, CVD follow-up (FORGE-05 run 2 on #81)
Under protan and deutan vision, crimson and emerald soldiers are the same olive, so the spire vs plume pair rests
on outline alone, and at 40 studs each crest is only about 16–20 px tall.
- Change: the spire base goes from 0.95 to 1.3 (a 1.84 diagonal, overhanging the helm corners by about 0.2,
  like the crimson towers' spires). It stays pointed and the tallest. The plume tilt goes from 55° to 70°: a
  near-horizontal tail ending 1.4 past the helm back.
- Outline (height × width × depth): the spire goes from 2.05 × 1.34 × 1.34 to 2.05 × 1.84 × 1.84. The plume goes
  from 1.62 × 0.70 × 2.45 to 1.08 × 0.70 × 2.59. The square and dome are unchanged.
- Spire vs plume: the front margin rises from 0.64 to 1.14, and the side margin goes from 1.11 to 0.97. The new
  tightest pair is plume vs dome from the front: the same height (1.08 vs 1.05), told apart by width (0.70 vs
  1.30).
- Renders: `kit_characters_crests*.jpg` (front and side, about 40 studs) and the new
  `kit_characters_crests_aerial.jpg` (camera at 50° elevation, 50 studs, front). All were checked in colour and
  in grayscale.
- Verdict:
  - Front: a broad pointed triangle vs a narrow round-tipped stub.
  - Side: a broad fin vs a near-horizontal tail; the clearest view.
  - Aerial 50°: before, the spire foreshortened to a tiny point. Now it reads as a broad peaked lump vs the
    plume's thin stick, which still projects upright on screen because it points away from the camera. They
    differ by width; the spire's point is mostly lost at that angle.
  - Plume vs dome from the front: a narrow stub vs a round ball, distinct at 40 studs.
  - Unverified: Studio, and the protan/deutan re-run on these new images (FORGE-05).

## Remaining weaknesses
- One-part tools cannot show handle + head: axe/pick/hammer read as heads at the fist (the arm is the handle in a
  swing); hoe, spear and staff are bare shafts. Imported tool meshes (Kit.prop ids, VS-2) would fix this.
- The face decal (`rbxasset://textures/face.png`) is not in the Blender preview; its look on a Ball head needs the
  Studio check. Remove the six lines in `Character.character` if it projects badly.
- The hauler's sack hides behind the head in a straight front view (reads from the side, back and above).
- Long hair and the hood share a ball shape (they differ by colour and size).
- Regalia fit was checked on stand-in R15/R6 attachment positions; real bundles vary (BodyBackAttachment height),
  so the cape top can sit up to ~0.3 above or below the shoulders.

Committed review images (soldier crests, for FORGE-05's CVD re-run with `production/quality-gates/cvd/cvd.py`):
`art/reviews/img/kit_characters_crests.jpg` (front sheet), `kit_characters_crests_side.jpg` (side sheet),
`kit_characters_crests_gameplay.jpg` and `kit_characters_crests_side_gameplay.jpg` (≈40-stud gameplay view, colour;
grayscale is a straight luminance conversion of these), `kit_characters_crests_aerial.jpg` (50° elevation, 50 studs).
All five were re-rendered after the CVD follow-up.
