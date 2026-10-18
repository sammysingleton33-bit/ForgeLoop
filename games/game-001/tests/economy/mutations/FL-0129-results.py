"""FL-0129: Results + the leadership recap ("Your reign"). Each row breaks one rule and expects a named
spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0129-results.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
M = "games/game-001/src/client/UI/RecapModel.luau"
V = "games/game-001/src/client/UI/LeadershipRecap.luau"
C = "games/game-001/src/client/Controllers/LeadershipRecapController.luau"
S = "games/game-001/src/client/Controllers/SliceSummaryController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/Recap"]
ROWS = [
    ("start follows the end", M, "\t\tif track.start == nil and active then\n\t\t\ttrack.start = table.clone(rep.values)",
     "\t\tif active then\n\t\t\ttrack.start = table.clone(rep.values)", "start → end per value"),
    ("smallest decisions first", M, "return math.abs(a.delta) > math.abs(b.delta)", "return math.abs(a.delta) < math.abs(b.delta)",
     "the biggest decisions first"),
    ("all decisions kept", M, "while #decisions > RecapModel.DECISIONS do", "while false do", "the biggest decisions first"),
    ("history forgotten when it scrolls", M, "\t\t\t\tif not track.seen[id] then", "\t\t\t\ttrack.entries = {}\n\t\t\t\tif not track.seen[id] then",
     "start → end per value"),
    ("a new match keeps the old one", M, "\tif key ~= track.key or (track.lobby and phase == \"Founding\") then",
     "\tif track.key == nil then", "a new match starts over"),
    ("stale history counted in a new match", M, "\t\t\t\ttrack.seen[`{e.t}|{e.category}|{e.text}`] = true", "\t\t\t\tlocal _ = e",
     "a new match starts over"),
    ("citizens never compared", M, "\t\tif track.citizens == nil and active then\n\t\t\ttrack.citizens = { start = total, finish = total }",
     "\t\tif false then\n\t\t\ttrack.citizens = { start = total, finish = total }", "start → end per value"),
    ("the fall forgets the reign", M, "\tlocal active = phase ~= nil and ACTIVE[phase] == true\n",
     "\tlocal active = phase ~= nil and ACTIVE[phase] == true\n\tif type(rep) ~= \"table\" or not rep.known then\n\t\ttrack.finish = nil\n\tend\n",
     "a ruler whose kingdom fell"),
    ("the fall forgets the citizens", M, "\tif total ~= nil then\n", "\tif total == nil then\n\t\ttrack.citizens = nil\n\tend\n\tif total ~= nil then\n",
     "a ruler whose kingdom fell"),
    ("no Your reign button", S, "local hasRecap = recapController ~= nil and recapController:recap() ~= nil", "local hasRecap = false",
     "the summary offers Your reign"),
    ("button without a recap", S, "local hasRecap = recapController ~= nil and recapController:recap() ~= nil",
     "local hasRecap = true", "there is no Your reign button"),
    ("Back goes nowhere", C, "\t\tonBack = function()\n\t\t\tself:close()", "\t\tonBack = function()\n\t\t\tlocal _ = self",
     "Back returns"),
    ("Continue leaves the recap open", S, "\tif recap and recap.isOpen then\n\t\trecap:close()", "\tif false then\n\t\trecap:close()",
     "Continue closes the summary and the recap"),
    ("decision rows misnamed", V, '\t\tName = "Decision_" .. index,', '\t\tName = "Decision_" .. order,', "Back returns"),
    ("phone in one column", V, "\tif phone then\n\t\tleft = column(\"Left\"", "\tif false then\n\t\tleft = column(\"Left\"",
     "two columns inside the screen"),
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
