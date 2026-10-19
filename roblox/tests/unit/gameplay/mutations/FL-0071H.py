"""FL-0071H mutation rows (arena hardening: DuelRunner act clock, DuelModel impactAt tick, DuelAI seed and dodge cost).
Run by ../mutations.py (`mutations.py FL-0071H`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
DR = G + "src/shared/Arena/DuelRunner.luau"
DM = G + "src/shared/Arena/DuelModel.luau"
AI = G + "src/shared/Arena/DuelAI.luau"
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
]
