"""Character-kit geometry (FL-0135, D-057): plain-Python meshes authored directly in ROBLOX RIG AXES.

Rig frame (studs, 1 Blender unit = 1 stud): +X = the character's right, +Y up, -Z = front, feet at y = 0, centred on
x = 0, z = 0 (blender/ART_DIRECTION.md section 2, games/game-001/art/char_kit/rig.json). A kit piece is an `M`: verts,
faces (tris/quads/convex caps), one sRGB colour per face and a smooth/flat flag per face. Colours are baked into
per-corner vertex colours at export (`corner_colors`): a light "sky" shading term (faces looking down are darker) keeps
tinted pieces in the neutral 0.78-1.0 band the contract asks for, and fixed pieces keep their own hue.

Everything here is deterministic (no global RNG) so the kit rebuilds bit-identically (check.sh --verify).
The module imports bpy/bmesh/mathutils lazily where it needs them, so the pure maths still imports without bpy.
"""

import math

TAU = math.tau


# ------------------------------------------------------------------ colours (sRGB 0..1)

def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


def grey(v):
    return (v, v, v)


def mul(c, f):
    return (min(1.0, c[0] * f), min(1.0, c[1] * f), min(1.0, c[2] * f))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


TINT = grey(1.0)  # tinted pieces are baked white; the corner shading keeps them in the 0.78-1.0 band


# ------------------------------------------------------------------ the mesh

