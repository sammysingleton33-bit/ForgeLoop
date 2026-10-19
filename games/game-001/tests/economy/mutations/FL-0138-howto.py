"""FL-0138 How to play (HowToPlayModel, HowToPlay, HowToPlayController, the Kingdom menu entry) and the FL-0137
onboarding targets. Each row breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0138-howto.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, spec filter, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests"]
M, V, K = U + "HowToPlayModel.luau", U + "HowToPlay.luau", C + "HowToPlayController.luau"
H = "economy/HowToPlay"
ROWS = [
    ("Crown Points copy drifts", M, "buildings, objectives, enemy units defeated and rival keeps taken", "buildings, land, objectives and raids", H,
     "sources the simulation has"),
    ("keys never bound", K, "\tself:_bind(open)", "\tself:_bind(false)", H, "through ContextActionService"),
    ("handled keys passed through", K, "\t\t\t\t\tthen Enum.ContextActionResult.Sink\n\t\t\t\t\telse Enum.ContextActionResult.Pass",
     "\t\t\t\t\tthen Enum.ContextActionResult.Pass\n\t\t\t\t\telse Enum.ContextActionResult.Sink", H, "through ContextActionService"),
    ("keys act on key up too", K, "if state ~= Enum.UserInputState.Begin then", "if false then", H, "through ContextActionService"),
    ("destroy leaves the rail button", K, "\t\tself.hud:removeRailItem(HowToPlayController.RAIL.id)\n\t\tself._railShown = false",
     "\t\tself._railShown = false", H, "destroy takes the Lobby rail button"),
    ("close returns to any menu", K, "self._returnTo = if from == \"kingdom\" then from else nil", "self._returnTo = from", H,
     "Kingdom menu only"),
    ("phases hard-coded", M, "local fromPacing = c.pacing.modes and c.pacing.modes[mode]", "local fromPacing = Pacing.modes.match",
     H, "follows a changed config"),
    ("minutes floored", M, "math.max(1, math.floor(seconds / 60 + 0.5))", "math.max(1, math.floor(seconds / 60))", H,
     "round to the nearest minute"),
    ("untimed shown", M, "or seconds == math.huge or seconds <= 0 then", "or seconds <= 0 then", H, "untimed phase"),
    ("lock literal", M, "local lock = (c.match.rulers and c.match.rulers.newcomerLockSeconds) or 120", "local lock = 120", H,
     "follows a changed config"),
    ("caps literal", M, "caps.passivePerStat\n", "0.05\n", H, "follows a changed config"),
    ("arena length literal", M, "return minutes(total) or \"a few min\"", "return \"3 min\"", H, "follows a changed config"),
    ("view not clamped", M, "local i = math.clamp(math.floor(index), 1, math.max(1, count))", "local i = index", H,
     "index clamped"),
    ("Back on the first card", V, "state = if v.first then \"disabled\" else \"default\",", "state = \"default\",", H,
     "walk the six cards"),
    ("no Done attribute", V, "nextButton.face:SetAttribute(\"last\", v.last)", "nextButton.face:SetAttribute(\"last\", false)", H,
     "walk the six cards"),
    ("phone box too tall", V, "HowToPlay.PHONE = table.freeze({ width = 600, height = 262 })",
     "HowToPlay.PHONE = table.freeze({ width = 600, height = 400 })", H, "phone 667"),
    ("Back buttons small", V, "back.instance.Size = UDim2.fromOffset(if phone then 110 else 140, 44)",
     "back.instance.Size = UDim2.fromOffset(if phone then 110 else 140, 32)", H, "phone 667"),
    ("Done does not close", K, "\tif self.index >= #self.cards then\n\t\tself:close()", "\tif self.index >= #self.cards then\n\t\tlocal _ = 0",
     H, "walk the six cards"),
    ("next past the end", K, "\tif self.index >= #self.cards then", "\tif self.index > 99 then", H, "walk the six cards"),
    ("back below one", K, "\tif self.index <= 1 then\n\t\treturn\n\tend\n\tself.index -= 1", "\tif false then\n\t\treturn\n\tend\n\tself.index -= 1",
     H, "keyboard"),
    ("keys while closed", K, "\tif not self:isOpen() then\n\t\treturn false\n\tend\n\tif table.find", "\tif false then\n\t\treturn false\n\tend\n\tif table.find",
     H, "keys do nothing while closed"),
    ("Enter ignored", K, "Enum.KeyCode.DPadRight, Enum.KeyCode.Return }", "Enum.KeyCode.DPadRight }", H, "keyboard"),
    ("no return to Kingdom", K, "self._returnTo = if from == \"kingdom\" then from else nil", "self._returnTo = nil", H,
     "returns there when closed"),
    ("reopen keeps the card", K, "\tself.index = 1\n\tself.hud:setMenu(HowToPlayController.MENU)", "\tself.hud:setMenu(HowToPlayController.MENU)", H,
     "starts at the first card"),
    ("back step closes at once", K, "\t\t\tif self.index > 1 then\n\t\t\t\tself:back()\n\t\t\t\treturn true", "\t\t\tif false then\n\t\t\t\tself:back()\n\t\t\t\treturn true",
     H, "back key steps"),
    ("no Lobby rail", K, "local lobby = type(match) == \"table\" and match.phase == \"Lobby\"", "local lobby = false", H, "Lobby countdown"),
    ("rail stays after Lobby", K, "\t\tself.hud:removeRailItem(HowToPlayController.RAIL.id)\n\tend\nend", "\t\tlocal _ = 0\n\tend\nend", H,
     "Lobby countdown"),
    ("rebuilt every render", K, "if key == self._key and self.view.instance ~= nil then", "if false then", H, "re-render"),
    ("no Kingdom entry", C + "KingdomHudController.luau", "onHelp = if self._registry:find(\"HowToPlayController\") ~= nil",
     "onHelp = if false", H, "opens from the Kingdom menu"),
    ("entry without the controller", C + "KingdomHudController.luau", "onHelp = if self._registry:find(\"HowToPlayController\") ~= nil",
     "onHelp = if true", H, "without HowToPlayController"),
    ("Kingdom target", U + "KingdomHud.luau", "target = \"HUD.KingdomButton\"", "target = \"HUD.Kingdom\"", "economy/KingdomUI",
     "shows the kingdom, its rulers"),
    ("Raid target", C + "KingdomHudController.luau", "target = \"HUD.RaidButton\",", "target = nil,", "economy/RaidPing", ""),
]
bad = 0
for name, path, old, new, flt, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        print(f"NOT APPLIED | {name}"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN + [flt], cwd=ROOT, capture_output=True, text=True, timeout=900).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(ROWS) - bad}/{len(ROWS)} caught")
sys.exit(1 if bad else 0)
