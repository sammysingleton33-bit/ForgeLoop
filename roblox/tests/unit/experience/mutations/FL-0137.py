"""FL-0137 mutation rows (full-match tips: tip flows, startMatch, war/siege/raid roles, per-flow
client state), run by ../mutations.py (`mutations.py FL-0137`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0137 here only (D-038 (7)).
"""
O = X + "Onboarding.luau"
SV = S + "OnboardingService.luau"
OC = C + "OnboardingController.luau"
SG = F + "Signals.luau"
CF = G + "config/Onboarding.luau"
FW = "experience/Onboarding.spec"
FC = "experience/OnboardingController"
GS = "experience/Onboarding.spec"
M = [
 # --- engine: tip validation and startMatch (framework)
 ("FL-0137", O, 'if #flow.steps ~= 1 then', 'if false then', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, '\t\t\tif flow.funnel then\n\t\t\t\ttable.insert(problems, `{where}: a tip never logs', '\t\t\tif false then\n\t\t\t\ttable.insert(problems, `{where}: a tip never logs', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, 'if flow.completeReward ~= nil or (type(step) == "table" and step.reward ~= nil) then', 'if flow.completeReward ~= nil then', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, 'if type(hides) ~= "number" or hides <= 0 or hides > Onboarding.TIP_MAX_SEC then', 'if type(hides) ~= "number" or hides <= 0 then', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, 'if type(hides) ~= "number" or hides <= 0 or hides > Onboarding.TIP_MAX_SEC then', 'if type(hides) ~= "number" or hides > Onboarding.TIP_MAX_SEC then', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, 'if type(trigger) == "table" and trigger.auto then', 'if false then', FW, "accepts a tip and rejects one", "fw"),
 ("FL-0137", O, 'okMatch = okMatch and type(key) == "string" and PRIMITIVE[type(value)] == true', 'okMatch = okMatch and PRIMITIVE[type(value)] == true', FW, "rejects a startMatch that is not names", "fw"),
 ("FL-0137", O, 'okMatch = okMatch and type(key) == "string" and PRIMITIVE[type(value)] == true', 'okMatch = okMatch and type(key) == "string"', FW, "rejects a startMatch that is not names", "fw"),
 ("FL-0137", O, 'local okMatch = type(flow.startMatch) == "table"', 'local okMatch = flow.startMatch ~= nil', FW, "rejects a startMatch that is not names", "fw"),
 ("FL-0137", O, 'if type(info) ~= "table" or info[key] ~= expected then', 'if type(info) == "table" and info[key] ~= expected then', FW, "startMatches: every startMatch key", "fw"),
 ("FL-0137", O, 'tip = flow.tip == true, --', 'tip = false, --', FW, "startMatches: every startMatch key", "fw"),
 # --- service: start filter, no tutorial analytics for tips, unstarted flows
 ("FL-0137", SV, 'eventName and Onboarding.startMatches(flow, subject.info) then', 'eventName then', FW, "a tip starts only on a start event that fits startMatch", "fw"),
 ("FL-0137", SV, 'if state.finishedAt ~= nil and not state.reportedFinish and flow.tip then', 'if false then', FW, "a tip starts only on a start event that fits startMatch", "fw"),
 ("FL-0137", SV, 'if not flow.tip then -- a dismissed tip is not a skipped tutorial', 'if true then -- a dismissed tip is not a skipped tutorial', FW, "dismissing a tip (Skip) logs no OnboardingSkipped", "fw"),
 ("FL-0137", SV, 'if states == nil or flow == nil or states[flowId] == nil then', 'if states == nil or flow == nil then', FW, "a tip starts only on a start event that fits startMatch", "fw"),
 # --- client: per-flow tips, tutorial first, Got it, hints off
 ("FL-0137", OC, 'if state.tip == true then\n\t\tself:_applyTip(state)\n\t\treturn\n\tend', 'if false then\n\t\tself:_applyTip(state)\n\t\treturn\n\tend', FC, "a tip shows over an unfinished tutorial step", "fw"),
 ("FL-0137", OC, '\tif self._settings:get("showHints") == false then\n\t\treturn nil', '\tif false then\n\t\treturn nil', FC, "no tip shows while showHints is off", "fw"),
 ("FL-0137", OC, 'local tutorial = tip == nil and self:_tutorialShowing()', 'local tutorial = self:_tutorialShowing()', FC, "a tip shows over an unfinished tutorial step", "fw"),
 ("FL-0137", OC, 'local state = if tip then tip elseif tutorial then self.state else nil', 'local state = if tutorial then self.state else nil', FC, "a tip shows over an unfinished tutorial step", "fw"),
 ("FL-0137", OC, 'local id = self._tipOrder[#self._tipOrder]', 'local id = self._tipOrder[1]', FC, "the newest tip shows", "fw"),
 ("FL-0137", OC, 'if state.done or state.hint == nil then\n\t\tself._tips[id] = nil', 'if state.hint == nil then\n\t\tself._tips[id] = nil', FC, "the newest tip shows", "fw"),
 ("FL-0137", OC, 'view.skip.Text = if tutorial then "Skip tutorial" else "Got it"', 'view.skip.Text = "Skip tutorial"', FC, "a tip shows over an unfinished tutorial step", "fw"),
 ("FL-0137", OC, 'view.counter.Text = if tutorial then `{state.step}/{state.total}` else ""', 'view.counter.Text = `{state.step}/{state.total}`', FC, "a tip shows over an unfinished tutorial step", "fw"),
 ("FL-0137", OC, 'RemoteLink.send(self._env, "Experience.OnboardingSkip", tip.flowId)', 'local _ = tip.flowId', FC, "Got it dismisses the tip on the server", "fw"),
 ("FL-0137", OC, '\tif self.tip ~= nil then\n\t\tself:dismissTip()\n\telse\n\t\tself:skip()\n\tend', '\tself:skip()', FC, "Got it dismisses the tip on the server", "fw"),
 ("FL-0137", OC, 'if (self.state and not self.state.done) or self.tip ~= nil then', 'if self.state and not self.state.done then', FC, "a tip shows over an unfinished tutorial step", "fw"),
 # --- game: Signals roles
 ("FL-0137", SG, '\t\treturn "declarer", "target"', '\t\treturn "target", "declarer"', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, '\treturn "acceptor", "proposer"', '\treturn "proposer", "acceptor"', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, 'if type(attacker) == "string" and not seen[attacker] then', 'if type(attacker) == "string" then', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, 'local seen = { [kingdomId] = true }', 'local seen = {}', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, 'if type(first) ~= "string" or type(other) ~= "string" then', 'if type(first) ~= "string" then', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, 'local kingdomId, on, details = args[1], args[2] == true, args[3]', 'local kingdomId, on, details = args[1], args[2], args[3]', GS, "Signals: war, siege and raid roles", "game"),
 ("FL-0137", SG, '\tSiegeChanged = warWatch,\n', '', GS, "a siege shows the siege tip to the defenders", "game"),
 # --- game: the tips themselves
 ("FL-0137", CF, 'match = { role = "target", atWar = true },', 'match = { atWar = true },', GS, "a war declared on me shows the war tip to the target only", "game"),
 ("FL-0137", CF, '}, { event = "WarChanged", match = { role = "declarer", atWar = true } }, {', '}, { event = "WarChanged", match = { atWar = true } }, {', GS, "a war declared on me shows the war tip to the target only", "game"),
 ("FL-0137", CF, '}, { event = "SiegeChanged", match = { role = "defender", on = false } }, {', '}, { event = "SiegeChanged", match = { role = "defender" } }, {', GS, "a siege shows the siege tip to the defenders", "game"),
 ("FL-0137", CF, 'match = { role = "attacker", on = true },', 'match = { on = true },', GS, "a siege shows the siege tip to the defenders", "game"),
 ("FL-0137", CF, '}, "MilitaryService"),', '}),', GS, "without FORGE-01's military the ram tip is passed over", "game"),
 ("FL-0137", CF, 'local TIP_SEC = 12', 'local TIP_SEC = 30', GS, "six full-match tips", "game"),
 ("FL-0137", CF, '\t\ttip = true,\n', '\n', GS, "six full-match tips", "game"),
]
