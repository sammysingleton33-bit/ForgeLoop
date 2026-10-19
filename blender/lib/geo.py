"""Geometry building blocks.

A `Piece` is plain Python geometry (verts + polygon index tuples) with a palette colour.
Generators create pieces with the primitives below, transform/deform them, and hand them
to a `Builder` (lib/asset.py), which merges everything into ONE mesh with palette UVs.

Conventions: Blender Z-up, 1 Blender unit = 1 Roblox stud, assets stand on z=0 and are
centred on x=y=0 (pivot at base centre). Faces are wound counter-clockwise seen from
outside; Builder recalculates normals per shell anyway.
"""

import math

import bmesh
import mathutils
from mathutils import Matrix, Vector
from mathutils import noise as mnoise

TAU = math.tau


class Piece:
    __slots__ = ("verts", "faces", "color", "face_colors", "face_smooth", "grad", "tint", "smooth", "tag")

    def __init__(self, verts, faces, color="stone", grad=None, tint=None, smooth=False, tag=""):
        self.verts = [Vector(v) for v in verts]
        self.faces = [tuple(f) for f in faces]
        self.color = color
        self.face_colors = None  # optional per-face palette names (len == len(faces))
        self.face_smooth = None  # optional per-face smooth flags (overrides `smooth`)
        self.grad = grad  # see asset.Builder._v01
        self.tint = tint  # 0..1 position across the swatch (cool..warm); None = random per piece
        self.smooth = smooth
        self.tag = tag  # free label used by structural checks (e.g. "branch", "leaf")

    # ---- transforms (return self for chaining) ----
    def transform(self, m):
        m = Matrix(m)
        if len(m) == 3:
            m = m.to_4x4()
        self.verts = [m @ v for v in self.verts]
        return self

    def move(self, x=0.0, y=0.0, z=0.0):
        d = Vector((x, y, z))
        self.verts = [v + d for v in self.verts]
        return self

    def scale(self, sx, sy=None, sz=None):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        self.verts = [Vector((v.x * sx, v.y * sy, v.z * sz)) for v in self.verts]
        return self

    def rotate(self, angle, axis="Z"):
        return self.transform(Matrix.Rotation(angle, 4, axis))

    def copy(self):
        p = Piece(self.verts, self.faces, self.color, self.grad, self.tint, self.smooth, self.tag)
        p.face_colors = list(self.face_colors) if self.face_colors else None
        p.face_smooth = list(self.face_smooth) if self.face_smooth else None
        return p

    def paint(self, color=None, grad=None, tint=None, smooth=None, tag=None):
        if color is not None:
            self.color = color
        if grad is not None:
            self.grad = grad
        if tint is not None:
            self.tint = tint
        if smooth is not None:
            self.smooth = smooth
        if tag is not None:
            self.tag = tag
        return self

    def bounds(self):
        xs = [v.x for v in self.verts]
        ys = [v.y for v in self.verts]
        zs = [v.z for v in self.verts]
        return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))

    @property
    def tris(self):
        return sum(len(f) - 2 for f in self.faces)

    # ---- deformations ----
    def jitter(self, rng, amount, axes=(1, 1, 1)):
        """Random per-vertex offset (hand-made wobble). Shared positions stay shared."""
        cache = {}
        out = []
        for v in self.verts:
            k = (round(v.x, 4), round(v.y, 4), round(v.z, 4))
            if k not in cache:
                cache[k] = Vector((rng.uniform(-amount, amount) * axes[0],
                                   rng.uniform(-amount, amount) * axes[1],
                                   rng.uniform(-amount, amount) * axes[2]))
            out.append(v + cache[k])
        self.verts = out
        return self

    def noise_displace(self, amount, freq=1.0, seed=0.0, center=None, radial=True):
        """Coherent noise displacement. radial=True pushes along the direction from `center`."""
        c = Vector(center) if center is not None else sum(self.verts, Vector()) / max(1, len(self.verts))
        off = Vector((seed * 13.7, seed * 7.3, seed * 3.1))
        out = []
        for v in self.verts:
            n = mnoise.noise(v * freq + off)
            if radial:
                d = v - c
                d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
                out.append(v + d * (n * amount))
            else:
                nv = mnoise.noise_vector(v * freq + off)
                out.append(v + nv * amount)
        self.verts = out
        return self

    def taper(self, z0, z1, s0=1.0, s1=0.8, center=(0.0, 0.0)):
        """Scale XY linearly with height between z0 (s0) and z1 (s1)."""
        cx, cy = center
        out = []
        for v in self.verts:
            t = 0.0 if z1 == z0 else min(1.0, max(0.0, (v.z - z0) / (z1 - z0)))
            s = s0 + (s1 - s0) * t
            out.append(Vector((cx + (v.x - cx) * s, cy + (v.y - cy) * s, v.z)))
        self.verts = out
        return self

    def bend(self, fn):
        """Arbitrary per-vertex function Vector -> Vector."""
        self.verts = [Vector(fn(v.copy())) for v in self.verts]
        return self


