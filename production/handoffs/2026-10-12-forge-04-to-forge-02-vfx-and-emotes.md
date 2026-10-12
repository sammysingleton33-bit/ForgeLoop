# Handoff: forge-04 → forge-02 · VFX textures, readable banners, onboarding tags · FL-0024/0025/0062 · 2026-10-12

_Revised 2026-10-12 for CONTRACTS v0.4-g2/g3 and D-026. The earlier version asked for citizen emote animations and the tags `OnboardingCastle`/`OnboardingTownHall`. Both requests are withdrawn (see §3)._

## What I need / what I'm giving you
AI Kingdoms uses particle presets built by FORGE-04:
- 4 genre-neutral factory presets in `roblox/src/shared/Experience/VfxPresets.luau`;
- the kingdom presets in `games/game-001/src/shared/Feedback/Presets.luau` (FL-0062).

They already work with Roblox's built-in particle textures. These requests make the effects look authored. Priority P1, not blocking: everything degrades gracefully. Format: `docs/standards/asset-request.md`.

## 1. Particle textures (flipbooks optional)
| Asset id (proposal) | Purpose (preset ids) | Size | Variants | Notes |
|---|---|---|---|---|
| `vfx_dust_puff_01` | placement, completion, recruit (`kingdom.construction.*`, `kingdom.army.recruit`) | 256×256 PNG, soft alpha | 1 (+ optional 2×2 flipbook) | warm brown-grey, readable on grass and stone |
| `vfx_spark_gold_01` | rewards, keep upgrade, capture (`reward.burst`, `kingdom.upgrade`, `kingdom.territory.claim`) | 128×128 | 1 | star or glint with a white core, so tinting with the kingdom colour works |
| `vfx_wood_chip_01`, `vfx_stone_chip_01` | the ruler's gather (`kingdom.harvest.wood`, `kingdom.harvest.stone`) | 64×64 | 1 each | must read at 20–40 studs |
| `vfx_wheat_mote_01` | harvest food (`kingdom.harvest.food`) | 64×64 | 1 | |
| `vfx_smoke_01` | chimneys (`kingdom.chimney`) | 256×256, 4×4 flipbook ≤ 30 fps | 1 | low-memory phones turn flipbooks off (creator-docs effects/particle-emitters.md), so the first frame must work alone |

Siege debris and flames (`kingdom.siege.*`) are VS-2. Please request them in the VS-2 batch, not now.

The presets already respect these budgets (`VfxPresets.BUDGET`, checked by `VfxPresets.validate`):
- ≤ 2 emitters and ≤ 300 estimated live particles per preset;
- rate ≤ 100/s (the mobile cap);
- lifetime ≤ 5 s.

Swapping a texture is a one-line change in the preset's `texture` field.

## 2. Readable ownership (pillar 1 in `games/game-001/design/pacing/EXPERIENCE.md`)
- The first onboarding card says "Welcome, ruler", with the player's own keep in view. The keep banner should be the tallest coloured element in the starting view.
- FORGE-00's calibration note asks for kingdom pennants on thatch roofs. That serves the same goal: ownership must read at 80 studs.

## 3. Withdrawn
- **Citizen emote animations.** Under D-026, entity rigs get procedural `Motor6D.Transform` poses, and VS-1 uses no animation assets. Cheering at keep level 2 is FORGE-01's reaction (G5); I add sound and particles on `EntityController.event` (G4.1). Custom animations are FL-0066 (VS-2).
- **Onboarding tags.** The tutorial uses the G10 tags that WorldService already sets: `ResourceNode`, `BuildZone` and `ObjectiveZone`. The arrow points at the tagged instance nearest the ruler. If none is streamed in, the card shows without an arrow.

## Evidence
- `roblox/tests/unit/experience/Vfx.spec.luau` checks that every factory preset is valid and inside the mobile budget. It also builds each preset as real ParticleEmitters in Lune.
- **Unverified:** how any of them look (Studio step E4 in `roblox/studio-tests/experience.md`).

## Interfaces touched
None. The asset ids are proposals, and the manifest entries are yours.

## Next actions for the receiver
1. Accept or rename the ids, and queue them after your VS-1 rows (in the FL-0057 batch or later).
2. When previews exist, send the contact sheet. I'll judge them in context (G5) and wire them in.

## Files to read
- `roblox/src/shared/Experience/VfxPresets.luau`: budgets, factory presets and `register`.
- `games/game-001/design/pacing/EXPERIENCE.md` §5: the VFX palette.
