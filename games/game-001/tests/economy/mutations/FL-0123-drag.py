"""FL-0123 drag a building (BuildMenuController dragPress / dragMove / dragRelease, setEditDrag, moveCooldownLeft).
Each row breaks one rule and expects a named Drag spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0123-drag.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, expected failing test (substring of its name)).
Left out as equivalent (another guard gives the same result): a bad pending verdict that still calls confirm()
(confirm refuses a spot that is not "ok"), a press during a move (startMove already left explore mode, so the mode
check refuses it), destroy without setEditDrag(false) (destroy cancels the move first, which ends the drag) and
dropping dragPress's `state == "destroyed"` check (the client store drops destroyed buildings, KingdomUIModels.spec
"drops destroyed buildings", so the `building == nil` guard refuses first; the Drag spec pins that path).
UI/DragInput (the live mouse/touch adapter) has no rows: the harness has no UserInputService (Studio step U30).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
B = "games/game-001/src/client/Controllers/BuildMenuController.luau"
U = "games/game-001/src/client/Controllers/UpgradePanelController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/Drag"]
ROWS = [
    ("no press point for the camera", B, "\t\t\t\tself:_editDrag(true, press.at)\n", "\t\t\t\tself:_editDrag(true)\n",
     "camera gets the press point"),
    ("second press while one is pending allowed", B, "if self.placing ~= nil or self._press ~= nil then",
     "if self.placing ~= nil then", "one press at a time"),
    ("hold timer fires for a replaced press", B, "\t\tif self._press == press then", "\t\tif self._press ~= nil then",
     "released press's hold timer"),
    ("config cooldown ignored", B, "cooldown = if type(cooldown) == \"number\" then cooldown else BuildMenuController.MOVE_COOLDOWN",
     "cooldown = BuildMenuController.MOVE_COOLDOWN", "config Buildings.moveCooldown"),
    ("no building record", B,
     "presses belong to them\n\tend\n\tlocal store = self.hud.store\n\tlocal building = store:building(buildingId)\n\tlocal mine = store:mine()\n\tif building == nil or mine == nil",
     "presses belong to them\n\tend\n\tlocal store = self.hud.store\n\tlocal building = store:building(buildingId)\n\tlocal mine = store:mine()\n\tif mine == nil",
     "the store does not know"),
    ("hold shorter than a tap", B, "BuildMenuController.DRAG_HOLD_SEC = 0.45", "BuildMenuController.DRAG_HOLD_SEC = 0.2",
     "longer than a tap"),
    ("no hold wait", B, "\t\tself._env.wait(BuildMenuController.DRAG_HOLD_SEC)\n", "", "hold picks it up"),
    ("no edge-pan", B, "\t\t\t\tself:_editDrag(true, press.at)\n", "", "hold picks it up"),
    ("edge-pan never ends", B, "\tself:_editDrag(false)\n\tlocal p = self.placing\n\tif p == nil or p.move == nil then",
     "\tlocal p = self.placing\n\tif p == nil or p.move == nil then", "bad spot"),
    ("drag does not aim", B, "\tif world ~= nil then\n\t\tself:aimAt(world)\n\tend\nend", "\tlocal _ = world\nend", "dragging moves the ghost"),
    ("release does not drop", B, "\tif p.status == \"ok\" then\n\t\tself:confirm()", "\tif p.status == \"ok\" then\n\t\tlocal _ = 0",
     "letting go on a good spot"),
    ("pending not dropped later", B, "\t\tp.dropWhenOk = p.key\n", "", "still being checked"),
    ("slop ignored", B, "\t\tif (screen - press.at).Magnitude > BuildMenuController.DRAG_SLOP then", "\t\tif false then",
     "camera pan, not a drag"),
    ("release before the hold still drags", B, "\tlocal was = self.dragging\n\tself._press = nil\n", "\tlocal was = self.dragging\n",
     "camera pan, not a drag"),
    ("keep draggable", B, "building.kingdom ~= mine.id or building.type == \"keep\" then\n\t\treturn false\n\tend\n\tif building.state == \"destroyed\" or not self.hud:hasRemote(\"Build.Move\") then\n\t\treturn false\n\tend\n\tif self:moveCooldownLeft",
     "building.kingdom ~= mine.id then\n\t\treturn false\n\tend\n\tif building.state == \"destroyed\" or not self.hud:hasRemote(\"Build.Move\") then\n\t\treturn false\n\tend\n\tif self:moveCooldownLeft",
     "never on the keep"),
    ("cooldown ignored", B, "\tif self:moveCooldownLeft(buildingId) > 0 then\n\t\treturn false", "\tif false then\n\t\treturn false",
     "never on the keep"),
    ("any mode drags", B, "\tif input ~= nil and input.mode ~= nil and input.mode ~= \"explore\" then", "\tif false then",
     "another mode owns the pointer"),
    ("cancel keeps edge-pan", B, "function BuildMenuController:_stop()\n\tself._press = nil\n\tself:_editDrag(false)",
     "function BuildMenuController:_stop()\n\tself._press = nil", "cancelling the move"),
    ("cooldown wrong", B, "return if movedAt then math.max(0, cooldown - (self._env.clock() - movedAt)) else 0", "return 0",
     "never on the keep"),
    ("panel ignores the shared rule", U, "\t\tleft = build:moveCooldownLeft(building.id)", "\t\tleft = 0", "same cooldown rule"),
]
bad = 0
for name, path, old, new, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        print(f"NOT APPLIED | {name}"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN, cwd=ROOT, capture_output=True, text=True, timeout=900).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(ROWS) - bad}/{len(ROWS)} caught")
sys.exit(1 if bad else 0)
