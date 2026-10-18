"""FL-0129b: the spectate screen (D-053 (3)). Each row breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0129-spectate.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
C = "games/game-001/src/client/Controllers/KingdomHudSpectateController.luau"
M = "games/game-001/src/client/UI/SpectateModel.luau"
V = "games/game-001/src/client/UI/SpectateScreen.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/Spectate"]
ROWS = [
    ("no title for the fallen", M, "title = if fallen then `{fallen} has fallen` else", "title = if false then `{fallen} has fallen` else",
     "who fell, who took the keep"),
    ("conqueror unnamed", M, "subtitle = if by then `{by} took your keep`", "subtitle = if false then `{by} took your keep`",
     "who fell, who took the keep"),
    ("current row never marked", M, "selected = current ~= nil and SpectateModel.same(target, current),", "selected = false,",
     "the current row follows the camera"),
    ("camera not started", C, "pcall(camera.setActive, camera, true)", "local _ = camera", "the camera on, the drawer closed"),
    ("drawer left open", C, "\t\t\t\tself.hud:setMenu(nil)", "\t\t\t\tlocal _ = self.hud", "the camera on, the drawer closed"),
    ("Stay keeps the card", C, "function KingdomHudSpectateController:stay()\n\tself.state = { card = false,",
     "function KingdomHudSpectateController:stay()\n\tself.state = { card = true,", "Stay leaves the target list"),
    ("tap selects nothing", C, "local ok, target = pcall(camera.select, camera, index)", "local ok, target = false, nil",
     "a tap on a target and Next"),
    ("targetChanged ignored", C, "\t\t\t\t\tself._current = target\n\t\t\t\t\tself:render()", "\t\t\t\t\tself:render()",
     "the current row follows the camera"),
    ("targets never re-read", C, "\t\t\tif self._running and self.spectating then\n\t\t\t\tself:render()",
     "\t\t\tif false then\n\t\t\t\tself:render()", "a tap on a target and Next"),
    ("Leave without asking", C, "\tself.state = { card = self.state.card, confirmLeave = true }\n\tself:render()",
     "\tself:confirmLeave()", "Leave asks first"),
    ("Leave goes nowhere", C, "\t\t\tplayer:Kick(KingdomHudSpectateController.GOODBYE)", "\t\t\tlocal _ = player",
     "Leave leaves the server"),
    ("camera stop ends a server spectate", C, "elseif not active and self.spectating and not self._byServer then",
     "elseif not active and self.spectating then", "a camera that stops alone does not"),
    ("seated again keeps the camera", C, "\t\t\tpcall(camera.setActive, camera, false)", "\t\t\tlocal _ = camera",
     "Match.Spectate(false) (seated again) ends it"),
    ("camera alone shows nothing", C, "\t\t\t\t\tif active and not self.spectating then", "\t\t\t\t\tif false then",
     "the camera alone (no server remote"),
    ("phone shows card and list together", V, "local showPanel = not (phone and state.card)", "local showPanel = true",
     "never both"),
    ("shown over the results", C, "if not self.spectating or KingdomHudSpectateController.PAUSED[phase] then",
     "if not self.spectating then", "Results and the Lobby hide it"),
    ("on a layer a spectator never sees", C, "self.view = self.view or SpectateScreen.new(hud.roots.modals)",
     "self.view = self.view or SpectateScreen.new(hud.roots.menus)", "a real spectator"),
    ("panel under a hidden stack", V, "local top = if state.stackHidden then", "local top = if false then", "a real spectator"),
    ("no empty-list words", V, 'text = "Nothing to watch yet",', 'text = "",', "the list says there is nothing yet"),
]
bad = 0
for name, path, old, new, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        print(f"NOT APPLIED | {name}"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN, cwd=ROOT, capture_output=True, text=True, timeout=600).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(ROWS) - bad}/{len(ROWS)} caught")
sys.exit(1 if bad else 0)
