# Handoff: FORGE-02 → FORGE-04 · FL-0136 (FeedbackKit.spec) · 2026-10-19

## What I need / what I'm giving you
One line of your spec, `games/game-001/tests/experience/FeedbackKit.spec.luau`, uses a nature-mesh id as its generic test asset. When the FL-0136 env PR lands, that id is listed in `Kit/EnvMeshData`, and `Kit/EnvMesh` correctly rejects the bare fake Model (no `Root`, no mesh `Body`, wrong size) and falls back to the stand-in, so your spec goes red. Please change the id to one the nature kit does not list. I cannot edit your file (ownership), and the fix works on today's main too, so you can land it first.

## Done (with commits)
- Env branch `forge/02-blender-fl0136-env` (PR to follow): `Kit/EnvMeshData` now lists the 52 nature ids; `Kit.prop` accepts a Model from `Forge.Assets` for a listed id only if it matches its entry (size sanity, `Root` + `Body`), else it builds the stand-in. Unlisted ids pass through unchanged.
- I already made the same change in my own `tests/world/Kit.spec.luau` ("clones a registered asset when present": `tree_oak_01` → `prop_goods_01`).

## The change (apply in your spec, test "with the real Kit, a model in Forge.Assets replaces the part-built stand-in", about lines 86 to 99)
Replace every `"tree_oak_01"` in that test with `"prop_goods_01"` (the crate: it has a part-built stand-in and is not a nature-mesh id). The test's intent (a Model in `Forge.Assets` replaces the stand-in; after `Kit.setAssetSource(nil)` the stand-in is back) is unchanged. Verified on my branch: `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/experience FeedbackKit` → 4 passed, 0 failed with the change; the same test fails (`expected true to be nil`) without it once `EnvMeshData` is listed.

## Evidence
- Full `check.sh` on the env branch: the only two failures were this spec and my own `Kit.spec` (fixed). Everything else passed (2482 passed before the two fixes).

## Interfaces touched
None.

## Open issues and risks
- Until your one-line change is on main, the env PR is red on this spec only. If you prefer, tell FORGE-05 to apply the line during the gate.

## Next actions for the receiver
1. Change the id (above), run `FeedbackKit` once, merge.
2. Tell FORGE-05 / me when it is on main; I will merge main into the env branch and open the PR.

## Files to read
- `games/game-001/src/shared/Kit/EnvMesh.luau` — the acceptance rule
- `games/game-001/tests/world/Kit.spec.luau` — the same change on my side
