"""FL-0070 mutation rows (Crown Arena support: Arena/SupportModel and config Support; CONTRACTS G12.2 / G12.3).
Run by ../mutations.py (`mutations.py FL-0070`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
SM = G + "src/shared/Arena/SupportModel.luau"
CFG = G + "config/Support.luau"
M = [
 # --- the score
 ("FL-0070", SM, 'return sampling.wholeMatchShare * wholeAverage + (1 - sampling.wholeMatchShare) * recentAverage', 'return recentAverage', "sim/SupportModel", "a good deed in the last minute cannot jump a tier"),
 ("FL-0070", SM, 'return sampling.wholeMatchShare * wholeAverage + (1 - sampling.wholeMatchShare) * recentAverage', 'return wholeAverage', "sim/SupportModel", "an early mistake is repairable"),
 ("FL-0070", SM, 'if finite(sample.t) and sample.t <= now then', 'if true then', "sim/SupportModel", "ignores samples from the future"),
 ("FL-0070", SM, 'if score >= cfg.tiers[tier].min then', 'if score > cfg.tiers[tier].min then', "sim/SupportModel", "tierOf honours the band edges"),
 ("FL-0070", SM, 'local value = clamp(if finite(raw) then raw else NEUTRAL, 0, 100)', 'local value = clamp(raw or 0, 0, 100)', "sim/SupportModel", "a sample that lacks a component counts it as neutral"),
 ("FL-0070", SM, 'if recent == nil or before == nil then\n\t\treturn 0', 'if recent == nil or before == nil then\n\t\treturn 1', "sim/SupportModel", "the trend is the change over 5 minutes"),
 # --- non-finite input (FORGE-07 L1)
 ("FL-0070", SM, 'local value = clamp(if finite(raw) then raw else NEUTRAL, 0, 100)', 'local value = clamp(raw or NEUTRAL, 0, 100)', "sim/SupportModel", "a NaN or infinite input is never evidence"),
 ("FL-0070", SM, 'if finite(sample.t) and sample.t <= now then', 'if sample.t <= now then', "sim/SupportModel", "a NaN or infinite input is never evidence"),
 ("FL-0070", SM, 'if not finite(now) then\n\t\treturn NEUTRAL', 'if false then\n\t\treturn NEUTRAL', "sim/SupportModel", "a NaN or infinite input is never evidence"),
 ("FL-0070", SM, 'if not finite(score) then\n\t\tscore = NEUTRAL', 'if false then\n\t\tscore = NEUTRAL', "sim/SupportModel", "a NaN or infinite input is never evidence"),
 ("FL-0070", CFG, 'adoring = { min = 85, passive = { damageReduction = 0.01, staminaRegen = 0.01 }', 'adoring = { min = 85, passive = { damageReduction = 0.02, staminaRegen = 0.01 }', "sim/SupportModel", "pins the FL-0076 trim"),
 ("FL-0070", CFG, 'pledged = 0.03,\n\t\t\tempowered = 0.05,\n\t\t\tduration = 4,', 'pledged = 0.05,\n\t\t\tempowered = 0.05,\n\t\t\tduration = 4,', "sim/SupportModel", "pins the FL-0076 trim"),
 ("FL-0070", CFG, 'pledged = 0.03,\n\t\t\tempowered = 0.05,\n\t\t\tduration = 4,', 'pledged = 0.03,\n\t\t\tempowered = 0.08,\n\t\t\tduration = 4,', "sim/SupportModel", "pins the FL-0076 trim"),
 # --- FORGE-00 verifier (a)-(c)
 ("FL-0070", SM, 'local magnitude = if power == "pledged" or power == "empowered" then perk[power] else nil', 'local magnitude = perk[power]', "sim/SupportModel", "accepts only the powers pledged and empowered"),
 ("FL-0070", SM, 'local magnitude = if power == "pledged" or power == "empowered" then perk[power] else nil', 'local magnitude = if power == "pledged" then perk[power] else nil', "sim/SupportModel", "both powers is within Caps.check"),
 ("FL-0070", SM, 'if picked[pick.trigger] then', 'if false then', "sim/SupportModel", "refuses a repeated pick"),
 ("FL-0070", SM, '	if tierDef == nil then\n		error(`SupportModel: unknown tier \'{tostring(tier)}\'`, 2)\n	end\n	local offers', '	if false then\n		error(`SupportModel: unknown tier \'{tostring(tier)}\'`, 2)\n	end\n	local offers', "sim/SupportModel", "offers refuses an unknown tier"),
 # --- the offers
 ("FL-0070", SM, 'citizen.loyalty >= cfg.offer.pledgedLoyalty', 'citizen.loyalty > cfg.offer.pledgedLoyalty', "sim/SupportModel", "offers a perk at loyalty 80"),
 ("FL-0070", SM, 'citizen.loyalty >= cfg.offer.empoweredLoyalty', 'citizen.loyalty > cfg.offer.empoweredLoyalty', "sim/SupportModel", "offers a perk at loyalty 80"),
 ("FL-0070", SM, 'if citizen.alive and byRole[citizen.role] == nil then', 'if byRole[citizen.role] == nil then', "sim/SupportModel", "a dead key citizen offers nothing"),
 ("FL-0070", SM, 'if citizen.alive and byRole[citizen.role] == nil then', 'if citizen.alive then', "sim/SupportModel", "one key citizen per role"),
 ("FL-0070", SM, '	if tierDef.crowdRally then\n		table.insert(offers, {', '	if true then\n		table.insert(offers, {', "sim/SupportModel", "the Crowd Rally is offered to Adoring only"),
 # --- the modifiers
 ("FL-0070", SM, 'if #picks > tierDef.slots then', 'if false then', "sim/SupportModel", "refuses too many picks"),
 ("FL-0070", SM, 'if pick.trigger == "crowdRally" and not tierDef.crowdRally then', 'if false then', "sim/SupportModel", "refuses too many picks"),
 # --- the config stays inside the caps and its own shape
 ("FL-0070", CFG, 'adoring = { min = 85, passive = { damageReduction = 0.01, staminaRegen = 0.01 }', 'adoring = { min = 85, passive = { damageReduction = 0.04, staminaRegen = 0.01 }', "sim/SupportModel", "every tier x every pick set"),
 ("FL-0070", CFG, 'empowered = 0.10,\n\t\t\tduration = 6,', 'empowered = 0.12,\n\t\t\tduration = 6,', "sim/SupportModel", "every tier x every pick set"),
 ("FL-0070", CFG, 'loyalty = { weight = 20, scope = "kingdom" },', 'loyalty = { weight = 25, scope = "kingdom" },', "sim/SupportModel", "component weights add up to 100"),
]
