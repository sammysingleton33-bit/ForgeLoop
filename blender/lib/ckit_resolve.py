"""Which pieces build a citizen: a Python port of the variant resolution in Kit/CharacterMesh.luau (FL-0135).

rig.json assemblies are `{assembly key: {slot key: template | [template, ...]}}`. A template is a piece id or an id with ONE
`%look.<axis>%` token (the pieces whose id is prefix + digits + suffix, in numeric order; the axis picks one) and optionally
`%kingdom%` (crimson | azure | emerald | gold). Same look, same kingdom, same pieces. The generator, the Blender assembler
(`ckit_rigload`), the tests and the budget script all resolve through this module, so a render shows what the runtime builds.

Axes: skin | hair | hairColor | outfit follow the look field and spill over extra variants; face | boots | acc | weapon mix the
whole look (`mix` and `axis_index` mirror `mix` and `axisIndex` in CharacterMesh.luau; keep them in step).
"""

import math
import re

LOOK_RANGES = {"skin": 6, "hair": 6, "hairColor": 8, "outfit": 6}  # Character.LOOK_RANGES (G13.2)
DEFAULT_LOOK = {"skin": 1, "hair": 1, "hairColor": 1, "outfit": 1}
KINGDOMS = ("crimson", "azure", "emerald", "gold")
_TOKEN = re.compile(r"%look\.(\w+)%")
JOB_ALIAS = {"woodcutter": "lumberjack", "lumberjack": "woodcutter"}


def normalize(look):
    lk = dict(DEFAULT_LOOK)
    for k, r in LOOK_RANGES.items():
        v = (look or {}).get(k)
        if isinstance(v, (int, float)) and math.isfinite(v):
            lk[k] = (math.floor(v) - 1) % r + 1
    return lk


def mix(salt, *vals):
    h = salt
    for v in vals:
        h = (h * 31 + v) % 2147483629
    return h


def axis_index(look, axis, n):
    """0-based variant index of `axis` for n variants (None for an unknown axis)."""
    if axis == "face":
        return mix(11, look["skin"], look["hairColor"], look["hair"], look["outfit"]) % n
    if axis == "boots":
        return mix(23, look["outfit"], look["skin"], look["hairColor"]) % n
    if axis == "acc":
        return mix(37, look["outfit"], look["hair"], look["skin"]) % n
    if axis == "weapon":
        return mix(41, look["hair"], look["hairColor"], look["skin"]) % n
    aux = {"skin": look["hair"] + look["outfit"], "hair": look["skin"] + look["outfit"], "hairColor": look["skin"] + look["outfit"],
           "outfit": look["skin"] + look["hairColor"]}.get(axis)
    if aux is None:
        return None
    r = LOOK_RANGES[axis]
    spill = (aux % math.ceil(n / r)) * r if n > r else 0
    return (look[axis] - 1 + spill) % n


def variants_of(piece_ids, prefix, suffix):
    found = []
    for pid in piece_ids:
        if len(pid) > len(prefix) + len(suffix) and pid.startswith(prefix) and (suffix == "" or pid.endswith(suffix)):
            middle = pid[len(prefix): len(pid) - len(suffix)]
            if middle.isdigit():
                found.append((int(middle), pid))
    return [pid for _, pid in sorted(found)]


_CACHE = {}


def resolve_template(template, piece_ids, look, kingdom, cache_key=None):
    """The piece id a template names for this look and kingdom (None when nothing fits)."""
    t = template.replace("%kingdom%", kingdom)
    m = _TOKEN.search(t)
    if not m:
        return t if t in piece_ids else None
    prefix, suffix = t[: m.start()], t[m.end():]
    if cache_key is None:
        lst = variants_of(piece_ids, prefix, suffix)
    else:
        lst = _CACHE.get((cache_key, prefix, suffix))
        if lst is None:
            lst = _CACHE[(cache_key, prefix, suffix)] = variants_of(piece_ids, prefix, suffix)
    if not lst:
        return None
    idx = axis_index(look, m.group(1), len(lst))
    return None if idx is None else lst[idx]


def assembly_key(assemblies, job):
    """Runtime lookup order: the job, its alias, then idle; soldiers: soldier_<job>, soldier; governors: governor."""
    if job == "governor":
        return "governor"
    if job.startswith("soldier"):
        return job if job in assemblies else "soldier"
    for k in (job, JOB_ALIAS.get(job), "idle"):
        if k and k in assemblies:
            return k
    return "idle"


def resolve_assembly(assemblies, pieces, job, look=None, kingdom="crimson"):
    """Piece ids (empty variants dropped) of one citizen, in slot-key order. `pieces` maps id -> record (or any container of ids)."""
    lk = normalize(look)
    asm = assemblies[assembly_key(assemblies, job)]
    ids = list(pieces)
    key = (id(pieces), len(ids))
    out = []
    for slot in sorted(asm):
        val = asm[slot]
        for template in val if isinstance(val, list) else [val]:
            pid = resolve_template(template, ids, lk, kingdom, key)
            if pid is None:
                raise KeyError(f"assembly {job}.{slot}: nothing fits {template!r}")
            rec = pieces[pid] if isinstance(pieces, dict) else {}
            if not (isinstance(rec, dict) and rec.get("empty")):
                out.append(pid)
    return out
