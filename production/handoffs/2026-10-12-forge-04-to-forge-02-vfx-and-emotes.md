# Handoff: forge-04 → forge-02 · VFX textures, citizen emotes, onboarding props · FL-0024/0025 · 2026-10-12

## What I need / what I'm giving you
AI Kingdoms (Game #1, user directive 2026-10-12) uses particle presets and citizen reactions that FORGE-04 built. The presets work with Roblox's built-in particle textures. These requests make the effects look authored, so citizens can *show* reactions and not only speak them. Priority P1, not blocking: everything degrades gracefully. Format follows `docs/standards/asset-request.md`.

## 1. Particle textures (flipbooks optional)
| Asset id (proposal) | Purpose | Size | Variants | Budget | Notes |
|---|---|---|---|---|---|
| `vfx_dust_puff_01` | construction place/complete, army recruit (`kingdom.construction.*`, `kingdom.army.recruit`) | 256×256 PNG, soft alpha | 1 (+ optional 2×2 flipbook) | 1 texture | warm brown-grey, readable on grass and stone |
| `vfx_spark_gold_01` | rewards, upgrades, territory claim, victory (`reward.burst`, `kingdom.upgrade`, `kingdom.victory`) | 128×128 | 1 | 1 texture | star/glint, white core so tinting with the kingdom colour works |
| `vfx_debris_stone_01` | siege impacts (`kingdom.siege.impact`) | 128×128, 2×2 flipbook | 4 chunks | 1 texture | must read at 60–120 studs |
| `vfx_wheat_mote_01` | harvest food (`kingdom.harvest.food`) | 64×64 | 1 | 1 texture | |
| `vfx_flame_01`, `vfx_smoke_01` | burning buildings, chimneys (`kingdom.siege.burning`, `kingdom.chimney`) | 256×256, 4×4 flipbook ≤ 30 fps | 1 each | 2 textures | creator-docs effects/particle-emitters.md: flipbooks are disabled on low-memory phones, so the first frame must work alone |

Budgets the presets already respect:
- ≤ 2 emitters and ≤ 300 estimated live particles per preset;
- rate ≤ 100/s (mobile cap) and lifetime ≤ 5 s;
- see `roblox/src/shared/Experience/VfxPresets.luau`.
Swapping a texture is a one-line change in `VfxPresets.TEXTURES`.

## 2. Citizen emote animations (with FORGE-01's citizen rig)
| Emote id (attribute `ForgeEmote`) | When | Length | Notes |
|---|---|---|---|
| `cheer` | building complete, festival, battle won | 1.5–2.5 s | arms up, small hop |
| `work` | construction started nearby | 2 s | hammer swing or rolled-up sleeves |
| `nod` | task accepted | ~1 s | quick bow/nod toward the ruler |
| `slump` | low morale, battle lost | 2–2.5 s | shoulders drop, head down |
| `flee` | under attack | while set (≈ 2 s; FORGE-01 moves them to the keep) | arms up, run cycle |

`VFXController` sets the attribute for about 2 s and clears it. FORGE-01's citizen animator plays the matching animation.

## 3. Onboarding props
- The player's **castle** and **Town Hall** need the tags `OnboardingCastle` / `OnboardingTownHall` (placed by FORGE-01/FORGE-05 in the map). For readability, the castle banner should be the tallest coloured element in the starting view: the tutorial says "Your banner marks your kingdom".

## Evidence
- Current presets validated by spec `Vfx.spec.luau` ("every shipped preset is valid and inside the mobile budget") and built as real ParticleEmitters in Lune. **Unverified:** how any of them look (Studio step E4).

## Interfaces touched
None (asset ids are proposals; manifest entries are yours).

## Next actions for the receiver
1. Accept or rename the ids; add them to your queue (FORGE-00 can turn this into a task).
2. When previews exist, send the contact sheet; I'll judge them in context (G5) and wire them in.

## Files to read
- `roblox/src/shared/Experience/VfxPresets.luau` — presets, colours and budgets
- `roblox/src/shared/Experience/CitizenReactions.luau` — reactions and emotes
