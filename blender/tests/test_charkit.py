"""Character kit tests (FL-0135): geometry library, rig definition, pose port, budgets, shipped rig.json consistency."""

import json
import math
import re
import sys
from pathlib import Path

import pytest

BLENDER = Path(__file__).resolve().parent.parent
REPO = BLENDER.parent
sys.path.insert(0, str(BLENDER))

try:
    import bpy  # noqa: F401

    HAVE_BPY = True
except ImportError:
    HAVE_BPY = False

needs_bpy = pytest.mark.skipif(not HAVE_BPY, reason="bpy not available")
RIG_JSON = REPO / "games/game-001/art/char_kit/rig.json"
NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def _registry():
    from generators import char_kit

    return char_kit.registry()


@needs_bpy
def test_loft_is_closed_and_outward():
    from lib.ckit import loft, sphere

    for m in (loft([(0, 1, 1), (1, 0.8, 0.8), (2, 0, 0)], seg=8), sphere(1.0, 0.8, 0.9, seg=8, rings=4)):
        m.triangulate()
        edges = {}
        for f in m.f:
            for i in range(3):
                e = tuple(sorted((f[i], f[(i + 1) % 3])))
                edges[e] = edges.get(e, 0) + 1
        assert all(c == 2 for c in edges.values())
        vol = 0.0
        for f in m.f:
            a, b, c = (m.v[i] for i in f)
            vol += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
        assert vol > 0


@needs_bpy
def test_mirror_flips_winding_and_keeps_volume_positive():
    from lib.ckit import loft

    m = loft([(0, 1, 1, 0.5, 0), (1, 0.5, 0.5, 0.5, 0), (2, 0, 0, 0.5, 0)], seg=6).triangulate()
    mm = m.copy().mirror_x()
    assert min(v[0] for v in mm.v) < 0
    mm.fix_winding()
    assert mm.tris == m.tris


@needs_bpy
def test_kit_pieces_and_assemblies_are_consistent():
    R, rig, hand = _registry()
    names = set(R.pieces)
    assert len(names) >= 90
    for n, p in R.pieces.items():
        assert NAME_RE.match(n), n
        assert p.joint in rig.JOINTS or p.joint == "Tool", (n, p.joint)
    for job in rig.ASSEMBLIES:
        for kd in rig.KINGDOMS:
            for hc in (1, 5):
                for hair in range(1, 7):
                    look = {"skin": 1 + hair % 6, "hair": hair, "hairColor": hc, "outfit": 1 + hair % 6}
                    for n in rig.names_for(job, look, kd):
                        assert n in names, (job, n)
    # at least 4 faces, 8 hair styles (incl. long hair), 2 boots, the eight job hats, tools of every job
    assert sum(1 for p in R.pieces.values() if p.slot == "head") >= 4
    assert sum(1 for p in R.pieces.values() if p.slot == "hair") >= 8
    assert len({n.rsplit("_", 1)[0] for n, p in R.pieces.items() if p.slot == "boot"}) >= 2
    for n in ("hat_straw", "hat_beanie", "hat_miner", "hat_builder", "hair_10", "hat_merchant", "hat_coif", "acc_02", "hat_helm",
              "hat_smith", "tool_hoe", "tool_axe", "tool_pick", "tool_mallet", "tool_hammer", "tool_scale", "tool_staff_healer", "tool_sack",
              "tool_spear", "tool_sword", "tool_bow", "hat_crown", "cape", "crest_crimson", "crest_azure", "crest_emerald",
              "crest_gold", "crest_neutral", "shield_crimson", "shield_gold", "shield_neutral", "quiver", "mantle_kingdom"):
        assert n in names, n


@needs_bpy
def test_budgets_hold_for_every_assembled_rig():
    from lib import ckit_kit

    R, rig, hand = _registry()
    table = ckit_kit.rig_measure(R, rig)
    for job, t in table.items():
        assert t["tris_max"] <= t["budget"], (job, t["tris_max"], t["budget"])
        assert t["pieces_max"] <= ckit_kit.MAX_PIECES, (job, t["pieces_max"])
        assert t["texture_bytes"] == 0
    for n, p in R.pieces.items():
        assert ckit_kit.tri_count(p.m) <= 400 or p.slot in ("head", "torso"), n
        assert ckit_kit.tri_count(p.m) < 20000


