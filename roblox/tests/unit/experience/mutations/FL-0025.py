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
 ("FL-0025", S+"OnboardingService.luau", 'if (flow.startOn or "PlayerReady") == eventName then', 'if eventName == "PlayerReady" then', "Onboarding", "starts on KingdomJoined (not PlayerReady)", "game"),
 ("FL-0025", C+"OnboardingController.luau", 'RemoteLink.send(self._env, "Experience.OnboardingSkip", state.flowId)', 'local _ = state.flowId', "OnboardingController", "Skip tells the server", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if (position - origin).Magnitude >= Def.MOVE_STUDS then', 'if true then', "OnboardingController", "reports RulerMoved after the character walks", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if distance < bestDistance then', 'if best == nil then', "OnboardingController", "marks the nearest tagged world object", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if part and (part.Position - position).Magnitude <= Def.REACH_STUDS then', 'if part then', "OnboardingController", "reports ReachedTarget near", "fw"),
 ("FL-0025", C+"OnboardingController.luau", 'if text == nil or self._settings:get("showHints") == false then', 'if text == nil then', "OnboardingController", "shows idle hints only after the tutorial", "fw"),
 ("FL-0025", X+"Onboarding.luau", 'if type(phase) ~= "string" or type(text) ~= "string" or #text == 0 or #text > 140 then', 'if false then', "Onboarding", "rejects idle hints", "fw"),
 ("FL-0025", G+"src/shared/Feedback/Signals.luau", 'return each(Signals.members(ctx, args[2]), { objectiveId = args[1], kingdom = args[2] })', 'return each(ctx.all(), { objectiveId = args[1], kingdom = args[2] })', "Onboarding", "never credits a rival kingdom", "game"),
]
