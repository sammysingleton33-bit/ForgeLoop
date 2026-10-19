# Import the nature kit into Studio (FL-0136, D-057 (18)-(20)) — one page, ~30 min, after the citizen kit

Trees, bushes, rocks, resource nodes, flowers and crops. Buildings stay part-built. **Every Studio step below is UNVERIFIED**:
nobody has run this in Studio yet; the script and the Kit were tested headless only (Lune, fake instances). Menu names are from
the Roblox docs and may differ in your Studio: if a step does not match, stop and report what you see. Nothing costs money.

## 0. Same as the citizen kit — do it once, before the FIRST upload
Asset Privacy on, user or group owner confirmed, upload destination = that owner (steps 0 and 2.1 of `IMPORT_CHARACTERS.md`). The same
Studio session and place can import both kits: do the citizens first, then this page. Do not upload the nature kit before Asset Privacy is on.

## 1. Files
- `env_kit.fbx` from the Blender worker (expected at `games/game-001/art/env_kit/`, or the PR's CI artifact), one mesh object per prop, named by asset id.
  Import only `env_kit.fbx` (the 52 ids the world places today). `env_kit_spares.fbx` (15 finished spares nothing places yet) is not needed until the world uses them.
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
**First, check that the meshes are really in use (a game script has fewer rights than the command bar, so an import that passes the command-bar smoke test can still
fall back in Play; and a quiet Output also looks fine when nothing was imported at all):**
1. **Explorer first.** In Play, open `Workspace.World.Props` and `Workspace.World.ResourceNodes`: a tree, bush, rock or crop field that is a Model holding just `Root`
   (an invisible Part), `Body` (a **MeshPart**) and sometimes `Collider` is the mesh prop; a Model with many small Parts is the part-built stand-in. Most of the trees, rocks and
   fields should be the mesh kind. (Nothing is wrong if a few ids are still stand-ins because they were not in the kit: say which.)
2. The **server** Output (View > Output, Server) has **no** line `Kit.prop: the imported ... is not used (...)`.
3. In the server command bar: `local s = require(game.ReplicatedStorage.Game.Kit.Kit).envMeshStatus(); print(s.props, s.accepted, next(s.rejected))` must print
   props = 52, `accepted` above 0 and **no rejected id** (`rejected` empty). `accepted` counts every mesh prop the world has built (hundreds), not the ids. The command bar can hand
   you a fresh copy of the module (accepted 0, and the Kit has no asset source): if `accepted` is 0, trust step 1 (Explorer), and tell FORGE-02 what you saw in both.
4. **CollisionFidelity (unverified).** The import script sets Hull on every `Body` (a game script cannot read or write the property at runtime, the API reference says so). The
   reference also lists it as not saved and not replicated: after you save `EnvKit.rbxm` and run `rojo build`, select one `Body` in the built place and read **CollisionFidelity**
   in Properties. Hull is what we expect; if it shows Default, tell FORGE-02 (nothing breaks: the meshes do not collide and raycasts still hit the default shape).
If the Output has `not used` lines or Explorer shows stand-ins for ids you imported, stop and send both to FORGE-02: those ids are still the part-built stand-ins.

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
