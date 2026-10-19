"""FL-0073: the Crown Arena screens (loadout and perk picker, intro card, duel HUD). Each row breaks one rule and
expects a named spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0073-arena.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT (a bad filter must never pass as a kill).
Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
LM, HM, IM = U + "LoadoutModel.luau", U + "ArenaHudModel.luau", U + "ArenaIntroModel.luau"
LC, HC = C + "LoadoutController.luau", C + "ArenaHudController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/Arena"]
ROWS = [
    ("slots ignored", LM, "if not isOffered or #nextChoice.triggers >= slots(support) then",
     "if not isOffered then", "toggling respects the slots"),
    ("unoffered perk accepted", LM, "if not isOffered or #nextChoice.triggers", "if false or #nextChoice.triggers",
     "toggling respects the slots"),
    ("no perks preselected", LM, "\t\tif #triggers >= slots(support) then\n\t\t\tbreak",
     "\t\tif true then\n\t\t\tbreak", "starts on the defaults"),
    ("spectator gets the picker", LM, "\tif side == nil then\n\t\treturn nil\n\tend\n\tlocal duellist",
     "\tside = side or \"a\"\n\tlocal duellist", "only a champion"),
    ("AI matched as the player", LM, "if type(d) == \"table\" and d.userId == userId and d.isAI ~= true then",
     "if type(d) == \"table\" and d.userId == userId then", "only a champion"),
    ("citizen hidden", LM, "citizen = if role then `{o.citizenName} · {role}` else o.citizenName",
     "citizen = nil", "offers show the citizen"),
    ("no urgent clock", LM, "urgent = secondsLeft ~= nil and secondsLeft <= LoadoutModel.URGENT_SEC,",
     "urgent = false,", "turns urgent"),
    ("Ready sends nothing", LC, "return self.hud.remotes:invoke(LoadoutController.CHOOSE, weapon, armour, triggers)",
     "return true", "Ready sends Arena.Choose"),
    ("no resend after Ready", LC, "\t\tself:ready() -- already Ready", "\t\tself:render() -- already Ready",
     "Ready sends Arena.Choose"),
    ("no auto-send", LC, "if st.endsAt - self._env.serverTimeNow() <= LoadoutController.AUTO_SEC then",
     "if false then", "sent before the time runs out"),
    ("refusal unsaid", LM, "else ArenaText.REASONS[sent.reason] or \"That choice was not accepted\"",
     "else \"That choice was not accepted\"", "refusal is said in words"),
    ("gamepad not focused", LC, "env.GuiService.SelectedObject = target or self.view:first()", "local _ = target",
     "a gamepad starts"),
    ("gamepad loses its place", LC, "local selected = if opening then nil else self:_selected()",
     "local selected = nil", "keeps its place"),
    ("hit not applied", HM, "\t\t\ttrack[other(side)].hp = hp", "\t\t\tlocal _ = hp", "hits, snapshots"),
    ("hit applied to the hitter", HM, "\t\t\ttrack[other(side)].hp = hp", "\t\t\ttrack[side].hp = hp",
     "hits, snapshots"),
    ("snapshot ignored", HM, "track[id].stamina = share(s.staminaShare) or track[id].stamina",
     "track[id].stamina = track[id].stamina", "hits, snapshots"),
    ("trigger never spent", HM, "elseif now - firedAt < ArenaHudModel.ACTIVE_SEC then \"active\"",
     "elseif true then \"active\"", "armed → active → spent"),
    ("trigger refires", HM, "if id and track[side].fired[id] == nil then", "if id then", "armed → active → spent"),
    ("viewer not on the left", HM, "local leftSide = mine or \"a\"", "local leftSide = \"a\"",
     "the viewer's side is on the left"),
    ("kingdom HUD stays in the duel", HC, "if ArenaHudController.FOCUS[stage] then\n\t\treturn true",
     "if false then\n\t\treturn true", "the kingdom HUD steps aside"),
    ("champion keeps the kingdom HUD in loadout", HC,
     "return stage == \"loadout\" and LoadoutModel.side(self.state, self:userId()) ~= nil",
     "return stage == \"loadout\"", "a spectator gets no picker"),
    ("intro reasons dropped", IM, "if type(r) == \"string\" and r ~= \"\" and #reasons < ArenaIntroModel.REASONS then",
     "if false then", "tier, three reasons"),
    ("events ignored", HC, "\t\tArenaHudModel.apply(self.track, event, now)", "\t\tlocal _ = event",
     "follows hits, snapshots and perks"),
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
