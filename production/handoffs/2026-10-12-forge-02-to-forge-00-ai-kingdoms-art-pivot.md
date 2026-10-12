# Handoff: FORGE-02 → FORGE-00 — Game #1 is AI Kingdoms: art pivot, task re-scope, calibration

Date: 2026-10-12 · From: FORGE-02 · To: FORGE-00 (Director)

## What happened
The user told FORGE-02 directly (FORGE-02 session, 2026-10-12): **"Game #1 is AI Kingdoms, not Flood Island"**: four competing medieval kingdoms. FORGE-02 was told to stop prioritising jungle-survival assets unless they support the medieval world or reusable generators. `DECISIONS.md` and FL-0035 do not record this yet. That is FORGE-00's to record (FORGE-02 does not edit them).

## What FORGE-02 did
- **FL-0013 (pipeline core)** is built as specified, with the medieval world as its first customer: palette texture, kit, rig, FBX export, validation, manifest + schema, `check.sh` and tests. It stays genre-agnostic.
- Instead of the jungle work in FL-0014/15/16, FORGE-02 is producing the **first medieval environment kit**:
  - castle: wall, tower, gatehouse, keep, per kingdom;
  - village: cottage, market, smithy, storehouse, barracks, tavern, workshop;
  - farm: field, fence, haystack, windmill, barn;
  - vegetation: oak, pine, birch, bush, flowers, grass;
  - rocks and resource nodes;
  - citizens and soldiers;
  - banners, siege, bridges, props;
  - a cohesion vignette.
- **Art bible:** `blender/ART_DIRECTION.md`. It sets the human-scale standard and the kingdom identity levers.
- **Budgets:** medieval budget classes added in `blender/budgets.json` (FORGE-02-owned): buildings 5k/8k/12k, castle wall/tower/gate/keep 3k/6k/9k/16k, character 2.5k, siege 4k, bridge 4k, resource 1.5k, crop 3k. The jungle classes are unchanged.

## Requests to FORGE-00
1. **Record the decision.** Game #1 = AI Kingdoms (DECISIONS + FL-0035), with the user's approval as the source.
2. **Re-scope the FORGE-02 tasks:**
   - FL-0014 → "Medieval vegetation generators" (oak/pine/birch/bush/flowers)
   - FL-0015 → "Rocks, resource nodes and castle kit"
   - FL-0016 → "Medieval village vignette and Studio import pack"
   - New tasks for the village buildings, farms, characters and siege/props sets. Or close FL-0014/15/16 and open new ones; your choice.
3. **Kingdom names:** confirm or replace the *working names* in `ART_DIRECTION.md` §3: Emberhold (red), Frostmere (blue), Thornwood (green), Sunspire (yellow). Also the emblems: flame/crown, star, oak leaf, sun.
4. **Calibration (D-019):** the first sheets for the user/FORGE-00 to judge are `blender/previews/house_cottage.jpg` and `blender/previews/tree_oak.jpg`. They replace `tree_broadleaf`, because the jungle tree is no longer first.
5. **Game brief for AI Kingdoms (§9 art):** point it at `blender/ART_DIRECTION.md` and `blender/manifest.json`.

## Not done / unverified
- Nothing has been imported into Roblox Studio (G6). The desktop-Blender rebuild (`roblox/studio-tests/assets.md` A0) has not been run by the user.
