"""'Waiting' on the rail (FL-0088 card, FL-0115 requests) and FORGE-07's #162 L1: mutation rows. Each row
breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0088-waiting.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
C = "games/game-001/src/client/Controllers/"
CARD = C + "CitizenCardController.luau"
H = C + "KingdomHudController.luau"
V = "games/game-001/src/client/UI/KingdomHud.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/"]
M = [
    ("shown while nobody waits", V, "button.instance.Visible = count ~= nil and count > 0",
     "button.instance.Visible = true", "shows how many citizens wait"),
    ("count never polled", CARD, "\t\t\tif self._running then\n\t\t\t\tself:refreshWaiting()",
     "\t\t\tif false then\n\t\t\t\tself:refreshWaiting()", "shows how many citizens wait"),
    ("tap opens a menu", H, "\t\tif item.id == id and item.onActivated ~= nil then",
     "\t\tif false then", "a tap goes to the oldest request"),
    ("tap goes back", CARD, "pcall(indicator.cycleRequests, indicator, 1)",
     "pcall(indicator.cycleRequests, indicator, -1)", "a tap goes to the oldest request"),
    ("shown while placing", CARD, "if indicator == nil or hud.state.placing or hud.state.menu",
     "if indicator == nil or hud.state.menu", "hidden while placing"),
    ("shown in a conversation", CARD, 'or hud.state.menu == "conversation" then', "then",
     "hidden while placing"),
    ("silent in the walking view", CARD, "\tself.hud:notify({ kind = \"info\", title = CitizenText.WAITING_AERIAL })\n",
     "", "in the walking view"),
    ("lost on a rail rebuild", V, "\t\tself.rail[menu.id] = button\n\t\tself:_applyBadge(menu.id)",
     "\t\tself.rail[menu.id] = button", "keeps its count across a rail rebuild"),
    ("lost before mount", H, "\tfor id, count in self._railBadges do\n\t\tself.view:setRailBadge(id, count)",
     "\tfor id, count in {} do\n\t\tself.view:setRailBadge(id, count)", "before the HUD mounts"),
    ("button without an indicator", CARD,
     "if indicator == nil or indicator.count == nil or indicator.cycleRequests == nil then\n\t\treturn",
     "if false then\n\t\treturn", "no indicator, no button"),
    ("#162 L1: inactive HUD keeps the handler", H,
     "\t\tself:_syncBack() -- the back key's handler goes with the drawer (FORGE-07 L1 on #162)\n", "",
     "the HUD going inactive"),
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
