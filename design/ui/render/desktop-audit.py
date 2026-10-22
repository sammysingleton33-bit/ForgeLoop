"""desktop-audit.py — fit audit at phone-se and the three desktop sizes (FL-0138 c) over the renderer's layout files.

    DEVICES="phone-se desktop-720 desktop desktop-1440" PROJECT=games/game-001/default.project.json \
        bash design/ui/render/shoot-luau.sh <absolute scene paths ...>        # render first
    python3 design/ui/render/desktop-audit.py [device ...]   # default: phone-se desktop-720 desktop desktop-1440
    python3 design/ui/render/desktop-audit.py --no-overlap phone-se          # clipped/offscreen only

Per device it runs the checks of phone-audit.py (same rules, same output):
  clipped    text wider (one line) or taller (wrapped) than its box (engine.js marks it), so Roblox cuts it
  offscreen  a GuiObject past the screen edge (inside a ScrollingFrame is fine: it scrolls)
and adds:
  overlap    two top-level WIDGETS whose rectangles intersect by more than 4 px in both directions.
             A widget is the first GuiObject, walking down from a ScreenGui, that does not cover most (85 %) of its
             ScreenGui: full-screen Root/Hud/Probe frames are containers and are looked through. So widgets are the
             HUD crest, pills, rail, queue, the drawer, a toast stack, a sheet, a dialog, ...
             Not reported (intended stacking, keeps the list low-noise):
               - widgets under a MODAL: a full-size container that paints a background, or has a full-size painted
                 child (a Scrim), marks everything below it as modal; a modal covers whatever is under it by design
               - decorations: a widget with no text, image, button or viewport in it (a dim band, a glow)
             A widget's rectangle is what it draws: a transparent container counts as the union of its painted /
             text / image descendants (a toast Stack frame is taller than its toasts). Descendants are not clipped
             to their parent here, so a scrolled-away list item can still count (rare; check the PNG).
               - widgets of layers that are not drawn on the same screen area (TopbarSafeInsets band vs the rest
                 never overlap geometrically, so nothing to skip there)
               - pairs in OVERLAP_OK (named, intended overlaps; add a reason)
Exit 0 when nothing is listed, 1 when anything is, 2 when the pinned fonts are missing (see phone-audit.py).
A headless approximation (README "Known deviations"); Studio decides.
"""
import json, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "out"
SKIP = {"crests", "kit", "selftest"}  # design sheets / renderer self-test, not game UI
DEFAULT = ["phone-se", "desktop-720", "desktop", "desktop-1440"]
FULL = 0.85  # a node covering this share of its ScreenGui is a container, not a widget
MIN_OVERLAP = 4.0  # px in both directions
CONTENT = {"TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ViewportFrame"}
# (widget path suffix A, widget path suffix B): reason. Order-insensitive; matched with str.endswith.
OVERLAP_OK = {
    # FL-0142: on a phone the 10 s champion vote (no scrim, so the arena stays in view) covers the resource pills;
    # nothing on the pills is needed while it is open (FORGE-07 L4 on #265)
    ("Hud.Pills", "ArenaVote.Panel"),
}

FONTS = HERE.parent / "node_modules" / "@fontsource" / "montserrat" / "files"
if not FONTS.is_dir():
    print(f"desktop-audit: the pinned fonts are missing ({FONTS}); run `npm ci` in design/ui and render again")
    sys.exit(2)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
overlap_on = "--no-overlap" not in sys.argv
devices = json.loads((HERE / "devices.json").read_text())


def snapshot_props(scene, device):
    """path -> props from out/<scene>-<device>.json (first node per path)."""
    f = OUT / f"{scene}-{device}.json"
    props = {}
    if not f.exists():
        return props

    def walk(n, prefix):
        path = f"{prefix}.{n['name']}" if prefix else n["name"]
        props.setdefault(path, n.get("props") or {})
        for c in n.get("children") or []:
            walk(c, path)

    for g in json.loads(f.read_text()).get("guis") or []:
        walk(g, "")
    return props


