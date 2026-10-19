"""Triangle counts read straight from a binary FBX file, no Blender needed (FL-0135; FORGE-07: budgets are MEASURED from the shipped
mesh data, never taken from a declared number).

    from lib import fbxtris
    fbxtris.measure("games/game-001/art/char_kit/citizen_kit.fbx")   # {"hat_straw": 124, ...}  one entry per Model (mesh object)

Reads the node tree of a binary FBX (version 7.x, 32- or 64-bit offsets), takes every `Geometry` node's `PolygonVertexIndex`
(a polygon ends at a negative index; a polygon with n corners is n - 2 triangles) and follows the `Connections` from each
geometry to its `Model`, whose name is the object name (= the piece id). Only what is needed is decoded.
"""

import struct
import zlib
from pathlib import Path

MAGIC = b"Kaydara FBX Binary  \x00\x1a\x00"
WANT = {"Geometry", "Model", "PolygonVertexIndex", "C"}
ARRAY_FMT = {"f": ("f", 4), "d": ("d", 8), "l": ("q", 8), "i": ("i", 4), "b": ("?", 1)}


class FbxError(ValueError):
    pass


def _props(data, pos, count, end):
    out = []
    for _ in range(count):
        t = chr(data[pos])
        pos += 1
        if t in ARRAY_FMT:
            n, enc, clen = struct.unpack_from("<III", data, pos)
            pos += 12
            raw = data[pos: pos + clen]
            pos += clen
            if enc == 1:
                raw = zlib.decompress(raw)
            code, size = ARRAY_FMT[t]
            out.append(struct.unpack_from(f"<{n}{code}", raw, 0) if n else ())
        elif t == "S" or t == "R":
            (n,) = struct.unpack_from("<I", data, pos)
            pos += 4
            out.append(bytes(data[pos: pos + n]))
            pos += n
        elif t == "Y":
            out.append(struct.unpack_from("<h", data, pos)[0])
            pos += 2
        elif t == "C":
            out.append(data[pos])
            pos += 1
        elif t == "I":
            out.append(struct.unpack_from("<i", data, pos)[0])
            pos += 4
        elif t == "F":
            out.append(struct.unpack_from("<f", data, pos)[0])
            pos += 4
        elif t == "D":
            out.append(struct.unpack_from("<d", data, pos)[0])
            pos += 8
        elif t == "L":
            out.append(struct.unpack_from("<q", data, pos)[0])
            pos += 8
        else:
            raise FbxError(f"unknown property type {t!r}")
    return out


def _nodes(data, pos, end, wide):
    """Child nodes of one level: [(name, props | None, children)]. Stops at the null record or `end`."""
    head = 24 if wide else 12
    out = []
    while pos + head < end:
        if wide:
            end_off, nprops, plen, nlen = struct.unpack_from("<QQQB", data, pos)
            pos += 25
        else:
            end_off, nprops, plen, nlen = struct.unpack_from("<IIIB", data, pos)
            pos += 13
        if end_off == 0:
            break
        name = data[pos: pos + nlen].decode("latin-1")
        pos += nlen
        props = _props(data, pos, nprops, pos + plen) if name in WANT else None
        pos += plen
        children = _nodes(data, pos, end_off, wide) if pos < end_off else []
        out.append((name, props, children))
        pos = end_off
    return out


def _name(prop):
    return prop.split(b"\x00\x01")[0].decode("utf-8") if isinstance(prop, bytes) else str(prop)


def measure(path):
    """{object name: triangle count} of every mesh Model in the FBX."""
    data = Path(path).read_bytes()
    if not data.startswith(MAGIC):
        raise FbxError("not a binary FBX")
    (version,) = struct.unpack_from("<I", data, 23)
    top = _nodes(data, 27, len(data), version >= 7500)
    tris, models, geom_to_model = {}, {}, {}
    for name, _, kids in top:
        if name == "Objects":
            for kname, props, grand in kids:
                if kname == "Geometry":
                    idx = next((p[0] for n, p, _ in grand if n == "PolygonVertexIndex"), ())
                    count, corners = 0, 0
                    for i in idx:
                        corners += 1
                        if i < 0:
                            count += corners - 2
                            corners = 0
                    tris[props[0]] = count
                elif kname == "Model":
                    models[props[0]] = _name(props[1])
        elif name == "Connections":
            for kname, props, _ in kids:
                if kname == "C" and props[0] == b"OO":
                    geom_to_model[props[1]] = props[2]
    out = {}
    for gid, n in tris.items():
        mid = geom_to_model.get(gid)
        if mid in models:
            out[models[mid]] = out.get(models[mid], 0) + n
    return out
