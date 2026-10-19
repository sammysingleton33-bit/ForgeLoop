"""FL-0071F mutation rows (Crown Arena stage flow and AI champion: Arena/ArenaFlow, Arena/DuelAI, config Arena).
Run by ../mutations.py (`mutations.py FL-0071F`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AF = G + "src/shared/Arena/ArenaFlow.luau"
AI = G + "src/shared/Arena/DuelAI.luau"
M = [
 # --- champions
 ("FL-0071F", AF, 'local better = best == nil', 'local better = best ~= nil', "sim/ArenaFlow", "ArenaFlow: champions"),
 ("FL-0071F", AF, 'better = votes > bestVotes', 'better = votes < bestVotes', "sim/ArenaFlow", "ArenaFlow: champions"),
 ("FL-0071F", AF, 'better = self._setup.leadership(candidate, kingdom)\n\t\t\t\t\t\t\t> self._setup.leadership(best :: number, kingdom)', 'better = self._setup.leadership(candidate, kingdom)\n\t\t\t\t\t\t\t< self._setup.leadership(best :: number, kingdom)', "sim/ArenaFlow", "a tied or empty vote goes to the higher leadership"),
 ("FL-0071F", AF, 'userId = if userId then userId else (if side == "a" then -1 else -2),', 'userId = if userId then userId else 0,', "sim/ArenaFlow", "an AI champion with a negative id"),
 ("FL-0071F", AF, 'if #candidates > 1 then -- a kingdom with one ruler has nothing to vote on', 'if true then', "sim/ArenaFlow", "closes the vote early"),
 ("FL-0071F", AF, 'if self._kingdoms[side] and #self._candidates[side] > 1 then', 'if self._kingdoms[side] and #self._candidates[side] > 0 then', "sim/ArenaFlow", "needs no vote"),
 ("FL-0071F", AF, 'if not contains(candidates, candidate) then\n\t\t\t\treturn false, "not_a_candidate"', 'if false then\n\t\t\t\treturn false, "not_a_candidate"', "sim/ArenaFlow", "not a candidate"),
 ("FL-0071F", AF, 'if self._stage ~= "vote" then\n\t\treturn false, "not_vote_stage"', 'if false then\n\t\treturn false, "not_vote_stage"', "sim/ArenaFlow", "not a candidate"),
 ("FL-0071F", AF, 'if anyHuman then\n\t\tself._stage = "loadout"', 'if true then\n\t\tself._stage = "loadout"', "sim/ArenaFlow", "two AI champions skip the loadout"),
 # --- the loadout
 ("FL-0071F", AF, 'if self._stage ~= "loadout" then\n\t\treturn false, "not_loadout_stage"', 'if false then\n\t\treturn false, "not_loadout_stage"', "sim/ArenaFlow", "only the champion chooses"),
 ("FL-0071F", AF, 'if champion == nil then\n\t\treturn false, "not_champion"', 'if false then\n\t\treturn false, "not_champion"', "sim/ArenaFlow", "only the champion chooses"),
 ("FL-0071F", AF, 'if champion.userId == userId and not champion.isAI then', 'if champion.userId == userId then', "sim/ArenaFlow", "an AI champion\'s id never chooses"),
 ("FL-0071F", AF, 'if #triggers > limit then', 'if #triggers > limit + 1 then', "sim/ArenaFlow", "more perks than slots"),
 ("FL-0071F", AF, 'local limit = math.min(champion.support.slots, Caps.NUMBERS.maxTriggers)', 'local limit = champion.support.slots', "sim/ArenaFlow", "more perks than slots"),
 ("FL-0071F", AF, 'if seen[trigger] then\n\t\t\treturn false, "duplicate"', 'if false then\n\t\t\treturn false, "duplicate"', "sim/ArenaFlow", "repeated perks"),
 ("FL-0071F", AF, 'if not offered then\n\t\t\treturn false, "not_offered"', 'if false then\n\t\t\treturn false, "not_offered"', "sim/ArenaFlow", "perks nobody offers"),
 ("FL-0071F", AF, 'DuelConfig.weapons[weapon] == nil', 'false', "sim/ArenaFlow", "a weapon or armour outside the config"),
 ("FL-0071F", AF, 'DuelConfig.armour[armour] == nil', 'false', "sim/ArenaFlow", "a weapon or armour outside the config"),
 ("FL-0071F", AF, 'if #out >= math.min(slots, Caps.NUMBERS.maxTriggers) then', 'if #out >= slots + 1 then', "sim/ArenaFlow", "the offered perks up to the slots"),
 ("FL-0071F", AF, 'if table.find(champion.triggers, offer.trigger) and offer.citizenName and offer.role then', 'if offer.citizenName and offer.role then', "sim/ArenaFlow", "the citizens behind the chosen perks"),
 # --- time and the end
 ("FL-0071F", AF, 'self._endsAt = at + self._cfg.duelMaxSeconds', 'self._endsAt = at + 1', "sim/ArenaFlow", "each stage lasts its configured time"),
 ("FL-0071F", AF, 'self:_crown(nil, nil, nil, { kind = "draw", reason = "duel_clock" }, at)', 'self:_crown("a", self._kingdoms.a, nil, { kind = "draw", reason = "duel_clock" }, at)', "sim/ArenaFlow", "walks vote, loadout, intro, duel, crowning, done"),
 ("FL-0071F", AF, 'while self._endsAt ~= nil and now >= self._endsAt and self._stage ~= "done" do', 'if self._endsAt ~= nil and now >= self._endsAt and self._stage ~= "done" then', "sim/ArenaFlow", "catches up through the stages it missed"),
 ("FL-0071F", AF, 'if result == "a" or result == "b" then', 'if result ~= "draw" then', "sim/ArenaFlow", "an unknown duel result is a draw"),
 ("FL-0071F", AF, 'self._coronation = if result.kind == "coronation" then kingdom else nil', 'self._coronation = kingdom', "sim/ArenaFlow", "a duel result starts the crowning"),
 ("FL-0071F", AF, 'if self._stage ~= "duel" then\n\t\treturn false\n\tend\n\tif result == "a"', 'if false then\n\t\treturn false\n\tend\n\tif result == "a"', "sim/ArenaFlow", "outside the duel stage is ignored"),
 ("FL-0071F", AF, 'self._winnerSide, self._winnerKingdom, self._winnerUser, self._coronation = nil, nil, nil, nil', 'self._winnerSide = nil', "sim/ArenaFlow", "a cancel during the crowning takes the winner back"),
 ("FL-0071F", AF, 'if self._stage == "crowning" or self._stage == "done" then\n\t\treturn false', 'if self._stage == "done" then\n\t\treturn false', "sim/ArenaFlow", "forfeits"),
 ("FL-0071F", AF, 'if other ~= nil and not other.gone then', 'if other ~= nil then', "sim/ArenaFlow", "both champions gone is a draw"),
 ("FL-0071F", AF, 'self._votes[voter] = nil', 'self._votes[voter] = voter', "sim/ArenaFlow", "a ruler who leaves during the vote drops out"),
 # --- the AI champion
 ("FL-0071F", AI, 'if event.kind == "heavyWindup" and event.side == self._other and event.data then', 'if event.kind == "heavyWindup" and event.data then', "sim/DuelAI", "is not answered"),
 ("FL-0071F", AI, 'if me.stamina < rules.lightCost + 6 then', 'if false then', "sim/DuelAI", "does not send a swing it cannot pay for"),
 ("FL-0071F", AI, 'if snapshot.ended then\n\t\treturn nil', 'if false then\n\t\treturn nil', "sim/DuelAI", "never sends while the duel is over"),
 ("FL-0071F", AI, 'if not incoming and them.state ~= "windup" then\n\t\t\treturn "blockEnd"', 'if false then\n\t\t\treturn "blockEnd"', "sim/DuelAI", "releases a block when nothing is coming"),
 ("FL-0071F", AI, 'local s = clamp(if type(skill) == "number" and skill == skill then skill else 0.5, 0, 1)', 'local s = if type(skill) == "number" then skill else 0.5', "sim/DuelAI", "clamps its skill"),
 ("FL-0071F", AI, 'self._seeAndAnswer = 0.35 + 0.55 * s', 'self._seeAndAnswer = 0', "sim/DuelAI", "answers a telegraphed heavy"),
 ("FL-0071F", AI, 'self._reaction = 0.30 - 0.18 * s', 'self._reaction = 0.30', "sim/DuelAI", "beats a novice AI clearly"),
]
