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
