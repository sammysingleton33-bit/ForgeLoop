"""Cameras and scene helpers for the character-kit renders (FL-0135): Kit.portrait framing, ~40-stud gameplay view and
the 170-stud aerial view of the earlier crowd renders. All positions are ROBLOX world coordinates (x, y, z); the
preview scene maps them to Blender with (x, y, z) -> (-x, z, y) like blender/scripts/render_aerial.py.
"""

import math

from mathutils import Matrix, Vector

from . import rig


def r2b(v):
    return Vector((-v[0], v[2], v[1]))


def look_at(cam, eye_r, target_r):
    cam.location = r2b(eye_r)
    rig.aim(cam, r2b(target_r))


def set_fov(cam, fov, aspect_w=1, aspect_h=1):
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(fov)


def portrait(cam, top, half_width, cx=0.0, cz=0.0, shoulders=3.9, fov=30.0):
    """Kit/Portrait.luau framing: head and shoulders for a square viewport, camera 6 degrees above the face."""
    headroom, chest, margin = 0.45, 1.15, 1.08
    top = top + headroom
    half = max((top - (shoulders - chest)) / 2, half_width) * margin
    centre = (cx, top - half, cz)
    dist = half / math.tan(math.radians(fov) / 2) + 1.0
    p = math.radians(6)
    eye = (cx, centre[1] + math.sin(p) * dist, cz - math.cos(p) * dist)
    set_fov(cam, fov)
    look_at(cam, eye, centre)
    return dist


def gameplay(cam, target, dist=40.0, elev_deg=14.0, az_deg=0.0, fov=70.0):
    """Camera `dist` studs from `target` (Roblox coords), elev above the horizon, looking along +z (az 0)."""
    a, e = math.radians(az_deg), math.radians(elev_deg)
    fwd = (math.sin(a), math.cos(a))
    eye = (target[0] - fwd[0] * dist * math.cos(e), target[1] + dist * math.sin(e), target[2] - fwd[1] * dist * math.cos(e))
    set_fov(cam, fov)
    look_at(cam, eye, target)


def aerial(cam, target, dist=170.0, pitch_deg=50.0, az_deg=0.0, fov=70.0):
    """RulerCameraController.aerialCFrame: `dist` from the focus along a ray `pitch` degrees below the horizon."""
    gameplay(cam, target, dist, pitch_deg, az_deg, fov)


def roblox_matrix(x, y, z, yaw_deg=0.0):
    """Roblox-space 4x4 placement (translation + yaw about +y)."""
    a = math.radians(yaw_deg)
    c, s = math.cos(a), math.sin(a)
    return Matrix(((c, 0, s, x), (0, 1, 0, y), (-s, 0, c, z), (0, 0, 0, 1)))