# ---------------------------------------------------------------- bmesh round trip

def _to_bm(piece):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in piece.verts]
    for f in piece.faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass  # duplicate face: skip
    bm.verts.ensure_lookup_table()
    return bm


def _from_bm(bm, like):
    bm.verts.index_update()
    verts = [v.co.copy() for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    p = Piece(verts, faces, like.color, like.grad, like.tint, like.smooth, like.tag)
    bm.free()
    return p


def bevel(piece, offset, segments=1, min_angle_deg=25.0):
    """Chamfer sharp edges (catches light: the main trick that stops boxes looking primitive)."""
    bm = _to_bm(piece)
    bm.normal_update()
    lim = math.radians(min_angle_deg)
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    return _from_bm(bm, piece)


def recalc_normals(piece):
    bm = _to_bm(piece)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return _from_bm(bm, piece)


def subdivide(piece, cuts=1, smooth=0.0):
    bm = _to_bm(piece)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=cuts, use_grid_fill=True, smooth=smooth)
    return _from_bm(bm, piece)


# ---------------------------------------------------------------- primitives

def box(sx, sy, sz, color="stone", base=True, **kw):
    """Axis-aligned box sx*sy*sz. base=True: sits on z=0; else centred."""
    x, y = sx / 2, sy / 2
    z0, z1 = (0.0, sz) if base else (-sz / 2, sz / 2)
    v = [(-x, -y, z0), (x, -y, z0), (x, y, z0), (-x, y, z0),
         (-x, -y, z1), (x, -y, z1), (x, y, z1), (-x, y, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return Piece(v, f, color, **kw)


def ring(r, seg, z=0.0, phase=0.0, rx=None):
    rx = r if rx is None else rx
    return [Vector((math.cos(phase + TAU * i / seg) * rx, math.sin(phase + TAU * i / seg) * r, z)) for i in range(seg)]


def lathe(profile, seg=8, color="stone", phase=None, cap_bottom=True, cap_top=True, **kw):
    """Revolve [(radius, z), ...] (bottom to top) around Z. radius 0 at an end makes a pole."""
    phase = (math.pi / seg) if phase is None else phase
    verts, faces, rings = [], [], []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([len(verts)])
            verts.append(Vector((0, 0, z)))
        else:
            idx = list(range(len(verts), len(verts) + seg))
            verts.extend(ring(r, seg, z, phase))
            rings.append(idx)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(seg):
                faces.append((a[0], b[i], b[(i + 1) % seg])[::1])
        elif len(b) == 1:
            for i in range(seg):
                faces.append((a[i], a[(i + 1) % seg], b[0]))
        else:
            for i in range(seg):
                j = (i + 1) % seg
                faces.append((a[i], a[j], b[j], b[i]))
    if cap_bottom and len(rings[0]) > 1:
        faces.append(tuple(reversed(rings[0])))
    if cap_top and len(rings[-1]) > 1:
        faces.append(tuple(rings[-1]))
    return Piece(verts, faces, color, **kw)


def cylinder(r_bottom, r_top, h, seg=8, color="stone", **kw):
    return lathe([(r_bottom, 0.0), (r_top, h)], seg, color, **kw)


def cone(r, h, seg=8, color="stone", **kw):
    return lathe([(r, 0.0), (0.0, h)], seg, color, **kw)


def prism(poly, depth, color="stone", axis="Y", **kw):
    """Extrude a 2D polygon (CCW, in the plane perpendicular to `axis`) by `depth`, centred.

    axis='Y': poly is (x, z) and depth runs along Y  -> gables, arches, doors.
    axis='Z': poly is (x, y) and depth runs up from z=0 -> floor plans.
    axis='X': poly is (y, z) and depth runs along X.
    """
    n = len(poly)
    verts = []
    if axis == "Y":
        for x, z in poly:
            verts.append((x, depth / 2, z))
        for x, z in poly:
            verts.append((x, -depth / 2, z))
    elif axis == "Z":
        for x, y in poly:
            verts.append((x, y, 0.0))
        for x, y in poly:
            verts.append((x, y, depth))
    else:
        for y, z in poly:
            verts.append((-depth / 2, y, z))
        for y, z in poly:
            verts.append((depth / 2, y, z))
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    return recalc_normals(Piece(verts, faces, color, **kw))


def loft(poly, ys, color="stone", deform=None, cap=True, **kw):
    """Extrude a closed 2D profile (x, z) through several stations along Y.
    `deform(ring_index, y, x, z) -> (x, y, z)` lets callers sag/wave each station."""
    rings = []
    for ri, y in enumerate(ys):
        rings.append([tuple(deform(ri, y, x, z)) if deform else (x, y, z) for x, z in poly])
    return loft_rings(rings, color, cap, **kw)


def loft_rings(rings_pts, color="stone", cap=True, **kw):
    """Skin a list of rings (equal point counts) into a closed solid. Caps are flagged flat
    (face_smooth False) so smooth-shaded lofts keep crisp ends."""
    n = len(rings_pts[0])
    verts, faces = [], []
    for r in rings_pts:
        verts.extend(r)
    rings = len(rings_pts)
    for r in range(rings - 1):
        a, b_ = r * n, (r + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b_ + j, b_ + i))
    smooth_flags = [True] * len(faces)
    if cap:
        faces.append(tuple(range(n)))
        faces.append(tuple(range((rings - 1) * n + n - 1, (rings - 1) * n - 1, -1)))
        smooth_flags += [False, False]
    p = recalc_normals(Piece(verts, faces, color, **kw))
    p.face_smooth = smooth_flags
    return p


def icosphere(radius=1.0, subdiv=1, color="leaf_mid", **kw):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return _from_bm(bm, Piece([], [], color, **kw))


def uvsphere(radius=1.0, seg=8, rings=5, color="leaf_mid", **kw):
    prof = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        prof.append((math.cos(a) * radius if 0 < i < rings else 0.0, math.sin(a) * radius))
    return lathe(prof, seg, color, **kw)


def tube(points, radii, seg=6, color="bark", cap_start=True, cap_end=True, twist=0.0, **kw):
    """Sweep a circle along a polyline (parallel-transport frames). radii per point."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    tangents = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        tangents.append(t.normalized() if t.length > 1e-9 else Vector((0, 0, 1)))
    normal = tangents[0].orthogonal().normalized()
    verts, faces, rings_ = [], [], []
    for i, (p, t) in enumerate(zip(pts, tangents)):
        normal = (normal - t * normal.dot(t))
        normal = normal.normalized() if normal.length > 1e-9 else t.orthogonal().normalized()
        bin_ = t.cross(normal)
        r = radii[i]
        idx = []
        for k in range(seg):
            a = TAU * k / seg + twist * i
            if r <= 1e-6:
                break
            idx.append(len(verts))
            verts.append(p + (normal * math.cos(a) + bin_ * math.sin(a)) * r)
        if not idx:
            idx = [len(verts)]
            verts.append(p.copy())
        rings_.append(idx)
    for a, b in zip(rings_, rings_[1:]):
        if len(b) == 1 and len(a) > 1:
            for k in range(seg):
                faces.append((a[k], a[(k + 1) % seg], b[0]))
        elif len(a) > 1 and len(b) > 1:
            for k in range(seg):
                j = (k + 1) % seg
                faces.append((a[k], a[j], b[j], b[k]))
    if cap_start and len(rings_[0]) > 1:
        faces.append(tuple(reversed(rings_[0])))
    if cap_end and len(rings_[-1]) > 1:
        faces.append(tuple(rings_[-1]))
    return recalc_normals(Piece(verts, faces, color, **kw))


def merge(pieces, color=None):
    """Concatenate pieces into one (keeps per-face colours)."""
    verts, faces, fcols = [], [], []
    for p in pieces:
        o = len(verts)
        verts.extend(p.verts)
        faces.extend(tuple(i + o for i in f) for f in p.faces)
        fcols.extend(p.face_colors or [p.color] * len(p.faces))
    first = pieces[0]
    out = Piece(verts, faces, color or first.color, first.grad, first.tint, first.smooth, first.tag)
    out.face_colors = fcols
    return out


# ---------------------------------------------------------------- composite helpers

def gable_roof(width, depth, rise, thickness=0.6, overhang=1.0, color="thatch", ridge=True, **kw):
    """Thick two-slope roof along Y. width = span (X) of the walls it covers, rise = height
    above eaves. Returns a list of pieces (two slabs + optional ridge cap)."""
    w = width / 2 + overhang
    d = depth + 2 * overhang
    slope_len = math.hypot(w, rise)
    ang = math.atan2(rise, w)
    pieces = []
    for side in (-1, 1):
        slab = box(slope_len + thickness * 0.5, d, thickness, color, base=False, **kw)
        slab.move(slope_len / 2 - thickness * 0.25, 0, 0)
        slab.rotate(-ang if side > 0 else ang, "Y")
        if side < 0:
            slab.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
            slab = recalc_normals(slab)
        slab.move(0, 0, 0)
        # slab hinge sits at the ridge; move so eave sits at z=0 (outer edge)
        pieces.append(slab)
    # slabs hinge at x=0 z=0; shift so ridge is at z=rise
    for p in pieces:
        p.move(0, 0, rise)
    if ridge:
        cap = box(thickness * 1.6, d + 0.2, thickness * 1.2, color, base=False, **kw)
        cap.rotate(math.radians(45), "Y")
        cap.move(0, 0, rise + thickness * 0.35)
        pieces.append(cap)
    return pieces


def frustum_box(bx, by, tx, ty, h, color="stone", **kw):
    """Box with a different top size (battered walls, plinths, hipped shapes when tx/ty = 0)."""
    v = [(-bx / 2, -by / 2, 0), (bx / 2, -by / 2, 0), (bx / 2, by / 2, 0), (-bx / 2, by / 2, 0),
         (-tx / 2, -ty / 2, h), (tx / 2, -ty / 2, h), (tx / 2, ty / 2, h), (-tx / 2, ty / 2, h)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return Piece(v, f, color, **kw)


def hip_roof(bx, by, h, ridge_frac=0.4, color="thatch", **kw):
    """Solid hipped roof: rectangular base bx*by, ridge along the longer axis."""
    if bx >= by:
        tx, ty = bx * ridge_frac, 0.02
    else:
        tx, ty = 0.02, by * ridge_frac
    return frustum_box(bx, by, tx, ty, h, color, **kw)


def arch_poly(width, height, seg=6, spring=None):
    """CCW outline (x, z) of a round-topped opening, base at z=0."""
    r = width / 2
    spring = height - r if spring is None else spring
    pts = [(-r, 0.0), (r, 0.0)]
    for i in range(seg + 1):
        a = TAU / 2 * i / seg
        pts.append((math.cos(a) * r, spring + math.sin(a) * r))
    pts = [pts[0], pts[1]] + pts[2:]
    # remove duplicate (r, spring) if spring == 0
    out = []
    for p in pts:
        if not out or (abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6):
            out.append(p)
    return out


def scatter_on_ring(rng, n, r_min, r_max, z=0.0):
    out = []
    for i in range(n):
        a = TAU * (i + rng.uniform(-0.3, 0.3)) / n
        r = rng.uniform(r_min, r_max)
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return out


def look_rot(direction, up=Vector((0, 0, 1))):
    """Rotation matrix that maps +Z to `direction`."""
    d = Vector(direction).normalized()
    return d.to_track_quat("Z", "Y").to_matrix().to_4x4()


__all__ = [
    "Piece", "Matrix", "Vector", "mathutils", "TAU",
    "bevel", "recalc_normals", "subdivide", "box", "ring", "lathe", "cylinder", "cone", "prism",
    "icosphere", "uvsphere", "tube", "merge", "gable_roof", "frustum_box", "hip_roof", "arch_poly",
    "scatter_on_ring", "look_rot",
]
