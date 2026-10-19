"""FL-0071 mutation rows (Crown Arena foundation: Arena/DuelModel and Arena/Caps; CONTRACTS G12.2 / G12.3).
Run by ../mutations.py (`mutations.py FL-0071`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
DM = G + "src/shared/Arena/DuelModel.luau"
CAPS = G + "src/shared/Arena/Caps.luau"
DUEL = G + "config/Duel.luau"
M = [
 # --- conditions the model can evaluate (FORGE-00 verifier findings 1, 2, 4)
 ("FL-0071", CAPS, 'if not validCondition(m.condition) then', 'if false then', "sim/ArenaCaps", "refuses an active effect with no condition"),
 ("FL-0071", CAPS, 'return share ~= nil and share > 0 and share <= 1', 'return share ~= nil and share >= 0 and share <= 1', "sim/ArenaCaps", "an HP share outside (0, 1]"),
 ("FL-0071", CAPS, 'return share ~= nil and share > 0 and share <= 1', 'return share ~= nil and share > 0', "sim/ArenaCaps", "an HP share outside (0, 1]"),
 ("FL-0071", CAPS, 'local FIXED_CONDITIONS = { staminaOut = true, hype = true, opponentHeavy = true }', 'local FIXED_CONDITIONS = { staminaOut = true, hype = true }', "sim/ArenaCaps", "refuses an active effect with no condition"),
 ("FL-0071", CAPS, 'if type(condition) ~= "string" then\n\t\treturn false\n\tend\n\tif FIXED_CONDITIONS', 'if false then\n\t\treturn false\n\tend\n\tif FIXED_CONDITIONS', "sim/ArenaCaps", "refuses an active effect with no condition"),
 ("FL-0071", DM, 'if type(condition) ~= "string" then\n\t\treturn false', 'if false then\n\t\treturn false', "sim/DuelModel", "never fires and never throws"),
 ("FL-0071", DM, 'lead = effect.lead or 0,', 'lead = effect.lead,', "sim/DuelModel", "reports warned = 0, never nil"),
 ("FL-0071", DUEL, 'quietStart = 10,', 'quietStart = 5,', "sim/ArenaCaps", "quiet start is never earlier"),
 # --- the duel
 ("FL-0071", DM, 'if not (dt > 0 and dt < math.huge) then', 'if false then', "sim/DuelModel", "a bad step"),
 ("FL-0071", DM, 'if not (dt > 0 and dt < math.huge) then', 'if not (dt < math.huge) then', "sim/DuelModel", "a bad step"),
 ("FL-0071", DM, 'if not (dt > 0 and dt < math.huge) then', 'if not (dt > 0) then', "sim/DuelModel", "a bad step"),
 ("FL-0071", DM, 'dt = math.min(dt, MAX_STEP)', 'dt = dt', "sim/DuelModel", "clamps a long step"),
 ("FL-0071", DM, 'damage *= cfg.suddenDeathDamage', 'damage *= 1', "sim/DuelModel", "a tie at the cap is sudden death"),
 ("FL-0071", DM, 'damage *= state.weapons[defender.weapon].blockFactor', 'damage *= 1', "sim/DuelModel", "a block lets only blockFactor"),
 ("FL-0071", DM, 'state.t >= math.max(state.config.quietStart, trigger.earliest or 0)', 'state.t >= (trigger.earliest or 0)', "sim/DuelModel", "a trigger never fires in the first 10 seconds"),
 ("FL-0071", DM, '	trigger.fired = true\n', '', "sim/DuelModel", "a trigger never fires in the first 10 seconds"),
 ("FL-0071", DM, '		if side.state ~= "idle" or side.stamina < cost then', '		if side.state ~= "idle" then', "sim/DuelModel", "cannot start an attack without stamina"),
 ("FL-0071", DM, '		if side.state ~= "idle" or side.stamina < cost then', '		if side.stamina < cost then', "sim/DuelModel", "cannot start an attack without stamina"),
 ("FL-0071", DM, '		emit(state, events, "parry", defender.id)\n		attacker.state = "stagger"', '		emit(state, events, "parry", defender.id)\n		attacker.state = "recover"', "sim/DuelModel", "a parry in time costs the attacker a stagger"),
 ("FL-0071", DM, '* (1 - state.armours[defender.armour].reduction)', '', "sim/DuelModel", "armour reduces damage taken"),
 ("FL-0071", DM, 'elseif state.t >= cfg.hardCap then\n		finish(state, "draw", "hardCap", events)', 'elseif false then\n		finish(state, "draw", "hardCap", events)', "sim/DuelModel", "a hard cap with no winner is a draw"),
 ("FL-0071", DM, 'finish(state, if a.hp > b.hp then "a" else "b", "timeCap", events)', 'finish(state, if a.hp > b.hp then "b" else "a", "timeCap", events)', "sim/DuelModel", "at the time cap the higher HP wins"),
 ("FL-0071", DM, '(1 + bonus(state, attacker, "damage"))', '1', "sim/DuelModel", "passive bonuses apply all duel"),
 ("FL-0071", DM, 'if effect.stat == stat and effect.endsAt > state.t and effect.magnitude > strongest then', 'if effect.stat == stat and effect.endsAt > state.t then', "sim/DuelModel", "do not stack, the stronger applies"),
 ("FL-0071", DM, 'side.hp = math.min(cfg.maxHp, side.hp + heal.rate * dt)', 'side.hp = side.hp + heal.rate * dt', "sim/DuelModel", "healing is spread over the trigger"),
 # --- the caps
 ("FL-0071", CAPS, 'passivePerStat = 0.05,', 'passivePerStat = 0.06,', "sim/ArenaCaps", "passive over 5 %"),
 ("FL-0071", CAPS, 'maxTriggers = 3,', 'maxTriggers = 4,', "sim/ArenaCaps", "more than 3 triggers"),
 ("FL-0071", CAPS, 'triggerMaxMagnitude = 0.10,', 'triggerMaxMagnitude = 0.12,', "sim/ArenaCaps", "more than 3 triggers"),
 ("FL-0071", CAPS, 'totalPerStat = 0.15,', 'totalPerStat = 0.12,', "sim/ArenaCaps", "accepts no support at all, and sets exactly at the limits"),
 ("FL-0071", CAPS, 'healPerDuel = 0.10,', 'healPerDuel = 0.20,', "sim/ArenaCaps", "healing over 8 %"),
 ("FL-0071", CAPS, 'if m.affectsOpponent then', 'if false then', "sim/ArenaCaps", "an effect on the opponent"),
 ("FL-0071", CAPS, 'if m.earliest ~= nil and m.earliest < caps.quietStartSeconds then', 'if false then', "sim/ArenaCaps", "a trigger inside the quiet start"),
]
