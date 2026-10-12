#!/usr/bin/env python3
"""Palette-compress UI screenshots in place before committing them (D-007: small previews only).

    python3 design/ui/compress-shots.py design/ui/screenshots/luau/*.png

256 colours, median cut, no dithering: flat UI keeps its look at about a third of the size.
Needs Pillow (preinstalled in the cloud image). Already-paletted files are left alone.
"""
import os
import sys

from PIL import Image


def main(paths):
    before = after = 0
    for path in paths:
        size = os.path.getsize(path)
        before += size
        image = Image.open(path)
        if image.mode == "P":
            after += size
            continue
        quantized = image.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        quantized.save(path, optimize=True)
        after += os.path.getsize(path)
    print(f"compress-shots: {len(paths)} file(s), {before / 1e6:.2f} MB -> {after / 1e6:.2f} MB")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
