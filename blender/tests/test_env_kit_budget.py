"""FL-0136 phase 2: the environment kit's numbers are MEASURED from the committed FBX (the way FORGE-07's gate does it for the citizen kit).

Pure Python for the gate (lib/fbxtris.py reads the FBX bytes, lib/manifest.env_budget_errors / env_kit_errors compare them with env.json and the
row); the last tests need Blender (the generator is rebuilt and the shipped FBX is imported). Each mutant below is a copy of the real data that the
check must catch."""

import copy
import json
import shutil
import sys
from pathlib import Path

import pytest

BLENDER = Path(__file__).resolve().parent.parent
REPO = BLENDER.parent
sys.path.insert(0, str(BLENDER))

from lib import fbxtris, manifest  # noqa: E402

FBX = REPO / "games/game-001/art/env_kit/env_kit.fbx"
ENV = REPO / "games/game-001/art/env_kit/env.json"
STANDINS = BLENDER / "lib/envkit_standins.json"
pytestmark = pytest.mark.skipif(not (FBX.exists() and ENV.exists()), reason="env kit files not committed")


@pytest.fixture(scope="module")
def real():
    return json.loads(ENV.read_text()), fbxtris.measure(FBX), fbxtris.measure_bounds(FBX)


def mutant(real, **tris):
    """A copy where the named props have `tris` replaced in BOTH the declaration and the measurement (so only the budget is wrong)."""
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    for k, v in tris.items():
        doc["props"][k]["tris"] = v
        measured[k] = v
    return doc, measured


def test_the_fbx_reader_agrees_with_env_json(real):
    doc, measured, bounds = real
    assert set(doc["props"]) == set(measured)
    assert all(doc["props"][k]["tris"] == n for k, n in measured.items())
    assert sum(measured.values()) > 20000
    for k, ((x0, y0, z0), (x1, y1, z1)) in bounds.items():
        size = [x1 - x0, z1 - z0, y1 - y0]  # Blender object space (z up) -> rig axes
        assert max(abs(a - b) for a, b in zip(size, doc["props"][k]["size"])) < 0.02, k


def test_the_committed_kit_is_inside_every_budget(real):
    assert manifest.env_budget_errors(real[0], real[1], real[2]) == []


@pytest.mark.parametrize("pid,tris,fragment", [
    ("tree_oak_01", 901, "outside the tree budget 300..900"),
    ("tree_oak_01", 299, "outside the tree budget 300..900"),
    ("bush_01", 401, "outside the bush budget 40..400"),
    ("rock_boulder_l_01", 401, "outside the rock budget 40..400"),
    ("plant_flowers_01", 401, "outside the flower budget 40..400"),
    ("resource_ore_03", 501, "outside the node budget 40..500"),
    ("farm_field_wheat_01", 3001, "outside the crop budget 200..3000"),
    ("farm_fence_01", 401, "outside the prop budget 40..400"),
    ("farm_field_wheat_01", 20001, "outside 1..20000"),
])
def test_mutant_a_mesh_over_or_under_its_family_budget_fails(real, pid, tris, fragment):
    doc, measured = mutant(real, **{pid: tris})
    errs = manifest.env_budget_errors(doc, measured)
    assert any(pid in e and fragment in e for e in errs), errs


def test_mutant_a_declared_count_that_differs_from_the_measurement_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["props"]["tree_oak_01"]["tris"] = measured["tree_oak_01"] - 1
    errs = manifest.env_budget_errors(doc, measured)
    assert any("tree_oak_01" in e and "declares" in e and f"the FBX has {measured['tree_oak_01']}" in e for e in errs), errs


def test_mutant_a_prop_missing_from_the_fbx_or_extra_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    del measured["bush_01"]
    measured["stowaway"] = 12
    errs = manifest.env_budget_errors(doc, measured)
    assert any("bush_01 is in env.json but not in the FBX" in e for e in errs) and any("stowaway" in e for e in errs), errs


