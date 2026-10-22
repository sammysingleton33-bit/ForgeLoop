"""FL-0143 mutation rows, run by ../mutations.py (FL-0143 only: `mutations.py FL-0143`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0143 here only (D-038 (7)).
Left out (equivalent): `if before ~= damage then` -> `if true then` only writes the same Damage value again, which
changes nothing a spec can see (the mocks have no AttributeChanged); the damage-state check still guards the apply.
"""
FB = C2 + "FeedbackController.luau"
BD = "experience/BuildingDamage"
M = [
 ("FL-0143", FB, 'if okApply and kit.damageState(damage) ~= kit.damageState(was) then', 'if okApply then', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, 'local was = if type(before) == "number" then before else 0', 'local was = 0', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, 'model:SetAttribute("Damage", damage)', 'local _ = damage', BD, "Damage follows Hp/MaxHp", "game"),
 ("FL-0143", FB, 'local ok, err = pcall(self.refreshDamage, self)', 'local ok, err = true, nil', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'if model:IsA("Model") then', 'if true then', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'if ready and type(hp) == "number" and hp == hp and type(maxHp) == "number" and maxHp > 0 then', 'if ready and type(hp) == "number" and type(maxHp) == "number" then', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'self._env.log("warn", "FeedbackController: Kit.applyDamage failed", { error = tostring(err) })', 'local _ = err', BD, "an applyDamage that throws", "game"),
 ("FL-0143", FB, 'if type(kit.applyDamage) ~= "function" or type(kit.damageFromHp) ~= "function" then', 'if false then', BD, "an applyDamage that throws", "game"),
 ("FL-0143", FB, '_kit = options.kit or Kit,', '_kit = Kit,', BD, "Damage follows Hp/MaxHp", "game"),

 # FORGE-07 #273: M1 (a damaged building the server moves), L1 (the tree guards), L2 (no PrimaryPart), the poll's pcall
 ("FL-0143", FB, 'local moved = dressedAt[model] ~= nil and movedSince(dressedAt[model], pivot)', 'local moved = false', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'if moved and kit.damageState(was) > 0 then', 'if false then', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'okApply, err = pcall(kit.applyDamage, model)\n\t\t\t\twas = 0', 'was = 0', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'return rel.Position.Magnitude > 0.01 or math.abs(angle) > 1e-3', 'return math.abs(angle) > 1e-3', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'return rel.Position.Magnitude > 0.01 or math.abs(angle) > 1e-3', 'return rel.Position.Magnitude > 0.01', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'dressedAt[model] = if kit.damageState(damage) > 0 then pivot else nil', 'dressedAt[model] = nil', BD, "a damaged building the server moves", "game"),
 ("FL-0143", FB, 'local ready = model.PrimaryPart ~= nil', 'local ready = true', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'hp == hp and type(maxHp) == "number" and maxHp > 0', 'hp == hp and maxHp > 0', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'local buildings = kingdom:FindFirstChild("Buildings")\n\t\tif buildings ~= nil then\n\t\t\tfor _, model in buildings:GetChildren() do\n\t\t\t\tif model:IsA("Model") then\n\t\t\t\t\tlocal hp', 'local buildings = kingdom:FindFirstChild("Buildings")\n\t\tif true then\n\t\t\tfor _, model in buildings:GetChildren() do\n\t\t\t\tif model:IsA("Model") then\n\t\t\t\t\tlocal hp', BD, "the poll does it", "game"),
 ("FL-0143", FB, 'local ok, err = pcall(self.refreshDamage, self)', 'local ok, err = true, self:refreshDamage()', BD, "an error in the damage pass", "game"),
 ("FL-0143", FB, 'self._env.log("warn", "FeedbackController: building damage failed", { error = tostring(err) })', 'local _ = err', BD, "an error in the damage pass", "game"),
]
