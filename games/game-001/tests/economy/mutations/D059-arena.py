"""D-059 arena pass: the phase pill names the Crown Arena's stage, the duel HUD says how the duel ended, the intro card
steps aside for the ring shot, and the crowning names who takes the crown. Each row breaks one rule and expects a
named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/D059-arena.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, filter, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
H, K, A, M, I = U + "HudModel.luau", C + "KingdomHudController.luau", C + "ArenaHudController.luau", U + "ArenaHudModel.luau", C + "ArenaIntroController.luau"


def run(filt):
    return ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
            "--specs", "games/game-001/tests", filt]


ROWS = [
    ("pill ignores the arena", H, "if stage and match.phase ~= \"Results\" and match.phase ~= \"Lobby\" then",
     "if false then", "ArenaPhase", "names the arena, the stage"),
    ("pill arena at Results", H, "if stage and match.phase ~= \"Results\" and match.phase ~= \"Lobby\" then",
     "if stage then", "ArenaPhase", "keeps the phase's own pill"),
    # (no row for a negative stage clock: Format.clock clamps at 0 itself)
    ("controller never told", A, "\t\tself.hud:setArenaState(self.state) -- the phase pill names the arena's stage",
     "\t\tlocal _ = 0", "ArenaPhase", "reads the arena's stage"),
    ("tick ignores the state", K, "HudModel.timer(self.store.match, self._env.serverTimeNow(), self.arenaState)",
     "HudModel.timer(self.store.match, self._env.serverTimeNow())", "ArenaPhase", "reads the arena's stage"),
    ("ended keeps the clock", M, "\tif ended then\n", "\tif false then\n", "ArenaModels", "says how the duel ended"),
    ("ended reason ignored", M, "clock = ArenaHudModel.ENDED[ended.reason] or", "clock = nil or", "ArenaModels",
     "says how the duel ended"),
    ("you win / you lost swapped", M, "(if ended.winner == mine then \"You win\" else \"You lost\")",
     "(if ended.winner ~= mine then \"You win\" else \"You lost\")", "ArenaModels", "says how the duel ended"),
    ("card over the ring", I, "\t\t\treturn nil -- the ring shot: the card steps aside", "\t\t\tlocal _ = 0", "ArenaPhase",
     "steps aside for the intro's last shot"),
    ("no crowning toast", A, "\tif stage == \"crowning\" and before ~= \"crowning\" then\n\t\tself:_announceCrown()",
     "\tif false then\n\t\tself:_announceCrown()", "ArenaPhase", "names the kingdom that takes the crown"),
    ("toast on every push", A, "\tif stage == \"crowning\" and before ~= \"crowning\" then\n\t\tself:_announceCrown()",
     "\tif stage == \"crowning\" then\n\t\tself:_announceCrown()", "ArenaPhase", "names the kingdom that takes the crown"),
    ("coronation ignored", A, "\tlocal kingdomId = state.coronation\n", "\tlocal kingdomId = nil\n", "ArenaPhase",
     "names the kingdom that takes the crown"),
    ("theirs in our accent", A, "kind = if ours then \"achievement\" else \"info\",", "kind = \"achievement\",",
     "ArenaPhase", "names the kingdom that takes the crown"),
]

bad = 0
for name, path, old, new, filt, expect in ROWS:
    f = ROOT / path
    src = f.read_text()
    if src.count(old) != 1:
        print(f"NOT APPLIED | {name} ({src.count(old)} matches)"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(run(filt), cwd=ROOT, capture_output=True, text=True, timeout=900).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(ROWS) - bad}/{len(ROWS)} caught")
sys.exit(1 if bad else 0)
