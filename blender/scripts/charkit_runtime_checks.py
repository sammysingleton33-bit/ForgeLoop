"""Python port of the structural checks the Kit runtime specs make on the committed kit (FL-0135), so the Blender side can iterate
without Lune. The authoritative oracle stays the Lune specs (KitCharacterMesh, KitCharacterMeshPose, KitCharacterMeshImport):

  ~/forge-bpy/bin/python -I blender/scripts/charkit_runtime_checks.py [--rig R] [--json OUT]

Per case of the specs (citizen jobs idle / farmer / woodcutter / miner / builder / hauler with corner and seeded looks, soldiers and
governors in every kingdom) it measures, from rig.json only:
  torso   the base torso piece starts at the hips (y 2.2 +- 0.06), ends at the neck joint (+- 0.1), shoulders and neck as Pose expects
  height  the highest body point (everything but the Tool, Hair and slot-tool parts) stays under 7.2 studs
  fall    the lowest corner of the torso box in the "dead" pose stays above -0.25
  tool    a posed hand tool keeps >= 0.1 stud (separating-axis box distance) from the head box in every action, and no closer to the
          headwear than at rest (idle), over 40 samples per cycle
Prints every violation with its margin; exit 1 on any. Blender-geometry evidence only (boxes, like the Lune specs), not Studio.
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402,F401  (brings mathutils)
from mathutils import Matrix, Vector  # noqa: E402

from lib import ckit_pose as P  # noqa: E402
from lib import ckit_resolve  # noqa: E402

ACTIONS = ("idle", "walk", "carry", "work", "fight", "celebrate", "flee")
STEPS = 40
MIN_CLEARANCE = 0.1
KINGDOMS = ("crimson", "azure", "emerald", "gold")
JOBS = ("idle", "farmer", "woodcutter", "miner", "builder", "hauler")


def seeded_look(seed):
    s = seed
    out = {}
    for k, n in (("skin", 6), ("hair", 6), ("hairColor", 8), ("outfit", 6)):
        s = (s * 16807) % 2147483647
        out[k] = s % n + 1
    return out


def corner_looks():
    return [{"skin": s, "hair": h, "hairColor": hc, "outfit": o} for s in (1, 6) for h in (1, 6) for hc in (1, 8) for o in (1, 6)]


def cases():
    out = []
    for job in JOBS:
        out.append((f"citizen/{job} default", "citizen", job, None, "crimson"))
        for lk in corner_looks():
            out.append((f"citizen/{job} {lk}", "citizen", job, lk, "crimson"))
        for seed in range(1, 7):
            out.append((f"citizen/{job} seed {seed}", "citizen", job, seeded_look(seed), KINGDOMS[seed % 4]))
    for i, kd in enumerate(KINGDOMS, 1):
        out.append((f"soldier {kd}", "soldier", "soldier", None, kd))
        out.append((f"soldier {kd} seed {10 + i}", "soldier", "soldier", seeded_look(10 + i), kd))
        out.append((f"drafted {kd}", "citizen", "soldier", seeded_look(20 + i), kd))
        out.append((f"governor/idle {kd}", "governor", "idle", seeded_look(30 + i), kd))
        out.append((f"governor {kd}", "governor", "governor", None, kd))
    return out


def box_box(cf_a, size_a, cf_b, size_b):
    """Separating-axis clearance of two boxes (same maths as MeshKit.boxBox): positive = free space."""
    ra_ax = [cf_a.col[i].to_3d() for i in range(3)]
    rb_ax = [cf_b.col[i].to_3d() for i in range(3)]
    ha = [s / 2 for s in size_a]
    hb = [s / 2 for s in size_b]
    d = cf_b.to_translation() - cf_a.to_translation()
    cands = [a for a in ra_ax] + [b for b in rb_ax]
    for a in ra_ax:
        for b in rb_ax:
            c = a.cross(b)
            if c.length > 1e-6:
                cands.append(c.normalized())
    best = -math.inf
    for ax in cands:
        ra = sum(ha[i] * abs(ra_ax[i].dot(ax)) for i in range(3))
        rb = sum(hb[i] * abs(rb_ax[i].dot(ax)) for i in range(3))
        best = max(best, abs(d.dot(ax)) - ra - rb)
    return best


def carrier(joint):
    return joint if joint in P.PARENT else "Torso"


def posed(doc, ids, tf):
    jw = P.joint_worlds(doc["joints"], tf)
    out = {}
    for pid in ids:
        p = doc["pieces"][pid]
        out[pid] = jw[carrier(p["joint"])] @ Matrix.Translation(Vector(p["bbox_center"]))
    return out


def corners(cf, size):
    h = [s / 2 for s in size]
    return [cf @ Vector((sx * h[0], sy * h[1], sz * h[2])) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]


def hand_tool_case(kind, job, look, label):
    """The rigs KitCharacterMeshPose.spec measures: farmer / woodcutter / miner / builder (default and seeded looks 1..6), soldiers,
    governors (job 'governor')."""
    if kind == "citizen":
        return job in ("farmer", "woodcutter", "miner", "builder") and (look is None or "seed" in label or "default" in label)
    return job in ("soldier", "governor")


def check(doc, tool_only=False):
    """-> (violations, worst) for a rig.json document."""
    pieces = doc["pieces"]
    bad, worst = [], {"tool_head": math.inf, "fall": math.inf, "height": -math.inf}
    for label, kind, job, look, kd in cases():
        key = "governor" if kind == "governor" else ("soldier" if kind == "soldier" or job == "soldier" else job)
        ids = ckit_resolve.resolve_assembly(doc["assemblies"], pieces, key, look, kd)
        base = {pieces[i]["joint"]: i for i in ids if pieces[i].get("weld_to") is None}
        torso = pieces[base["Torso"]]
        if not tool_only:
            t_lo = torso["bbox_center"][1] - torso["size"][1] / 2
            t_hi = torso["bbox_center"][1] + torso["size"][1] / 2
            if abs(t_lo - 2.2) > 0.06:
                bad.append(f"{label}: torso piece {base['Torso']} starts at y {t_lo:.2f}, hips are 2.2")
            if abs(t_hi - doc["joints"]["Head"]["pos"][1]) > 0.1:
                bad.append(f"{label}: torso top {t_hi:.2f} is not at the neck {doc['joints']['Head']['pos'][1]}")
            # height: everything but the Tool part(s), Hair and slot-tool parts
            top = -math.inf
            for i in ids:
                p = pieces[i]
                if p["joint"] in ("Tool", "TorsoTool") or p["slot"] in ("tool", "hair"):
                    continue
                top = max(top, p["bbox_center"][1] + p["size"][1] / 2)
            worst["height"] = max(worst["height"], top)
            if top >= 7.2:
                bad.append(f"{label}: highest body point {top:.2f} >= 7.2")
            # death fall: lowest corner of the torso box
            tf = P.sample("dead", job, 0.0, 0.0)
            cf = posed(doc, [base["Torso"]], tf)[base["Torso"]]
            low = min(c.y for c in corners(cf, torso["size"]))
            worst["fall"] = min(worst["fall"], low)
            if low <= -0.25:
                bad.append(f"{label}: death fall lowest torso corner {low:.4f} <= -0.25")
        # hand tool clearance
        tool_ids = [i for i in ids if pieces[i]["joint"] == "Tool"]
        if not tool_ids or not hand_tool_case(kind, job, look, label):
            continue
        head_id = base["Head"]
        hat_ids = [i for i in ids if pieces[i]["joint"] == "Head" and i != head_id]

        def worst_for(action):
            speed = 12.0 if action in ("walk", "carry", "flee") else 0.0
            lo_head, lo_hat = math.inf, math.inf
            for step in range(STEPS):
                tfm = P.sample(action, job, step / STEPS, speed)
                world = posed(doc, tool_ids + [head_id] + hat_ids, tfm)
                for t in tool_ids:
                    lo_head = min(lo_head, box_box(world[t], pieces[t]["size"], world[head_id], pieces[head_id]["size"]))
                    for h in hat_ids:
                        lo_hat = min(lo_hat, box_box(world[t], pieces[t]["size"], world[h], pieces[h]["size"]))
            return lo_head, lo_hat

        _, idle_hat = worst_for("idle")
        floor = min(MIN_CLEARANCE, idle_hat)
        for act in ACTIONS:
            hd, ht = worst_for(act)
            worst["tool_head"] = min(worst["tool_head"], hd)
            if hd < MIN_CLEARANCE:
                bad.append(f"{label} {act}: only {hd:.3f} studs between tool and head")
            if ht < floor - 1e-6:
                bad.append(f"{label} {act}: {ht:.3f} between tool and headwear, below {floor:.3f}")
    return sorted(set(bad)), worst


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--rig", default=str(REPO / "games/game-001/art/char_kit/rig.json"))
    ap.add_argument("--json", default="")
    ap.add_argument("--tool-only", action="store_true")
    a = ap.parse_args(argv)
    doc = json.loads(Path(a.rig).read_text())
    uniq, worst = check(doc, a.tool_only)
    for b in uniq:
        print("FAIL", b)
    print(f"[runtime checks] {len(uniq)} violations; worst tool-head {worst['tool_head']:.3f}, lowest fall corner {worst['fall']:.3f}, "
          f"highest body point {worst['height']:.2f}")
    if a.json:
        Path(a.json).write_text(json.dumps({"violations": uniq, "worst": worst}, indent=1))
    return 1 if uniq else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:]))
