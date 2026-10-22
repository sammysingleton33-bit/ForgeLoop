"""FL-0129c slice 2 the gate (UI/GatePick, BuildMenuController's pick-a-wall mode, BuildModel's price override, Text's gate
reasons). Each row breaks one rule and expects a named Gate spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0129c-gate.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
G, B, M, X = U + "GatePick.luau", C + "BuildMenuController.luau", U + "BuildModel.luau", U + "Text.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/Gate"]

ROWS = [
    ("no margin", G, "s.X / 2 + m and math.abs(here.Z) <= s.Y / 2 + m", "s.X / 2 and math.abs(here.Z) <= s.Y / 2",
     "picks the piece the aim is on"),
    ("first match, not nearest", G, "if distance < bestDistance then", "if true then", "picks the piece the aim is on"),
    ("destroyed walls picked", G, "if row.type == \"wall\" and row.state ~= \"destroyed\" and", "if row.type == \"wall\" and",
     "picks the piece the aim is on"),
    ("ignores the wall's turn", G, "local here = row.cframe:PointToObjectSpace(", "local here = CFrame.new(row.cframe.Position):PointToObjectSpace(",
     "picks the piece the aim is on"),
    ("destroyed gates counted", G, "if row.type == \"gate\" and row.state ~= \"destroyed\" then", "if row.type == \"gate\" then",
     "picks the piece the aim is on"),
    ("refund not floored", G, "refund[res] = math.floor(amount * share)", "refund[res] = amount * share", "splits the price"),
    ("net below zero", G, "net[res] = math.max(0, amount - (refund[res] or 0))", "net[res] = amount - (refund[res] or 0)",
     "splits the price"),
    ("gate mode never on", B, "elseif buildingType == BuildMenuController.GATE_TYPE and self.hud:hasRemote(BuildMenuController.GATE) then",
     "elseif false then", "picks a wall piece, previews"),
    ("gate mode without the remote", B, "elseif buildingType == BuildMenuController.GATE_TYPE and self.hud:hasRemote(BuildMenuController.GATE) then",
     "elseif buildingType == BuildMenuController.GATE_TYPE then", "places a gate as one spot"),
    ("open ground accepted", B, "p.status, p.reason = \"bad\", Text.reason(\"not_a_wall\", \"gate\")", "local _ = 0",
     "picks a wall piece, previews"),
    ("no gate limit", B, "elseif def and def.maxCount and GatePick.gates(rows) >= def.maxCount then", "elseif false then",
     "one gate per kingdom"),
    ("no affordability check", B, "p.status, p.reason = \"bad\", Text.reason(\"cannot_afford\", \"gate\")", "local _ = 0",
     "drops below the net price"),
    ("full price in the menu", B, "return { [BuildMenuController.GATE_TYPE] = split.net }", "return nil",
     "holds the price less the refund"),
    ("ghost unturned", B, "self.ghost:show(p.footprint, wall.cframe, nil)", "self.ghost:show(p.footprint, CFrame.new(wall.cframe.Position), nil)",
     "facing as it did"),
    ("ghost stays off the wall", B, "\t\telse\n\t\t\tself.ghost:hide()\n\t\tend", "\t\telse\n\t\tend", "picks a wall piece, previews"),
    ("wrong id sent", B, "invoke(BuildMenuController.GATE, wall.id)", "invoke(BuildMenuController.GATE, wall.id + 1)",
     "sends the piece's id"),
    ("refusal counts as placed", B, "if called and gateId ~= nil and reason == nil then", "if called then", "keeps the gate mode open"),
    ("Turn turns a gate", B, "if p.line or p.gate then", "if p.line then", "Turn does nothing"),
    ("Turn shown on a gate", B, "noTurn = line ~= nil or gate ~= nil,", "noTurn = line ~= nil,", "fits the phone bar"),
    ("detail ignores the price", M, "if entry and opts and opts.cost then", "if false then", "holds the price less the refund"),
    ("row ignores the price", M, "if entry and price then", "if false then", "holds the price less the refund"),
    ("gate reasons unused", X, "\tif context == \"gate\" and GATE_REASONS[key] then", "\tif false then", "words every"),
]

bad = 0
for name, path, old, new, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if src.count(old) != 1:
        print(f"NOT APPLIED | {name} ({src.count(old)} matches)"); bad += 1; continue
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
