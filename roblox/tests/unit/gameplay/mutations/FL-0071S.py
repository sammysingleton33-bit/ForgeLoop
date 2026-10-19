"""FL-0071S mutation rows (Crown Arena shell: Services/ArenaService, Services/SupportService).
Run by ../mutations.py (`mutations.py FL-0071S`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AS = G + "src/server/Services/ArenaService.luau"
SS = G + "src/server/Services/SupportService.luau"
M = [
 # --- the arena host
 ("FL-0071S", AS, 'if self._flow ~= nil then\n\t\treturn false\n\tend\n\tlocal sim', 'if false then\n\t\treturn false\n\tend\n\tlocal sim', "sim/ArenaService", "a second arena cannot begin"),
 ("FL-0071S", AS, '\tleadership:closeOut()', '\tlocal _ = 0', "sim/ArenaService", "closes the leadership ledger"),
 ("FL-0071S", AS, 'local ok = flow:vote(player.UserId, candidate)', 'local ok = flow:vote(candidate, candidate)', "sim/ArenaService", "co-rulers vote"),
 ("FL-0071S", AS, 'flow:choose(player.UserId, weapon, armour, triggers)', 'flow:choose(1, weapon, armour, triggers)', "sim/ArenaService", "takes the champion's choice from the sender"),
 ("FL-0071S", AS, 'runner:act(player.UserId, action, self:_now())', 'runner:act(1, action, self:_now())', "sim/ArenaService", "drops an action from a stranger"),
 ("FL-0071S", AS, 'self._match:arenaEnded(winner)', 'self._match:arenaEnded(nil)', "sim/ArenaService", "a knockout ends the duel"),
 ("FL-0071S", AS, 'place(a.userId, site.x - half, site.z, site.x + half, site.z)', 'place(a.userId, site.x + half, site.z, site.x - half, site.z)', "sim/ArenaService", "places both champions on the ring"),
 ("FL-0071S", AS, 'if a and not a.isAI then', 'if false then', "sim/ArenaService", "places both champions on the ring"),
 ("FL-0071S", AS, 'if self._runner ~= nil and flow:stage() == "duel" then', 'if false then', "sim/ArenaService", "a player who leaves during the duel forfeits"),
 ("FL-0071S", AS, 'if rev == self._rev then\n\t\treturn\n\tend', 'if false then\n\t\treturn\n\tend', "sim/ArenaService", "publishes the state to everyone on every change"),
 ("FL-0071S", AS, 'self:_cancel(reason)', 'local _ = reason', "sim/ArenaService", "a cancel from the match clears the arena"),
 # --- the support view
 ("FL-0071S", SS, 'if sim.kingdoms[kingdom] == nil then\n\t\treturn nil', 'if false then\n\t\treturn nil', "sim/ArenaService", "has no view for a kingdom that is not in the match"),
 ("FL-0071S", SS, 'local kingdom, userId = self:_rulerOf(player)\n\t\tif kingdom == nil then\n\t\t\treturn nil', 'local kingdom, userId = self:_rulerOf(player)\n\t\tif false then\n\t\t\treturn nil', "sim/ArenaService", "their own view"),
 ("FL-0071S", SS, 'return da > db', 'return da < db', "sim/ArenaService", "names the three moments that moved the score most"),
 ("FL-0071S", SS, 'if not seen[entry.moment.text] then', 'if true then', "sim/ArenaService", "each text once"),
 ("FL-0071S", SS, 'if #reasons >= REASONS then', 'if #reasons >= REASONS + 5 then', "sim/ArenaService", "names the three moments that moved the score most"),
 ("FL-0071S", SS, 'self._leadership.sampled:connect(function()', 'self._leadership.acted:connect(function()', "sim/ArenaService", "pushes Kingdom.Support to every ruler after each leadership sample"),
]
