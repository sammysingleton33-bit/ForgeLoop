"""FL-0092 mutation rows, run by ../mutations.py (FL-0092 only: `mutations.py FL-0092`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0092 here only (D-038 (7)).
"""
M = [
 ("FL-0092", G+"src/server/Services/PacingService.luau", 'if minutes < Def.MATCH30_MINUTES.min or minutes > Def.MATCH30_MINUTES.max then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0092", G+"src/server/Services/PacingService.luau", 'out[phase] = durations[phase] -- nil unless', 'out[phase] = nil -- nil unless', "PacingService", "match30 is the", "game"),
 ("FL-0092", G+"src/server/Services/PacingService.luau", 'elseif table.find(Def.LATER_PHASES, key) and not seconds(value) then', 'elseif false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'trigger = { client = "CitizenInspected" }', 'trigger = { client = "CitizenAnswered" }', "Onboarding", "a client action completes only the current step", "game"),
 ("FL-0092", C2+"InputModeController.luau", '				onboarding:report("CitizenInspected")', '				local _ = onboarding', "InputMode", "reports CitizenInspected", "game"),
 ("FL-0092", X+"Onboarding.luau", 'elseif state.unavailable and state.unavailable[step.id] then', 'elseif false then', "Onboarding", "a step whose service is missing is passed over", "fw"),
 ("FL-0092", X+"Onboarding.luau", 'if type(step.requires) == "string" and not has(step.requires) then', 'if false then', "Onboarding", "a step whose service is missing is passed over", "fw"),
 ("FL-0092", X+"Onboarding.luau", 'if type(step.requires) ~= "string" or not string.match(step.requires, NAME_PATTERN) then', 'if false then', "Onboarding", "a step's `requires` names a service", "fw"),
 ("FL-0092", S+"OnboardingService.luau", 'or (transition.via == "timeout" and step and step.interactive)', 'or false', "Onboarding", "moves on after autoAdvanceSec, logged as passed", "game"),
 ("FL-0092", S+"OnboardingService.luau", 'local passed = transition.via == "unavailable" or', 'local passed =', "Onboarding", "AnswerCitizen is passed over, logged as passed", "game"),
 ("FL-0092", S+"OnboardingService.luau", '			if passed then', '			if true then', "Onboarding", "a real answer is never logged as passed", "game"),
 ("FL-0092", S+"OnboardingService.luau", '	state.unavailable = self._unavailable[flow.id]\n', '', "Onboarding", "AnswerCitizen is passed over", "game"),
 ("FL-0092", G+"config/Onboarding.luau", '					requires = "MilitaryService",\n', '', "Onboarding", "Recruit and Capture are passed over", "game"),
 ("FL-0092", G+"config/Onboarding.luau", '					requires = "ObjectiveService",\n', '', "Onboarding", "Recruit and Capture are passed over", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'nudgeAfterSec = 180,', 'nudgeAfterSec = 60,', "Onboarding", "Recruit and Capture are passed over", "game"),
 ("FL-0092", G+"config/Onboarding.luau", '					requires = "ConversationService",\n', '', "Onboarding", "AnswerCitizen is passed over", "game"),
 ("FL-0092", G+"config/Onboarding.luau", '					autoAdvanceSec = 120,\n', '', "Onboarding", "moves on after autoAdvanceSec, logged as passed", "game"),
 ("FL-0092", G+"src/server/Services/PacingService.luau", 'elseif table.find(Def.LATER_PHASES, key) and not Def.LATER_PHASE_MODES[mode] then', 'elseif false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0092", C+"OnboardingController.luau", '	if state.clientAction ~= action then\n		return false -- the server would ignore it', '	if false then\n		return false -- the server would ignore it', "OnboardingController", "UI code reports actions through report()", "fw"),
 ("FL-0092", S+"OnboardingService.luau", 'if not isPlayer(player) or player.Parent == nil then', 'if not isPlayer(player) then', "Onboarding", "a start event for a player who already left keeps no state", "fw"),
 ("FL-0092", G+"config/Onboarding.luau", 'target = { kind = "world", tag = "BuildSlot" }, -- Build.PlaceSlot', 'target = { kind = "ui", name = "HUD.BuildButton" }, -- Build.PlaceSlot', "Onboarding", "client-reported steps grant nothing and are whitelisted", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'name = "HUD.ArmyButton" }', 'name = "HUD.Recruit" }', "Onboarding", "client-reported steps grant nothing and are whitelisted", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'target = { kind = "world", tag = "BuildSlot" }', 'target = { kind = "world", tag = "BuildSlot", position = Vector3.zero }', "OnboardingTargets", "world hints name a checked tag and never a fixed position", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'target = { kind = "world", tag = "ObjectiveZone" }', 'target = { kind = "world", tag = "PlotRoad" }', "OnboardingTargets", "world hints name a checked tag and never a fixed position", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'choose a House, then confirm', 'choose a Farm, then confirm', "OnboardingTargets", "BuildOnPlot: the hint names a House", "game"),
 ("FL-0092", G+"config/Onboarding.luau", 'choose a House, then confirm', 'choose a House or a Farm, then confirm', "OnboardingTargets", "BuildOnPlot: the hint names a House", "game"),
 ("FL-0092", G+"config/Kingdoms.luau", 'startResources = { food = 120, wood = 100,', 'startResources = { food = 120, wood = 10,', "OnboardingTargets", "BuildOnPlot: the hint names a House", "game"),
 ("FL-0092", G+"config/Costs.luau", 'Costs.starting = table.freeze({ food = 120, wood = 100,', 'Costs.starting = table.freeze({ food = 120, wood = 10,', "OnboardingTargets", "BuildOnPlot: the hint names a House", "game"),
 ("FL-0092", G+"src/shared/Kingdom/Layout.luau", 'sim.noBuild = Layout.reservedAreas()', 'sim.noBuild = {}', "OnboardingTargets", "BuildOnPlot: the hint names a House", "game"),
 ("FL-0092", G+"src/shared/Kingdom/Layout.luau", 'entry.x, entry.z = w.cframe.Position.X, w.cframe.Position.Z', 'entry.x, entry.z = WorldLayout.plots.crimson.spawn.Position.X, WorldLayout.plots.crimson.spawn.Position.Z', "OnboardingTargets", "capture: every ObjectiveZone the hint can mark", "game"),
]
