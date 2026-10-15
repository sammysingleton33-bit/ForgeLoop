"""FL-0103 mutation rows, run by ../mutations.py (FL-0103 only: `mutations.py FL-0103`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0103 here only (D-038 (7)).
"""
M = [
 ("FL-0103", X+"SettingsModel.luau", 'nextValue = options[index % #options + 1]', 'nextValue = options[1]', "SettingsPanel", "choices cycle", "fw"),
 ("FL-0103", X+"SettingsModel.luau", 'out.canUp = value < 1', 'out.canUp = true', "SettingsPanel", "rows show what is in force", "fw"),
 ("FL-0103", X+"SettingsModel.luau", 'if key == "reducedMotion" and opts.platformReducedMotion and not value then', 'if key == "reducedMotion" and not value then', "SettingsPanel", "the device's Reduce Motion is named", "fw"),
 ("FL-0103", X+"SettingsModel.luau", 'return math.clamp(math.floor(x * perUnit + 0.5) / perUnit, 0, 1)', 'return x', "SettingsPanel", "volumes step by 0.1 and stop at 0 and 1", "fw"),
 ("FL-0103", X+"SettingsPanel.luau", 'plus:update({ disabled = not r.canUp })', 'plus:update({})', "SettingsPanel", "a volume at its end disables", "fw"),
 ("FL-0103", X+"SettingsPanel.luau", 'if self.panel and key == self._frameKey then', 'if false then', "SettingsPanel", "a tap changes the setting and patches the row", "fw"),
 ("FL-0103", C+"SettingsPanelController.luau", 'local open = menu == Controller.MENU', 'local open = menu ~= nil', "SettingsPanel", "another menu closes it", "fw"),
 ("FL-0103", C+"SettingsPanelController.luau", 'pcall(host.addRailItem, host, Def.RAIL)', 'local _ = host', "SettingsPanel", "a rail button opens it", "fw"),
 ("FL-0103", C+"SettingsPanelController.luau", 'return self._settings:set(key, nextValue) == true', 'return true', "SettingsPanel", "a tap changes the setting and patches the row", "fw"),
 ("FL-0103", C+"SettingsPanelController.luau", 'connect(self._settings.changed, function()\n\t\t\t\tif self.isOpen then', 'connect(self._settings.changed, function()\n\t\t\t\tif false then', "SettingsPanel", "a change from elsewhere redraws the open panel", "fw"),
 ("FL-0103", C+"VFXController.luau", 'scale *= Def.REDUCED_QUALITY', 'scale *= 1', "Vfx", "effectsQuality 'reduced' halves every effect", "fw"),
 ("FL-0103", X+"SettingsPanel.luau", 'SettingsPanel.STEPPER = 44', 'SettingsPanel.STEPPER = 36', 'SettingsPanel', 'every control is a touch target', "fw"),
 ("FL-0103", X+"SettingsPanel.luau", 'size = "regular", -- 44 px tall: a touch target', 'size = "small",', 'SettingsPanel', 'every control is a touch target', "fw"),
 ("FL-0103", X+"SettingsPanel.luau", '\t\tif compact then\n\t\t\tlabel.Size = UDim2.new(1, 0, 0, SettingsPanel.LABEL_HEIGHT)', '\t\tif false then\n\t\t\tlabel.Size = UDim2.new(1, 0, 0, SettingsPanel.LABEL_HEIGHT)', 'SettingsPanel', 'phones stack the label', "fw"),
 ("FL-0103", C+"SettingsController.luau", 'ok = false -- an older echo: the local change stands', 'ok = ok', 'SettingsController', 'an older echo never reverts', "fw"),
 ("FL-0103", C+"SettingsController.luau", 'local left = pending.sendAt - env.clock()', 'local left = 0', 'SettingsController', 'taps in a row send once', "fw"),
 ("FL-0103", C+"SettingsController.luau", 'local waiting = not pending.sent or now < pending.untilAt', 'local waiting = true', 'SettingsController', 'snaps back to the server', "fw"),
]
