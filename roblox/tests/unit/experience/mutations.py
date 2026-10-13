"""Mutation check for FORGE-04 specs: proves each named spec can fail.

Each row breaks one rule in the source, runs the matching Lune specs, expects the named test to
fail, and restores the file (also on error). Run from anywhere:
    python3 roblox/tests/unit/experience/mutations.py            # all rows
    python3 roblox/tests/unit/experience/mutations.py FL-0025    # one task
Prints one line per row: CAUGHT / NOT CAUGHT / MUTATION NOT APPLIED. Needs lune on PATH.
"""
import subprocess, sys, re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[4]  # repository root
S = "roblox/src/server/Services/"; C = "roblox/src/client/Controllers/"; X = "roblox/src/shared/Experience/"
G = "games/game-001/"; C2 = G + "src/client/Controllers/"; F = G + "src/shared/Feedback/"
RUN = {
    "fw": ["lune", "run", "roblox/tests/harness/run.luau"],
    "game": ["lune", "run", "roblox/tests/harness/run.luau", "--project", "games/game-001/default.project.json", "--specs", "games/game-001/tests"],
}
M = [
 # (task, file, old, new, spec filter, expected failing test, project) -- project "game" runs games/game-001/tests
 ("FL-0023", S+"AnalyticsService.luau", 'local floor = if kind == "event" then self._capacity * self._limits.customReserve else 0', 'local floor = 0', "AnalyticsService", "keeps a reserve for funnels", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if decl.kind == "recurring" and (type(sessionId) ~= "string" or sessionId == "") then', 'if false then', "AnalyticsService", "drops recurring funnel steps without a sessionId", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'local ok, err = pcall(service[method], service, ...)', 'local ok, err = true, service[method](service, ...)', "AnalyticsService", "never throws when Roblox errors", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'out[AnalyticsSchema.FIELD_KEYS[index]] = text', 'out[AnalyticsSchema.FIELD_KEYS[4 - index]] = text', "AnalyticsService", "maps the value field and CustomField01-03", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if state.tokens < 1 then', 'if false then', "AnalyticsService", "caps one player at perPlayerPerMinute", "fw"),
 ("FL-0023", X+"AnalyticsSchema.luau", 'if #fields > AnalyticsSchema.CAPS.customFields then', 'if false then', "AnalyticsSchema", "rejects more than 3 custom fields", "fw"),
 ("FL-0023", X+"Subjects.luau", 'local ok, result = pcall(resolver, args, ctx)', 'local ok, result = true, resolver(args, ctx)', "AnalyticsService", "isolates a resolver that errors", "fw"),
 ("FL-0023", X+"Subjects.luau", 'table.insert(out, { player = subject.player, info = Subjects.primitives(subject.info) })', 'table.insert(out, { player = subject.player, info = subject.info })', "AnalyticsSchema", "a game resolver wins over the default and its info is filtered too", "fw"),
 ("FL-0024", X+"Schema.luau", 'local step = migrations[fromVersion]', 'local step = migrations[fromVersion + 1] or migrations[fromVersion]', "Settings", "migrates step by step", "fw"),
 ("FL-0024", S+"SettingsService.luau", 'if section == "settings" or not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', 'if not table.find(Schema.SECTIONS, section) or not isPlayer(player) then', "Settings", "update(section) changes only that section", "fw"),
 ("FL-0024", S+"SettingsService.luau", 'if last and now - last < ANALYTICS_GAP then', 'if false then', "Settings", "reports SettingChanged at most once per key", "fw"),
 ("FL-0024", S+"SettingsService.luau", '	local ok = pcall(fn, copy)\n	if not ok then\n		return false\n	end\n	self._session[player] = copy', '	local ok = pcall(fn, copy)\n	self._session[player] = copy\n	if not ok then\n		return false\n	end', "Settings", "same no-partial-write and validation rules", "fw"),
 ("FL-0024", X+"SoundRegistry.luau", 'if not nonEmpty(entry.licence) then', 'if false then', "Audio", "rejects entries without licence", "fw"),
 ("FL-0024", C+"AudioController.luau", 'Def.BUDGET = table.freeze({ voices = 8, music = 1, ambience = 2 })', 'Def.BUDGET = table.freeze({ voices = 9, music = 1, ambience = 2 })', "Audio", "keeps at most 8 voices", "fw"),
 ("FL-0024", C+"AudioController.luau", 'if self:_countOf(soundId) >= (entry.maxInstances or 2) then', 'if false then', "Audio", "enforces cooldown and maxInstances", "fw"),
 ("FL-0024", C+"AudioController.luau", 'if self._backend.available and not self._backend.available() then', 'if false then', "Audio", "skips sounds cleanly when there is no SoundService", "fw"),
 ("FL-0024", X+"VfxPresets.luau", 'if live > B.particlesPerPreset then', 'if false then', "Vfx", "rejects presets over budget", "fw"),
 ("FL-0024", X+"VfxPresets.luau", 'if type(preset) == "table" and type(preset.id) == "string" and byId[preset.id] ~= nil then', 'if false then', "Vfx", "register() rejects invalid lists and duplicate ids", "fw"),
 ("FL-0024", C+"VFXController.luau", 'local scale = if reduced and preset.reducedMotion == "reduce" then 0.5 else 1', 'local scale = 1', "Vfx", "reduced motion halves", "fw"),
 ("FL-0024", C+"VFXController.luau", 'if victim == nil then\n\t\t\treturn false', 'if victim == nil then\n\t\t\treturn true', "Vfx", "keeps live particles on screen within budget", "fw"),
 ("FL-0024", X+"CueDirector.luau", 'if variant.sound and not (variant.vfx or variant.notify or variant.float or variant.react) then', 'if false then', "Feedback", "the validator catches a sound-only cue", "fw"),
 ("FL-0024", X+"CueDirector.luau", 'local first = repeatCount == 1', 'local first = true', "Feedback", "coalesces repeats", "fw"),
 ("FL-0024", X+"MusicDirector.luau", 'if not leavingUrgent and now - self._since < self._minDwell then', 'if false then', "Feedback", "only after the minimum dwell time", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if step.trigger.client == trigger.client then', 'if true then', "Onboarding", "client actions only complete the current step", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if step.reward and not trigger.bus then', 'if false then', "Onboarding", "rejects rewards on client-triggered steps", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'elseif limits.firstInteractionSec and firstInteraction > limits.firstInteractionSec then', 'elseif false then', "Onboarding", "first interaction comes too late", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if future.trigger.bus and not state.satisfied[future.id] and busMatches(future, trigger) then', 'if false then', "Onboarding", "a later bus step done early", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'if flow == nil or not Onboarding.skip(flow, state, self._env.now()) then', 'if flow == nil then', "Onboarding", "skipping logs OnboardingSkipped", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'section.flows[flow.id] = Onboarding.persisted(state)', 'section.flows[flow.id] = nil', "Onboarding", "persists progress and resumes", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'if (flow.startOn or "PlayerReady") == eventName then', 'if eventName == "PlayerReady" then', "Onboarding", "starts on KingdomJoined (not PlayerReady)", "game"),
 ("FL-0025", C+"OnboardingController.luau", 'RemoteLink.send(self._env, "Experience.OnboardingSkip", state.flowId)', 'local _ = state.flowId', "OnboardingController", "Skip tells the server", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if (position - origin).Magnitude >= Def.MOVE_STUDS then', 'if true then', "OnboardingController", "reports RulerMoved after the character walks", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if distance < bestDistance then', 'if best == nil then', "OnboardingController", "marks the nearest tagged world object", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if part and (part.Position - position).Magnitude <= Def.REACH_STUDS then', 'if part then', "OnboardingController", "reports ReachedTarget near", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if text == nil or self._settings:get("showHints") == false then', 'if text == nil then', "OnboardingController", "shows idle hints only after the tutorial", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if type(phase) ~= "string" or type(text) ~= "string" or #text == 0 or #text > 140 then', 'if false then', "Onboarding", "rejects idle hints", "fw"),
 ("FL-0025", G+"src/shared/Feedback/Signals.luau", 'return each(Signals.members(ctx, args[2]), { objectiveId = args[1], kingdom = args[2] })', 'return each(ctx.all(), { objectiveId = args[1], kingdom = args[2] })', "Onboarding", "never credits a rival kingdom", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if slice.Lobby ~= 0 then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if minutes < limits.matchMinMinutes or minutes > limits.matchMaxMinutes then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", '		config = Def.DEFAULTS\n', '', "PacingService", "an invalid config never breaks the match", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if durations == nil or not table.find(Def.MODES, mode) then', 'if false then', "PacingService", "rejects an unknown mode", "game"),
 ("FL-0024", G+"config/Sounds.luau", 'id = "music.tension"', 'id = "music.tense"', "Sounds", "registers a track for every music state", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'if self._firing then', 'if false then', "InputMode", "applies a set() made inside a changed handler", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'return self.mode == mode and self._env.clock() - self._changedAt >= self._config.settleSec', 'return self.mode == mode', "InputMode", "accepts() gives a tap", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'self:_bindLeave(nextMode == "build")', 'self:_bindLeave(true)', "InputMode", "binds X / gamepad B only while in build mode", "game"),
 ("FL-0053", C2+"InputModeController.luau", 'if not table.find(Def.MODES, mode) then', 'if mode == nil then', "InputMode", "refuses unknown modes", "game"),
 ("FL-0053", C2+"RulerController.luau", 'return { held = state.held, toggled = toggled }, moving and (state.held or toggled)', 'return { held = state.held, toggled = toggled }, state.held or toggled', "Ruler", "standing still never sprints", "game"),
 ("FL-0053", C2+"RulerController.luau", 'local toggled = state.toggled and moving', 'local toggled = state.toggled', "Ruler", "the toggle ends when the ruler stops", "game"),
 ("FL-0053", C2+"RulerController.luau", 'return math.min(current + step, target)', 'return current + step', "Ruler", "never overshoots", "game"),
 ("FL-0053", C2+"RulerController.luau", 'humanoid.AutoRotate = false', 'humanoid.AutoRotate = true', "Ruler", "smooth turning: AutoRotate off", "game"),
 ("FL-0053", C2+"RulerController.luau", '	if self._input ~= nil then\n		self._input:set("explore")\n	end\n	if character == nil then', '	if character == nil then', "Ruler", "respawn, removal and death return input to explore", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'elseif previous == "build" and self._autoFrom ~= nil then', 'elseif false then', "RulerCamera", "build mode uses the overview", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'self._autoFrom = nil -- the player chose', '-- removed', "RulerCamera", "build mode uses the overview", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'if reduced or settings:get("cameraShake") == false then', 'if false then', "RulerCamera", "never shakes when camera shake is off", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'local alpha = 1 - math.exp(-rate * dt)', 'local alpha = math.min(1, rate * dt)', "RulerCamera", "frame-rate independent", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'camera.CFrame = self._blendFrom:Lerp(goal, Def.ease(self._blendT))', 'camera.CFrame = goal', "RulerCamera", "returning to the overview blends", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'self._target.zoom = Def.clamp(self._target.zoom + steps * overview.zoomStep, overview.minZoom, overview.maxZoom)', 'self._target.zoom = self._target.zoom + steps * overview.zoomStep', "RulerCamera", "zoom stays within", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'local ratio = scale / self._pinch', 'local ratio = scale', "RulerCamera", "zoom stays within", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'while #self._shakes > limits.maxActive do', 'while false do', "RulerCamera", "caps the duration and the number of shakes", "game"),
 ("FL-0053", C2+"RulerCameraController.luau", 'return Def.clamp(magnitude, 0, 1) * maxDegrees * left * left', 'return magnitude * maxDegrees * left * left', "RulerCamera", "shakeAmplitude() eases out and clamps", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self._target.focus = Def.clampFocus(position, self._bounds, self._config.overview.boundsMargin)', 'self._target.focus = position', "RulerCamera", "the focus never leaves the map bounds", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if moved.Magnitude < self:_tapPixels() then', 'if false then', "RulerCamera", "left-drag pans the ground", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'type(touches) ~= "table" or #touches ~= 1 then', 'type(touches) ~= "table" or #touches < 1 then', "RulerCamera", "two-finger moves never pan", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:_bindRotateKeys(false) -- Q / R belong', 'self:_bindRotateKeys(true) -- Q / R belong', "RulerCamera", "Q / E rotate in the overview", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'if not far or now - (self._streamedAt :: number) < overview.streamEverySec then', 'if not far then', "RulerCamera", "stream around the focus", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:_setTouchControls(not overview)', 'self:_setTouchControls(true)', "RulerCamera", "starts in the overview over the throne", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", '			self._ruler:standUp()', '			local _ = self._ruler', "RulerCamera", "follow (walk mode) stands the ruler up", "game"),
 ("FL-0090", C2+"RulerCameraController.luau", 'self:panBy(direction * (overview.panSpeed * target.zoom * dt))', 'self:panBy(direction * (overview.panSpeed * dt))', "RulerCamera", "WASD pans relative to the view", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'local ok, entityId = pcall(entities.pick, entities, screenPos)', 'local ok, entityId = false, nil', "InputMode", "a tap on a citizen selects it", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'return (upAt - downAt).Magnitude < config.tapPixels and heldSec <= config.tapSec', 'return true', "InputMode", "a drag (pan) or a long press is not a tap", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'if nextMode == "build" and self.selection.kind ~= "none" then', 'if false then', "InputMode", "build mode clears the selection", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'for _ = 1, 8 do', 'for _ = 1, 20 do', "InputMode", "resolveHit() stops after 8 levels", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'if okId and buildingId ~= nil then', 'if false then', "InputMode", "selects the building through", "game"),
 ("FL-0090", C2+"InputModeController.luau", 'return "slot", if okSlot and slotId ~= nil then slotId else current.Name', 'return "slot", current.Name', "InputMode", "selects the slot through the BuildSlot tag", "game"),
 ("FL-0090", C2+"RulerController.luau", 'if (okSit and sitting) or (okSeat and seatPart ~= nil) then', 'if true then', "Ruler", "standUp() leaves the throne", "game"),
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
 ("FL-0027", X+"NotificationQueue.luau", 'if #self._visible < config.maxVisible then', 'if true then', "Notification", "shows at most 3", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if shown.priority < item.priority and', 'if shown.priority <= item.priority and', "Notification", "shows at most 3", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'item.expiresAt = math.min(refreshed, (item.shownAt :: number) + config.maxRefreshSec)', 'item.expiresAt = refreshed', "Notification", "not past maxRefreshSec", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if self.filter == "important" and not important then', 'if false then', "Notification", "the 'important' filter keeps only", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if #pending >= self._config.maxPending then', 'if false then', "Notification", "keeps at most maxPending waiting", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if item.priority > waiting.priority then', 'if false then', "Notification", "keeps at most maxPending waiting", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if how == "shown" or how == "replaced" then', 'if how ~= "filtered" and how ~= "invalid" then', "Notification", "with a ×N badge", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'local cooling = last ~= nil and now - last.at < (spec.cooldownSec or 1)', 'local cooling = false', "Notification", "coalesces the same celebration", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if cooling and (key == nil or last.keys[key]) then', 'if cooling then', "Notification", "a different moment of the same kind", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'local data = if type(payload) == "table" then payload else nil', 'local data = payload', "Notification", "a payload that is not a table", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'root.stack.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, top)', 'root.stack.Position = Def.POSITION', "Notification", "place() follows the game's layout", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'top = math.max(top, px)', 'local _ = px', "Notification", "place() follows the game's layout", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", ' and spec.durationSec == spec.durationSec -- not NaN', '', "Notification", "a NaN duration gets the kind's default", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'return if #text > limit then string.sub(text, 1, limit) .. "…" else text', 'return text', "Notification", "a NaN duration gets the kind's default", "fw"),
 ("FL-0027", C+"OnboardingController.luau", '	self:_reserve(Def.CARD_RESERVE)\n', '', "OnboardingController", "keeps the toast stack below the card", "fw"),
 ("FL-0027", C+"OnboardingController.luau", '		self:_reserve(nil)\n		return', '		return', "OnboardingController", "keeps the toast stack below the card", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'return if missing then nil else id', 'return id', "Notification", "never asks for the sound id", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'self:_announce(item, spec.silent == true)', 'self:_announce(item, false)', "Notification", "celebration toasts are important", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if spec.sound ~= nil and not hasVisual then', 'if false then', "Notification", "games register celebrations", "fw"),
 ("FL-0027", C+"NotificationController.luau", '				self.queue:setFilter(value)', '				local _ = value', "Notification", "applies the notifications setting live", "fw"),
 ("FL-0027", C+"OnboardingController.luau", 'if wasActive and state.done and not state.skipped then', 'if state.done then', "OnboardingController", "celebrates when the last step completes", "fw"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if self:_reducedMotion() or duration <= 0 or shown == nil then', 'if duration <= 0 or shown == nil then', "RulerCamera", "reduced motion cuts to the conversation view", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '	if self._saved == nil then\n		self._saved = {', '	if true then\n		self._saved = {', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'shown.focus = glide.from.focus:Lerp(glide.to.focus, k)', 'shown.focus = glide.to.focus', "RulerCamera", "glides to the citizen; restore() glides back", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '		self._glide = nil -- a pan or a "go to" ends a conversation glide\n', '', "RulerCamera", "a pan ends a glide", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'local focus = Def.clampFocus(position + Def.panVector(conversation.offset, yaw), bounds, margin)', 'local focus = Def.clampFocus(position, bounds, margin)', "RulerCamera", "conversationView() frames the citizen above the centre", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", 'if typeof(position) ~= "Vector3" or self.mode ~= "overview" or self._target.focus == nil then', 'if typeof(position) ~= "Vector3" or self._target.focus == nil then', "RulerCamera", "walk mode ignores it", "game"),
 ("FL-0100", C2+"RulerCameraController.luau", '			self:focusOn(position, {})', '			local _ = position', "RulerCamera", "follows ConversationController.opened / closed", "game"),
]
only = sys.argv[1] if len(sys.argv) > 1 else None
rows = []
for task, path, old, new, filt, expect, project in M:
    if only and task != only: continue
    f = ROOT / path
    if not f.exists():
        rows.append((task, path, filt, expect, "FILE MISSING")); continue
    src = f.read_text()
    if old not in src:
        rows.append((task, path, filt, expect, "MUTATION NOT APPLIED (text not found)")); continue
    f.write_text(src.replace(old, new, 1))
    try:
        out = subprocess.run(RUN[project] + [filt], cwd=ROOT, capture_output=True, text=True, timeout=300).stdout
    finally:
        f.write_text(src)
    failed = [l.strip() for l in out.splitlines() if l.strip().startswith("x ")]
    hit = any(expect in l for l in failed)
    summary = [l for l in out.splitlines() if l.startswith("Lune tests:")]
    rows.append((task, path.split("/")[-1], filt, expect, ("CAUGHT" if hit else "NOT CAUGHT") + " | " + (summary[0] if summary else "?")))
for r in rows:
    print(" | ".join(r))
