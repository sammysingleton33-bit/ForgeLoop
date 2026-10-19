"""Private helpers for the rocks / resource-node family (rock_boulder, rock_cliff,
resource_stone, resource_ore, resource_wood).

Rocks are built as *convex hulls of noise-displaced point clouds* (chunky low-poly facets),
then shaped with planar cuts (fracture planes, quarry faces, the ground plane) and a light
chamfer on the sharpest edges. Each solid lives in a bmesh with an int face layer "tag"
so cut faces, veins and the buried base can be painted differently. `to_piece()` turns the
bmesh into a lib.geo.Piece with per-face palette colours (closed, triangulated shells).

Everything here is deterministic given the caller's rng / seed.
"""

import math

import bmesh
from mathutils import Matrix, Vector
from mathutils import noise as mnoise
from mathutils.bvhtree import BVHTree

from lib.geo import Piece, cylinder, lathe

ROUGH, CUT, GROUND, VEIN = 0, 1, 2, 3
GOLDEN = math.pi * (3.0 - math.sqrt(5.0))

# rock colour families: (dark, mid, light) palette names
STONES = {
    "granite": ("granite_dark", "granite", "granite_light"),
    "stone": ("stone_dark", "stone", "stone_light"),
    "warm": ("sandstone_dark", "rock_warm", "sandstone"),
    "cool": ("slate", "stone_cool_dark", "stone_cool"),
    "dark": ("slate_dark", "granite_dark", "granite"),
}


# ------------------------------------------------------------------ bmesh basics

def _tag_layer(bm):
    return bm.faces.layers.int.get("tag") or bm.faces.layers.int.new("tag")


def hull(points, tag=ROUGH):
    """Closed convex hull of a point cloud, near-coplanar triangles merged into facets."""
    bm = bmesh.new()
    lay = _tag_layer(bm)
    for p in points:
        bm.verts.new(Vector(p))
    bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4.0), verts=bm.verts[:], edges=bm.edges[:])
    for f in bm.faces:
        f[lay] = tag
    bm.normal_update()
    return bm


def bounds(bm):
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def centroid(bm):
    return sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))


def support(bm, d):
    """max over vertices of v . d"""
    d = Vector(d)
    return max(v.co.dot(d) for v in bm.verts)


def transform(bm, m):
    m = Matrix(m)
    if len(m) == 3:
        m = m.to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    bm.normal_update()
    return bm


def move(bm, x=0.0, y=0.0, z=0.0):
    bmesh.ops.translate(bm, vec=Vector((x, y, z)), verts=bm.verts[:])
    return bm


def cut(bm, co, no, tag=CUT):
    """Keep the half-space (x - co) . no <= 0 and cap the opening with a flat face tagged `tag`.
    Returns the new cap faces."""
    co, no = Vector(co), Vector(no).normalized()
    lay = _tag_layer(bm)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=co, plane_no=no, clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    new = []
    if edges:
        res = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        new = res["faces"]
        for f in new:
            f[lay] = tag
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.normal_update()
    return new


def chamfer(bm, offset, min_angle_deg=38.0, segments=1):
    """Bevel only the sharpest edges (a few chamfers that catch light)."""
    bm.normal_update()
    lim = math.radians(min_angle_deg)
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, profile=0.5, affect="EDGES",
                        clamp_overlap=True)
    bm.normal_update()
    return bm


def chamfer_lips(bm, offset, up=0.6, front=-0.35):
    """Bevel only 'lip' edges: between an up-facing face and a front (-Y) facing face
    (ledge edges that catch the light), cheap compared with a full chamfer."""
    bm.normal_update()
    edges = []
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f0, f1 = e.link_faces
        a, c = f0.normal, f1.normal
        if (a.z > up and c.y < front) or (c.z > up and a.y < front):
            edges.append(e)
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    return bm


def displace(bm, amount, freq=0.5, seed=0.0, center=None):
    c = Vector(center) if center is not None else centroid(bm)
    off = Vector((seed * 13.7, seed * 7.3, seed * 3.1))
    for v in bm.verts:
        d = v.co - c
        d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
        v.co += d * (mnoise.noise(v.co * freq + off) * amount)
    bm.normal_update()
    return bm


