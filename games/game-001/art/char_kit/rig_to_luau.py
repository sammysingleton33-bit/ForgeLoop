#!/usr/bin/env python3
"""rig_to_luau — turns the Blender citizen kit's rig.json into Kit/CharacterMeshData.luau (FL-0135, D-057, FORGE-02).

Standard library only (Python 3.10+). Deterministic: the same rig.json gives the same bytes, so the output can be
committed and diffed. THE one command, from anywhere in the repository, once rig.json has landed:

    python3 games/game-001/art/char_kit/rig_to_luau.py

reads  games/game-001/art/char_kit/rig.json
writes games/game-001/src/shared/Kit/CharacterMeshData.luau   (then run the Kit specs: see the end of this docstring)

    --in PATH / --out PATH   other files          --validate-only   check rig.json, write nothing (the Blender worker's gate)
    --check                  exit 1 if --out differs from what --in would generate (a drift check)
    --selftest               validator + converter against the placeholder kit and a table of broken kits
Exit codes: 0 ok, 1 invalid or out of date, 2 usage. Warnings never fail the run; read them.

After converting:  lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json \\
                       --specs games/game-001/tests/world KitCharacterMesh
The specs build every assembly of the committed data over a fake CitizenKit folder and check joints, flags, budgets
(<= 16 pieces, the triangle budget below, <= 20,000 per mesh), tints and pose clearance on the real numbers.

RIG.JSON v1 (what Kit/CharacterMesh reads; the FL-0135 contract plus the clarifications marked [+])
  schema_version 1; unit "stud"; root_height 3.2 (Character.ROOT_HEIGHT). Rig axes in studs: +X the character's right, +Y up,
  -Z front, feet at y = 0, centred on x = z = 0. Any other top-level key (notes, budgets, manifest...) is ignored.
  joints   Torso(parent Root) Head LeftArm RightArm LeftLeg RightLeg (parent Torso) Tool (parent RightArm) and, for the
           hauler's sack, TorsoTool (parent Torso; its Motor6D is still named "Tool"). pos = [x, y, z] at the rest pose.
           [+] Torso (0, 2.2, 0): Sim/Pose's death fall assumes hips 2.2 up. Head x = z = 0; legs at y 2.2, mirrored in x;
           arms mirrored in x. One joint table for every assembly, so all torsos share the shoulder pivots.
  pieces   id -> { joint, weld_to?, mirror?, empty?, bbox_center, size, tris, tint, tint_factor?, slot, tags? }
           id         lowercase snake case, = the mesh object name in citizen_kit.fbx (and the CitizenKit MeshPart name)
           joint      the joint it rides (any key of joints)
           weld_to    null: a BASE piece, the rigid body of `joint` (one per joint in an assembly; carries the Motor6D).
                      A joint name or a piece id: an EXTRA, Weld-ed to that joint's base piece / that piece (same joint).
                      [+] A piece id that the assembly swaps for another variant of its joint (hair welded to head_01 on
                      a rig that has head_03) follows the variant. [+] Pieces of slot hair, hat, boot, sleeve, cape, acc
                      are always extras: without weld_to they are welded to their joint's base piece.
           mirror     [+] true: this one piece stands for both sides of a Left/Right joint (the other side is the same
                      mesh at x mirrored, so it must be left-right symmetric); `joint` is the authored side. Pieces
                      with a splayed arm or a handed prop are not symmetric: give them left and right pieces.
           empty      [+] true: no mesh (a bald variant, "no accessory"); only joint, slot, tint, tags are needed.
           bbox_center, size   bounding box of the mesh in the rig frame at rest: the MeshPart's Position and Size.
           tris       triangles, 1..20,000 (Roblox's per-mesh cap), most under 400
           tint       skin | hair | kingdom | cloth | fixed  (baked WHITE-ish for the first four; fixed keeps its colours)
           tint_factor [+] kingdom pieces only, 0.3..1.3: shade(kingdomColor, f); default 0.8 citizens / 1 soldiers, governors
           slot       head hair hat torso armour arm sleeve leg boot tool back cape acc   ([+] acc: accessories)
  assemblies  key -> { slot key -> template | [template, ...] }. key: a job (idle farmer woodcutter|lumberjack miner builder
           hauler blacksmith merchant healer...), "soldier" (also "soldier_<unit>" for one unit kind) or "governor". Unknown
           jobs build "idle". Slot keys are free labels except [+] "hair" (the piece becomes the part Hair: KitHeadwear)
           and "acc" (Accessory: KitAccessory). The pieces of one assembly: exactly one base piece for each of Torso, Head,
           LeftArm, RightArm, LeftLeg, RightLeg, at most one for Tool/TorsoTool, any number of extras, <= 16 pieces in all
           (a mirror piece counts twice), and within the triangle BUDGET (D-057 amendment (15)): citizens 1,000 in all, of
           which the body <= 900 and the hand tool or sack with its heads <= 150; soldiers and governors 1,500 in all.
           template   a piece id, or [+] an id with ONE variant token (same look -> same model):
                      %look.<axis>%  the pieces whose id is prefix + digits + suffix, in numeric order, one picked by the
                                     axis: skin hair hairColor outfit (a look field, spilling over extra variants) or
                                     face boots acc weapon (a mix of the whole look). All variants of a template must
                                     ride the same joint with the same base/extra role.
                      %kingdom%      crimson azure emerald gold (and neutral for an unknown or grey colour): every one of
                                     the four must exist; a missing neutral only sends neutral-coloured builds to the
                                     part-built rig.
Kit/CharacterMesh.luau is the other half of this contract (header comment); keep them in step.
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
DEFAULT_IN = HERE / "rig.json"
DEFAULT_OUT = ROOT / "games/game-001/src/shared/Kit/CharacterMeshData.luau"
PLACEHOLDER = ROOT / "games/game-001/tests/world/fixtures/char_kit_placeholder.rig.json"
PLACEHOLDER_LUAU = ROOT / "games/game-001/tests/world/fixtures/CharacterMeshFixture.luau"

SCHEMA_VERSION = 1
ROOT_HEIGHT = 3.2
MAX_MESH_TRIS = 20000
MAX_PIECES = 16
# THE triangle budget (mirrors CharacterMesh.BUDGET in Kit/CharacterMesh.luau, which the Kit specs enforce exactly)
BUDGET = {"citizen": {"total": 1000, "body": 900, "tool": 150}, "soldier": {"total": 1500}, "governor": {"total": 1500}}
TINTS = ("skin", "hair", "kingdom", "cloth", "fixed")
SLOTS = ("head", "hair", "hat", "torso", "armour", "arm", "sleeve", "leg", "boot", "tool", "back", "cape", "acc")
EXTRA_SLOTS = ("hair", "hat", "boot", "sleeve", "cape", "acc")
AXES = ("skin", "hair", "hairColor", "outfit", "face", "boots", "acc", "weapon")
KINGDOMS = ("crimson", "azure", "emerald", "gold")
REQUIRED_JOINTS = ("Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg")
TOOL_JOINTS = ("Tool", "TorsoTool")
EXPECTED_PARENT = {
    "Torso": "Root", "Head": "Torso", "LeftArm": "Torso", "RightArm": "Torso", "LeftLeg": "Torso", "RightLeg": "Torso",
    "Tool": "RightArm", "TorsoTool": "Torso",
}
OPPOSITE = {"LeftArm": "RightArm", "RightArm": "LeftArm", "LeftLeg": "RightLeg", "RightLeg": "LeftLeg"}
ID_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
VARIANT_RE = re.compile(r"%look\.([A-Za-z]+)%")
LUAU_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
PIECE_KEYS = ("joint", "weld_to", "mirror", "empty", "bbox_center", "size", "tris", "tint", "tint_factor", "slot", "tags")


# ------------------------------------------------------------------------------------------------ validation
def is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def is_vec(v, positive: bool = False) -> bool:
    return isinstance(v, list) and len(v) == 3 and all(is_num(x) for x in v) and (not positive or all(x > 0 for x in v))


def weld_target(piece: dict) -> str | None:
    """What a piece is welded to (None: a base piece). Mirrors weldTarget in Kit/CharacterMesh.luau."""
    wt = piece.get("weld_to")
    if isinstance(wt, str):
        return wt
    return piece.get("joint") if piece.get("slot") in EXTRA_SLOTS else None


def split_template(template: str):
    """-> (prefix, axis, suffix) for a variant template, (template, None, '') for a plain one."""
    m = VARIANT_RE.search(template)
    if not m:
        return template, None, ""
    return template[: m.start()], m.group(1), template[m.end():]


def candidates(template: str, pieces: dict, kingdom: str | None = None) -> list[str]:
    """Piece ids a template can resolve to (for one kingdom), in numeric variant order."""
    t = template.replace("%kingdom%", kingdom) if kingdom else template
    prefix, axis, suffix = split_template(t)
    if axis is None:
        return [t] if t in pieces else []
    found = []
    for pid in pieces:
        if len(pid) > len(prefix) + len(suffix) and pid.startswith(prefix) and pid.endswith(suffix):
            middle = pid[len(prefix): len(pid) - len(suffix)]
            if middle.isdigit():
                found.append((int(middle), pid))
    return [pid for _, pid in sorted(found)]


def validate(data) -> tuple[list[str], list[str]]:
    """-> (errors, warnings). An empty error list means Kit/CharacterMesh can build every assembly of the data."""
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(data, dict):
        return ["rig.json must be a JSON object"], warnings
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}, not {data.get('schema_version')!r}")
    if data.get("unit", "stud") != "stud":
        errors.append(f"unit must be 'stud', not {data.get('unit')!r}")
    if data.get("root_height") != ROOT_HEIGHT:
        errors.append(f"root_height must be {ROOT_HEIGHT} (Character.ROOT_HEIGHT), not {data.get('root_height')!r}")
    joints, pieces, assemblies = data.get("joints"), data.get("pieces"), data.get("assemblies")
    for name, value in (("joints", joints), ("pieces", pieces), ("assemblies", assemblies)):
        if not isinstance(value, dict) or not value:
            errors.append(f"{name} must be a non-empty object")
    if errors:
        return errors, warnings

    # ---- joints
    for j in REQUIRED_JOINTS:
        if j not in joints:
            errors.append(f"joints: missing {j}")
    for j, d in joints.items():
        if j not in EXPECTED_PARENT:
            errors.append(f"joints.{j}: unknown joint (the rig has {', '.join(EXPECTED_PARENT)})")
            continue
        if not isinstance(d, dict) or not is_vec(d.get("pos")):
            errors.append(f"joints.{j}: pos must be three finite numbers")
            continue
        if d.get("parent") != EXPECTED_PARENT[j]:
            errors.append(f"joints.{j}: parent must be {EXPECTED_PARENT[j]} (the motor tree Sim/Pose animates), not {d.get('parent')!r}")
    if not errors:
        pos = {j: joints[j]["pos"] for j in joints}

        def near(a, b, tol=0.011):
            return all(abs(x - y) <= tol for x, y in zip(a, b))

        if not near(pos["Torso"], [0, 2.2, 0]):
            errors.append(f"joints.Torso: pos must be [0, 2.2, 0] (hips; Pose's death fall assumes 2.2), not {pos['Torso']}")
        if abs(pos["Head"][0]) > 0.011 or abs(pos["Head"][2]) > 0.011 or not 3.5 <= pos["Head"][1] <= 4.3:
            errors.append(f"joints.Head: pos must be above the spine (x = z = 0, y 3.5..4.3), not {pos['Head']}")
        for side, other in (("LeftLeg", "RightLeg"), ("LeftArm", "RightArm")):
            a, b = pos[side], pos[other]
            if abs(a[0] + b[0]) > 0.011 or abs(a[1] - b[1]) > 0.011 or abs(a[2] - b[2]) > 0.011 or a[0] >= 0:
                errors.append(f"joints.{side}/{other}: must mirror in x (left x < 0), not {a} and {b}")
        for leg in ("LeftLeg", "RightLeg"):
            if abs(pos[leg][1] - 2.2) > 0.011:
                errors.append(f"joints.{leg}: pos.y must be 2.2 (the hips), not {pos[leg][1]}")
        for arm in ("LeftArm", "RightArm"):
            if not 2.8 <= pos[arm][1] <= 3.95:
                errors.append(f"joints.{arm}: pos.y must be a shoulder height (2.8..3.95), not {pos[arm][1]}")
        if "Tool" in pos and pos["Tool"][0] <= 0:
            errors.append("joints.Tool: must be inside the RIGHT fist (x > 0)")

    # ---- pieces
    for pid, p in pieces.items():
        where = f"pieces.{pid}"
        if not ID_RE.match(pid):
            errors.append(f"{where}: id must be lowercase snake case ([a-z0-9_])")
        if not isinstance(p, dict):
            errors.append(f"{where}: must be an object")
            continue
        if p.get("joint") not in joints:
            errors.append(f"{where}: joint {p.get('joint')!r} is not in joints")
        if p.get("slot") not in SLOTS:
            errors.append(f"{where}: slot {p.get('slot')!r} is not one of {', '.join(SLOTS)}")
        if p.get("tint") not in TINTS:
            errors.append(f"{where}: tint {p.get('tint')!r} is not one of {', '.join(TINTS)}")
        for flag in ("mirror", "empty"):
            if flag in p and not isinstance(p[flag], bool):
                errors.append(f"{where}: {flag} must be true or false")
        wt = p.get("weld_to")
        if wt is not None and not isinstance(wt, str):
            errors.append(f"{where}: weld_to must be null, a joint name or a piece id")
        if "tint_factor" in p and (p.get("tint") != "kingdom" or not is_num(p["tint_factor"]) or not 0.3 <= p["tint_factor"] <= 1.3):
            errors.append(f"{where}: tint_factor is for kingdom pieces only and must be 0.3..1.3")
        if "tags" in p and not (isinstance(p["tags"], list) and all(isinstance(t, str) for t in p["tags"])):
            errors.append(f"{where}: tags must be a list of strings")
        if p.get("mirror") is True and p.get("joint") not in OPPOSITE:
            errors.append(f"{where}: mirror needs a LeftArm/RightArm/LeftLeg/RightLeg joint, not {p.get('joint')!r}")
        if p.get("empty") is True:
            continue
        if not is_vec(p.get("bbox_center")):
            errors.append(f"{where}: bbox_center must be three finite numbers")
        if not is_vec(p.get("size"), positive=True):
            errors.append(f"{where}: size must be three positive numbers")
        tris = p.get("tris")
        if not isinstance(tris, int) or isinstance(tris, bool) or not 1 <= tris <= MAX_MESH_TRIS:
            errors.append(f"{where}: tris must be an integer 1..{MAX_MESH_TRIS} (Roblox's per-mesh cap), not {tris!r}")
        if is_vec(p.get("bbox_center")) and is_vec(p.get("size"), positive=True):
            low = p["bbox_center"][1] - p["size"][1] / 2
            if low < -0.05:
                warnings.append(f"{where}: reaches {low:.2f} below the ground (feet are at y = 0)")
            if any(abs(c) + s / 2 > 25 for c, s in zip(p["bbox_center"], p["size"])):
                errors.append(f"{where}: lies more than 25 studs from the rig origin (a unit mistake?)")
    if errors:
        return errors, warnings

    # ---- weld graph: targets exist, same joint, no cycles
    for pid, p in pieces.items():
        wt = weld_target(p)
        if wt is None:
            continue
        if wt in joints:
            if wt != p["joint"] and not (wt in TOOL_JOINTS and p["joint"] in TOOL_JOINTS):
                errors.append(f"pieces.{pid}: welded to joint {wt} but rides {p['joint']}")
        elif wt in pieces:
            t = pieces[wt]
            if t["joint"] != p["joint"] and not (t["joint"] in TOOL_JOINTS and p["joint"] in TOOL_JOINTS):
                errors.append(f"pieces.{pid}: welded to {wt} (joint {t['joint']}) but rides {p['joint']}")
            if (p.get("mirror") is True) != (t.get("mirror") is True) and not t.get("empty") and weld_target(t) is not None:
                errors.append(f"pieces.{pid}: mirror must match its weld target {wt}")
        else:
            errors.append(f"pieces.{pid}: weld_to {wt!r} is neither a joint nor a piece")
    for pid in pieces:
        seen, at = set(), pid
        while at in pieces and isinstance(pieces[at].get("weld_to"), str) and pieces[at]["weld_to"] in pieces:
            if at in seen:
                errors.append(f"pieces.{pid}: weld cycle")
                break
            seen.add(at)
            at = pieces[at]["weld_to"]
    if errors:
        return errors, warnings

    # ---- assemblies (static: every variant of a template must play the same role; counts as a conservative bound)
    def role(pid: str):
        p = pieces[pid]
        return (p["joint"], weld_target(p) is None, p.get("mirror") is True)

    for key, assembly in assemblies.items():
        where = f"assemblies.{key}"
        if not isinstance(assembly, dict) or not assembly:
            errors.append(f"{where}: must be a non-empty object")
            continue
        slots = []  # (slot key, template, [candidate ids over kingdoms and variants])
        for slot_key, value in assembly.items():
            templates = value if isinstance(value, list) else [value]
            for template in templates:
                if not isinstance(template, str):
                    errors.append(f"{where}.{slot_key}: templates are piece-id strings")
                    continue
                _, axis, _ = split_template(template)
                if len(VARIANT_RE.findall(template)) > 1:
                    errors.append(f"{where}.{slot_key}: {template!r} has more than one %look.axis% token")
                    continue
                if axis is not None and axis not in AXES:
                    errors.append(f"{where}.{slot_key}: unknown look axis {axis!r} in {template!r} (use {', '.join(AXES)})")
                    continue
                if "%kingdom%" in template:
                    per = {k: candidates(template, pieces, k) for k in KINGDOMS + ("neutral",)}
                    for k in KINGDOMS:
                        if not per[k]:
                            errors.append(f"{where}.{slot_key}: no piece for {template!r} with kingdom {k}")
                    if not per["neutral"]:
                        warnings.append(f"{where}.{slot_key}: no neutral variant of {template!r}: neutral-coloured builds use the part-built rig")
                    ids = sorted({i for v in per.values() for i in v})
                else:
                    ids = candidates(template, pieces)
                    if not ids:
                        errors.append(f"{where}.{slot_key}: no piece {template!r}" if axis is None else f"{where}.{slot_key}: no piece fits {template!r} (ids must be prefix + digits + suffix)")
                    elif axis is not None and len(ids) == 1:
                        warnings.append(f"{where}.{slot_key}: {template!r} has a single variant")
                if ids:
                    solid = [i for i in ids if not pieces[i].get("empty")]
                    if len({role(i) for i in solid}) > 1:
                        errors.append(f"{where}.{slot_key}: the variants of {template!r} ride different joints or roles: {sorted({role(i) for i in solid})}")
                    slots.append((slot_key, template, solid))
        if any(e.startswith(where) for e in errors):
            continue
        base_count = {j: 0 for j in REQUIRED_JOINTS}
        tool_bases = 0
        n_pieces, tris_bound, tool_bound = 0, 0, 0
        all_ids = {i for _, _, ids in slots for i in ids}
        base_joints = set()
        for slot_key, template, ids in slots:
            if not ids:
                continue
            joint, is_base, mirror = role(ids[0])
            n = 2 if mirror else 1
            n_pieces += n
            worst = n * max(pieces[i]["tris"] for i in ids)
            tris_bound += worst
            if joint in TOOL_JOINTS:
                tool_bound += worst
            if is_base:
                targets = (joint, OPPOSITE[joint]) if mirror else (joint,)
                for j in targets:
                    if j in TOOL_JOINTS:
                        tool_bases += 1
                    else:
                        base_count[j] += 1
                    base_joints.add(j)
        for j, n in base_count.items():
            if n != 1:
                errors.append(f"{where}: {n} base pieces for {j} (needs exactly one)")
        if tool_bases > 1:
            errors.append(f"{where}: {tool_bases} tool base pieces (at most one of Tool/TorsoTool)")
        for slot_key, template, ids in slots:
            for i in ids:
                wt = weld_target(pieces[i])
                if wt is None:
                    continue
                if wt in joints:
                    ok = wt in base_joints or (wt in TOOL_JOINTS and base_joints & set(TOOL_JOINTS))
                else:
                    t = pieces[wt]
                    ok = wt in all_ids or (weld_target(t) is None and t["joint"] in base_joints)
                if not ok:
                    errors.append(f"{where}.{slot_key}: {i} is welded to {wt}, which this assembly does not have")
        if n_pieces > MAX_PIECES:
            errors.append(f"{where}: {n_pieces} pieces, the budget is {MAX_PIECES} (D-057: draw calls per citizen)")
        style = "governor" if key == "governor" else "soldier" if key.startswith("soldier") else "citizen"
        # D-057 (16): the kingdom must still read on a mesh soldier (D-033 (3)): every soldier assembly carries a %kingdom% crest piece
        if style == "soldier" and not any("%kingdom%" in tmpl and "crest" in tmpl for _, tmpl, _ in slots):
            errors.append(f"{where}: a soldier assembly needs a %kingdom% crest piece (a slot template with crest and %kingdom%; D-057 (16), D-033 (3))")
        limits = BUDGET[style]
        for what, got in (("total", tris_bound), ("body", tris_bound - tool_bound), ("tool", tool_bound)):
            if what in limits and got > limits[what]:
                warnings.append(f"{where}: worst case {got} {what} triangles over the {style} budget of {limits[what]} (heaviest variant of every slot; the Kit specs measure the real looks)")
    for needed in ("idle", "farmer", "miner", "builder", "hauler", "soldier", "governor"):
        if needed not in assemblies:
            warnings.append(f"assemblies: no '{needed}': it builds the part-built rig")
    if "woodcutter" not in assemblies and "lumberjack" not in assemblies:
        warnings.append("assemblies: no 'woodcutter' (or 'lumberjack'): it builds the part-built rig")
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


def piece_lua(p: dict) -> str:
    fields = []
    for key in PIECE_KEYS:
        if key not in p or p[key] is None:
            continue
        v = p[key]
        if key in ("bbox_center", "size"):
            fields.append(f"{key} = {lua_vec(v)}")
        elif key in ("mirror", "empty"):
            if v:
                fields.append(f"{key} = true")
        elif key == "tags":
            fields.append("tags = { " + ", ".join(lua_str(t) for t in v) + " }" if v else "tags = {}")
        elif isinstance(v, str):
            fields.append(f"{key} = {lua_str(v)}")
        else:
            fields.append(f"{key} = {num(v)}")
    return "{ " + ", ".join(fields) + " }"


def template_lua(value) -> str:
    if isinstance(value, list):
        return "{ " + ", ".join(lua_str(t) for t in value) + " }"
    return lua_str(value)


def to_luau(data: dict, source_name: str, source_bytes: bytes) -> str:
    digest = hashlib.sha256(source_bytes).hexdigest()
    n_pieces = sum(1 for p in data["pieces"].values() if not p.get("empty"))
    lines = [
        "--!strict",
        "--[[",
        "\tKit/CharacterMeshData — the imported-mesh citizen kit as data (FL-0135, D-057). GENERATED, do not edit by hand:",
        "\t\tpython3 games/game-001/art/char_kit/rig_to_luau.py",
        f"\tsource {source_name}  sha256 {digest}",
        f"\t{len(data['pieces'])} pieces ({n_pieces} with a mesh), {len(data['assemblies'])} assemblies, {len(data['joints'])} joints.",
        "\tKit/CharacterMesh.luau reads it; with no pieces (or a CitizenKit folder that lacks one) Kit.character falls back.",
        "]]",
        "",
        "-- stylua: ignore start",
        "return table.freeze({",
        f"\tschema_version = {SCHEMA_VERSION},",
        '\tunit = "stud",',
        f"\troot_height = {num(data['root_height'])},",
        "\tjoints = {",
    ]
    for j in sorted(data["joints"]):
        d = data["joints"][j]
        lines.append(f"\t\t{lua_key(j)} = {{ parent = {lua_str(d['parent'])}, pos = {lua_vec(d['pos'])} }},")
    lines += ["\t},", "\tpieces = {"]
    for pid in sorted(data["pieces"]):
        lines.append(f"\t\t{lua_key(pid)} = {piece_lua(data['pieces'][pid])},")
    lines += ["\t},", "\tassemblies = {"]
    for key in sorted(data["assemblies"]):
        lines.append(f"\t\t{lua_key(key)} = {{")
        for slot_key in sorted(data["assemblies"][key]):
            lines.append(f"\t\t\t{lua_key(slot_key)} = {template_lua(data['assemblies'][key][slot_key])},")
        lines.append("\t\t},")
    lines += ["\t},", "})", "-- stylua: ignore end", ""]
    return "\n".join(lines)


def load_json(text: str):
    def bad(c):
        raise ValueError(f"non-finite number {c} in rig.json")

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

    def drop_piece(pid):
        return m(lambda d: d["pieces"].pop(pid))

    return [
        ("schema 2", m(lambda d: d.update(schema_version=2)), "schema_version"),
        ("root height", m(lambda d: d.update(root_height=3.0)), "root_height"),
        ("missing joint", m(lambda d: d["joints"].pop("LeftLeg")), "missing LeftLeg"),
        ("hips moved", m(lambda d: d["joints"]["Torso"].update(pos=[0, 2.3, 0])), "joints.Torso"),
        ("head parent", m(lambda d: d["joints"]["Head"].update(parent="RightArm")), "joints.Head: parent"),
        ("asymmetric arms", m(lambda d: d["joints"]["RightArm"].update(pos=[1.0, 3.5, 0])), "must mirror"),
        ("bad tint", m(lambda d: d["pieces"]["head_01"].update(tint="red")), "tint 'red'"),
        ("mesh too big", m(lambda d: d["pieces"]["head_01"].update(tris=20001)), "tris must be"),
        ("bad slot", m(lambda d: d["pieces"]["head_01"].update(slot="banana")), "slot 'banana'"),
        ("zero size", m(lambda d: d["pieces"]["head_01"].update(size=[0, 1, 1])), "size must be"),
        ("unknown joint", m(lambda d: d["pieces"]["head_01"].update(joint="Ear")), "joint 'Ear'"),
        ("unit mistake", m(lambda d: d["pieces"]["head_01"].update(bbox_center=[0, 464, 0])), "25 studs"),
        ("bad id", m(lambda d: d["pieces"].update({"Head-01": d["pieces"]["head_01"]})), "snake case"),
        ("tint_factor on cloth", m(lambda d: d["pieces"]["torso_02"].update(tint_factor=0.9)), "tint_factor"),
        ("mirror on a torso", m(lambda d: d["pieces"]["torso_01"].update(mirror=True)), "mirror needs"),
        ("weld nowhere", m(lambda d: d["pieces"]["hair_01"].update(weld_to="ghost")), "neither a joint nor a piece"),
        ("weld across joints", m(lambda d: d["pieces"]["hair_01"].update(weld_to="LeftArm")), "welded to joint LeftArm"),
        (
            "weld cycle",
            m(lambda d: (d["pieces"]["tool_hoe"].update(weld_to="tool_hoe_blade"))),
            "weld cycle",
        ),
        ("unknown axis", m(lambda d: d["assemblies"]["idle"].update(hair="hair_%look.shoe%")), "unknown look axis"),
        ("two axes", m(lambda d: d["assemblies"]["idle"].update(hair="hair_%look.hair%_%look.skin%")), "more than one"),
        ("no variants", m(lambda d: d["assemblies"]["idle"].update(hair="wig_%look.hair%")), "no piece fits"),
        ("no such piece", m(lambda d: d["assemblies"]["idle"].update(boot="boot_99")), "no piece 'boot_99'"),
        ("kingdom missing", drop_piece("armour_azure"), "kingdom azure"),
        ("soldier without a crest", m(lambda d: d["assemblies"]["soldier"].pop("hair")), "crest piece"),
        (
            "variants disagree",
            m(lambda d: d["pieces"]["torso_02"].update(joint="Head", weld_to=None, slot="head")),
            "ride different joints",
        ),
        ("no leg", m(lambda d: d["assemblies"]["idle"].pop("leg")), "base pieces for LeftLeg"),
        ("two heads", m(lambda d: d["assemblies"]["idle"].update(head2="head_helm")), "base pieces for Head"),
        (
            "two tools",
            m(lambda d: d["assemblies"]["farmer"].update(tool2="tool_axe")),
            "tool base pieces",
        ),
        (
            "too many pieces",
            m(lambda d: d["assemblies"]["idle"].update(extras=[f"hair_0{i}" for i in (1, 2, 3, 4, 6, 7, 8)] + ["acc_01", "acc_02"])),
            "pieces, the budget is 16",
        ),
        ("extra without its target", m(lambda d: d["assemblies"]["farmer"].pop("tool")), "welded to tool_hoe"),
        ("not json numbers", '{"schema_version": NaN}', "non-finite"),
    ]


def selftest() -> int:
    failures: list[str] = []

    def check(ok: bool, what: str):
        print(("  ok    " if ok else "  FAIL  ") + what)
        if not ok:
            failures.append(what)

    if not PLACEHOLDER.exists():
        print(f"selftest: {PLACEHOLDER} is missing (run make_placeholder_rig.py)")
        return 1
    raw = PLACEHOLDER.read_bytes()
    good = load_json(raw.decode())
    errors, warnings = validate(good)
    check(not errors, f"the placeholder kit validates ({len(errors)} errors)" + "".join(f"\n        {e}" for e in errors[:5]))
    text_a = to_luau(good, shown_path(PLACEHOLDER), raw)
    text_b = to_luau(load_json(raw.decode()), shown_path(PLACEHOLDER), raw)
    check(text_a == text_b, "conversion is deterministic")
    check(text_a.count("{") == text_a.count("}"), "braces balance in the generated Luau")
    check(not re.search(r"\b(nan|inf)\b", text_a), "no nan or inf in the generated Luau")
    check(PLACEHOLDER_LUAU.exists() and PLACEHOLDER_LUAU.read_text() == text_a, f"{PLACEHOLDER_LUAU.name} is what the converter makes of the placeholder")
    shuffled = dict(reversed(list(good.items())))
    check(to_luau(shuffled, shown_path(PLACEHOLDER), raw) == text_a, "key order in rig.json does not change the output")
    check(num(3.0) == "3" and num(-0.0) == "0" and num(4.64) == "4.64" and num(1e-7) == "0", "numbers print short")
    check(lua_str('a"b\\c') == '"a\\"b\\\\c"' and lua_key("end") == '["end"]' and lua_key("hat_01") == "hat_01", "strings and keys escape")
    empty = {**good, "pieces": {}}
    check(any("non-empty" in e for e in validate(empty)[0]), "an empty kit is invalid, not silently accepted")
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
    # warnings (they never fail a run, but the Blender worker must see them)
    def warns(mutate, expect: str) -> bool:
        errs, warn = validate(mutate(copy.deepcopy(good)))
        return not errs and any(expect in w for w in warn)

    def fatten(d):
        d["pieces"]["torso_02"]["tris"] = 950
        return d

    def fatten_tool(d):
        d["pieces"]["tool_hoe"]["tris"] = 200
        return d

    def drop_neutral(d):
        d["pieces"].pop("crest_neutral")
        return d

    def drop_job(d):
        d["assemblies"].pop("miner")
        return d

    check(warns(fatten, "over the citizen budget of 900"), "a 950-triangle torso is warned about (citizen body budget 900)")
    check(warns(fatten_tool, "tool triangles over the citizen budget of 150"), "a 200-triangle hoe is warned about (tool budget 150)")
    check(warns(drop_neutral, "no neutral variant"), "a missing neutral variant is warned about")
    check(warns(drop_job, "no 'miner'"), "a missing job assembly is warned about")
    check(BUDGET["citizen"] == {"total": 1000, "body": 900, "tool": 150} and BUDGET["soldier"] == {"total": 1500}, "the budget constants are D-057 amendment (15)'s")
    print(f"selftest: {'FAIL' if failures else 'PASS'} ({len(failures)} failure(s))")
    return 1 if failures else 0


# ------------------------------------------------------------------------------------------------ CLI
def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="rig.json -> Kit/CharacterMeshData.luau (FL-0135)")
    ap.add_argument("--in", dest="src", type=Path, default=DEFAULT_IN)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--validate-only", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.src.exists():
        print(f"rig_to_luau: {args.src} does not exist yet (the Blender worker writes it)", file=sys.stderr)
        return 1
    text, errors, warnings = convert(args.src)
    for w in warnings:
        print(f"warning: {w}")
    if text is None:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"rig_to_luau: {args.src} is invalid ({len(errors)} error(s)); nothing written", file=sys.stderr)
        return 1
    if args.validate_only:
        print(f"rig_to_luau: {args.src} is valid ({len(warnings)} warning(s))")
        return 0
    if args.check:
        if not args.out.exists() or args.out.read_text() != text:
            print(f"rig_to_luau: {args.out} is out of date: run python3 games/game-001/art/char_kit/rig_to_luau.py", file=sys.stderr)
            return 1
        print(f"rig_to_luau: {args.out} is up to date")
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)
    print(f"rig_to_luau: wrote {args.out} ({len(text.splitlines())} lines, {len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
