"""FL-0091 mutation rows, run by ../mutations.py (FL-0091 only: `mutations.py FL-0091`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0091 here only (D-038 (7)).
"""
M = [
 ("FL-0091", F+"Bubbles.luau", 'if current ~= nil and current.kind == "reaction" then', 'if false then', "CitizenBubbles", "a reaction replaces the thought", "game"),
 ("FL-0091", F+"Bubbles.luau", 'local text = cut(data.text, self._config.maxChars)\n	if text == nil then\n		self.stats.ignored += 1\n		return nil\n	end\n	local current', 'local text = cut(data.text, self._config.maxChars) or "…"\n	local current', "CitizenBubbles", "uses only the event's text", "game"),
 ("FL-0091", F+"Bubbles.luau", 'if distance <= config.maxDistance then', 'if true then', "CitizenBubbles", "beyond maxDistance is never picked", "game"),
 ("FL-0091", F+"Bubbles.luau", 'for index = 1, math.min(#candidates, config.maxOnScreen) do', 'for index = 1, #candidates do', "CitizenBubbles", "pick(): within maxDistance", "game"),
 ("FL-0091", F+"Bubbles.luau", 'return a.priority > b.priority', 'return a.priority < b.priority', "CitizenBubbles", "reactions first, then nearest", "game"),
 ("FL-0091", F+"Bubbles.luau", '	self._bubbles[entityId] = nil\n	self._striking[entityId] = nil\nend', '	self._bubbles[entityId] = nil\nend', "CitizenBubbles", "release() clears the bubble and the placard", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '	self:_undraw(entityId)\n	self._models[entityId] = nil', '	self._models[entityId] = nil', "CitizenBubbles", "released rigs lose their bubble", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'if bubble ~= nil and not (bubble.kind == "reaction" and self:_barksOff()) then', 'if bubble ~= nil then', "CitizenBubbles", "citizenBarks off hides reactions", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'gui.Active = false', 'gui.Active = true', "CitizenBubbles", "draws a thought over the citizen", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'elseif self._config.cues and self._config.cues[cue] then', 'elseif false then', "CitizenBubbles", "plays a G13.3 cue's pose", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '	self:_pose(entityId, spec.pose)\n', '', "CitizenBubbles", "plays a G13.3 cue's pose", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'self:_pose(entityId, if fallback then Bubbles.POSE[fallback :: string] else nil)', 'self:_pose(entityId, nil)', "CitizenBubbles", "an unknown cue falls back to the reaction tone", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'elseif current and current.kind == "reaction" then current.tone', 'elseif false then nil', "CitizenBubbles", "an unknown cue falls back to the reaction tone", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'payload.cue or payload.cueId', 'payload.cue', "CitizenBubbles", "plays a G13.3 cue's pose", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'if camera ~= nil and camera.getFocus ~= nil then', 'if false then', "CitizenBubbles", "measures distance from the camera focus", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'gui.MaxDistance = 0', 'gui.MaxDistance = 160', "CitizenBubbles", "draws at most maxOnScreen bubbles", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'if self.bubbles:get(id) ~= nil and model.Parent ~= nil then', 'if self.bubbles:get(id) ~= nil then', "CitizenBubbles", "LOD-hidden (unparented) rigs never take a bubble slot", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '				self._leaving[id] = nil -- a rig swap: the citizen stays\n', '', "CitizenBubbles", "a job change swaps the rig", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '	self.bubbles:strike(entityId, false) -- a new job is a new occupation, so off strike\n', '', "CitizenBubbles", "a job change swaps the rig", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '		self.bubbles:release(id) -- released and not rendered again: the citizen is gone\n', '', "CitizenBubbles", "a job change swaps the rig", "game"),
 ("FL-0091", C2+"CitizenBubbleController.luau", 'return type(value) == "number" and value == value', 'return type(value) == "number"', "CitizenBubbles", "a NaN entity id from the event signal is ignored", "game"),
 ("FL-0091", F+"Bubbles.luau", 'return type(value) == "number" and value == value', 'return type(value) == "number"', "CitizenBubbles", "a NaN entity id is ignored", "game"),
 ("FL-0091", C+"VFXController.luau", '			elseif host ~= nil then', '			elseif false then', "Vfx", "puts an effect on a Model into an owned Attachment", "fw"),
 ("FL-0091", C+"VFXController.luau", '		if ok and direct then\n			return parent, true', '		if false then\n			return parent, true', "Vfx", "uses a BasePart or Attachment parent as is", "fw"),
 ("FL-0091", C2+"CitizenBubbleController.luau", '	if position == nil then\n		return -- no rendered rig', '	if false then\n		return -- no rendered rig', "CitizenBubbles", "a cue for a citizen with no rendered rig", "game"),
]
