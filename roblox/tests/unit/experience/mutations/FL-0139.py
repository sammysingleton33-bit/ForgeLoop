"""FL-0139 mutation rows, run by ../mutations.py (FL-0139 only: `mutations.py FL-0139`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0139 here only (D-038 (7)).
Left out (equivalent today): `_arena = options.arena or ArenaConfig` without the fallback, because
config Arena's ring.walkSpeed (16, #255) equals the controller's own walkSpeed.
"""
R = C2 + "RulerController.luau"
M = [
 ("FL-0139", R, 'local ring = self:_ringSpeed()', 'local ring = nil', "experience/Ruler.", "a champion walks at ring.walkSpeed", "game"),
 ("FL-0139", R, 'self.sprinting = false -- a champion never sprints (FL-0139)', 'self.sprinting = sprinting -- a champion never sprints (FL-0139)', "experience/Ruler.", "a champion walks at ring.walkSpeed", "game"),
 ("FL-0139", R, 'humanoid.WalkSpeed = ring -- held, not eased', 'humanoid.WalkSpeed = Def.approach(humanoid.WalkSpeed, ring, config.accel * dt) -- held, not eased', "experience/Ruler.", "a champion walks at ring.walkSpeed", "game"),
 ("FL-0139", R, 'if not ok or champion ~= true then', 'if not ok then', "experience/Ruler.", "a champion walks at ring.walkSpeed", "game"),
 ("FL-0139", R, 'local ok, champion = pcall(duel.isChampion, duel)', 'local ok, champion = true, duel:isChampion()', "experience/Ruler.", "a champion check that errors", "game"),
 ("FL-0139", R, 'return self._config.walkSpeed -- no ring config', 'return nil -- no ring config', "experience/Ruler.", "without config Arena's ring", "game"),
 ("FL-0139", R, 'local ring = if type(self._arena) == "table" then self._arena.ring else nil', 'local ring = nil', "experience/Ruler.", "a champion walks at ring.walkSpeed", "game"),
 # FORGE-07 #259 L2: a bad ring speed and a missing isChampion
 ("FL-0139", R, 'if type(speed) == "number" and speed > 0 and speed ~= math.huge then', 'if type(speed) == "number" and speed ~= math.huge then', "experience/Ruler.", "a ring speed of 0, NaN or infinity", "game"),
 ("FL-0139", R, 'if type(speed) == "number" and speed > 0 and speed ~= math.huge then', 'if type(speed) == "number" and speed > 0 then', "experience/Ruler.", "a ring speed of 0, NaN or infinity", "game"),
 ("FL-0139", R, 'local ok, champion = pcall(duel.isChampion, duel)', 'local ok, champion = true, duel.isChampion(duel)', "experience/Ruler.", "a DuelController without isChampion", "game"),
]
