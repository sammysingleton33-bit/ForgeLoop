"""FL-0125I mutation rows (D-055 (2), (5): interest tiers and Sim.Focus in the full match). Run by ../mutations.py
(`mutations.py FL-0125I`). One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
ES = G + "src/server/Services/EntityService.luau"
M = [
 ("FL-0125I", ES, 'and self._match.host.match.mode == "match"', '', "sim/EntityService", "the slice broadcasts everything"),
 ("FL-0125I", ES, 'always = if kingdomId then always[kingdomId] else nil,', 'always = nil,', "sim/EntityService", "keeps a player's own soldiers"),
 ("FL-0125I", ES, 'self._env.clock() - focus.at <= MatchConfig.interest.focusStaleSeconds', 'true', "sim/EntityService", "a stale focus falls back"),
 ("FL-0125I", ES, 'farEvery = MatchConfig.interest.farEvery,', 'farEvery = 1,', "sim/EntityService", "sends the entities near each player's focus"),
 ("FL-0125I", ES, 'nearRadius = MatchConfig.interest.nearRadius,', 'nearRadius = 1e9,', "sim/EntityService", "sends the entities near each player's focus"),
 ("FL-0125I", ES, '			at = self._env.clock(),\n', '			at = 0,\n', "sim/EntityService", "a stale focus falls back"),
 ("FL-0125I", ES, '				self._focus[userId] = nil -- a player who left', '				local _ = nil -- a player who left', "sim/EntityService", "drops a player's focus when they leave"),
]
