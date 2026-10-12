#!/usr/bin/env python3
"""Top-down plan PNG of the generated map (footprints projected to XZ, drawn by height). Needs Pillow.

    python3 roblox/scripts/render_map_plan.py games/sandbox/map games/sandbox/map-plan.png

A layout review aid only: it is not a Studio render and says nothing about lighting or materials."""
import glob, json, sys
from PIL import Image, ImageDraw

def walk(node, out, tags=()):
    props = node.get("properties", {})
    if "Size" in props and "CFrame" in props:
        out.append((node, props))
    for c in node.get("children", []):
        walk(c, out)

def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2: return pts
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

mapdir, out_png = sys.argv[1], sys.argv[2]
parts = []
for f in sorted(glob.glob(mapdir + "/*.model.json")):
    walk(json.load(open(f)), parts)
W = 1440; scale = W / 760.0; off = 380
img = Image.new("RGB", (W, W), (30, 30, 30)); d = ImageDraw.Draw(img)
items = []
for node, p in parts:
    cf = p["CFrame"]["CFrame"]; pos = cf["position"]; R = cf["orientation"]; sx, sy, sz = p["Size"]
    corners = []
    for a in (-0.5, 0.5):
        for b in (-0.5, 0.5):
            for c in (-0.5, 0.5):
                l = (a*sx, b*sy, c*sz)
                w = [pos[i] + R[i][0]*l[0] + R[i][1]*l[1] + R[i][2]*l[2] for i in range(3)]
                corners.append(w)
    top = max(c[1] for c in corners)
    poly = hull([(round((c[0]+off)*scale, 2), round((c[2]+off)*scale, 2)) for c in corners])
    col = tuple(int(v*255) for v in p.get("Color", [0.6,0.6,0.6]))
    invisible = p.get("Transparency", 0) >= 1
    items.append((top, poly, col, invisible, p.get("Tags", []), node.get("name","")))
items.sort(key=lambda t: t[0])
for top, poly, col, inv, tags, name in items:
    if inv:
        if tags and "ForgePlayArea" not in tags:
            d.polygon(poly, outline=(255, 0, 255))
        continue
    d.polygon(poly, fill=col, outline=tuple(max(0, v-40) for v in col))
for top, poly, col, inv, tags, name in items:
    if tags and "ForgePlayArea" not in tags and "ForgeKingdom" not in tags:
        cx = sum(p[0] for p in poly)/len(poly); cy = sum(p[1] for p in poly)/len(poly)
        label = tags[0].replace("Forge", "")
        d.text((cx-3*len(label), cy-5), label, fill=(255, 255, 255))
d.text((10, 10), "N = -Z (top)   world plan, 1 px = %.2f studs" % (1/scale), fill=(255,255,255))
img.save(out_png)
print("rendered", len(items), "parts ->", out_png)
