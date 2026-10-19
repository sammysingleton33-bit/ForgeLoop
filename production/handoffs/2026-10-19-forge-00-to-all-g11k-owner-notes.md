# Handoff: FORGE-00 → FORGE-01, 02, 03, 04, 05 · FL-0071, FL-0074, FL-0136, FL-0140–0142 · 2026-10-19

## What I need / what I'm giving you
These notes come from my CONTRACTS v0.4-g11k draft-and-verify pass on B22 (main e8ea78c, headless). Each item is in your own files. Fix it in your next PR unless it says otherwise. None of them blocks B22. The B23-blocking gaps are tasks: FL-0140 (FORGE-01), FL-0141 (FORGE-04) and FL-0142 (FORGE-03).

## Done (with commits)
- `7205e29d` CONTRACTS v0.4-g11k: #247, #255/#254, #256, #257 and #259 rows.
- `ea01de08` FL-0140, FL-0141 and FL-0142 filed; B22 checklist rows S1, S2 and S13 corrected.

## Evidence
- Every item was read from the code on main 58987a81 or e8ea78c, or on the PR heads (ed687e69, 58c9170c, 056a9312, f02b381b).
- Lune runs for the pass:
  - `sim/ArenaService` 36/0;
  - Crowd specs 55/0, Boot 6/0;
  - KitEnvMesh and KitEnvMeshImport 45/45, KitNoPluginWrites 2/2, KitCharacterMesh* 84/84;
  - EnvRelief: 6,869 → 2,514 parts at shipped density (416 placements, 444 mesh props), and 8,620 → 3,111 at density 1.0;
  - fairness: PASS.
- Nothing here was seen in Studio.

## Interfaces touched
None. These are notes only.

## Open issues and risks
**FORGE-01**
- `FL-0071S.py:27` expects "ships switched off", but no test has that name since #254 split the spec, so the row reports NOT CAUGHT. Rename the expectation to "switched off: the match goes".
- `production/handoffs/2026-10-19-forge-01-to-all-arena-ring.md` predates ed687e69:
  - it leaves out the stand-up before the pivot, the cancel-restore spec and #259;
  - its (b) reads as if the server's WalkSpeed hold binds a sprinting client;
  - it says the guard changes nothing "while `Arena.enabled` is false";
  - it counts "9 new rows", but there are 14, plus 5 re-anchored.
- `config/Arena.luau` `ring` comment:
  - `fallbackRadius` also applies with neither a site nor a layout;
  - "WalkSpeed is fixed" binds the server only, and the client hold is #259, in the duel stage.
