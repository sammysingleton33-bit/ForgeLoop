"""FL-0136 phase 3: the same prop from two versions of the env kit side by side (A = an older FBX + env.json, B = the committed kit), Cycles, Roblox cameras.

  ~/forge-bpy/bin/python -I blender/scripts/envkit_ab.py --id tree_oak_05 --a-fbx /tmp/old/env_kit.fbx --a-json /tmp/old/env.json --out /tmp/ab [--with tree_oak_01]
Writes OUT_<cam>.png for the 82-stud gameplay camera and the 45-stud close view; A on the left, B on the right, an untouched neighbour for scale. Blender renders are not Studio renders.
"""

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402,F401

from lib import ckit_scene, ckit_view, envkit_scene, rig  # noqa: E402


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--a-fbx", required=True)
    ap.add_argument("--a-json", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--with", dest="neighbour", default="")
    ap.add_argument("--only", default="", help="a or b: render one version alone at the origin (to compare the two images pixel by pixel)")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--samples", type=int, default=20)
    a = ap.parse_args(argv)
    w, h = (int(v) for v in a.size.split("x"))
    kit_dir = REPO / "games/game-001/art/env_kit"
    for cam, dist, pitch in (("gameplay82", 82.0, 44.3), ("close45", 45.0, 30.0)):
        sc = ckit_view.stage(w, h, a.samples)
        ka = envkit_scene.EnvKit(a.a_fbx, a.a_json)
        for o in ka.src.values():  # the second import would otherwise get ".001" names
            o.name = "A__" + o.name
        kb = envkit_scene.EnvKit(kit_dir / "env_kit.fbx", kit_dir / "env.json")
        if a.only == "a":
            ka.spawn(a.id, 0.0, 0.0, 0.0)
        elif a.only == "b":
            kb.spawn(a.id, 0.0, 0.0, 0.0)
        else:
            ka.spawn(a.id, -16.0, 0.0, 0.0)
            kb.spawn(a.id, 16.0, 0.0, 0.0)
        if a.neighbour and not a.only:
            kb.spawn(a.neighbour, 0.0, 22.0, 0.0)
        c = rig.add_camera(sc, 70)
        ckit_scene.gameplay(c, (0.0, 10.0, 8.0), dist, pitch, az_deg=0.0, fov=70.0)
        out = Path(f"{a.out}_{cam}.png")
        rig.render(sc, out)
        print(f"[ab] {out}", flush=True)


if __name__ == "__main__":
    main(sys.argv)