def ray_surface(bm, origin, direction):
    """First hit of a ray against the solid: (location, normal) or (None, None)."""
    tree = BVHTree.FromBMesh(bm)
    loc, nrm, _i, _d = tree.ray_cast(Vector(origin), Vector(direction).normalized())
    return loc, nrm


def surface_from_centre(bm, direction, centre=None):
    """Point on the surface seen from the centre along `direction` (cast inwards from outside)."""
    c = Vector(centre) if centre is not None else centroid(bm)
    d = Vector(direction).normalized()
    loc, nrm = ray_surface(bm, c + d * 500.0, -d)
    return loc, nrm


# ------------------------------------------------------------------ point clouds

def ellipsoid_points(rng, n, rx, ry, rz, noise=0.12, freq=1.2, jitter=0.06, seed=0.0):
    """Fibonacci points on an ellipsoid with coherent radial noise (the 'noise displacement')."""
    pts = []
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    phase = rng.uniform(0, math.tau)
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = phase + i * GOLDEN + rng.uniform(-0.25, 0.25)
        u = Vector((r * math.cos(a), r * math.sin(a), z))
        k = 1.0 + noise * mnoise.noise(u * freq + off) + rng.uniform(-jitter, jitter)
        pts.append(Vector((u.x * rx * k, u.y * ry * k, u.z * rz * k)))
    return pts


def block_points(rng, sx, sy, sz, chamfer=0.25, jitter=0.12, base=True, bottom=True):
    """Chamfered-box point cloud: each corner split into 3 points pulled in along x/y/z.
    The hull is a box with natural chamfers (cheap: ~44 tris). base=True: sits on z=0.
    bottom=False keeps the bottom corners sharp (one point each; for stacked strata)."""
    pts = []
    z0 = 0.0 if base else -sz / 2
    for cx in (-1, 1):
        for cy in (-1, 1):
            for cz in (0, 1):
                c = Vector((cx * sx / 2, cy * sy / 2, z0 + cz * sz))
                if cz == 0 and not bottom:
                    pts.append(c + Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter), 0.0)))
                    continue
                k = chamfer * rng.uniform(0.5, 1.4)
                inward = Vector((-cx, -cy, 1 if cz == 0 else -1))
                for ax in range(3):
                    p = c.copy()
                    p[ax] += inward[ax] * k
                    p += Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter),
                                 rng.uniform(-jitter, jitter)))
                    pts.append(p)
    return pts


# ------------------------------------------------------------------ composite rock shapes

def boulder(rng, rx, ry, rz, n=22, fractures=2, flat_top=0.0, bury=0.25, lean=(0.0, 0.0), yaw=None,
            chamfer_frac=0.05, chamfer_angle=36.0, noise=0.13, at=(0.0, 0.0), ground=True, seed=None,
            frac_z=(-0.15, 0.9), frac_depth=(0.78, 0.9), top_tilt=0.2):
    """One faceted rock mass, cut flat at z=0 (half-buried look). Returns the bmesh.

    rx/ry/rz: semi-axes before burying; bury: fraction of the height sunk below ground;
    fractures: big planar fracture facets; flat_top: 0..0.4 slices the top flat."""
    seed = rng.uniform(0, 100) if seed is None else seed
    bm = hull(ellipsoid_points(rng, n, rx, ry, rz, noise=noise, seed=seed))
    for _ in range(fractures):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), rng.uniform(*frac_z))).normalized()
        cut(bm, d * support(bm, d) * rng.uniform(*frac_depth), d, tag=ROUGH)
    if flat_top > 0:
        d = Vector((rng.uniform(-top_tilt, top_tilt), rng.uniform(-top_tilt, top_tilt), 1.0)).normalized()
        cut(bm, d * support(bm, d) * (1.0 - flat_top), d, tag=ROUGH)
    rot = Matrix.Rotation(lean[0], 4, "X") @ Matrix.Rotation(lean[1], 4, "Y")
    rot = Matrix.Rotation(rng.uniform(0, math.tau) if yaw is None else yaw, 4, "Z") @ rot
    transform(bm, rot)
    lo, hi = bounds(bm)
    move(bm, at[0], at[1], -lo.z - (hi.z - lo.z) * bury)
    if chamfer_frac > 0:
        chamfer(bm, chamfer_frac * min(rx, ry, rz), chamfer_angle)
    if ground:
        cut(bm, (0, 0, 0), (0, 0, -1), tag=GROUND)
    return bm


