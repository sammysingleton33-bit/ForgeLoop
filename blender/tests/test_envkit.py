"""FL-0136 phase 1 comparison tooling: fitting to footprints, the wheat generator, the S3 report, provenance of the pinned pack files."""

import json
import sys
from pathlib import Path

import pytest

BLENDER = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BLENDER))
sys.path.insert(0, str(BLENDER / "scripts"))

try:
    import bpy  # noqa: F401

    HAVE_BPY = True
except ImportError:
    HAVE_BPY = False

needs_bpy = pytest.mark.skipif(not HAVE_BPY, reason="bpy not available")


def _box(x, y, z):
    from lib.ckit import box

    return box(x, y, z, color=(0.5, 0.5, 0.5), smooth=False).move(3.0, y / 2 + 1.0, -2.0)  # off-centre and floating on purpose


@needs_bpy
def test_fit_footprint_scales_uniformly_centres_and_grounds_the_base():
    from lib import envkit as E

    m, rep = E.fit_footprint(_box(2.0, 4.0, 1.0), 32, 32)
    (x0, y0, z0), (x1, y1, z1) = E.bbox(m)
    assert abs(y0) < 1e-9 and abs((x0 + x1) / 2) < 1e-9 and abs((z0 + z1) / 2) < 1e-9
    assert rep["scale"] == pytest.approx(16.0, abs=1e-3)  # x limits: 32 / 2
    assert (x1 - x0, y1 - y0, z1 - z0) == pytest.approx((32.0, 64.0, 16.0), abs=1e-6)  # uniform: the box keeps its proportions
    assert rep["xz_within"] and rep["x_fill"] == pytest.approx(1.0) and rep["z_fill"] == pytest.approx(0.5)


@needs_bpy
def test_fit_footprint_limits_by_the_tighter_side_and_by_max_height():
    from lib import envkit as E

    m, rep = E.fit_footprint(_box(1.0, 1.0, 2.0), 30, 20)
    assert rep["scale"] == pytest.approx(10.0, abs=1e-3)  # z limits: 20 / 2
    assert rep["size"][0] == pytest.approx(10.0) and rep["size"][2] == pytest.approx(20.0)
    m2, rep2 = E.fit_footprint(_box(1.0, 1.0, 2.0), 30, 20, max_height=5.0)
    assert rep2["height"] == pytest.approx(5.0)


@needs_bpy
def test_wheat_b_stages_stay_inside_the_field_and_within_the_crop_budget():
    from lib import envkit as E

    h = []
    for stage in (1, 2, 3):
        m = E.wheat_b(stage, 38.0, 28.0)
        (x0, y0, z0), (x1, y1, z1) = E.bbox(m)
        assert x1 - x0 <= 38.0 + 1e-6 and z1 - z0 <= 28.0 + 1e-6 and y0 >= -1e-9
        assert m.tris <= 3000  # budgets.json: crop class
        h.append(y1)
    assert h[0] < h[1] < h[2]  # the crop grows


def test_s3_bbox_reads_rotated_boxes():
    from lib import envkit as E

    # one 2 x 2 x 2 box turned 45 degrees about y at (0, 1, 0): extent sqrt(2) * 2 / ... = 2.828 in x and z
    c, s = 0.7071067811865476, 0.7071067811865476
    entry = {"parts": [{"size": [2, 2, 2], "cframe": [0, 1, 0, c, 0, s, 0, 1, 0, -s, 0, c]}]}
    mn, mx = E.s3_bbox(entry)
    assert mx[0] - mn[0] == pytest.approx(2.8284, abs=1e-3) and mx[1] - mn[1] == pytest.approx(2.0) and mn[1] == pytest.approx(0.0)
    rep = E.s3_report(entry, (3.0, 3.0))
    assert rep["xz_within"] is True
    assert E.s3_report(entry, (2.5, 3.0))["xz_within"] is False


def test_pinned_pack_sources_name_the_commit_and_licence():
    src = json.loads((BLENDER / "lib" / "envkit_sources.json").read_text())
    assert src["commit"] == "84fa4e91af6a88989be7c99e0891cede11f2ca38"
    assert len(src["license_sha256"]) == 64 and "CC0" in src["license"]
    assert src["files"] and all(len(v) == 64 for v in src["files"].values())
    assert all(".." not in k and not k.startswith("/") for k in src["files"])


def test_pinned_pack_files_match_the_cache_when_it_is_present():
    from lib import envkit as E

    if not (E.KAYKIT_CACHE / "LICENSE.txt").exists():
        pytest.skip("KayKit cache not fetched (bash blender/scripts/fetch_kaykit.sh)")
    src = json.loads(E.SOURCES_JSON.read_text())
    for rel, want in src["files"].items():
        assert E.sha256(E.KAYKIT_CACHE / rel) == want, rel
    assert E.sha256(E.KAYKIT_CACHE / "LICENSE.txt") == src["license_sha256"]


def test_sheet_letters_are_fixed_and_the_key_is_not_in_the_image_folder():
    import envkit_sheets as S

    assert sorted(S.LETTER.values()) == ["A", "B", "C", "D"]
    for name, spec in S.SHEETS.items():
        assert name.startswith("sheet_") and spec["rows"]
    # the blind labels carry no source names
    assert not any(k.lower() in "".join(S.LETTER.values()).lower() for k in ("kaykit", "forge", "kit"))
