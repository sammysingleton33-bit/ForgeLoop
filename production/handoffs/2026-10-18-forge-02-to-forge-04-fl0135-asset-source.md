# Handoff: FORGE-02 → FORGE-04 (cc FORGE-03, FORGE-00) · FL-0135 mesh citizens: give the client the asset folder · 2026-10-18

## What I need / what I'm giving you
`Kit.character` can now return a Blender MeshPart rig (D-057) instead of the part-built one, but only if the Kit knows the folder the meshes live in.
`WorldService` (server) already calls `Kit.setAssetSource(ReplicatedStorage.Forge.Assets)`; **the client never does**, and `EntityController` and `Kit.portrait`
run on the client. Please add one call on the client before the first rig is built. Nothing else of yours changes.

## Done (with commits)
- Branch `forge/02-blender-fl0135-runtime`: `Kit/CharacterMesh.luau` (builder + fallback), `Kit/CharacterMeshData.luau` (EMPTY until the real kit lands), `Kit.setAssetSource` now also
  hands the folder to the character builder, `Kit.characterMeshAvailable()` and `Kit.characterMeshStatus()`. With the committed (empty) data every build is today's part-built rig,
  so nothing changes in a build until the owner imports the meshes.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world KitCharacterMesh`: headless, fake MeshParts, placeholder kit
  (see the FORGE-02 report for counts). Mesh rigs have the SAME Motor6D names as `Sim/Pose.JOINTS`, axis-aligned joint frames, an anchored invisible Root with the pivot at the feet,
  and the pose/clearance rules of `tests/sim/PoseClearance.spec` hold on them. **Not seen in Studio.**
- `Sim/Pose.JOINTS`, `Pose.LIMITS`, the wire (EventCodec, SnapshotCodec) and `Kit.CHARACTER_ROOT_HEIGHT` (3.2) are unchanged.

## Interfaces touched
Additive in `Kit`: `Kit.characterMeshAvailable()`, `Kit.characterMeshStatus()`; `Kit.setAssetSource` also feeds the character builder. `Kit.character` / `Kit.portrait` signatures are unchanged.

## Open issues and risks
- Without the client call, mesh rigs would exist only on the server and the owner's import would change nothing on screen. `Kit.characterMeshStatus()` says why (`source = false`).
- Your pool key `kind|job|kingdom|Kit.lookKey(look)` is still the right key: a mesh rig depends on the look only through `Kit.lookKey` (and soldiers through the kingdom), and
  `Kit.setKingdomColor` recolours it exactly (specs). A rig that was built before the call (part-built) stays part-built in your pool: call it before the first `_acquire`.
- A mesh rig has no `Tool` Motor6D when the citizen carries nothing (idle), and its `Tool` motor hangs off the Torso for the hauler's sack; `rig.motors[name]` / `joints[joint] or IDENTITY` already copes.
- Optional: log `Kit.characterMeshStatus()` once after the first rig (pieces, missing, meshBuilds, fallbackBuilds, lastFallback) so the owner's playtest output shows which rigs were mesh.

## Next actions for the receiver
1. In `EntityController:start()` (or any client controller that starts before the first rig; the call is idempotent and shared by every client Kit user, including `Kit.portrait`):
   ```lua
   local forge = env.ReplicatedStorage:FindFirstChild("Forge")
   Kit.setAssetSource(forge and forge:FindFirstChild("Assets") or nil)
   ```
2. Add a spec line that the controller calls it (a fake `env.ReplicatedStorage` with `Forge.Assets` and a `CitizenKit` folder makes `Kit.characterMeshAvailable()` true).
3. Studio row (after the owner's import, FORGE-05): the citizens at the aerial camera are MeshParts under `Workspace.KingdomEntities`.

## Files to read
- `games/game-001/src/shared/Kit/CharacterMesh.luau` — header: the data format, the fallback rule, part names and attributes
- `games/game-001/art/IMPORT_CHARACTERS.md` — the owner's procedure
