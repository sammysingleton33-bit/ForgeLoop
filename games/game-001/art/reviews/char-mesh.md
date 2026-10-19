# Citizen mesh kit review log (FL-0135, D-057) — FORGE-02 worker B

D-019 loop for the Blender character mesh kit that replaces the primitive-part citizens. Everything here is Blender evidence
(Cycles renders of the shipped meshes with Roblox-like single-sided shading, Roblox 70 deg FOV). **Nothing is a Studio
render**; MeshPart pivot/bbox after import, vertex-colour tinting and importer axes are unverified until the owner imports.
Scores 1-5, rubric `blender/reviews/README.md` (silhouette / variation / readability >= 4, proportions / palette / detail /
cohesion / cost >= 3). The reviewer sees images only (no code, no hints which option is which); blind labels are mapped below.

## Round 1 - style comparison (one pass, 2026-10-18)
Same three citizens in every option: farmer (straw hat, hoe), soldier (helmet with a crimson crest, spear + pennant), ruler (crown,
staff, ermine collar), crimson kingdom colour. Views: Kit.portrait framing (30 deg FOV, 6 deg above), ~40 studs (Roblox 70 deg
FOV, crop enlarged 2x) and 170 studs / 50 deg down next to a KayKit Medieval Hexagon building (`building_home_A_red`, scaled x25,
CC0, read from a gitignored cache) for cohesion. Reproduce: `blender/scripts/charkit_compare.py` + `charkit_sheet.py`.

| Option | What it is | Citizen triangles (farmer / soldier / ruler) |
|---|---|---|
| Reference | the current part-built rigs (`games/game-001/art/char_kit/old_rigs.json`, Kit/Character.luau at main 0964214c) | about 130 |
| **B** (reviewer "Style 1") | faceted / flat-shaded chunky low-poly, procedural lofts with 6-8 segments, flat normals, +-6 % facet brightness | 886 / 924 / 1,080 |
| **C** (reviewer "Style 2") | KayKit Adventurers (CC0, Kay Lousberg) Knight + Rogue parts, atlas baked to vertex colours, closed and decimated 4-5x, refitted per part into our envelope; hats, tools, crown, cape, collar are my own | 1,242 / 1,362 / 1,438 |
| **A** (reviewer "Style 3") | smooth-shaded rounded low-poly, same lofts with 8-12 segments and smooth normals | 1,164 / 1,194 / 1,444 |

Images (commit `games/game-001/art/reviews/img/d057-style-review-r1/`): `sheet_portrait.jpg`, `sheet_gameplay40.jpg`,
`sheet_aerial170.jpg`; the reviewer's reply is stored verbatim in `review.json` there.

What I saw before asking (author view, all renders opened):
- Reference: block characters read by hat/tool colour, no faces, kingdom colour on the torso. Detail 1.
- A: cleanest portrait, friendly, but heavy for the budget (farmer 1,164 > 1,000) and the smooth shading flattens the small faces.
- B: chunkier, facets catch light and read as "hand-made low-poly"; farmer 886, soldier 924, ruler 1,080 (<= 1,500) fit the amended D-057 (11) budget with room for variants.
- C: KayKit's own meshes are 4,148 triangles for head + body + arms + legs (Knight; measured with `blender/lib/ckit_kaykit.py`, head 956, body 1,052, arm 594 x 2, leg 476 x 2), so they only fit by decimating to about 22 %; at that ratio the eyes and visor slits blur, the torso crumples, and the proportions (chibi, head 48 % of height) must be stretched into our envelope (legs 2.2, torso 1.7, head 1.6). Soldier and ruler both end up grey.

Reviewer verdict (fresh image-only session, pick = Style 1 = **B**), scores silhouette / variation / readability / proportions / palette / detail / cohesion / cost:

| Option | sil | var | read | prop | pal | detail | coh | cost | verdict |
|---|---|---|---|---|---|---|---|---|---|
| Reference | 4 | 2 | 3 | 3 | 4 | 1 | 4 | 5 | NEEDS-WORK (variation, readability, detail) |
| B | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 5 | PASS (all thresholds met) |
| C | 3 | 3 | 3 | 3 | 2 | 3 | 2 | 3 | NEEDS-WORK |
| A | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | PASS, but over the 1,000 budget (farmer 1,164) |

