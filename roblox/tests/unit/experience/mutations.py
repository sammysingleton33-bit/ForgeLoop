"""Mutation check for FORGE-04 specs: proves each named spec can fail.

Each row breaks one rule in the source, runs the matching Lune specs, expects the named test to
fail, and restores the file (also on error). Run from anywhere:
    python3 roblox/tests/unit/experience/mutations.py            # all rows
    python3 roblox/tests/unit/experience/mutations.py FL-0025    # one task
Prints one line per row: CAUGHT / NOT CAUGHT / MUTATION NOT APPLIED. Needs lune on PATH.

Rows live in one file per task, mutations/<task>.py (D-038 (7)), so PRs for different tasks never
touch the same file. Each file sets `M = [ (task, file, old, new, spec filter, expected failing
test, project), ... ]` with the path prefixes below; a row whose task is not its file's name is
reported as WRONG FILE.
"""
import runpy, subprocess, sys, re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
S = "roblox/src/server/Services/"; C = "roblox/src/client/Controllers/"; X = "roblox/src/shared/Experience/"
G = "games/game-001/"; C2 = G + "src/client/Controllers/"; F = G + "src/shared/Feedback/"
RUN = {
    "fw": ["lune", "run", "roblox/tests/harness/run.luau"],
    "game": ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json", "--specs", "games/game-001/tests"],
}
PREFIXES = {"S": S, "C": C, "X": X, "G": G, "C2": C2, "F": F}
ROWS_DIR = pathlib.Path(__file__).resolve().parent / "mutations"
M, misplaced = [], []
for rows_file in sorted(ROWS_DIR.glob("FL-*.py")):
    for row in runpy.run_path(str(rows_file), init_globals=PREFIXES)["M"]:
        (M if row[0] == rows_file.stem else misplaced).append(row)
only = sys.argv[1] if len(sys.argv) > 1 else None
rows = [(task, path, filt, expect, "WRONG FILE (move it to mutations/" + task + ".py)")
        for task, path, _, _, filt, expect, _ in misplaced if not only or task == only]
for task, path, old, new, filt, expect, project in M:
    if only and task != only: continue
    f = ROOT / path
    if not f.exists():
        rows.append((task, path, filt, expect, "FILE MISSING")); continue
    src = f.read_text()
    if old not in src:
        rows.append((task, path, filt, expect, "MUTATION NOT APPLIED (text not found)")); continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN[project] + [filt], cwd=ROOT, capture_output=True, text=True, timeout=300).stdout
    finally:
        f.write_text(src)
    failed = [l.strip() for l in out.splitlines() if l.strip().startswith("x ")]
    hit = any(expect in l for l in failed)
    summary = [l for l in out.splitlines() if l.startswith("Lune tests:")]
    rows.append((task, path.split("/")[-1], filt, expect, ("CAUGHT" if hit else "NOT CAUGHT") + " | " + (summary[0] if summary else "?")))
for r in rows:
    print(" | ".join(r))
