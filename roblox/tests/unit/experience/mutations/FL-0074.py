"""FL-0074 mutation rows, run by ../mutations.py (FL-0074 only: `mutations.py FL-0074`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0074 here only (D-038 (7)).
"""
D = F + "CrowdDirector.luau"
K = G + "config/Crowd.luau"
K2 = C2 + "FeedbackCrowdController.luau"
M = [
 # figures and seats
 ("FL-0074", D, 'return math.min(math.ceil(n / config.citizensPerFigure), config.maxPerStand)', 'return math.ceil(n / config.citizensPerFigure)', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'return if type(value) == "number" and value > 0 then value else 0', 'return if value > 0 then value else 0', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'local trimA = math.min(over, math.max(0, a - b))', 'local trimA = 0', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'return math.floor(figures * tierOf(tier, config).fill + 0.5)', 'return figures', "CrowdDirector", "a lower tier leaves more seats empty", "game"),
 ("FL-0074", D, 'return config.tiers[tier] or config.tiers.divided', 'return config.tiers[tier] or config.tiers.adoring', "CrowdDirector", "an unknown tier counts as divided", "game"),
 # reactions by tier
 ("FL-0074", D, 'self:_reaction(other, if good then theirs.bad else theirs.good, true, priority),', 'self:_reaction(other, if good then theirs.good else theirs.bad, true, priority),', "CrowdDirector", "a big hit", "game"),
 ("FL-0074", D, 'count(data.damageShare) >= config.moments.bigHit', 'count(data.damage) >= config.moments.bigHit', "CrowdDirector", 'a big hit', "game"),
 ("FL-0074", D, 'self:_track(SIDES[side] :: Stand, data.hpShare)', 'self:_track(SIDES[side] :: Stand, data.hp)', "CrowdDirector", 'near-death once per champion', "game"),
 ("FL-0074", K, 'hostile = table.freeze({ fill = 0.5, idle = "boo", good = "silence", bad = "turnBack", chants = false }),', 'hostile = table.freeze({ fill = 0.5, idle = "boo", good = "cheer", bad = "turnBack", chants = false }),', "CrowdDirector", "a hostile stand boos", "game"),
 # rationing and priority
 ("FL-0074", D, 'if now - self._lastMajor < self._config.majorGapSec then', 'if false then', "CrowdDirector", "at most one major reaction every 3 s", "game"),
 ("FL-0074", K, 'majorGapSec = 3,', 'majorGapSec = 2,', "CrowdDirector", "at most one major reaction every 3 s", "game"),
 ("FL-0074", D, 'if now - self._lastMinor[stand] < self._config.minorGapSec then', 'if false then', "CrowdDirector", "small hits are minor", "game"),
 ("FL-0074", D, '\t\tself._lastMajor = now\n\t\tself:duck(now, config.duck.perkSec)', '\t\tself:duck(now, config.duck.perkSec)', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'self:duck(now, config.duck.perkSec)', 'local _ = config.duck.perkSec', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'if trigger == "crowdRally" then "rally" else "perk", true, true, {', '"perk", true, true, {', "CrowdDirector", 'perk moments always win', "game"),
 ("FL-0074", D, 'then (string.gsub(data.source, "^perk:", "")) else nil', 'then nil else nil', "CrowdDirector", 'a triggerFired names its perk', "game"),
 ("FL-0074", D, 'trigger = config.triggerNames[trigger] or "their pledge",', 'trigger = trigger or "their pledge",', "CrowdDirector", 'a triggerFired names its perk', "game"),
 ("FL-0074", D, 'return if type(value) == "string" then value else nil', 'return nil', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'return if now < self._duckUntil then self._config.duck.volume else 1', 'return 1', "CrowdDirector", "perk moments always win", "game"),
 # near-death and comeback
 ("FL-0074", D, 'if not self._nearDeath[target] and self._hp[target] > 0 and self._hp[target] < moments.nearDeath then', 'if self._hp[target] > 0 and self._hp[target] < moments.nearDeath then', "CrowdDirector", "near-death once per champion", "game"),
 ("FL-0074", D, 'if self._trailed[hitter] and self._hp[hitter] > self._hp[target] then', 'if false then', "CrowdDirector", "a comeback when the trailing champion takes the lead", "game"),
 ("FL-0074", D, 'self._trailed[stand] = true', 'local _ = stand', "CrowdDirector", "a comeback when the trailing champion takes the lead", "game"),
 # chants
 ("FL-0074", D, 'if not tierOf(self._sides[side].tier, config).chants then', 'if false then', "CrowdDirector", 'chants for a chanting tier only', "game"),
 ("FL-0074", D, 'line = config.chants.any[1] -- no name to chant', 'local _ = 0 -- no name to chant', "CrowdDirector", "chants for a chanting tier only", "game"),
 # endings
 ("FL-0074", D, 'return if high then "flood" else "thinCrowning"', 'return "flood"', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'return if high then "salute" else "empty"', 'return "salute"', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'if self._ended or (winner ~= nil and SIDES[winner] == nil) then', 'if (winner ~= nil and SIDES[winner] == nil) then', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'if self._ended or type(event) ~= "table" then', 'if type(event) ~= "table" then', "CrowdDirector", "four endings", "game"),
 # input hygiene
 ("FL-0074", D, 'self._duckUntil = math.max(self._duckUntil, now + math.min(seconds, 30))', 'self._duckUntil = math.max(self._duckUntil, now + seconds)', "CrowdDirector", "ignores unknown kinds", "game"),
 # config: sounds and arena timings
 ("FL-0074", G + "config/Sounds.luau", 'id = "crowd.salute",', 'id = "crowd.salutes",', "CrowdDirector", "sounds exist", "game"),
 ("FL-0074", G + "config/Pacing.luau", 'duel = 120,', 'duel = 150,', "CrowdDirector", "arena stage timings in Pacing", "game"),
 # #193 L1 and FORGE-00's draw ruling: a duel with no winner or a draw is called off
 ("FL-0074", D, 'then "calledOff"', 'then "empty"', "CrowdDirector", 'a duel with no winner or a draw is called off', "game"),
 ("FL-0074", D, '(event.side == nil or event.side == "draw")', '(event.side == nil)', "CrowdDirector", 'a duel with no winner or a draw is called off', "game"),
 ("FL-0074", D, '(event.side == nil or event.side == "draw")', '(event.side == "draw")', "CrowdDirector", 'a duel with no winner or a draw is called off', "game"),
 ("FL-0074", D, '(winner ~= nil and SIDES[winner] == nil)', '(SIDES[winner] == nil)', "CrowdDirector", "a duel with no winner or a draw is called off", "game"),
 # part 2a: FeedbackCrowdController (spec CrowdClient)
 ("FL-0074", K2, 'if Def.DUEL_STAGES[stage] and type(a) == "table" and type(b) == "table" then', 'if stage == "duel" and type(a) == "table" and type(b) == "table" then', "CrowdClient", "is made when Arena.State names both duellists at the intro", "game"),
 ("FL-0074", K2, 'if pair ~= self._pair then', 'if true then', "CrowdClient", "a new pair starts a new one", "game"),
 ("FL-0074", K2, 'elseif stage == "done" then', 'elseif false then', "CrowdClient", "a new pair starts a new one", "game"),
 ("FL-0074", K2, 'if type(phase) == "string" and Def.END_PHASES[phase] then', 'if false then', "CrowdClient", "Results and Lobby drop the director", "game"),
 ("FL-0074", K2, 'local volume = if director ~= nil then director:volume(now) else 1', 'local volume = 1', "CrowdClient", "duck the crowd's volume", "game"),
 ("FL-0074", K2, 'director:duck(self._env.clock(), Crowd.duck.announcerSec)', 'local _ = director', "CrowdClient", "duck the crowd's volume", "game"),
 ("FL-0074", K2, 'local text = if name ~= nil then `{name}: {reaction.caption}` else reaction.caption', 'local text = reaction.caption', "CrowdClient", "one line per stand with the kingdom's name", "game"),
 ("FL-0074", K2, 'if current ~= nil and current.priority and not priority and now < current.ends then', 'if false then', "CrowdClient", "a perk's line holds", "game"),
 ("FL-0074", K2, 'if clock >= line.ends then', 'if false then', "CrowdClient", "lines expire", "game"),
 ("FL-0074", K2, 'if type(duellist) == "table" and state.winner ~= nil and duellist.userId == state.winner then', 'if type(duellist) == "table" then', "CrowdClient", "crowning plays the winner's ending once", "game"),
 ("FL-0074", K2, 'if type(duellist) ~= "table" or duellist.isAI == true or type(duellist.userId) ~= "number" then', 'if type(duellist) ~= "table" or type(duellist.userId) ~= "number" then', "CrowdClient", "an AI duellist's stand chants a line without one", "game"),
 ("FL-0074", K2, 'label.RichText = false', 'label.RichText = true', "CrowdClient", "one line per stand with the kingdom's name", "game"),
 ("FL-0074", K2, '\tif not self:_isStudio() then\n\t\treturn false\n\tend\n\tlocal tierA', '\tlocal tierA', "CrowdClient", "never outside Studio", "game"),
 ("FL-0074", K2, '\tlocal tierA, tierB = nil, nil\n\tif type(spec) == "string" then\n\t\ttierA, tierB = string.match(spec, "^%s*(%a+)%s*,%s*(%a+)%s*$")\n\tend', '\tlocal tierA, tierB = if type(spec) == "string" then string.match(spec, "^%s*(%a+)%s*,%s*(%a+)%s*$") else nil', "CrowdClient", "the Studio preview plays the scripted duel", "game"),
 ("FL-0074", K2, '\tif self._pair ~= nil then\n\t\treturn false -- a real duel is never interrupted by the preview\n\tend\n', '', "CrowdClient", "the Studio preview plays the scripted duel", "game"),
 ("FL-0074", K2, 'if self._previewOwned then', 'if false then', "CrowdClient", "the Studio preview plays the scripted duel", "game"),
 # subtitles keep clear of the duel's touch buttons (FORGE-03 on #199)
 ("FL-0074", K2, 'if area ~= nil then -- left of the duel buttons', 'if false then -- left of the duel buttons', "CrowdClient", "left of and above the duel's touch buttons", "game"),
 ("FL-0074", K2, 'label.Position = UDim2.new(0, rule.edge, 1, -bottom - (index - 1) * rule.step)', 'label.Position = UDim2.new(0, rule.edge, 1, -(index - 1) * rule.step)', "CrowdClient", "left of and above the duel's touch buttons", "game"),
 ("FL-0074", K2, 'label.Size = UDim2.new(1, -(area.left + rule.clear + rule.edge), 0, rule.height)', 'label.Size = UDim2.new(1, -area.left, 0, rule.height)', "CrowdClient", "left of and above the duel's touch buttons", "game"),
 ("FL-0074", K2, 'local ok, area = pcall(arena.touchArea, arena)', 'local ok, area = true, arena:touchArea()', "CrowdClient", "left of and above the duel's touch buttons", "game"),
 # two-line boxes, short names, above the thumbstick (FORGE-07's #199 M1)
 ("FL-0074", K2, 'else rule.thumbClear.large', 'else rule.thumbClear.small', "CrowdClient", "left of and above the duel's touch buttons", "game"),
 ("FL-0074", K2, 'NAMES[identity.id] = (string.gsub(identity.name, "%s+Kingdom$", ""))', 'NAMES[identity.id] = identity.name', "CrowdClient", "one line per stand with the kingdom's name", "game"),
 ("FL-0074", K2, '\theight = 44,', '\theight = 28,', "CrowdClient", "every subtitle fits a two-line box", "game"),
 ("FL-0074", K2, '\tmaxChars = 80,', '\tmaxChars = 40,', "CrowdClient", "every subtitle fits a two-line box", "game"),
]