def widgets(items, props):
    """Top-level widgets: [(entry, layer, modal)]."""
    by_parent = {}
    for e in items:
        parent = e["path"].rsplit(".", 1)[0] if "." in e["path"] else None
        by_parent.setdefault(parent, []).append(e)
    found = []

    def paints(path):
        p = props.get(path, {})
        bt = p.get("BackgroundTransparency", 1 if p else 0)
        return isinstance(bt, (int, float)) and bt < 0.99

    def content(e):
        """Has text, an image or a button in its subtree (else it is a decoration: a dim, a glow)."""
        if e["class"] in CONTENT:
            return True
        return any(content(c) for c in by_parent.get(e["path"], []))

    def down(e, layer, modal):
        area = layer["w"] * layer["h"] or 1
        kids = [c for c in by_parent.get(e["path"], []) if c.get("w", 0) > 0 and c.get("h", 0) > 0]
        full = [c for c in kids if c["w"] * c["h"] >= FULL * area]
        # a full-size painted sibling (a Scrim) makes this container a modal
        modal = modal or any(paints(c["path"]) for c in full)
        for c in kids:
            if c in full:
                down(c, layer, modal)
            elif content(c):
                box = visible(c)
                if box:
                    found.append(({**c, **box}, layer, modal))

    def visible(e):
        """The part of a widget that is drawn: its own box if it paints or is content, else the union of its
        children's (a transparent toast Stack or a list container is as big as what it shows, not its frame)."""
        if e["class"] in CONTENT or paints(e["path"]):
            return {"x": e["x"], "y": e["y"], "w": e["w"], "h": e["h"]}
        boxes = [b for c in by_parent.get(e["path"], []) if c.get("w", 0) > 0 and c.get("h", 0) > 0
                 for b in [visible(c)] if b]
        if not boxes:
            return None
        x0, y0 = min(b["x"] for b in boxes), min(b["y"] for b in boxes)
        x1, y1 = max(b["x"] + b["w"] for b in boxes), max(b["y"] + b["h"] for b in boxes)
        if clips(e):  # what it shows is cut to its own rectangle
            x0, y0 = max(x0, e["x"]), max(y0, e["y"])
            x1, y1 = min(x1, e["x"] + e["w"]), min(y1, e["y"] + e["h"])
            if x1 <= x0 or y1 <= y0:
                return None
        return {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}

    def clips(e):
        return e["class"] in ("ScrollingFrame", "CanvasGroup") or props.get(e["path"], {}).get("ClipsDescendants") is True

    for layer in by_parent.get(None, []):
        if layer["class"] == "ScreenGui":
            down(layer, layer, False)
    return found


def overlaps(items, props):
    ws = [w for w in widgets(items, props) if not w[2]]
    out = []
    for i in range(len(ws)):
        a = ws[i][0]
        for j in range(i + 1, len(ws)):
            b = ws[j][0]
            dx = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
            dy = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
            if dx <= MIN_OVERLAP or dy <= MIN_OVERLAP:
                continue
            if any(
                (a["path"].endswith(p) and b["path"].endswith(q)) or (a["path"].endswith(q) and b["path"].endswith(p))
                for (p, q) in OVERLAP_OK
            ):
                continue
            out.append(f"overlap   {a['path']} x {b['path']} ({dx:.0f}x{dy:.0f} px)")
    return out


def audit(device):
    dev = devices.get(device) or {}
    W, H = dev.get("width", 667), dev.get("height", 375)
    bad = total = 0
    counts = {"clipped": 0, "offscreen": 0, "overlap": 0}
    for f in sorted(OUT.glob(f"*-{device}.layout.json")):
        scene = f.name[: -len(f"-{device}.layout.json")]
        if scene in SKIP:
            continue
        total += 1
        items = json.loads(f.read_text())
        scrollers = [e["path"] + "." for e in items if e["class"] == "ScrollingFrame"]
        issues = []
        for e in items:
            if e["class"] == "ScreenGui" or e["path"].count(".") <= 1:
                continue
            if e.get("clipped"):
                issues.append(f"clipped   {e['path']}")
            inside = any(e["path"].startswith(s) for s in scrollers)
            if not inside and e.get("w", 0) > 0 and e.get("h", 0) > 0:
                if e["x"] < -0.5 or e["y"] < -0.5 or e["x"] + e["w"] > W + 0.5 or e["y"] + e["h"] > H + 0.5:
                    issues.append(f"offscreen {e['path']} ({e['x']:.0f},{e['y']:.0f} {e['w']:.0f}x{e['h']:.0f})")
        if overlap_on:
            issues += overlaps(items, snapshot_props(scene, device))
        if issues:
            bad += 1
            print(f"## {scene} @ {device}")
            for i in issues:
                counts[i.split()[0]] += 1
                print("   " + i)
    summary = ", ".join(f"{k} {v}" for k, v in counts.items())
    print(f"== {device} ({W}x{H}): {bad}/{total} scene(s) with issues ({summary})")
    return bad, total


results = [audit(d) for d in (args or DEFAULT)]
missing = [d for d, (_, t) in zip(args or DEFAULT, results) if t == 0]
if missing:
    print(f"desktop-audit: no layout files for {', '.join(missing)} (render them first)")
sys.exit(1 if any(b for b, _ in results) or missing else 0)
