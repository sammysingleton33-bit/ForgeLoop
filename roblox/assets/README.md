# roblox/assets — imported models (owner: FORGE-05)

Rojo maps this folder to `ReplicatedStorage.Forge.Assets` (`roblox/default.project.json`).
Each `<asset_id>.rbxm` becomes a child Model named by its asset id (interfaces §10), e.g.
`tree_broadleaf_01.rbxm` → `ReplicatedStorage.Forge.Assets.tree_broadleaf_01`. Code refers to assets
only by id.

- Asset ids match `^[a-z]+(_[a-z0-9]+)+_\d{2}$` (category first); the hand-over is `blender/manifest.json`.
- Until an Open Cloud key exists, import is manual: Studio 3D Importer → save as `.rbxm` here
  (FORGE-05 with the user). Commit only small `.rbxm` files (D-007); exported meshes are CI artifacts.
- This README produces no instance (Rojo ignores `.md`), so the folder builds empty until the first
  asset lands. The place check asserts the `Assets` folder exists.
