"""Measure the character kit budgets from the SHIPPED files only (FL-0135; FORGE-07 A5).

  ~/forge-bpy/bin/python blender/scripts/charkit_budget.py [--fbx F] [--rig R] [--md OUT.md]

Imports citizen_kit.fbx into a fresh Blender scene, counts the triangles of every imported mesh object (quads count 2), then
assembles every (job x look x kingdom) citizen from rig.json's own rules (lib/ckit_rigload.names_from_doc) and reports, per job:
default / maximum triangles, tool triangles, pieces (= MeshParts = draw calls, one material) and texture memory (0: vertex
colours only). Exit 1 when a budget of rig.json's `budget` block is exceeded. Evidence class: Blender geometry, not Studio.
"""

import argparse
import itertools
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402

from lib import ckit_rigload  # noqa: E402

TOOL_SLOTS = ("tool", "toolband", "shield")  # what counts against the <= 150 tool budget (lib/ckit_kit.TOOL_SLOTS)
BIG = {"soldier", "soldier_sword", "soldier_bow", "governor"}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default=str(REPO / "games/game-001/art/char_kit/citizen_kit.fbx"))
    ap.add_argument("--rig", default=str(REPO / "games/game-001/art/char_kit/rig.json"))
    ap.add_argument("--md", default="")
    a = ap.parse_args(argv)
    doc = json.loads(Path(a.rig).read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=a.fbx, axis_forward="-Z", axis_up="Y", global_scale=1.0)
    tris, mats, layers = {}, set(), set()
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        me = o.data
        tris[o.name] = sum(len(p.vertices) - 2 for p in me.polygons)
        mats.update(m.name for m in me.materials if m)
        layers.update(c.name for c in me.color_attributes)
    pieces = doc["pieces"]
    missing = sorted(set(pieces) - set(tris))
    drift = {n: (tris[n], p["tris"]) for n, p in pieces.items() if n in tris and tris[n] != p["tris"]}
    b = doc["budget"]
    looks = [{"skin": s, "hair": h, "hairColor": hc, "outfit": o} for s, h, hc, o in itertools.product((1, 4), range(1, 7), (1, 5, 8), range(1, 7))]
    rows, ok = [], not missing and not drift
    for job in doc["assemblies"]:
        lo, hi, pmax, tool_max, dflt = 10 ** 9, 0, 0, 0, None
        for kd in ckit_rigload.KINGDOMS:
            for lk in looks:
                names = ckit_rigload.names_from_doc(doc, job, lk, kd)
                t = sum(tris[n] for n in names)
                lo, hi, pmax = min(lo, t), max(hi, t), max(pmax, len(names))
                tool_max = max(tool_max, sum(tris[n] for n in names if pieces[n]["slot"] in TOOL_SLOTS))
                if dflt is None:
                    dflt = t
        cap = b["ruler_tris"] if job in BIG else b["citizen_tris"]
        good = hi <= cap and pmax <= b["max_pieces"] and tool_max <= b["tool_tris"]
        ok = ok and good
        rows.append((job, dflt, lo, hi, cap, tool_max, pmax, good))
    lines = [f"FBX {Path(a.fbx).stat().st_size:,} bytes; {len(tris)} mesh objects, {sum(tris.values()):,} triangles in all; materials {sorted(mats)}; "
             f"colour layers {sorted(layers)}; missing from FBX {missing or 'none'}; triangle drift vs rig.json {drift or 'none'}", "",
             "| job | default tris | min | max | cap | tool tris max | pieces = draw calls (max) | texture memory | verdict |",
             "|---|---|---|---|---|---|---|---|---|"]
    for job, d, lo, hi, cap, tm, pm, good in rows:
        lines.append(f"| {job} | {d} | {lo} | {hi} | {cap} | {tm} | {pm} | 0 B | {'PASS' if good else 'FAIL'} |")
    out = "\n".join(lines)
    print(out)
    if a.md:
        Path(a.md).write_text(out + "\n")
    print("\ncharkit budget:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:]))
