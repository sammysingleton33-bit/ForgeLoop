"""Mutation check for FORGE-01 game-001 gameplay specs: proves each named spec can fail.

Each row breaks one rule in the source, runs the matching Lune specs, expects the named test to fail,
and restores the file (also on error). Run from anywhere, and don't edit the tree while it runs (it
mutates the real files, one at a time, and puts them back):
    python3 roblox/tests/unit/gameplay/mutations.py            # all rows
    python3 roblox/tests/unit/gameplay/mutations.py FL-0119    # one task
Prints one line per row: CAUGHT / NOT CAUGHT / MUTATION NOT APPLIED. Needs lune on PATH.

Same layout as roblox/tests/unit/experience/mutations.py (FORGE-04): rows live in one file per task,
mutations/<task>.py, each setting `M = [ (task, file, old, new, spec filter, expected failing test), ... ]`
with the path prefix G (games/game-001/) in scope.
"""
import runpy, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
G = "games/game-001/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests"]
ROWS_DIR = pathlib.Path(__file__).resolve().parent / "mutations"
M, misplaced = [], []
for rows_file in sorted(ROWS_DIR.glob("FL-*.py")):
    for row in runpy.run_path(str(rows_file), init_globals={"G": G})["M"]:
        (M if row[0] == rows_file.stem else misplaced).append(row)
only = sys.argv[1] if len(sys.argv) > 1 else None
rows = [(task, path, filt, expect, "WRONG FILE (move it to mutations/" + task + ".py)")
        for task, path, _, _, filt, expect in misplaced if not only or task == only]
for task, path, old, new, filt, expect in M:
    if only and task != only:
        continue
    f = ROOT / path
    if not f.exists():
        rows.append((task, path, filt, expect, "FILE MISSING"))
        continue
    src = f.read_text()
    if old not in src:
        rows.append((task, path.split("/")[-1], filt, expect, "MUTATION NOT APPLIED (text not found)"))
        continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN + [filt], cwd=ROOT, capture_output=True, text=True, timeout=600).stdout
    finally:
        f.write_text(src)
    failed = [l.strip() for l in out.splitlines() if l.strip().startswith("x ")]
    hit = any(expect in l for l in failed)
    summary = [l for l in out.splitlines() if l.startswith("Lune tests:")]
    rows.append((task, path.split("/")[-1], filt, expect, ("CAUGHT" if hit else "NOT CAUGHT") + " | " + (summary[0] if summary else "?")))
for r in rows:
    print(" | ".join(r))
