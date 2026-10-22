"""FL-0141C mutation rows (the duel cues FL-0141 animates from: DuelModel lightWindup / dodgeStart / hit.blocked and their
Arena.Events relay in DuelRunner). Run by ../mutations.py (`mutations.py FL-0141C`).
One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
DM = G + "src/shared/Arena/DuelModel.luau"
DR = G + "src/shared/Arena/DuelRunner.luau"
M = [
 ("FL-0141C", DM, 'emit(state, events, "lightWindup", side.id, { impactAt = state.t + side.timer - (state.stepDt or 0) })', 'local _ = 0', "sim/DuelModel", "a light swing is announced when it starts"),
 ("FL-0141C", DM, 'emit(state, events, "lightWindup", side.id, { impactAt = state.t + side.timer - (state.stepDt or 0) })', 'emit(state, events, "lightWindup", side.id, { impactAt = state.t + side.timer })', "sim/DuelModel", "a light swing is announced when it starts"),
 ("FL-0141C", DM, '\t\t\temit(state, events, "dodgeStart", side.id)\n', '', "sim/DuelModel", "a dodge is announced when it begins"),
 ("FL-0141C", DM, 'local blocked = defender.state == "block"', 'local blocked = false', "sim/DuelModel", "a hit says whether the target was guarding"),
 ("FL-0141C", DM, '\t\tblocked = blocked,\n', '\t\tblocked = defender.state == "block",\n', "sim/DuelModel", "a hit says whether the target was guarding"),
 ("FL-0141C", DR, 'data = { impactIn = math.max(0, data.impactAt - event.t) },', 'data = { impactIn = data.impactAt },', "sim/DuelRunner", "relays the cues FL-0141 animates from"),
 ("FL-0141C", DR, ' or kind == "hype" or kind == "dodgeStart" then', ' or kind == "hype" then', "sim/DuelRunner", "relays the cues FL-0141 animates from"),
 ("FL-0141C", DR, 'blocked = data.blocked == true,', 'blocked = false,', "sim/DuelRunner", "relays the cues FL-0141 animates from"),
 ("FL-0141C", DR, '\telseif kind == "lightWindup" and data then', '\telseif kind == "lightWindupX" and data then', "sim/DuelRunner", "relays the cues FL-0141 animates from"),
]
