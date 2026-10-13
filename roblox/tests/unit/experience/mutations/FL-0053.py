"""FL-0053 mutation rows, run by ../mutations.py (FL-0053 only: `mutations.py FL-0053`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0053 here only (D-038 (7)).
"""
M = [
 ("FL-0053", C2+"InputModeController.luau", 'if self._firing then', 'if false then', "InputMode", "applies a set() made inside a changed handler", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'return self.mode == mode and self._env.clock() - self._changedAt >= self._config.settleSec', 'return self.mode == mode', "InputMode", "accepts() gives a tap", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'self:_bindLeave(nextMode == "build")', 'self:_bindLeave(true)', "InputMode", "binds X / gamepad B only while in build mode", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'if not table.find(Def.MODES, mode) then', 'if mode == nil then', "InputMode", "refuses unknown modes", "game"),
 ("FL-0053", C2+"RulerController.luau", 'return { held = state.held, toggled = toggled }, moving and (state.held or toggled)', 'return { held = state.held, toggled = toggled }, state.held or toggled', "Ruler", "standing still never sprints", "game"),
 ("FL-0053", C2+"RulerController.luau", 'local toggled = state.toggled and moving', 'local toggled = state.toggled', "Ruler", "the toggle ends when the ruler stops", "game"),
 ("FL-0053", C2+"RulerController.luau", 'return math.min(current + step, target)', 'return current + step', "Ruler", "never overshoots", "game"),
 ("FL-0053", C2+"RulerController.luau", 'humanoid.AutoRotate = false', 'humanoid.AutoRotate = true', "Ruler", "smooth turning: AutoRotate off", "game"),
 ("FL-0053", C2+"RulerController.luau", '	if self._input ~= nil then\n		self._input:set("explore")\n	end\n	if character == nil then', '	if character == nil then', "Ruler", "respawn, removal and death return input to explore", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'elseif previous == "build" and self._autoFrom ~= nil then', 'elseif false then', "RulerCamera", "build mode uses the overview", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'self._autoFrom = nil -- the player chose', '-- removed', "RulerCamera", "build mode uses the overview", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'if reduced or settings:get("cameraShake") == false then', 'if false then', "RulerCamera", "never shakes when camera shake is off", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'local alpha = 1 - math.exp(-rate * dt)', 'local alpha = math.min(1, rate * dt)', "RulerCamera", "frame-rate independent", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'camera.CFrame = self._blendFrom:Lerp(goal, Def.ease(self._blendT))', 'camera.CFrame = goal', "RulerCamera", "returning to the overview blends", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'self._target.zoom = Def.clamp(self._target.zoom + steps * overview.zoomStep, overview.minZoom, overview.maxZoom)', 'self._target.zoom = self._target.zoom + steps * overview.zoomStep', "RulerCamera", "zoom stays within", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'local ratio = scale / self._pinch', 'local ratio = scale', "RulerCamera", "zoom stays within", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'while #self._shakes > limits.maxActive do', 'while false do', "RulerCamera", "caps the duration and the number of shakes", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'return Def.clamp(magnitude, 0, 1) * maxDegrees * left * left', 'return magnitude * maxDegrees * left * left', "RulerCamera", "shakeAmplitude() eases out and clamps", "game"),
]
