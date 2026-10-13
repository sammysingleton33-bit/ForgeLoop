"""FL-0024 mutation rows, run by ../mutations.py (FL-0024 only: `mutations.py FL-0024`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0024 here only (D-038 (7)).
"""
M = [
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
 ("FL-0024", G+"config/Sounds.luau", 'id = "music.tension"', 'id = "music.tense"', "Sounds", "registers a track for every music state", "game"),
]
