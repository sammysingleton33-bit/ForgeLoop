"""FL-0108 mutation rows, run by ../mutations.py (FL-0108 only: `mutations.py FL-0108`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0108 here only (D-038 (7)).
"""
M = [
 ("FL-0108", G+"config/Onboarding.luau", 'trigger = { bus = "CitizenAnswered" }', 'trigger = { client = "CitizenInspected" }', "Onboarding", "AnswerCitizen follows G9 CitizenAnswered", "game"),
 ("FL-0108", F+"Signals.luau", '\t\treturn { { player = player, info = info } }\n', '\t\treturn {}\n', "Onboarding", "AnswerCitizen follows G9 CitizenAnswered", "game"),
 ("FL-0108", X+"Onboarding.luau", 'step.trigger.bus and step.reward ~= nil then', 'step.trigger.bus then', "Onboarding", "auto-advancing rewarded bus steps", "fw"),
]
