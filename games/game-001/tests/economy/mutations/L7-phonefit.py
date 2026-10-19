"""Release checklist L7 (PR #215): the 667 x 375 phone fit. Each row breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/L7-phonefit.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, spec filter, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests"]
ROWS = [
    ("drawer threshold off", U + "Layout.luau", "Layout.PHONE_DRAWER_MIN = 300", "Layout.PHONE_DRAWER_MIN = 0",
     "economy/ReputationModel", "667 × 375 phone wraps"),
    ("pills not a grid", U + "KingdomHud.luau", "local wrapped = h.pills.columns ~= nil and h.pills.columns < #Resources.ids",
     "local wrapped = false", "economy/PhoneFit", "2 × 2 grid"),
    ("chip under a two-row strip", U + "ReputationStrip.luau",
     "local below = self._compact and (self._rows or 1) == 1", "local below = self._compact", "economy/PhoneFit",
     "change chip floats"),
    ("stage over the pills", U + "StageModel.luau", "then pills.y + pills.height + G.hudGap", "then pills.y + G.hudGap",
     "economy/PhoneFit", "stage and the citizen sheet"),
    ("stage under the strip", U + "StageModel.luau", "\t\t\tand pills.rows > 1\n", "\t\t\tand pills.rows > 99\n", "economy/PhoneFit", "stage and the citizen sheet"),
    ("sheet over the second pill row", U + "CitizenModel.luau",
     "local pillsBottom = m.hud.pills.y + (m.hud.pills.height or Layout.PILL_HEIGHT)",
     "local pillsBottom = m.hud.pills.y + Layout.PILL_HEIGHT", "economy/PhoneFit", "stage and the citizen sheet"),
    ("strip shown in a conversation", C + "ReputationPanelController.luau",
     "local talking = narrow and hud.state.menu == \"conversation\"", "local talking = false", "economy/PhoneFit",
     "strip hides during a conversation"),
    ("toast wider than the band", C + "KingdomHudController.luau",
     "then math.min(m.toast.width, math.max(160, free.width - 20))", "then m.toast.width", "economy/PhoneFit",
     "fits the free band"),
    ("showing toasts keep their width", "roblox/src/shared/UI/ToastStack.luau",
     "\t\ttoast.instance.Size = UDim2.fromOffset(width, 0)", "\t\tlocal _ = toast", "economy/PhoneFit",
     "follows ToastStack:place"),
    ("spectate card buttons small", U + "SpectateScreen.luau",
     "size = \"regular\", onActivated = fn })", "size = \"small\", onActivated = fn })", "economy/Spectate",
     "phone 667 × 375"),
    ("spectate Prev/Next small", U + "SpectateScreen.luau", "\t\tsize = \"regular\",\n\t\twidth = 52,",
     "\t\tsize = \"small\",\n\t\twidth = 52,", "economy/Spectate", "phone 667 × 375"),
    ("spectate panel Leave small", U + "SpectateScreen.luau",
     "variant = \"secondary\", size = \"regular\", onActivated = ui.onLeave })",
     "variant = \"secondary\", size = \"small\", onActivated = ui.onLeave })", "economy/Spectate", "phone 667 × 375"),
    ("rivals actions small on phones", U + "RivalsList.luau", "size = if phone then \"regular\" else \"small\",",
     "size = \"small\",", "economy/Diplomacy", "phone 667 × 375 keeps every row"),
    ("recap Back small", U + "LeadershipRecap.luau", "back.instance.Size = UDim2.new(0.5, -8, 0, 44)",
     "back.instance.Size = UDim2.new(0.5, -8, 0, 32)", "economy/Recap", "phone 667 × 375"),
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