class M:
    """Authoring mesh (rig axes). faces: tuples of vertex indices (CCW seen from outside)."""

    __slots__ = ("v", "f", "c", "s", "k", "h", "cc")

    def __init__(self, verts=None, faces=None, color=(0.8, 0.8, 0.8), smooth=True, tag=""):
        self.v = [tuple(float(a) for a in p) for p in (verts or [])]
        self.f = [tuple(f) for f in (faces or [])]
        self.c = [color] * len(self.f)
        self.s = [smooth] * len(self.f)
        self.k = [tag] * len(self.f)
        self.h = [1.0] * len(self.v)  # per-vertex shade multiplier (extra baked darkening, 1 = none)
        self.cc = None  # optional per-face lists of per-corner colours (baked from a texture); overrides `c`

    # ---- bookkeeping
    def copy(self):
        m = M()
        m.v, m.f, m.c, m.s, m.k, m.h = (list(self.v), list(self.f), list(self.c), list(self.s), list(self.k),
                                        list(self.h))
        m.cc = [list(c) for c in self.cc] if self.cc is not None else None
        return m

    @property
    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def bounds(self):
        xs, ys, zs = zip(*self.v)
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    # ---- transforms (in place, return self)
    def map(self, fn):
        self.v = [tuple(fn(p)) for p in self.v]
        return self

    def move(self, x=0.0, y=0.0, z=0.0):
        return self.map(lambda p: (p[0] + x, p[1] + y, p[2] + z))

    def scale(self, sx, sy=None, sz=None):
        sy = sx if sy is None else sy
        sz = sx if sz is None else sz
        return self.map(lambda p: (p[0] * sx, p[1] * sy, p[2] * sz))

    def rot(self, deg, axis="z", pivot=(0.0, 0.0, 0.0)):
        a = math.radians(deg)
        c, s = math.cos(a), math.sin(a)
        px, py, pz = pivot

        def f(p):
            x, y, z = p[0] - px, p[1] - py, p[2] - pz
            if axis == "x":
                y, z = y * c - z * s, y * s + z * c
            elif axis == "y":
                x, z = x * c + z * s, -x * s + z * c
            else:
                x, y = x * c - y * s, x * s + y * c
            return (x + px, y + py, z + pz)

        return self.map(f)

    def mirror_x(self):
        """Reflect across x = 0 (right limb -> left limb); winding is flipped so normals stay outward."""
        self.v = [(-p[0], p[1], p[2]) for p in self.v]
        self.f = [tuple(reversed(f)) for f in self.f]
        if self.cc is not None:
            self.cc = [list(reversed(c)) for c in self.cc]
        return self

    # ---- colour / shading
    def paint(self, color, tag=None, where=None):
        """Set the colour of every face (or the faces with this tag, or whose centroid passes `where`)."""
        for i, f in enumerate(self.f):
            if tag is not None and self.k[i] != tag:
                continue
            if where is not None:
                cx = sum(self.v[j][0] for j in f) / len(f)
                cy = sum(self.v[j][1] for j in f) / len(f)
                cz = sum(self.v[j][2] for j in f) / len(f)
                if not where(cx, cy, cz):
                    continue
            self.c[i] = color
        return self

    def tagged(self, tag):
        self.k = [tag] * len(self.f)
        return self

    def smooth(self, flag=True):
        self.s = [flag] * len(self.f)
        return self

    def shade_y(self, y0, y1, a=0.85, b=1.0):
        """Multiply the per-vertex shade by a ramp along y (a at y0, b at y1), clamped outside."""
        for i, p in enumerate(self.v):
            t = min(1.0, max(0.0, (p[1] - y0) / (y1 - y0))) if y1 != y0 else 1.0
            self.h[i] *= a + (b - a) * t
        return self

    # ---- topology helpers
    def fix_winding(self):
        """Flip every face if the signed volume of the (assumed closed) shell is negative."""
        vol = 0.0
        for f in self.f:
            a = self.v[f[0]]
            for j in range(1, len(f) - 1):
                b, c = self.v[f[j]], self.v[f[j + 1]]
                vol += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
                        + a[2] * (b[0] * c[1] - b[1] * c[0]))
        if vol < 0:
            self.f = [tuple(reversed(f)) for f in self.f]
            if self.cc is not None:
                self.cc = [list(reversed(c)) for c in self.cc]
        return self

    def triangulate(self):
        """Quads along the shorter diagonal, convex n-gons as fans. Per-face attributes follow."""
        nf, nc, ns, nk, ncc = [], [], [], [], []
        for i, f in enumerate(self.f):
            if self.cc is not None and len(f) != 3:
                raise ValueError("corner-coloured meshes must be triangles")
            if len(f) == 3:
                parts = [f]
            elif len(f) == 4:
                a, b, c, d = (self.v[j] for j in f)
                if _d2(a, c) <= _d2(b, d):
                    parts = [(f[0], f[1], f[2]), (f[0], f[2], f[3])]
                else:
                    parts = [(f[0], f[1], f[3]), (f[1], f[2], f[3])]
            else:
                parts = [(f[0], f[j], f[j + 1]) for j in range(1, len(f) - 1)]
            for t in parts:
                nf.append(t)
                nc.append(self.c[i])
                ns.append(self.s[i])
                nk.append(self.k[i])
                if self.cc is not None:
                    ncc.append(self.cc[i])
        self.f, self.c, self.s, self.k = nf, nc, ns, nk
        if self.cc is not None:
            self.cc = ncc
        return self

    def weld(self, eps=1e-5):
        """Merge coincident vertices (keeps the first); drops faces that collapse to < 3 distinct corners."""
        key, remap, nv, nh = {}, [], [], []
        for i, p in enumerate(self.v):
            q = (round(p[0] / eps), round(p[1] / eps), round(p[2] / eps))
            if q not in key:
                key[q] = len(nv)
                nv.append(p)
                nh.append(self.h[i])
            remap.append(key[q])
        nf, nc, ns, nk, ncc = [], [], [], [], []
        for i, f in enumerate(self.f):
            g = []
            for j in f:
                r = remap[j]
                if not g or g[-1] != r:
                    g.append(r)
            if len(g) > 1 and g[0] == g[-1]:
                g.pop()
            if len(set(g)) < 3:
                continue
            nf.append(tuple(g))
            nc.append(self.c[i])
            ns.append(self.s[i])
            nk.append(self.k[i])
            if self.cc is not None:
                ncc.append(self.cc[i])
        self.v, self.h, self.f, self.c, self.s, self.k = nv, nh, nf, nc, ns, nk
        if self.cc is not None:
            self.cc = ncc
        return self


