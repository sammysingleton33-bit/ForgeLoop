"""phone-audit.py — the phone-fit audit (release checklist L7) over the renderer's layout files.

    PROJECT=games/game-001/default.project.json DEVICES=phone-se bash design/ui/render/shoot-luau.sh   # every scene
    python3 design/ui/render/phone-audit.py [device]        # default phone-se (667 x 375)

For every out/<scene>-<device>.layout.json it lists:
  clipped    text wider (one line) or taller (wrapped) than its box (engine.js marks it), so Roblox cuts it
  offscreen  a GuiObject that reaches past the screen edge (inside a ScrollingFrame is fine: it scrolls)
Exit 1 when anything is listed. A headless approximation (README "Known deviations"); Studio on a device decides.
"""
import json, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
device = sys.argv[1] if len(sys.argv) > 1 else "phone-se"
devices = json.loads((HERE / "devices.json").read_text())
dev = devices.get(device) or {}
W, H = dev.get("width", 667), dev.get("height", 375)
bad = 0
for f in sorted((HERE / "out").glob(f"*-{device}.layout.json")):
    scene = f.name[: -len(f"-{device}.layout.json")]
    items = json.loads(f.read_text())
    scrollers = [e["path"] + "." for e in items if e["class"] == "ScrollingFrame"]
    issues = []
    for e in items:
        if e["class"] in ("ScreenGui",) or e["path"].count(".") <= 1:
            continue
        if e.get("clipped"):
            issues.append(f"clipped   {e['path']}")
        inside_scroll = any(e["path"].startswith(s) for s in scrollers)
        if not inside_scroll and e.get("w", 0) > 0 and e.get("h", 0) > 0:
            if e["x"] < -0.5 or e["y"] < -0.5 or e["x"] + e["w"] > W + 0.5 or e["y"] + e["h"] > H + 0.5:
                issues.append(f"offscreen {e['path']} ({e['x']:.0f},{e['y']:.0f} {e['w']:.0f}x{e['h']:.0f})")
    if issues:
        bad += 1
        print(f"## {scene}")
        for i in issues:
            print("   " + i)
print(f"{bad} scene(s) with issues at {device} ({W}x{H})")
sys.exit(1 if bad else 0)
