"""FL-0115 mutation rows, run by ../mutations.py (FL-0115 only: `mutations.py FL-0115`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0115 here only (D-038 (7)).
"""
M = [
 ("FL-0115", F+"Bubbles.luau", 'limit = math.min(limit, config.withTextPhone)', 'limit = limit', "CitizenBubbles", 'textLimit(): fewer words', "game"),
 ("FL-0115", F+"Bubbles.luau", 'if type(zoom) == "number" and zoom > config.farZoom then', 'if type(zoom) == "number" and zoom >= config.farZoom then', "CitizenBubbles", 'textLimit(): fewer words', "game"),
 ("FL-0115", F+"Bubbles.luau", '\t\t\t\tother.owner ~= owner\n', '\t\t\t\ttrue\n', "CitizenBubbles", 'a card never covers another bubble', "game"),
 ("FL-0115", F+"Bubbles.luau", '\t\t\tplace(rectOf(entityId, size.badge), entityId)\n', '\n', "CitizenBubbles", 'requests too close for words both show badges', "game"),
 ("FL-0115", F+"Bubbles.luau", 'bubble.kind == kind and words < most then', 'bubble.kind == kind then', "CitizenBubbles", 'layout(): placards always show words', "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'anchors[id] = self:_screenPoint(positions[id] + Vector3.new(0, Def.HEIGHT, 0))', 'anchors[id] = nil', "CitizenBubbles", 'on screen, requests too close for words', "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'if input.accepts ~= nil and not input:accepts("explore") then', 'if false then', "CitizenBubbles", 'a tap on a bubble selects its citizen', "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'if self._pulsed[entityId] == key then', 'if false then', "CitizenBubbles", "a new request's badge pops once", "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", '\tif self:_reducedMotion() then\n\t\treturn\n\tend\n', '', "CitizenBubbles", "a new request's badge pops once", "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'gui.AlwaysOnTop = true', 'gui.AlwaysOnTop = false', "CitizenBubbles", 'reads from the aerial camera', "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'gui.Active = interactive', 'gui.Active = false', "CitizenBubbles", 'a tap on a bubble selects its citizen', "game"),
 ("FL-0115", C2+"CitizenBubbleController.luau", 'gui.Parent = self._playerGui or model', 'gui.Parent = model', "CitizenBubbles", 'a tap on a bubble selects its citizen', "game"),
]
