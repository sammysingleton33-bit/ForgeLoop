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
]
