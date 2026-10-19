"""Render the whole D-019 evidence set of one kit version (FL-0135 silhouettes): the crowd around the farm at 170 and 40 studs, the labelled
170-stud lineup, the eleven identities from the front / the back / as silhouettes, the 36-look grid and the eleven portraits.

  python3 blender/scripts/charkit_render_set.py --fbx F --rig R --out DIR [--only crowd170,jobs] [--samples 16]

Runs blender/scripts/charkit_scenes.py once per image with the bpy Python (~/forge-bpy/bin/python). Two sets (old kit files, new kit files)
feed blender/scripts/charkit_compare_sheets.py. Blender renders are not Studio renders.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = os.environ.get("FORGE_BPY_PYTHON") or str(Path.home() / "forge-bpy/bin/python")

SCENES = {
    "crowd170": ["--scene", "crowd170", "--dist", "170", "--pitch", "50", "--target", "0,3,0", "--size", "1280x720"],
    "crowd40": ["--scene", "crowd40", "--size", "1280x720"],
    "lineup170": ["--scene", "jobs", "--dist", "170", "--pitch", "50", "--size", "1280x720"],
    "jobs": ["--scene", "jobs", "--dist", "15", "--pitch", "6", "--size", "1800x560"],
    "jobs_back": ["--scene", "jobs", "--dist", "15", "--pitch", "6", "--yaw", "180", "--size", "1800x560"],
    "jobs_air": ["--scene", "jobs", "--dist", "30", "--pitch", "50", "--size", "1800x560"],
    "sil_jobs": ["--scene", "jobs", "--silhouette", "--dist", "15", "--pitch", "3", "--size", "1800x420"],
    "sil_jobs_yaw": ["--scene", "jobs", "--silhouette", "--yaw", "40", "--dist", "15", "--pitch", "3", "--size", "1800x420"],
    "sil_air": ["--scene", "jobs", "--silhouette", "--dist", "30", "--pitch", "50", "--size", "1800x560"],
    "looks": ["--scene", "looks", "--size", "1600x900"],
    "portraits": ["--scene", "portraits", "--ground", "150,148,140", "--size", "360x360"],
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", required=True)
    ap.add_argument("--rig", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    names = a.only.split(",") if a.only else list(SCENES)
    for n in names:
        cmd = [PY, "-I", str(HERE / "charkit_scenes.py"), "--fbx", a.fbx, "--rig", a.rig, "--out", str(out / f"{n}.png"),
               "--samples", str(a.samples)] + SCENES[n]
        r = subprocess.run(cmd, capture_output=True, text=True)
        err = [l for l in (r.stdout + r.stderr).splitlines() if "Traceback" in l or "rror:" in l and "EGL" not in l]
        print(f"[render_set] {n}: {'ok' if r.returncode == 0 and not err else 'FAILED ' + ' | '.join(err[:2])}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
