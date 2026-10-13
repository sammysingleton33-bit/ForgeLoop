# Colour-vision check (D-033 (4)) — FORGE-05

D-033 (3): kingdoms are never identified by colour alone (silhouette + emblem + name).
D-033 (4): run a protanopia / deuteranopia simulation over the kingdom UI and a world view before VS-1 acceptance.

## Method
- `production/quality-gates/cvd/cvd.py OUTDIR IMG...` — Machado et al. 2009 matrices (severity 1.0) applied in
  linear RGB; CIEDE2000 between the four kingdom colours (`config/Kingdoms.luau`, D-033 canonical) and against
  grass; writes a swatch sheet and a 2×2 grid per image (normal / protanopia / deuteranopia / tritanopia).
- Headless renders only. A Studio screenshot of a four-kingdom view must be run through the same script before
  VS-1 acceptance (STUDIO_PLAYTEST "Colour vision").

## Run 1 — 2026-10-13, main `b05ed1c`
Inputs: `design/ui/screenshots/luau/kingdom-desktop.png`, `hud-phone.png` (FORGE-03 Luau renders) and FORGE-02's
`kit_characters_looks` sheet (rendered for the #60 review from `e078ab7`). I looked at every output grid.

CIEDE2000 between kingdom colours (< 10 hard to tell apart at a glance; < 5 near-identical):

| Vision | cri/azu | cri/eme | cri/gol | azu/eme | azu/gol | eme/gol | closest pair | vs grass (cri / azu / eme / gol) |
|---|---|---|---|---|---|---|---|---|
| normal | 43.5 | 60.8 | 51.6 | 39.7 | 64.8 | 43.2 | azu/eme 39.7 | 61.7 / 55.3 / **18.1** / 29.8 |
| protanopia | 44.5 | **14.7** | 43.3 | 39.1 | 63.4 | 29.2 | cri/eme 14.7 | 29.3 / 53.1 / **16.3** / **13.9** |
| deuteranopia | 52.8 | **15.1** | 29.4 | 34.6 | 69.0 | 36.6 | cri/eme 15.1 | **13.0** / 53.1 / 19.1 / 19.2 |
| tritanopia | 66.8 | 59.9 | 31.3 | **10.8** | 57.5 | 53.3 | azu/eme 10.8 | 53.7 / 15.8 / 14.2 / 43.2 |

### Findings
1. **UI passes D-033 (3).** Crest, standings and HUD always pair the colour with an emblem (flame, star, sun, tree)
   and the kingdom name; under protan/deutan the Emberhold and Thornwood crests turn the same olive but stay
   identifiable by emblem and name. (FORGE-03's tinctures, not the world palette, colour the UI.)
2. **World fails D-033 (3) for soldiers (FORGE-02 Kit + FORGE-01 rigs).** Soldiers of different kingdoms share one
   silhouette and differ only by torso colour; crimson and emerald soldiers become the same olive under
   protanopia and deuteranopia (ΔE00 ≈ 15). In battle a colour-blind player cannot tell friend from foe.
   Needs a non-colour kingdom marker on soldiers (helmet crest / shield emblem shape per kingdom) — owner FORGE-02
   (Kit) with FORGE-01 (rig selection).
3. **Low-contrast against terrain:** emerald vs grass is 18 even with normal vision; crimson vs grass 13 under
   deuteranopia; gold vs grass 14 under protanopia. Kingdom-coloured roofs/banners are the main world cue at the
   aerial zoom, so add a non-colour cue there too (banner emblem visible from the overview camera).
4. Tritanopia: azure vs emerald 10.8 — same remedy as 2–3.

Routing (FORGE-00, CONTRACTS G13.2 at `2221c1e`):
- Finding 2 → soldier helmet crest per kingdom in its tower style (spire / square / plume / dome) as the 9th rig part;
  FORGE-02 builds it in the Kit, FORGE-01 passes the kingdom id when rendering soldiers. **VS-1 acceptance row.**
- Finding 3 → banner emblems readable from the overview camera (FORGE-02, VS-1 polish, after FL-0085).
- Finding 4 → covered by tower silhouettes and emblems; re-check in the Studio four-kingdom screenshot step.

Status: **not yet acceptable for VS-1** (finding 2). Re-run after the soldier marker lands and once with a Studio
screenshot of a four-kingdom view.

## Run 2: 2026-10-13, soldier helmet crests, PR #81 head `2ef6606` (not yet merged)
**Input.** FORGE-02's Blender (`bpy`) renders from #81, `games/game-001/art/reviews/img/`:
- `kit_characters_crests_gameplay.jpg`: front view at about 40 studs, 1280×720;
- `kit_characters_crests_side_gameplay.jpg`: the same, from the side;
- one soldier per kingdom, plus a dummy with no kingdom.

Command: `python3 -I production/quality-gates/cvd/cvd.py OUT <both jpgs>`. I enlarged the soldier strip 3× to look at it.

**Palette.** The CIEDE2000 values are unchanged from run 1: crimson/emerald 14.7 protan and 15.1 deutan; azure/emerald 10.8 tritan. The colours alone still don't separate crimson and emerald soldiers.

**Crests (looked at in all four simulations, front and side).**
- Crimson has a pointed cone (spire). Emerald has a tall upright cylinder (plume), which leans back in the side view.
- Under protanopia and deuteranopia these two soldiers are the same olive, but cone and cylinder still read apart.
- Azure's flat square plate and gold's round dome are distinct in every simulation.
- Under tritanopia, azure and emerald are both teal, but the plate and the plume tell them apart.
- The dummy keeps the plain helm.
- At 40 studs a crest is about 12–15 px tall in the 960×540 simulation panel (about 16–20 px in the 1280×720 render). The spire and the plume are the two shapes closest to each other at that size. They differ in outline (triangle vs. bar) rather than in height.

**Verdict.**
- **Finding 2 is resolved in the renders**: friend and foe can be told apart without colour at gameplay distance in the Blender renders.
- **Unverified in Studio**, at the 50° aerial overview distance, and in the live game:
  - FORGE-01 must pass `kingdom` in `EntityController.buildRig` (a #81 dependency) before soldiers get crests in play;
  - the four-kingdom Studio screenshot (STUDIO_PLAYTEST colour-vision steps 1–6) is still owed.

Status: the soldier marker is acceptable for VS-1 on the render evidence, pending #81 merging, FORGE-01's `kingdom` plumbing and the Studio screenshot. Findings 3 (banner emblems from the overview) and 4 (tritanopia in Studio) are unchanged.

## Run 3: 2026-10-13, crest follow-up, PR #81 head `f4cfb86` (not yet merged)
**What changed.** FORGE-02 widened the spire base from 0.95 to 1.3 and tilted the plume from 55° to 70°. They report the front-view outline gap between spire and plume grew from 0.64 to 1.14 studs.

**Input.** Re-rendered `kit_characters_crests_gameplay.jpg` and `_side_gameplay.jpg`, plus a new `kit_characters_crests_aerial.jpg`: 50° elevation, about 50 studs, 1280×720, Blender (`bpy`).

**Command.** `python3 -I production/quality-gates/cvd/cvd.py OUT <3 jpgs>`. I looked at all four simulations with the soldier strips enlarged 3–4×.

**Front view.** Under protanopia and deuteranopia the crimson and emerald soldiers are still the same olive. The broad-based spire and the plume bent back now differ clearly in outline.

**Aerial view, 50°.** All four kingdoms are told apart without colour in every simulation:
- the spire reads as a broad peaked lump;
- the plume as a thin upright stick;
- the azure plate, seen from above, as a large flat square;
- the gold dome as a round knob.

**Tritanopia.** Azure and emerald soldiers are both teal, but the plate and the plume still separate them.

**Verdict: finding 2 (soldiers) passes on render evidence at both gameplay distance and 50° aerial.**

**Still open:**
- #81 has to merge after FORGE-07's verdict.
- FORGE-01 has to pass `kingdom` in `EntityController.buildRig`.
- The Studio four-kingdom screenshot (STUDIO_PLAYTEST colour-vision steps 1–6) has not been taken. It would also confirm the aerial camera's real distance, which may be more than 50 studs.
- Findings 3 and 4 are unchanged.

## Run 4: 2026-10-13, finding 3 (kingdoms from the overview camera), PR #105 head `c483f29` (not yet merged)
**What changed.** FORGE-02 put the D-039 emblem on every banner, flag, pennant, crest, `prop_banner` and
slot sign (ivory crown, star, oak leaf; deep-gold sun on gold), added an up-facing roof plaque and a
donjon-back plaque to each keep, and made `Kit.setKingdomColor` swap the emblem.

**Input.** PR #105's committed Blender (`bpy`) renders of the Lune Kit dump, 1:1 crops of 1920×1080 at the
Roblox 70° FOV, 50° down: `kit_emblems_aerial_170.jpg` (four keeps L1) and `kit_emblems_aerial_distances.jpg`
(120 / 170 / 220 studs). I also looked at FORGE-02's `kit_emblems_aerial_170_cvd.jpg` (their run of this
tool, plus grayscale).

**Command.** `python3 -I production/quality-gates/cvd/cvd.py OUT kit_emblems_aerial_170.jpg kit_emblems_aerial_distances.jpg`;
I looked at all four simulations for both images. Closest kingdom pairs (ΔE): protanopia crimson/emerald
14.7, deuteranopia crimson/emerald 15.1, tritanopia azure/emerald 10.8.

**What tells the kingdoms apart without colour, from the overview camera:**
- **Roof silhouette** (the strongest cue at every distance): crimson's stacked cones, azure's tall
  pyramids, emerald's hipped roofs with a dark eave band, gold's onion domes.
- **Roof plaque emblem**: at 120 and 170 studs the star and the sun read clearly, the crown reads as a
  crown, and the oak leaf reads as a leaf; at 220 studs (about 10 px) the star and the sun still read,
  the crown is a light blob and the oak leaf is the weakest.
- Protanopia and deuteranopia: crimson and emerald go olive and grey; cones vs hipped roofs and crown vs
  leaf separate them. Tritanopia: azure and emerald are both teal; pyramids vs hipped roofs and star vs
  leaf separate them. Grayscale (FORGE-02's strip): all four separate by silhouette and emblem.

**Verdict: finding 3 passes on render evidence** at 120-220 studs, with the roof silhouette as the main
cue and the emblem as the second. The oak leaf is the weakest emblem (also #86 L7 in the UI).

**Still open:** the Studio four-kingdom screenshot (STUDIO_PLAYTEST colour-vision steps 1-7, the B7/B8
asks) would confirm the real camera distance and finding 4 (tritanopia in Studio).

**Update 2026-10-13:** #105 merged on main as `f562a31` (FORGE-05 D-040 verdict on `f44cfc3`, after
CHANGES REQUESTED for the slot-marker and stage budget gates). Finding 3 is resolved on render evidence;
findings 1, 2 and 3 now wait only for the Studio screenshot.
