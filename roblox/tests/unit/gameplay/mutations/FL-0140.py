"""FL-0140 mutation rows (the Crown Arena's bodies, gear and venue: ArenaService + Arena/Figures).
Run by ../mutations.py (`mutations.py FL-0140`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AS = G + "src/server/Services/ArenaService.luau"
FG = G + "src/shared/Arena/Figures.luau"
M = [
 ("FL-0140", AS, 'return figures:poseOf(userId) -- an AI champion stands where its figure does', 'return nil', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", AS, '\t\tself._match.host:snapRuler(userId)\n', '\t\tlocal _ = userId\n', "sim/ArenaService", "tells the sim a champion was moved"),
 ("FL-0140", AS, '\tself:_releaseAll()\n\tself:_clearFigures()\n\tself._flow, self._runner = nil, nil\n\tself._remotes:fireAll("Arena.State", IDLE_STATE)\n\tself._match:arenaEnded(winner)', '\tself:_releaseAll()\n\tself._flow, self._runner = nil, nil\n\tself._remotes:fireAll("Arena.State", IDLE_STATE)\n\tself._match:arenaEnded(winner)', "sim/ArenaService", "back to neutral"),
 ("FL-0140", AS, '\tflow:cancel(reason)\n\tself:_publish()\n\tself:_releaseAll()\n\tself:_clearFigures()\n', '\tflow:cancel(reason)\n\tself:_publish()\n\tself:_releaseAll()\n', "sim/ArenaService", "when the match calls the arena off"),
 ("FL-0140", AS, '\t\tfigures:dress(venue, colors.a, colors.b)\n', '\t\tlocal _ = colors\n', "sim/ArenaService", "dresses the venue in the two qualifiers' colours"),
 ("FL-0140", AS, '\t\tfigures:reset(venue)\n', '\t\tlocal _ = venue\n', "sim/ArenaService", "dresses the venue in the two qualifiers' colours"),
 ("FL-0140", AS, 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 0.7)', 'local _ = step', "sim/ArenaService", "walks the AI figure up to its opponent"),
 ("FL-0140", AS, '\t\t\tself:_wear(champion, character) -- the gear stayed on the old character\n', '', "sim/ArenaService", "dresses a champion who resets again"),
 ("FL-0140", AS, '\t\t\t\tself:_wear(champion, character)\n', '', "sim/ArenaService", "puts the loadout's weapon and armour on a human champion"),
 ("FL-0140", FG, 'pcall(kit.character, "governor", "idle", spec.color, spec.look, spec.kingdom)', 'pcall(kit.character, "citizen", "idle", spec.color, spec.look, spec.kingdom)', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", FG, '\tmodel:SetAttribute("ArenaSide", spec.side)\n', '', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", FG, '\t\t\tself._collection:AddTag(model, "ArenaChampion")\n', '\t\t\tlocal _ = model\n', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", AS, 'local step = dt * self.config.ring.walkSpeed\n', 'local step = dt * self.config.ring.walkSpeed * 2\n', "sim/ArenaService", "never moves the AI figure faster than the fixed WalkSpeed"),
 ("FL-0140", FG, '\t\t\tif out > ring.radius then', '\t\t\tif false then', "sim/ArenaService", "keeps the AI figure inside the ring"),
 ("FL-0140", AS, 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 0.7, ring)', 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 3, ring)', "sim/ArenaService", "stays within its reach"),
]
