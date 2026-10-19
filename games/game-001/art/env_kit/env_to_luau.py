#!/usr/bin/env python3
"""env_to_luau — turns the Blender env kit's env.json into Kit/EnvMeshData.luau (FL-0136, D-057 (18)-(20), FORGE-02).

Standard library only (Python 3.10+). Deterministic: the same env.json gives the same bytes, so the output can be
committed and diffed. THE one command, from anywhere in the repository, once env.json has landed:

    python3 games/game-001/art/env_kit/env_to_luau.py

reads  games/game-001/art/env_kit/env.json
writes games/game-001/src/shared/Kit/EnvMeshData.luau   (then run the Kit specs: see the end of this docstring)

    --in PATH / --out PATH   other files          --validate-only   check env.json, write nothing (the Blender worker's gate)
    --check                  exit 1 if --out differs from what --in would generate (a drift check)
    --selftest               validator + converter against the placeholder kit and a table of broken kits
    --print-budget           the triangle budget as JSON (the Lune specs compare it with Kit/EnvMesh.BUDGET)
Exit codes: 0 ok, 1 invalid or out of date, 2 usage. Warnings never fail the run; read them.

After converting:  lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json \\
                       --specs games/game-001/tests/world KitEnvMesh
With data committed, the specs also check every id against the world (WorldPlan and Layout place it), the family triangle
budgets, and `standin_size` against the live part-built prop (Kit.prop with no asset source).

ENV.JSON v1 (what Kit/EnvMesh reads; the FL-0136 contract plus the clarifications marked [+])
  { "schema_version": 1, "unit": "stud", "props": { "<assetId>": { ... } } }  Any other top-level key is ignored.
  Axes in studs, Roblox rig axes: +X right, +Y up, -Z front; each prop stands on y = 0 with its pivot at its base centre
  (x = z = 0). The FBX has one mesh object per prop named exactly by the asset id, Y up / -Z forward, 1 unit = 1 stud.
  assetId      the id Kit.prop is called with, lowercase, ending in _NN: tree_oak_03, bush_02, rock_boulder_m_01, resource_ore_04,
               plant_flowers_05, farm_field_wheat_01, farm_haystack_01 ... [+] ids not placed by the world are not rejected here,
               the Kit specs report them.
  family       tree | bush | rock | flower | crop | haystack | fence   (drives the triangle budget and the default collider)
  bbox_center  [x, y, z] centre of the mesh's bounding box, from the base centre
  size         [x, y, z] bounding-box size = the imported MeshPart.Size (the Studio import and the Kit both check it, +/- 0.1)
  tris         integer, 1..20,000 per mesh (Roblox's cap) and within the family budget: tree 300-900, bush/rock/flower 40-400,
               [+] crop 40-1,500, haystack/fence 40-600 (FORGE-02's proposal, the contract is silent)
  tint         "fixed" (colours are baked into the vertex colours; [+] Kit sets MeshPart.Color white)
  standin_size [x, y, z] of the part-built stand-in's drawn bounds (visible parts, pivot frame) from blender/scripts/lune/EnvDump.spec
               or the probe: [+] the mesh must fit it: footprint max(x, z) within 85-115 %, height within 75-125 %; a resource node
               (node: true) footprint within 85-102 % (selection and keep-out use it). A larger deviation needs `fit_note`
               (a non-empty string saying why the role needs it).
  node         true if the id is also used as a resource NODE (Layout.resourceNodes: trees, bushes, rocks, ore and stone)
  collider     [+] optional [w, h, d] of the invisible solid box at the base centre, or false for none. Default by family: tree a trunk
               (20 % of the wider side, 1.4-3.4 studs, up to 7 high), rock and haystack 80 % of each footprint axis (64 % of the area) up to
               7 high, bush 60 % of each axis up to 3 high, fence its length 4 high, flower and crop none. The DEFAULT heights stop at
               7 (WorldService.COLLIDE_HEIGHT); an explicit collider is used as given, and a height over 7 is only warned about.
  fit_note     [+] optional string, see standin_size
  One body mesh per prop (budget: 1 MeshPart), vertex colours only, one material, no textures, no PBR. The Studio import script
  deletes everything but the geometry (scripts, SurfaceAppearance, attributes, tags, children) and Kit.prop does it again.
Kit/EnvMesh.luau is the other half of this contract (header comment); keep them in step.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DEFAULT_IN = HERE / "env.json"
DEFAULT_OUT = ROOT / "games/game-001/src/shared/Kit/EnvMeshData.luau"
PLACEHOLDER = ROOT / "games/game-001/tests/world/fixtures/env_placeholder.env.json"
PLACEHOLDER_LUAU = ROOT / "games/game-001/tests/world/fixtures/EnvMeshFixture.luau"

SCHEMA_VERSION = 1
MAX_MESH_TRIS = 20000
MAX_EXTENT = 80  # studs per axis: a unit mistake shows long before a field (38) or a pine (33) does
FAMILIES = ("tree", "bush", "rock", "flower", "crop", "haystack", "fence")
# THE triangle budget (mirrors EnvMesh.BUDGET in Kit/EnvMesh.luau; a Lune spec compares them through --print-budget)
BUDGET = {
    "tree": {"min": 300, "max": 900},
    "bush": {"min": 40, "max": 400},
    "rock": {"min": 40, "max": 400},
    "flower": {"min": 40, "max": 400},
    "crop": {"min": 40, "max": 1500},
    "haystack": {"min": 40, "max": 600},
    "fence": {"min": 40, "max": 600},
}
ID_RE = re.compile(r"^[a-z]+(?:_[a-z0-9]+)*_\d{2}$")
PREFIX_FAMILIES = (
    ("tree_", ("tree",)),
    ("bush_", ("bush",)),
    ("plant_", ("flower",)),
    ("rock_", ("rock",)),
    ("resource_", ("rock", "tree")),
    ("farm_field_", ("crop",)),
    ("farm_haystack_", ("haystack",)),
    ("farm_fence_", ("fence",)),
)
FOOTPRINT_FIT = (0.85, 1.15)
NODE_FOOTPRINT_FIT = (0.85, 1.02)
HEIGHT_FIT = (0.75, 1.25)
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUAU_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}
PROP_KEYS = ("family", "bbox_center", "size", "tris", "tint", "standin_size", "node", "collider", "fit_note")


# ------------------------------------------------------------------------------------------------ validation
def is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def is_vec(v, positive: bool = False) -> bool:
    return isinstance(v, list) and len(v) == 3 and all(is_num(x) for x in v) and (not positive or all(x > 0 for x in v))


def validate(data) -> tuple[list[str], list[str]]:
    """-> (errors, warnings). An empty error list means Kit/EnvMesh can use every prop of the data."""
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(data, dict):
        return ["env.json must be a JSON object"], warnings
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}, not {data.get('schema_version')!r}")
    if data.get("unit", "stud") != "stud":
        errors.append(f"unit must be 'stud', not {data.get('unit')!r}")
    props = data.get("props")
    if not isinstance(props, dict) or not props:
        errors.append("props must be a non-empty object")
        return errors, warnings
    for pid, p in props.items():
        where = f"props.{pid}"
        if not ID_RE.match(pid):
            errors.append(f"{where}: id must be lowercase, end in _NN and look like tree_oak_03 / rock_boulder_m_01")
        if not isinstance(p, dict):
            errors.append(f"{where}: must be an object")
            continue
        family = p.get("family")
        if family not in FAMILIES:
            errors.append(f"{where}: family {family!r} is not one of {', '.join(FAMILIES)}")
        else:
            for prefix, allowed in PREFIX_FAMILIES:
                if pid.startswith(prefix) and family not in allowed:
                    warnings.append(f"{where}: family {family} is unusual for {prefix}* (expected {' or '.join(allowed)})")
            if not any(pid.startswith(prefix) for prefix, _ in PREFIX_FAMILIES):
                warnings.append(f"{where}: no known id prefix: does the world place it? (the Kit specs report ids it does not)")
        if p.get("tint") != "fixed":
            errors.append(f"{where}: tint must be 'fixed' (vertex colours only), not {p.get('tint')!r}")
        if not isinstance(p.get("node"), bool):
            errors.append(f"{where}: node must be true or false")
        tris = p.get("tris")
        if not isinstance(tris, int) or isinstance(tris, bool) or not 1 <= tris <= MAX_MESH_TRIS:
            errors.append(f"{where}: tris must be an integer 1..{MAX_MESH_TRIS} (Roblox's per-mesh cap), not {tris!r}")
        elif family in BUDGET and not BUDGET[family]["min"] <= tris <= BUDGET[family]["max"]:
            errors.append(f"{where}: {tris} triangles is outside the {family} budget {BUDGET[family]['min']}-{BUDGET[family]['max']}")
        if not is_vec(p.get("size"), positive=True):
            errors.append(f"{where}: size must be three positive numbers")
        if not is_vec(p.get("bbox_center")):
            errors.append(f"{where}: bbox_center must be three finite numbers")
        if not is_vec(p.get("standin_size"), positive=True):
            errors.append(f"{where}: standin_size must be three positive numbers (the part-built prop's drawn bounds)")
        if "collider" in p and p["collider"] is not False and not is_vec(p["collider"], positive=True):
            errors.append(f"{where}: collider must be false or [w, h, d] of three positive numbers")
        if "fit_note" in p and not (isinstance(p["fit_note"], str) and p["fit_note"].strip()):
            errors.append(f"{where}: fit_note must be a non-empty string")
        if not (is_vec(p.get("size"), positive=True) and is_vec(p.get("bbox_center"))):
            continue
        size, center = p["size"], p["bbox_center"]
        if any(s > MAX_EXTENT for s in size):
            errors.append(f"{where}: size {size} has an axis over {MAX_EXTENT} studs (a unit mistake?)")
        bottom = center[1] - size[1] / 2
        if not -1.0 <= bottom <= 0.5:
            errors.append(f"{where}: the base is at y = {bottom:.2f}; a prop stands on y = 0 (pivot at the base centre)")
        elif abs(bottom) > 0.1:
            warnings.append(f"{where}: the base is at y = {bottom:.2f}, not 0")
        if abs(center[0]) > 0.5 * size[0] or abs(center[2]) > 0.5 * size[2]:
            errors.append(f"{where}: bbox_center {center} is far off the base centre for size {size} (is the pivot at the base centre?)")
        if p.get("collider") is not False and is_vec(p.get("collider"), positive=True) and p["collider"][1] > 7:
            warnings.append(f"{where}: collider is {p['collider'][1]} high: over 7 (WorldService.COLLIDE_HEIGHT); the Kit uses an explicit collider as given, only the family defaults stop at 7")
        # fit to the stand-in it replaces
        if is_vec(p.get("standin_size"), positive=True) and "fit_note" not in p:
            ss = p["standin_size"]
            fp_ratio = max(size[0], size[2]) / max(ss[0], ss[2])
            h_ratio = size[1] / ss[1]
            lo, hi = NODE_FOOTPRINT_FIT if p.get("node") is True else FOOTPRINT_FIT
            if not lo <= fp_ratio <= hi:
                errors.append(
                    f"{where}: footprint is {fp_ratio * 100:.0f} % of the stand-in's (allowed {lo * 100:.0f}-{hi * 100:.0f} %"
                    f"{', a resource node' if p.get('node') is True else ''}); fit it or state why in fit_note"
                )
            if not HEIGHT_FIT[0] <= h_ratio <= HEIGHT_FIT[1]:
                errors.append(
                    f"{where}: height is {h_ratio * 100:.0f} % of the stand-in's (allowed {HEIGHT_FIT[0] * 100:.0f}-{HEIGHT_FIT[1] * 100:.0f} %); fit it or state why in fit_note"
                )
    return errors, warnings


# ------------------------------------------------------------------------------------------------ Luau output
def num(x) -> str:
    if isinstance(x, int):
        return str(x)
    x = round(float(x), 6)
    if x == 0:
        return "0"
    if x == int(x) and abs(x) < 1e15:
        return str(int(x))
    return repr(x)


def lua_str(s: str) -> str:
    out = ['"']
    for ch in s:
        if ch in '\\"':
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\n")
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append(f"\\{ord(ch):03d}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def lua_key(k: str) -> str:
    return k if IDENT_RE.match(k) and k not in LUAU_KEYWORDS else f"[{lua_str(k)}]"


def lua_vec(v) -> str:
    return "{ " + ", ".join(num(x) for x in v) + " }"


def prop_lua(p: dict) -> str:
    fields = []
    for key in PROP_KEYS:
        if key not in p:
            continue
        v = p[key]
        if key in ("bbox_center", "size", "standin_size"):
            fields.append(f"{key} = {lua_vec(v)}")
        elif key == "collider":
            fields.append("collider = false" if v is False else f"collider = {lua_vec(v)}")
        elif key == "node":
            fields.append(f"node = {'true' if v else 'false'}")
        elif isinstance(v, str):
            fields.append(f"{key} = {lua_str(v)}")
        else:
            fields.append(f"{key} = {num(v)}")
    return "{ " + ", ".join(fields) + " }"


def to_luau(data: dict, source_name: str, source_bytes: bytes) -> str:
    digest = hashlib.sha256(source_bytes).hexdigest()
    props = data["props"]
    nodes = sum(1 for p in props.values() if p.get("node"))
    lines = [
        "--!strict",
        "--[[",
        "\tKit/EnvMeshData — the imported nature meshes as data (FL-0136, D-057 (18)-(20)). GENERATED, do not edit by hand:",
        "\t\tpython3 games/game-001/art/env_kit/env_to_luau.py",
        f"\tsource {source_name}  sha256 {digest}",
        f"\t{len(props)} props ({nodes} also resource nodes).",
        "\tKit/EnvMesh.luau reads it; Kit.prop uses a Forge.Assets Model for these ids only when it matches, else the stand-in.",
        "]]",
        "",
        "-- stylua: ignore start",
        "return table.freeze({",
        f"\tschema_version = {SCHEMA_VERSION},",
        '\tunit = "stud",',
        "\tprops = {",
    ]
    for pid in sorted(props):
        lines.append(f"\t\t{lua_key(pid)} = {prop_lua(props[pid])},")
    lines += ["\t},", "})", "-- stylua: ignore end", ""]
    return "\n".join(lines)


def load_json(text: str):
    def bad(c):
        raise ValueError(f"non-finite number {c} in env.json")

    return json.loads(text, parse_constant=bad)


def shown_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return path.name


def convert(path: Path) -> tuple[str | None, list[str], list[str]]:
    raw = path.read_bytes()
    try:
        data = load_json(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError) as e:
        return None, [f"{path}: {e}"], []
    errors, warnings = validate(data)
    if errors:
        return None, errors, warnings
    return to_luau(data, shown_path(path), raw), errors, warnings


# ------------------------------------------------------------------------------------------------ self-test
def broken_kits(good: dict):
    """(name, mutate(data) or raw text, substring the errors must contain)."""

    def m(fn):
        def apply(d):
            d = copy.deepcopy(d)
            fn(d)
            return d

        return apply

    some = next(iter(good["props"]))
    oak = "tree_oak_01"
    return [
        ("schema 2", m(lambda d: d.update(schema_version=2)), "schema_version"),
        ("unit", m(lambda d: d.update(unit="m")), "unit must be"),
        ("empty", m(lambda d: d.update(props={})), "non-empty"),
        ("bad id", m(lambda d: d["props"].update({"Tree-Oak": copy.deepcopy(d["props"][some])})), "lowercase"),
        ("id without _NN", m(lambda d: d["props"].update({"tree_oak": copy.deepcopy(d["props"][some])})), "lowercase"),
        ("bad family", m(lambda d: d["props"][oak].update(family="shrub")), "family 'shrub'"),
        ("tint kingdom", m(lambda d: d["props"][oak].update(tint="kingdom")), "tint must be 'fixed'"),
        ("node missing", m(lambda d: d["props"][oak].pop("node")), "node must be"),
        ("mesh too big", m(lambda d: d["props"][oak].update(tris=20001)), "tris must be"),
        ("tree over budget", m(lambda d: d["props"][oak].update(tris=901)), "outside the tree budget"),
        ("tree under budget", m(lambda d: d["props"][oak].update(tris=299)), "outside the tree budget"),
        ("bush over budget", m(lambda d: d["props"]["bush_01"].update(tris=401)), "outside the bush budget"),
        ("zero size", m(lambda d: d["props"][oak].update(size=[0, 20, 20])), "size must be"),
        ("unit mistake", m(lambda d: d["props"][oak].update(size=[1900, 2400, 2000])), "over 80 studs"),
        ("floating", m(lambda d: d["props"][oak].update(bbox_center=[0, 30, 0])), "stands on y = 0"),
        ("sunk", m(lambda d: d["props"][oak].update(bbox_center=[0, 0, 0])), "stands on y = 0"),
        ("pivot not at the base centre", m(lambda d: d["props"][oak].update(bbox_center=[40, 12, 0])), "base centre"),
        ("no stand-in size", m(lambda d: d["props"][oak].pop("standin_size")), "standin_size"),
        ("too fat", m(lambda d: d["props"][oak].update(size=[30, 24, 30], bbox_center=[0, 12, 0])), "footprint is"),
        ("too tall", m(lambda d: d["props"][oak].update(size=[17, 40, 17], bbox_center=[0, 20, 0])), "height is"),
        ("too thin", m(lambda d: d["props"][oak].update(size=[8, 24, 8], bbox_center=[0, 12, 0])), "footprint is"),
        ("node wider than its stand-in", m(lambda d: d["props"]["resource_stone_01"].update(size=[17.5, 7.5, 10.5], bbox_center=[0, 3.75, 0])), "a resource node"),
        ("bad collider", m(lambda d: d["props"][oak].update(collider=[1, 2])), "collider must be"),
        ("empty fit_note", m(lambda d: d["props"][oak].update(fit_note=" ")), "fit_note must be"),
        ("not json numbers", '{"schema_version": NaN}', "non-finite"),
    ]


def selftest() -> int:
    failures: list[str] = []

    def check(ok: bool, what: str):
        print(("  ok    " if ok else "  FAIL  ") + what)
        if not ok:
            failures.append(what)

    if not PLACEHOLDER.exists():
        print(f"selftest: {PLACEHOLDER} is missing (run make_placeholder_env.py)")
        return 1
    raw = PLACEHOLDER.read_bytes()
    good = load_json(raw.decode())
    errors, warnings = validate(good)
    check(not errors, f"the placeholder kit validates ({len(errors)} errors)" + "".join(f"\n        {e}" for e in errors[:5]))
    text_a = to_luau(good, shown_path(PLACEHOLDER), raw)
    check(text_a == to_luau(load_json(raw.decode()), shown_path(PLACEHOLDER), raw), "conversion is deterministic")
    check(text_a.count("{") == text_a.count("}"), "braces balance in the generated Luau")
    check(not re.search(r"\b(nan|inf)\b", text_a), "no nan or inf in the generated Luau")
    check(PLACEHOLDER_LUAU.exists() and PLACEHOLDER_LUAU.read_text() == text_a, f"{PLACEHOLDER_LUAU.name} is what the converter makes of the placeholder")
    shuffled = {**good, "props": dict(reversed(list(good["props"].items())))}
    check(to_luau(shuffled, shown_path(PLACEHOLDER), raw) == text_a, "key order in env.json does not change the output")
    check(num(3.0) == "3" and num(-0.0) == "0" and num(4.64) == "4.64", "numbers print short")
    check(lua_str('a"b\\c') == '"a\\"b\\\\c"' and lua_key("end") == '["end"]' and lua_key("tree_oak_01") == "tree_oak_01", "strings and keys escape")
    check(any(p.get("fit_note") for p in good["props"].values()), "the placeholder exercises fit_note")
    check(any(p.get("collider") is False for p in good["props"].values()) and any(isinstance(p.get("collider"), list) for p in good["props"].values()), "the placeholder exercises both collider forms")
    for name, mutate, expect in broken_kits(good):
        if isinstance(mutate, str):
            try:
                load_json(mutate)
                check(False, f"broken kit '{name}' was accepted")
            except ValueError as e:
                check(expect in str(e), f"broken kit '{name}' -> {e}")
            continue
        errs, _ = validate(mutate(good))
        check(any(expect in e for e in errs), f"broken kit '{name}' -> " + (errs[0] if errs else "ACCEPTED"))

    def warns(mutate, expect: str) -> bool:
        errs, warn = validate(mutate(copy.deepcopy(good)))
        return not errs and any(expect in w for w in warn)

    def unknown_prefix(d):
        d["props"]["thing_odd_01"] = copy.deepcopy(d["props"]["rock_boulder_m_01"])
        return d

    def family_mismatch(d):
        d["props"]["rock_boulder_m_01"]["family"] = "bush"
        d["props"]["rock_boulder_m_01"]["tris"] = 100
        return d

    def a_bit_low(d):
        d["props"]["bush_01"]["bbox_center"][1] += 0.3
        return d

    def tall_collider(d):
        d["props"]["tree_oak_01"]["collider"] = [2, 9, 2]
        return d

    check(warns(unknown_prefix, "no known id prefix"), "an id with an unknown prefix is warned about")
    check(warns(family_mismatch, "unusual for rock_"), "a family that does not match the id prefix is warned about")
    check(warns(a_bit_low, "not 0"), "a base 0.1-0.5 off the ground is warned about")
    check(warns(tall_collider, "over 7"), "a collider taller than 7 is warned about")
    check(BUDGET["tree"] == {"min": 300, "max": 900} and BUDGET["bush"] == {"min": 40, "max": 400}, "the budget constants are the contract's")
    print(f"selftest: {'FAIL' if failures else 'PASS'} ({len(failures)} failure(s))")
    return 1 if failures else 0


# ------------------------------------------------------------------------------------------------ CLI
def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="env.json -> Kit/EnvMeshData.luau (FL-0136)")
    ap.add_argument("--in", dest="src", type=Path, default=DEFAULT_IN)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--validate-only", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--print-budget", action="store_true")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if args.print_budget:
        print(json.dumps({"families": list(FAMILIES), "budget": BUDGET, "max_mesh_tris": MAX_MESH_TRIS}, sort_keys=True))
        return 0
    if not args.src.exists():
        print(f"env_to_luau: {args.src} does not exist yet (the Blender worker writes it)", file=sys.stderr)
        return 1
    text, errors, warnings = convert(args.src)
    for w in warnings:
        print(f"warning: {w}")
    if text is None:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"env_to_luau: {args.src} is invalid ({len(errors)} error(s)); nothing written", file=sys.stderr)
        return 1
    if args.validate_only:
        print(f"env_to_luau: {args.src} is valid ({len(warnings)} warning(s))")
        return 0
    if args.check:
        if not args.out.exists() or args.out.read_text() != text:
            print(f"env_to_luau: {args.out} is out of date: run python3 games/game-001/art/env_kit/env_to_luau.py", file=sys.stderr)
            return 1
        print(f"env_to_luau: {args.out} is up to date")
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)
    print(f"env_to_luau: wrote {args.out} ({len(text.splitlines())} lines, {len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
