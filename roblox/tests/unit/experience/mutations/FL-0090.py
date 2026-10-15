"""FL-0090 mutation rows, run by ../mutations.py (FL-0090 only: `mutations.py FL-0090`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0090 here only (D-038 (7)).
"""
M = [
 ("FL-0090", C2+"RulerCameraController.luau", 'self._target.focus = Def.clampFocus(position, self._bounds, self._config.overview.boundsMargin)', 'self._target.focus = position', "RulerCamera", "the focus never leaves the map bounds", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if moved.Magnitude < self:_tapPixels() then', 'if false then', "RulerCamera", "left-drag pans the ground", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'type(touches) ~= "table" or #touches ~= 1 then', 'type(touches) ~= "table" or #touches < 1 then', "RulerCamera", "two-finger moves never pan", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:_bindRotateKeys(false) -- Q / R belong', 'self:_bindRotateKeys(true) -- Q / R belong', "RulerCamera", "Q / E rotate in the overview", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if not far or now - (self._streamedAt :: number) < overview.streamEverySec then', 'if not far then', "RulerCamera", "stream around the focus", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:_setTouchControls(not overview)', 'self:_setTouchControls(true)', "RulerCamera", "starts in the overview over the throne", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", '			self._ruler:standUp()', '			local _ = self._ruler', "RulerCamera", "follow (walk mode) stands the ruler up", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:panBy(direction * (overview.panSpeed * target.zoom * dt))', 'self:panBy(direction * (overview.panSpeed * dt))', "RulerCamera", "WASD pans relative to the view", "game"),
 ("FL-0090", C2+"InputModeController.luau", '\n\t\tlocal ok, entityId = pcall(entities.pick, entities, screenPos)', '\n\t\tlocal ok, entityId = false, nil', "InputMode", "a tap on a citizen selects it", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'return (upAt - downAt).Magnitude < config.tapPixels and heldSec <= config.tapSec', 'return true', "InputMode", "a drag (pan) or a long press is not a tap", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'if nextMode ~= "explore" and self.selection.kind ~= "none" then', 'if false then', "InputMode", "build mode clears the selection", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'for _ = 1, 8 do', 'for _ = 1, 20 do', "InputMode", "resolveHit() stops after 8 levels", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'if okId and buildingId ~= nil then', 'if false then', "InputMode", "selects the building through", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'return "slot", if okSlot and slotId ~= nil then slotId else current.Name', 'return "slot", current.Name', "InputMode", "selects the slot through the BuildSlot tag", "game"),
 ("FL-0090", C2+"RulerController.luau", 'if (okSit and sitting) or (okSeat and seatPart ~= nil) then', 'if true then', "Ruler", "standUp() leaves the throne", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'if okTag and tagged then', 'if okTag then', "InputMode", "a tap on bare ground (an untagged part) fires none", "game"),
]
