"""Back key in FORGE-03's drawers (FL-0059 follow-up to FORGE-04's #130): mutation rows. Each row
breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0059-back.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
C = "games/game-001/src/client/Controllers/"
H = C + "KingdomHudController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/"]
M = [
    ("never registers", H, "if self.state.menu ~= nil and self._releaseBack == nil and not self._destroyed then",
     "if false then", "closes the open drawer"),
    ("never releases", H, "elseif self.state.menu == nil and self._releaseBack ~= nil then", "elseif false then",
     "closes the open drawer"),
    ("setMenu skips the sync", H, "\tself.state.menu = id\n\tself:_syncBack()\n", "\tself.state.menu = id\n",
     "closes the open drawer"),
    ("one handler per menu switch", H, "self._releaseBack == nil and not self._destroyed",
     "not self._destroyed", "closes the open drawer"),
    ("press does not close", H, "\tself:setMenu(nil)\n\treturn true\nend\n\nfunction KingdomHudController:_syncBack",
     "\treturn true\nend\n\nfunction KingdomHudController:_syncBack", "closes the open drawer"),
    ("step ignored", H, "\t\tif ok and took == true then\n\t\t\treturn true\n\t\tend\n\tend\n\tself:setMenu(nil)",
     "\tend\n\tself:setMenu(nil)", "steps back inside a panel first"),
    ("step error escapes", H, "local ok, took = pcall(step)", "local ok, took = true, step()",
     "a step that errors"),
    ("destroy keeps the handler", H, "\tif self._releaseBack ~= nil then\n\t\tpcall(self._releaseBack)",
     "\tif false then\n\t\tpcall(self._releaseBack)", "a step that errors"),
    ("no kingdom step", H, "\t\tif self.state.panel.upgradeId == nil then\n\t\t\treturn false",
     "\t\tif true then\n\t\t\treturn false", "steps back inside a panel first"),
    ("build step on desktop", C + "BuildMenuController.luau",
     'if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then',
     'if self.state.phoneView ~= "detail" then', "steps back inside a panel first"),
    ("no build step", C + "BuildMenuController.luau",
     'if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then', "if true then",
     "steps back inside a panel first"),
    ("no reputation step", C + "ReputationPanelController.luau",
     'if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then', "if true then",
     "the back key (#130) on a phone"),
    ("no plot step", C + "PlotPickerController.luau",
     'if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then', "if true then",
     "the back key (#130) on a phone"),
    ("no conversation step", C + "ConversationController.luau",
     'if self.state == nil or self.state.phase ~= "confirming" then', "if true then", "the back key (#130, Studio E11)"),
]
bad = 0
for name, path, old, new, expect in M:
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
print(f"{len(M) - bad}/{len(M)} caught")
sys.exit(1 if bad else 0)
