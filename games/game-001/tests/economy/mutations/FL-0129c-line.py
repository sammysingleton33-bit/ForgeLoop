"""FL-0129c the wall line (UI/WallLine, BuildMenuController's two-ends mode, PlacementBar's noTurn, Text's line reasons).
Each row breaks one rule and expects a named WallLine spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0129c-line.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
W, B, P, X = U + "WallLine.luau", C + "BuildMenuController.luau", U + "PlacementBar.luau", U + "Text.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/WallLine"]

ROWS = [
    ("no grid snap", W, "return math.floor(v / grid + 0.5) * grid", "return v", "snaps both ends to the grid"),
    ("pieces from the end, not the middle", W, "local at = (i - 0.5) * segment", "local at = i * segment",
     "snaps both ends to the grid"),
    ("yaw sign flipped", W, "plan.yaw = math.atan2(-uz, ux)", "plan.yaw = math.atan2(uz, ux)", "snaps both ends"),
    ("floor, not round", W, "math.floor(length / segment + 0.5)", "math.floor(length / segment)", "rounds to whole"),
    ("no too_short", W, "if length < grid then", "if false then", "rounds to whole"),
    ("too_long off by one", W, "if count > max then", "if count > max + 1 then", "rounds to whole"),
    ("cost not times count", W, "total[currency] = amount * count", "total[currency] = amount", "prices a line"),
    ("line mode never on", B, "if buildingType == BuildMenuController.LINE_TYPE and self.hud:hasRemote(BuildMenuController.LINE) then",
     "if false then", "sets the start, previews"),
    ("line mode without the remote", B, "and self.hud:hasRemote(BuildMenuController.LINE) then", "then",
     "places one wall as before"),
    ("start not set on confirm", B, "\t\tline.from = p.position\n", "\t\tline.from = nil\n", "sets the start, previews"),
    ("no affordability check", B, "p.status, p.reason = \"bad\", Text.reason(\"cannot_afford\", \"line\")", "local _ = 0",
     "the whole line's price"),
    ("one ghost only", B, "\twhile #line.ghosts < #pieces - 1 do", "\twhile false do", "sets the start, previews"),
    ("ghosts stay after cancel", B, "\tfor _, g in if self.placing and self.placing.line then self.placing.line.ghosts else {} do\n\t\tg:destroy()",
     "\tfor _, g in {} do\n\t\tg:destroy()", "keeps the line open"),
    ("Turn turns a line", B, "\tif p.line then\n\t\treturn -- a wall line faces along itself: no Turn", "\tif false then\n\t\treturn",
     "Turn does nothing"),
    ("refusal ends the line", B, "\t\t\tlocal text = Text.reason(if called then reason else nil, \"line\")",
     "\t\t\tself:_stop()\n\t\t\tdo return end\n\t\t\tlocal text = Text.reason(if called then reason else nil, \"line\")",
     "keeps the line open"),
    ("empty id list accepted", B, "type(result) == \"table\" and #result > 0", "type(result) == \"table\"", "keeps the line open"),
    ("wrong ends sent", B, "BuildMenuController.LINE_TYPE, plan.from, plan.to)", "BuildMenuController.LINE_TYPE, plan.to, plan.from)",
     "sends both ends in one call"),
    ("Turn shown on a line", B, "noTurn = line ~= nil,", "noTurn = false,", "fits the phone bar"),
    ("bar keeps Turn", P, "local turn = model.noTurn ~= true", "local turn = true", "sets the start, previews"),
    # FORGE-07 L1-L3 on #308
    ("start checked like a piece", B, "p.position, p.key, p.status, p.reason = snapped, key, \"ok\", nil\n\t\tself._checker:cancel()",
     "p.position, p.key, p.status, p.reason = snapped, key, \"pending\", nil\n\t\tself._checker:request(p.type, snapped, p.rot)",
     "sets the start, previews"),
    ("the exact price reads short", B, "short = (have[c.currency] or 0) < amount })", "short = (have[c.currency] or 0) <= amount })",
     "pays for the line exactly"),
    ("line price not times count", B, "local total = WallLine.cost(per, count)", "local total = WallLine.cost(per, 1)",
     "sets the start, previews"),
    ("desktop hint ignored", P, "\t\t\ttext = model.hint\n", "\t\t\ttext = nil\n", "sets the start, previews"),
    ("segment not the catalog's", W, "WallLine.SEGMENT = 32", "WallLine.SEGMENT = 30", "the catalog's placeSize"),
    ("line reasons unused", X, "\tif context == \"line\" and LINE_REASONS[key] then", "\tif false then", "words every"),
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