def slab(rng, sx, sy, sz, chamfer_k=0.3, jitter=0.15, taper=0.9, at=(0, 0, 0), yaw=0.0, tilt=(0.0, 0.0),
         bottom=True):
    """Chunky rectangular rock block (strata, cut stones). Base at z=0 before `at`."""
    pts = block_points(rng, sx, sy, sz, chamfer_k, jitter, bottom=bottom)
    if taper != 1.0:
        for p in pts:
            t = p.z / max(1e-6, sz)
            s = 1.0 + (taper - 1.0) * t
            p.x *= s
            p.y *= s
    bm = hull(pts)
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(tilt[0], 4, "X") \
        @ Matrix.Rotation(tilt[1], 4, "Y")
    transform(bm, m)
    return bm


def cap_layer(rock_bm, rng, frac=0.55, tilt=0.25, thick=0.15, subdiv=1, noise=0.35, seed=0.0, rim_in=0.35):
    """Moss / grass cap: the top of a rock above a tilted plane, inflated by `thick` with a
    soft rim that tucks back into the rock. Returns a new bmesh (caller paints it)."""
    bm = rock_bm.copy()
    lo, hi = bounds(bm)
    c = centroid(bm)
    no = Vector((rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), 1.0)).normalized()
    co = Vector((c.x, c.y, lo.z + (hi.z - lo.z) * frac))
    caps = cut(bm, co, -no, tag=GROUND)
    if not bm.faces or not caps:
        bm.free()
        return None
    if subdiv:
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if not all(f in caps for f in e.link_faces)],
                                  cuts=subdiv, use_grid_fill=True)
    bm.normal_update()
    lay = _tag_layer(bm)
    rim = set()
    for f in bm.faces:
        if f[lay] == GROUND:
            rim.update(f.verts)
    off = Vector((seed * 5.1, seed * 2.9, seed * 1.3))
    for v in bm.verts:
        ns = [f.normal for f in v.link_faces if f[lay] != GROUND]
        if not ns:
            continue
        n = sum(ns, Vector()).normalized()
        k = 1.0 + noise * mnoise.noise(v.co * 0.9 + off)
        if v in rim:
            v.co -= n * (thick * rim_in)
        else:
            v.co += n * thick * k
    bm.normal_update()
    return bm


def moss_patch(rock_bm, rng, min_nz=0.5, min_z_frac=0.35, thick=0.15, rim=0.3, sink=0.03, keep=None, only_tag=None):
    """Moss / grass growing on the up-facing facets of a rock: the selected facets are lifted
    off the surface by `thick` (closed shell: lifted top + tapered rim walls + sunk bottom).
    Outline follows the rock's facets, so it reads as moss, not as a lid. Returns bmesh or None."""
    bm = rock_bm.copy()
    bm.normal_update()
    lo, hi = bounds(bm)
    zcut = lo.z + (hi.z - lo.z) * min_z_frac
    lay = _tag_layer(bm)
    sel = []
    for f in bm.faces:
        if f[lay] == GROUND or (only_tag is not None and f[lay] != only_tag):
            continue
        c = f.calc_center_median()
        if f.normal.z >= min_nz and c.z >= zcut and (keep is None or keep(f, c)):
            sel.append(f)
    if not sel:
        bm.free()
        return None
    sel_set = set(sel)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in sel_set], context="FACES_ONLY")
    loose_e = [e for e in bm.edges if not e.link_faces]
    if loose_e:
        bmesh.ops.delete(bm, geom=loose_e, context="EDGES")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.normal_update()
    vnorm = {}
    for v in bm.verts:
        n = sum((f.normal * f.calc_area() for f in v.link_faces), Vector())
        vnorm[v] = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
    boundary = {v for e in bm.edges if e.is_boundary for v in e.verts}
    bottom = list(bm.faces)
    res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:] + bm.edges[:] + bm.verts[:], use_keep_orig=True)
    new_verts = sorted((g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)), key=lambda v: _key(v.co))
    # map new verts back to originals by position
    orig = {tuple(round(c, 5) for c in v.co): v for v in vnorm}
    for nv in new_verts:
        ov = orig.get(tuple(round(c, 5) for c in nv.co))
        n = vnorm.get(ov, Vector((0, 0, 1)))
        k = rim if ov in boundary else 1.0
        nv.co += n * thick * k * rng.uniform(0.85, 1.15)
    for v in vnorm:  # sink the bottom a hair into the rock
        v.co -= vnorm[v] * sink
    for f in bm.faces:
        f[lay] = ROUGH
    for f in bottom:
        if f.is_valid:
            f[lay] = GROUND
    bm.normal_update()
    return bm


