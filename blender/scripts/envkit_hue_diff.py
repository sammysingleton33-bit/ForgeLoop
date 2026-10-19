"""FL-0136 phase 1: how much of a KayKit building changes between its four hue variants? (the team-colour region a runtime could tint)

  ~/forge-bpy/bin/python -I blender/scripts/envkit_hue_diff.py [--out report.json]

Compares the red / blue / green / yellow glTF of each model face by face (the geometry is identical across hues when the vertex lists
match); a face whose baked colour differs between hues belongs to the team-colour region. Reports triangles and the share of the surface.
"""

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402

from lib import envkit as E  # noqa: E402

MODELS = ["castle", "barracks", "home_A", "tower_A", "market", "blacksmith"]


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    a = ap.parse_args(argv)
    res = {}
    for name in MODELS:
        ms = {}
        for hue in ("red", "blue", "green", "yellow"):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            ms[hue] = E.kk_load(f"buildings/{hue}/building_{name}_{hue}")
        base = ms["red"]
        same_geo = all(len(m.v) == len(base.v) and len(m.f) == len(base.f) and all(abs(p[k] - q[k]) < 1e-6 for p, q in zip(m.v, base.v) for k in range(3))
                       for m in ms.values())
        diff = set()
        for hue in ("blue", "green", "yellow"):
            for i, (c0, c1) in enumerate(zip(base.cc, ms[hue].cc)):
                if any(abs(x - y) > 0.04 for ca, cb in zip(c0, c1) for x, y in zip(ca, cb)):
                    diff.add(i)
        area = lambda m, ids: sum(_tri_area(m, i) for i in ids)  # noqa: E731
        tot = area(base, range(len(base.f)))
        res[name] = {"tris": base.tris, "same_geometry_in_all_hues": same_geo, "team_colour_tris": len(diff),
                     "team_colour_tri_share": round(len(diff) / len(base.f), 3), "team_colour_area_share": round(area(base, diff) / tot, 3)}
        print(f"{name:10s} tris {base.tris:5d} same geometry {same_geo} team-colour tris {len(diff):5d} ({100 * len(diff) / len(base.f):.0f}% of tris, "
              f"{100 * res[name]['team_colour_area_share']:.0f}% of the area)", flush=True)
    if a.out:
        Path(a.out).write_text(json.dumps(res, indent=1))


def _tri_area(m, i):
    a, b, c = (m.v[j] for j in m.f[i])
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    return 0.5 * (nx * nx + ny * ny + nz * nz) ** 0.5


if __name__ == "__main__":
    main(sys.argv)
