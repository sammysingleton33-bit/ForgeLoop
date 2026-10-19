"""Python port of Sim/Pose.luau (FORGE-04's procedural animation) + forward kinematics over the kit rig, used to check that
capes and hair never poke through the body in any action (FL-0135). Read-only mirror of the Luau maths: if Pose.luau
changes, update this port (tests/test_pose_port.py compares the samples against the documented limits).

Joint transform semantics (Motor6D.Transform with axis-aligned joint frames, pivot at the joint position p):
    world(piece on joint J) = world(parent joint) * T(p) * Transform_J * T(-p)
"""

import math

from mathutils import Matrix, Vector

JOINTS = ("Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool")
LIMITS = {"Torso": 90, "Head": 30, "LeftArm": 150, "RightArm": 150, "LeftLeg": 90, "RightLeg": 90, "Tool": 45}
WALK_REF_SPEED = 12.0
STRIDE = 6.0
DEAD_LIFT = -1.7
WORK_STYLE = {"woodcutter": "chop", "miner": "mine", "builder": "hammer", "farmer": "harvest"}
CHEERS_EMPTY_HANDED = {"idle": True, "hauler": True}
TOOL_CHEER_RAISE, TOOL_TIP_BACK, TOOL_TIP_OUT = 55.0, 40.0, 20.0
I4 = Matrix.Identity(4)


def rx(d):
    return Matrix.Rotation(math.radians(d), 4, "X")


def ry(d):
    return Matrix.Rotation(math.radians(d), 4, "Y")


def rz(d):
    return Matrix.Rotation(math.radians(d), 4, "Z")


def _clamp01(x):
    return max(0.0, min(1.0, x))


def work_style(job):
    return WORK_STYLE.get(job, "generic")


def _stride(speed):
    return _clamp01(speed / WALK_REF_SPEED)


def _torso(lean, twist, lift):
    return Matrix.Translation((0, lift, 0)) @ ry(twist) @ rx(-lean)


def _legs(out, swing, lean, spread=0.0):
    out["LeftLeg"] = rx(swing + lean) @ rz(-spread)
    out["RightLeg"] = rx(-swing + lean) @ rz(spread)


def sample(action, job, phase, speed=0.0):
    """Joint transforms (4x4, rotation + Torso lift) for an action at `phase` (cycles) and horizontal `speed`."""
    o = {j: I4.copy() for j in JOINTS}
    p = phase % 1.0
    ang = math.tau * p
    s, c = math.sin(ang), math.cos(ang)
    c2 = math.cos(2 * ang)
    if action in ("walk", "flee"):
        max_swing, lean = (40, 0) if action == "walk" else (50, 12)
        k = _stride(speed)
        swing = max_swing * k * s
        o["Torso"] = _torso(lean * k, 4 * k * s, 0.1 * k * (1 - c2) / 2)
        o["Head"] = rx(lean * k * 0.5)
        o["LeftArm"] = rx(-0.8 * swing)
        o["RightArm"] = rx(0.8 * swing)
        _legs(o, swing, lean * k)
    elif action == "carry":
        k = _stride(speed)
        swing = 35 * k * s
        o["Torso"] = _torso(0, 0, 0.08 * k * (1 - c2) / 2)
        o["LeftArm"] = rx(70) @ rz(10)
        o["RightArm"] = rx(70) @ rz(-10)
        _legs(o, swing, 0)
    elif action == "work":
        st = work_style(job)
        lean, twist = 0.0, 0.0
        if st == "chop":
            lean, twist = 5 + 5 * c, -10 * s
            o["RightArm"], o["LeftArm"], o["Tool"] = rx(55 + 35 * c), rx(40 + 25 * c), rx(15 * c)
        elif st == "mine":
            lean = 10 - 8 * c
            o["RightArm"], o["LeftArm"] = rx(60 + 30 * c), rx(60 + 30 * c)
        elif st == "hammer":
            lean = 8.0
            o["RightArm"], o["LeftArm"], o["Tool"] = rx(50 + 30 * c), rx(25), rx(10 * c)
        elif st == "harvest":
            lean = 25 + 8 * s
            o["RightArm"], o["LeftArm"] = rx(45 + 15 * c), rx(45 + 15 * c)
        else:
            lean = 5.0
            o["RightArm"], o["LeftArm"] = rx(30 + 10 * s), rx(30 - 10 * s)
        o["Torso"] = _torso(lean, twist, 0)
        o["Head"] = rx(-0.3 * lean)
        _legs(o, 0, lean)
    elif action == "fight":
        o["Torso"] = _torso(5, 15 * s, 0)
        o["RightArm"], o["LeftArm"] = rx(45 + 45 * s), rx(30)
        _legs(o, 0, 5, 8)
    elif action == "celebrate":
        raise_ = 140 + 10 * s
        o["Torso"] = _torso(0, 0, 0.3 * (1 - c) / 2)
        o["Head"] = rx(10)
        o["LeftArm"] = rz(-raise_)
        if CHEERS_EMPTY_HANDED.get(job):
            o["RightArm"] = rz(raise_)
        else:
            o["RightArm"] = rz(TOOL_CHEER_RAISE + 10 * s)
            o["Tool"] = rx(-TOOL_TIP_BACK) @ rz(-TOOL_TIP_OUT)
        _legs(o, 0, 0)
    elif action == "dead":
        o["Torso"] = Matrix.Translation((0, DEAD_LIFT, 0)) @ rx(90)
        o["LeftArm"], o["RightArm"] = rz(-20), rz(20)
        o["LeftLeg"], o["RightLeg"] = rz(-8), rz(8)
    else:  # idle
        o["Head"] = ry(6 * s) @ rx(2 * c)
        o["LeftArm"] = rz(-(3 + 2 * s))
        o["RightArm"] = rz(3 + 2 * s)
    return o


ACTIONS = [("idle", 0.0), ("walk", 12.0), ("walk", 6.0), ("carry", 8.0), ("flee", 14.0), ("work", 0.0), ("fight", 0.0),
           ("celebrate", 0.0), ("dead", 0.0)]
PHASES = (0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875)

# joint -> its parent joint (None = Root)
PARENT = {"Torso": None, "Head": "Torso", "LeftArm": "Torso", "RightArm": "Torso", "LeftLeg": "Torso", "RightLeg": "Torso",
          "TorsoTool": "Torso", "Tool": "RightArm"}


def joint_worlds(joints, tf):
    """World matrix per joint for transforms `tf` ({joint: 4x4}); `joints` = rig.json joints ({name: {pos}})."""
    out = {}

    def world(j):
        if j in out:
            return out[j]
        par = PARENT[j]
        base = world(par) if par else I4
        p = Vector(joints[j]["pos"])
        t = tf.get(j, I4) if j != "TorsoTool" else I4
        out[j] = base @ Matrix.Translation(p) @ t @ Matrix.Translation(-p)
        return out[j]

    for j in PARENT:
        world(j)
    return out


def apply_to_points(pts, mat):
    return [tuple(mat @ Vector(p)) for p in pts]