MOSS_COLS = {ROUGH: ("pine_light", "moss", "moss"), GROUND: "moss"}  # muted olive moss, cooler sides
TURF_COLS = {ROUGH: ("moss", "grass_dark", "grass_dark"), GROUND: "moss"}


def moss_plates(rock_bm, rng, n=3, size=1.5, thick=0.08, min_nz=0.45, z_frac=0.45, sides=7, spread=0.6):
    """Thin moss that follows the rock exactly: each plate is the rock's own surface inside an
    irregular polygon around a sunny surface point, lifted by `thick` (+ a little per plate so
    overlaps never z-fight). Overlapping plates give a ragged, patchy outline. Returns bmeshes."""
    out = []
    lo, hi = bounds(rock_bm)
    c = centroid(rock_bm)
    R = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) / 2
    zmin = lo.z + (hi.z - lo.z) * z_frac
    tries = 0
    pts = []
    while len(pts) < n and tries < n * 12:
        tries += 1
        x = c.x + rng.uniform(-1, 1) * (hi.x - lo.x) * 0.5 * spread
        y = c.y + rng.uniform(-1, 1) * (hi.y - lo.y) * 0.5 * spread
        loc, nrm = ray_surface(rock_bm, (x, y, hi.z + 10.0), (0, 0, -1))
        if loc is None or nrm.z < min_nz or loc.z < zmin:
            continue
        if any((loc - q).length < size * 0.6 for q, _ in pts):
            continue
        pts.append((loc, nrm))
    for i, (loc, nrm) in enumerate(pts):
        plate = rock_bm.copy()
        k = 1.0 + (thick + 0.03 * i) / max(R, 1e-3)
        transform(plate, Matrix.Translation(c) @ Matrix.Scale(k, 4) @ Matrix.Translation(-c))
        a0 = rng.uniform(0, math.tau)
        for q in range(sides):
            a = a0 + q * math.tau / sides + rng.uniform(-0.25, 0.25)
            tv = Vector((math.cos(a), math.sin(a), 0.0))
            tv = (tv - nrm * tv.dot(nrm)).normalized()
            cut(plate, loc + tv * size * rng.uniform(0.55, 1.15), tv, tag=ROUGH)
        cut(plate, loc - nrm * size * 0.9, -nrm, tag=GROUND)
        if plate.faces:
            lo2, _h = bounds(plate)
            if lo2.z < 0:
                cut(plate, (0, 0, 0), (0, 0, -1), tag=GROUND)
            out.append(plate)
        else:
            plate.free()
    return out


def surface_plate(rock_bm, rng, loc, nrm, size, thick, depth=None, sides=7):
    """One irregular plate of the rock's own surface around `loc` (normal `nrm`), lifted by about
    `thick`: the polygon prism runs along `nrm`, so a plate at a ledge lip drapes down the face
    to `depth` below `loc` (turf hanging over a cliff edge). Closed convex shell, or None."""
    plate = rock_bm.copy()
    piv = Vector(loc) - Vector(nrm) * 4.0
    transform(plate, Matrix.Translation(piv) @ Matrix.Scale(1.0 + thick / 4.0, 4) @ Matrix.Translation(-piv))
    a0 = rng.uniform(0, math.tau)
    for q in range(sides):
        a = a0 + q * math.tau / sides + rng.uniform(-0.25, 0.25)
        tv = Vector((math.cos(a), math.sin(a), 0.0))
        tv = (tv - nrm * tv.dot(nrm)).normalized()
        cut(plate, loc + tv * size * rng.uniform(0.55, 1.15), tv, tag=ROUGH)
    cut(plate, loc - nrm * (depth if depth is not None else size * 0.9), -nrm, tag=GROUND)
    if not plate.faces:
        plate.free()
        return None
    lo, _hi = bounds(plate)
    if lo.z < 0:
        cut(plate, (0, 0, 0), (0, 0, -1), tag=GROUND)
    return plate


