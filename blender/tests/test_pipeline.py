"""FORGE-02 pipeline tests. Pure-Python tests always run; bpy tests are skipped without bpy.

Run: ~/forge-bpy/bin/python -m pytest -q blender/tests   (or plain python3 for the pure subset)
"""

import copy
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

BLENDER = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BLENDER))

import build  # noqa: E402
from lib import coords, manifest, palette, schema  # noqa: E402

try:
    import bpy  # noqa: F401

    HAVE_BPY = True
except ImportError:
    HAVE_BPY = False

needs_bpy = pytest.mark.skipif(not HAVE_BPY, reason="bpy not available")
ID_RE = re.compile(r"^[a-z]+(_[a-z0-9]+)+_\d{2}$")


# ------------------------------------------------------------------ CLI / desktop Blender form

def test_parse_args_blender_style():
    a = build.parse_args(["blender", "-b", "-P", "blender/build.py", "--", "--generator", "house_cottage",
                          "--variants", "3", "--seed", "11", "--quick"])
    assert a.generator == ["house_cottage"] and a.variants == 3 and a.seed == 11 and a.quick


def test_parse_args_python_style():
    a = build.parse_args(["build.py", "--all", "--no-render"])
    assert a.all and a.no_render and a.generator is None


def _run_as_blender_would(tmp_path, extra):
    """`blender -b -P <abs path>/build.py -- ...` from an unrelated cwd: Blender sets sys.argv like
    this and executes the file as __main__ without adding its folder to sys.path."""
    script = BLENDER / "build.py"
    code = ("import sys, runpy; sys.path = [p for p in sys.path if 'blender' not in p.split('/')[-1:]]; "
            f"sys.argv = ['blender', '-b', '-P', {str(script)!r}, '--'] + {extra!r}; "
            f"runpy.run_path({str(script)!r}, run_name='__main__')")
    return subprocess.run([sys.executable, "-c", code], cwd=tmp_path, capture_output=True, text=True, timeout=120)


def test_blender_P_form_lists_generators(tmp_path):
    r = _run_as_blender_would(tmp_path, ["--list"])
    assert r.returncode == 0, r.stderr
    assert "house_cottage" in r.stdout.split()


def test_blender_P_form_rejects_unknown_generator(tmp_path):
    r = _run_as_blender_would(tmp_path, ["--generator", "no_such_generator"])
    assert r.returncode != 0
    assert "unknown generator" in r.stdout


# ------------------------------------------------------------------ palette

def test_palette_names_unique_and_fit():
    assert len(palette.NAMES) == len(set(palette.NAMES))
    assert len(palette.NAMES) <= palette.GRID * palette.GRID
    assert palette.SIZE <= 512


def test_palette_uv_round_trip():
    for name in palette.NAMES:
        for u01, v01 in ((0, 0), (0.5, 0.5), (1, 1)):
            u, v = palette.swatch_uv(name, u01, v01)
            assert 0 <= u <= 1 and 0 <= v <= 1
            assert palette.swatch_at_uv(u, v) == name


def test_kingdom_roles_complete():
    for k in palette.KINGDOMS:
        for role in palette.KINGDOM_ROLES:
            assert palette.kingdom_color(k, role) in palette.INDEX
    with pytest.raises(ValueError):
        palette.kingdom_color("purple", "roof")


def test_palette_is_append_only_for_v1_prefix():
    # the first 160 entries (rows 0-9) shipped in palette v1; their positions must never change
    assert palette.NAMES[0] == "leaf_dark" and palette.NAMES[159] == "ember"
    assert palette.INDEX["plaster"] == 42 and palette.INDEX["red_roof"] == 81


# ------------------------------------------------------------------ coordinates

def test_blender_to_roblox_mapping():
    assert coords.blender_to_roblox((1, 0, 0)) == (-1, 0, 0)
    assert coords.blender_to_roblox((0, 0, 1)) == (0, 1, 0)  # up stays up
    assert coords.blender_to_roblox((0, -1, 0)) == (0, 0, -1)  # front (-Y) -> Roblox front (-Z)
    assert coords.size_to_roblox((2, 3, 4)) == (2, 4, 3)


