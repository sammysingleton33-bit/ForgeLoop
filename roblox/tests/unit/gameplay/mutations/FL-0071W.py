"""FL-0071W mutation rows (per-tier uses for the Called Warning: Arena/SupportModel, config Support).
Run by ../mutations.py (`mutations.py FL-0071W`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
SM = G + "src/shared/Arena/SupportModel.luau"
CS = G + "config/Support.luau"
M = [
 ("FL-0071W", SM, 'return uses[power]', 'return uses.pledged', "sim/SupportModel", "covers 2 heavy attacks pledged and 3 empowered"),
 ("FL-0071W", SM, 'uses = usesOf(perk, power),', 'uses = usesOf(perk, "pledged"),', "sim/SupportModel", "covers 2 heavy attacks pledged and 3 empowered"),
 ("FL-0071W", SM, 'format(perk.effect, perk[power], usesOf(perk, power))', 'format(perk.effect, perk[power], usesOf(perk, "pledged"))', "sim/SupportModel", "covers 2 heavy attacks pledged and 3 empowered"),
 ("FL-0071W", SM, 'return tostring(uses or 1)', 'return "two"', "sim/SupportModel", "covers 2 heavy attacks pledged and 3 empowered"),
 ("FL-0071W", CS, 'uses = { pledged = 2, empowered = 3 }', 'uses = { pledged = 2, empowered = 2 }', "sim/SupportModel", "covers 2 heavy attacks pledged and 3 empowered"),
]