def _remove_bowties(bm):
    """Delete faces so no vertex joins two face fans that only touch at that vertex (an
    extruded patch with such a 'bowtie' would not be a closed 2-manifold)."""
    while True:
        hit = None
        for v in bm.verts:
            fs = list(v.link_faces)
            if len(fs) < 2:
                continue
            parent = {f: f for f in fs}

            def find(f):
                while parent[f] is not f:
                    parent[f] = parent[parent[f]]
                    f = parent[f]
                return f
            for e in v.link_edges:
                lf = [f for f in e.link_faces if f in parent]
                if len(lf) == 2:
                    parent[find(lf[0])] = find(lf[1])
            groups = {}
            for f in fs:
                groups.setdefault(find(f), []).append(f)
            if len(groups) > 1:
                gs = sorted(groups.values(), key=lambda g: (-len(g), _key(g[0].calc_center_median())))
                hit = [f for g in gs[1:] for f in g]
                break
        if not hit:
            return
        bmesh.ops.delete(bm, geom=hit, context="FACES")


def _drop_small_islands(bm, min_faces=3):
    seen, small = set(), []
    for f0 in bm.faces:
        if f0 in seen:
            continue
        comp, stack = [], [f0]
        seen.add(f0)
        while stack:
            f = stack.pop()
            comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
        if len(comp) < min_faces:
            small += comp
    if small:
        bmesh.ops.delete(bm, geom=small, context="FACES")


def moss_cover(rock_bm, rng, min_nz=0.55, min_z_frac=0.4, thick=0.08, subdiv=1, ragged=0.3, freq=0.9,
               rim=0.0, sink=0.02, drape=0.0, only_tag=None, seed=0.0, cuts=0):
    """Moss / turf that follows the rock: the up-facing part of the surface (optionally subdivided
    once) is selected with a noisy threshold so the border is ragged, then lifted by a thin `thick`
    with the rim tapered back onto the rock. `drape` (studs) also takes the steep faces within a
    noisy depth below the top edge, so turf hangs over a cliff lip. Closed shell; None if empty."""
    bm = rock_bm.copy()
    bm.normal_update()
    lay = _tag_layer(bm)
    lo, hi = bounds(bm)
    zcut = lo.z + (hi.z - lo.z) * min_z_frac
    off = Vector((seed * 3.7, seed * 1.9, seed * 2.3))

    def candidate(f, loose=0.0):
        if f[lay] == GROUND or (only_tag is not None and f[lay] != only_tag):
            return False
        c = f.calc_center_median()
        if drape > 0 and c.z > hi.z - drape * 1.6 and f.normal.z > -0.35:
            return True
        return f.normal.z >= min_nz - ragged - loose and c.z >= zcut - (hi.z - lo.z) * 0.1

    keep = [f for f in bm.faces if candidate(f, 0.1)]
    if not keep:
        bm.free()
        return None
    ks = set(keep)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in ks], context="FACES")
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    if cuts:  # split the (few, large) candidate facets so the noisy threshold can cut ragged holes/edges
        bmesh.ops.subdivide_edges(bm, edges=sorted(bm.edges, key=lambda e: _key((e.verts[0].co + e.verts[1].co) / 2)),
                                  cuts=cuts, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    for _ in range(subdiv):  # refine only along the border: ragged edge without paying for the interior
        border = {e for f in bm.faces if any(ed.is_boundary for ed in f.edges) for e in f.edges}
        if not border:
            break
        border = sorted(border, key=lambda e: _key((e.verts[0].co + e.verts[1].co) / 2))
        bmesh.ops.subdivide_edges(bm, edges=border, cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    bm.normal_update()
    drop = []
    for f in bm.faces:
        c = f.calc_center_median()
        nz = mnoise.noise(c * freq + off)
        ok = f.normal.z + ragged * nz >= min_nz and c.z >= zcut
        if drape > 0 and f.normal.z > -0.35:
            ok = ok or c.z >= hi.z - drape * (0.55 + 0.45 * nz)
        if not ok:
            drop.append(f)
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="FACES")
    _remove_bowties(bm)
    _drop_small_islands(bm)
    for g in ([e for e in bm.edges if not e.link_faces], [v for v in bm.verts if not v.link_faces]):
        if g:
            bmesh.ops.delete(bm, geom=g, context="EDGES" if isinstance(g[0], bmesh.types.BMEdge) else "VERTS")
    if not bm.faces:
        bm.free()
        return None
    bm.normal_update()
    vnorm = {}
    for v in bm.verts:
        n = sum((f.normal * f.calc_area() for f in v.link_faces), Vector())
        vnorm[v] = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
    boundary = {v for e in bm.edges if e.is_boundary for v in e.verts}
    bottom = list(bm.faces)
    res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:] + bm.edges[:] + bm.verts[:], use_keep_orig=True)
    new_verts = sorted((g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)), key=lambda v: _key(v.co))
    orig = {_key(v.co): v for v in vnorm}
    for nv in new_verts:
        ov = orig.get(_key(nv.co))
        n = vnorm.get(ov, Vector((0, 0, 1)))
        k = rim if ov in boundary else 1.0
        nv.co += n * (thick * k + 0.01) * (1.0 + 0.3 * mnoise.noise(nv.co * 1.3 + off))
    for v in vnorm:
        v.co -= vnorm[v] * sink
    for f in bm.faces:
        f[lay] = ROUGH
    for f in bottom:
        if f.is_valid:
            f[lay] = GROUND
    bm.normal_update()
    if any(len(e.link_faces) != 2 for e in bm.edges) or _has_dup_faces(bm):
        bm.free()  # non-manifold patch (rare): retry once with a calmer border, else no moss
        if ragged > 0.05:
            return moss_cover(rock_bm, rng, min_nz, min_z_frac, thick, 0, ragged * 0.3, freq, rim, sink, drape,
                              only_tag, seed + 1.0, 0)
        return None
    return bm