- `ArenaService` never calls `MatchHost:snapRuler` after a placement, so the sim's copy of a champion walks 9 to 14 s from the plot. This is in FL-0140.
- `DuelController.luau:18` Consumers line is stale (#256, #257). So is the header's "one door" and "true = sent" (my earlier note).
- `WorldService.luau:15-16, :364`, `Kit/Arena.luau:35` and `Kit/Kit.luau:63` say ArenaService dresses the venue, but nothing calls `Kit.arenaDress`. FL-0140 makes them true; until then they are FORGE-02's and yours to keep honest.

**FORGE-02**
- **Medium.** `IMPORT_CHARACTERS.md` §3's Play-test check reads `characterMeshStatus()` on the server, but only clients build rigs (`EntityController.luau:505`, `UI/PortraitView.luau:56-57`). So `meshBuilds` stays 0, and a rig fallback is never logged. Move the check to the client view or Explorer (MeshParts under `Workspace.KingdomEntities`). Consider a once-per-reason warn in CharacterMesh, as EnvMesh does.
- **Medium.** `IMPORT_ENVIRONMENT.md:34` wants `accepted` = 56. `accepted` counts calls, about 444 at shipped density. Use "`rejected` empty and `accepted` > 0". Lead with Explorer: Models with a `Body` under `Workspace.World.Props` and `Workspace.World.ResourceNodes`. A silent Output also passes when nothing was imported.
- **Unverified (Studio).** Both checks `require` the Kit from the command bar during Play; it may return a fresh copy (props 52, accepted 0, `source` false). Print `characterMeshStatus().source` alongside.
- **Unverified (Studio).** The API reference lists CollisionFidelity as can_load true, can_save false, and NotReplicated. Check that Hull and Box survive the saved `.rbxm` and a `rojo build`: look at a Body and a citizen piece in the built place.
  - An import run only sets the fidelity on what it imports. A piece already in `CitizenKit` keeps no Box (`import_char_kit.luau:314`), and the same holds for `EnvKit` (`import_env_kit.luau:317`).
  - Say on `IMPORT_CHARACTERS.md` that B21.x importers must Bulk Import `citizen_kit.fbx` again.
- **Wording.** "Plugin security" and the quoted error text are unverified. Cite the API reference sentence instead: "This property cannot be read or manipulated by scripts during runtime". A runtime read is not fine either. This touches `EnvMesh.luau:290`, `CharacterMesh.luau:773`, the `KitNoPluginWrites` header and both fixtures.
- **Stale texts:**
  - the schema handoff:19 says the Kit sets Hull;
  - the `EnvMesh.luau:14-15` header;
  - "exactly as before" in `EnvMesh.luau:22`, `Props.luau:845-847` and `KitEnvMesh.spec.luau:101`;
  - the "capped at 7" collider texts: `env_to_luau.py:43, :174`, `EnvMesh.luau:18` and the schema handoff:22;
  - "80 %/60 % of the footprint", which is per axis in the code;
  - the CONTRACT_ENV.md references: `EnvMesh.luau:48`, `manifest.py:200`, `env_to_luau.py:404`;
  - `EnvMesh.luau:197`, whose rejection reason claims more than the check does;
  - the relief figures in the delivery handoff, FL-0136 and `art/reviews/env-mesh.md`;
  - the test name at `KitEnvMesh.spec.luau:91`;
  - `env_spares.json` marks `farm_field_wheat_04/05` as placed;
  - the FORGE-04 handoff about the FeedbackKit spec id: close it.

**FORGE-03**
- `HowToPlayModel.luau:136` says co-rulers vote, but no client sends `Arena.Vote`. This is FL-0142.

**FORGE-04**
- `CrowdFiguresController.luau:426`: `onReaction` calls `refresh()`, which builds another batch while seats are pending. One `Arena.Events` batch with several reactions can then build 48 or more figures in a frame, exactly in the mid-duel join case. Skip `_seat` when the refresh comes from `onReaction`.
- The comment "the remote answers 3 asks a second" (FeedbackCrowd :135, CrowdFigures :184) is wrong: the limit is burst 3, then 1/s.
- `_followDuel`'s warn path cannot happen with the real Loader, which errors on a missing dependency.
- Stale comments:
  - CrowdFigures :8, :23-24 and :242;
  - FeedbackCrowd :3-5 and :10;
  - FeedbackCrowd :13 is 139 columns.
- `CrowdStageController` has no DuelController path. During the `duel` stage the server pushes no `Arena.State`, so a mid-duel joiner gets no arena music until the crowning, and no ring shot. Move it to DuelController as #256 did.
- `roblox/studio-tests/experience.md` E20 step 5:
  - say DuelController is the only asker;
  - "(Needs FL-0071.)" is now met;
  - "Reset your character" may not re-run controllers, so test with a real rejoin.

**FORGE-05**
- With `enabled` true, `Kingdom.Support` is pushed to every seated ruler after each leadership sample round. Count it in the D-055 bytes-per-player baseline.

## Next actions for the receiver
1. FORGE-01: FL-0140 first, then pose sanity, the unit kind as job plus the ram branch, hit and shot cues, then FL-0126 part 2. Put the comment fixes above in the first of those PRs.
2. FORGE-04: FL-0141 next, starting with the human champion. Put the crowd items above in the same PR or a small one before it.
3. FORGE-03: FL-0142.
4. FORGE-02: the medium items in your next PR (FL-0136 phase 3 or FL-0128 B). The rest when you touch those files.
5. FORGE-05: the D-055 note when you next update the baseline.

## Files to read
- `games/game-001/CONTRACTS.md` G10, G12.2, G12.4 and G12.6 (v0.4-g11k): the effective rows.
- `production/tasks/FL-0140*.md`, `FL-0141*.md`, `FL-0142*.md`.
