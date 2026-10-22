"""FL-0142S mutation rows (ArenaState.vote, the server half of FORGE-03's vote panel: ArenaFlow:state()).
Run by ../mutations.py (`mutations.py FL-0142S`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AF = G + "src/shared/Arena/ArenaFlow.luau"
M = [
 ("FL-0142S", AF, 'if self._stage ~= "vote" then\n\t\treturn nil', 'if false then\n\t\treturn nil', "sim/ArenaFlow", "lists only the sides that vote, and nothing once the vote has closed"),
 ("FL-0142S", AF, 'candidates and #candidates > 1 then\n\t\t\tlocal voted', 'candidates and #candidates > 0 then\n\t\t\tlocal voted', "sim/ArenaFlow", "lists only the sides that vote"),
 ("FL-0142S", AF, 'if self._votes[candidate] ~= nil then\n\t\t\t\t\ttable.insert(voted, candidate)', 'if true then\n\t\t\t\t\ttable.insert(voted, candidate)', "sim/ArenaFlow", "shows the vote stage"),
 ("FL-0142S", AF, 'if self._votes[candidate] ~= nil then\n\t\t\t\t\ttable.insert(voted, candidate)', 'if false then\n\t\t\t\t\ttable.insert(voted, candidate)', "sim/ArenaFlow", "shows the vote stage"),
 ("FL-0142S", AF, 'view[side] = { kingdom = kingdom, candidates = table.clone(candidates), voted = voted }', 'view[side] = { kingdom = kingdom, candidates = voted, voted = voted }', "sim/ArenaFlow", "shows the vote stage"),
 ("FL-0142S", AF, '\t\tvote = self:_voteView(),\n', '', "sim/ArenaFlow", "shows the vote stage"),
 ("FL-0142S", AF, 'if self._votes[userId] == nil then\n\t\t\t\tself._rev += 1', 'if true then\n\t\t\t\tself._rev += 1', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0142S", AF, 'if self._votes[userId] == nil then\n\t\t\t\tself._rev += 1', 'if false then\n\t\t\t\tself._rev += 1', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0142S", AF, '\t\tself._votes[userId] = nil\n\t\tif changed then', '\t\tself._votes[userId] = nil\n\t\tfor voter, candidate in self._votes do\n\t\t\tif candidate == userId then\n\t\t\t\tself._votes[voter] = nil\n\t\t\tend\n\t\tend\n\t\tif changed then', "sim/ArenaFlow", "does not show, after a leaver, who had voted for them"),
]