def _has_dup_faces(bm):
    bm.verts.index_update()
    seen = set()
    for f in bm.faces:
        k = tuple(sorted(v.index for v in f.verts))
        if k in seen:
            return True
        seen.add(k)
    return False


# ------------------------------------------------------------------ to Piece

def _fix_slivers(bm, eps=5e-7, tries=200):
    """Rotate the longest edge of zero-area triangles (collinear corners) so the closed shell
    stays closed but has no degenerate faces. Never collapses (that can break manifoldness);
    a face that cannot be fixed by rotation is left as is."""
    skip = set()
    bm.faces.index_update()
    for _ in range(tries):
        bad = next((f for f in bm.faces if f.calc_area() < eps and f.index not in skip), None)
        if bad is None:
            break
        e = max(bad.edges, key=lambda ed: ed.calc_length())
        r = None
        if len(e.link_faces) == 2:
            opp = [v for f in e.link_faces for v in f.verts if v not in e.verts]
            joined = len(opp) == 2 and any(opp[1] in ed.verts for ed in opp[0].link_edges)
            if not joined and all(len(f.verts) == 3 for f in e.link_faces):
                try:
                    r = bmesh.utils.edge_rotate(e, False)
                except (ValueError, RuntimeError):
                    r = None
        bm.faces.index_update()
        if r is None:
            skip.add(bad.index)
        bm.faces.ensure_lookup_table()
    bm.normal_update()


def _key(co):
    return (round(co.x, 4), round(co.y, 4), round(co.z, 4))


def canonical(bm):
    """Rebuild a bmesh with faces / loops / verts in a geometry-defined order. Some bmesh
    operators order their output by memory address, which made the triangulation (and the
    geometry hash that pins reviews) differ between runs; after this the result only
    depends on the geometry."""
    lay = _tag_layer(bm)
    polys = []
    for f in bm.faces:
        ks = [_key(v.co) + (v.co.x, v.co.y, v.co.z) for v in f.verts]  # rounded first, exact as tie-break
        srcs = list(f.verts)
        i0 = min(range(len(ks)), key=lambda i: ks[i])
        ks = ks[i0:] + ks[:i0]
        srcs = srcs[i0:] + srcs[:i0]
        polys.append((tuple(ks), srcs, f[lay], f.smooth))
    polys.sort(key=lambda t: t[0])
    out = bmesh.new()
    olay = _tag_layer(out)
    vmap = {}  # keyed by the source vertex: distinct verts never merge, order is geometric
    for ks, srcs, tag, _sm in polys:
        vs = []
        for sv in srcs:
            v = vmap.get(sv)
            if v is None:
                v = vmap[sv] = out.verts.new(sv.co.copy())
            vs.append(v)
        if len(set(vs)) < 3:
            continue
        try:
            f = out.faces.new(vs)
        except ValueError:
            continue  # duplicate face
        f[olay] = tag
    out.normal_update()
    return out