**Pick, recorded once: B (faceted, flat-shaded chunky low-poly, project-original).** Reasons from the reviewer: kingdom crimson on
every torso reads from above, the three roles separate clearly, it stays well under budget, and the faceted shapes sit beside the
flat cottage. Defects named for B (the work list for the kit): faces too small / glum in the portrait; soldier helmet+arms grey and
the ruler's white sleeves wash out the crimson from above; farmer apron and grey sleeves muddy; ruler collar and shoulders lumpy;
hoe head a plain white block. Defects named for the others: C loses the kingdom colour (grey armour), its fine detail turns to noise
at 40 studs, the glossy painterly look clashes with the flat cottage; A costs more triangles for little visible gain.

Consequences of the pick:
- No third-party mesh ships: every committed asset is `project-original`. KayKit stays a comparison-only reference
  (`blender/generators/_charkit_kaykit.py`, `blender/lib/ckit_kaykit.py`, fetch script `blender/scripts/fetch_kaykit.sh` pinned to
  `KayKit-Character-Pack-Adventures-1.0@672074b73ba276876a19e8816ecdc5241817ab47`; the cache is gitignored and nothing from the
  pack is committed). The manifest provenance rule (`lib/manifest.py`, FORGE-07 A1/A4) is in place for any future CC0 asset.
- Fairness caveat for C: it is a one-pass automatic decimation prototype, not a hand-retopologised KayKit set; a hand-built KayKit
  kit at about 1,000 triangles would score better than round 1, but it would also need every missing job (hats, aprons, tools, packs)
  built by hand in the same style, which is what B already is.

## The kit (2026-10-19): what was built, measured, and the D-019 re-score loop

