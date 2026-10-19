"""FORGE-07: the character kit's triangle budget is MEASURED from the committed FBX and fails check() when exceeded.

Pure Python (no Blender): lib/fbxtris.py reads the FBX bytes; lib/manifest.kit_budget_errors / kit_errors compare them with rig.json
and the row's own summary. Each test below is a mutant of the real data that the check must catch."""

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

FBX = REPO / "games/game-001/art/char_kit/citizen_kit.fbx"
RIG = REPO / "games/game-001/art/char_kit/rig.json"
pytestmark = pytest.mark.skipif(not (FBX.exists() and RIG.exists()), reason="kit files not committed")
LOOKS = manifest.kit_looks(sample=72)


@pytest.fixture(scope="module")
def real():
    return json.loads(RIG.read_text()), fbxtris.measure(FBX)


def mutant(real, **bumps):
    """A copy where the named pieces have `tris` replaced in BOTH the declaration and the measurement (so only the budget is wrong)."""
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    for k, v in bumps.items():
        doc["pieces"][k]["tris"] = v
        measured[k] = v
    return doc, measured


def test_the_fbx_reader_agrees_with_rig_json(real):
    doc, measured = real
    assert {k for k, v in doc["pieces"].items() if not v.get("empty")} == set(measured)
    assert all(doc["pieces"][k]["tris"] == n for k, n in measured.items())
    assert sum(measured.values()) > 5000


def test_the_committed_kit_is_inside_every_budget(real):
    assert manifest.kit_budget_errors(real[0], real[1], looks=LOOKS) == []


def test_mutant_a_citizen_over_1000_triangles_fails(real):
    doc, measured = mutant(real, torso_smock=700)  # healer: the rest of the rig is about 600
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any(e.startswith("healer:") and "over the citizen budget 1000" in e for e in errs), errs


def test_mutant_a_citizen_body_over_900_fails(real):
    doc, measured = mutant(real, torso_smock=620)  # total stays under 1000, the body does not
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any(e.startswith("healer:") and "body" in e and "over 900" in e for e in errs), errs


def test_mutant_a_hand_tool_over_150_fails(real):
    doc, measured = mutant(real, tool_hoe=151)
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any(e.startswith("farmer:") and "tool 151" in e and "over 150" in e for e in errs), errs


def test_mutant_a_soldier_over_1500_fails(real):
    doc, measured = mutant(real, tool_spear=900)
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any(e.startswith("soldier:") and "over the 1500 budget" in e for e in errs), errs


def test_mutant_a_mesh_over_20000_fails(real):
    doc, measured = mutant(real, hat_straw=20001)
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any("hat_straw" in e and "outside 1..20000" in e for e in errs), errs


def test_mutant_17_pieces_in_one_rig_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["assemblies"]["farmer"]["extras"] += ["apron_smith", "satchel_herb"]
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any(e.startswith("farmer:") and "pieces over 16" in e for e in errs), errs


def test_mutant_a_declared_count_lower_than_measured_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    doc["pieces"]["hat_straw"]["tris"] = measured["hat_straw"] - 1
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any("hat_straw" in e and "declares" in e and f"the FBX has {measured['hat_straw']}" in e for e in errs), errs


def test_mutant_a_piece_missing_from_the_fbx_or_extra_fails(real):
    doc, measured = copy.deepcopy(real[0]), dict(real[1])
    del measured["hat_straw"]
    measured["stowaway"] = 12
    errs = manifest.kit_budget_errors(doc, measured, looks=LOOKS)
    assert any("hat_straw is in rig.json but not in the FBX" in e for e in errs) and any("stowaway" in e for e in errs), errs


def test_end_to_end_row_check_catches_a_tampered_rig_json(tmp_path, real):
    """kit_errors(): measure the FBX file, compare with the rig.json file the row names (here a tampered copy)."""
    shutil.copy(FBX, tmp_path / "citizen_kit.fbx")
    doc = copy.deepcopy(real[0])
    row = {"id": "char_kit_01", "files": {"mesh_committed": "citizen_kit.fbx", "rig": "rig.json"},
           "kit": {"total_piece_tris": sum(real[1].values()), "jobs": {}}}
    (tmp_path / "rig.json").write_text(json.dumps(doc))
    clean = manifest.kit_errors(row, repo=tmp_path)
    assert all("tris_max" in e for e in clean), clean  # only the (here empty) jobs summary differs
    doc["pieces"]["tool_hammer"]["tris"] -= 3
    (tmp_path / "rig.json").write_text(json.dumps(doc))
    errs = manifest.kit_errors(row, repo=tmp_path)
    assert any("tool_hammer" in e and "declares" in e for e in errs), errs


def test_end_to_end_row_check_reads_a_broken_fbx_as_an_error(tmp_path):
    (tmp_path / "citizen_kit.fbx").write_bytes(b"not an fbx")
    shutil.copy(RIG, tmp_path / "rig.json")
    row = {"id": "char_kit_01", "files": {"mesh_committed": "citizen_kit.fbx", "rig": "rig.json"}, "kit": {}}
    errs = manifest.kit_errors(row, repo=tmp_path)
    assert errs and "cannot read the FBX" in errs[0]


def test_the_real_manifest_check_includes_the_measurement():
    assert [e for e in manifest.check() if "char_kit" in e] == []


def test_rig_json_passes_the_runtime_converters_validator():
    """The Kit runtime (games/game-001/art/char_kit/rig_to_luau.py, FL-0135 runtime worker) is the other half of the contract."""
    import subprocess

    conv = REPO / "games/game-001/art/char_kit/rig_to_luau.py"
    if not conv.exists():
        pytest.skip("rig_to_luau.py not on this branch")
    r = subprocess.run([sys.executable, str(conv), "--in", str(RIG), "--validate-only"], capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "0 warning(s)" in r.stderr + r.stdout, r.stdout + r.stderr
