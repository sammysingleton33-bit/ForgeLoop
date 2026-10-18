"""FL-0074 mutation rows, run by ../mutations.py (FL-0074 only: `mutations.py FL-0074`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0074 here only (D-038 (7)).
"""
D = F + "CrowdDirector.luau"
K = G + "config/Crowd.luau"
M = [
 # figures and seats
 ("FL-0074", D, 'return math.min(math.ceil(n / config.citizensPerFigure), config.maxPerStand)', 'return math.ceil(n / config.citizensPerFigure)', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'return if type(value) == "number" and value > 0 then value else 0', 'return if value > 0 then value else 0', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'local trimA = math.min(over, math.max(0, a - b))', 'local trimA = 0', "CrowdDirector", "one figure per two citizens", "game"),
 ("FL-0074", D, 'return math.floor(figures * tierOf(tier, config).fill + 0.5)', 'return figures', "CrowdDirector", "a lower tier leaves more seats empty", "game"),
 ("FL-0074", D, 'return config.tiers[tier] or config.tiers.divided', 'return config.tiers[tier] or config.tiers.adoring', "CrowdDirector", "an unknown tier counts as divided", "game"),
 # reactions by tier
 ("FL-0074", D, 'self:_reaction(other, if good then theirs.bad else theirs.good, true, priority),', 'self:_reaction(other, if good then theirs.good else theirs.bad, true, priority),', "CrowdDirector", "a big hit", "game"),
 ("FL-0074", D, 'if data.heavy == true or count(data.damage) >= config.moments.bigHit then', 'if data.heavy == true then', "CrowdDirector", "a big hit", "game"),
 ("FL-0074", K, 'hostile = table.freeze({ fill = 0.5, idle = "boo", good = "silence", bad = "turnBack", chants = false }),', 'hostile = table.freeze({ fill = 0.5, idle = "boo", good = "cheer", bad = "turnBack", chants = false }),', "CrowdDirector", "a hostile stand boos", "game"),
 # rationing and priority
 ("FL-0074", D, 'if now - self._lastMajor < self._config.majorGapSec then', 'if false then', "CrowdDirector", "at most one major reaction every 3 s", "game"),
 ("FL-0074", K, 'majorGapSec = 3,', 'majorGapSec = 2,', "CrowdDirector", "at most one major reaction every 3 s", "game"),
 ("FL-0074", D, 'if now - self._lastMinor[stand] < self._config.minorGapSec then', 'if false then', "CrowdDirector", "small hits are minor", "game"),
 ("FL-0074", D, '\t\tself._lastMajor = now\n\t\tself:duck(now, config.duck.perkSec)', '\t\tself:duck(now, config.duck.perkSec)', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'self:duck(now, config.duck.perkSec)', 'local _ = config.duck.perkSec', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'self:_reaction(side, if rally then "rally" else "perk", true, true, {', 'self:_reaction(side, "perk", true, true, {', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'return if type(value) == "string" then value else nil', 'return nil', "CrowdDirector", "perk moments always win", "game"),
 ("FL-0074", D, 'return if now < self._duckUntil then self._config.duck.volume else 1', 'return 1', "CrowdDirector", "perk moments always win", "game"),
 # near-death and comeback
 ("FL-0074", D, 'if not self._nearDeath[target] and self._hp[target] > 0 and self._hp[target] < moments.nearDeath then', 'if self._hp[target] > 0 and self._hp[target] < moments.nearDeath then', "CrowdDirector", "near-death once per champion", "game"),
 ("FL-0074", D, 'if self._trailed[hitter] and self._hp[hitter] > self._hp[target] then', 'if false then', "CrowdDirector", "a comeback when the trailing champion takes the lead", "game"),
 ("FL-0074", D, 'self._trailed[stand] = true', 'local _ = stand', "CrowdDirector", "a comeback when the trailing champion takes the lead", "game"),
 # chants
 ("FL-0074", D, 'if data.full ~= true or not tierOf(self._sides[side].tier, config).chants then', 'if data.full ~= true then', "CrowdDirector", "full hype chants for a chanting tier only", "game"),
 ("FL-0074", D, 'line = config.chants.any[1] -- no name to chant', 'local _ = 0 -- no name to chant', "CrowdDirector", "full hype chants for a chanting tier only", "game"),
 # endings
 ("FL-0074", D, 'return if high then "flood" else "thinCrowning"', 'return "flood"', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'return if high then "salute" else "empty"', 'return "salute"', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'if self._ended or SIDES[winner] == nil then', 'if SIDES[winner] == nil then', "CrowdDirector", "four endings", "game"),
 ("FL-0074", D, 'if self._ended or type(event) ~= "table" or SIDES[event.side] == nil then', 'if type(event) ~= "table" or SIDES[event.side] == nil then', "CrowdDirector", "four endings", "game"),
 # input hygiene
 ("FL-0074", D, 'self._duckUntil = math.max(self._duckUntil, now + math.min(seconds, 30))', 'self._duckUntil = math.max(self._duckUntil, now + seconds)', "CrowdDirector", "ignores unknown kinds", "game"),
 # config: sounds and arena timings
 ("FL-0074", G + "config/Sounds.luau", 'id = "crowd.salute",', 'id = "crowd.salutes",', "CrowdDirector", "sounds exist", "game"),
 ("FL-0074", G + "config/Pacing.luau", 'duel = 120,', 'duel = 150,', "CrowdDirector", "arena stage timings in Pacing", "game"),
]
