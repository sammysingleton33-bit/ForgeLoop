"""Blender-side loader for the SHIPPED env kit (FL-0136 phase 2): imports games/game-001/art/env_kit/env_kit.fbx and places any prop by asset id,
the way the Kit places a model (pivot = the base centre on the ground, yaw about +y). Renders made with it show what Studio will import,
not what the generator happened to build. Blender renders are not Studio renders.

    kit = EnvKit(fbx_path, env_json_path)
    obj = kit.spawn("tree_oak_01", x=12, z=-4, yaw=30)          # Roblox world coordinates (studs)
"""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix

from . import ckit_view
from .ckit_rigload import C, CI, RZ180


class EnvKit:
    def __init__(self, fbx_path, env_path, collection=None):
        self.doc = json.loads(Path(env_path).read_text())
        self.collection = collection or bpy.context.scene.collection
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(fbx_path), axis_forward="-Z", axis_up="Y", global_scale=1.0)
        self.src = {o.name: o for o in bpy.data.objects if o not in before and o.type == "MESH"}
        for o in self.src.values():
            o.hide_render = True
            o.hide_viewport = True
        self.rest = {n: o.matrix_world.copy() for n, o in self.src.items()}
        missing = sorted(set(self.doc["props"]) - set(self.src))
        if missing:
            raise ValueError(f"FBX lacks props named in env.json: {missing}")

    def spawn(self, pid, x=0.0, z=0.0, yaw=0.0, tint=(1.0, 1.0, 1.0), tag="", collection=None, scale=1.0):
        src = self.src[pid]
        me = src.data.copy()
        col = me.color_attributes[0]
        dst = me.color_attributes.new("Cview", "BYTE_COLOR", "CORNER")
        for i in range(len(me.loops)):
            c = col.data[i].color_srgb
            dst.data[i].color_srgb = (min(1.0, c[0] * tint[0]), min(1.0, c[1] * tint[1]), min(1.0, c[2] * tint[2]), 1.0)
        me.color_attributes.active_color = dst
        o = bpy.data.objects.new(f"{tag}{pid}", me)
        (collection or self.collection).objects.link(o)
        me.materials.clear()
        me.materials.append(ckit_view.view_material())
        a = math.radians(yaw)
        place = Matrix(((math.cos(a), 0, math.sin(a), x), (0, 1, 0, 0), (-math.sin(a), 0, math.cos(a), z), (0, 0, 0, 1)))
        if scale != 1.0:
            place = place @ Matrix.Diagonal((scale, scale, scale, 1))
        o.matrix_world = RZ180 @ (C @ place @ CI) @ self.rest[pid]
        return o

    def size(self, pid):
        return self.doc["props"][pid]["size"]


PREVIEW = ["tree_oak_01", "tree_oak_05", "tree_pine_01", "tree_pine_04", "tree_birch_01", "tree_oak_07", "bush_03", "bush_02", "plant_flowers_01",
           "plant_flowers_05", "rock_boulder_s_01", "rock_boulder_m_02", "rock_boulder_l_03", "resource_stone_01", "resource_ore_03", "resource_ore_04"]


def render_preview(fbx, env_json, out_jpg, samples=14, size=(1600, 560)):
    """Manifest preview: a lineup of representative props from the SHIPPED fbx (Cycles, <= 250 KB JPEG)."""
    from PIL import Image

    from . import ckit_scene
    from . import rig as scene_rig

    sc = ckit_view.stage(size[0], size[1], samples)
    kit = EnvKit(fbx, env_json)
    xs, x = [], 0.0
    for pid in PREVIEW:
        w = max(kit.size(pid)[0], kit.size(pid)[2])
        xs.append((pid, x + w / 2))
        x += w + 3.0
    for pid, cx in xs:
        kit.spawn(pid, cx - x / 2, 0.0, 0.0)
    cam = scene_rig.add_camera(sc, 70)
    ckit_scene.gameplay(cam, (0.0, 8.0, 0.0), x * 0.62, 24.0, fov=70)
    tmp = Path(out_jpg).with_suffix(".png")
    scene_rig.render(sc, tmp)
    im = Image.open(tmp).convert("RGB")
    for q in (88, 80, 72, 64, 56, 48):
        im.save(out_jpg, quality=q, optimize=True)
        if Path(out_jpg).stat().st_size <= 250 * 1024:
            break
    tmp.unlink()
    return Path(out_jpg).stat().st_size
