"""FL-0100 mutation rows, run by ../mutations.py (FL-0100 only: `mutations.py FL-0100`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0100 here only (D-038 (7)).
"""
M = [
 ("FL-0100", C2+"RulerCameraController.luau", 'if self:_reducedMotion() or duration <= 0 or shown == nil then', 'if duration <= 0 or shown == nil then', "RulerCamera", "reduced motion cuts to the conversation view", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '	if self._saved == nil then\n		self._saved = {', '	if true then\n		self._saved = {', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'shown.focus = glide.from.focus:Lerp(glide.to.focus, k)', 'shown.focus = glide.to.focus', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '		self._glide = nil -- a pan or a "go to" ends a conversation glide\n', '', "RulerCamera", "a pan ends a glide", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'local focus = Def.clampFocus(position + Def.panVector(offset, yaw), bounds, margin)', 'local focus = Def.clampFocus(position, bounds, margin)', "RulerCamera", "conversationView() frames the citizen above the centre", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if typeof(position) ~= "Vector3" or self.mode ~= "overview" or self._target.focus == nil then', 'if typeof(position) ~= "Vector3" or self._target.focus == nil then', "RulerCamera", "walk mode ignores it", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if self:focusOn(position, { facing = facing }) and source == "rig" then', 'if false then', "RulerCamera", "follows ConversationController.opened / closed", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\treturn yawOf(-flat)\n', '\treturn yawOf(flat)\n', "RulerCamera", "conversationYaw() looks at the citizen's face", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'return toRuler, "ruler"', 'return nil, nil', "RulerCamera", "faces the citizen toward the ruler's character", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'and source == "rig" then', 'then', "RulerCamera", "faces the citizen toward the ruler's character", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if math.abs(angleDelta(talking.yaw, yaw)) < math.rad(Def.FOLLOW_DEGREES) then', 'if true then', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\tself._talking = nil -- the player turns the view: stop following the citizen\n', '', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\tself:_followTalker(dt)\n', '', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'local offset = if phone and conversation.phoneOffset then conversation.phoneOffset else conversation.offset', 'local offset = conversation.offset', "RulerCamera", "on a phone the citizen sits in the top 40 %", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'return ScreenLayout.breakpoint(width, self:_viewportHeight()) == "phone"', 'return false', "RulerCamera", "on a phone the citizen sits in the top 40 %", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if Vector3.new(moved.X, 0, moved.Z).Magnitude > Def.FOLLOW_STUDS then', 'if false then', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if talking.age > Def.FOLLOW_WINDOW_SEC then', 'if false then', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\tself._talking = nil -- the one turn: after it, the camera holds\n', '', "RulerCamera", "one turn followed, never a released citizen", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\t\tself._glide = nil -- a glide left from a conversation that ended in walk mode never replays\n', '', "RulerCamera", "leaves no glide to replay in the overview", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '\t\tminZoom = math.min(minZoom, conversation.zoom)\n', '\t\tlocal _ = conversation\n', "RulerCamera", "zooming in during a conversation never moves the camera out", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then', 'if type(value) ~= "number" then', "RulerCamera", "zooming in during a conversation never moves the camera out", "game"),
]