def test_mutant_an_unknown_family_and_a_bad_id_fail(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["props"]["tree_oak_01"]["family"] = "castle"
    errs = manifest.env_budget_errors(doc, measured)
    assert any("unknown family" in e for e in errs), errs
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["props"]["Tree Oak"] = doc["props"].pop("tree_oak_01")
    measured["Tree Oak"] = measured.pop("tree_oak_01")
    assert any("not a valid asset id" in e for e in manifest.env_budget_errors(doc, measured)), "id shape"


def test_mutant_the_fit_window_is_enforced_unless_a_reason_is_given(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    p = doc["props"]["tree_oak_01"]
    p["fit"] = dict(p["fit"], radius_ratio=1.31)
    assert any("tree_oak_01" in e and "footprint radius" in e and "no fit_note" in e for e in manifest.env_budget_errors(doc, measured))
    p["fit"] = dict(p["fit"], radius_ratio=1.0, height_ratio=1.4)
    assert any("tree_oak_01" in e and "height" in e and "no fit_note" in e for e in manifest.env_budget_errors(doc, measured))
    p["fit_note"] = "a reason"
    assert not any("tree_oak_01" in e and "fit_note" in e for e in manifest.env_budget_errors(doc, measured))


def test_mutant_a_prop_sunk_far_below_the_ground_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["props"]["rock_boulder_s_01"]["base_y"] = -1.2
    assert any("rock_boulder_s_01" in e and "sinks" in e for e in manifest.env_budget_errors(doc, measured))


def test_mutant_a_declared_box_that_is_not_the_meshs_fails(real):
    doc, measured, bounds = copy.deepcopy(real[0]), dict(real[1]), real[2]
    doc["props"]["tree_pine_01"]["size"][1] += 1.0
    errs = manifest.env_budget_errors(doc, measured, bounds)
    assert any("tree_pine_01" in e and "differs from the FBX vertices" in e for e in errs), errs


def _row(tmp_path, doc, fbx_bytes=None):
    fbx = tmp_path / "env_kit.fbx"
    if fbx_bytes is None:
        shutil.copy(FBX, fbx)
    else:
        fbx.write_bytes(fbx_bytes)
    import hashlib

    sha = hashlib.sha256(fbx.read_bytes()).hexdigest()
    doc = copy.deepcopy(doc)
    doc["fbx_sha256"] = sha
    (tmp_path / "env.json").write_text(json.dumps(doc))
    measured = fbxtris.measure(fbx)
    row = {"id": "env_kit_01", "files": {"mesh_committed": "env_kit.fbx", "env": "env.json"},
           "kit": {"props": len(measured), "total_tris": sum(measured.values()), "max_mesh_tris": max(measured.values()), "fbx_sha256": sha}}
    return row


def test_end_to_end_row_check_passes_on_the_real_files(tmp_path, real):
    assert manifest.env_kit_errors(_row(tmp_path, real[0]), repo=tmp_path) == []


def test_end_to_end_row_check_catches_a_tampered_env_json(tmp_path, real):
    doc = copy.deepcopy(real[0])
    doc["props"]["tool_hammer" if False else "bush_02"]["tris"] -= 3
    errs = manifest.env_kit_errors(_row(tmp_path, doc), repo=tmp_path)
    assert any("bush_02" in e and "declares" in e for e in errs), errs


def test_end_to_end_row_check_catches_a_personal_path_in_the_fbx(tmp_path, real):
    raw = FBX.read_bytes()
    assert b"/foobar.fbx" in raw  # Blender's own placeholder: no real path is ever written
    evil = raw.replace(b"/foobar.fbx", b"/tmp/ab.fbx", 1)  # same length: the node offsets stay valid
    errs = manifest.env_kit_errors(_row(tmp_path, real[0], evil), repo=tmp_path)
    assert any("path-like string" in e for e in errs), errs
    evil = raw.replace(b"/foobar.fbx", b"C:\\xx\\a.fbx", 1)
    errs = manifest.env_kit_errors(_row(tmp_path, real[0], evil), repo=tmp_path)
    assert any("path-like string" in e for e in errs), errs


def test_end_to_end_row_check_catches_a_stale_sha(tmp_path, real):
    row = _row(tmp_path, real[0])
    row["kit"]["fbx_sha256"] = "0" * 64
    errs = manifest.env_kit_errors(row, repo=tmp_path)
    assert any("kit.fbx_sha256" in e for e in errs), errs
    row = _row(tmp_path, real[0])
    doc = json.loads((tmp_path / "env.json").read_text())
    doc["fbx_sha256"] = "1" * 64
    (tmp_path / "env.json").write_text(json.dumps(doc))
    assert any("env.json fbx_sha256" in e for e in manifest.env_kit_errors(row, repo=tmp_path))


def test_end_to_end_row_check_catches_a_wrong_row_summary(tmp_path, real):
    row = _row(tmp_path, real[0])
    row["kit"]["total_tris"] += 1
    assert any("kit.total_tris" in e for e in manifest.env_kit_errors(row, repo=tmp_path))
    row = _row(tmp_path, real[0])
    row["kit"]["max_mesh_tris"] -= 1
    assert any("kit.max_mesh_tris" in e for e in manifest.env_kit_errors(row, repo=tmp_path))


def test_end_to_end_row_check_reads_a_broken_fbx_as_an_error(tmp_path, real):
    errs = manifest.env_kit_errors(_row(tmp_path, real[0], b"not an fbx"), repo=tmp_path) if False else None
    row = {"id": "env_kit_01", "files": {"mesh_committed": "env_kit.fbx", "env": "env.json"}, "kit": {}}
    (tmp_path / "env_kit.fbx").write_bytes(b"not an fbx")
    (tmp_path / "env.json").write_text(json.dumps(real[0]))
    errs = manifest.env_kit_errors(row, repo=tmp_path)
    assert errs and "cannot read the FBX" in errs[0]


def test_the_real_manifest_check_includes_the_env_kit_measurement():
    assert [e for e in manifest.check() if "env_kit" in e] == []


def test_every_nature_and_crop_id_the_world_places_has_a_mesh(real):
    """The inventory (blender/lib/envkit_standins.json, from the real WorldService run) lists every id the world places; each in-scope one exists in the kit."""
    st = json.loads(STANDINS.read_text())["standins"]
    scope = ("tree_", "bush_", "plant_flowers_", "rock_", "resource_", "farm_field_", "farm_haystack_")
    placed = [k for k, v in st.items() if k.startswith(scope) and v["placed"]]
    assert len(placed) >= 40
    missing = [k for k in placed if k not in real[0]["props"]]
    assert missing == []
    # the world's resource nodes are marked as nodes in the kit (K sets collision / selection from them)
    for k, v in st.items():
        if v["node"] and k in real[0]["props"]:
            assert real[0]["props"][k]["node"] is True, k


def test_the_world_ids_and_variant_ranges_are_complete():
    """WorldPlan draws oak 1..8, pine 1..6, birch 1..6, bush 1..8, flowers 1..6, boulders s/m/l 1..3 and wheat 1 + i % 3 (1..3): all present."""
    doc = json.loads(ENV.read_text())["props"]
    want = ([f"tree_oak_{i:02d}" for i in range(1, 9)] + [f"tree_pine_{i:02d}" for i in range(1, 7)] + [f"tree_birch_{i:02d}" for i in range(1, 7)]
            + [f"bush_{i:02d}" for i in range(1, 9)] + [f"plant_flowers_{i:02d}" for i in range(1, 7)]
            + [f"rock_boulder_{s}_{i:02d}" for s in "sml" for i in range(1, 4)] + [f"resource_stone_{i:02d}" for i in range(1, 4)]
            + [f"resource_ore_{i:02d}" for i in range(1, 7)] + [f"farm_field_wheat_{i:02d}" for i in range(1, 4)] + ["farm_field_cabbage_03", "farm_haystack_01"])
    assert [k for k in want if k not in doc] == []


# ---- needs Blender

def test_the_generator_is_deterministic_and_matches_the_committed_hash():
    bpy = pytest.importorskip("bpy")  # noqa: F841
    from generators import env_kit
    from lib import envkit_build

    a = envkit_build.canon_hash(env_kit.registry())
    b = envkit_build.canon_hash(env_kit.registry())
    assert a == b
    assert a == json.loads(ENV.read_text())["geometry_hash"], "the committed FBX is out of date: rebuild with build.py --generator env_kit"


def test_a_floating_part_is_refused():
    pytest.importorskip("bpy")
    from generators import _envkit_style as S

    near = S.box(2, 2, 2, color=S.WOOD).move(0, 1, 0)
    far = S.box(1, 1, 1, color=S.WOOD).move(0, 9, 0)
    with pytest.raises(AssertionError, match="floating"):
        S.assemble([near, far], "mutant")
    S.assemble([near, S.box(1, 1, 1, color=S.WOOD).move(0, 2.4, 0)], "ok")


def test_the_shipped_fbx_imports_with_one_material_and_vertex_colours():
    bpy = pytest.importorskip("bpy")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(FBX), axis_forward="-Z", axis_up="Y", global_scale=1.0)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    doc = json.loads(ENV.read_text())["props"]
    assert {o.name for o in objs} == set(doc)
    for o in objs:
        assert len(o.data.color_attributes) >= 1, o.name
        assert len(o.data.materials) <= 1, o.name
        assert len(o.data.uv_layers) == 0, f"{o.name} carries UVs (a texture-less kit needs none)"


def test_the_shipped_env_kit_names_no_home_directory_user_or_machine():
    """Like FORGE-07 A6 for the citizen kit: the FBX bytes, env.json and the manifest rows carry no personal path, user name or address."""
    blob = FBX.read_bytes()
    for needle in (b"/home/", b"/root", b"/tmp", b"C:\\Users", b"sammy", b"outlook", b"claude"):
        assert needle not in blob, needle
    for f in (ENV, manifest.MANIFEST, manifest.FRAG_DIR / "env_kit.json"):
        text = f.read_text()
        for needle in ("/home/", "/root", "/tmp/", "C:\\Users", "sammy", "outlook"):
            assert needle not in text, (f.name, needle)
