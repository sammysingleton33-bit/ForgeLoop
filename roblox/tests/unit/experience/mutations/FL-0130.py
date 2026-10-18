"""FL-0130 mutation rows, run by ../mutations.py (FL-0130 only: `mutations.py FL-0130`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0130 here only (D-038 (7)).
"""
A = "src/server/Services/AnnouncerService.luau"
M = [
 # --- Moments: KingdomEliminated (G9)
 ("FL-0130", F+"Moments.luau", 'local conqueror = if type(by) == "string" and by ~= kingdom then by else nil', 'local conqueror = by', "KingdomFeedback", "KingdomEliminated: the fallen rulers", "game"),
 ("FL-0130", F+"Moments.luau", 'if not isMember(fallen, player) and not isMember(winners, player) then', 'if true then', "KingdomFeedback", "KingdomEliminated: the fallen rulers", "game"),
 ("FL-0130", F+"Moments.luau", 'to(out, rest, { kind = "rivalFell", kingdom = kingdom, kingdomName = kingdomName, byName = byName })', 'to(out, rest, { kind = "rivalFell", kingdom = kingdom, kingdomName = kingdomName })', "KingdomFeedback", "KingdomEliminated: the fallen rulers", "game"),
 # --- Moments: WarChanged (proposed G9)
 ("FL-0130", F+"Moments.luau", 'to(out, if atWar then except(mine, actor) else mine, own)', 'to(out, mine, own)', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
 ("FL-0130", F+"Moments.luau", 'target.role = "other"', 'target.role = "self"', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
 ("FL-0130", F+"Moments.luau", 'rival.role = "rival"', 'rival.role = "other"', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
 ("FL-0130", F+"Moments.luau", 'type(other) ~= "string" or kingdom == other or type(atWar)', 'type(other) ~= "string" or type(atWar)', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
 ("FL-0130", F+"Moments.luau", 'local role = Lines.WAR[moment.role]', 'local role = Lines.WAR.self', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
 # --- Moments: SiegeChanged / RaidChanged (proposed G9)
 ("FL-0130", F+"Moments.luau", 'byName = if on then attackerName(details, ctx) else nil,', 'byName = nil,', "KingdomFeedback", "SiegeChanged and RaidChanged", "game"),
 ("FL-0130", F+"Moments.luau", 'if ids == nil or #ids ~= 1 or type(ids[1]) ~= "string" then', 'if ids == nil or #ids < 1 or type(ids[1]) ~= "string" then', "KingdomFeedback", "SiegeChanged and RaidChanged", "game"),
 ("FL-0130", F+"Moments.luau", 'position = if on and kind == "raid" and typeof(details.position) == "Vector3" then details.position else nil,', 'position = details.position,', "KingdomFeedback", "SiegeChanged and RaidChanged", "game"),
 ("FL-0130", F+"Moments.luau", 'body = body or line.bodyPlain,', 'body = body,', "KingdomFeedback", "SiegeChanged and RaidChanged", "game"),
 # --- Moments: timed phases and whole bodies
 ("FL-0130", F+"Moments.luau", 'minutes = if minutes ~= 0 then minutes else nil', 'minutes = minutes', "KingdomFeedback", "phase moments carry the phase's length from Pacing", "game"),
 ("FL-0130", F+"Moments.luau", 'local body = if moment.minutes ~= nil then fillAll(line.timed, moment) or line.body else line.body', 'local body = line.body', "KingdomFeedback", "phase moments carry the phase's length from Pacing", "game"),
 ("FL-0130", F+"Moments.luau", 'body = fillAll(line.body, moment) or line.bodyPlain, -- never half a sentence', 'body = fill(line.body, moment),', "KingdomFeedback", "KingdomEliminated: the fallen rulers", "game"),
 # --- Lines
 ("FL-0130", F+"Lines.luau", 'key = "war:{other}:off"', 'key = "war:{other}:on"', "KingdomFeedback", "every sound and effect named in Lines exists", "game"),
 ("FL-0130", F+"Lines.luau", 'key = "raid:off"', 'key = "raid:on"', "KingdomFeedback", "every sound and effect named in Lines exists", "game"),
 ("FL-0130", F+"Lines.luau", 'sound = "kingdom.alarm",', 'sound = "kingdom.horn.war",', "KingdomFeedback", "SiegeChanged and RaidChanged", "game"),
 # --- AnnouncerService
 ("FL-0130", G+A, '	"KingdomEliminated",\n', '', "KingdomFeedback", "KingdomEliminated and the proposed war, siege and raid events", "game"),
 ("FL-0130", G+A, '	"WarChanged",\n', '', "KingdomFeedback", "KingdomEliminated and the proposed war, siege and raid events", "game"),
 ("FL-0130", G+A, 'return math.floor(seconds / 60 + 0.5)', 'return seconds', "KingdomFeedback", "phase moments carry the Pacing length", "game"),
 # --- MusicController: battle music while a raid or siege is on
 ("FL-0130", C2+"MusicController.luau", 'self._director:combat(self._env.clock()) -- a long raid keeps the battle music up', '', "KingdomFeedback", "MusicController: a raid or a siege plays battle music", "game"),
 ("FL-0130", C2+"MusicController.luau", '		if next(self.alerts) == nil then\n			self._director:calm(self._env.clock())', '		if false then\n			self._director:calm(self._env.clock())', "KingdomFeedback", "MusicController: a raid or a siege plays battle music", "game"),
 ("FL-0130", C2+"MusicController.luau", '				elseif moment.kind == "kingdomFell" then\n					self:clearAlerts()\n', '', "KingdomFeedback", "MusicController: a raid or a siege plays battle music", "game"),
 ("FL-0130", C2+"MusicController.luau", 'if phase == "Results" or phase == "Lobby" then', 'if false then', "KingdomFeedback", "MusicController: a raid or a siege plays battle music", "game"),
]
