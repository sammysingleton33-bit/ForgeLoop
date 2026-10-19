"""Roblox export: one FBX per asset with only the visual mesh.

Settings follow Roblox's Blender guidance (creator-docs `art/blender.md`,
`art/modeling/export-requirements.md`, fetched 2026-10-12):
  Unit System None (1 Blender unit = 1 stud), Apply Scalings = FBX Unit Scale,
  Forward = Z, Up = Y, Path Mode = Copy + Embed Textures, no leaf bones, no animation.
Studio importer: Scale Unit = Stud, World Forward = Front, World Up = Top.
"""

from pathlib import Path

import bpy

from .coords import blender_to_roblox, size_to_roblox  # noqa: F401  (re-exported for callers)


def _select_only(objs):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def export_fbx(obj, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    _select_only([obj])
    bpy.ops.export_scene.fbx(
        filepath=str(path),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        global_scale=1.0,
        axis_forward="Z",
        axis_up="Y",
        bake_space_transform=False,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        use_tspace=False,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        use_custom_props=False,
    )
    return path


def export_gltf(obj, path):
    """Alternative (no scale settings needed per Roblox docs). Not the default."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    _select_only([obj])
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLTF_SEPARATE", use_selection=True,
                              export_yup=True, export_apply=True)
    return path

