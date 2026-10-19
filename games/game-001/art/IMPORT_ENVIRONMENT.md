# Import the nature kit into Studio (FL-0136, D-057 (18)-(20)) — one page, ~30 min, after the citizen kit

Trees, bushes, rocks, resource nodes, flowers and crops. Buildings stay part-built. **Every Studio step below is UNVERIFIED**:
nobody has run this in Studio yet; the script and the Kit were tested headless only (Lune, fake instances). Menu names are from
the Roblox docs and may differ in your Studio: if a step does not match, stop and report what you see. Nothing costs money.

## 0. Same as the citizen kit — do it once, before the FIRST upload
Asset Privacy on, user or group owner confirmed, upload destination = that owner (steps 0 and 2.1 of `IMPORT_CHARACTERS.md`). The same
Studio session and place can import both kits: do the citizens first, then this page. Do not upload the nature kit before Asset Privacy is on.

## 1. Files
- `env_kit.fbx` from the Blender worker (expected at `games/game-001/art/env_kit/`, or the PR's CI artifact), one mesh object per prop, named by asset id.
  Import only `env_kit.fbx` (**56 ids**: the 52 the part-built world places, plus 4 the world places **only as imported meshes**: `farm_fence_01/02` along the crop fields and `farm_field_cabbage_01/02` (the cabbage fields' variants); `tree_oak_05` is 5 % narrower than in the first import). If you imported the 52-id file of the first FL-0136 round, import this one again: it has 4 new objects.
  `env_kit_spares.fbx` (11 finished spares nothing places: wood nodes, iron and crystal ore (not game resources), wheat 03 and the two growth stages (the world has no growth), the rock cliffs (their rim placement was dropped)) is not needed. If an id is missing or rejected, the world simply does not place its dressing (`WorldPlan.meshDressing`) and builds nothing part-built in its place.
- A place built from the repo: `rojo build games/game-001/default.project.json -o crownfall.rbxl`. It must contain
  `ReplicatedStorage.Game.Kit.EnvMeshData` (made by `python3 games/game-001/art/env_kit/env_to_luau.py`) and `ReplicatedStorage.Forge.Assets`.

## 2. Import (Studio)
1. **View > Asset Manager > Bulk Import**, pick `env_kit.fbx`. Settings: **Scale Unit: Studs** · **Ignore Vertex Colors: OFF** (unticked) ·
   **Merge Meshes: OFF** · Rig Type: **No Rig** · axes: the defaults (the FBX is Y-up, -Z-forward) · upload to the **owner from step 0**.
   A model (`env_kit`) of MeshParts appears in Workspace.
2. **View > Command Bar**: paste the whole of `blender/studio/import_env_kit.luau`, press Enter (`DRY_RUN = true` at the top only reports). It wraps every
   MeshPart in a Model named by its asset id (invisible `Root` at the base centre + the mesh `Body`) under `ReplicatedStorage.Forge.Assets.EnvKit`, strips
   everything but the geometry, and asks the Kit whether it accepts each prop. Run it again any time: it replaces, never duplicates; Ctrl+Z undoes a run.
3. Read the Output. **Good: `RESULT: OK` and `Kit.prop accepts N of N props`.** Not good: `MISSING`, `WRONG SIZE` (a scale or unit mistake), `NO MESH` (the
   upload failed), `ROTATED` (axes), or `part-built still (...)` lines: do not continue, send the Output to FORGE-02. Triangle counts are not available in Studio
   (they are Blender's, `env.json`). A `TEXTURED` line is information (the contract is vertex colours only).
4. The script selects `EnvKit`. Right-click it > **Save to File...** > `roblox/assets/EnvKit.rbxm` in the checkout (a few KB: mesh ids, not meshes) and commit it in a PR
   (FORGE-05/02): that is what makes `rojo build` include the props. Rojo cannot live-sync mesh ids: use `rojo build`, not `rojo serve`, to see them.
5. Delete the leftover `env_kit` model from Workspace, **File > Save**, and Publish if you play from Roblox.

## 3. Look at it (Play, F5) and measure
**First, the Play-test check (a game script has fewer rights than the command bar, so a smoke test that passes in the command bar can still fall back
in Play):** in the **server** Output there must be **no** line `Kit.prop: the imported ... is not used (...)`, and in the server command bar
`print(require(game.ReplicatedStorage.Game.Kit.Kit).envMeshStatus())` must show `accepted` equal to the number of props (56 with the dressing) and an empty `rejected`.
(CollisionFidelity is set by the import script, not by the Kit: a game script cannot write it. Hull on each `Body` is in the saved `EnvKit.rbxm`.)
If the Output has `not used` lines, stop and send them to FORGE-02: those ids are still the part-built stand-ins.

Forests, lone trees, bushes, rocks, flowers and the farm fields from the **aerial camera** and the **82-stud gameplay camera**, next to the kingdom buildings and the
citizens (does it look like one world? are trunks and rocks solid for the ruler? do the resource nodes sit where the stand-ins did?). In Explorer, `Workspace.World.Props`
holding Models with a `Body` MeshPart are the mesh props; the old multi-part Models are the stand-ins (the Kit falls back per id). Then the **300-citizen phone stress
test** from `IMPORT_CHARACTERS.md` (Render Stats: FPS, triangles, draw calls) and screenshots at the **aerial** and **portrait** views.

## 4. Revert
Delete the `EnvKit` folder (and `roblox/assets/EnvKit.rbxm` from the repo): every prop is its part-built stand-in again at the next play or build.

## 5. Report back
The script's Output (paste it) · aerial and gameplay-distance screenshots · Render Stats and FPS from the phone · whether a user or a group owns the experience and
Asset Privacy was on before the upload · anything wrong (scale, floating or sunk props, a solid thing you walk through or a ghost wall, colours) with a screenshot.

*Unverified in Studio: the importer settings; vertex colours through `MeshPart.Color`; a MeshPart's position being its bounding-box centre; mesh ids surviving the `.rbxm` round
trip; collision of the `Collider` parts; the script on a real Workspace; the phone numbers. Headless evidence: `tests/world/KitEnvMesh*.spec.luau`.*