**Built (project-original, style B):** `blender/generators/char_kit.py` (+ `_charkit_*.py`) exports ONE FBX `games/game-001/art/char_kit/citizen_kit.fbx`
(103 pieces named by piece id, vertex colours, one material, 1 Blender unit = 1 stud, Y up / -Z forward) and `rig.json` beside it; manifest row
`char_kit_01`; preview `blender/previews/char_kit.jpg`. 6 faces, 10 hair styles (one is a hood) + beard, 6 torso cuts + smith / merchant / healer
/ soldier / ruler torsos, bare / hand-only / gauntlet arms, 4 sleeve types, 3 leg types, 3 boots + plate, 11 hats (straw, beanie, miner helmet,
builder cap, merchant beret + feather, healer coif, smith cap, helm, crown, hood, headband), 14 tools (hoe, axe, pick, mallet, hammer, scale,
healer staff, hauler sack, spear + pennant, sword, bow, ruler staff), ruler cape + ermine collar + trim, four kingdom crests (crown, star, oak
leaf, sun) + shields + a neutral crest and shield, quiver, aprons, satchels, and a kingdom-coloured shoulder mantle on every worker.
13 assemblies (farmer, woodcutter, miner, builder, hauler, blacksmith, merchant, healer, idle, soldier, soldier_knight, soldier_archer,
governor). `rig.json` passes `python3 games/game-001/art/char_kit/rig_to_luau.py --validate-only` (0 warnings; the converter is the runtime
worker's file, copied verbatim); variants are resolved by `blender/lib/ckit_resolve.py`, a port of the runtime's `CharacterMesh.luau` rules, in
every render, test and budget check.

**Measured from the shipped files** (`~/forge-bpy/bin/python -I blender/scripts/charkit_budget.py`, which counts triangles from the FBX bytes
(`blender/lib/fbxtris.py`) and again through the Blender importer, compares both with `tris` in rig.json, then sums every job x all 1,728 looks x
4 kingdoms; `blender/lib/manifest.py check()` runs the same measurement in `bash blender/scripts/check.sh` and fails over budget or on any
declared-vs-measured mismatch; mutants in `blender/tests/test_kit_budget.py`):

FBX 483,788 bytes; 103 mesh objects, 6,804 triangles in all; largest mesh 188; materials ['M_charkit_vc']; colour layers ['Col']; looks checked per job: 1,728 x 4 kingdoms

| job | default tris | min | max | cap | body max | tool max | pieces = draw calls (max) | texture memory | verdict |
|---|---|---|---|---|---|---|---|---|---|
| farmer | 864 | 824 | 910 | 1000 | 838 | 72 | 15 | 0 B | PASS |
| woodcutter | 792 | 752 | 838 | 1000 | 798 | 40 | 14 | 0 B | PASS |
| miner | 800 | 760 | 846 | 1000 | 778 | 68 | 13 | 0 B | PASS |
| builder | 760 | 720 | 806 | 1000 | 750 | 56 | 13 | 0 B | PASS |
| hauler | 814 | 774 | 952 | 1000 | 858 | 94 | 14 | 0 B | PASS |
| blacksmith | 738 | 714 | 764 | 1000 | 720 | 44 | 13 | 0 B | PASS |
| merchant | 916 | 892 | 942 | 1000 | 840 | 102 | 15 | 0 B | PASS |
| healer | 928 | 904 | 954 | 1000 | 866 | 88 | 14 | 0 B | PASS |
| idle | 676 | 636 | 814 | 1000 | 814 | 0 | 13 | 0 B | PASS |
| soldier | 810 | 806 | 856 | 1500 | 770 | 86 | 14 | 0 B | PASS |
| soldier_knight | 854 | 846 | 920 | 1500 | 862 | 58 | 14 | 0 B | PASS |
| soldier_archer | 888 | 884 | 934 | 1500 | 850 | 84 | 14 | 0 B | PASS |
| governor | 900 | 900 | 926 | 1500 | 834 | 92 | 16 | 0 B | PASS |

Budget: citizen <= 1,000 in all (body <= 900, hand tool or sack <= 150), soldiers and governor <= 1,500, <= 16 pieces, every mesh <= 20,000, one
material, texture memory 0. Draw calls = pieces (one MeshPart each); Studio draw-call cost is **unverified**.
Pose clearance (`python blender/scripts/charkit_clearance.py`, hair / hats / crests / cape / pack / aprons / shields against the bodies over
every Pose action and phase, Python port of Sim/Pose.luau): over tolerance 0; the only penetrations above 0.06 stud are thin soft shells (aprons,
regal hem, sack strap, <= 0.33 stud) that a thigh crosses in the fast walk / flee frames.

### Re-score loop (fresh image-only reviewers, rubric `blender/reviews/README.md`; two author rounds, then stop)
Reviewer sessions saw only the sheets in `img/d057-kit-review-r1/` and `img/d057-kit-review-r2/`; replies are verbatim in each `review.json`.

| Round | Kit | sil | var | read | prop | pal | detail | coh | cost | verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| r1 (kit v1: kingdom-red torsos, 99 pieces) | Reference | 2 | 1 | 2 | 2 | 3 | 1 | 4 | 5 | |
| r1 | Kit | 3 | 3 | 3 | 4 | 4 | 4 | 4 | 4 | NEEDS-WORK, ship: false |
| r2 (kit v2: job colours + kingdom mantle, runtime contract, 103 pieces) | Reference | 2 | 2 | 2 | 3 | 3 | 1 | 4 | 5 | |
| r2 | Kit | 3 | 4 | 3 | 3 | 3 | 4 | 4 | 4 | **NEEDS-WORK, ship: false** |

r1 defects (summary): the non-farmer, non-soldier jobs blur into one red figure at 170 studs; every citizen wears the same red tunic so the kingdom colour
does not separate jobs; the lower-body job silhouettes share one torso / head outline; same-job citizens are clones with different heads; faces are
tiny dashes (dark skins). What I changed for r2 (author round 2): kingdom colour moved from the whole torso to a shoulder mantle (`mantle_kingdom`)
and job identity into clothes and hats (baked colours: charcoal woodcutter beanie, cream builder cap, violet merchant beret + coat, white healer
coif + smock, soot-black smith cap + shirt); 6 interchangeable torso cuts for every worker; neutral crest / shield; ruler cape darker and flared;
coif, hood and bob no longer cover the eyes (found with a front-view headgear grid); mirrored-hull winding fixed (axe head had rendered black);
budgets now measured; the kit data conforms to the runtime contract.
r2 identities (reviewer, Kit; at 40 / at 170 studs): farmer yes / yes, soldier yes / yes, miner yes / partly, woodcutter yes / partly, governor
yes / partly, merchant partly / partly, hauler partly / partly, blacksmith partly / no, healer partly / no, builder partly / no, idle no / no.
r2 defects: (1) blacksmith, builder, healer, hauler, idle are not distinguishable at 170 studs, props are thin and small; (2) the kingdom colour is one
small band on workers so it reads weakly from above; (3) silhouettes of the non-tool jobs are near-identical blobs; (4) same-job variation is mostly
skin and hair colour (grid reads as clones at distance, though variation scored 4); (5) awkward proportions (large heads, stiff arms), faces and small
cues vanish at 40+ studs.

**Status: NEEDS-WORK after two rounds (silhouette 3, readability 3; proportions and palette dropped from 4 to 3 with the mantle change).** The
author round limit is used, so this is a blocker report, not a pass. It is a real kit that is clearly better than the reference at portrait and 40
studs (all three reviewers' sheets agree: faces, hair, hats, tools, variation, cohesion), and it passes the budgets and the runtime validator, but it
does not yet make blacksmith, builder, healer, hauler and idle unmistakable at 170 studs. My read of why, from the renders: at 170 studs a citizen
is about 10 px tall, so only the hat, the shoulders and a tool read; thin tools (scale, staff, pick) vanish, and the kingdom-vs-job colour budget has
no good answer inside one torso colour. Options for the owner / coordinator (not done, each needs a decision): (a) an aerial LOD with oversized
hat and prop silhouettes (about 1.3x) swapped in beyond ~100 studs; (b) one job-coloured torso family per job (about 54 torso meshes, +0.2 MB) with the
kingdom colour on mantle plus sleeves; (c) the runtime reading rig.json's own cloth palettes (`tints.cloth_panels`) instead of `Character.clothColor`
so the job colours of the first design (green farmer, rust woodcutter, slate miner) apply; (d) accept the 170-stud read of the seven identities
as "partly" and rely on the 40-stud read. Studio will change several of these judgements (lighting, vertex-colour tint, real camera FOV).

**What I looked at (all opened):** the portraits of all 11 identities (Cycles, neutral ground), the 11-identity lineup at ~35 studs, 36-look grid,
four kingdoms from the front and back, a ruler and a hauler from four sides, silhouettes (front and turned 40 degrees, old vs new), the 30-citizen
crowd at 40 and 170 studs (old vs new, same camera), the headgear x face grid, pose lineups of a farmer and a hauler. **What is weak:** see the r2
defects; additionally the hauler's sack hangs 0.2 stud off the back (rest pose), faces are geometry only, ears are thin diamonds, the red mantle
reads like a scarf, and Cycles renders add a green bounce on skin unless the ground is neutral (a render artefact, not Roblox).
**Placeholder / unverified:** everything about Studio (importer axes and scale, MeshPart pivot and bounding box, vertex colours and
`MeshPart.Color` multiplication in sRGB, draw-call cost at crowd sizes); no textures; unit-kind keys `soldier_knight` / `soldier_archer` are
guesses; the cloth colours of workers follow the runtime's old job panels, not a new palette.

Reproduce: `~/forge-bpy/bin/python blender/build.py --generator char_kit`, `blender/scripts/charkit_scenes.py` (scenes crowd170 / crowd40 / jobs /
looks / kingdoms / turntable / poses / portraits, `--silhouette`, `--yaw`, `--old`), `blender/scripts/charkit_review_sheets.py`,
`blender/scripts/charkit_clearance.py`, `blender/scripts/charkit_budget.py`.

### Runtime fit (integration branch forge/02-blender-fl0135-kit, 2026-10-19)
The Kit runtime specs (`KitCharacterMesh`, `KitCharacterMeshPose`, `KitCharacterMeshImport`) run on the real data and found four Blender-side defects; fixed
without touching the specs: (1) base torsos started at y 1.5..2.06 instead of the hip joint 2.2: every torso is now clipped at the hips and the hems of
robe / coat / smock / tabard / regal robe are separate `skirt_*` pieces (`skirt_%look.outfit%` with five empty variants + `skirt_06`, `skirt_merchant`,
`skirt_smock`, `skirt_tabard`, `skirt_regal`), leg tops sit at 2.24; (2) soldier crests rose to 7.67 studs: emblems are now 1.24 tall, highest body point
7.17 (< 7.2); (3) the death fall followed from (1) (lowest torso corner -0.133, was -0.2509); (4) the bounding boxes of hoe, pick and mallet came within
0.09 stud (pick and mallet overlapped) of the head: hoe upright, pick one-sided (long curved end outward, short blunt end inward, a mattock),
mallet head front to back, so every posed tool keeps >= 0.228 stud (limit 0.1) from the head in all seven actions and no closer to the headwear than at rest.
The ermine collar is merged into `trim_regal` to keep the governor at 16 pieces; curls hair trimmed so the converter's static worst case
has 0 warnings. Measured again from the FBX: max citizen 982 / 1,000 (healer; body <= 894), soldiers and governor <= 978 / 1,500. Ported checks:
`blender/scripts/charkit_runtime_checks.py` (also a pytest). Look check (opened): `img/d057-kit-runtime-fit/after_jobs.jpg`, `after_portraits.jpg`,
`after_kingdoms.jpg` against the r2 sheets: same identities, hats, colours; the pick now shows its long end outward and its blunt end on the front view,
the mallet head is seen end-on from the front. The D-019 verdict is unchanged (NEEDS-WORK at 170 studs, accepted as interim by the coordinator under D-051).

### Silhouette pass (FL-0135, branch `forge/02-blender-fl0135-silhouettes`, 2026-10-19): FORGE-00 OPTION A, bolder job silhouettes inside the kit
Decision applied: the kit itself gets bolder, larger job-specific hats, tools, back gear and one colour VALUE per job, readable at 170 studs / 50 degrees
down (about 10 px per citizen); no zoom-dependent swap, so portrait and world rig stay identical (G13.8). Budgets unchanged (citizen <= 1,000,
body <= 900, tool <= 150; soldier / governor <= 1,500; <= 16 pieces). Two author rounds, each followed by a fresh image-only D-019 reviewer who saw
only the seven sheets (`img/d057-sil-review-r1/`, `img/d057-sil-review-r2/`; verbatim replies in each `review.json`). OLD = the kit of PR #220
(snapshot of `citizen_kit.fbx` + `rig.json`), NEW = this branch, same camera, same 30-citizen roster around the farm.

**Round 1 (kit change):** woodcutter orange knit cap with a tall point + pompom, miner yellow pot helmet with a wide rim and a lamp, builder teal hard
hat with a peak and a white ridge, farmer wider straw brim, merchant beret + larger feather, healer coif with a flat green top cross; every tool
about 1.2 to 1.4x longer / bigger (hoe, axe, pick, mallet, hammer, scale, staff); one merged back-gear piece per job (`gear_farmer`, `gear_woodcutter`
log bundle with pale tops above the shoulders, `gear_miner` blue pack + lantern, `gear_builder` three planks, `gear_smith` apron, `gear_merchant` pack +
yellow roll, `gear_healer`), a bigger hauler sack with a red tie. **Round 2 (after reviewer 1):** hauler cobalt flat cap (replaces the hair slot, so
the hauler no longer has an orange head next to the woodcutter); blacksmith wide soot-black forge hat with an ember band, a hammer head about 1.6x
the first kit's and an anvil strapped on the back; healer wide white winged coif with a big green cross on a flat top, forest-green tabard front and
back with a white cross (hem 2.42, clear of the thighs); merchant lighter violet beret, 4.2 stud scale beam, bigger pans; governor taller crown points
and a broader ermine collar; mantle slimmed vertically (y 3.46 to 3.97) so more job-coloured torso shows (the ring seen from above is unchanged).
Assembly `soldier_swordsman` renamed `soldier_knight` on FORGE-07's review of #220 (sim units: soldier, archer, knight; no ram, FL-0128).
No per-job torso shape was added: what still fails is blob size at 10 px, not the torso block.

| Rubric (After kit) | silhouette | variation | readability | proportions | palette | detail | cohesion | verdict |
|---|---|---|---|---|---|---|---|---|
| Before (PR #220 kit), both reviewers | 2 | 2 | 2 | 4 | 3 | 4 | 4 | |
| After round 1 | 3 | 3 | 3 | 4 | 4 | 4 | 4 | NEEDS-WORK, ship false |
| After round 2 | 3 | 3 | 3 | 4 | 4 | 4 | 4 | **NEEDS-WORK, ship false** |

Identities, After kit, at 40 / at 170 studs (reviewer's words reduced to yes / partly / no): r1: farmer y/y, miner y/p, woodcutter y/p, blacksmith p/n,
merchant y/p, healer p/n, soldier y/y, builder y/p, hauler p/p, idle p/n, governor y/p. r2: farmer y/y, miner y/p, woodcutter y/p, blacksmith p/p,
merchant y/y, healer p/p, soldier y/y, builder p/p, hauler p/p, idle n/n, governor y/p. At 170 studs that is 2 "yes" and 3 "no" in r1 and 3 "yes" and 1 "no"
in r2 (the PR #220 kit had 2 "yes" and 4 "no": blacksmith, healer, builder, idle). The builder, hauler and idle rows did not change between r1 and r2
in geometry, so a one-step swing (builder 40: yes to partly) is reviewer noise of one level, not a regression I can attribute.

**Status: NEEDS-WORK after two author rounds (silhouette, variation and readability 3 against a pass bar of 4). Blocker, reported not hidden.** The
170-stud identity read improved (no identity is a blank dot any more except the idle citizen; merchant joined farmer and soldier as "yes"), and the
40-stud read is clearly better than the PR #220 kit (my own look at the sheets agrees: teal builder, orange woodcutter, yellow miner, blue hauler,
violet merchant, white healer with a cross, black-hatted smith, crowned governor are each a different coloured shape from above). What the reviewers
still flag, ordered: (1) at 10 px only a hat-colour dot separates the jobs; red / brown / beige dominate the crowd, builder / hauler / blacksmith /
healer remain "partly"; (2) idle has no hat, tool or prop by definition, so it reads as "a citizen with nothing", and the same-job variation (skin,
hair, outfit tint; the hat jobs have no hair slot) stays at 3; (3) the governor and soldier are both red from above. Options for FORGE-00, none done
because each needs a decision: (a) scale every citizen about 1.15x in the runtime rig (the aerial read grows with area, tools and heads included; touches
the Pose / camera numbers); (b) give idle a visible accessory (a bundle, a bare light head-cloth) and let hat jobs keep a hair tuft / sideburn for
variation (a kit change, within budget: idle has 190 tris of headroom, builder 138); (c) a per-job coloured torso family or the runtime applying
`tints.cloth_panels` so the job colour also covers the body (not only hat and gear); (d) accept the 170-stud read of builder / hauler / blacksmith /
healer / idle as "partly", with the unambiguous cues (hat colour, tool, back gear) kept for 40 studs, and judge it in Studio, where lighting, FOV and
the vertex-colour tint will change several of these judgements.

**Measured** (`~/forge-bpy/bin/python -I blender/scripts/charkit_budget.py`, from the FBX bytes, 1,728 looks x 4 kingdoms; FBX 512,972 bytes, 111 mesh objects,
7,180 triangles, largest mesh 188): farmer 858 default / 928 max, woodcutter 840 / 910, miner 820 / 890, builder 792 / 862, hauler 842 / 912, blacksmith
796 / 822, merchant 912 / 938, healer 940 / 966, idle 660 / 810 (all citizens cap 1,000, body max 878 of 900, tool max 102 of 150), soldier 854 / 900,
soldier_knight 898 / 964, soldier_archer 932 / 978, governor 928 / 954 (cap 1,500); pieces <= 16; PASS; converter `rig_to_luau.py`: 0 warnings.
**Runtime fit, specs not weakened:** `Kit` filter 248 passed, whole `games/game-001/tests/world` suite 318 passed / 0 failed (20 files); ported checks
`charkit_runtime_checks.py`: 0 violations, worst tool-head clearance 0.204 (limit 0.1, and no closer to headwear than at rest in any Pose action),
lowest fall corner -0.133 (limit -0.25), highest body point 7.17 (< 7.2); `charkit_clearance.py`: 0 over tolerance; `blender/tests` 58 passed
(new: assembly keys equal the sim unit kinds); `bash blender/scripts/check.sh` PASS.
**What I looked at (all opened):** the r1 and r2 sheets (aerial crowd at 170 studs, labelled lineup, 40-stud crowd, front / behind / above, black silhouettes,
portraits, 36 looks), and the 11-identity jobs strip from the front and behind. **Weak / unverified:** everything about Studio (importer scale and axes, vertex-colour
multiplication, real lighting and FOV, draw-call cost in a crowd); Blender renders are not Studio renders; the blacksmith's anvil reads from behind and above
only; the healer's cross is about 2 px at 170 studs, the white wing and the green tabard carry the read; the hat jobs show no hair.
