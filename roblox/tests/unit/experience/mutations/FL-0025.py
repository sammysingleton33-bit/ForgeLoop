"""FL-0025 mutation rows, run by ../mutations.py (FL-0025 only: `mutations.py FL-0025`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0025 here only (D-038 (7)).
"""
M = [
 ("FL-0025", X+"Onboarding.luau", 'if step.trigger.client == trigger.client then', 'if true then', "Onboarding", "client actions only complete the current step", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if step.reward and not trigger.bus then', 'if false then', "Onboarding", "rejects rewards on client-triggered steps", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'elseif limits.firstInteractionSec and firstInteraction > limits.firstInteractionSec then', 'elseif false then', "Onboarding", "first interaction comes too late", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if future.trigger.bus and not state.satisfied[future.id] and busMatches(future, trigger) then', 'if false then', "Onboarding", "a later bus step done early", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'if flow == nil or not Onboarding.skip(flow, state, self._env.now()) then', 'if flow == nil then', "Onboarding", "skipping logs OnboardingSkipped", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'section.flows[flow.id] = Onboarding.persisted(state)', 'section.flows[flow.id] = nil', "Onboarding", "persists progress and resumes", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'if (flow.startOn or "PlayerReady") == eventName and Onboarding', 'if eventName == "PlayerReady" and Onboarding', "Onboarding", "starts on KingdomJoined (not PlayerReady)", "game"),
 ("FL-0025", C+"OnboardingController.luau", 'RemoteLink.send(self._env, "Experience.OnboardingSkip", state.flowId)', 'local _ = state.flowId', "OnboardingController", "Skip tells the server", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if (position - origin).Magnitude >= Def.MOVE_STUDS then', 'if true then', "OnboardingController", "reports RulerMoved after the character walks", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if distance < bestDistance then', 'if best == nil then', "OnboardingController", "marks the nearest tagged world object", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if part and (part.Position - position).Magnitude <= Def.REACH_STUDS then', 'if part then', "OnboardingController", "reports ReachedTarget near", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if text == nil or self._settings:get("showHints") == false then', 'if text == nil then', "OnboardingController", "shows idle hints only after the tutorial", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if type(phase) ~= "string" or type(text) ~= "string" or #text == 0 or #text > 140 then', 'if false then', "Onboarding", "rejects idle hints", "fw"),
 ("FL-0025", G+"src/shared/Feedback/Signals.luau", 'return each(Signals.members(ctx, args[2]), { objectiveId = args[1], kingdom = args[2] })', 'return each(ctx.all(), { objectiveId = args[1], kingdom = args[2] })', "Onboarding", "never credits a rival kingdom", "game"),
 ("FL-0025", X+"Subjects.luau", 'local covered = Subjects.DEFAULTS[name] ~= nil or', 'local covered = true or', "AnalyticsSchema", "names the events neither the defaults nor the game", "fw"),
 ("FL-0025", S+"OnboardingService.luau", '	if #problems == 0 then\n		for _, name in Subjects.missing(Onboarding.events(config), subjects) do', '	if false then\n		for _, name in Subjects.missing(Onboarding.events(config), subjects) do', "Onboarding", "a config listening to an event that no resolver covers is invalid", "fw"),
 ("FL-0025", X+"Onboarding.luau", '		add(flow.startOn or "PlayerReady")\n', '', "Onboarding", "a config listening to an event that no resolver covers is invalid", "fw"),
 ("FL-0025", X+"Onboarding.luau", '\tif PAID_VIA[via] then\n\t\tstate.earned = true\n\tend\n', '', "Onboarding", "a flow pays its completeReward only if", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if state.finishedAt == nil or state.earned ~= true then', 'if state.finishedAt == nil then', "Onboarding", "a flow pays its completeReward only if", "fw"),
 ("FL-0025", X+"Onboarding.luau", '\t\tearned = state.earned == true,\n', '', "Onboarding", "a flow pays its completeReward only if", "fw"),
 ("FL-0025", X+"Onboarding.luau", '\t\t\tearned = stored.earned == true,\n', '\t\t\tearned = false,\n', "Onboarding", "a flow pays its completeReward only if", "fw"),
 ("FL-0025", S+"OnboardingService.luau", 'local reward = Onboarding.completionReward(flow, state)', 'local reward = flow.completeReward', "Onboarding", "every server step passed over pays no completeReward", "fw"),
 # D-059: the card docks at the bottom for the start-frame steps (hint.dock); a short screen gets the compact card
 ("FL-0025", C+"OnboardingController.luau", 'self._dock = if state.hint.dock == "bottom" then "bottom" else "top"', 'self._dock = "top"', "OnboardingController", "docks the card at the bottom centre", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'self._dock = if state.hint.dock == "bottom" then "bottom" else "top"', 'self._dock = self._dock', "OnboardingController", "docks the card at the bottom centre", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'view.card.Position = UDim2.new(0.5, 0, 1, -Def.CARD_BOTTOM)\n\t\tself:_reserve(nil)', 'view.card.Position = UDim2.new(0.5, 0, 1, -Def.CARD_BOTTOM)\n\t\tself:_reserve(Def.CARD_RESERVE)', "OnboardingController", "docks the card at the bottom centre", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'Def.CARD_BOTTOM = 16', 'Def.CARD_BOTTOM = 72', "OnboardingController", "docks the card at the bottom centre", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'local short = tall ~= nil and tall <= Def.SHORT_SCREEN', 'local short = false', "OnboardingController", "compacts the card on a short screen", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'local short = tall ~= nil and tall <= Def.SHORT_SCREEN', 'local short = tall ~= nil', "OnboardingController", "compacts the card on a short screen", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'view.counter.Visible = not short', 'view.counter.Visible = true', "OnboardingController", "compacts the card on a short screen", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'view.body.TextWrapped = not short', 'view.body.TextWrapped = true', "OnboardingController", "compacts the card on a short screen", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'self:_reserve(Def.CARD_TOP + height + 8)', 'self:_reserve(Def.CARD_RESERVE)', "OnboardingController", "compacts the card on a short screen", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if dock ~= nil and dock ~= "top" and dock ~= "bottom" then', 'if false then', "Onboarding", "accepts hint.dock top or bottom", "fw"),
 ("FL-0025", G+"config/Onboarding.luau", 'body = "Their card shows their job, mood and loyalty.",\n\t\t\t\t\t\tdock = "bottom",', 'body = "Their card shows their job, mood and loyalty.",', "Onboarding", "docks the card at the bottom for the start-frame steps only", "game"),
]