def _d2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def merge(*parts):
    out = M()
    flat = []
    for p in parts:
        if p is None:
            continue
        flat += list(p) if isinstance(p, (list, tuple)) else [p]
    if any(q.cc is not None for q in flat):
        out.cc = []
    for q in flat:
        o = len(out.v)
        out.v += q.v
        out.h += q.h
        out.f += [tuple(i + o for i in f) for f in q.f]
        out.c += q.c
        out.s += q.s
        out.k += q.k
        if out.cc is not None:
            out.cc += q.cc if q.cc is not None else [[c] * len(f) for c, f in zip(q.c, q.f)]
    return out


# ------------------------------------------------------------------ primitives

def _ring(y, rx, rz, cx, cz, seg, n, phase):
    e = 2.0 / n
    pts = []
    for i in range(seg):
        a = phase + TAU * i / seg
        c, s = math.cos(a), math.sin(a)
        pts.append((cx + rx * math.copysign(abs(c) ** e, c), y, cz + rz * math.copysign(abs(s) ** e, s)))
    return pts


def loft(rings, seg=8, n=2.0, caps=(True, True), phase=0.0, color=(0.8, 0.8, 0.8), smooth=True, tag=""):
    """Closed lofted solid along +Y through elliptical (super-elliptical) rings.

    rings: (y, rx, rz[, cx, cz[, n]]). rx = rz = 0 makes a pole. n = 2 is an ellipse, > 2 squarer, < 2 diamond-like.
    Ring vertex k sits at angle phase + k * 360 / seg from +X towards +Z.
    """
    m = M(color=color, smooth=smooth, tag=tag)
    index = []  # per ring: list of vertex indices, or [idx] for a pole
    for r in rings:
        y, rx = r[0], r[1]
        rz = r[2] if len(r) > 2 and r[2] is not None else rx
        cx = r[3] if len(r) > 3 else 0.0
        cz = r[4] if len(r) > 4 else 0.0
        rn = r[5] if len(r) > 5 and r[5] else n
        if rx < 1e-6 and rz < 1e-6:
            m.v.append((cx, y, cz))
            index.append([len(m.v) - 1])
        else:
            base = len(m.v)
            m.v += _ring(y, rx, rz, cx, cz, seg, rn, phase)
            index.append(list(range(base, base + seg)))
    m.h = [1.0] * len(m.v)
    faces = []
    for a, b in zip(index[:-1], index[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(seg):
                faces.append((a[0], b[(i + 1) % seg], b[i]))
        elif len(b) == 1:
            for i in range(seg):
                faces.append((a[i], a[(i + 1) % seg], b[0]))
        else:
            for i in range(seg):
                j = (i + 1) % seg
                faces.append((a[i], a[j], b[j], b[i]))
    if caps[0] and len(index[0]) > 1:
        faces.append(tuple(reversed(index[0])))
    if caps[1] and len(index[-1]) > 1:
        faces.append(tuple(index[-1]))
    m.f = faces
    m.c = [color] * len(faces)
    m.s = [smooth] * len(faces)
    m.k = [tag] * len(faces)
    return m.fix_winding()


def sphere(rx, ry=None, rz=None, seg=10, rings=6, n=2.0, cx=0.0, cy=0.0, cz=0.0, color=(0.8, 0.8, 0.8),
           smooth=True, tag="", phase=0.0):
    ry = rx if ry is None else ry
    rz = rx if rz is None else rz
    rs = []
    for i in range(rings + 1):
        t = math.pi * i / rings
        # y from top to bottom would give inward winding; fix_winding sorts it, so go bottom -> top
        yy = -math.cos(t)
        rr = math.sin(t)
        rs.append((cy + ry * yy, rx * rr, rz * rr, cx, cz))
    return loft(rs, seg=seg, n=n, caps=(False, False), phase=phase, color=color, smooth=smooth, tag=tag)


def cyl(r0, r1, h, seg=8, rz0=None, rz1=None, y0=0.0, color=(0.8, 0.8, 0.8), smooth=True, tag="", n=2.0,
        phase=0.0, caps=(True, True)):
    rz0 = r0 if rz0 is None else rz0
    rz1 = r1 if rz1 is None else rz1
    return loft([(y0, r0, rz0), (y0 + h, r1, rz1)], seg=seg, n=n, caps=caps, phase=phase, color=color, smooth=smooth,
                tag=tag)


def cone(r, h, seg=8, y0=0.0, rz=None, color=(0.8, 0.8, 0.8), smooth=True, tag="", phase=0.0):
    rz = r if rz is None else rz
    return loft([(y0, r, rz), (y0 + h, 0, 0)], seg=seg, caps=(True, False), phase=phase, color=color, smooth=smooth,
                tag=tag)


def _bm_to_m(bm, color, smooth, tag):
    bm.verts.ensure_lookup_table()
    m = M([tuple(v.co) for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces], color=color,
          smooth=smooth, tag=tag)
    return m.fix_winding()


def box(sx, sy, sz, bevel=0.0, seg=1, cx=0.0, cy=0.0, cz=0.0, color=(0.8, 0.8, 0.8), smooth=False, tag=""):
    """Axis-aligned box centred on (cx, cy, cz); `bevel` chamfers/rounds every edge (bmesh bevel)."""
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, 0.49 * min(sx, sy, sz)), segments=seg,
                        affect="EDGES", clamp_overlap=True)
    m = _bm_to_m(bm, color, smooth, tag)
    bm.free()
    return m.move(cx, cy, cz)


