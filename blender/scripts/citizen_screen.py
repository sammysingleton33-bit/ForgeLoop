"""Citizen readability at the start camera (visual upgrade pass 1, stream C).

Pure python (numpy + Pillow, no bpy): reads the Lune world dump (WorldDump.spec: `feature = "citizen"` placements, by default the sim's
real positions 30 s after the start, rest pose) and measures how big the citizens are on screen.

  measure   how many pixels tall / wide is each citizen at the ruler's start camera? The camera is the one render_world.py draws: the dump's
            `start` = {zoom, fov, pitch, ahead, turn} (the focus lies `ahead` studs in front of the seated ruler's root along the throne's
            facing; the camera looks along that facing turned by `turn` degrees: 180 = back across the yard at the keep), the pitch
            from pitchFor(zoom) = 38 + 27 * (zoom - 40) / 180 (zoom 70 -> 42.5 deg, zoom 220 -> 65, zoom 120 -> 50). Every part's
            silhouette is projected (boxes by their 8 corners, cylinders by two end circles, balls as screen discs) and the figure's
            screen box is their union: `figure h` is its height in pixels with hat and tool, `body-only h` without them.
  crops     cut the citizens out of a finished render of the same view at 1:1 (no resampling), labelled by job (a citizen outside the
            frame is blank: citizen_crops.py draws every citizen on its own tile instead).

  python3 blender/scripts/citizen_screen.py measure --json world.json --kingdom crimson --views default1080,defaultphone,far1080,farphone
  python3 blender/scripts/citizen_screen.py crops   --json world.json --kingdom crimson --view default --image render.png --out sheet.jpg

Views: see VIEWS (default = the start view, far = zoom 220, legacy = zoom 120 / FOV 70; each at the 1600 x 900 render size, "1080" =
1920 x 1080 desktop, "phone" = 750 x 311). Pixel sizes scale with the viewport height: a 900 px render is 0.83 of 1080p.
(A render-based "ground contrast" measure was tried and dropped: the ring of ground round a citizen in the start frame is mostly
buildings and shadow, so the number moved with the neighbours, not the citizen. The colour rule is KitCitizenAerial.spec's CIELAB dE.)
"""

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

# View name -> (camera, width, height). Cameras: "default" = the START view (the dump's `start` = {zoom, fov, pitch, ahead, turn}: the
# focus lies `ahead` studs in front of the seated ruler's root along the throne's facing and the camera looks along that facing turned
# by `turn` degrees: 180 = back across the yard at the keep), "far" = the same focus fully zoomed out (zoom 220, pitch 65), "legacy" =
# the B22 build's camera (zoom 120, FOV 70, pitch 50, focus on the throne, no turn). 1600 x 900 = the renders, 1080 = desktop 1080p,
# phone = 750 x 311.
CAMERAS = ("default", "far", "legacy")
SIZES = {"": (1600, 900), "1080": (1920, 1080), "phone": (750, 311)}
VIEWS = {f"{c}{sfx}": (c, w, h) for c in CAMERAS for sfx, (w, h) in SIZES.items()}
START_DEFAULT = {"zoom": 70.0, "fov": 55.0, "ahead": 20.0, "turn": 180.0}  # FL-0147: until the dump carries `start`


def pitch_for(zoom):
    """RulerCameraController.pitchFor: 38 deg at zoom 40 up to 65 deg at zoom 220, linear in between."""
    z = min(220.0, max(40.0, zoom))
    return 38.0 + 27.0 * (z - 40.0) / 180.0


def camera_params(data, camera):
    """(zoom, fov, ahead, turn_deg) of a named camera for this dump."""
    st = {**START_DEFAULT, **(data.get("start") or {})}
    if camera == "default":
        return st["zoom"], st["fov"], st["ahead"], st["turn"]
    if camera == "far":
        return 220.0, st["fov"], st["ahead"], st["turn"]
    return 120.0, 70.0, 0.0, 0.0  # legacy


def flat_dir(throne, turn_deg):
    """The camera's flat look direction: the throne's facing (a CFrame's look vector is minus its third column) turned by turn_deg."""
    lx, lz = -throne[5], -throne[11]
    n = math.hypot(lx, lz) or 1.0
    lx, lz = lx / n, lz / n
    t = math.radians(turn_deg)
    return lx * math.cos(t) - lz * math.sin(t), lx * math.sin(t) + lz * math.cos(t)


