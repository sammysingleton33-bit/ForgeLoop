"""Contact sheets: hero tiles of every variant + a gameplay-distance strip, saved as a JPEG
under the 250 KB commit limit. Needs Pillow (installed in the cloud bpy venv); without it
the sheet is skipped and the individual renders remain in blender/renders/."""

import io
from pathlib import Path

MAX_BYTES = 245_000

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # desktop Blender's bundled Python has no Pillow
    Image = None


def available():
    return Image is not None


def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def save_jpeg_under(img, path, max_bytes=MAX_BYTES):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    im = img.convert("RGB")
    while True:
        for q in (88, 84, 80, 76, 72, 68):
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=q, optimize=True, progressive=True)
            if buf.tell() <= max_bytes:
                path.write_bytes(buf.getvalue())
                return path, buf.tell(), q, im.size
        im = im.resize((int(im.width * 0.88), int(im.height * 0.88)), Image.LANCZOS)


def sheet(title, tiles, strip=None, cols=3, tile_px=420, out=None, subtitle=""):
    """tiles: [(png_path, label_line1, label_line2)], strip: optional (png_path, caption)."""
    if not available():
        return None
    pad, head, lab = 10, 54, 40
    rows = (len(tiles) + cols - 1) // cols
    width = cols * tile_px + (cols + 1) * pad
    strip_img = None
    strip_h = 0
    if strip:
        strip_img = Image.open(strip[0]).convert("RGB")
        sw = width - 2 * pad
        strip_img = strip_img.resize((sw, int(strip_img.height * sw / strip_img.width)), Image.LANCZOS)
        strip_h = strip_img.height + lab + pad
    height = head + rows * (tile_px + lab + pad) + pad + strip_h
    im = Image.new("RGB", (width, height), (34, 37, 42))
    d = ImageDraw.Draw(im)
    d.text((pad + 4, 8), title, fill=(245, 236, 210), font=_font(24))
    if subtitle:
        d.text((pad + 4, 34), subtitle, fill=(170, 176, 186), font=_font(14))
    for i, (png, l1, l2) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = pad + c * (tile_px + pad)
        y = head + r * (tile_px + lab + pad)
        t = Image.open(png).convert("RGB").resize((tile_px, tile_px), Image.LANCZOS)
        im.paste(t, (x, y))
        d.text((x + 4, y + tile_px + 3), l1, fill=(240, 240, 240), font=_font(16))
        d.text((x + 4, y + tile_px + 21), l2, fill=(160, 168, 178), font=_font(13))
    if strip_img:
        y = head + rows * (tile_px + lab + pad)
        im.paste(strip_img, (pad, y))
        d.text((pad + 4, y + strip_img.height + 4), strip[1], fill=(200, 205, 212), font=_font(15))
    if out:
        return save_jpeg_under(im, out)
    return im
