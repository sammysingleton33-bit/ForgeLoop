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

## FL-0098 portraits (CONTRACTS G13.8, D-036; `art/reviews/img/kit_portraits.jpg`)
`Kit.portrait(kind, job, kingdomColor, look?, kingdom?)` calls `Character.character`, anchors every part, keeps the
motors and the HairWeld, and adds the camera attachment `Root.PortraitFocus` (attributes PortraitFov 30 and
PortraitDistance). Sheet: 8 portraits rendered from that camera (vertical FOV 30, square) on a flat card colour,
each beside the same world rig. The mix is 3 citizens (short hair, hood, straw hat), a governor and one soldier
per kingdom. Rendered from the `portraits` and `portraits_world` groups of `KitCharacterDump` with a scratch
render script.
- Round P1: the first framing had 0.2 headroom, and the hair, crown and azure plate touched the top edge. The
  headroom is now 0.45, and the spec requires the highest point below 92 % of the half-frame.
- Verdict: every portrait matches its rig in colours, headwear, crest and tool, and is head and shoulders. The
  face and the hat, crown or crest are uncropped, the shoulder line and arm tops are visible, and the outer
  arm edges are cut in a square frame.
- Tall crests pull the camera back, so the face share of the frame height is 0.39–0.41 for citizens, the
  governor and plain soldiers, and 0.25 (spire), 0.31 (plume), 0.31 (dome) and 0.36 (square) for crested soldiers.
  These were measured with the 0.45 headroom and the crest follow-up geometry. The spire is just above the
  spec's 0.25 floor.
- Re-rendered after the crest CVD follow-up (wider spire, plume at 70°): the wider spire still fits with headroom
  and its base corners are not cropped. The 70° plume is uncropped but reads as a short stub from the front,
  because the tail hides behind the helm.
- Unverified: the face decal is not in the Blender preview, and the ViewportFrame look in Studio (lighting,
  `Ambient`/`LightDirection`) is not checked.

## Citizen job silhouettes (art pass after the user's first live Studio playtest; Phase 1, 9 parts)
Feedback: "AI worker / citizen models are too plain. Tools and silhouettes need more character and readability."
Goal: every job reads at a glance at gameplay distance (40-80 studs) and from the overview camera (50° down, 170 studs,
about 3 px per stud on a 720 px frame, where a citizen is a 6-10 px blob and only hat and tool keep a shape), in colour
and in grayscale. Two author rounds (A: first build and renders; B: fixes from the close-ups), D-019 quick/full renders
through the same Lune dump → Blender preview as the crest work (no Roblox material textures, no face decal).
Images (`art/reviews/img/`): `citizen_polish_jobs.jpg` (all jobs, ~40 studs, before/after, colour + grayscale),
`citizen_polish_crowd.jpg` (30 citizens round a farm, aerial 50° at 170 studs, before/after), `citizen_polish_groups.jpg`
(4 per job, aerial, colour + grayscale), `citizen_polish_tools.jpg` (tool close-ups), `citizen_polish_heads.jpg`
(headwear close-ups), `citizen_polish_sheet.jpg` (the 8-job hero sheet and gameplay strip, after).

| Job | Hat (Hair slot, `KitHeadwear`) | Tool (`KitTool`) | Accent (`KitAccent` = job) | Torso |
|---|---|---|---|---|
| farmer | wide flat straw disc 3.4 × 0.42, L .70 (`strawhat`; was a 2.3 hair-style hat) | board 1.0 × 5.4 × 0.3 (was a 0.34 stick) | olive trousers, cream panel | 1.95 lean (was 2.0) |
| woodcutter | charcoal wedge cap, low over the brow, tall tail behind, L .23 (`knitcap`) | bearded steel wedge 0.5 × 2.4 × 2.3 (was 1.7) | black-brown trousers, umber panel | 2.3 stocky (was 2.2) |
| miner | squat burnt-ochre iron pot 2.2 × 0.8, Metal, L .50 (`hardhat`) | dark bar 0.7 × 0.7 × 4.4 across the arm, a T (was a 3.0 one-sided spike) | coal trousers, soot-grey panel | 2.2 (was 2.1) |
| builder | white linen block cap 1.95 × 0.85, L .91 (`buildercap`) | wooden mallet block 1.4 × 1.35 × 2.6 (was a 1.15 × 1.8 drum) | dusty navy trousers, tan canvas panel | 2.3 (was 2.2) |
| hauler | none: the look's hair stays | sackcloth ball 2.7, set higher on the back (was 2.1) | russet trousers, sackcloth panel | 2.3 (was 2.15) |
| idle | the look's hair | nothing | none | 1.9 lean (was 2.0) |
| soldier | steel helm + kingdom crest (unchanged) | spear 9.0 × 0.4 pale ash (was 8.0 × 0.34 dark wood) | tabard (unchanged) | 2.15 |

- **Outfit accent.** The trousers take the job colour in every outfit; the outfit's fixed neutral torso or sleeve colour
  (not the kingdom tint, not bare skin) takes the job's panel colour. `look.outfit` still moves the kingdom tint
  (torso or sleeves, always one of them), the bare arms and the cut; the accent stays. Parts carry `KitAccent = <job>`.