def hull(points, color=(0.8, 0.8, 0.8), smooth=False, tag=""):
    """Convex hull of a point cloud (faceted blobs, gems, chunky shapes)."""
    import bmesh

    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    # convex_hull leaves interior verts: drop the loose ones
    bm.verts.ensure_lookup_table()
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.verts.ensure_lookup_table()
    m = _bm_to_m(bm, color, smooth, tag)
    bm.free()
    return m.weld()


def prism(poly, z0, z1, color=(0.8, 0.8, 0.8), smooth=False, tag="", scale1=1.0):
    """Extrude a (convex or concave, CCW seen from +Z) polygon in the XY plane from z0 to z1 (end scaled by scale1)."""
    from mathutils import Vector
    from mathutils.geometry import tessellate_polygon

    n = len(poly)
    cxm = sum(p[0] for p in poly) / n
    cym = sum(p[1] for p in poly) / n
    v = [(p[0], p[1], z0) for p in poly] + [
        (cxm + (p[0] - cxm) * scale1, cym + (p[1] - cym) * scale1, z1) for p in poly]
    f = []
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
    tess = tessellate_polygon([[Vector((p[0], p[1], 0)) for p in poly]])
    for a, b, c in tess:
        f.append((c, b, a))  # bottom cap: faces -Z
        f.append((n + a, n + b, n + c))  # top cap: faces +Z
    m = M(v, f, color=color, smooth=smooth, tag=tag)
    return m.fix_winding()


