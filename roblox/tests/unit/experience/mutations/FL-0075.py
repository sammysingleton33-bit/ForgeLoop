"""FL-0075 mutation rows, run by ../mutations.py (FL-0075 only: `mutations.py FL-0075`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0075 here only (D-038 (7)).
"""
A = C2 + "InputModeArenaController.luau"
I = C2 + "InputModeController.luau"
R = C2 + "RulerCameraController.luau"
M = [
 # InputModeController: the arena mode, its keys and its hold on build / edit
 ("FL-0075", I, 'Def.MODES = table.freeze({ "explore", "build", "edit", "arena" })', 'Def.MODES = table.freeze({ "explore", "build", "edit" })', "DuelInput", "the champion enters arena mode at the duel stage", "game"),
 ("FL-0075", I, 'if self.mode ~= "arena" or mode == "explore" or mode == "arena" then', 'if true then', "DuelInput", "build or edit are refused", "game"),
 ("FL-0075", I, 'self:_bindLeave(Def.LEAVE_MODES[nextMode] == true)', 'self:_bindLeave(nextMode ~= "explore")', "DuelInput", "arena mode never binds InputMode's X / B leave keys", "game"),
 # when: champion only, duel stage only, leaves after, re-enters on a respawn
 ("FL-0075", A, 'if type(side) == "table" and side.userId == userId and side.isAI ~= true then', 'if type(side) == "table" and side.userId == userId then', "DuelInput", "an AI namesake", "game"),
 ("FL-0075", A, 'self._ours = state.stage == "duel" and Def.isDuellist(state, self:_userId())', 'self._ours = Def.isDuellist(state, self:_userId())', "DuelInput", "the champion enters arena mode at the duel stage", "game"),
 ("FL-0075", A, 'elseif not wanted and input.mode == Def.MODE then', 'elseif false then', "DuelInput", "leaves at crowning or done", "game"),
 ("FL-0075", A, 'if type(phase) == "string" and Def.END_PHASES[phase] then', 'if false then', "DuelInput", "leaves at crowning or done", "game"),
 ("FL-0075", A, 'if (self._ours or self._preview) and mode == "explore" then', 'if false then', "DuelInput", "a respawn's explore re-enters arena mode", "game"),
 ("FL-0075", A, 'local ok, state = pcall(duel.getState, duel)', 'local ok, state = false, nil', "DuelInput", "starts from DuelController:getState()", "game"),
 # keys and gamepad
 ("FL-0075", A, 'end, false, high, table.unpack(binding.keys))', 'end, false, 1, table.unpack(binding.keys))', "DuelInput", "binds the five actions at High priority", "game"),
 ("FL-0075", A, 'actions:UnbindAction(name)', 'local _ = name', "DuelInput", "binds the five actions at High priority only while in arena mode, and unbinds them after", "game"),
 ("FL-0075", A, 'dodge = { name = "ForgeDuelDodge", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB } },', 'dodge = { name = "ForgeDuelDodge", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonA } },', "DuelInput", "binds the five actions", "game"),
 ("FL-0075", A, 'return down == true and (self:_send(action))', 'return (self:_send(action))', "DuelInput", "never on the release", "game"),
 ("FL-0075", A, 'return not wasHeld and (self:_send(action))', 'return (self:_send(action))', "DuelInput", "block is held", "game"),
 ("FL-0075", A, 'return next(held) == nil and self:_release(release)', 'return self:_release(release)', "DuelInput", "block is held", "game"),
 ("FL-0075", A, '\t\tself:_releaseAll()\n', '', "DuelInput", "leaving mid-block ends it", "game"),
 ("FL-0075", A, 'if not self.active or type(action) ~= "string" or not table.find(Def.ACTIONS, action) then', 'if type(action) ~= "string" then', "DuelInput", "press() sends nothing outside arena mode", "game"),
 ("FL-0075", A, 'if not self._warned[key] then', 'if true then', "DuelInput", "without a DuelController it sends nothing and logs once", "game"),
 # touch
 ("FL-0075", A, 'if not self:_isTouch() then', 'if false then', "DuelInput", "other devices never do", "game"),
 ("FL-0075", A, 'gui:Destroy()', 'local _ = gui', "DuelInput", "a touch device gets the buttons under PlayerGui only in arena mode", "game"),
 ("FL-0075", A, 'return math.min(viewport.X, viewport.Y) <= Def.SMALL_SCREEN_PX', 'return true', "DuelInput", "a touch device gets the buttons", "game"),
 ("FL-0075", A, 'light = { size = 68, x = -150, y = -50, label = "Light" },', 'light = { size = 40, x = -150, y = -50, label = "Light" },', "DuelInput", "both layouts", "game"),
 ("FL-0075", A, 'dodge = { size = 56, x = -228, y = -100, label = "Dodge" },', 'dodge = { size = 56, x = -190, y = -100, label = "Dodge" },', "DuelInput", "both layouts", "game"),
 # the camera walks for the duel
 ("FL-0075", R, 'Def.FOLLOW_MODES = table.freeze({ arena = true })', 'Def.FOLLOW_MODES = table.freeze({})', "DuelInput", "switches to the walk camera for the duel", "game"),
 ("FL-0075", R, 'if self._input ~= nil and Def.FOLLOW_MODES[self._input.mode] and mode ~= "follow" then', 'if false then', "DuelInput", "refuses the overview meanwhile", "game"),
 ("FL-0075", R, 'elseif Def.FOLLOW_MODES[previous] then', 'elseif false then', "DuelInput", "restores it after", "game"),
 ("FL-0075", R, 'self:_bindView(false) -- no View key', 'local _ = 0 -- no View key', "DuelInput", "switches to the walk camera for the duel", "game"),
 ("FL-0075", R, '\t\tself:_bindView(true)\n', '', "DuelInput", "restores it after", "game"),
 # Studio preview (E16)
 ("FL-0075", A, 'if self._preview and not self._ours then', 'if false then', "DuelInput", "Studio preview (E16)", "game"),
 ("FL-0075", A, 'local wanted = self._ours or self._preview', 'local wanted = self._ours', "DuelInput", "Studio preview (E16)", "game"),
 ("FL-0075", A, 'if not self:_isStudio() then\n\t\treturn false\n\tend\n', '', "DuelInput", "never outside Studio", "game"),
 # touchArea: other UI keeps clear of the duel's touch buttons (FORGE-03 on #199)
 ("FL-0075", A, '\tif self._gui == nil then\n\t\treturn nil\n\tend\n\treturn Def.extent', '\treturn Def.extent', "DuelInput", "a touch device gets the buttons under PlayerGui only in arena mode", "game"),
 ("FL-0075", A, '\t\tself._small = small\n', '', "DuelInput", "a touch device gets the buttons under PlayerGui only in arena mode", "game"),
 ("FL-0075", A, 'left = math.max(left, math.abs(button.x) + button.size / 2)', 'left = math.max(left, math.abs(button.x))', "DuelInput", "a touch device gets the buttons under PlayerGui only in arena mode", "game"),
 # FORGE-00 (#249 verification): press() reports act()'s answer; a refused blockEnd is retried until sent
 ("FL-0075", A, 'return result == true, result ~= true', 'return ok, false', "DuelInput", "a blockEnd the real DuelController's empty bucket refuses", "game"),
 ("FL-0075", A, 'if sent or not refused or self._retrying[release] then', 'if true then', "DuelInput", "a blockEnd the real DuelController's empty bucket refuses", "game"),
 ("FL-0075", A, '\t\t\tif self:_send(release) then\n\t\t\t\tbreak', '\t\t\tif false then\n\t\t\t\tbreak', "DuelInput", "a blockEnd the real DuelController's empty bucket refuses", "game"),
 ("FL-0075", A, 'self._retrying[release] = nil -- held again', '-- held again', "DuelInput", "a blockEnd the real DuelController's empty bucket refuses", "game"),
 ("FL-0075", A, 'return next(held) == nil and self:_release(release)', 'return next(held) == nil and (self:_send(release))', "DuelInput", "a blockEnd the real DuelController's empty bucket refuses", "game"),
]