- **Hat and hair share one slot** (D-032), so a working citizen's `look.hair` picks one of 6 variants of the job hat (roll
  0 / +9° / -9° times shade 1 / 0.88; `KitHeadwear` never changes) and the hair colour is hidden under it. Idle and
  hauler citizens keep all six hair styles. Style 6 is now `curls` (a big round mass), because a straw hat on an idle
  citizen is a decoy farmer. Beards and long hair on working jobs are a Phase 2 item.
- **No job hat is a ball** (balls are hair) and the four hats' value ranges (including shaded variants) never overlap:
  woodcutter .20-.23, miner .44-.50, farmer .61-.70, builder .80-.91 (luminance 0.2126 R + 0.7152 G + 0.0722 B).
- **Part counts, default look (short hair), before → after:** citizen idle 8 → 8, farmer 9 → 9, woodcutter 9 → 9,
  miner 9 → 9, builder 9 → 9, hauler 9 → 9; soldier 8 → 8 (9 → 9 with a crest); governor 9 → 9. Bald looks: idle 7 → 7,
  hauler 8 → 8, farmer, woodcutter, miner and builder 8 → 9 (they always wear the hat now). Cap `Character.MAX_PARTS` = 9.
- **Aerial threshold, from measurement.** Smallest job hat: builder cap 1.95 studs across (farmer 3.40, woodcutter
  2.00, miner 2.20); before this pass the hat slot held a 1.66 ball. Smallest tool at its longest: axe blade 2.40 (hoe
  5.49, pick 3.86, hammer 2.89, sack 2.70); before: axe 1.7, hammer/sack about 2.1. Signature box (hat ∪ tool,
  diagonal) of the working jobs: 6.78 (builder) to 8.11 (woodcutter). Spec floors: hat ≥ 1.9, tool ≥ 2.3, box ≥ 6.5 studs
  (about 6 px, 7 px and 20 px at the overview camera).
- **Round A findings (first build).** The corner-wedge knit cap read as a wizard hat and the skull poked through its
  low front slopes as two skin-coloured holes; the pick bar was thin and low contrast against grass; the straw hat and
  the burlap sack were the same tan from above (farmers and haulers blurred at 170 studs).
