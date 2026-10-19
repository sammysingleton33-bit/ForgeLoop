"""FL-0071H mutation rows (arena hardening: DuelRunner act clock, DuelModel impactAt tick, DuelAI seed and dodge cost).
Run by ../mutations.py (`mutations.py FL-0071H`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
DR = G + "src/shared/Arena/DuelRunner.luau"
DM = G + "src/shared/Arena/DuelModel.luau"
AI = G + "src/shared/Arena/DuelAI.luau"
AF = G + "src/shared/Arena/ArenaFlow.luau"
AS = G + "src/server/Services/ArenaService.luau"
SS = G + "src/server/Services/SupportService.luau"
M = [
 ("FL-0071H", DR, 'if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge then', 'if false then', "sim/DuelRunner", "refuses a clock that is not a finite number"),
 ("FL-0071H", DR, 'if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge then', 'if type(now) ~= "number" then', "sim/DuelRunner", "refuses a clock that is not a finite number"),
 ("FL-0071H", DR, 'if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge then', 'if type(now) ~= "number" or now ~= now then', "sim/DuelRunner", "refuses a clock that is not a finite number"),
 ("FL-0071H", DM, '{ impactAt = state.t + side.timer - (state.stepDt or 0), warned = warned }', '{ impactAt = state.t + side.timer, warned = warned }', "sim/DuelModel", "the telegraphed impact time is the time the heavy actually lands"),
 ("FL-0071H", DM, '\tstate.stepDt = dt', '\tstate.stepDt = 0', "sim/DuelModel", "the telegraphed impact time is the time the heavy actually lands"),
 ("FL-0071H", AI, 'if type(seed) == "number" and seed == seed and math.abs(seed) < math.huge then seed else 1', 'seed', "sim/DuelAI", "a seed that is not a finite number"),
 ("FL-0071H", AI, 'seed == seed and math.abs(seed) < math.huge then', 'seed == seed then', "sim/DuelAI", "a seed that is not a finite number"),
 ("FL-0071H", AI, 'if me.stamina >= dodgeCost and nextRandom(self) < 0.5 then', 'if me.stamina >= 25 and nextRandom(self) < 0.5 then', "sim/DuelAI", "a dodge needs the armour's own dodge cost"),
 ("FL-0071H", AI, 'if me.stamina >= dodgeCost and nextRandom(self) < 0.5 then', 'if me.stamina >= 1 and nextRandom(self) < 0.5 then', "sim/DuelAI", "a dodge needs the armour's own dodge cost"),
 # --- FORGE-00's lows: one truthiness rule for the gate, rev only on a real change, an AI champion's own reasons
 ("FL-0071H", AS, 'if self.config.enabled ~= true then', 'if not self.config.enabled then', "sim/ArenaService", "only `enabled = true` switches the arena on"),
 ("FL-0071H", AF, 'if self._votes[userId] ~= candidate then', 'if true then', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, 'local changed = not champion.chosen', 'local changed = true', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, 'local changed = not champion.chosen', 'local changed = false', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, '\t\tor champion.weapon ~= weapon\n', '\n', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, '\t\tor champion.armour ~= armour\n', '\n', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, '\t\tor #champion.triggers ~= #chosen\n', '\n', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", AF, 'changed = changed or champion.triggers[index] ~= trigger', 'changed = changed', "sim/ArenaFlow", "a repeat of the same vote or loadout changes nothing"),
 ("FL-0071H", SS, 'if moment.userId == nil then', 'if true then', "sim/ArenaService", "an AI champion's reasons are the kingdom's own moments"),
 ("FL-0071H", SS, '\tif userId == nil then\n\t\t-- an AI champion answers', '\tif false then\n\t\t-- an AI champion answers', "sim/ArenaService", "an AI champion's reasons are the kingdom's own moments"),
]
