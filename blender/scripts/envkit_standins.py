"""Write blender/lib/envkit_standins.json from the Lune inventory dump (stdlib only; FL-0136 phase 2).

  FORGE_ENV_INVENTORY=/tmp/env_inventory.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json \
      --specs blender/scripts/lune EnvInventory
  python3 blender/scripts/envkit_standins.py /tmp/env_inventory.json [--table]

The JSON is the table the env kit is fitted against (bbox, reach, parts and how often the real world places each id); --table prints the
markdown inventory used in games/game-001/art/reviews/env-mesh.md.
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

from lib import envkit_standin as S  # noqa: E402

FAMILIES = [("tree_oak", "oak"), ("tree_pine", "pine"), ("tree_birch", "birch"), ("bush", "bush"), ("plant_flowers", "flowers"), ("rock_boulder_s", "boulder S"),
            ("rock_boulder_m", "boulder M"), ("rock_boulder_l", "boulder L"), ("rock_cliff", "cliff"), ("resource_stone", "node stone"), ("resource_ore", "node ore"),
            ("resource_wood", "node wood"), ("farm_field_wheat", "wheat"), ("farm_field_cabbage", "cabbage"), ("farm_haystack", "haystack"), ("farm_fence", "fence")]


def family(pid):
    for prefix, name in FAMILIES:
        if pid.startswith(prefix):
            return name
    return None


def main(argv):
    src = Path(argv[1])
    dump = json.loads(src.read_text())
    table = S.summarise(dump)
    doc = {"_comment": "Part-built stand-in figures per asset id, summarised from blender/scripts/lune/EnvInventory.spec.luau (Kit/Props.luau at the Kit.VERSION below): bbox size in studs "
                       "(x, y, z), PlotClearance-style horizontal reach, parts (Root included), and how many times the real world places the id (count_full = density 1.0 incl. resource "
                       "nodes, count_shipped = the shipped density). Regenerate with blender/scripts/envkit_standins.py.",
           "kit_version": dump["version"], "clear_radius": dump["clear"], "world": {k: {"parts": v["parts"], "props": v["props"]} for k, v in dump["runs"].items()},
           "standins": table}
    (HERE / "lib" / "envkit_standins.json").write_text(json.dumps(doc, indent=1) + "\n")
    print(f"wrote blender/lib/envkit_standins.json: {len(table)} ids")
    if "--table" in argv:
        print("| family | ids | placed ids | placements (density 1.0 / shipped) | stand-in parts each | radius (m) | height | reach |")
        print("|---|---|---|---|---|---|---|---|")
        rows = {}
        for pid, v in table.items():
            f = family(pid)
            if not f:
                continue
            r = rows.setdefault(f, {"ids": [], "placed": 0, "full": 0, "ship": 0, "parts": set(), "r": [], "h": [], "reach": []})
            r["ids"].append(pid)
            r["placed"] += 1 if v["placed"] else 0
            r["full"] += v["count_full"]
            r["ship"] += v["count_shipped"]
            r["parts"].add(v["parts"])
            r["r"].append((v["size"][0] + v["size"][2]) / 4)
            r["h"].append(v["size"][1])
            r["reach"].append(v["reach"])
        for f, r in rows.items():
            print(f"| {f} | {len(r['ids'])} | {r['placed']} | {r['full']} / {r['ship']} | {', '.join(str(p) for p in sorted(r['parts']))} | {min(r['r']):.1f} to {max(r['r']):.1f} | "
                  f"{min(r['h']):.1f} to {max(r['h']):.1f} | {min(r['reach']):.1f} to {max(r['reach']):.1f} |")


if __name__ == "__main__":
    main(sys.argv)
