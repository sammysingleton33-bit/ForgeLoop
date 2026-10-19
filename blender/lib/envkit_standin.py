"""Bounds of the part-built stand-ins (Kit/Props.luau) from a Lune dump, stdlib only (FL-0136 phase 2).

A dump entry is { parts = [{ shape, size, cframe, transparency }...] } as written by blender/scripts/lune/EnvInventory.spec.luau.
`bbox` is exact for blocks and tight for balls and upright/tilted cylinders (a rotated box would over-state them);
`reach` is the horizontal radius the PlotClearance spec measures (WorldPlan.CLEAR.radius is rounded up from it): a ball by its
true radius, an upright cylinder by its radius, anything else by the farthest corner of its box around the pivot.
"""

import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
STANDINS_JSON = HERE / "envkit_standins.json"


def _axes(c):
    return c[:3], [c[3:6], c[6:9], c[9:12]]


def part_extent(p):
    """Half extents of the part's bounding box along the world axes."""
    pos, R = _axes(p["cframe"])
    h = [s / 2 for s in p["size"]]
    sh = p["shape"]
    out = []
    for i in range(3):
        if sh == "Ball":
            e = min(h)
        elif sh == "Cylinder":  # axis along local X, radius = min(Y, Z) / 2
            r = min(h[1], h[2])
            e = abs(R[i][0]) * h[0] + r * math.sqrt(max(0.0, 1 - R[i][0] ** 2))
        else:
            e = sum(abs(R[i][j]) * h[j] for j in range(3))
        out.append(e)
    return pos, out


def bbox(entry):
    mn, mx = [1e9] * 3, [-1e9] * 3
    for p in entry["parts"]:
        if p.get("transparency", 0) >= 0.99:
            continue
        pos, e = part_extent(p)
        for i in range(3):
            mn[i] = min(mn[i], pos[i] - e[i])
            mx[i] = max(mx[i], pos[i] + e[i])
    return mn, mx


def reach(entry):
    r = 0.0
    for p in entry["parts"]:
        if p.get("transparency", 0) >= 0.99:
            continue
        c = p["cframe"]
        pos, R = _axes(c)
        h = [s / 2 for s in p["size"]]
        sh = p["shape"]
        if sh == "Ball":
            reach_ = min(h)
        elif sh == "Cylinder" and abs(R[1][0]) > 0.999:
            reach_ = max(h[1], h[2])
        else:
            ex = sum(abs(R[0][j]) * h[j] for j in range(3))
            ez = sum(abs(R[2][j]) * h[j] for j in range(3))
            reach_ = math.hypot(ex, ez)
        r = max(r, math.hypot(pos[0], pos[2]) + reach_)
    return r


def summarise(dump):
    """id -> the figures the mesh kit is fitted to, from the inventory dump."""
    full, ship = dump["runs"]["full"]["byId"], dump["runs"]["default"]["byId"]
    out = {}
    for pid, entry in sorted(dump["subjects"].items()):
        mn, mx = bbox(entry)
        out[pid] = {
            "size": [round(mx[i] - mn[i], 2) for i in range(3)],
            "x_range": [round(mn[0], 2), round(mx[0], 2)],
            "z_range": [round(mn[2], 2), round(mx[2], 2)],
            "reach": round(reach(entry), 2),
            "parts": entry["partCount"],
            "placed": bool(entry.get("placed")),
            "count_full": full.get(pid, {}).get("n", 0),
            "count_shipped": ship.get(pid, {}).get("n", 0),
            "node": pid in dump.get("nodes", {}),
            "features": full.get(pid, {}).get("features") or {},
        }
    return out


def load():
    return json.loads(STANDINS_JSON.read_text())
