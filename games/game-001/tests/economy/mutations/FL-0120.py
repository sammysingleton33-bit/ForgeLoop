"""FL-0120 (move-edit UI) mutation rows: each row breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0120.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
B = C + "BuildMenuController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/"]
M = [
    ("keep movable", B, 'or building.type == "keep" then\n\t\treturn false', "then\n\t\treturn false", "explains every refusal"),
    ("no remote gate", B, 'if building.state == "destroyed" or not self.hud:hasRemote("Build.Move") then',
     'if building.state == "destroyed" then', "offers Move"),
    ("CanMove -> CanPlace", B, 'if move then\n\t\t\t\treturn hud.remotes:invoke("Build.CanMove"',
     'if false then\n\t\t\t\treturn hud.remotes:invoke("Build.CanMove"', "picks the building up"),
    ("no plot snap", B, "local slot = self:_slotAt(position)\n\t\tp.move.slot = slot",
     "local slot = nil\n\t\tp.move.slot = slot", "snaps to a free plot"),
    ("occupied plot snaps", B, "if slot.occupiedBy == nil or slot.occupiedBy == p.move.id then", "if true then",
     "never snaps"),
    ("wall snaps", B, 'if p == nil or p.move == nil or p.type == "wall" or p.type == "gate" then',
     "if p == nil or p.move == nil then", "never snaps"),
    ("turn not clamped", B, "if not table.find(slot.allowed, p.move.turn) then\n\t\t\t\tp.move.turn = slot.allowed[1]",
     "if false then\n\t\t\t\tp.move.turn = slot.allowed[1]", "keeps the turn only where it fits"),
    ("plot turn back ignored", B, "(if back then -1 else 1)) % #allowed + 1]", "1) % #allowed + 1]",
     "snaps to a free plot"),
    ("MoveToSlot -> Move", B, "if move and slot then\n\t\t\t\treturn", "if false then\n\t\t\t\treturn",
     "snaps to a free plot"),
    ("move success check", B, "(if move then result == true else type(result) == \"number\")", "(called)",
     "explains every refusal"),
    ("movedAt not set", B, "\t\t\tself.movedAt[move.id] = self._env.clock()\n", "", "moves it"),
    ("original not undimmed", B, "\tself._checker:cancel()\n\tself:_undim()", "\tself._checker:cancel()",
     "picks the building up"),
    ("edit mode not tried", B, 'if not self:_setMode("edit") then', "if true then", "picks the building up"),
    ("verdict context", B, 'Text.reason(reason, if p.move then "move" else nil)', "Text.reason(reason)",
     "moves it"),
    ("rot from cframe", B, "rot = math.floor(yaw / (math.pi / 2) + 0.5) % 4", "rot = 0", "picks the building up"),
    # FORGE-07 on #148
    ("B1 panel opens mid-move", C + "UpgradePanelController.luau",
     "\tif self:_editing() then\n\t\treturn\n\tend\n", "", "keeps the move through taps"),
    ("B1 plot drawer opens mid-move", C + "PlotPickerController.luau",
     "\tif self:_editing() then\n\t\treturn\n\tend\n", "", "keeps the move through taps"),
    ("B1 moving() false", B, "return self.placing ~= nil and self.placing.move ~= nil", "return false",
     "keeps the move through taps"),
    ("M1 own-plot turn ignored", B, "fromTurn = math.floor((yaw - frame.yaw) / (math.pi / 2) + 0.5) % 4",
     "fromTurn = 0", "starts at the turn it stands at"),
    ("L3 same plot is a move", B, "slot.id == move.fromSlot and move.turn == move.fromTurn", "false",
     "starts at the turn it stands at"),
    ("L3 same turn ignored", B, "slot.id == move.fromSlot and move.turn == move.fromTurn",
     "slot.id == move.fromSlot", "starts at the turn it stands at"),
    ("L3 same cell is a move", B, "else p.key == move.fromKey", "else false", "starts at the turn it stands at"),
    ("L5 hint says places", U + "PlacementBar.luau", 'Click {model.clickVerb or "places"}', "Click places",
     "starts at the turn it stands at"),
    ("panel keep", C + "UpgradePanelController.luau", 'if building.type == "keep" or building.state',
     "if building.state", "offers Move"),
    ("panel cooldown", C + "UpgradePanelController.luau", "\tif left > 0 then\n\t\tself:_renderAfter(left)",
     "\tif false then\n\t\tself:_renderAfter(left)", "moves it"),
    ("move reason context", U + "Text.luau", 'if context == "move" and MOVE_REASONS[key] then', "if false then",
     "explains every refusal"),
    ("plot contains", U + "Slots.luau",
     "return math.abs(p.X) <= frame.size.X / 2 and math.abs(p.Z) <= frame.size.Y / 2", "return true",
     "snaps to a free plot"),
    ("bar confirm word", U + "PlacementBar.luau", 'text = model.confirm or "Place",', 'text = "Place",',
     "picks the building up"),
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
