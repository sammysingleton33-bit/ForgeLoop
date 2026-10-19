"""Blender -> Roblox coordinate conversion (pure Python; no bpy needed).

FBX export uses axis_forward='Z', axis_up='Y'. bpy_extras.io_utils.axis_conversion(to_forward='Z',
to_up='Y') is [[-1,0,0],[0,0,1],[0,1,0]] (checked 2026-10-12, bpy 5.2.2; re-checked by
tests/test_pipeline.py when bpy is available), i.e. (x, y, z) -> (-x, z, y). Generators put the
asset's front on Blender -Y, which becomes Roblox -Z: the Model's LookVector side.
In-Studio confirmation: roblox/studio-tests/assets.md (A3).
"""


def blender_to_roblox(v):
    x, y, z = v
    return (-x, z, y)


def size_to_roblox(size):
    sx, sy, sz = size
    return (abs(sx), abs(sz), abs(sy))
