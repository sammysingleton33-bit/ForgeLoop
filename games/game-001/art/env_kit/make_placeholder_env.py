#!/usr/bin/env python3
"""make_placeholder_env — writes the PLACEHOLDER env kit (env.json shape, schema_version 1) the Kit specs use.

FL-0136 (D-057 (18)-(20)), FORGE-02. Standard library only. Not art: only numbers. The stand-in sizes are the drawn bounds of
the part-built props measured on 2026-10-19 with a Lune probe over Kit.prop (visible parts, pivot frame); the mesh sizes are
chosen to sit inside the fit rules (and one prop exercises `fit_note`). It exercises every field of the format: the
families, resource nodes, both collider forms, fit_note.

    python3 games/game-001/art/env_kit/make_placeholder_env.py [--out PATH] [--check]

Default output games/game-001/tests/world/fixtures/env_placeholder.env.json (deterministic). --check exits 1 when the
committed file differs. The real kit is games/game-001/art/env_kit/env.json (Blender worker).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DEFAULT_OUT = ROOT / "games/game-001/tests/world/fixtures/env_placeholder.env.json"

# id: (family, node, stand-in size measured, mesh size, bbox centre x/z offset, tris, extras)
PROPS = {
    "tree_oak_01": ("tree", True, (18.9, 25.5, 21.0), (17.6, 24.0, 19.2), (-1.0, 0.4), 780, {}),
    "tree_oak_02": ("tree", False, (16.3, 24.6, 16.9), (16.0, 23.5, 16.4), (-0.2, -0.4), 720, {}),
    "tree_oak_03": ("tree", True, (20.8, 25.5, 22.7), (17.0, 32.0, 17.0), (0.5, 0.0), 800,
                    {"fit_note": "a tall, narrow lone oak: the role is a landmark, so it is taller and thinner than the part-built dome"}),
    "tree_pine_01": ("tree", False, (16.4, 29.6, 16.4), (15.0, 28.8, 15.2), (0.0, 0.1), 620, {}),
    "tree_pine_02": ("tree", True, (16.4, 32.3, 16.4), (15.6, 31.0, 15.6), (0.1, 0.0), 640, {}),
    "tree_birch_01": ("tree", False, (10.1, 22.2, 8.1), (9.6, 21.0, 8.8), (-1.5, 0.2), 520, {}),
    "bush_01": ("bush", False, (7.4, 5.2, 6.9), (7.0, 4.8, 6.6), (-0.2, 0.3), 160, {}),
    "bush_03": ("bush", True, (6.1, 5.5, 6.7), (6.2, 5.2, 6.4), (0.3, 0.0), 180, {}),
    "rock_boulder_m_01": ("rock", False, (6.2, 5.3, 8.9), (6.0, 5.0, 8.4), (0.2, 0.8), 120, {}),
    "rock_boulder_l_01": ("rock", False, (18.0, 9.1, 14.3), (17.0, 8.8, 13.6), (-1.0, 0.0), 260, {"collider": [10, 6, 8]}),
    "resource_stone_01": ("rock", True, (16.8, 7.8, 10.7), (16.0, 7.4, 10.2), (0.5, -0.4), 240, {}),
    "resource_ore_03": ("rock", True, (11.4, 8.1, 9.9), (10.8, 7.8, 9.6), (0.6, -0.5), 280, {}),
    "plant_flowers_01": ("flower", False, (4.1, 3.0, 3.0), (4.0, 2.8, 3.1), (0.1, -0.2), 90, {"collider": False}),
    "farm_field_wheat_01": ("crop", False, (38.0, 2.4, 28.0), (37.0, 2.3, 27.0), (0.0, 0.0), 1200, {}),
    "farm_haystack_01": ("haystack", False, (7.3, 6.2, 6.2), (7.0, 6.0, 6.4), (0.4, 0.0), 150, {}),
}


def build() -> dict:
    props = {}
    for pid, (family, node, standin, size, (ox, oz), tris, extra) in PROPS.items():
        p = {
            "family": family,
            "bbox_center": [ox, round(size[1] / 2, 4), oz],
            "size": list(size),
            "tris": tris,
            "tint": "fixed",
            "standin_size": list(standin),
            "node": node,
        }
        p.update(extra)
        props[pid] = p
    return {"schema_version": 1, "unit": "stud", "props": props}


def render() -> str:
    return json.dumps(build(), indent=1, sort_keys=True) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    args = ap.parse_args(argv)
    text = render()
    if args.check:
        if not args.out.exists() or args.out.read_text() != text:
            print(f"make_placeholder_env: {args.out} is out of date", file=sys.stderr)
            return 1
        print(f"make_placeholder_env: {args.out} is up to date")
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)
    print(f"make_placeholder_env: wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
