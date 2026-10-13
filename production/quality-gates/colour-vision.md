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