class Camera:
    def __init__(self, focus, zoom, res, fov, flat):
        """focus (x, y, z); `flat` = the camera's flat look direction (fx, fz); it stands `zoom` studs away at pitch_for(zoom)."""
        pitch = math.radians(pitch_for(zoom))
        self.zoom, self.fov = zoom, fov
        fwd_g = np.array(flat, float)
        self.loc = np.array([focus[0] - fwd_g[0] * zoom * math.cos(pitch), focus[1] + zoom * math.sin(pitch),
                             focus[2] - fwd_g[1] * zoom * math.cos(pitch)])
        f = np.array(focus, float) - self.loc
        self.fwd = f / np.linalg.norm(f)
        right = np.cross(self.fwd, np.array([0.0, 1.0, 0.0]))
        self.right = right / np.linalg.norm(right)
        self.up = np.cross(self.right, self.fwd)
        self.w, self.h = res
        self.f = (self.h / 2.0) / math.tan(math.radians(fov) / 2.0)
        self.pitch = math.degrees(pitch)

    def project(self, p):
        """World point(s) (n, 3) -> (x px, y px, depth); y grows downward."""
        d = np.asarray(p, float) - self.loc
        z = d @ self.fwd
        x = self.w / 2.0 + self.f * (d @ self.right) / z
        y = self.h / 2.0 - self.f * (d @ self.up) / z
        return x, y, z

    def studs_per_px(self, depth):
        return depth / self.f


def cf_matrix(c):
    r = np.array(c[3:12], float).reshape(3, 3)
    return np.array(c[0:3], float), r


def part_points(part, pos, rot, n=14):
    """Surface sample points of a part in world space and, for balls, (centre, radius)."""
    ppos, prot = cf_matrix(part["cframe"])
    centre = pos + rot @ ppos
    rr = rot @ prot
    sx, sy, sz = part["size"]
    shape = part.get("shape")
    if shape == "Ball":
        return None, (centre, max(sx, sy, sz) / 2.0)
    pts = []
    if shape == "Cylinder":  # axis along local X
        for sgn in (-1, 1):
            for k in range(n):
                a = 2 * math.pi * k / n
                pts.append([sgn * sx / 2, math.cos(a) * sy / 2, math.sin(a) * sz / 2])
    else:  # Block, WedgePart, CornerWedgePart: the 8 corners of the bounding box
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    pts.append([ix * sx / 2, iy * sy / 2, iz * sz / 2])
    pts = np.array(pts, float)
    return centre + (rr @ pts.T).T, None


BODY = ("Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg")


def citizen_box(cam, parts, placement, body_only=False):
    """Screen box (x0, y0, x1, y1) of the figure and its mean depth; body_only leaves out hats, tools and details."""
    pos, rot = cf_matrix(placement["cframe"])
    xs, ys, zs = [], [], []
    for part in parts:
        if part.get("transparency", 0) >= 0.99 or part["name"] == "Root":
            continue
        if body_only and part["name"] not in BODY:
            continue
        pts, ball = part_points(part, pos, rot)
        if ball is not None:
            c, r = ball
            x, y, z = cam.project(c[None, :])
            rpx = r * cam.f / z[0]
            xs += [x[0] - rpx, x[0] + rpx]
            ys += [y[0] - rpx, y[0] + rpx]
            zs.append(z[0])
        else:
            x, y, z = cam.project(pts)
            xs += list(x)
            ys += list(y)
            zs += list(z)
    return (min(xs), min(ys), max(xs), max(ys)), float(np.mean(zs))


def citizens(data, kingdom):
    out = []
    for p in data["placements"]:
        if p.get("feature") != "citizen" or not p["assetId"].endswith("_" + kingdom):
            continue
        job = p["assetId"][len("citizen_"):-len("_" + kingdom)]
        out.append((job, p))
    return out


def camera_for(data, kingdom, view, focus=None):
    """The camera of `view` for a kingdom: focus = `ahead` studs in front of the seated ruler's root (the dump's `throne`) unless a
    focus is given (the crop tool centres the same camera on each citizen)."""
    camera, w, h = VIEWS[view]
    zoom, fov, ahead, turn = camera_params(data, camera)
    th = data["plots"][kingdom]["throne"]
    fl = flat_dir(th, 0.0)  # the throne's facing: the focus lies along it
    if focus is None:
        focus = (th[0] + fl[0] * ahead, th[1], th[2] + fl[1] * ahead)
    return Camera(focus, zoom, (w, h), fov, flat_dir(th, turn))