def to_piece(bm, colors, grad=("range", 0.15, 0.95), smooth=False, by_normal=True, free=True, tint=None, tag=""):
    """bmesh -> Piece. `colors`: {tag: name or (dark, mid, light)}; a 3-tuple picks by facet
    orientation (tops light, undersides dark) when by_normal. Missing tags use ROUGH."""
    if bm.verts and min(v.co.z for v in bm.verts) < -1e-5:  # nothing goes below the ground plane
        cut(bm, (0, 0, 0), (0, 0, -1), tag=GROUND)
    bm.normal_update()
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges[:])
    src = bm
    bm = canonical(bm)
    if free:
        src.free()
    free = True
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    _fix_slivers(bm)
    lay = _tag_layer(bm)
    bm.verts.index_update()
    verts = [v.co.copy() for v in bm.verts]
    faces, fcols = [], []
    for f in bm.faces:
        t = f[lay]
        c = colors.get(t, colors.get(ROUGH))
        if isinstance(c, tuple):
            nz = f.normal.z
            c = c[2] if (by_normal and nz > 0.66) else (c[0] if (by_normal and nz < -0.2) else c[1])
        faces.append(tuple(v.index for v in f.verts))
        fcols.append(c)
    p = Piece(verts, faces, fcols[0] if fcols else "stone", grad=grad, smooth=smooth, tint=tint, tag=tag)
    p.face_colors = fcols
    if free:
        bm.free()
    return p


def rest_on_ground(b):
    """Safety net for props (tilted timbers, tool handles, root flares): any piece that dips
    below z=0 is lifted so its lowest point rests on the ground (pivot = ground level)."""
    for pc in b.pieces:
        if not pc.verts:
            continue
        mz = min(v.z for v in pc.verts)
        if mz < -1e-6:
            pc.move(0, 0, -mz)


# ------------------------------------------------------------------ small props shared by resources

def grass_tuft(rng, x, y, size=1.0, blades=5, color=("grass_dark", "grass", "grass_light")):
    """Small solid grass tuft (tetrahedral blades leaning out)."""
    out = []
    for i in range(blades):
        a = math.tau * i / blades + rng.uniform(-0.4, 0.4)
        h = size * rng.uniform(0.7, 1.25)
        w = size * 0.16
        lean = Vector((math.cos(a), math.sin(a), 0)) * h * rng.uniform(0.25, 0.5)
        bx, by = math.cos(a) * size * 0.12, math.sin(a) * size * 0.12
        t = Vector((math.cos(a + 1.57), math.sin(a + 1.57), 0)) * w
        p0 = Vector((bx, by, 0)) + t
        p1 = Vector((bx, by, 0)) - t
        p2 = Vector((bx, by, 0)) + Vector((math.cos(a), math.sin(a), 0)) * -w * 0.8
        tip = Vector((bx, by, h)) + lean
        pc = Piece([p0, p1, p2, tip], [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)],
                   rng.choice(color), grad=("range", 0.0, 1.0))
        out.append(pc.move(x, y, 0.0))  # base on z=0 so the pivot stays at ground level
    return out


def pebble(rng, x, y, r, colors, n=8, bury=0.35):
    bm = boulder(rng, r, r * rng.uniform(0.7, 1.0), r * rng.uniform(0.45, 0.7), n=n, fractures=0,
                 bury=bury, chamfer_frac=0.0, at=(x, y))
    return to_piece(bm, {ROUGH: colors, GROUND: colors[0]})


