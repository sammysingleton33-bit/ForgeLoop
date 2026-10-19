"""FL-0073 (f) the "Arena & support" page of the leadership recap (ArenaRecapModel, LeadershipRecap,
LeadershipRecapController). Each row breaks one rule and expects a named RecapArena spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0073-recap.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/RecapArena"]
M, V, K = U + "ArenaRecapModel.luau", U + "LeadershipRecap.luau", C + "LeadershipRecapController.luau"
ROWS = [
    ("no reset on a new match", M, "\tif matchKey ~= track.key then\n\t\treset(track, matchKey)", "\tif matchKey ~= track.key then\n\t\ttrack.key = matchKey",
     "a new match key starts over"),
    ("moments counted twice", M, "\t\t\t\tif not track.seen[id] then", "\t\t\t\tif true then", "keeps every moment once"),
    ("smallest first", M, "\t\t\treturn da > db", "\t\t\treturn da < db", "keeps every moment once"),
    ("ties earlier first", M, "\t\treturn (a.t or 0) > (b.t or 0)", "\t\treturn (a.t or 0) < (b.t or 0)", "keeps every moment once"),
    ("more than five", M, "\t\tif #moments >= ArenaRecapModel.MOMENTS then", "\t\tif #moments >= 99 then", "Adoring champion who won"),
    ("not my side", M, "\t\t\tif d.kingdom == mine then", "\t\t\tif d.kingdom ~= mine then", "Adoring champion who won"),
    ("fired ignored", M, "\t\t\ttrack.fired[id] = true", "\t\t\tlocal _ = id", "Adoring champion who won"),
    ("ended ignored", M, "\t\t\ttrack.result = w", "\t\t\tlocal _ = w", "crowd follows design"),
    ("state winner ignored", M, "\t\t\tif userId == arena.winner then", "\t\t\tif false then", "falls back to ArenaState.winner"),
    ("high win is quiet", M, "return if high then \"crowned\" else \"quiet\"", "return if high then \"quiet\" else \"quiet\"",
     "crowd follows design"),
    ("low loss saluted", M, "return if high then \"saluted\" else \"emptied\"", "return \"saluted\"", "Hostile champion who lost"),
    ("draw as a loss", M, "\telseif track.result == \"draw\" then", "\telseif false then", "crowd follows design"),
    ("recap before anything seen", M, "\tif not track.supportSeen and track.side == nil then", "\tif false then",
     "nothing seen"),
    ("no arena page", K, "\t\trecap.arena = ArenaRecapModel.build(self.arenaTrack)", "\t\trecap.arena = nil",
     "Adoring champion who won"),
    ("reopen keeps the page", K, "\tself.isOpen = true\n\tself.page = \"reign\"", "\tself.isOpen = true", "opening the recap again"),
    ("page ignored", V, "local page = if arena and ui.page == \"arena\" then \"arena\" else \"reign\"",
     "local page = \"reign\"", "Adoring champion who won"),
    ("page without arena", V, "local page = if arena and ui.page == \"arena\" then \"arena\" else \"reign\"",
     "local page = if ui.page == \"arena\" then \"arena\" else \"reign\"", "without the arena"),
    ("phone columns over the buttons", V, "local footer = if phone and arena then 52 else 0", "local footer = 0", "phone 667"),
    ("Back half width without arena", V, "back.instance.Size = if arena then UDim2.new(0.5, -8, 0, 44) else UDim2.new(1, 0, 0, 44)",
     "back.instance.Size = UDim2.new(0.5, -8, 0, 44)", "without the arena"),
    # FORGE-07 M1 / L1 / L2 on #229
    ("no arena reads as no champion", M, "\tif not track.pairSeen then\n\t\treturn \"none\"", "\tif false then\n\t\treturn \"none\"",
     "no arena this match"),
    ("pair never marked", M, "\t\t\ttrack.pairSeen = true\n", "", "Not in the arena"),
    ("emptied loadout kept", M, "(picked or #d.triggers > 0)", "(#d.triggers > 0)", "emptied loadout"),
    ("early empty list clears", M, "(picked or #d.triggers > 0)", "(true)", "emptied loadout"),
    ("dedupe by text only", M, "local id = `{m.t}|{m.act}|{m.text}`", "local id = m.text", "same text at another time"),
    ("zero delta kept", M, "\t\tif m.delta ~= 0 then", "\t\tif true then", "same text at another time"),
    ("delta not rounded", M, "local r = if n < 0 then -math.floor(-n + 0.5) else math.floor(n + 0.5)",
     "local r = if n < 0 then -math.floor(-n) else math.floor(n)", "same text at another time"),
    ("perk plural always", M, "perk{if #perks == 1 then \"\" else \"s\"} fired", "perks fired", "emptied loadout"),
    ("winner read mid-duel", M, "\t\tand (arena.stage == \"crowning\" or arena.stage == \"done\")\n", "\t\tand true\n",
     "only once the duel is over"),
    ("any page accepted", K, "self.page = if page == \"arena\" then \"arena\" else \"reign\"", "self.page = page",
     "unknown page name"),
    ("fallen ruler loses the story", K, "if kingdom then kingdom.id else self._lastKingdom", "if kingdom then kingdom.id else nil",
     "kingdom fell keeps"),
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
