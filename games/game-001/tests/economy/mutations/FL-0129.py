"""FL-0129a (Operation Crownfall): the phase bar and the Kingdom panel's Rivals tab (war and peace).
Each row breaks one rule and expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0129.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in
which no spec file ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name), spec filter).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
H = "games/game-001/src/client/Controllers/KingdomHudController.luau"
DM = U + "DiplomacyModel.luau"
RL = U + "RivalsList.luau"
D = "economy/Diplomacy"
K = "economy/KingdomUI"
M = [
    # the phase bar
    ("no next phase", U + "HudModel.luau", "local nextPhase = if step then HudModel.PHASES[step + 1] else nil",
     "local nextPhase = nil", "with what it opens", K),
    ("no note on Conflict", U + "HudModel.luau", 'HudModel.NEXT_NOTE = table.freeze({ Conflict = "war opens" })',
     "HudModel.NEXT_NOTE = table.freeze({})", "with what it opens", K),
    ("track on phones", U + "KingdomHud.luau", "local show = not phone and timer.step ~= nil",
     "local show = timer.step ~= nil", "phase track", K),
    ("track states off by one", U + "KingdomHud.luau", 'if i < timer.step then "done"',
     'if i <= timer.step then "done"', "phase track", K),
    # the rules the buttons follow (DiplomacyModel)
    ("war open before Conflict", DM, "if phase and BEFORE_WAR[phase] then", "if false then",
     "war is closed before Conflict", D),
    ("grace ignored", DM, 'if type(grace) == "number" and grace > now then', "if false then",
     "during grace", D),
    ("truce ignored", DM, "local truce = if war then nil else truceUntil(diplomacy, mine.id, kingdom.id, now)",
     "local truce = nil", "in a truce", D),
    ("my offer not waited for", DM, "enabled = ours == nil,", "enabled = true,", "mine waits", D),
    ("offers not counted", DM, "incoming += 1", "incoming += 0", "counts as incoming", D),
    # the Rivals tab and the controller
    ("declare without asking", H, 'if action == "declareWar" then\n\t\tself.state.panel.confirmWar = kingdomId',
     'if false then\n\t\tself.state.panel.confirmWar = kingdomId', "declare war asks first", D),
    ("confirm sends nothing", H, '\tself:_diplomacy("declareWar", kingdomId, if view then view.senior else nil)', "\tself:render()",
     "declare war asks first", D),
    ("offer never said", H, "\t\t\t\tif not seen[row.id] then", "\t\t\t\tif false then", "an offer of peace", D),
    ("bubble stays after the answer", U + "KingdomHud.luau", "button:update({ badge = count or 0 })",
     "button:update({ badge = count })", "an offer of peace", D),
    ("refusal as the generic line", H, "title = Text.reason(if called then reason else nil),",
     "title = Text.reason(nil),", "a refusal is said in words", D),
    ("a code without words", U + "Text.luau", "\tpeace_cooldown = ", "\tpeace_cooldown_x = ",
     "every diplomacy refusal code reads in words", D),
    ("countdowns rebuild the list", RL, "note = r.note ~= nil,", "note = r.note,", "countdowns tick in place", D),
    ("reason squeezed beside the buttons", RL, 'line(frame, "Reason", reason, 5,', 'line(actions, "Reason", reason, 5,',
     "before Conflict the button explains itself", D),
    ("fixed-width buttons on phones", RL, "\tif phone then\n\t\tCreate(\"Frame\", {\n\t\t\tName = \"Slot_\"",
     "\tif false then\n\t\tCreate(\"Frame\", {\n\t\t\tName = \"Slot_\"", "phone 667", D),
    ("tab labels crowd Close on phones", U + "KingdomPanel.luau", "if phone and #tabs > #KingdomPanel.TABS then",
     "if false then", "phone 667", D),
    # D-054: senior ruler and newcomer lock
    ("co-ruler declares outright", DM, 'label = if senior then "Ask for war" else "Declare war",',
     'label = "Declare war",', "co-ruler asks the senior ruler", D),
    ("co-ruler accepts peace", DM, "local reason = if senior then `{senior} decides` else lockReason(diplomacy, now)",
     "local reason = lockReason(diplomacy, now)", "co-ruler asks the senior ruler", D),
    ("lock ignored", DM, "\treturn lockReason(diplomacy, now)\nend", "\treturn nil\nend", "a new ruler waits", D),
    ("ask said as a declaration", H, "local title = if askedOf then", "local title = if false then",
     "an ask to the senior ruler", D),
    ("Rivals without the remote", H,
     "if not self:hasRemote(KingdomHudController.DIPLOMACY) then\n\t\treturn nil",
     "if false then\n\t\treturn nil", "without the server's diplomacy remote", D),
]
bad = 0
for name, path, old, new, expect, spec in M:
    f = ROOT / path
    src = f.read_text()
    if old not in src:
        print(f"NOT APPLIED | {name}"); bad += 1; continue
    f.write_text(src.replace(old, new, 1))
    try:
        run = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
               "--specs", "games/game-001/tests", spec]
        out = subprocess.run(run, cwd=ROOT, capture_output=True, text=True, timeout=600).stdout
    finally:
        f.write_text(src)
    ran = " 0 spec file(s)" not in out
    hit = ran and any(l.strip().startswith("x ") and expect in l for l in out.splitlines())
    bad += not hit
    print(f"{'CAUGHT' if hit else 'NOT CAUGHT'} | {name} | {expect}")
print(f"{len(M) - bad}/{len(M)} caught")
sys.exit(1 if bad else 0)
