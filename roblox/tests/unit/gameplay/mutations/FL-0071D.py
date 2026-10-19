"""FL-0071D mutation rows (the client DuelController: Controllers/DuelController, spec experience/DuelController).
Run by ../mutations.py (`mutations.py FL-0071D`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
DC = G + "src/client/Controllers/DuelController.luau"
M = [
 ("FL-0071D", DC, 'if not self:isChampion() then\n\t\treturn false', 'if false then\n\t\treturn false', "experience/DuelController", "sends nothing from a spectator"),
 ("FL-0071D", DC, 'state.stage ~= "duel" then\n\t\treturn false', 'false then\n\t\treturn false', "experience/DuelController", "sends nothing from a spectator"),
 ("FL-0071D", DC, 'duellist.userId == me and duellist.isAI ~= true', 'duellist.userId == me', "experience/DuelController", "sends nothing from a spectator"),
 ("FL-0071D", DC, 'duellist.userId == me and duellist.isAI ~= true', 'duellist.isAI ~= true', "experience/DuelController", "sends nothing from a spectator"),
 ("FL-0071D", DC, 'or not DuelController.ACTIONS[action] then', 'then', "experience/DuelController", "refuses an action that is not a DuelAction"),
 ("FL-0071D", DC, 'if self._tokens < 1 then', 'if false then', "experience/DuelController", "keeps to the server's rate"),
 ("FL-0071D", DC, 'math.max(0, now - last) * DuelController.PER_SECOND', 'math.max(0, now - last) * 1000', "experience/DuelController", "keeps to the server's rate"),
 ("FL-0071D", DC, 'math.max(0, now - last) * DuelController.PER_SECOND', 'math.max(0, now - last) * 0', "experience/DuelController", "keeps to the server's rate"),
 ("FL-0071D", DC, '\t\tself._tokens = DuelController.BURST -- a fresh duel starts with a full bucket\n', '', "experience/DuelController", "starts a new duel with a full bucket"),
 ("FL-0071D", DC, 'if type(event) == "table" and type(event.kind) == "string" then', 'if true then', "experience/DuelController", "unpacks Arena.Events batches"),
 ("FL-0071D", DC, 'if type(state) ~= "table" or type(state.stage) ~= "string" then', 'if false then', "experience/DuelController", "keeps the latest Arena.State"),
 ("FL-0071D", DC, 'if not self._destroyed and self._state == nil then', 'if false then', "experience/DuelController", "asks Arena.GetState once"),
 ("FL-0071D", DC, 'if self._destroyed or type(action) ~= "string"', 'if type(action) ~= "string"', "experience/DuelController", "stops relaying and sending after destroy"),
 ("FL-0071D", DC, '\t\tlink:disconnect()\n', '', "experience/DuelController", "stops relaying and sending after destroy"),
]