@needs_bpy
def test_kit_build_is_deterministic_in_one_process():
    from lib import ckit_kit

    R1, _, _ = _registry()
    R2, _, _ = _registry()
    assert ckit_kit.canon_hash(R1.pieces) == ckit_kit.canon_hash(R2.pieces)


@needs_bpy
def test_every_piece_is_watertight_triangulated_and_coloured():
    from lib import ckit_kit

    R, rig, hand = _registry()
    objs = ckit_kit.build_objects(R)
    rows, ok = ckit_kit.validate_objects(objs)
    assert ok, {n: r for n, r in rows.items() if not r["pass"]}
    open_pieces = [n for n, r in rows.items() if not r["watertight"]]
    assert not open_pieces, open_pieces


@needs_bpy
def test_pose_port_stays_within_documented_limits():
    from lib import ckit_pose as P

    for act, speed in P.ACTIONS:
        for job in ("farmer", "woodcutter", "miner", "builder", "hauler", "idle", "soldier"):
            for ph in P.PHASES:
                tf = P.sample(act, job, ph, speed)
                for j, m in tf.items():
                    if act == "dead" and j == "Torso":
                        continue  # the fall rotates the whole body 90 degrees
                    ang = math.degrees(m.to_quaternion().angle)
                    assert ang <= P.LIMITS[j] + 0.5 or (act == "celebrate" and ang <= 150.5), (act, job, j, ang)


@needs_bpy
def test_committed_rig_json_matches_a_rebuild():
    from lib import ckit_kit

    if not RIG_JSON.exists():
        pytest.skip("rig.json not committed yet")
    doc = json.loads(RIG_JSON.read_text())
    R, rig, hand = _registry()
    assert doc["geometry_hash"] == ckit_kit.canon_hash(R.pieces), "rig.json is stale: rebuild with build.py --generator char_kit"
    assert doc["schema_version"] == 1 and doc["unit"] == "stud" and doc["root_height"] == 3.2
    for j in ("Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool", "TorsoTool"):
        assert j in doc["joints"]
    assert {k for k, v in doc["pieces"].items() if not v.get("empty")} == set(R.pieces)
    assert doc["joints"]["Torso"]["pos"] == [0.0, 2.2, 0.0] and doc["joints"]["Head"]["pos"] == [0.0, 3.9, 0.0]


@needs_bpy
def test_rig_json_assemblies_resolve_like_the_generator_and_the_runtime_contract():
    """lib/ckit_rigload.names_from_doc reads rig.json only; it must agree with the generator's own resolution for every look,
    every id it names exists, nothing is left over budget."""
    from lib import ckit_kit, ckit_rigload

    R, rig, hand = _registry()
    doc = ckit_kit.rig_json(R, rig, "B", hand)
    n = 0
    for job in rig.ASSEMBLIES:
        for kd in rig.KINGDOMS:
            for skin in (1, 4):
                for hair in range(1, 7):
                    for hc in (1, 6):
                        for outfit in range(1, 7):
                            look = {"skin": skin, "hair": hair, "hairColor": hc, "outfit": outfit}
                            a = rig.names_for(job, look, kd)
                            b = ckit_rigload.names_from_doc(doc, job, look, kd)
                            assert a == b, (job, look, kd, a, b)
                            assert len(a) <= ckit_kit.MAX_PIECES
                            for name in a:
                                assert name in doc["pieces"] and not doc["pieces"][name].get("empty")
                                c = ckit_rigload.tint_from_doc(doc, name, job, look, kd)
                                assert all(0.0 <= v <= 1.0 for v in c)
                            n += 1
    assert n > 1000


@needs_bpy
def test_variant_resolution_matches_the_luau_port():
    """Spot values of CharacterMesh.luau's axisIndex / mix (hand-computed from the Luau source)."""
    from lib import ckit_resolve as RS

    look = {"skin": 3, "hair": 5, "hairColor": 2, "outfit": 4}
    assert RS.mix(11, 3, 2, 5, 4) == ((((11 * 31 + 3) * 31 + 2) * 31 + 5) * 31 + 4) % 2147483629
    assert RS.axis_index(look, "outfit", 6) == 3  # direct axis, no spill: outfit - 1
    assert RS.axis_index(look, "hair", 10) == (4 + ((3 + 4) % 2) * 6) % 10  # 10 hair styles over a range of 6: spill by skin + outfit
    assert RS.axis_index(look, "unknown", 3) is None
    ids = ["torso_02", "torso_01", "torso_smith", "torso_10", "head_01"]
    assert RS.variants_of(ids, "torso_", "") == ["torso_01", "torso_02", "torso_10"]


