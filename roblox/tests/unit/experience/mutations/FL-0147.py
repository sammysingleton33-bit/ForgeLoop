"""FL-0147 mutation rows, run by ../mutations.py (FL-0147 only: `mutations.py FL-0147`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0147 here only (D-038 (7)).
"""
R = C2 + "RulerCameraController.luau"
M = [
 # the first view looks back at the keep across the yard (startTurn 180), from 20 studs before the throne
 ("FL-0147", R, 'startTurn = 180, -- degrees', 'startTurn = 0, -- degrees', "RulerCamera", "the first view stands over the yard", "game"),
 ("FL-0147", R, 'return yawOf(look) + math.rad(turn)', 'return yawOf(look)', "RulerCamera", "the first view stands over the yard", "game"),
 ("FL-0147", R, 'if look.Magnitude < 1e-3 then\n\t\treturn nil\n\tend\n', '', "RulerCamera", "the first view stands over the yard", "game"),
 # the overview's entry takes the first view's yaw once; later entries keep the camera's
 ("FL-0147", R, 'self._target.yaw = self._startYaw or yawOf(camera.CFrame.LookVector)', 'self._target.yaw = yawOf(camera.CFrame.LookVector)', "RulerCamera", "starts in the overview over the yard, looking back", "game"),
 ("FL-0147", R, '\t\t\tself._startYaw = nil\n\t\t\tself._shown = nil', '\t\t\tself._shown = nil', "RulerCamera", "returning to the overview blends from the walk view", "game"),
 # a character that comes after the start: the overview is already on screen, so the yaw is the target at once
 ("FL-0147", R, 'if self.mode == "overview" and self._inOverview then\n\t\tself._target.yaw = yaw', 'if false then\n\t\tself._target.yaw = yaw', "RulerCamera", "a ruler whose character comes after the start", "game"),
 ("FL-0147", R, '\t\tself._inOverview = true\n', '', "RulerCamera", "a ruler whose character comes after the start", "game"),
 ("FL-0147", R, 'if self.mode == "overview" and self._inOverview then', 'if self.mode == "overview" then', "RulerCamera", "starts in the overview over the yard, looking back", "game"),
]
