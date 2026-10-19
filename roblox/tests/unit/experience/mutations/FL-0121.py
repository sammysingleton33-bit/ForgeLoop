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
 # --- #234 (FORGE-07 via FORGE-03): only the finger holding the building edge-pans
 ("FL-0121", C2+"RulerCameraController.luau", 'if kind ~= Enum.UserInputType.Touch or self._dragTouch == nil or input == self._dragTouch then', 'if true then', "RulerCamera", "edit drag on touch", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'local finger = Def.heldTouch(self._touches, at) -- the one that was held', 'local finger = Def.heldTouch(self._touches, nil) -- the one that was held', "RulerCamera", "an older thumb resting on the world", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\t\t\t\tself._dragTouch = nil -- the dragging finger lifted: its point no longer edge-pans\n\t\t\t\tself._pointer = nil\n', '\t\t\t\tlocal _ = 0\n', "RulerCamera", "edit drag on touch", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\t\t\tif finger ~= nil then\n\t\t\t\ttable.remove(self._touches, finger)', '\t\t\tif false then\n\t\t\t\ttable.remove(self._touches, finger)', "RulerCamera", "edit drag on touch", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\t\tself._drag = nil -- a pan already under way stops\n', '\t\tlocal _ = 0\n', "RulerCamera", "setEditDrag(true) stops a pan already under way", "game"),
 # --- #239 (FORGE-07): the finger nearest the press point is the held one (M1); a finger parked at the edge (L2)
 ("FL-0121", C2+"RulerCameraController.luau", '\t\treturn touches[1]\n\tend\n\tlocal best', '\t\treturn touches[#touches]\n\tend\n\tlocal best', "RulerCamera", "an older thumb resting on the world", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", 'if distance < bestDistance then -- a tie keeps the older finger', 'if distance <= bestDistance then -- a tie keeps the older finger', "RulerCamera", "heldTouch: the touch nearest the press point", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\t\tif tx ~= nil and ty ~= nil then\n\t\t\tlocal distance', '\t\tif true then\n\t\t\tlocal distance', "RulerCamera", "heldTouch: the touch nearest the press point", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\t\t\tself._pointer = Vector2.new(finger.Position.X, finger.Position.Y)\n', '\t\t\tlocal _ = 0\n', "RulerCamera", "a finger already at the edge when the hold completes", "game"),
 ("FL-0121", C2+"RulerCameraController.luau", '\tself._editDrag = on\n\tself._dragTouch = nil\n', '\tself._editDrag = on\n', "RulerCamera", "an older thumb resting on the world", "game"),
]
