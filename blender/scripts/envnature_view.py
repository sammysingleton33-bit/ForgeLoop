"""FL-0136 phase 2 dev view: build env-kit props in-process and render them in a row at a Roblox camera (Cycles, or --quick Workbench).

  ~/forge-bpy/bin/python -I blender/scripts/envnature_view.py --ids tree_oak_01,tree_pine_01 --out /tmp/v.png [--dist 82 --pitch 44.3] [--citizens]
  ids may be a prefix ending in * (tree_oak_*). --closeup renders each prop's own bounds at a low camera instead of the gameplay camera.
Blender renders are not Studio renders.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402

from generators import _envkit_style as S  # noqa: E402
from generators import env_kit  # noqa: E402
from lib import envkit_standin, ckit_rigload, ckit_scene, ckit_view, kitparts, rig  # noqa: E402

STAND = envkit_standin.load()["standins"]
FBX = REPO / "games/game-001/art/char_kit/citizen_kit.fbx"
RIGJ = REPO / "games/game-001/art/char_kit/rig.json"


def piece_seed(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:6], 16)


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--dist", type=float, default=82.0)
    ap.add_argument("--pitch", type=float, default=44.3)
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--citizens", action="store_true")
    ap.add_argument("--gap", type=float, default=3.0)
    ap.add_argument("--target-h", type=float, default=0.0)
    ap.add_argument("--az", type=float, default=0.0)
    ap.add_argument("--cols", type=int, default=0, help="wrap the row after this many props")
    ap.add_argument("--before", default="", help="the inventory dump (EnvInventory.spec.luau): put each prop's part-built stand-in left of the mesh")
    return ap.parse_args(argv)


def resolve(spec, reg_all):
    ids = []
    for tok in spec.split(","):
        tok = tok.strip()
        if tok.endswith("*"):
            ids += [k for k in reg_all if k.startswith(tok[:-1])]
        elif tok:
            ids.append(tok)
    return ids


def main(argv):
    a = parse(argv)
    w, h = (int(v) for v in a.size.split("x"))
    ids = resolve(a.ids, env_kit.all_ids())
    reg = env_kit.registry(only=set(ids))
    dump = json.loads(Path(a.before).read_text())["subjects"] if a.before else None
    sc = ckit_view.stage(w, h, a.samples, quick=a.quick)
    objs, x = [], 0.0
    placed = []
    cols = a.cols or len(ids)
    rowx, rowz, rowmax = 0.0, 0.0, 0.0
    layout = []
    for n, pid in enumerate(ids):
        p = reg[pid]
        (x0, y0, z0), (x1, y1, z1) = p.m.bounds()
        wid = max(x1 - x0, z1 - z0)
        if dump:
            wid = wid * 2 + a.gap
        if n and n % cols == 0:
            rowx, rowz = 0.0, rowz + rowmax + a.gap
            rowmax = 0.0
        cx = rowx + wid / 2
        layout.append((pid, cx, rowz))
        rowx += wid + a.gap
        rowmax = max(rowmax, wid)
    rows = {}
    for pid, cx, cz in layout:
        rows.setdefault(cz, []).append(cx)
    widest = max(max(v) for v in rows.values())
    for pid, cx, cz in layout:
        p = reg[pid]
        (x0, y0, z0), (x1, y1, z1) = p.m.bounds()
        half = max(x1 - x0, z1 - z0) / 2 + a.gap / 2
        dx = -half if dump else 0.0
        o = ckit_view.make(pid, p.m, ao=S.AO, facet=S.FACET, seed=piece_seed(pid), location=(cx - widest / 2 + dx, 0.0, cz))
        objs.append(o)
        if dump:
            objs += kitparts.build_model(dump[pid], sc.collection, transform=ckit_scene.roblox_matrix(cx - widest / 2 + half, 0, cz, 0))
        si = STAND.get(pid)
        fit = ""
        if si:
            sz = [x1 - x0, y1 - y0, z1 - z0]
            r_m, r_s = (sz[0] + sz[2]) / 4, (si["size"][0] + si["size"][2]) / 4
            fit = f"  r_fp {r_m:.1f} vs {r_s:.1f} ({r_m / r_s - 1:+.0%})  h {sz[1]:.1f} vs {si['size'][1]:.1f} ({sz[1] / si['size'][1] - 1:+.0%})  base {y0:.2f}"
        print(f"{pid}: {p.m.copy().triangulate().tris} tris{fit} {p.info}", flush=True)
    cit = []
    if a.citizens:
        kit = ckit_rigload.Kit(FBX, RIGJ)
        for i, (job, look) in enumerate([("farmer", dict(skin=2, hair=3, hairColor=4, outfit=1)), ("soldier", dict(skin=1, hair=1, hairColor=2, outfit=1)),
                                          ("hauler", dict(skin=4, hair=5, hairColor=3, outfit=2))]):
            cit += kit.spawn(job, look, "crimson", -6.0 + i * 5.0, -8.0, 10 * i - 10, tag=f"{job}_")
    cam = rig.add_camera(sc, 70)
    zmax = max(cz for _, _, cz in layout)
    th = a.target_h or 8.0
    ckit_scene.gameplay(cam, (0.0, th, zmax / 2 - 2.0), a.dist, a.pitch, az_deg=a.az, fov=70.0)
    rig.render(sc, a.out)
    print("rendered", a.out, flush=True)


if __name__ == "__main__":
    main(sys.argv)
