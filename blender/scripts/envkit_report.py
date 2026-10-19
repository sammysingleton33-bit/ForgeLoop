"""Markdown tables for games/game-001/art/reviews/env-mesh.md "Phase 2" from the committed kit files (stdlib only; FL-0136).

  python3 blender/scripts/envkit_report.py [--relief /tmp/env_relief.json]

Prints: the per-id measured table of env.json (triangles, bounding box, footprint and height against the stand-in, node flag), the family summary of both kits and,
with --relief (the dump of blender/scripts/lune/EnvRelief.spec.luau), the part-count relief per family.
"""

import argparse
import json
from pathlib import Path

KIT = Path(__file__).resolve().parents[2] / "games/game-001/art/env_kit"


def table(doc, title):
    print(f"\n**{title}**\n")
    print("| asset id | family | triangles | bbox x, y, z (studs) | footprint vs stand-in | height vs stand-in | node | note |")
    print("|---|---|---|---|---|---|---|---|")
    for pid, p in doc["props"].items():
        f = p.get("fit") or {}
        s = p["size"]
        note = "fit_note" if p.get("fit_note") else ""
        fp = f"{f['footprint_ratio']:.0%}" if f else "n/a"
        hh = f"{f['height_ratio']:.0%}" if f else "n/a"
        print(f"| `{pid}` | {p['family']} | {p['tris']} | {s[0]:.1f}, {s[1]:.1f}, {s[2]:.1f} | {fp} | {hh} | {'yes' if p['node'] else ''} | {note} |")


def families(doc, title):
    print(f"\n**{title}**\n")
    print("| family | meshes | triangles per mesh (min to max) | total | budget |")
    print("|---|---|---|---|---|")
    for fam, e in doc["measured"].items():
        print(f"| {fam} | {e['props']} | {e['tris_min']} to {e['tris_max']} | {e['tris_total']} | {e['budget'][0]} to {e['budget'][1]} |")


def relief(path):
    runs = json.loads(Path(path).read_text())["runs"]
    for dens, label in (("shipped", "shipped density"), ("full", "density 1.0 (the untrimmed valley)")):
        p, m = runs[dens]["plain"], runs[dens]["mesh"]
        print(f"\n**{label}: {p['parts']} -> {m['parts']} parts ({p['parts'] - m['parts']} fewer, {1 - m['parts'] / p['parts']:.0%})**, same {p['props']} placements\n")
        print("| family | placements (incl. nodes) | parts today | parts with meshes | relief |")
        print("|---|---|---|---|---|")
        tot = 0
        for fam in sorted(set(p["byFamily"]) | set(m["byFamily"])):
            a = p["byFamily"].get(fam, {"n": 0, "parts": 0})
            b = m["byFamily"].get(fam, {"n": 0, "parts": 0})
            tot += a["parts"] - b["parts"]
            print(f"| {fam} | {a['n']} | {a['parts']} | {b['parts']} | {a['parts'] - b['parts']} |")
        print(f"| total | | | | {tot} |")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--relief", default="")
    a = ap.parse_args()
    main_doc = json.loads((KIT / "env.json").read_text())
    spare_doc = json.loads((KIT / "env_spares.json").read_text())
    families(main_doc, "env_kit_01 (env_kit.fbx, the ids the world places)")
    families(spare_doc, "env_kit_02 (env_kit_spares.fbx, ids nothing places yet)")
    table(main_doc, "env_kit_01: measured per id")
    table(spare_doc, "env_kit_02: measured per id")
    if a.relief:
        relief(a.relief)


if __name__ == "__main__":
    main()
