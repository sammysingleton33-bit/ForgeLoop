"""FL-0108 mutation rows, run by ../mutations.py (FL-0108 only: `mutations.py FL-0108`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0108 here only (D-038 (7)).
"""
M = [
 ("FL-0108", G+"config/Onboarding.luau", 'trigger = { bus = "CitizenAnswered" }', 'trigger = { client = "CitizenInspected" }', "Onboarding", "AnswerCitizen follows G9 CitizenAnswered", "game"),
 ("FL-0108", F+"Signals.luau", '\t\treturn { { player = player, info = info } }\n', '\t\treturn {}\n', "Onboarding", "AnswerCitizen follows G9 CitizenAnswered", "game"),
 ("FL-0108", X+"Onboarding.luau", 'step.trigger.bus and step.reward ~= nil then', 'step.trigger.bus then', "Onboarding", "auto-advancing rewarded bus steps", "fw"),
 ("FL-0108", X+"Onboarding.luau", 'reward = if PAID_VIA[via] then step.reward else nil', 'reward = step.reward', "Onboarding", "only the real action pays a reward", "fw"),
 ("FL-0108", X+"Onboarding.luau", 'local PAID_VIA = table.freeze({ bus = true, satisfied = true })', 'local PAID_VIA = table.freeze({ bus = true })', 'Onboarding', 'a rewarded step done early', 'fw'),
 ("FL-0108", F+"Signals.luau", '\t\tif player == nil then\n\t\t\treturn {}\n\t\tend\n\t\tlocal info', '\t\tlocal info', 'Onboarding', 'CitizenAnswered without secondsOpen', 'game'),
 ("FL-0108", F+"Signals.luau", 'decision = if type(args[4]) == "string" then args[4] else nil', 'decision = args[4]', 'Onboarding', 'CitizenAnswered without secondsOpen', 'game'),
 ("FL-0108", F+"Signals.luau", 'secondsOpen = if type(args[5]) == "number" and args[5] == args[5] then args[5] else nil', 'secondsOpen = if type(args[5]) == "number" then args[5] else nil', 'Onboarding', 'CitizenAnswered without secondsOpen', 'game'),
 ("FL-0108", G+"config/Onboarding.luau", 'clientActions = { "GoalAcknowledged", "CitizenInspected" },', 'clientActions = { "GoalAcknowledged", "CitizenInspected", "CitizenAnswered" },', 'Onboarding', 'client-reported steps grant nothing', 'game'),
 ("FL-0108", F+"Signals.luau", 'occupation = occupationOf(ctx, args[3]),', 'occupation = nil,', "MatchAnalytics", "logs ConversationAnswered from G9 CitizenAnswered", "game"),
 ("FL-0108", F+"Signals.luau", 'if ok and type(view) == "table" then view.occupation else nil', 'if ok and type(view) == "table" then view.job else nil', "MatchAnalytics", "logs ConversationAnswered from G9 CitizenAnswered", "game"),
 ("FL-0108", G+"config/Analytics.luau", 'fields = { "secondsOpen", "occupation", "decision" }', 'fields = { "occupation", "decision" }', "MatchAnalytics", "logs ConversationAnswered from G9 CitizenAnswered", "game"),
 ("FL-0108", G+"config/Analytics.luau", 'on = "CitizenAnswered",\n\t\t\tevent = "ConversationAnswered",', 'on = "KingdomJoined",\n\t\t\tevent = "ConversationAnswered",', "ConversationAnalytics", "an accepted answer logs one ConversationAnswered", "game"),
]
