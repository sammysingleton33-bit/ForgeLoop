"""Provenance rule of manifest.check (FORGE-07 A1/A4, D-057 (13)-(14)): every row names its licence; a third-party CC0 row
also carries source URL, pinned commit or date, source sha256 and the committed licence text."""

import copy
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BLENDER = HERE.parent
sys.path.insert(0, str(BLENDER))

from lib import manifest  # noqa: E402

GOOD_CC0 = {
    "id": "char_kit_99", "license": "CC0-1.0", "license_file": "blender/manifest.schema.json",  # any committed file
    "source_url": "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0",
    "source_commit": "672074b73ba276876a19e8816ecdc5241817ab47", "source_date": "2026-10-18",
    "source_files": {"Characters/gltf/Knight.glb": "0" * 64},
}
GOOD_OWN = {"id": "house_cottage_99", "license": "project-original"}


def test_committed_rows_have_a_license():
    data = json.loads(manifest.MANIFEST.read_text())
    assert data["assets"]
    for a in data["assets"]:
        assert manifest.provenance_errors(a) == [], a["id"]


def test_project_original_needs_no_source():
    assert manifest.provenance_errors(GOOD_OWN) == []


def test_good_cc0_row_passes():
    assert manifest.provenance_errors(GOOD_CC0) == []


def test_mutant_missing_license_fails():
    row = copy.deepcopy(GOOD_OWN)
    del row["license"]
    assert any("missing license" in e for e in manifest.provenance_errors(row))


def test_mutant_non_cc0_license_fails():
    for lic in ("CC-BY-4.0", "MIT", "QAL-1.0", "Synty-EULA", "unknown", ""):
        row = copy.deepcopy(GOOD_CC0)
        row["license"] = lic
        assert manifest.provenance_errors(row), lic


def test_mutant_cc0_missing_fields_fail():
    for key in ("source_url", "source_date", "license_file", "source_files"):
        row = copy.deepcopy(GOOD_CC0)
        row.pop(key)
        row["source_commit"] = None if key == "source_date" else row["source_commit"]
        errs = manifest.provenance_errors(row)
        assert errs, key


def test_mutant_cc0_missing_licence_text_fails():
    row = copy.deepcopy(GOOD_CC0)
    row["license_file"] = "blender/does-not-exist/LICENSE.txt"
    assert any("not committed" in e for e in manifest.provenance_errors(row))


def test_schema_rejects_a_bad_sha256():
    from lib import schema

    sch = json.loads(manifest.SCHEMA.read_text())
    props = sch["$defs"]["asset"]["properties"]
    assert schema.validate("abc", props["source_sha256"])
    assert not schema.validate("a" * 64, props["source_sha256"])