def log(rng, length, r, seg=7, bark="bark", end="wood_pale", heart="wood_light", rings=(True, True),
        chamfer=True, taper=1.0):
    """Log along +Y centred on the origin (axis at z=0): bark body with a chamfer and pale cut
    ends; `rings` adds a darker heartwood disc on the -Y / +Y end. Returns a list of Pieces."""
    L = length
    c = min(0.12, r * 0.15) if chamfer else 0.0
    rb = r * taper
    prof = [(r - c, -L / 2), (r, -L / 2 + c), (rb, L / 2 - c), (rb - c, L / 2)] if c else [(r, -L / 2), (rb, L / 2)]
    body = lathe([(pr, pz) for pr, pz in prof], seg, bark, phase=rng.uniform(0, 1))
    # paint end caps pale (the last two faces are the caps), chamfer rings light bark
    fc = []
    nf = len(body.faces)
    for i in range(nf):
        if i >= nf - 2:
            fc.append(end)
        elif c and (i < seg or i >= nf - 2 - seg):
            fc.append("bark_light")
        else:
            fc.append(bark)
    body.face_colors = fc
    body.grad = ("range", 0.15, 0.9)
    body.transform(Matrix.Rotation(-math.pi / 2, 4, "X"))
    out = [body]
    for side, on in zip((-1, 1), rings):
        if on:
            rr = r if side < 0 else rb
            d = cylinder(rr * 0.45, rr * 0.45, 0.06, seg, heart)
            d.transform(Matrix.Rotation(-math.pi / 2 * side, 4, "X"))
            d.move(0, side * (L / 2 - 0.02), 0)
            out.append(d.paint(grad="flat"))
    return out


__all__ = ["ROUGH", "CUT", "GROUND", "VEIN", "STONES", "hull", "bounds", "centroid", "support", "transform", "move",
           "cut", "chamfer", "chamfer_lips", "displace", "ray_surface", "surface_from_centre", "ellipsoid_points", "block_points",
           "boulder", "slab", "cap_layer", "moss_patch", "moss_cover", "moss_plates", "surface_plate", "MOSS_COLS", "TURF_COLS", "face_bounds", "beam", "pickaxe", "sledgehammer",
           "ladder", "wedge", "rest_on_ground", "to_piece", "grass_tuft", "pebble", "log"]


# ------------------------------------------------------------------ tools and timber props

def face_bounds(faces):
    vs = [v.co for f in faces if f.is_valid for v in f.verts]
    if not vs:
        return None
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def beam(p0, p1, w, d, color, up=(0, 0, 1)):
    """Unbevelled timber from p0 to p1 (w x d section); `up` roughly orients the d axis."""
    from lib.kit import oriented_box
    return oriented_box(p0, p1, w, d, color, Vector(up))


def pickaxe(base, top, color_handle="wood_light", head="iron", side=(1, 0, 0)):
    """Pickaxe leaning from `base` (handle end on the ground) to `top` (head end)."""
    base, top = Vector(base) + Vector((0, 0, 0.14)), Vector(top)
    ax = (top - base).normalized()
    s = Vector(side)
    s = (s - ax * s.dot(ax)).normalized()
    out = [beam(base, top + ax * 0.25, 0.24, 0.24, color_handle, s)]
    for sg in (-1, 1):
        tip = top + s * sg * 1.25 - ax * 0.35
        out.append(beam(top, tip, 0.3, 0.22, head, ax.cross(s)))
    out.append(beam(top - ax * 0.25, top + ax * 0.2, 0.42, 0.42, "iron_dark", s))
    return out


def sledgehammer(base, top, side=(1, 0, 0)):
    base, top = Vector(base) + Vector((0, 0, 0.14)), Vector(top)
    ax = (top - base).normalized()
    s = Vector(side)
    s = (s - ax * s.dot(ax)).normalized()
    out = [beam(base, top, 0.24, 0.24, "wood_light", s)]
    out.append(beam(top - s * 0.6, top + s * 0.6, 0.6, 0.6, "iron_dark", ax))
    return out


def ladder(base, top, width=1.6, rung=1.0, color="wood"):
    base, top = Vector(base) + Vector((0, 0, 0.14)), Vector(top)
    ax = top - base
    L = ax.length
    ax.normalize()
    side = ax.cross(Vector((0, 0, 1)))
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side.normalize()
    nrm = side.cross(ax)
    out = []
    for sg in (-1, 1):
        o = side * sg * width / 2
        out.append(beam(base + o, top + o, 0.26, 0.2, color, nrm))
    n = int(L // rung)
    for i in range(1, n + 1):
        c = base + ax * (i * rung - 0.3)
        out.append(beam(c - side * width / 2, c + side * width / 2, 0.18, 0.14, "wood_light", nrm))
    return out


def wedge(x, y, z, rot=0.0, color="wood_light"):
    from lib.geo import frustum_box
    w = frustum_box(0.16, 0.34, 0.56, 0.42, 0.62, color)
    w.move(0, 0, -0.3).rotate(rot, "Z").move(x, y, z)
    return w
