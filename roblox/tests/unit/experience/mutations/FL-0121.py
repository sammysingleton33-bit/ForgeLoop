"""FL-0121 mutation rows, run by ../mutations.py (FL-0121 only: `mutations.py FL-0121`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0121 here only (D-038 (7)).
"""
M = [
 ("FL-0121", C2+"InputModeController.luau", 'Def.MODES = table.freeze({ "explore", "build", "edit", "arena" })', 'Def.MODES = table.freeze({ "explore", "build", "arena" })', 'InputMode', 'edit mode (G13.9) is a mode', "game"),
 ("FL-0121", C2+"InputModeController.luau", 'Def.LEAVE_MODES = table.freeze({ build = true, edit = true })', 'Def.LEAVE_MODES = table.freeze({ build = true })', 'InputMode', 'edit mode (G13.9) is a mode', "game"),
 ("FL-0121", C2+"InputModeController.luau", 'if nextMode ~= "explore" and self.selection.kind ~= "none" then', 'if nextMode == "build" and self.selection.kind ~= "none" then', 'InputMode', 'edit mode (G13.9) is a mode', "game"),
 ("FL-0121", C2+"InputModeController.luau", 'if ok and owner ~= nil and owner == mine then', 'if ok then', 'InputMode', 'edit mode (G13.9): a tap selects only your own', "game"),
 ("FL-0121", C2+"InputModeController.luau", 'kind, id = Def.resolveEdit(hit, self:_hasTag(), self:_kingdom())', 'kind, id = Def.resolveHit(hit, self:_hasTag())', 'InputMode', 'edit mode (G13.9): a tap selects only your own', "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'Def.OVERVIEW_MODES = table.freeze({ build = true, edit = true })', 'Def.OVERVIEW_MODES = table.freeze({ build = true })', 'RulerCamera', 'edit mode (G13.9) keeps the overview', "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'local on = active == true and self._input ~= nil and self._input.mode == "edit"', 'local on = active == true', 'RulerCamera', 'edit mode (G13.9) keeps the overview', "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'if drag == nil or self.mode ~= "overview" or self._editDrag then', 'if drag == nil or self.mode ~= "overview" then', 'RulerCamera', 'edit mode (G13.9) keeps the overview', "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'direction += Def.edgeDirection(self._pointer, self:_viewport(), Def.EDGE_PIXELS)', 'direction += Vector2.zero', 'RulerCamera', 'edit mode (G13.9) keeps the overview', "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\tif mode ~= "edit" then\n\t\tself:setEditDrag(false)\n\tend\n', '', 'RulerCamera', 'edit mode (G13.9) keeps the overview', "game"),
]
