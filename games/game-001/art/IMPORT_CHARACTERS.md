# Import the citizen kit into Studio (FL-0135, D-057) — one page, ~1 hour

**Every Studio step below is UNVERIFIED**: nobody has run this in Studio yet. The script and the Kit were tested
headless only (Lune, fake instances). Menu names are from the Roblox docs and may differ in your Studio; if a step does not
match, stop and report what you see. Nothing here costs money or needs an API key.

## 0. Before any upload (5 min) — Asset Privacy
1. **Who owns the experience: a user or a group?** (Creator Hub > Creations > the experience.) The imported meshes are
   uploaded to that owner.
2. **Turn on Asset Privacy BEFORE the upload.** It is not retroactive, and Open Use cannot be reversed. User: Creator
   Dashboard > Settings > Advanced; group: the group's profile settings (docs/research/2026-10-18-art-sourcing-brief.md,
   section C and E; confirm the names in your UI). Your own assets always load in your own published experiences. Leave
   "Allow Loading Third Party Assets" off.

## 1. Get the files (repo checkout, `forge/02-...` merged or checked out)
- `citizen_kit.fbx` from the Blender worker (expected at `games/game-001/art/char_kit/`, or the PR's CI artifact).
- A place built from the repo: `rojo build games/game-001/default.project.json -o crownfall.rbxl`. Open that file. It
  must contain `ReplicatedStorage.Game.Kit.CharacterMeshData` (the kit's data, made by
  `python3 games/game-001/art/char_kit/rig_to_luau.py`) and `ReplicatedStorage.Forge.Assets`.

## 2. Import (Studio)
1. **View > Asset Manager > Bulk Import**, pick `citizen_kit.fbx`. Importer settings: **Scale Unit: Studs** · **Ignore
   Vertex Colors: OFF** (unticked: the Kit tints the baked vertex colours) · **Merge Meshes: OFF** (one MeshPart per piece) ·
   Rig Type: **No Rig** · axes: leave the defaults (the FBX is Y-up, -Z-forward; the script reports any rotation) ·
   upload to the **owner from step 0**. Import. A model (`citizen_kit`) of MeshParts appears in Workspace.
2. **View > Command Bar**: paste the whole of `blender/studio/import_char_kit.luau`, press Enter. It copies each MeshPart
   into `ReplicatedStorage.Forge.Assets.CitizenKit` by piece name and prints a report. (Set `DRY_RUN = true` at the top to only
   look.) Run it again any time: it replaces, never duplicates; Ctrl+Z undoes a run.
3. Read the Output. **Good: `RESULT: OK`**, `N imported, 0 missing`. Not good: `MISSING`, `WRONG SIZE` (a scale/unit
   mistake), `NO MESH` (the upload failed), `ROTATED` (axes): do not continue, send the Output to FORGE-02. Triangle counts
   are not available in Studio: the figures are Blender's (`rig.json`, the manifest).
   The script also deletes from its copies everything inside a piece except a `SurfaceAppearance` (scripts, Sounds, Decals,
   ObjectValues, Attachments... anything that executes, fetches or carries an id) and lists each in the Output as
   `stripped:`. A clean import prints none: if you see any, paste them to FORGE-02 before saving the `.rbxm`.
4. The script selects `CitizenKit`. Right-click it > **Save to File...** > `roblox/assets/CitizenKit.rbxm` in the
   checkout (a few KB: it holds mesh ids, not meshes). Commit it in a PR (FORGE-05/02): that is what makes `rojo build`
   include the kit. Rojo cannot live-sync mesh ids: use `rojo build`, not `rojo serve`, to see the meshes.
5. Delete the leftover `citizen_kit` model from Workspace, **File > Save**, and Publish if you play from Roblox.

## 3. Look at it (Play, F5)
Citizens by job at the **aerial camera** (farmer hat, woodcutter, miner, builder, hauler sack read apart; the kingdom colour
shows on torsos from above), a **conversation portrait**, the **ruler** (crown, cape), each kingdom's **soldiers** (crest and
armour), the walk and work animations, kingdom recolouring. In Explorer, `Workspace.KingdomEntities.<citizen_...>` holding
**MeshParts** is the mesh rig; plain Parts mean the Kit fell back (it does that for any piece missing or off-size).
Then the **300-citizen stress test on a real phone**: reach the population caps (D-055: 60 citizens + 15 soldiers per
kingdom, STUDIO_PLAYTEST.md has the F8 presets), open **Render Stats** and note FPS, triangles and draw calls, and take
screenshots at the **aerial** and **portrait** views.

## 4. Revert
Delete the `CitizenKit` folder (and `roblox/assets/CitizenKit.rbxm` from the repo): the Kit builds today's part-built
citizens again at the next play or build. Nothing else was changed.

## 5. Report back
The script's Output (paste it) · the aerial and portrait screenshots · Render Stats and FPS from the phone · whether a user or
a group owns the experience and that Asset Privacy was on before the upload · anything that looked wrong (colours, hair,
tool in the hand, scale, an invisible citizen) with a screenshot.

*Unverified in Studio: the importer settings above; that vertex colours tint via MeshPart.Color; that a MeshPart's position
is its bounding-box centre after import; mesh ids surviving `.rbxm` round trips; the script's behaviour on the real
Workspace; the phone numbers. Headless evidence: `tests/world/KitCharacterMesh*.spec.luau`.*
