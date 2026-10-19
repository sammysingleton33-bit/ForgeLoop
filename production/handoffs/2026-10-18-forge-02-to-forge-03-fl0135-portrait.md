# Handoff: FORGE-02 → FORGE-03 · FL-0135 mesh citizens in the conversation portrait · 2026-10-18

## What I need / what I'm giving you
`Kit.portrait` now builds the imported mesh rig when the kit is imported (same call, same `PortraitFocus` camera contract). One thing is needed on the client: the Kit must know the asset
folder before the first portrait (the same one-line `Kit.setAssetSource(ReplicatedStorage.Forge.Assets)` I ask FORGE-04 to add in `EntityController:start()`, see my handoff to FORGE-04).

## Done (with commits)
- Branch `forge/02-blender-fl0135-runtime`: `Kit/Portrait.luau` builds through `CharacterMesh.character` and frames everything welded to the Head, directly or through its hat.

## Evidence
- `tests/world/KitCharacterMeshPose.spec.luau` (headless, fake MeshParts): anchored parts, motors and welds kept, `PortraitFocus`/`PortraitFov`/`PortraitDistance`, head + headwear + both shoulders in view, `Kit.posePortrait`
  absolute and restorable. The old `KitPortrait.spec` still passes unchanged on the part-built rigs. **Studio unverified**; nobody has looked at a mesh portrait.

## Interfaces touched
None. `PortraitView` (yours) needs no change: `Kit.portrait("citizen", job, colour, look, nil)` returns a mesh rig with the same part names Torso/Head/LeftArm/RightArm/... and the camera from `Kit.portraitCamera`.

## Open issues and risks
- If `Kit.setAssetSource` was not called on the client before the first portrait, the portrait is part-built (a fallback, not an error). The conversation stage's drawer fallback is not involved.
- A mesh portrait's face comes from the head mesh's baked vertex colours (no `Face` Decal), so `PortraitView` code must not look for a Decal.

## Next actions for the receiver
1. Check nothing in `PortraitView` / `ConversationStage` / `FeedbackPoseController` reads the primitive part names `Hair`/`Detail1`/`Face`. (A grep of main found none outside Kit; the mesh rig names its hair piece `Hair` too.)
2. After the owner's import, the Studio row's portrait screenshot (FL-0135 acceptance).

## Files to read
- `games/game-001/src/shared/Kit/Portrait.luau` — the worn-parts walk
