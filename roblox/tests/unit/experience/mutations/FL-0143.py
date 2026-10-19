"""FL-0143 mutation rows, run by ../mutations.py (FL-0143 only: `mutations.py FL-0143`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0143 here only (D-038 (7)).
"""
FB = C2 + "FeedbackController.luau"
BD = "experience/BuildingDamage"
M = [
 ("FL-0143", FB, 'if before ~= damage then', 'if true then', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'if kit.damageState(damage) ~= kit.damageState(was) then', 'if true then', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, 'local was = if type(before) == "number" then before else 0', 'local was = 0', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, 'model:SetAttribute("Damage", damage)', 'local _ = damage', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, '\t\t\tself:refreshDamage()\n', '', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'if model:IsA("Model") then', 'if true then', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'if type(hp) == "number" and hp == hp and type(maxHp) == "number" and maxHp > 0 then', 'if type(hp) == "number" and type(maxHp) == "number" then', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'self._env.log("warn", "FeedbackController: Kit.applyDamage failed", { error = tostring(err) })', 'local _ = err', BD, "an applyDamage that throws", "game"),
 ("FL-0143", FB, 'if type(kit.applyDamage) ~= "function" or type(kit.damageFromHp) ~= "function" then', 'if false then', BD, "an applyDamage that throws", "game"),
 ("FL-0143", FB, '_kit = options.kit or Kit,', '_kit = Kit,', BD, "Damage follows Hp/MaxHp", "game"),
]
