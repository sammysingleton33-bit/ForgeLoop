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
 # D-059 framing (FL-0145): the overview's own start zoom and field of view; walk mode keeps Roblox's
 ("FL-0090", C2+"RulerCameraController.luau", 'startZoom = 70, -- 42.5', 'startZoom = 120, -- 42.5', "RulerCamera", "the start view frames a citizen", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'fieldOfView = 55, -- degrees, vertical', 'fieldOfView = 70, -- degrees, vertical', "RulerCamera", "the start view frames a citizen", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'camera.FieldOfView = self:_fieldOfView()', 'local _ = self:_fieldOfView()', "RulerCamera", "starts in the overview over the throne", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if self.mode == "overview" and overview ~= nil and type(overview.fieldOfView) == "number" then', 'if overview ~= nil and type(overview.fieldOfView) == "number" then', "RulerCamera", "follow (walk mode) stands the ruler up", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'Def.worldPerPixel(self._target.zoom, self:_fieldOfView(), self:_viewportHeight())', 'Def.worldPerPixel(self._target.zoom, self._config.fieldOfView, self:_viewportHeight())', "RulerCamera", "left-drag pans the ground", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'zoom = 35,', 'zoom = 30,', "RulerCamera", "on a phone the citizen's head", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'phoneOffset = Vector2.new(0, -7.5),', 'phoneOffset = Vector2.new(0, -12),', "RulerCamera", "on a phone the citizen's head", "game"),
 ("FL-0090", G+"config/Crowd.luau", 'standZoom = 74, ringZoom = 108,', 'standZoom = 55, ringZoom = 80,', "CrowdStage", "the intro: one horn", "game"),
 # D-059: the first view centres the yard in front of the keep (FORGE-00)
 ("FL-0090", C2+"RulerCameraController.luau", 'startAhead = 40, -- studs', 'startAhead = 0, -- studs', "RulerCamera", "starts in the overview over the yard", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if look.Magnitude < 1e-3 then\n\t\treturn root.Position\n\tend\n', '', "RulerCamera", "startFocus() is `ahead` studs", "game"),
 # (left out, equivalent: the startFocus call in _apply runs only when no character set the focus first,
 # which no spec can reach; _onCharacter's call is the row below)
 ("FL-0090", C2+"RulerCameraController.luau", 'self:focusOn(Def.startFocus(root.CFrame, self._config.overview.startAhead or 0)) -- the yard', 'self:focusOn(root.CFrame.Position) -- the yard', "RulerCamera", "starts in the overview over the yard", "game"),
]
