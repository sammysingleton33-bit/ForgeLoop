"""Measure the character kit budgets from the SHIPPED files only (FL-0135; FORGE-07: measured, never declared).

  ~/forge-bpy/bin/python blender/scripts/charkit_budget.py [--fbx F] [--rig R] [--md OUT.md]

Counts the triangles of every mesh object twice, independently: (1) straight from the FBX bytes (lib/fbxtris.py, the same reader
manifest.check() uses) and (2) by importing the FBX into a fresh Blender scene. Both must agree with each other and with `tris`
in rig.json. Then every assembly (job) x every look of G13.2 (1,728) x the four kingdoms is resolved with the runtime's own
variant rules (lib/ckit_resolve.py) and summed from the measured counts: citizen <= 1,000 (body <= 900, hand tool or sack <= 150),
soldiers and governor <= 1,500, <= 16 pieces, every mesh <= 20,000. Prints a table, exits 1 on any violation.
Evidence class: Blender geometry, not a Studio play test.
"""

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import json  # noqa: E402

from lib import ckit_resolve, fbxtris, manifest  # noqa: E402


def blender_counts(fbx):
    import bpy

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(fbx), axis_forward="-Z", axis_up="Y", global_scale=1.0)
    out, mats, layers = {}, set(), set()
    for o in bpy.data.objects:
        if o.type == "MESH":
            out[o.name] = sum(len(p.vertices) - 2 for p in o.data.polygons)
            mats.update(m.name for m in o.data.materials if m)
            layers.update(c.name for c in o.data.color_attributes)
    return out, sorted(mats), sorted(layers)


def table(doc, measured):
    pieces = doc["pieces"]
    rows = []
    for key in doc["assemblies"]:
        big = key == "governor" or key.startswith("soldier")
        lo, hi, dflt, pmax, tool_max, body_max = 10 ** 9, 0, None, 0, 0, 0
        for kd in manifest.KIT_KINGDOMS:
            for lk in manifest.kit_looks():
                ids = ckit_resolve.resolve_assembly(doc["assemblies"], pieces, key, lk, kd)
                t = sum(measured[i] for i in ids)
                tl = sum(measured[i] for i in ids if pieces[i]["joint"] in manifest.KIT_TOOL_JOINTS)
                lo, hi, pmax = min(lo, t), max(hi, t), max(pmax, len(ids))
                tool_max, body_max = max(tool_max, tl), max(body_max, t - tl)
                if dflt is None:
                    dflt = t
        cap = manifest.KIT_LIMITS["ruler" if big else "citizen"]
        ok = hi <= cap and pmax <= manifest.KIT_LIMITS["pieces"] and (big or (body_max <= manifest.KIT_LIMITS["citizen_body"]
                                                                              and tool_max <= manifest.KIT_LIMITS["citizen_tool"]))
        rows.append((key, dflt, lo, hi, cap, body_max, tool_max, pmax, ok))
    return rows


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default=str(REPO / "games/game-001/art/char_kit/citizen_kit.fbx"))
    ap.add_argument("--rig", default=str(REPO / "games/game-001/art/char_kit/rig.json"))
    ap.add_argument("--md", default="")
    ap.add_argument("--no-blender", action="store_true", help="skip the second measurement through the Blender importer")
    a = ap.parse_args(argv)
    doc = json.loads(Path(a.rig).read_text())
    measured = fbxtris.measure(a.fbx)
    errs = manifest.kit_budget_errors(doc, measured)
    mats, layers = [], []
    if not a.no_blender:
        bl, mats, layers = blender_counts(a.fbx)
        errs += [f"Blender import counts {bl.get(k)} triangles for {k}, the FBX reader {v}" for k, v in measured.items() if bl.get(k) != v]
        if mats != ["M_charkit_vc"] or layers != ["Col"]:
            errs.append(f"materials {mats} / colour layers {layers} (want one material M_charkit_vc and one colour layer Col)")
    rows = table(doc, measured) if not errs or all("over" in e or "pieces" in e for e in errs) else []
    lines = [f"FBX {Path(a.fbx).stat().st_size:,} bytes; {len(measured)} mesh objects, {sum(measured.values()):,} triangles in all; "
             f"largest mesh {max(measured.values())}; materials {mats or 'n/a'}; colour layers {layers or 'n/a'}; "
             f"looks checked per job: {len(manifest.kit_looks()):,} x {len(manifest.KIT_KINGDOMS)} kingdoms", "",
             "| job | default tris | min | max | cap | body max | tool max | pieces = draw calls (max) | texture memory | verdict |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for key, d, lo, hi, cap, body, tool, pm, ok in rows:
        lines.append(f"| {key} | {d} | {lo} | {hi} | {cap} | {body} | {tool} | {pm} | 0 B | {'PASS' if ok else 'FAIL'} |")
    out = "\n".join(lines)
    print(out)
    for e in errs:
        print("ERROR:", e)
    if a.md:
        Path(a.md).write_text(out + "\n")
    ok = not errs and all(r[-1] for r in rows)
    print("\ncharkit budget:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:]))
