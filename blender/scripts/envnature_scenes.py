"""FL-0136 phase 2 renders: the part-built stand-ins ("before") against the shipped style-B meshes ("after"), same scene, same cameras.

  ~/forge-bpy/bin/python -I blender/scripts/envnature_scenes.py --inv /tmp/env_inventory.json --out /tmp/env/n1 [--scenes settlement_crimson,forest_broadleaf] [--cams gameplay82,aerial170]
                                                                [--modes before,after] [--size 1280x720] [--samples 20] [--quick]

`--inv` is the dump of blender/scripts/lune/EnvInventory.spec.luau (stand-in parts per id, the shipped world's placements, the resource nodes and two plots' part-built
starting buildings). "After" meshes come from the SHIPPED games/game-001/art/env_kit/env_kit.fbx through lib/envkit_scene.EnvKit (what Studio will import), the citizens from
the shipped char_kit FBX (farmer, soldier, hauler, governor); buildings stay part-built in both. Cameras: RulerCameraController overview, 70 degrees vertical FOV,
gameplay = 82 studs at 44.3 degrees, aerial = 170 studs at 50 degrees. Blender renders are not Studio renders.
Writes OUT/<scene>__<mode>__<cam>.png and OUT/<scene>.json (counts, triangles, parts).
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402

from lib import ckit_rigload, ckit_scene, ckit_view, envkit_scene, kitparts, rig  # noqa: E402

FBX_CHAR = REPO / "games/game-001/art/char_kit/citizen_kit.fbx"
RIG_CHAR = REPO / "games/game-001/art/char_kit/rig.json"
KITS_ENV = [(REPO / "games/game-001/art/env_kit/env_kit.fbx", REPO / "games/game-001/art/env_kit/env.json"),
            (REPO / "games/game-001/art/env_kit/env_kit_spares.fbx", REPO / "games/game-001/art/env_kit/env_spares.json")]  # the ids the world places, then the spares

CAMS = {"gameplay82": dict(dist=82.0, pitch=44.3), "aerial170": dict(dist=170.0, pitch=50.0), "close45": dict(dist=45.0, pitch=30.0)}
CITIZENS = [("farmer", dict(skin=2, hair=3, hairColor=4, outfit=1)), ("soldier", dict(skin=1, hair=1, hairColor=2, outfit=1)),
            ("hauler", dict(skin=4, hair=5, hairColor=3, outfit=2)), ("governor", dict(skin=3, hair=2, hairColor=1, outfit=1))]

# subjects whose "before" is another id's stand-in (the growth stages replace the wheat field's look)
BEFORE_AS = {"farm_field_wheat_04": "farm_field_wheat_01", "farm_field_wheat_05": "farm_field_wheat_01"}

SCENES = {
    "settlement_crimson": dict(kind="plot", plot="crimson", kingdom="crimson", radius=215, cams=("gameplay82", "aerial170")),
    "settlement_emerald": dict(kind="plot", plot="emerald", kingdom="emerald", radius=215, cams=("gameplay82", "aerial170")),
    "forest_broadleaf": dict(kind="forest", center=(250.0, 60.0), radius=100, tgt=(250.0, 60.0), kingdom="crimson", cams=("gameplay82", "aerial170")),
    "forest_pine": dict(kind="forest", center=(-480.0, -170.0), radius=100, tgt=(-480.0, -170.0), kingdom="crimson", cams=("gameplay82", "aerial170")),
    "trees_lineup": dict(kind="lineup", ids=["tree_oak_01", "tree_oak_02", "tree_oak_03", "tree_oak_04", "tree_oak_05", "tree_oak_06", "tree_oak_07", "tree_oak_08",
                                             "tree_pine_01", "tree_pine_02", "tree_pine_03", "tree_pine_04", "tree_pine_05", "tree_pine_06",
                                             "tree_birch_01", "tree_birch_02", "tree_birch_03", "tree_birch_04", "tree_birch_05", "tree_birch_06"], gap=2.5, cols=7, tgt_h=9.0,
                         cams=("gameplay82",)),
    "trees_close": dict(kind="lineup", ids=["tree_oak_01", "tree_oak_05", "tree_pine_02", "tree_birch_03"], gap=3.0, cols=4, tgt_h=10.0, cams=("close45",)),
    "bushes_lineup": dict(kind="lineup", ids=[f"bush_0{i}" for i in range(1, 9)] + [f"plant_flowers_0{i}" for i in range(1, 7)], gap=2.5, cols=7, tgt_h=1.5, cams=("gameplay82", "close45")),
    "rocks_lineup": dict(kind="lineup", ids=[f"rock_boulder_{s}_0{i}" for s in "sml" for i in (1, 2, 3)], gap=3.0, cols=5, tgt_h=3.0, cams=("gameplay82", "close45")),
    "nodes_lineup": dict(kind="lineup", ids=["resource_stone_01", "resource_stone_02", "resource_stone_03", "resource_ore_03", "resource_ore_04", "tree_oak_01", "tree_pine_02", "bush_03"],
                         gap=3.5, cols=4, tgt_h=3.0, cams=("gameplay82", "close45")),
    "nodes_spares": dict(kind="lineup", ids=["resource_ore_01", "resource_ore_05", "resource_wood_01", "rock_cliff_01"], gap=3.5, cols=4, tgt_h=3.0, cams=("close45",)),
    "crops": dict(kind="lineup", ids=["farm_field_wheat_01", "farm_field_wheat_02", "farm_field_cabbage_03", "farm_haystack_01"], gap=4.0, cols=2, tgt_h=1.0, cams=("gameplay82", "aerial170")),
    "wheat_stages": dict(kind="lineup", ids=["farm_field_wheat_04", "farm_field_wheat_05", "farm_field_wheat_01"], gap=4.0, cols=3, tgt_h=1.0, cams=("gameplay82",)),
}


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--inv", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--scenes", default="")
    ap.add_argument("--cams", default="", help="override the scene's own camera list")
    ap.add_argument("--modes", default="before,after")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--samples", type=int, default=20)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--no-citizens", action="store_true")
    return ap.parse_args(argv)


# ------------------------------------------------------------------------------------------------ scene items

def plot_items(inv, spec):
    sc = inv["scene"]
    plot = sc["plots"][spec["plot"]]
    kx, kz, kyaw = plot["keep"]["x"], plot["keep"]["z"], plot["keep"]["yaw"]
    front = (-math.sin(kyaw), -math.cos(kyaw))  # the keep's front (-Z of its CFrame) in the world
    tx, tz = kx + front[0] * 38.0, kz + front[1] * 38.0  # the yard in front of the keep: where the camera looks
    r = spec["radius"]
    items = []
    for p in sc["placements"]:
        if math.hypot(p["x"] - tx, p["z"] - tz) <= r:
            items.append(dict(kind="prop", id=p["id"], x=p["x"], z=p["z"], yaw=p["yaw"], feature=p["feature"]))
    for n in sc["nodeList"]:
        if math.hypot(n["x"] - tx, n["z"] - tz) <= r:
            items.append(dict(kind="prop", id=n["assetId"], x=n["x"], z=n["z"], yaw=n["yaw"], feature="node:" + n["resource"]))
    houses = [b for b in plot["buildings"] if b["name"] == "house"]
    for b in plot["buildings"]:
        if b["name"] != "house":
            items.append(dict(kind="bld", model=b["model"], x=b["x"], z=b["z"], yaw=b["yaw"], name=b["name"]))
    # two houses beside the yard (the slots' own houses stand 80 studs in front of the keep, under the camera): keep frame (x right, z back), facing the front
    c, s_ = math.cos(kyaw), math.sin(kyaw)
    for lx, lz in ((64.0, -60.0), (-62.0, -64.0)):
        items.append(dict(kind="bld", model=houses[0]["model"], x=kx + c * lx + s_ * lz, z=kz - s_ * lx + c * lz, yaw=kyaw, name="house"))
    # the camera looks from the yard back at the keep: az so that its forward vector points along -front (towards the keep)
    az = math.degrees(kyaw)
    cits = []
    for i, (job, look) in enumerate(CITIZENS):
        off = (i - 1.5) * 6.0
        cits.append((job, look, tx + front[1] * off * -1.0 + front[0] * 4.0, tz + front[0] * off + front[1] * 4.0, math.degrees(kyaw) + (i - 2) * 25))
    return items, dict(target=(tx, 9.0, tz), az=az, cits=cits, kingdom=spec["kingdom"])


def forest_items(inv, spec):
    sc = inv["scene"]
    cx, cz = spec["center"]
    items = [dict(kind="prop", id=p["id"], x=p["x"], z=p["z"], yaw=p["yaw"], feature=p["feature"]) for p in sc["placementsFull"]  # density 1.0: the untrimmed stands
             if math.hypot(p["x"] - cx, p["z"] - cz) <= spec["radius"]]
    # the forest's near edge faces the camera at -z: citizens stand in front of it
    cits = [(job, look, cx - 14.0 + i * 8.0, cz - spec["radius"] * 0.55 - (i % 2) * 3.0, 15.0 * (i - 1.5)) for i, (job, look) in enumerate(CITIZENS)]
    return items, dict(target=(cx, 10.0, cz - 6.0), az=0.0, cits=cits, kingdom=spec["kingdom"])


def lineup_items(inv, spec):
    ids = spec["ids"]
    st = {k: v for k, v in json.load(open(HERE / "lib/envkit_standins.json"))["standins"].items()}
    items, x, z, rowmax = [], 0.0, 0.0, 0.0
    cols = spec.get("cols", len(ids))
    widths = []
    for pid in ids:
        sz = st.get(BEFORE_AS.get(pid, pid), {"size": [8, 8, 8]})["size"]
        widths.append(max(sz[0], sz[2]))
    colw = [max(widths[c::cols]) for c in range(cols)]
    tot = sum(colw) + spec["gap"] * (cols - 1)
    xs = []
    acc = -tot / 2
    for c in range(cols):
        xs.append(acc + colw[c] / 2)
        acc += colw[c] + spec["gap"]
    rows = (len(ids) + cols - 1) // cols
    rowd = [max(widths[r * cols:(r + 1) * cols]) for r in range(rows)]
    zacc = 0.0
    for i, pid in enumerate(ids):
        r, c = divmod(i, cols)
        if c == 0 and r:
            zacc += rowd[r - 1] / 2 + spec["gap"] + rowd[r] / 2
        items.append(dict(kind="prop", id=pid, x=xs[c], z=zacc, yaw=0.0, feature="lineup"))
    cits = [(job, look, -6.0 + i * 4.5, -max(rowd[0] / 2 + 5.0, 9.0), 10.0 * (i - 1)) for i, (job, look) in enumerate(CITIZENS[:3])]
    return items, dict(target=(0.0, spec["tgt_h"], zacc / 2), az=0.0, cits=cits, kingdom="crimson", width=tot, depth=zacc)


# ------------------------------------------------------------------------------------------------ building the Blender scene

def build(inv, spec, items, mode, size, samples, quick, citizens=True, extra=None):
    w, h = size
    sc = ckit_view.stage(w, h, samples, quick=quick)
    col = sc.collection
    subjects = inv["subjects"]
    kits = [envkit_scene.EnvKit(f, j) for f, j in KITS_ENV if f.exists()] if mode == "after" else []
    n_mesh = n_parts = tris = 0
    ids = {}
    for it in items:
        if it["kind"] == "bld":
            kitparts.build_model(it["model"], col, transform=ckit_scene.roblox_matrix(it["x"], 0, it["z"], math.degrees(it["yaw"])))
            continue
        pid = it["id"]
        yaw = math.degrees(it["yaw"]) if abs(it["yaw"]) < 10 else it["yaw"]
        ids[pid] = ids.get(pid, 0) + 1
        owner = next((k for k in kits if pid in k.doc["props"]), None)
        if owner is not None:
            owner.spawn(pid, it["x"], it["z"], yaw)
            n_mesh += 1
            tris += owner.doc["props"][pid]["tris"]
        else:
            ent = subjects.get(BEFORE_AS.get(pid, pid))
            if ent is None:
                continue
            kitparts.build_model(ent, col, transform=ckit_scene.roblox_matrix(it["x"], 0, it["z"], yaw))
            n_parts += ent["partCount"]
    ck = []
    if citizens and extra:
        ckit = ckit_rigload.Kit(FBX_CHAR, RIG_CHAR)
        for job, look, x, z, yaw in extra["cits"]:
            ckit.spawn(job, look, extra["kingdom"], x, z, yaw, tag=f"{job}_")
    return sc, dict(props=sum(ids.values()), mesh_props=n_mesh, standin_parts=n_parts, mesh_tris=tris, ids=ids)


def main(argv):
    a = parse(argv)
    inv = json.loads(Path(a.inv).read_text())
    w, h = (int(v) for v in a.size.split("x"))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    names = [s for s in a.scenes.split(",") if s] or list(SCENES)
    for name in names:
        spec = SCENES[name]
        if spec["kind"] == "plot":
            items, extra = plot_items(inv, spec)
        elif spec["kind"] == "forest":
            items, extra = forest_items(inv, spec)
        else:
            items, extra = lineup_items(inv, spec)
        report = {"cams": {}}
        for mode in a.modes.split(","):
            sc, rep = build(inv, spec, items, mode, (w, h), a.samples, a.quick, not a.no_citizens, extra)
            report[mode] = rep
            cam = rig.add_camera(sc, 70)
            for camname in (a.cams.split(",") if a.cams else spec["cams"]):
                cfg = dict(CAMS[camname])
                if spec["kind"] == "lineup":
                    # the camera's own distance, widened only when the row would not fit the frame (reported in the json: the sheet caption says so)
                    half_h = math.tan(math.radians(35.0)) * w / h
                    need = (extra["width"] / 2 + 6.0) / half_h * 1.05 + extra["depth"] / 2 + 4.0
                    if need > cfg["dist"]:
                        cfg["dist"] = need
                    report.setdefault("cams", {})[camname] = dict(dist=round(cfg["dist"], 1), pitch=cfg["pitch"], widened=bool(need > CAMS[camname]["dist"]))
                ckit_scene.gameplay(cam, extra["target"], cfg["dist"], cfg["pitch"], az_deg=extra["az"], fov=70.0)
                path = out / f"{name}__{mode}__{camname}.png"
                rig.render(sc, path)
                print(f"[scenes] {name} {mode} {camname}: {rep['props']} props ({rep['mesh_props']} mesh, {rep['mesh_tris']} tris; {rep['standin_parts']} stand-in parts) -> {path.name}", flush=True)
        (out / f"{name}.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main(sys.argv)