def torus(R, r, seg=10, tseg=5, y=0.0, color=(0.8, 0.8, 0.8), smooth=True, tag="", rz=None, ry=None, phase=0.0):
    """Torus about the Y axis: major radius R (x; `rz` for z if different), minor radius r (`ry` vertical if different)."""
    rz = R if rz is None else rz
    ry = r if ry is None else ry
    verts, faces = [], []
    for i in range(seg):
        a = phase + TAU * i / seg
        ca, sa = math.cos(a), math.sin(a)
        for j in range(tseg):
            b = TAU * j / tseg
            cb, sb = math.cos(b), math.sin(b)
            verts.append(((R + r * cb) * ca, y + ry * sb, (rz + r * cb) * sa))
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            j2 = (j + 1) % tseg
            faces.append((i * tseg + j, i2 * tseg + j, i2 * tseg + j2, i * tseg + j2))
    return M(verts, faces, color=color, smooth=smooth, tag=tag).fix_winding()


def tube(path, radii, seg=6, caps=True, n=2.0, color=(0.8, 0.8, 0.8), smooth=True, tag="", rz_scale=1.0):
    """Sweep a circle along a 3D polyline with per-point radii (parallel-transport frames)."""
    from mathutils import Vector

    pts = [Vector(p) for p in path]
    tang = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a)
        tang.append(t.normalized() if t.length > 1e-9 else Vector((0, 1, 0)))
    ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
    u = tang[0].cross(ref).normalized()
    w = tang[0].cross(u).normalized()
    verts, ringidx = [], []
    for i, p in enumerate(pts):
        if i:
            axis = tang[i - 1].cross(tang[i])
            if axis.length > 1e-9:
                ang = math.asin(min(1.0, axis.length))
                from mathutils import Matrix
                rm = Matrix.Rotation(ang, 3, axis.normalized())
                u = (rm @ u).normalized()
                w = (rm @ w).normalized()
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        base = len(verts)
        e = 2.0 / n
        for k in range(seg):
            a = TAU * k / seg
            c, s = math.cos(a), math.sin(a)
            q = p + u * (r * math.copysign(abs(c) ** e, c)) + w * (r * rz_scale * math.copysign(abs(s) ** e, s))
            verts.append(tuple(q))
        ringidx.append(list(range(base, base + seg)))
    f = []
    for a, b in zip(ringidx[:-1], ringidx[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            f.append((a[i], a[j], b[j], b[i]))
    if caps:
        f.append(tuple(reversed(ringidx[0])))
        f.append(tuple(ringidx[-1]))
    return M(verts, f, color=color, smooth=smooth, tag=tag).fix_winding()


# ------------------------------------------------------------------ colour baking

def _fnormal(m, f):
    a, b, c = m.v[f[0]], m.v[f[1]], m.v[f[2]]
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    return nx, ny, nz


def vertex_normals(m):
    """Area-weighted vertex normals over the smooth faces (flat faces use their own normal at render)."""
    acc = [[0.0, 0.0, 0.0] for _ in m.v]
    for i, f in enumerate(m.f):
        if not m.s[i]:
            continue
        n = _fnormal(m, f)
        for j in f:
            acc[j][0] += n[0]
            acc[j][1] += n[1]
            acc[j][2] += n[2]
    out = []
    for a in acc:
        l = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)
        out.append((a[0] / l, a[1] / l, a[2] / l) if l > 1e-12 else (0.0, 1.0, 0.0))
    return out


def corner_colors(m, ao=0.22, facet=0.0, seed=0):
    """Per-face lists of per-corner sRGB colours: face colour x sky shading (down-facing = darker) x vertex shade.

    facet: +-fraction of per-face brightness variation (deterministic) for the faceted style.
    """
    vn = vertex_normals(m)
    out = []
    for i, f in enumerate(m.f):
        base = m.c[i]
        ccs = m.cc[i] if m.cc is not None else None
        fn = _fnormal(m, f)
        ln = math.sqrt(fn[0] ** 2 + fn[1] ** 2 + fn[2] ** 2) or 1.0
        fny = fn[1] / ln
        fv = 1.0
        if facet:
            hsh = (i * 2654435761 + seed * 40503 + 12345) & 0xFFFF
            fv = 1.0 + facet * ((hsh / 65535.0) * 2.0 - 1.0)
        cs = []
        for ci, j in enumerate(f):
            ny = vn[j][1] if m.s[i] else fny
            sh = (1.0 - ao) + ao * (0.5 + 0.5 * ny)
            k = sh * m.h[j] * fv
            b = ccs[ci] if ccs is not None else base
            cs.append((min(1.0, b[0] * k), min(1.0, b[1] * k), min(1.0, b[2] * k)))
        out.append(cs)
    return out


# ------------------------------------------------------------------ surface conform (face marks)

class Surface:
    """Ray-cast helper over a mesh, to sit small features exactly on a curved surface."""

    def __init__(self, m):
        from mathutils.bvhtree import BVHTree

        t = m.copy().triangulate()
        self.tree = BVHTree.FromPolygons([tuple(p) for p in t.v], [tuple(f) for f in t.f])

    def front_z(self, x, y):
        """z of the front (-Z side) surface at (x, y), or None."""
        from mathutils import Vector

        hit = self.tree.ray_cast(Vector((x, y, -20.0)), Vector((0, 0, 1)))
        return None if hit[0] is None else hit[0].z

    def back_z(self, x, y):
        from mathutils import Vector

        hit = self.tree.ray_cast(Vector((x, y, 20.0)), Vector((0, 0, -1)))
        return None if hit[0] is None else hit[0].z

    def top_y(self, x, z):
        from mathutils import Vector

        hit = self.tree.ray_cast(Vector((x, 30.0, z)), Vector((0, -1, 0)))
        return None if hit[0] is None else hit[0].y


# ------------------------------------------------------------------ Blender objects + export

def to_object(name, m, location=(0.0, 0.0, 0.0), ao=0.22, facet=0.0, seed=0, collection=None):
    """Create a Blender mesh object from an `M` (rig axes -> Blender axes (x, -z, y)).

    The object origin sits at the bounding-box centre (so the MeshPart pivot is unambiguous) and the object is placed
    at `location` (rig frame) + that centre. Returns (object, bbox_min, bbox_max) in rig axes.
    """
    import bpy

    m = m.copy().triangulate()
    (x0, y0, z0), (x1, y1, z1) = m.bounds()
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    verts = [(p[0] - cx, -(p[2] - cz), p[1] - cy) for p in m.v]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], [tuple(f) for f in m.f])
    me.update()
    for poly, sm in zip(me.polygons, m.s):
        poly.use_smooth = bool(sm)
    cols = corner_colors(m, ao=ao, facet=facet, seed=seed)
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly, cs in zip(me.polygons, cols):
        for k, li in enumerate(poly.loop_indices):
            attr.data[li].color_srgb = (cs[k][0], cs[k][1], cs[k][2], 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = 0
    obj = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(obj)
    obj.location = (cx + location[0], -(cz + location[2]), cy + location[1])
    return obj, (x0, y0, z0), (x1, y1, z1)


def rig_to_blender(p):
    """Rig-frame point -> Blender point (the inverse of the FBX exporter's (bx, by, bz) -> (bx, bz, -by))."""
    return (p[0], -p[2], p[1])


def vertex_color_material(name="M_charkit_vc"):
    """One material: Principled BSDF fed by the active vertex colour (the preview twin of Roblox's
    MeshPart.Color x baked vertex colours; the tint multiply happens on the CPU, see ckit_assemble)."""
    import bpy

    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    mat.use_backface_culling = True  # Roblox renders single-sided
    return mat


def export_fbx(objs, path):
    """ONE FBX with every kit piece as its own mesh object (Roblox importer: Y up, -Z forward, 1 unit = 1 stud)."""
    from pathlib import Path

    import bpy

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=str(path),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=False,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        colors_type="SRGB",
        prioritize_active_color=True,
        use_tspace=False,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="AUTO",
        embed_textures=False,
        use_custom_props=False,
    )
    return path