@needs_bpy
def test_looks_make_visibly_different_citizens():
    """>= 4 faces, >= 8 hair styles and >= 5 torso cuts per worker job are reachable from the four look fields."""
    from lib import ckit_resolve as RS

    R, rig, hand = _registry()
    faces, hairs = set(), set()
    torsos = {j: set() for j in ("farmer", "woodcutter", "miner", "builder", "hauler", "idle")}
    for skin in range(1, 7):
        for hair in range(1, 7):
            for hc in (1, 5):
                for outfit in range(1, 7):
                    look = {"skin": skin, "hair": hair, "hairColor": hc, "outfit": outfit}
                    names = rig.names_for("idle", look, "crimson")
                    faces.update(n for n in names if n.startswith("head_"))
                    hairs.update(n for n in names if n.startswith("hair_"))
                    for j in torsos:
                        torsos[j].update(n for n in rig.names_for(j, look, "crimson") if n.startswith("torso_"))
    assert len(faces) >= 4 and len(hairs) >= 8, (faces, hairs)
    for j, t in torsos.items():
        assert len(t) >= 5, (j, t)


@needs_bpy
def test_hair_and_capes_never_poke_through_the_body_in_any_pose():
    import importlib.util

    spec = importlib.util.spec_from_file_location("charkit_clearance", BLENDER / "scripts" / "charkit_clearance.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    assert mod.main(["--quick"]) == 0


FBX_COMMITTED = REPO / "games/game-001/art/char_kit/citizen_kit.fbx"
MANIFEST = BLENDER / "manifest.json"


@needs_bpy
def test_committed_fbx_matches_rig_json_and_the_manifest_row():
    """The shipped FBX re-imports to exactly the pieces and triangle counts rig.json lists, and one manifest row owns it (FORGE-07 A2)."""
    from lib import ckit_kit

    if not FBX_COMMITTED.exists():
        pytest.skip("citizen_kit.fbx not committed yet")
    doc = json.loads(RIG_JSON.read_text())
    rt = ckit_kit.roundtrip_fbx(FBX_COMMITTED, doc)
    assert rt["pass"], rt
    rows = [a for a in json.loads(MANIFEST.read_text())["assets"] if a.get("files", {}).get("mesh_committed")]
    assert [a["id"] for a in rows] == ["char_kit_01"]
    assert rows[0]["files"]["mesh_committed"] == FBX_COMMITTED.relative_to(REPO).as_posix()
    assert rows[0]["geometry_hash"] == doc["geometry_hash"]


def test_committed_fbx_has_no_personal_paths():
    """FORGE-07 A6: nothing in the shipped FBX / rig.json / manifest row names a home directory, user or machine."""
    if not FBX_COMMITTED.exists():
        pytest.skip("citizen_kit.fbx not committed yet")
    blob = FBX_COMMITTED.read_bytes()
    for needle in (b"/home/", b"/root", b"/tmp", b"C:\\Users", b"sammy", b"outlook", b"claude"):
        assert needle not in blob, needle
    for f in (RIG_JSON, MANIFEST):
        text = f.read_text()
        for needle in ("/home/", "/root", "/tmp/", "C:\\Users", "sammy", "outlook"):
            assert needle not in text, (f.name, needle)


@needs_bpy
def test_budget_script_passes_on_the_shipped_files():
    """FORGE-07 A5: the budget table is measured by re-importing the committed FBX, not read from the generator."""
    import subprocess

    if not FBX_COMMITTED.exists():
        pytest.skip("citizen_kit.fbx not committed yet")
    r = subprocess.run([sys.executable, "-I", str(BLENDER / "scripts" / "charkit_budget.py")], capture_output=True, text=True, timeout=300)
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-1000:]
    assert "charkit budget: PASS" in r.stdout


@needs_bpy
def test_committed_kit_passes_the_ported_runtime_spec_checks():
    """Torso at the hips, highest body point < 7.2, death-fall margin, tool-to-head clearance (KitCharacterMesh / KitCharacterMeshPose)."""
    import importlib.util

    spec = importlib.util.spec_from_file_location("charkit_runtime_checks", BLENDER / "scripts" / "charkit_runtime_checks.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    doc = json.loads(RIG_JSON.read_text())
    bad, worst = mod.check(doc)
    assert not bad, bad[:5]
    assert worst["height"] < 7.2 and worst["fall"] > -0.25 and worst["tool_head"] >= 0.1
