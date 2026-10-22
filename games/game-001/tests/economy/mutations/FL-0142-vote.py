"""FL-0142 the co-rulers' champion vote (ArenaVoteModel, ArenaVote, ArenaHudVoteController). Each row breaks one
rule and expects a named ArenaVote spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0142-vote.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
M, V, K = U + "ArenaVoteModel.luau", U + "ArenaVote.luau", C + "ArenaHudVoteController.luau"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/ArenaVote"]
ROWS = [
    ("label not held to the button", V, "\t\t\tlabel.Size = UDim2.new(0, each - ArenaVote.PAD, 1, 0)\n", "", "long names are cut"),
    ("wide letters counted narrow", V, "local WIDE = { W = 19, M = 18, m = 16, w = 15 }", "local WIDE = {}", "long names are cut"),
    ("side b never votes", M, "ArenaVoteModel.SIDES = table.freeze({ \"a\", \"b\" })", "ArenaVoteModel.SIDES = table.freeze({ \"a\" })",
     "side b"),
    ("a vote for a ruler who left stays", M, "\t\tpick = nil\n\tend\n\tlocal candidates", "\t\tlocal _ = nil\n\tend\n\tlocal candidates",
     "a vote for a ruler who left"),
    ("no tie hint", M, "A tie goes to the higher leadership.`", "`", "names, 'You', the countdown"),
    ("rebuilt every second", K, "\tstructure.seconds = nil\n\tstructure.clock = nil\n", "", "countdown moves in place"),
    ("clock not moved in place", K, "\t\tself.view:tick(model)\n", "", "countdown ticks down"),
    ("key ignores the screen", K, "local key = Signature.of({ model = structure, breakpoint = m.breakpoint, width = m.width, height = m.height })",
     "local key = Signature.of({ model = structure })", "countdown moves in place"),
    ("toast as an error", K, "self.hud:notify({ kind = \"info\", title = text })", "self.hud:notify({ kind = \"error\", title = text })",
     "says the champion once"),
    ("timeout as long as the vote", K, "ArenaHudVoteController.VOTE_TIMEOUT_SEC = 6", "ArenaHudVoteController.VOTE_TIMEOUT_SEC = 12",
     "never waits longer"),
    ("names not cut", V, "\t\t\ttext = ArenaVote.shorten(c.name, each),", "\t\t\ttext = c.name,", "long names are cut"),
    ("desktop box too short", V, "ArenaVote.SIZE = table.freeze({ width = 520, height = 204 })",
     "ArenaVote.SIZE = table.freeze({ width = 520, height = 120 })", "everything fits"),
    ("buttons ignore the gaps", V, "local each = math.floor((inner - ArenaVote.GAP * (count - 1)) / count)",
     "local each = math.floor(inner / count)", "everything fits"),
    ("under the HUD", V, "\t\tZIndex = 20,\n\t}, { Panel = panel.instance })", "\t\tZIndex = 1,\n\t}, { Panel = panel.instance })",
     "everything fits"),
    ("shown to non-candidates", M, "if type(e) == \"table\" and contains(e.candidates, me) then", "if type(e) == \"table\" then",
     "only a candidate"),
    ("shown outside the vote stage", M, "state.stage ~= \"vote\" or type(state.vote)", "type(state.vote)", "only a candidate"),
    ("countdown floored", M, "math.max(0, math.ceil(state.endsAt - now))", "math.max(0, math.floor(state.endsAt - now))",
     "names, 'You', the countdown"),
    ("everyone counted as voted", M, "\t\tif hasVoted then\n\t\t\tvoted += 1", "\t\tif true then\n\t\t\tvoted += 1",
     "names, 'You', the countdown"),
    ("a refused vote stays gold", M, "pick.candidate == id and pick.status ~= \"failed\"", "pick.candidate == id",
     "names, 'You', the countdown"),
    ("own name, not You", M, "local name = if you then \"You\" else", "local name = if false then \"You\" else",
     "names, 'You', the countdown"),
    ("result for the wrong side", M, "\tlocal d = state[side]\n", "\tlocal d = state.b\n", "says the champion once"),
    ("tap sends the wrong ruler", V, "ui.onVote(c.userId)", "ui.onVote(c.userId + 1)", "a tap sends Arena.Vote"),
    ("small candidate buttons", V, "\t\t\tsize = \"regular\",\n\t\t\twidth = each,", "\t\t\tsize = \"small\",\n\t\t\twidth = each,",
     "phone 667"),
    ("phone box too tall", V, "ArenaVote.PHONE = table.freeze({ width = 520, height = 178 })",
     "ArenaVote.PHONE = table.freeze({ width = 520, height = 400 })", "phone 667"),
    ("two calls at once", K, "\tif self.pick ~= nil and self.pick.status == \"pending\" then\n\t\treturn false\n\tend\n", "",
     "one call at a time"),
    ("any id sent", K, "\tif not known then\n\t\treturn false\n\tend\n", "", "a tap sends Arena.Vote"),
    ("nil answer counted", K, "status = if ok and accepted == true then \"ok\" else \"failed\"",
     "status = if ok and accepted ~= false then \"ok\" else \"failed\"", "refused or dropped"),
    ("no timeout", K, "\t\t\tself.pick = { candidate = candidate, status = \"failed\" }\n\t\t\tself:render()\n\t\tend\n\tend)",
     "\t\t\tlocal _ = 0\n\t\tend\n\tend)", "no answer within"),
    ("a late answer wins", K, "if self._destroyed or token ~= self._token or self.pick == nil then",
     "if self._destroyed or self.pick == nil then", "late answer"),
    ("not dark without the remote", K, "local model = if hud:hasRemote(ArenaHudVoteController.VOTE) then self:model() else nil",
     "local model = self:model()", "dark without the Arena.Vote remote"),
    ("no result toast", K, "\t\t\t\tself.hud:notify({ kind = \"info\", title = text })", "\t\t\t\tlocal _ = text",
     "says the champion once"),
    ("result said again", K, "\t\t\tself._side = nil\n\t\t\tself.pick = nil\n\t\t\tif text", "\t\t\tself.pick = nil\n\t\t\tif text",
     "says the champion once"),
    ("panel stays after the vote", K, "\tif model == nil then\n\t\tself.view:destroy()", "\tif model == nil then\n\t\tlocal _ = 0",
     "closes when the loadout starts"),
    ("no countdown poll", K, "\t\t\tif self._running and st ~= nil and st.stage == \"vote\" then", "\t\t\tif false then",
     "countdown ticks down"),
    ("destroy keeps listening", K, "\tself._destroyed = true\n\tself._running = false", "\tself._running = false",
     "destroy removes the panel"),
    ("phone status box too short", V, "local statusHeight = if phone then 32 else 40",
     "local statusHeight = if phone then 8 else 40", "phone status line holds its longest text"),
    ("left pick shows the opening hint", M, "\tif pickLeft then", "\tif false then",
     "counts for nobody and says so"),
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
