"""FL-0100 mutation rows, run by ../mutations.py (FL-0100 only: `mutations.py FL-0100`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0100 here only (D-038 (7)).
"""
M = [
 ("FL-0100", C2+"RulerCameraController.luau", 'if self:_reducedMotion() or duration <= 0 or shown == nil then', 'if duration <= 0 or shown == nil then', "RulerCamera", "reduced motion cuts to the conversation view", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '	if self._saved == nil then\n		self._saved = {', '	if true then\n		self._saved = {', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'shown.focus = glide.from.focus:Lerp(glide.to.focus, k)', 'shown.focus = glide.to.focus', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '		self._glide = nil -- a pan or a "go to" ends a conversation glide\n', '', "RulerCamera", "a pan ends a glide", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'local focus = Def.clampFocus(position + Def.panVector(conversation.offset, yaw), bounds, margin)', 'local focus = Def.clampFocus(position, bounds, margin)', "RulerCamera", "conversationView() frames the citizen above the centre", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if typeof(position) ~= "Vector3" or self.mode ~= "overview" or self._target.focus == nil then', 'if typeof(position) ~= "Vector3" or self._target.focus == nil then', "RulerCamera", "walk mode ignores it", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '			self:focusOn(position, {})', '			local _ = position', "RulerCamera", "follows ConversationController.opened / closed", "game"),
 ("FL-0100", F+"ReactionPoses.luau", 'local weight = math.min(smooth(t / ReactionPoses.EASE_IN), smooth((duration - t) / ReactionPoses.EASE_OUT))', 'local weight = 1', "ReactionPoses", "eases in, and moves in between", "game"),
 ("FL-0100", F+"ReactionPoses.luau", 'out.LeftArm = rz(-(132 + 10 * wave))', 'out.LeftArm = rz(-(152 + 10 * wave))', "ReactionPoses", "every pose stays within Sim/Pose limits", "game"),
 ("FL-0100", F+"ReactionPoses.luau", 'or Bubbles.POSE.neutral', 'or "cheer"', "ReactionPoses", "tones map to Bubbles.POSE", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", 'local held = self:_reducedMotion()', 'local held = false', "ReactionPoses", "reduced motion holds the key pose", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", '\t\tif not entry.held then\n', '\t\tif true then\n', "ReactionPoses", "reduced motion holds the key pose", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", 'local model = portrait or (conversation and conversation.portrait)', 'local model = conversation and conversation.portrait', "ReactionPoses", "follows the conversation", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", '\t\t\t\t\tself:stopPortrait(model)\n', '\t\t\t\t\tlocal _ = model\n', "ReactionPoses", "follows the conversation", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", '\tself:_apply(portrait, ReactionPoses.rest(self._joints))\n', '', "ReactionPoses", "plays a tone's pose on the portrait, frame by frame, then rests", "game"),
 ("FL-0100", C2+"FeedbackPoseController.luau", 'if not self._warned then', 'if true then', "ReactionPoses", "warns once", "game"),
]
