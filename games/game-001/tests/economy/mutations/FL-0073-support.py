"""FL-0073 support meter and breakdown (SupportMeterModel, SupportMeter, SupportPanel, SupportMeterController, Layout).
Each row breaks one rule and expects a named SupportUI spec to fail.

Run from the repository root (needs lune on PATH):
    python3 games/game-001/tests/economy/mutations/FL-0073-support.py
One line per row: CAUGHT / NOT CAUGHT / NOT APPLIED. Exits 1 unless every row is CAUGHT. A run in which no spec file
ran counts as NOT CAUGHT. Left out as equivalent: dropping the NaN guard on the trend (NaN fails both comparisons
and reads "Steady" anyway; the NaN breakdown guard is pinned). Rows: (name, file, old, new, expected failing test (substring of its name)).
"""
import pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
U = "games/game-001/src/client/UI/"
C = "games/game-001/src/client/Controllers/"
RUN = ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json",
       "--specs", "games/game-001/tests", "economy/SupportUI"]
M, V, P, K = U + "SupportMeterModel.luau", U + "SupportMeter.luau", U + "SupportPanel.luau", C + "SupportMeterController.luau"
ROWS = [
    ("model shows before a view", M, "if type(sv) ~= \"table\" or type(sv.score) ~= \"number\" then\n\t\treturn nil",
     "if type(sv) ~= \"table\" then\n\t\treturn nil", "is nil until the server"),
    ("score not rounded", M, "math.clamp(math.floor(sv.score + 0.5), 0, 100)", "math.clamp(math.floor(sv.score), 0, 100)",
     "says the tier in words"),
    ("trend always steady", M, "if v > SupportMeterModel.TREND_STEP then", "if v > 999 then", "says the tier in words"),
    ("next tier off by one", M, "math.ceil(Support.tiers[up].min - score)", "math.ceil(Support.tiers[up].min - score) + 1",
     "says the tier in words"),
    ("components unordered weight", M, "weight = Support.components[id] and Support.components[id].weight or 0",
     "weight = 0", "seven components in config order"),
    ("missing component shows 0", M, "value = if value then math.floor(value + 0.5) else nil", "value = if value then math.floor(value + 0.5) else 0",
     "seven components in config order"),
    ("moments oldest first", M, "return (type(a) == \"table\" and a.t or 0) > (type(b) == \"table\" and b.t or 0)",
     "return (type(a) == \"table\" and a.t or 0) < (type(b) == \"table\" and b.t or 0)", "newest moments first"),
    ("moments unbounded", M, "if #moments >= SupportMeterModel.MOMENTS then", "if #moments >= 99 then", "newest moments first"),
    ("slot plural", M, "if slots == 1 then \"1 perk slot in the arena\"", "if slots == 0 then \"1 perk slot in the arena\"",
     "arena line comes from config"),
    ("chip score attribute lost", V, "button:SetAttribute(\"score\", model.score)", "button:SetAttribute(\"score\", 0)",
     "shows the tier in words"),
    ("chip tap does nothing", V, "\t\t\tif ui.onOpen then\n\t\t\t\tui.onOpen()", "\t\t\tif false then\n\t\t\t\tui.onOpen()",
     "a tap opens the breakdown"),
    ("kicker on phones", V, "Kicker = (not phone) and Style.text({", "Kicker = true and Style.text({", "drops the kicker"),
    ("chip trend attribute", V, "if model.trend.arrow == \"▲\" then \"up\" elseif model.trend.arrow == \"▼\" then \"down\"",
     "if model.trend.arrow == \"▲\" then \"up\" elseif false then \"down\"", "falling score changes"),
    ("component weight text", P, "text = `{c.weight} %`,", "text = `{c.weight}`,", "the breakdown: tier chip"),
    ("moment delta colour", P, "Theme.color(if mo.positive then \"vert\" else \"gules\")", "Theme.color(\"vert\")",
     "a pushed act updates"),
    ("moments named by order", P, "momentRow(mo, phone, i, 31 + i)", "momentRow(mo, phone, 31 + i, 31 + i)",
     "the breakdown: tier chip"),
    ("no empty-match line", P, "if model.noMoments then", "if false then", "empty match"),
    ("controller ignores push", K, "\t\t\t\t\tself:apply(view, true)", "\t\t\t\t\tlocal _ = view", "a pushed act updates"),
    ("malformed push wipes", K, "if pushed and model == nil then\n\t\treturn", "if false then\n\t\treturn",
     "ignores a malformed push"),
    ("not dark without remotes", K, "\tif not self.hud:hasRemote(SupportMeterController.GET) then\n\t\treturn\n\tend\n", "",
     "dark until Kingdom.Support"),
    ("no late-join fetch", K, "\tif mine ~= nil then\n\t\tself._env.spawn(function()", "\tif false then\n\t\tself._env.spawn(function()",
     "late join"),
    ("chip rebuilt on every HUD render", K, "if meterKey ~= self._meterKey or (shown and self.meter.instance == nil) then",
     "if true then", "treasury pushes leave"),
    ("panel rebuilt on every HUD render", K, "if key == self._panelKey and self.panel and self.panel.panel then",
     "if false then", "treasury pushes leave"),
    ("no layout room", C + "KingdomHudController.luau", "support = self.state.support == true", "support = false",
     "sits where Layout puts it"),
    ("bottom ignores the chip", U + "Layout.luau", "\t\tbottom = support.y + h\n", "", "sits where Layout puts it"),
    ("pushes after destroy", K, "function SupportMeterController:apply(view: any, pushed: boolean?)\n\tif self._destroyed then",
     "function SupportMeterController:apply(view: any, pushed: boolean?)\n\tif false then", "after destroy"),
    # FORGE-07 L1 on #225: the mutants the first spec round let through
    ("refresh on every kingdoms change", K, "\tif mine == self._mine then\n\t\treturn", "\tif false then\n\t\treturn",
     "only when my kingdom changes"),
    ("chip without a banner", K, "local active = HudModel.banner(hud.store) ~= nil and model ~= nil", "local active = model ~= nil",
     "no chip without a kingdom banner"),
    ("chip over a conversation", K, "local talking = narrow and hud.state.menu == \"conversation\"", "local talking = false",
     "narrow phone hides the chip"),
    ("gap for a nil view", K, "\tlocal visible = model ~= nil\n", "\tlocal visible = true\n", "nil view from GetSupport"),
    ("push kept after destroy", K, "\t\tself._push = nil\n", "", "destroy removes the push listener"),
    ("chip glued to the stack", U + "Layout.luau", "support = { x = x, y = bottom + 6,", "support = { x = x, y = bottom,",
     "chip sits a gap below"),
    ("phone chip too narrow", U + "Layout.luau", "Layout.SUPPORT_WIDTH_PHONE = 150", "Layout.SUPPORT_WIDTH_PHONE = 90",
     "chip sits a gap below"),
    ("score not clamped", M, "math.clamp(math.floor(sv.score + 0.5), 0, 100)", "math.floor(sv.score + 0.5)", "clamps the score"),
    ("NaN breakdown", M, "if type(raw) == \"number\" and raw == raw then", "if type(raw) == \"number\" then", "clamps the score"),
    ("trend boundary inclusive", M, "if v > SupportMeterModel.TREND_STEP then", "if v >= SupportMeterModel.TREND_STEP then",
     "clamps the score"),
    ("negative rounding", M, "\tif n < 0 then\n", "\tif false then\n", "clamps the score"),
    ("trend window literal", M, "math.floor(Support.trendSeconds / 60 + 0.5)", "math.floor(600 / 60 + 0.5)", "clamps the score"),
    ("open stroke thin", V, "if ui.open then 2 else 1,", "if ui.open then 1 else 1,", "gold 2 px outline"),
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
