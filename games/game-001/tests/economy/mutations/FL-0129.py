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
    ("confirm sends nothing", H, '\tself:_diplomacy("declareWar", kingdomId)\nend', "\tself:render()\nend",
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
    ("co-ruler declares outright", DM, 'label = if senior then `Ask {senior} to declare war` else "Declare war",',
     'label = "Declare war",', "co-ruler asks the senior ruler", D),
    ("co-ruler accepts peace", DM, "local reason = if senior then `{senior} decides` else lockReason(diplomacy, now)",
     "local reason = lockReason(diplomacy, now)", "co-ruler asks the senior ruler", D),
    ("lock ignored", DM, "\treturn lockReason(diplomacy, now)\nend", "\treturn nil\nend", "a new ruler waits", D),
    ("long ask squeezed on phones", RL, "Size = if alone and action.ask then UDim2.fromScale(1, 0) else",
     "Size = if false then UDim2.fromScale(1, 0) else", "phone 667", D),
    # FORGE-07's review of #180
    ("M1 toast ignores the server's answer", H,
     'local war = if action == "declareWar" and type(reason) == "string" then WAR_DONE[reason] else nil',
     "local war = nil", "follows the server's answer", D),
    ("L1 fallen kingdom still makes war", DM, "\tif closed then\n\t\tfor _, row in rows do",
     "\tif false then\n\t\tfor _, row in rows do", "a fallen kingdom and a finished match", D),
    ("L2 expired offer keeps the bubble", H, "if count ~= self._railBadges.kingdom then", "if false then",
     "runs out takes the Kingdom bubble", D),
    ("L3 last match's wars kept", "games/game-001/src/client/UI/KingdomStore.luau",
     "if diplomacy ~= nil or self._diplomacy ~= nil then", "if diplomacy ~= nil then",
     "clears last match's wars", D),
    # FORGE-01's final contract (2026-10-18)
    ("seniors read from the wrong kingdom", DM, "seniors[kingdomId] else nil", "seniors.azure else nil",
     "co-ruler asks the senior ruler", D),
    ("ask never said to the senior", H, "\tself:notify({\n\t\tkind = \"warning\",\n\t\ttitle = `{who} asks for war",
     "\tlocal _ = ({\n\t\tkind = \"warning\",\n\t\ttitle = `{who} asks for war", "hears a co-ruler's ask", D),
    ("ask from nowhere said", H, "\tif kingdom == nil then\n\t\treturn\n\tend\n\tlocal name = if type(kingdom.name)",
     "\tif false then\n\t\treturn\n\tend\n\tlocal name = if kingdom and type(kingdom.name)", "hears a co-ruler's ask", D),
    # Raid on the rail (FORGE-04's raid ping)
    ("raid button never shown", H, "\t\traid = ok and alert ~= nil", "\t\traid = false", "shows while a raid lasts", "RaidPing"),
    ("raid tap goes nowhere", H, "\t\t\tpcall(current.goToAlert, current)", "\t\t\tlocal _ = current",
     "shows while a raid lasts", "RaidPing"),
    ("raid button stays after the raid", H, "\t\tself:removeRailItem(KingdomHudController.RAID_RAIL.id)\n",
     "", "gone when the lands are clear", "RaidPing"),
    ("a failing alert() still shows it", H, "\t\tlocal ok, alert = pcall(war.alert, war)\n\t\traid = ok and alert ~= nil",
     "\t\tlocal ok, alert = pcall(war.alert, war)\n\t\traid = (ok or true) and (alert ~= nil or not ok)",
     "no FORGE-04 controller or a failing one", "RaidPing"),
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
