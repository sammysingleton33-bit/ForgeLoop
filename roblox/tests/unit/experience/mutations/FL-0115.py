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
 ("FL-0115", C2+"InputModeController.luau", 'if screenPos ~= nil and self:accepts("explore") then', 'if screenPos ~= nil then', 'InputMode', 'hover: a mouse move over a citizen', "game"),
 ("FL-0115", C2+"InputModeController.luau", 'if kind ~= self.hover.kind or id ~= self.hover.id then', 'if true then', 'InputMode', 'hover: a mouse move over a citizen', "game"),
 ("FL-0115", C2+"InputModeController.luau", 'if input.UserInputType == Enum.UserInputType.MouseMovement then', 'if true then', 'InputMode', 'hover: a mouse move over a citizen', "game"),
 ("FL-0115", C2+"InputModeController.luau", 'self:hoverAt(if processed then nil else Vector2.new(input.Position.X, input.Position.Y))', 'self:hoverAt(Vector2.new(input.Position.X, input.Position.Y))', 'InputMode', 'hover: a mouse move over a citizen', "game"),
 ("FL-0115", C2+"InputModeController.luau", 'if nextMode ~= "explore" then', 'if false then', 'FeedbackHighlight', 'placing a building clears the hover outline', "game"),
 ("FL-0115", C2+"InputModeController.luau", '\t\t\t\tself:hoverAt(nil)\n', '', 'InputMode', 'hover: leaving explore mode clears it at once', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'return if kind == "citizen" and type(id) == "number" and id == id then id else nil', 'return id', 'FeedbackHighlight', 'the selected citizen keeps a gold outline', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'self._gone[id] = true -- getModel still returns the pooled rig until it is rendered again', 'local _ = id', 'FeedbackHighlight', 'a released rig loses its outline', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'local hover = if self.hoverId ~= self.selectedId then self.hoverId else nil', 'local hover = self.hoverId', 'FeedbackHighlight', 'the selected citizen keeps a gold outline', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'if id == nil or self._talking or self._gone[id] then', 'if id == nil or self._gone[id] then', 'FeedbackHighlight', 'while the conversation stage shows', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'if not ok or model == nil or model.Parent == nil then', 'if not ok or model == nil then', 'FeedbackHighlight', 'no outline on a rig hidden by LOD', "game"),
 ("FL-0115", C2+"FeedbackHighlightController.luau", 'light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop', 'light.DepthMode = Enum.HighlightDepthMode.Occluded', 'FeedbackHighlight', 'outlines the citizen under the mouse', "game"),
]