@needs_bpy
def test_mapping_matches_fbx_exporter_axis_conversion():
    from bpy_extras.io_utils import axis_conversion
    from mathutils import Vector

    m = axis_conversion(to_forward="Z", to_up="Y")
    for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1), (0.3, -2.0, 5.0)):
        got = tuple(round(c, 6) for c in m @ Vector(v))
        assert got == tuple(round(c, 6) for c in coords.blender_to_roblox(v))


# ------------------------------------------------------------------ budgets, schema, manifest

def test_budgets_sane():
    b = json.loads((BLENDER / "budgets.json").read_text())
    assert b["roblox_max_tris"] == 20000 and b["max_texture_px"] <= 512 and b["max_materials"] == 1
    for cls, tris in b["classes"].items():
        assert isinstance(tris, int) and 0 < tris <= b["roblox_max_tris"], cls


def test_committed_manifest_valid():
    errs = manifest.check()
    assert errs == [], errs


def test_manifest_is_merge_of_fragments():
    data = json.loads(manifest.MANIFEST.read_text())
    frag_ids = sorted(e["id"] for f in manifest.fragments() for e in f["assets"])
    assert [a["id"] for a in data["assets"]] == frag_ids


def test_schema_rejects_bad_entries():
    data = json.loads(manifest.MANIFEST.read_text())
    sch = json.loads(manifest.SCHEMA.read_text())
    assert schema.validate(data, sch) == []
    bad = copy.deepcopy(data)
    a = bad["assets"][0]
    a["id"] = "Bad-Id"
    a["triangles"]["lod0"] = 25000
    del a["collision"]
    a["unexpected"] = 1
    errs = schema.validate(bad, sch)
    joined = "\n".join(errs)
    assert "does not match" in joined and "maximum 20000" in joined
    assert "missing required 'collision'" in joined and "unexpected property 'unexpected'" in joined


def test_asset_ids_and_categories():
    data = json.loads(manifest.MANIFEST.read_text())
    assert data["assets"], "manifest is empty"
    for a in data["assets"]:
        assert ID_RE.match(a["id"]), a["id"]
        assert a["id"].startswith(a["category"] + "_")


def test_committed_images_under_250kb():
    for p in list((BLENDER / "previews").rglob("*")) + list((BLENDER / "reviews").rglob("*")):
        if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            assert p.stat().st_size <= 250_000, f"{p} is {p.stat().st_size} bytes"


def test_generators_define_contract():
    for name in build.list_generators():
        src = (BLENDER / "generators" / f"{name}.py").read_text()
        for field in ("NAME =", "VERSION =", "CATEGORY =", "BUDGET =", "def variants(", "def build("):
            assert field in src, f"{name} lacks {field}"
        assert f'NAME = "{name}"' in src, f"{name}: NAME must equal the file name"


# ------------------------------------------------------------------ geometry (bpy)

@needs_bpy
def test_cottage_builds_valid_and_deterministic():
    import importlib

    from lib import asset, rig, validate

    gen = importlib.import_module("generators.house_cottage")
    rig.reset_scene()
    p = gen.variants(2, 7)[1]
    hashes = []
    for _ in range(2):
        b = asset.Builder("house_cottage_02", p["seed"])
        gen.build(b, p)
        ob = b.finalize()
        hashes.append(build.geometry_hash(ob))
    rep = validate.validate(ob, 10, gen.BUDGET, b.stats, gen.CHECKS)
    assert rep["pass"], [c for c in rep["checks"] if not c["pass"]]
    assert hashes[0] == hashes[1]


@needs_bpy
def test_validation_fails_on_budget_breach_and_open_geometry():
    import bmesh

    from lib import asset, rig, validate
    from lib.geo import box

    rig.reset_scene()
    b = asset.Builder("prop_test_01", 1)
    b.add(box(2, 2, 2, "wood"))
    ob = b.finalize()
    rep = validate.validate(ob, 4, "prop_small")
    assert rep["pass"]
    # same mesh against an impossible budget -> fail
    validate.BUDGETS["classes"]["_tiny"] = 4
    try:
        assert not validate.validate(ob, 4, "_tiny")["pass"]
    finally:
        del validate.BUDGETS["classes"]["_tiny"]
    # delete one face -> open shell -> fail
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[0]], context="FACES_ONLY")
    bm.to_mesh(ob.data)
    bm.free()
    rep = validate.validate(ob, 4, "prop_small")
    assert not rep["pass"]
    assert any(c["check"].startswith("closed shells") and not c["pass"] for c in rep["checks"])
