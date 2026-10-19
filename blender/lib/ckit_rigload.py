"""Blender-side assembler that builds ANY (job, look, kingdom) citizen from the SHIPPED files only: citizen_kit.fbx + rig.json
(FL-0135). It does not import the generator, so renders made with it show what the Kit will assemble from the same two files:
piece choice (assemblies + look rules), tints, rest placement, optional pose (Sim/Pose.luau port).

    kit = Kit(fbx_path, rig_json_path)
    objs = kit.spawn("farmer", look={"skin": 2, "hair": 3, "hairColor": 4, "outfit": 1}, kingdom="crimson", x=3, z=-5, yaw=30)

Positions are Roblox world coordinates (studs); objects land in the house preview convention (x, y, z) -> (-x, z, y), front -Y.
"""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

from . import ckit_pose, ckit_view

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # rig -> authoring (Blender) axes
CI = C.inverted()
RZ180 = Matrix.Rotation(math.pi, 4, "Z")  # authoring -> house preview convention


JOBS = ["farmer", "woodcutter", "miner", "builder", "hauler", "blacksmith", "merchant", "healer", "idle", "soldier", "governor"]
KINGDOMS = ["crimson", "azure", "emerald", "gold"]


def job_look(i):
    """The look of the i-th citizen of a lineup (skins, hair styles, hair colours and outfits all differ between neighbours)."""
    return {"skin": 1 + (i * 2) % 6, "hair": 1 + (i * 5) % 6, "hairColor": 1 + (i * 3) % 8, "outfit": 1 + (i * 7) % 6}


def c01(c):
    return tuple(v / 255.0 for v in c)


class Kit:
    def __init__(self, fbx_path, rig_path, collection=None):
        self.doc = json.loads(Path(rig_path).read_text())
        self.collection = collection or bpy.context.scene.collection
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(fbx_path), axis_forward="-Z", axis_up="Y", global_scale=1.0)
        self.src = {o.name: o for o in bpy.data.objects if o not in before and o.type == "MESH"}
        for o in self.src.values():
            o.hide_render = True
            o.hide_viewport = True
        self.rest = {n: o.matrix_world.copy() for n, o in self.src.items()}
        missing = sorted(set(self.doc["pieces"]) - set(self.src))
        if missing:
            raise ValueError(f"FBX lacks pieces named in rig.json: {missing}")

    # ---------------------------------------------------------------- rules (module functions below; the Kit ports these)
    def names_for(self, job, look=None, kingdom="crimson"):
        return names_from_doc(self.doc, job, look, kingdom)

    def tint_for(self, name, job, look, kingdom):
        return tint_from_doc(self.doc, name, job, look, kingdom)

    # ---------------------------------------------------------------- placement
    def spawn(self, job, look=None, kingdom="crimson", x=0.0, z=0.0, yaw=0.0, action=None, phase=0.0, speed=0.0, tag="", names=None):
        """Create the objects of one citizen; returns the list. `action` poses the rig with the Pose.luau port."""
        joints = self.doc["joints"]
        tf = ckit_pose.sample(action, job.split("_")[0], phase, speed) if action else {}
        jw = ckit_pose.joint_worlds(joints, tf) if action else None
        a = math.radians(yaw)
        place = Matrix(((math.cos(a), 0, math.sin(a), x), (0, 1, 0, 0), (-math.sin(a), 0, math.cos(a), z), (0, 0, 0, 1)))
        objs = []
        for n in names or self.names_for(job, look, kingdom):
            p = self.doc["pieces"][n]
            src = self.src[n]
            me = src.data.copy()
            col = me.color_attributes[0]
            dst = me.color_attributes.new("Cview", "BYTE_COLOR", "CORNER")
            tint = self.tint_for(n, job, look, kingdom)
            for i in range(len(me.loops)):
                c = col.data[i].color_srgb
                dst.data[i].color_srgb = (c[0] * tint[0], c[1] * tint[1], c[2] * tint[2], 1.0)
            me.color_attributes.active_color = dst
            o = bpy.data.objects.new(f"{tag}{n}", me)
            self.collection.objects.link(o)
            me.materials.clear()
            me.materials.append(ckit_view.view_material())
            jm = jw[_carrier(p["joint"])] if jw else Matrix.Identity(4)
            o.matrix_world = RZ180 @ (C @ place @ jm @ CI) @ self.rest[n]
            objs.append(o)
        return objs

    def pieces_tris(self, names):
        return sum(self.doc["pieces"][n]["tris"] for n in names)


def _carrier(joint):
    return joint if joint in ckit_pose.PARENT else "Torso"


def names_from_doc(d, job, look=None, kingdom="crimson"):
    """Piece names of one citizen from rig.json alone (assemblies + look rules)."""
    lk = look or {"skin": 1, "hair": 1, "hairColor": 1, "outfit": 1}
    L = d["looks"]
    face = L["faces"][(lk["hair"] + 2 * lk["outfit"] + lk["skin"]) % len(L["faces"])]
    hs = L["hair_sets"][0 if lk["hairColor"] <= 4 else 1]
    hair = hs[(lk["hair"] - 1) % len(hs)]
    tv = L["torso_variants"].get(job)
    torso_id = tv[(lk["outfit"] - 1) % len(tv)] if tv else ""
    acc = L["accessories"][(lk["outfit"] + 2 * lk["hair"] + 3 * lk["skin"]) % len(L["accessories"])] or ""
    out = []
    for slot, val in d["assemblies"][job].items():
        if slot == "extras":
            for v in val:
                v = v.replace("%kingdom%", kingdom).replace("%accessory%", acc)
                if v:
                    out.append(v)
            continue
        if val is None:
            continue
        val = val.replace("%face%", face).replace("%kingdom%", kingdom).replace("%hair%", hair).replace("%torso%", torso_id)
        if slot == "boot" and job in L["boots"]:
            lst = L["boots"][job]
            val = lst[(lk["outfit"] + lk["skin"]) % len(lst)]
        if slot in d["sided_slots"]:
            out += [val + "_l", val + "_r"]
        else:
            out.append(val)
    return out


def tint_from_doc(d, name, job, look, kingdom):
    """MeshPart.Color the Kit sets for piece `name` (sRGB 0..1), from rig.json alone."""
    p = d["pieces"][name]
    t = p["tint"]
    T = d["tints"]
    lk = look or {"skin": 1, "hair": 1, "hairColor": 1, "outfit": 1}
    if t in (None, "fixed"):
        return (1.0, 1.0, 1.0)
    if t == "skin":
        return c01(T["skin"][(lk["skin"] - 1) % len(T["skin"])])
    if t == "hair":
        return c01(T["hair"][(lk["hairColor"] - 1) % len(T["hair"])])
    if t == "kingdom":
        base = name[:-2] if name.endswith(("_l", "_r")) else name
        f = T["kit_tint"].get(base, p.get("kit_tint", 0.85))
        if p["slot"] in ("torso", "sleeve"):
            f = min(1.0, max(0.5, f + T["tint_shift"][(lk["hairColor"] + lk["skin"] - 2) % len(T["tint_shift"])]))
        return tuple(min(1.0, v * f) for v in c01(T["kingdom"][kingdom]))
    if t == "cloth":
        variants = T["cloth_variants"].get(job) or T["cloth_variants"]["idle"]
        pal = variants[(lk["hairColor"] - 1) % len(variants)]
        c = pal.get(p["slot"]) or pal.get("default") or (200, 200, 200)
        dye = T["dye"][(lk["hairColor"] - 1) % len(T["dye"])]
        return tuple(min(1.0, v * dye) for v in c01(c))
    return (1.0, 1.0, 1.0)
