"""Mutation check for FORGE-04 specs: proves each named spec can fail.

Each row breaks one rule in the source, runs the matching Lune specs, expects the named test to
fail, and restores the file (also on error). Run from anywhere:
    python3 roblox/tests/unit/experience/mutations.py            # all rows
    python3 roblox/tests/unit/experience/mutations.py FL-0025    # one task
Prints one line per row: CAUGHT / NOT CAUGHT / MUTATION NOT APPLIED. Needs lune on PATH.
"""
import subprocess, sys, re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
S = "roblox/src/server/Services/"; C = "roblox/src/client/Controllers/"; X = "roblox/src/shared/Experience/"
G = "games/game-001/"
RUN = {
    "fw": ["lune", "run", "roblox/tests/harness/run.luau"],
    "game": ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json", "--specs", "games/game-001/tests"],
}
M = [
 # (task, file, old, new, spec filter, expected failing test, project) -- project "game" runs games/game-001/tests
 ("FL-0023", S+"AnalyticsService.luau", 'local floor = if kind == "event" then self._capacity * self._limits.customReserve else 0', 'local floor = 0', "AnalyticsService", "keeps a reserve for funnels", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if decl.kind == "recurring" and (type(sessionId) ~= "string" or sessionId == "") then', 'if false then', "AnalyticsService", "drops recurring funnel steps without a sessionId", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'local ok, err = pcall(service[method], service, ...)', 'local ok, err = true, service[method](service, ...)', "AnalyticsService", "never throws when Roblox errors", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'out[AnalyticsSchema.FIELD_KEYS[index]] = text', 'out[AnalyticsSchema.FIELD_KEYS[4 - index]] = text', "AnalyticsService", "maps the value field and CustomField01-03", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if state.tokens < 1 then', 'if false then', "AnalyticsService", "caps one player at perPlayerPerMinute", "fw"),
 ("FL-0023", X+"AnalyticsSchema.luau", 'if #fields > AnalyticsSchema.CAPS.customFields then', 'if false then', "AnalyticsSchema", "rejects more than 3 custom fields", "fw"),
 ("FL-0023", X+"Subjects.luau", 'local ok, result = pcall(resolver, args, ctx)', 'local ok, result = true, resolver(args, ctx)', "AnalyticsService", "isolates a resolver that errors", "fw"),
 ("FL-0023", X+"Subjects.luau", 'table.insert(out, { player = subject.player, info = Subjects.primitives(subject.info) })', 'table.insert(out, { player = subject.player, info = subject.info })', "AnalyticsSchema", "a game resolver wins over the default and its info is filtered too", "fw"),
 ("FL-0024", X+"Schema.luau", 'local step = migrations[fromVersion]', 'local step = migrations[fromVersion + 1] or migrations[fromVersion]', "Settings", "migrates step by step", "fw"),
 ("FL-0024", S+"SettingsService.luau", 'if section == "settings" or not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', 'if not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', "Settings", "update(section) changes only that section", "fw"),
 ("FL-0024", S+"SettingsService.luau", 'if last and now - last < ANALYTICS_GAP then', 'if false then', "Settings", "reports SettingChanged at most once per key", "fw"),
 ("FL-0024", S+"SettingsService.luau", '	local ok = pcall(fn, copy)\n	if not ok then\n		return false\n	end\n	self._session[player] = copy', '	local ok = pcall(fn, copy)\n	self._session[player] = copy\n	if not ok then\n		return false\n	end', "Settings", "same no-partial-write and validation rules", "fw"),
 ("FL-0024", X+"SoundRegistry.luau", 'if not nonEmpty(entry.licence) then', 'if false then', "Audio", "rejects entries without licence", "fw"),
 ("FL-0024", C+"AudioController.luau", 'Def.BUDGET = table.freeze({ voices = 8, music = 1, ambience = 2 })', 'Def.BUDGET = table.freeze({ voices = 9, music = 1, ambience = 2 })', "Audio", "keeps at most 8 voices", "fw"),
 ("FL-0024", C+"AudioController.luau", 'if self:_countOf(soundId) >= (entry.maxInstances or 2) then', 'if false then', "Audio", "enforces cooldown and maxInstances", "fw"),
 ("FL-0024", C+"AudioController.luau", 'if self._backend.available and not self._backend.available() then', 'if false then', "Audio", "skips sounds cleanly when there is no SoundService", "fw"),
 ("FL-0024", X+"VfxPresets.luau", 'if live > B.particlesPerPreset then', 'if false then', "Vfx", "rejects presets over budget", "fw"),
 ("FL-0024", X+"VfxPresets.luau", 'if type(preset) == "table" and type(preset.id) == "string" and byId[preset.id] ~= nil then', 'if false then', "Vfx", "register() rejects invalid lists and duplicate ids", "fw"),
 ("FL-0024", C+"VFXController.luau", 'local scale = if reduced and preset.reducedMotion == "reduce" then 0.5 else 1', 'local scale = 1', "Vfx", "reduced motion halves", "fw"),
 ("FL-0024", C+"VFXController.luau", 'if victim == nil then\n\t\t\treturn false', 'if victim == nil then\n\t\t\treturn true', "Vfx", "keeps live particles on screen within budget", "fw"),
 ("FL-0024", X+"CueDirector.luau", 'if variant.sound and not (variant.vfx or variant.notify or variant.float or variant.react) then', 'if false then', "Feedback", "the validator catches a sound-only cue", "fw"),
 ("FL-0024", X+"CueDirector.luau", 'local first = repeatCount == 1', 'local first = true', "Feedback", "coalesces repeats", "fw"),
 ("FL-0024", X+"MusicDirector.luau", 'if not leavingUrgent and now - self._since < self._minDwell then', 'if false then', "Feedback", "only after the minimum dwell time", "fw"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if slice.Lobby ~= 0 then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if minutes < limits.matchMinMinutes or minutes > limits.matchMaxMinutes then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", '		config = Def.DEFAULTS\n', '', "PacingService", "an invalid config never breaks the match", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if durations == nil or not table.find(Def.MODES, mode) then', 'if false then', "PacingService", "rejects an unknown mode", "game"),
 ("FL-0024", G+"config/Sounds.luau", 'id = "music.tension"', 'id = "music.tense"', "Sounds", "registers a track for every music state", "game"),
]
only = sys.argv[1] if len(sys.argv) > 1 else None
rows = []
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
