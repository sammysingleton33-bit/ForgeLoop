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
JOBS = ckit_rigload.JOBS
KINGDOMS = ckit_rigload.KINGDOMS


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
    ap.add_argument("--yaw", type=float, default=0.0, help="turn of every citizen of the jobs lineup (degrees about the vertical axis)")
    ap.add_argument("--az", type=float, default=0.0, help="camera azimuth about the target in degrees (180 = look at the backs)")
    ap.add_argument("--ground", default="", help="r,g,b 0-255 ground colour (default grass); a neutral grey stops the green bounce tinting skin in close-ups")
    ap.add_argument("--silhouette", action="store_true", help="flat black figures on white (Workbench): judge the identity from the outline alone")
    ap.add_argument("--building", default="")
    ap.add_argument("--building-scale", type=float, default=25.0)
    return ap.parse_args(argv)


def look_grid(rows=6, cols=6):
    """rows x cols distinct looks: skin, hair style, hair colour and outfit all move together so no two neighbours match."""
    return [[{"skin": 1 + (c + r) % 6, "hair": 1 + (c * 2 + r * 3) % 6, "hairColor": 1 + (c * 3 + r * 5) % 8, "outfit": 1 + (c + 2 * r) % 6}
             for c in range(cols)] for r in range(rows)]


def main(argv):
    a = parse(argv)
    quick = a.quick
    ckit_view.QUICK = quick
    w, h = (int(v) for v in a.size.split("x")) if a.size else (1280, 720)
    old = json.loads(OLD.read_text())
    kit = None
    ground = tuple(float(v) for v in a.ground.split(",")) if a.ground else ckit_view.GRASS
    sc = ckit_view.stage(w, h, a.samples or (24 if not quick else 6), ground=ground, quick=quick)
    kit = ckit_rigload.Kit(a.fbx, a.rig) if not a.old else None
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
                kitparts.build_model(m, sc.collection, transform=ckit_scene.roblox_matrix(x, 0, 0, a.yaw))
            else:
                kit.spawn(job, ckit_rigload.job_look(i), "crimson", x, 0, a.yaw, tag=f"{job}_")
        ckit_scene.gameplay(cam, (0, 2.8, 0), a.dist or 46.0, a.pitch or 12.0, fov=70)
        # pixel position of every identity's feet (preview axes: x mirrored), for labelled lineup sheets
        from bpy_extras.object_utils import world_to_camera_view
        from mathutils import Vector

        bpy.context.view_layer.update()
        pts = {}
        for i, job in enumerate(JOBS):
            x = ((n - 1) / 2 - i) * 6.2
            co = world_to_camera_view(sc, cam, Vector((-x, 0.0, 0.0)))
            pts[job] = [round(co.x * w, 1), round((1 - co.y) * h, 1)]
        Path(str(a.out) + ".labels.json").write_text(json.dumps(pts))
    elif scene == "looks":
        grid = look_grid()
        jobs = ["idle", "idle", "idle", "idle", "farmer", "builder"]
        for r, row in enumerate(grid):
            for c, lk in enumerate(row):
                kit.spawn(jobs[r], lk, "crimson", (2.5 - c) * 5.2, r * 5.6, 0, tag=f"l{r}{c}_")
        ckit_scene.gameplay(cam, (0, 2.6, 12.0), a.dist or 36.0, a.pitch or 30.0, fov=48)
    elif scene == "kingdoms":
        for i, kd in enumerate(KINGDOMS):
            for r, job in enumerate(("soldier", "soldier_swordsman", "soldier_archer", "governor")):
                kit.spawn(job, {"skin": 1 + (i + r) % 6, "hair": 1, "hairColor": 1, "outfit": 1}, kd, (1.5 - i) * 8.0, r * 7.0, 0, tag=f"{kd}{job}_")
        ckit_scene.gameplay(cam, (0, 2.8, 10.0), a.dist or 56.0, a.pitch or 30.0, az_deg=a.az, fov=60)
    elif scene == "poses":
        acts = [("idle", 0.0), ("walk", 12.0), ("carry", 8.0), ("work", 0.0), ("fight", 0.0), ("celebrate", 0.0), ("dead", 0.0)]
        job = a.target or "farmer"
        for i, (act, sp) in enumerate(acts):
            kit.spawn(job, None, "crimson", (3 - i) * 7.5, 0, 0, action=act, phase=0.25, speed=sp, tag=f"{act}_")
        ckit_scene.gameplay(cam, (0, 2.8, 0), a.dist or 46.0, a.pitch or 12.0, az_deg=a.az, fov=60)
    elif scene == "turntable":
        # one citizen seen from the front, right side, back and left side (yaw 0 / 90 / 180 / 270): shows capes, packs, quivers
        job = a.target or "governor"
        lk = ckit_rigload.job_look(JOBS.index(job) if job in JOBS else 0)
        for i, yaw in enumerate((0, 90, 180, 270)):
            kit.spawn(job, lk, "crimson", (1.5 - i) * 5.0, 0, yaw, tag=f"t{i}_")
        ckit_scene.gameplay(cam, (0, 3.0, 0), a.dist or 21.0, a.pitch or 8.0, fov=60)
    elif scene == "portraits":
        # head and shoulders of every job (Kit.portrait framing), composed into one contact sheet
        from PIL import Image, ImageDraw

        px = w if a.size else 360
        sc.render.resolution_x = sc.render.resolution_y = px
        tiles = []
        jobs = a.target.split(",") if a.target else JOBS
        for i, job in enumerate(jobs):
            look = ckit_rigload.job_look(JOBS.index(job) if job in JOBS else i)
            names = kit.names_for(job, look, "crimson")
            objs = kit.spawn(job, look, "crimson", 0, 0, 0, tag=f"{job}_", names=names)
            top, half = 0.0, 1.5
            for n in names:
                p = kit.doc["pieces"][n]
                if p["joint"] == "Head":
                    top = max(top, p["bbox_center"][1] + p["size"][1] / 2)
                    half = max(half, (abs(p["bbox_center"][0]) + p["size"][0] / 2) * 1.15)
            ckit_scene.portrait(cam, top, half)
            path = Path(a.out).with_name(f"portrait_{job}.png")
            rig.render(sc, path)
            tiles.append((job, path))
            for o in objs:
                bpy.data.objects.remove(o)
        cols = 4
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * px, rows * (px + 22)), (28, 30, 34))
        d = ImageDraw.Draw(sheet)
        for i, (job, path) in enumerate(tiles):
            r, c = divmod(i, cols)
            sheet.paste(Image.open(path).convert("RGB"), (c * px, r * (px + 22) + 22))
            d.text((c * px + 6, r * (px + 22) + 4), job, fill=(235, 235, 235))
        sheet.save(a.out, quality=88)
        print(f"[scenes] portraits -> {a.out}", flush=True)
        return
    else:
        raise SystemExit(f"unknown scene {scene}")
    if a.silhouette:
        sc.render.engine = "BLENDER_WORKBENCH"
        sh = sc.display.shading
        sh.light, sh.color_type, sh.single_color = "FLAT", "SINGLE", (0.02, 0.02, 0.02)
        sh.show_shadows = sh.show_cavity = sh.show_object_outline = False
        sh.background_type, sh.background_color = "VIEWPORT", (1.0, 1.0, 1.0)
        sc.view_settings.view_transform = "Standard"
        for ob in bpy.data.objects:
            if ob.name == "forge_ground":
                ob.hide_render = True
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
