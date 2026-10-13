"""D-033 (4) colour-vision check: Machado et al. 2009 (severity 1.0) simulation in linear RGB,
CIEDE2000 between kingdom colours, and side-by-side renders. Usage: cvd.py OUTDIR IMG..."""
import sys, math, itertools
import numpy as np
from PIL import Image, ImageDraw

M = {
    "protanopia": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "deuteranopia": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "tritanopia": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}

def to_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def to_srgb(l):
    l = np.clip(l, 0, 1)
    return np.where(l <= 0.0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - 0.055) * 255.0

def sim(rgb, kind):
    if kind == "normal":
        return np.asarray(rgb, float)
    lin = to_lin(np.asarray(rgb, float))
    return to_srgb(lin @ M[kind].T)

def lab(rgb):
    l = to_lin(np.asarray(rgb, float))
    X = l @ np.array([0.4124564, 0.3575761, 0.1804375]); Y = l @ np.array([0.2126729, 0.7151522, 0.0721750]); Z = l @ np.array([0.0193339, 0.1191920, 0.9503041])
    xn, yn, zn = 0.95047, 1.0, 1.08883
    f = lambda t: np.where(t > (6 / 29) ** 3, np.cbrt(t), t / (3 * (6 / 29) ** 2) + 4 / 29)
    fx, fy, fz = f(X / xn), f(Y / yn), f(Z / zn)
    return np.array([116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)])

def de2000(l1, l2):
    L1, a1, b1 = l1; L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2); Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360; h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dLp = L2 - L1; dCp = C2p - C1p
    dh = h2p - h1p
    if C1p * C2p == 0: dh = 0
    elif dh > 180: dh -= 360
    elif dh < -180: dh += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lbp = (L1 + L2) / 2; Cbp = (C1p + C2p) / 2
    if C1p * C2p == 0: hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180: hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360: hbp = (h1p + h2p + 360) / 2
    else: hbp = (h1p + h2p - 360) / 2
    T = 1 - 0.17 * math.cos(math.radians(hbp - 30)) + 0.24 * math.cos(math.radians(2 * hbp)) + 0.32 * math.cos(math.radians(3 * hbp + 6)) - 0.20 * math.cos(math.radians(4 * hbp - 63))
    dTh = 30 * math.exp(-(((hbp - 275) / 25) ** 2)); Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + 0.015 * (Lbp - 50) ** 2 / math.sqrt(20 + (Lbp - 50) ** 2); Sc = 1 + 0.045 * Cbp; Sh = 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dTh)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))

KINGDOMS = {"crimson": (190, 40, 50), "azure": (40, 110, 210), "emerald": (35, 128, 95), "gold": (235, 185, 16)}
GRASS = (110, 160, 80)  # approximate terrain grass in the Luau renders
out = sys.argv[1]
kinds = ["normal", "protanopia", "deuteranopia", "tritanopia"]
print("CIEDE2000 between kingdom colours (and vs grass); < 10 = hard to tell apart at a glance, < 5 = near-identical")
for kind in kinds:
    sims = {k: sim(v, kind) for k, v in KINGDOMS.items()}
    pairs = [(a, b, de2000(lab(sims[a]), lab(sims[b]))) for a, b in itertools.combinations(KINGDOMS, 2)]
    grass = [(k, de2000(lab(sims[k]), lab(sim(GRASS, kind)))) for k in KINGDOMS]
    worst = min(pairs, key=lambda p: p[2])
    print(f"{kind:13s} " + "  ".join(f"{a[:3]}/{b[:3]} {d:5.1f}" for a, b, d in pairs) + f"   | min {worst[0]}/{worst[1]} {worst[2]:.1f}   | vs grass " + " ".join(f"{k[:3]} {d:.1f}" for k, d in grass))
# swatch sheet
W = 120
sheet = Image.new("RGB", (W * 4 + 140, W * 4), (30, 30, 36)); d = ImageDraw.Draw(sheet)
for r, kind in enumerate(kinds):
    d.text((6, r * W + W // 2 - 6), kind, fill=(230, 230, 230))
    for c, (k, v) in enumerate(KINGDOMS.items()):
        col = tuple(int(x) for x in np.round(sim(v, kind)))
        d.rectangle([140 + c * W + 6, r * W + 6, 140 + (c + 1) * W - 6, (r + 1) * W - 6], fill=col)
        d.text((140 + c * W + 10, r * W + 10), k, fill=(255, 255, 255))
sheet.save(f"{out}/swatches.png")
for path in sys.argv[2:]:
    img = np.asarray(Image.open(path).convert("RGB"), float)
    tiles = [Image.fromarray(np.uint8(np.round(sim(img.reshape(-1, 3), kind).reshape(img.shape)))) for kind in kinds]
    w, h = tiles[0].size; scale = min(1.0, 960 / w); tw, th = int(w * scale), int(h * scale)
    grid = Image.new("RGB", (tw * 2, th * 2 + 0), (0, 0, 0))
    for i, t in enumerate(tiles):
        grid.paste(t.resize((tw, th)), ((i % 2) * tw, (i // 2) * th))
    name = path.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    grid.save(f"{out}/cvd-{name}.png")
    print("wrote", f"{out}/cvd-{name}.png", "(TL normal, TR protanopia, BL deuteranopia, BR tritanopia)")