- **Round B changes.** Cap → a wedge 1.9 × 1.7 × 2.0 whose slope stays above the skull (no skin shows) and whose
  tall tail hangs behind; pick bar 0.5 → 0.7 thick and 4.2 → 4.4 long; sack darker (L .46 vs the straw's .70);
  straw and hard-hat values moved apart; hauler panel and trousers darker.
- **Portrait (`Kit.portrait`, FL-0098, now on main).** The farmer's 3.4 straw disc was wider than the portrait frame
  (projected x 1.04 against 0.95); `Portrait.frame` now keeps the headwear's whole width in view (parallax 1.15), so the
  farmer's face is a little smaller there. `KitPortrait.spec` passes (5/5); the portrait still comes from
  `Character.character`, so hat, tool and accent come along.

| model | sil | var | read | prop | pal | detail | coh | cost | notes |
|---|---|---|---|---|---|---|---|---|---|
| citizens (job read, gameplay) | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 5 | was 3 / 3 / 3 in the Final table; hat + tool + trousers tell all five jobs at 40 studs |
| citizens (job read, aerial 170) | 4 | 4 | 4 | - | 4 | - | 4 | - | discs, white squares, ochre dots, dark slabs and sacks form groups; woodcutter is the weakest (dark on dark ground and shadow) |
| citizens (looks) | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 5 | skin, outfit and hat variants vary; hair colour only shows on idle and hauler |
| soldier / governor | 4 | 3 / - | 4 | 4 | 4 | 3 | 4 | 5 | spear taller and paler; no regression |

- **Verdict, honest.** At 40 studs all eight read: farmer (disc and board), woodcutter (dark cap and big blade), miner
  (ochre pot and bar), builder (white cap and mallet), hauler (sack), idle (nothing), soldier (long pale spear, crest),
  governor (staff, circlet). In grayscale the farmer, builder and the dark woodcutter separate by hat value; the miner
  is mid grey and relies on the bar. From the aerial camera farmers, builders, miners and haulers read as groups in the
  crowd render. **Still weak:** the woodcutter's cap reads as a dark slab or visor more than a knit cap, and a dark blob
  against shadow at 170 studs; the hoe is a board, not a shaft with a blade; the pick is a flat bar (no points); the
  sack has no visible tie; the soldier's spear has no head. All need a second part.
- **Unverified.** Studio (materials, the face decal under a brim, the hat against the real camera), the swing poses with
  the larger tool heads (only the headless Pose walk and death smoke test ran), protan/deutan on the new images (FORGE-05).
- **Phase 2 (a raised cap, D-048 up to 11 parts, not built):** hoe, axe, pick and hammer as handle plus head;
  straw crown over the brim, a lamp on the hard hat, a hauler's strap and sack tie, a spear head. Each detail part would
  carry `KitDetail = true` (client may drop it beyond the LOD distance), no new Motor6D, derived from kind and job.

## Remaining weaknesses
- One-part tools cannot show handle + head: axe/pick/hammer read as heads at the fist (the arm is the handle in a
  swing); hoe is a board, spear and staff are bare shafts (the job-silhouette round made them bigger, not two-part).
  Phase 2 (D-048, 11 parts) or imported tool meshes (Kit.prop ids, VS-2) would fix this.
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
All five were re-rendered after the CVD follow-up. Portraits: `kit_portraits.jpg` (FL-0098).

## Fresh-context D-019 scoring — FL-0118 phase 1 citizens

Reviewer: fresh-context visual reviewer (did not build these rigs), 2026-10-15. Evidence: the six Blender renders `img/citizen_polish_{jobs,crowd,groups,tools,heads,sheet}.jpg` (an approximation of Studio, no material textures, **not a Studio play test**; the grey blocky figure in the strips is a scale-reference dummy). I opened each image, then cropped and up-scaled 2-3x, greyscaled the "after" rows, and did a rough pixel count of kingdom-red in the crowd shot. Scored before reading any author log or the Kit source. Part counts (8-9 per rig) are read off the caption of `citizen_polish_sheet.jpg`.

Rubric (1-5): PASS needs silhouette >= 4, variation >= 4, readability at gameplay distance (40 studs) >= 4, and proportions, palette, detail density, cohesion and part cost each >= 3. Variation = how different individuals of the same job look in the 4-per-job aerial group; a unique role (governor) is not penalised for it.

| rig | sil | var | read | prop | pal | detail | cohes | cost | verdict | note |
|---|---|---|---|---|---|---|---|---|---|---|
| **Rig set (all 8)** | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 | NEEDS-WORK | Visible improvement in job identification: before, the five working jobs were the same red tunic, brown trousers and cream sleeves, told apart only by a thin tool; now four jobs have a headwear shape and a trouser or sleeve colour of their own, and each group reads as a block of one hat colour at 170 studs. Still plain: all eight torsos are identical red boxes, no faces, no belts or aprons, and the **tools mostly do not read as tools** (see below). |
| farmer | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 5 | NEEDS-WORK | Best of the set. Wide straw disc hat is a strong silhouette at 40 studs and from above; olive trousers help. Near-pass: the four farmers are identical clones (var 3) and the "tool" is a bare orange stick with no scythe blade or fork tines, so it reads as a pole or fence post. |
| woodcutter | 4 | 3 | 3 | 3 | 4 | 3 | 3 | 5 | NEEDS-WORK | Dark navy slanted-block hat is a distinct silhouette and the darkest in the set (separates well in greyscale) but it reads as a chimney or bucket, not woodcutter gear, and is oversized for the head. The axe is a flat grey triangle with no handle, hanging low at the side, so it reads as a banner or shard. |
| miner | 3 | 3 | 3 | 4 | 4 | 3 | 4 | 5 | NEEDS-WORK | Orange flat-disc hard hat is a clear colour cue and reads as a hat. Silhouette is close to the farmer's disc, only smaller and orange (they differ by hue and a pole). The pickaxe is a dark horizontal bar with no pick head, so it reads as a plank or stick. Grey sleeves help. |
| builder | 3 | 3 | 3 | 3 | 4 | 3 | 3 | 5 | NEEDS-WORK | White box on the head is highly visible at every distance and the group is the brightest block in greyscale, but a flat white cuboid reads as a paper hat or chef's hat, not a hard hat. The held brown crate is the same shape and colour language as the hauler's load, so builder vs hauler relies on the hat alone; there is no hammer, saw or trowel. |
| hauler | 4 | 4 | 4 | 3 | 4 | 3 | 4 | 5 | PASS (marginal) | Round brown sack on the back reads as "carrying a load" at 40 studs and from above, and is the only prop-based job that works; the four haulers vary in sack tone and head. Caveat: with no strap or tie, in front and side views the sack can read as a hair bun or hood (see `citizen_polish_heads.jpg`), and the whole figure is brown on brown. |
| idle | 3 | 4 | 4 | 4 | 4 | 2 | 4 | 5 | NEEDS-WORK | Unchanged from "before" and the plainest: sphere hair on a red box, cream sleeves, brown trousers. Reads correctly as "no job" and the four vary in hair and skin tone, but this is the model the user called too plain. Needs one cheap personal detail (hair-style variants, a cap or kerchief, a belt). |
| soldier | 5 | 3 | 4 | 3 | 4 | 3 | 3 | 5 | NEEDS-WORK | Strongest silhouette: tall pale spear, grey helmet with a red plume. Essentially unchanged (spear went from dark to pale). The spear has no head (a bare pole), the grey cube plus small red cone reads as a garden-gnome hat, and the 9-stud pole dwarfs a 4x2 body. Not in the 4-per-job aerial group, so variation and aerial reading are unverified. |
| governor | 3 | 4 | 3 | 4 | 4 | 3 | 4 | 5 | NEEDS-WORK | Unchanged from "before". Gold circlet is a thin band (reads as a headband at 40 studs, a few pixels from above) and the gold staff is thin; for the key character it is the least prominent silhouette in the set. Variation is N/A (unique role) and not penalised. Not in the aerial group, so aerial reading is unverified. |

### Answers to the specific checks

- **Each job recognisable at 40 studs?** Farmer (straw hat), hauler (sack) and soldier (spear + plume) yes. Woodcutter, miner and builder are recognisable as "three different workers" but their hats and tools do not say what the job is. Idle and governor are distinguishable by absence and by crown, respectively.
- **Group reads from the aerial camera?** Yes, clearly better than before: in the 4-per-job strip each group is a block of one colour (straw discs / navy slabs / orange discs / white boxes / sack balls) where before all six groups were the same red. In the 30-citizen crowd, the jobs can be picked out by hat colour. Soldier and governor were not in the group strip.
- **Jobs separate in greyscale?** Mostly. Woodcutter (darkest), builder (brightest) and farmer (light disc) separate well at 40 studs; farmer vs builder differ by disc vs box shape; woodcutter vs idle vs miner groups are all dark at 170 studs and separate mainly by shape.
- **Tools read as tools?** Mostly no. Sack, crate and the governor's staff read as carried objects. Farmer stick, woodcutter wedge, miner bar and soldier pole are heads-less shafts or blades without a handle: the tool silhouettes are only modestly bigger than before, and the user explicitly asked for tools with more character and readability.
- **Kingdom colour still visible from above?** Yes. Every citizen still shows a red tunic or shoulders in the 50-degree 170-stud crowd. A rough pixel count of kingdom-red in the crowd shot fell about 14% (1981 to 1704 px), because straw and white hats cover shoulders; red is no longer the only strong colour from above (hat colours now compete), which matters if rival kingdoms are told apart by tunic.

### Fixable problems (NEEDS-WORK rows)

1. **Tools (all working jobs, the user's explicit complaint).** Give each tool a head: farmer = scythe blade (curved wedge) or a fork with three tines on the stick; woodcutter = axe with a visible handle and a bright steel head, held up beside the body, not hanging low; miner = pick head crossing the shaft (a T or crescent); builder = hammer (handle plus block head) in place of or in addition to the crate; soldier = spearhead (small pale wedge or diamond) on the pole. Keep them lighter than the clothes so they separate in greyscale.
2. **Woodcutter hat:** replace the oversized navy block with a smaller cap, hood or beanie; keep the dark value.
3. **Builder hat:** make it read as a hard hat or a cloth cap (rounded or with a brim in a warm light colour), not a flat white box; give the builder a different carried item from the hauler's (hammer, plank or ladder).
4. **Miner vs farmer:** keep the miner's hat smaller than the farmer's disc and add a lamp (a small bright block on the front) so the two discs differ in silhouette, not only hue.
5. **Variation (farmer, woodcutter, miner, builder, soldier):** the four of each job are clones apart from slight sleeve and trouser shades. Vary hat colour or tilt, shirt shade and hair per individual so a crowd of 30 farmers does not look cloned.
6. **Idle and bodies (the "too plain" part is not addressed):** all torsos are the same red box and all heads have no face. Add at least a belt or sash stripe and a collar to the shared torso, a couple of hair or headwear variants for idle citizens, and check in Studio whether a face decal restores eyes (unverified here; the renders have none).
7. **Governor:** make the crown taller or wider and the cape or robe a distinct shape so the governor reads at 170 studs; a thin band and a thin staff are lost from above.
8. **Soldier:** swap the grey cube plus cone for a proper helmet (dome, or a box with a crest ridge) and add the spearhead; check the pole length against the body.
9. **Hauler:** add a rope or strap to the sack, and a flat tied top, so it cannot read as hair or a hood; give the hauler trousers a different tone from the sack.
10. **Head defect:** in `citizen_polish_heads.jpg`, the border between the hair sphere and the face sphere is a jagged, ragged intersection line (hair cap and face overlap). Invisible at 40 studs but visible in the portrait; check in Studio and inset the hair or use a wedge or cap shape.
11. **Review-sheet issue (not a model defect):** the grey reference dummy overlaps the builder and hauler in `citizen_polish_jobs.jpg`; offset it for the next sheet.

### Verdict

- Visible improvement on "before": **yes for job identification, grouping and crowd read** (the hats and trouser colours are a real, visible gain, strongest on the farmer); **no for the tools**, which still do not read as tools; **none for idle, soldier and governor**, which are essentially unchanged.
- Passes: the rig set as a whole does **not** pass (variation 3, detail density 3; tools unresolved). Hauler is a marginal pass. Everything is headless and render-based: no Studio evidence.
- Still reads as placeholder: the tools (stick, grey wedge, dark bar, crate, bare pole), the flat torsos with no faces, the builder's white-box hat, the woodcutter's block hat, the governor's thin crown and the unchanged idle model.

## FL-0118 clip fix on #138 (FORGE-05 visible-defect findings; D-051)

FORGE-05 found two clipping defects on the phase 1 renders: the builder's head poked through its cap, and the hauler's sack
overlapped the head. Minimal change, still 9 parts; nothing else in the phase 1 design moved.
- **Builder.** The 1.95 x 0.85 x 1.95 block wrapped the head 0.455 deep and its flat underside cut across the face. It is now
  a low wedge cap 1.7 x 0.95 x 1.9 (thin lip over the brow, higher crown behind), base 0.45 above the head centre, so it sits
  ON the head (the head enters it 0.35) and its slope stays above the skull (no skin through it). It is still white linen
  (L .91); it is a different primitive from the woodcutter's tall dark wedge (height 0.95 against 1.6, spec).
- **Hauler.** The sack (centre 1.26 right, 4.0 up, 1.28 behind the spine) overlapped the head sphere by 0.25 and the right
  arm; it is now centred on the spine, 3.05 up and 1.95 behind (still 2.7 across). Gap to the head 0.37 at rest and at least
  0.30 in every pose of idle, walk, work, carry, fight and flee; gap to both arms at least 0.23.
- **Other clips found by the same check.** The governor's gold circlet (0.38 tall, top at +0.76) let the head's top
  (+0.80) poke through its top face; it is now 0.5 tall at +0.66 (covers the head, a gold disc from above). The woodcutter's
  cap and the miner's pot wrapped the head 0.46 deep; both sit 0.1 higher (cap apex unchanged at 2.04, slope 1.6 tall).
- **Not a model defect.** The jagged hair/face line seen in `citizen_polish_heads.jpg` comes from the preview's 24-segment
  spheres; the clipfix renders use 64 x 32 spheres and the line is smooth. Studio spheres are smooth.
- **Still clipping, not fixable in the Kit.** In the `celebrate` pose (arms raised 140°) the hand tool sweeps through the head
  (box vs head sphere: farmer -0.34, builder -0.35, hauler's arms are clear, woodcutter -0.07, miner -0.14). The cause is
  `Sim/Pose.celebrate` (FORGE-04): it gives no Tool rotation. Suggested fix there: tool jobs celebrate with `Tool` swung
  out (the joint allows 45°) or with one arm raised.
- **Spec.** `KitCharacter.spec` "clearance" (4 tests): every head surface point above a hat's lower face is inside the hat
  (so no skin shows through any job hat, whatever the look, nor through the governor's crown); the head enters a hat by
  0.15-0.4; the sack clears the head sphere (0.2 at rest, 0.1 in poses) and both arms (0.03) in idle, walk, work, carry, fight
  and flee at speeds 0, 6 and 12; the four hand tools clear the head sphere by 0.1 in the same poses. 10 mutants (old builder
  block, short peak, old sack position, sack on the arm, sack against the head, old crown, old cap and pot heights, hoe
  into the head, floating farmer disc) all fail the spec.
- **Renders** (`img/citizen_polish_clipfix_*.jpg`, looked at): `_heads_a.jpg` (farmer, woodcutter, miner, builder) and
  `_heads_b.jpg` (hauler, idle, soldier, governor), each from the front, the side and the back; `_builder_hauler.jpg`
  (builder and hauler enlarged, 3 angles); `_poses.jpg` (hauler walk, flee, work, carry; builder, woodcutter, farmer and
  miner work, side view); `_crowd.jpg` (30 citizens, 50° at 170 studs, #138 as pushed against after). Result: no head
  clips a hat or the sack in any tile; the builder reads as a peaked cap, the sack still sits behind the head in the front
  view (a big brown ball beside the shoulder), so a bun reading remains possible there.

### Still NEEDS-WORK after this fix (fresh-context D-019 round 1, deferred; not regressions)
- **Tools are placeholders (Phase 2, D-048):** hoe is a board, axe a head with no handle, pick a bar, mallet a block, spear a
  bare pole; they need handle + head (2 detail parts).
- **Woodcutter cap** is oversized and reads as a chimney or bucket; **builder** hat reads as a paper hat, not a hard hat, and
  the mallet block resembles the hauler's load; **miner** pot is close to the farmer's disc (needs a lamp and a smaller pot).
- **Variation:** the four of a job are near clones (hat colour, shirt shade); **idle** is the plainest model; torsos are
  identical red boxes (no belt, sash or collar); **governor** crown and staff are thin from the air, no cape (a welded cape
  needs a Torso part, outside D-048); **soldier** helm reads as a gnome hat and the spear has no head.
- **Kingdom red from above** fell about 14% because straw and white hats cover the shoulders.

## FL-0118 phase 1b: the fresh review's 9-part fixes (interim art, D-051)

Phase 1 plus the clip fix (#138) passed the D-051 gates; this stacked branch takes the fresh-context D-019 round 1's lowest
criteria that fit in 9 parts. Still 9 parts per rig; Phase 2 (D-048, tools with handle and head) is the next branch.
Images (`art/reviews/img/`): `citizen_polish1b_jobs.jpg` (all 8 jobs at about 40 studs, before = #138 as pushed, colour and
grayscale), `citizen_polish1b_heads.jpg` (each job from the front, side and back), `citizen_polish1b_crowd.jpg` (30 citizens
round a farm, 50° at 170 studs, before and after), `citizen_polish1b_groups.jpg` (4 per job at the aerial camera, colour and
grayscale), `citizen_polish1b_idle.jpg` (12 idle looks).
- **Woodcutter cap smaller.** The 1.9 x 1.6 x 2.0 wedge slab (read as a chimney) became a 1.5 charcoal knit beanie, a ball sitting
  high (top 6.09, was 6.68). Its rim runs above the eyes and meets the head at 53° (spec: at least 35°, rim at least 0.33
  above the head centre on the face side).
- **Miner pot smaller and darker than the farmer disc.** Pot 2.2 x 0.8 ochre (L .50) became 1.9 x 0.7 dark burnt ochre
  (L .44, palette .38-.44); the farmer's disc went 3.4 to 3.1 and its straw to L .62. Spec: pot width at most 0.65 of the disc, pot value at
  least 0.1 darker.
- **Builder hat.** Cream cloth cap (240, 214, 160, was white) on the same low peaked wedge. It still does not read as a hard hat:
  a one-part dome cannot leave its rim above the eyes except as a tall egg (the rim sits at +0.1 for a flat dome), so the dome
  with a brim is a Phase 2 detail-part item. Honest status: improved from white paper to warm cloth cap, not a hard hat.
- **Per-individual variation, from the look alone** (no wire field): the hair colour, hidden under a working citizen's hat,
  dyes the clothes: trousers and neutral panel (a palette of three hues per job times 8 dyes of +-10%) and the shirt's kingdom tint factor (8 shifts, -0.16 to +0.12, KitTint
  stays exact so `setKingdomColor` still matches; the default look is unchanged). Spec: 8 shirt tones and 8 trouser dyes per
  job, different jobs' trousers stay at least 10 apart under every dye pair, the three palette picks differ in hue (not only brightness).
- **Idle variety.** Idle citizens carry nothing, so the free 9th part is an `Accessory` welded to the Head on about two looks
  in three: a headband (kingdom red or indigo) or a scarf (cream or rust). Spec: share between 55 and 80%, never on any other
  job or kind, headband above the eyes, scarf below the chin line, flags as the other parts, 9 parts at most.
- **Governor.** Crown 1.52 x 0.5 became a 1.9 x 0.6 gold disc, staff 5.6 x 0.34 became 6.4 x 0.5, body 2.2 to 2.4. (A cape would
  need a Torso-welded part: outside D-048.)
- **Soldier crest less gnome-like.** The crimson spire went from 1.3 x 2.1 to 1.0 x 1.6 (1.55 above the helm, no taller than the
  helm 1.6; base diagonal 1.41). The great helm is still a steel box, so a cone on a cube remains; a rounder helm is a separate
  change (it moves the D-033 crest silhouettes) and is not done here.
- **Kingdom red from above.** Besides the smaller farmer disc: an even hair colour makes a working citizen's neutral sleeves
  kingdom-red (an odd one keeps the job panel), so the shoulders show red from the air on half the looks. Kingdom-red pixels in
  the 30-citizen crowd crop (same looks, positions and camera; my threshold): main 420, #138 380, this branch 441. Spec: the
  tinted top area is at least 1.0 larger with red sleeves.
- **Hauler sack.** Centre 0.1 right, 2.8 up, 2.1 behind the spine (was 3.05 up, 1.95 behind): its top is 4.15, just above the
  shoulders (3.9), so from the front it is a bag behind the body. Spec adds: top at most 4.3, bottom at least 1.3, walking legs
  never enter it (0.02), plus the earlier head and arm gaps. A strap or tie needs a part: Phase 2.
- **Spec and mutants.** `KitCharacter.spec` has 44 tests (39 before): hat clearance now handles a ball beanie (rim rule), and six
  new tests cover individuals, red sleeves, idle accessories, the governor and the low crest. 17 mutants (beanie over the eyes or
  oversized, pot wide or light, sack beside the head or in the legs, headband on the eyes, scarf over the face, no red sleeves,
  dye or shirt tone ignored, accessory on everyone or welded to the torso, thin crown, thin staff, tall spire, shifted default
  look) all fail the spec. `check.sh` OVERALL PASS (game-001 specs 1431 passed).

### Phase 1b: fresh-context D-019 re-score, round 1 (image-only reviewer), and round 2
Round 1 (first build, images `citizen_polish1b_*` at d32fecf): **rig set NEEDS-WORK**, sil 4 / var 3 / read 3 / prop 3 / pal 4 /
detail 3 / cohes 4. Per rig (sil / var / read): farmer 4/2/4, woodcutter 3/2/3, miner 3/2/3, builder 4/2/4, hauler 3/3/3, idle
3/4/4, soldier 5/4/5 (PASS), governor 4/4/4 (PASS). Findings, worst first: no within-job variation in the 4-per-job aerial group
(all clones); the axe and pick are flat slabs that merge in grayscale; the hauler's front view is almost the idle citizen; the
builder carries a crate and its wedge looks like folded paper; farmer, miner and governor hats are all flat discs; tool-to-arm
joins are ragged; the idle hair is a split sphere; detail density is low. Kingdom red: 380 to 441 px (confirmed).
Round 2 (this commit): variation made visible. Each working job has a palette of three hat colours (look.hair: six hats = three
colours x three tilts, one value band per job so grayscale separation holds), three panel and three trouser hues (hair colour),
a wider shirt-tone shift, and the miner pot a little lighter so it separates from the woodcutter in grayscale. Kingdom-red
pixels in the crowd crop: 443 (main 420, #138 380). Not addressed here because each needs a second part (Phase 2, D-048): tools
with handle and head, the hauler's strap and sack tie, the builder's hard hat (dome + visor) and hammer, the miner's lamp, the
spearhead. Hair is still a hemisphere (a cap shape is a separate change).

#### Round 2 fresh re-score (image-only reviewer, commit 356dfc2): rig set NEEDS-WORK
The reviewer did not zoom the aerial crops. Scores sil / var / read / prop / pal / detail / cohes: farmer 5/2/5/4/4/3/3,
woodcutter 3/3/3/4/3/3/3, miner 3/3/3/4/4/3/2, builder 4/3/4/3/3/3/3, hauler 3/3/2/3/3/2/3, idle 3/3/4/4/4/3/3, soldier
4/4/4/3/3/3/3 (PASS, borderline), governor 4/4/4/4/4/3/4 (PASS); rig set 3/3/3/4/4/3/3. Two of eight pass; visibly better than
BEFORE "but only slightly". Remaining, lowest first: hauler read 2 (the sack hides behind the arm in the front view, the figure
looks like idle: needs the strap, Phase 2); farmer variation 2 (the four farmers still look alike in the aerial group: hat colour
and tilt are subtle at 3 px per stud); miner cohesion 2 and a ragged tool-arm join; tools overall are slabs (no handle and head:
Phase 2); woodcutter, miner and idle share a dark value in grayscale; builder carries a crate and the wedge cap reads as paper;
idle hair is two overlapping spheres; the soldier's cone reads as a party hat and the helm is a box. The criterion still below
threshold after two author rounds on 9 parts, as the coordinator's rule asks, is **variation (2-3, needs 4) and tool readability**;
stopped here. Phase 2 (the next stacked branch) takes the tools, the hauler's strap, the builder's hard hat and the miner's lamp.

## FL-0118 phase 2: D-048 11-part rigs, tools with handle and head (interim art, D-051)

Stacked on phase 1b (PR 153). The rig cap is `Character.MAX_PARTS` = 11 = `BASE_PARTS` 9 (D-032) + `MAX_DETAIL` 2 (D-048). Detail parts are rigid
parts welded by a `Weld` "DetailWeld" to the Head or the Tool (never a Motor6D: `Sim/Pose.JOINTS` and the root height are unchanged), named
Detail1 and Detail2, `KitDetail = true` (so the client may drop them beyond the rig's LOD distance; the base rig is complete without them)
and `KitDetailKind` = the part's name. Nothing new on the wire: they derive from kind and job. Images (`art/reviews/img/`):
`citizen_polish2_jobs.jpg` (8 jobs at about 40 studs, before = phase 1b, colour and grayscale), `_tools.jpg` (close-ups), `_heads.jpg`
(each rig from the front, side and back), `_crowd.jpg` (30 citizens, 50 degrees at 170 studs), `_aerial.jpg` (4 per job, colour and grayscale).
| Job | Tool (handle, Tool part) | Tool head (detail) | Head detail |
|---|---|---|---|
| farmer | 5.2 pale-wood handle | steel hoe blade, angled down | kingdom-red crown over the straw brim |
| woodcutter | 3.9 haft | bearded steel axe head | kingdom-red pompom on the beanie |
| miner | 3.7 dark handle | 3.6 double-sided iron bar (T) | lamp on the pot |
| builder | 3.0 pale handle | fat wooden mallet head | visor: the cream drum becomes a hard hat |
| hauler | the sack (Tool) | kingdom-red strap across the chest, the sack's tied neck | none |
| soldier | 9.0 ash shaft | pale steel spearhead, kingdom pennant | none (crest as before) |
| governor | 6.4 gold staff | gold orb | kingdom-red velvet cap over the crown disc |
Idle citizens keep their free 9th part as the Accessory and have no detail parts. Part counts: working citizens 11, hauler 11, soldier 11 (10
without a kingdom), governor 11, idle 7 to 9 (was 9, 9, 9, 8-9, 9, 7-9).
- **Fixes from the fresh review of #138/153:** tools now have a handle and a head, held at head height beside the body (the old board, slab
  and bar are gone); the builder's paper-like cap is a hard hat (drum + visor) and his hammer differs from the hauler's load; the miner has a
  lamp; the hauler has a strap and a tied sack, so the front view differs from idle; kingdom red shows on top of every working rig (crown,
  pompom, pennant, strap, velvet cap): kingdom-red pixels in the 30-citizen crowd crop 443 (phase 1b) to 461 (main 420).
- **Rules and specs.** `KitCharacter.spec` 49 tests (45 before): parts at most 11 with at most 2 detail parts and a base rig of at most 9; every
  detail flagged, named, welded rigidly to the Head or the Tool, never a Motor6D, flags like the other parts; `Pose.JOINTS` and every Motor6D
  name unchanged and no joint to a detail; the exact two details per job (kind, weld target); head details above the eyes and following the
  hat's tilt; tool heads and handles clear the head sphere by 0.1 in idle, walk, work, carry, fight and flee. `KitPortrait.spec` and
  `Kit.spec` follow (the portrait frames head-welded details too, so the governor's velvet cap is not cropped). 17 mutants of `Character.luau`
  and one of `Portrait.luau` (not flagged, third detail, welded to the torso, short handles, missing heads, dark spearhead, untinted strap
  and pennant, blade through the head, no visor, cap back to 9, no velvet cap, lamp over the face, details ignoring the hat tilt, mallet
  through the head, equal handle colours, portrait ignoring details) all fail the spec.
- **Known upstream issue, unchanged:** `Sim/Pose.celebrate` (FORGE-04) gives no Tool rotation, so hand tools sweep through the head with raised
  arms; the spec excludes celebrate for hand tools.

### D-019 re-score, phase 2 (fresh context, image-only, one round)

Reviewer: a fresh session that saw only `citizen_polish2_{jobs,tools,heads,crowd,aerial}.jpg` (no code, no earlier scores). Scale 1-5; thresholds
silhouette, variation and readability at least 4, proportions, palette, detail and cohesion at least 3. Blender previews, not a Studio play test.
| Rig | sil | var | read | prop | pal | detail | cohes | Verdict |
|---|---|---|---|---|---|---|---|---|
| farmer | 5 | 3 | 5 | 4 | 4 | 4 | 3 | NEEDS-WORK (variation) |
| woodcutter | 4 | 3 | 4 | 4 | 4 | 4 | 3 | NEEDS-WORK (variation) |
| miner | 3 | 3 | 3 | 4 | 3 | 3 | 3 | NEEDS-WORK (silhouette, variation, readability) |
| builder | 4 | 3 | 4 | 4 | 4 | 4 | 3 | NEEDS-WORK (variation) |
| hauler | 3 | 3 | 3 | 3 | 3 | 3 | 3 | NEEDS-WORK (silhouette, variation, readability) |
| idle | 3 | 4 | 4 | 4 | 3 | 2 | 4 | NEEDS-WORK (silhouette; detail 2 is below 3) |
| soldier | 5 | n/a | 5 | 3 | 4 | 4 | 3 | PASS |
| governor | 5 | n/a | 5 | 4 | 4 | 4 | 4 | PASS |
| rig set | 4 | 3 | 4 | 4 | 3 | 3 | 3 | NEEDS-WORK |
Reviewer's words, shortened: visibly better than before for farmer, woodcutter, builder, soldier and governor; miner and hauler improved only
marginally; idle is basically unchanged (it is the no-tool baseline, with only the 1b accessory); tools read as tools up close and from the
side, and the hoe, spear and staff also at 40 studs from the front; the miner pick is thin and hides behind the torso from the front; the
hauler sack reads from the side or back and not from the front, and the sash is lost in grayscale; four individuals of one job barely differ
in the aerial groups; woodcutter and miner merge in grayscale; kingdom red is still clearly visible from above (443 to 461 red pixels in the
crowd crop, main 420); the soldier's red crest still reads as a separate cone on a box helm.
- **Reviewer limits, so not over-read:** it did not zoom the aerial crops, and it could not tell from the images whether the side-view
  overlaps (hoe blade against the straw brim, pick across the face and hat, mallet and axe head against head and shoulder) are real
  intersections or only the projection. The geometric clearance specs (tool heads and handles clear the head sphere by 0.1 in idle, walk,
  work, carry, fight, flee; celebrate excluded, `Sim/Pose`) pass, so the overlaps are projection, but this is headless evidence only.
- **Outcome, honest:** NEEDS-WORK as a set. Variation (3) is the core miss for the four tool jobs; miner and hauler are below 4 on silhouette
  and readability; idle detail is 2. This is the first fresh re-score of phase 2 and the 2-round rule has not been spent, but the remaining
  items are not 11-part tool fixes: per-individual variation beyond hat tone, a taller or brighter miner head, a front-readable hauler load
  and an idle silhouette feature are either another art pass or a different approach (tool meshes via Kit.prop ids / VS-2, per-look
  proportions). They are reported and left for FORGE-00 to schedule or accept under D-051 (no worse than main per asset, clearly better as a
  set, no visible defects, code gates pass); no further loop on this branch.
