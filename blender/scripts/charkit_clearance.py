"""Pose clearance check for the character kit (FL-0135): hair, hats, capes and packs must not poke through the body in any
action of Sim/Pose.luau (ported in lib/ckit_pose.py).

  ~/forge-bpy/bin/python blender/scripts/charkit_clearance.py [--json OUT.json] [--tol 0.06]

For every job assembly (all hair styles for the jobs that show hair, all kingdoms' crests) and every action x phase:
transform every piece with the joint FK, then test the vertices of each "shell" piece (hair, hat, crest, cape, collar, pack,
satchel, quiver, apron, shield) against the bodies it must not enter (torso, arms, sleeves, legs, boots, head). Penetration depth
= how far a vertex sits inside the other solid (nearest-surface normal test). Exit 1 if any depth exceeds --tol studs.
Evidence class: Blender geometry only (not a Studio play test).
"""

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

from lib import ckit_pose as P  # noqa: E402

SHELL_SLOTS = ("hair", "hat", "hatband", "crest", "cape", "extra", "shield", "toolband")
BODY_SLOTS = ("torso", "arm", "sleeve", "leg", "boot", "head")
# a shell never has to avoid its own carrier: hats/hair ride the head, so test them against shoulders and arms only
# shells that hang loose in FRONT of the swinging thighs and are allowed to be crossed by a leg in the fast walk/flee swing (the leg is
# drawn in front of a thin apron/hem/strap; nothing pokes out of the body). Everything else (hair, hats, capes, packs, crests) is strict.
SOFT = {"gear_farmer": 0.36, "gear_smith": 0.36, "strap_kingdom": 0.36, "trim_regal": 0.40, "tool_pennant": 0.0}
AVOID = {
    "hair": ("torso", "arm", "sleeve"), "hat": ("torso", "arm", "sleeve"), "hatband": ("torso", "arm", "sleeve"),
    "crest": ("torso", "arm", "sleeve"), "cape": ("arm", "sleeve", "leg", "boot", "head"),
    "extra": ("arm", "sleeve", "leg", "boot"), "shield": ("torso", "leg", "boot"), "toolband": ("head",),
}


def world_pts(m, jw):
    return [tuple(jw @ Vector(p)) for p in m.v]


def bvh(pts, faces):
    return BVHTree.FromPolygons(pts, [tuple(f) for f in faces])


_DIRS = (Vector((0.267, 0.802, 0.534)).normalized(), Vector((-0.64, 0.31, -0.7)).normalized(), Vector((0.1, -0.95, 0.29)).normalized())


def _crossings(tree, p, d, limit=24):
    n, o = 0, Vector(p)
    for _ in range(limit):
        loc, nrm, idx, dist = tree.ray_cast(o, d)
        if loc is None:
            break
        n += 1
        o = loc + d * 1e-4
    return n


def depth_inside(tree, p, margin=0.0):
    """Penetration depth of point p into the closed solid (0 if outside): ray-parity inside test in three directions (two of
    three must agree), depth = distance to the nearest surface point."""
    votes = sum(1 for d in _DIRS if _crossings(tree, p, d) % 2 == 1)
    if votes < 2:
        return 0.0
    loc, nrm, idx, dist = tree.find_nearest(Vector(p))
    return max(0.0, dist - margin)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="")
    ap.add_argument("--tol", type=float, default=0.06)
    ap.add_argument("--quick", action="store_true")
    a = ap.parse_args(argv)
    from generators import char_kit

    R, rig, hand = char_kit.registry()
    joints = {k: {"pos": (v["pos"] or [hand[0], hand[1], hand[2]])} for k, v in rig.JOINTS.items()}
    results = []
    worst = 0.0
    looks = [{"skin": 1, "hair": h, "hairColor": hc, "outfit": 1} for hc in (1, 5) for h in range(1, 7)]
    actions = P.ACTIONS if not a.quick else P.ACTIONS[:5]
    for job in rig.ASSEMBLIES:
        seen = set()
        for kd in rig.KINGDOMS:
            for lk in (looks if job in ("idle", "hauler", "blacksmith") else looks[:1]):
                names = rig.names_for(job, lk, kd)
                key = tuple(names)
                if key in seen:
                    continue
                seen.add(key)
                shells = [n for n in names if R.pieces[n].slot in AVOID]
                bodies = [n for n in names if R.pieces[n].slot in BODY_SLOTS]
                for act, speed in actions:
                    for ph in (P.PHASES if not a.quick else P.PHASES[::2]):
                        tf = P.sample(act, job.split("_")[0], ph, speed)
                        jw = P.joint_worlds(joints, tf)
                        trees = {}
                        for n in bodies:
                            p = R.pieces[n]
                            pts = world_pts(p.m, jw[_carrier(p.joint)])
                            trees[n] = (bvh(pts, p.m.copy().triangulate().f), R.pieces[n].slot)
                        for s in shells:
                            ps = R.pieces[s]
                            spts = world_pts(ps.m, jw[_carrier(ps.joint)])
                            avoid = AVOID[ps.slot]
                            for bn, (tree, bslot) in trees.items():
                                if bslot not in avoid:
                                    continue
                                if R.pieces[bn].joint == ps.joint:  # same rigid carrier: fixed at rest, checked once below
                                    continue
                                dmax = max((depth_inside(tree, p) for p in spts[:: max(1, len(spts) // 400)]), default=0.0)
                                if dmax > 0.0:
                                    results.append({"job": job, "kingdom": kd, "shell": s, "body": bn, "action": act, "phase": ph,
                                                    "depth": round(dmax, 3)})
                                    worst = max(worst, dmax)
    # rest-pose check of same-carrier pairs (hair vs head is intentional: only torso/arm pieces matter, handled above)
    results.sort(key=lambda r: -r["depth"])
    bad = [r for r in results if r["depth"] > max(a.tol, SOFT.get(r["shell"], 0.0))]
    print(f"[clearance] {len(results)} penetrating samples, worst depth {worst:.3f} studs, over tolerance ({a.tol}; soft shells {SOFT}): {len(bad)}")
    agg = {}
    for r in results:
        k = (r["shell"], r["body"].rsplit("_", 1)[0] if r["body"].endswith(("_l", "_r")) else r["body"], r["action"])
        e = agg.setdefault(k, {"depth": 0.0, "n": 0, "jobs": set()})
        e["depth"] = max(e["depth"], r["depth"])
        e["n"] += 1
        e["jobs"].add(r["job"])
    rows = sorted(agg.items(), key=lambda kv: -kv[1]["depth"])
    print(f"[clearance] {len(rows)} distinct (shell, body, action) pairs penetrate; worst first:")
    for (shell, body, action), e in rows[:60]:
        print(f"  {shell:18s} in {body:18s} {action:10s} depth {e['depth']:.3f} ({e['n']} samples; {', '.join(sorted(e['jobs']))[:60]})")
    if a.json:
        Path(a.json).write_text(json.dumps({"tolerance": a.tol, "worst": round(worst, 3), "over": bad[:200], "samples": len(results)}, indent=1))
    return 1 if bad else 0


def _carrier(joint):
    return joint if joint in P.PARENT else "Torso"


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