def cmd_measure(args):
    data = json.loads(Path(args.json).read_text())
    rows = []
    for view in args.views.split(","):
        cam = camera_for(data, args.kingdom, view)
        per_job = {}
        for job, p in citizens(data, args.kingdom):
            (x0, y0, x1, y1), depth = citizen_box(cam, data["assets"][p["assetId"]], p)
            (_, by0, _, by1), _ = citizen_box(cam, data["assets"][p["assetId"]], p, body_only=True)
            per_job.setdefault(job, []).append((y1 - y0, x1 - x0, by1 - by0))
        allh = [h for v in per_job.values() for h, _, _ in v]
        print(f"\n== {view}: {cam.w} x {cam.h}, zoom {cam.zoom:.0f}, FOV {cam.fov:.0f}, pitch {cam.pitch:.1f}, "
              f"{cam.studs_per_px(cam.zoom):.3f} studs/px at the focus, {len(allh)} citizens ({args.kingdom})")
        for job, v in sorted(per_job.items()):
            hs, ws, bs = [a for a, _, _ in v], [b for _, b, _ in v], [c for _, _, c in v]
            print(f"   {job:<11} n={len(v):>2}  figure h px min {min(hs):5.1f} med {statistics.median(hs):5.1f} max {max(hs):5.1f}"
                  f"   w med {statistics.median(ws):5.1f}   body-only h med {statistics.median(bs):5.1f}")
        allb = [c for v in per_job.values() for _, _, c in v]
        print(f"   all         n={len(allh):>2}  figure h px min {min(allh):5.1f} med {statistics.median(allh):5.1f} max {max(allh):5.1f}"
              f"            body-only h med {statistics.median(allb):5.1f}")
        rows.append((view, statistics.median(allh)))
    return rows


def load_image(path):
    from PIL import Image

    return Image.open(path).convert("RGB")


def cmd_crops(args):
    from PIL import Image, ImageDraw, ImageFont

    data = json.loads(Path(args.json).read_text())
    cam = camera_for(data, args.kingdom, args.view)
    img = load_image(args.image)
    if img.size != (cam.w, cam.h):
        raise SystemExit(f"image is {img.size}, the {args.view} view is {(cam.w, cam.h)}")
    order = ["farmer", "woodcutter", "miner", "hauler", "builder", "idle"]
    cits = sorted(citizens(data, args.kingdom), key=lambda jp: order.index(jp[0]) if jp[0] in order else 9)
    tile = args.tile
    cols = 6
    scale = max(1, args.scale)
    rows = (len(cits) + cols - 1) // cols
    pad, head, lab = 6, 26, 14
    cw = tile * scale
    W, H = cols * (cw + pad) + pad, head + rows * (cw + lab + pad) + pad
    sheet = Image.new("RGB", (W, H), (34, 37, 42))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(size=11)
        big = ImageFont.load_default(size=14)
    except TypeError:
        font = big = ImageFont.load_default()
    d.text((pad, 5), f"{args.kingdom} citizens, {args.view} view ({cam.w} x {cam.h}), crops {tile} px"
                     + (f" shown x{scale} nearest" if scale > 1 else " at 1:1"), fill=(245, 236, 210), font=big)
    for i, (job, p) in enumerate(cits):
        (x0, y0, x1, y1), _ = citizen_box(cam, data["assets"][p["assetId"]], p)
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        left, top = int(round(cx - tile / 2)), int(round(cy - tile / 2))
        crop = img.crop((left, top, left + tile, top + tile))
        if scale > 1:
            crop = crop.resize((cw, cw), Image.NEAREST)
        col, row = i % cols, i // cols
        ox, oy = pad + col * (cw + pad), head + row * (cw + lab + pad)
        sheet.paste(crop, (ox, oy))
        d.text((ox + 1, oy + cw + 1), f"{job} {y1 - y0:.0f}px", fill=(200, 204, 212), font=font)
    from lib import contact  # same JPEG size cap as every other preview

    if args.out.endswith(".png"):
        sheet.save(args.out)
        print(f"wrote {args.out} {sheet.size}")
    else:
        res = contact.save_jpeg_under(sheet, args.out)
        print(f"wrote {res[0]} {res[1]} bytes {res[3]}")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("measure")
    m.add_argument("--json", required=True)
    m.add_argument("--kingdom", default="crimson")
    m.add_argument("--views", default="default,default1080,phone,far,far1080,farphone")
    c = sub.add_parser("crops")
    c.add_argument("--json", required=True)
    c.add_argument("--kingdom", default="crimson")
    c.add_argument("--view", default="default", choices=sorted(VIEWS))
    c.add_argument("--image", required=True)
    c.add_argument("--out", required=True)
    c.add_argument("--tile", type=int, default=56)
    c.add_argument("--scale", type=int, default=1)
    args = ap.parse_args(argv)
    {"measure": cmd_measure, "crops": cmd_crops}[args.cmd](args)


if __name__ == "__main__":
    main(sys.argv[1:])
