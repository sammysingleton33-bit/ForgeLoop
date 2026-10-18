"""Crowd, lineup and before/after scenes built from the SHIPPED kit files (citizen_kit.fbx + rig.json) (FL-0135).

  ~/forge-bpy/bin/python blender/scripts/charkit_scenes.py --scene crowd170 --fbx F --rig R --out OUT.png [--old] [--quick]
scenes: crowd170 / crowd40 (the 30-citizen roster of the earlier citizen-polish renders around the old farm; --old renders the
part-built rigs for the same roster), jobs (every identity side by side), looks (24 looks of one job), kingdoms (soldiers and
rulers in the four kingdom colours), poses (one job in every Pose action), portraits (head and shoulders of every job).
Blender renders are not Studio renders.
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

from lib import ckit_rigload, ckit_scene, ckit_view, kitparts, rig  # noqa: E402

OLD = REPO / "games/game-001/art/char_kit/old_rigs.json"
JOBS = ["farmer", "woodcutter", "miner", "builder", "hauler", "blacksmith", "merchant", "healer", "idle", "soldier", "governor"]
KINGDOMS = ["crimson", "azure", "emerald", "gold"]


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene", required=True)
    ap.add_argument("--fbx", default="")
    ap.add_argument("--rig", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--old", action="store_true", help="render the part-built rigs instead of the kit")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--size", default="")
    ap.add_argument("--target", default="")
    ap.add_argument("--dist", type=float, default=0.0)
    ap.add_argument("--pitch", type=float, default=0.0)
    ap.add_argument("--building", default="")
    ap.add_argument("--building-scale", type=float, default=25.0)
    return ap.parse_args(argv)


def look_grid(n_skin=6):
    """24 looks: columns vary skin; rows vary hair style / hair colour / outfit together."""
    rows = [(1, 1, 1), (2, 5, 2), (3, 2, 3), (4, 7, 4), (5, 3, 5), (6, 8, 6), (2, 4, 1), (4, 6, 3)]
    return [[{"skin": s + 1, "hair": h, "hairColor": hc, "outfit": o} for s in range(n_skin)] for (h, hc, o) in rows]


def main(argv):
    a = parse(argv)
    quick = a.quick
    ckit_view.QUICK = quick
    w, h = (int(v) for v in a.size.split("x")) if a.size else (1280, 720)
    old = json.loads(OLD.read_text())
    kit = None
    if not a.old:
        sc = ckit_view.stage(w, h, a.samples or (24 if not quick else 6), quick=quick)
        kit = ckit_rigload.Kit(a.fbx, a.rig)
    else:
        sc = ckit_view.stage(w, h, a.samples or (24 if not quick else 6), quick=quick)
    cam = rig.add_camera(sc, 70)
    scene = a.scene
    if scene in ("crowd170", "crowd40"):
        kitparts.build_model(old["farm"], sc.collection)
        if a.old:
            for m in old["crowd_old_models"]:
                kitparts.build_model(m, sc.collection)
        else:
            for c in old["crowd"]:
                kit.spawn(c["job"] if c["job"] != "soldier" else "soldier", c["look"], "crimson", c["x"], c["z"], c["yaw"], tag=f"{c['job']}_")
        if a.building:
            pass
        if scene == "crowd170":
            tgt = tuple(float(v) for v in (a.target or "0,3,0").split(","))
            ckit_scene.aerial(cam, tgt, a.dist or 170.0, a.pitch or 50.0)
        else:
            tgt = tuple(float(v) for v in (a.target or "-30,3,-6").split(","))
            ckit_scene.gameplay(cam, tgt, a.dist or 40.0, a.pitch or 18.0, az_deg=0.0)
    elif scene == "jobs":
        n = len(JOBS)
        for i, job in enumerate(JOBS):
            x = ((n - 1) / 2 - i) * 6.2
            if a.old:
                m = _old_job(old, job)
                kitparts.build_model(m, sc.collection, transform=ckit_scene.roblox_matrix(x, 0, 0, 0))
            else:
                look = {"skin": 1 + (i * 2) % 6, "hair": 1 + (i * 5) % 6, "hairColor": 1 + (i * 3) % 8, "outfit": 1 + (i * 7) % 6}
                kit.spawn(job, look, "crimson", x, 0, 0, tag=f"{job}_")
        ckit_scene.gameplay(cam, (0, 2.8, 0), a.dist or 46.0, a.pitch or 12.0, fov=70)
    elif scene == "looks":
        grid = look_grid()
        job = "idle"
        for r, row in enumerate(grid):
            for c, lk in enumerate(row):
                x, z = (2.5 - c) * 5.2, r * 5.2
                kit.spawn(job if r < 4 else "farmer", lk, "crimson", x, z, 0, tag=f"l{r}{c}_")
        ckit_scene.gameplay(cam, (0, 2.0, 18.0), a.dist or 58.0, a.pitch or 38.0, fov=60)
    elif scene == "kingdoms":
        for i, kd in enumerate(KINGDOMS):
            for r, job in enumerate(("soldier", "soldier_sword", "soldier_bow", "governor")):
                kit.spawn(job, {"skin": 1 + (i + r) % 6, "hair": 1, "hairColor": 1, "outfit": 1}, kd, (1.5 - i) * 8.0, r * 7.0, 0, tag=f"{kd}{job}_")
        ckit_scene.gameplay(cam, (0, 2.8, 10.0), a.dist or 56.0, a.pitch or 30.0, fov=60)
    elif scene == "poses":
        acts = [("idle", 0.0), ("walk", 12.0), ("carry", 8.0), ("work", 0.0), ("fight", 0.0), ("celebrate", 0.0), ("dead", 0.0)]
        job = a.target or "farmer"
        for i, (act, sp) in enumerate(acts):
            kit.spawn(job, None, "crimson", (3 - i) * 7.5, 0, 0, action=act, phase=0.25, speed=sp, tag=f"{act}_")
        ckit_scene.gameplay(cam, (0, 2.8, 0), a.dist or 46.0, a.pitch or 12.0, fov=60)
    elif scene == "portraits":
        # head and shoulders of every job, a strip of square tiles
        raise SystemExit("use charkit_compare.py for portraits")
    else:
        raise SystemExit(f"unknown scene {scene}")
    rig.render(sc, a.out)
    print(f"[scenes] {scene} -> {a.out}", flush=True)


def _old_job(old, job):
    name = "idle" if job == "idle" else job
    for m in old["jobs"]:
        if m["label"] == name:
            return m
    for m in old["jobs"]:
        if m["label"] == "idle":
            return m


if __name__ == "__main__":
    main(sys.argv)
