"""FL-0069F mutation rows (follow-ups to the leadership ledger: per-kingdom cap, frozen records, sim-time polling,
ruler acts need a ruler, neutral stability; Caps order, DuelModel malformed hpBelow).
Run by ../mutations.py (`mutations.py FL-0069F`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
LG = G + "src/shared/Arena/Ledger.luau"
LS = G + "src/server/Services/LeadershipService.luau"
CP = G + "src/shared/Arena/Caps.luau"
DM = G + "src/shared/Arena/DuelModel.luau"
M = [
 # --- the ledger cap and frozen moments
 ("FL-0069F", LG, 'if kept > Ledger.MAX_PER_KINGDOM then', 'if kept > Ledger.MAX_PER_KINGDOM * 100 then', "sim/Ledger", "keeps the last moments of each kingdom"),
 ("FL-0069F", LG, 'if old.kingdom == kingdom then', 'if true then', "sim/Ledger", "keeps the last moments of each kingdom"),
 ("FL-0069F", LG, 'local kept = (ledger.counts[kingdom] or 0) + 1', 'local kept = #ledger.moments', "sim/Ledger", "keeps the last moments of each kingdom"),
 ("FL-0069F", LG, '\ttable.freeze(moment)\n', '', "sim/Ledger", "hands out frozen moments"),
 ("FL-0069F", LG, 'return def ~= nil and def.scope == "ruler"', 'return def ~= nil', "sim/Ledger", "knows which components belong to a ruler"),
 # --- the service
 ("FL-0069F", LS, 'if userId == nil and #k.rulers > 0 and def and Ledger.isRulerComponent(self._ledger, def.component) then', 'if false then', "sim/LeadershipService", "refuses a ruler act with no ruler named"),
 ("FL-0069F", LS, 'if userId == nil and #k.rulers > 0 and def and Ledger.isRulerComponent(self._ledger, def.component) then', 'if userId == nil and #k.rulers > 0 and def then', "sim/LeadershipService", "refuses a ruler act with no ruler named"),
 ("FL-0069F", LS, 'if userId == nil and #k.rulers > 0 and def and', 'if userId == nil and def and', "sim/LeadershipService", "refuses a ruler act with no ruler named"),
 ("FL-0069F", LS, '(conditions.stability or NEUTRAL)', '(conditions.stability or 0)', "sim/LeadershipService", "reads a conditions table without stability as neutral"),
 ("FL-0069F", LS, '(k.unrestPressure or 0)', '0', "sim/LeadershipService", "reads a conditions table without stability as neutral"),
 ("FL-0069F", LS, 'self._env.wait(self.config.sampling.pollSeconds)', 'self._env.wait(self.config.sampling.intervalSeconds)', "sim/LeadershipService", "checks for a due sample every pollSeconds"),
 ("FL-0069F", LS, 'return if list then table.clone(list) else {}', 'return if list then list else {}', "sim/LeadershipService", "returns copies and frozen records"),
 ("FL-0069F", LS, '\ttable.freeze(sample.components)\n', '', "sim/LeadershipService", "returns copies and frozen records"),
 ("FL-0069F", LS, '\ttable.freeze(sample)\n', '', "sim/LeadershipService", "returns copies and frozen records"),
 # --- Caps and DuelModel
 ("FL-0069F", CP, 'if slottedPassive[name] then', 'if false then', "sim/ArenaCaps", "in either order"),
 ("FL-0069F", CP, 'slottedPassive[name] = true\n', '', "sim/ArenaCaps", "in either order"),
 ("FL-0069F", DM, 'if limit == nil then', 'if false then', "sim/DuelModel", "a malformed hpBelow condition never fires"),
 ("FL-0069F", LS, 'local key = `{kingdom}|-|{act}`', 'local key = `-|{act}`', "sim/LeadershipService", "logging it once per kingdom and act"),
]
