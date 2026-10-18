"""FL-0125 mutation rows (full match by default, D-053): the defaults, elimination and spectators, the Crown Arena
hooks, the debug phase jump / restart, the host's Match.Spectate and event isolation, and the governor changes
(barracks growth, resting after an empty placement search) that let wars happen inside the tick budget.

Run by ../mutations.py (`mutations.py FL-0125`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
CFG = G + "config/Match.luau"
MATCH = G + "src/shared/Kingdom/Match.luau"
HOST = G + "src/shared/Kingdom/MatchHost.luau"
SVC = G + "src/server/Services/MatchService.luau"
AI = G + "src/shared/Sim/RulerAI.luau"
SIM = G + "src/shared/Sim/Simulation.luau"
MIL = G + "src/shared/Sim/Military.luau"
AUTH = G + "src/shared/Sim/Authority.luau"
DIPL = G + "src/shared/Sim/Diplomacy.luau"
CMD = G + "src/shared/Sim/Commands.luau"
M = [
 # --- the shipped defaults are the full match
 ("FL-0125", CFG, 'mode = "match", -- the full match is the default build', 'mode = "slice", -- the full match is the default build', "sim/Match.spec", "is the full match by default"),
 ("FL-0125", CFG, 'pvp = { enabled = true,', 'pvp = { enabled = false,', "sim/Match.spec", "is the full match by default"),
 ("FL-0125", MATCH, 'GovernorConfig.enabled and mode == "match"', 'GovernorConfig.enabled and mode == "slice"', "sim/Match.spec", "is the full match by default"),
 ("FL-0125", MATCH, 'populateOnJoin = if options.populateOnJoin == nil then mode == "slice"', 'populateOnJoin = if options.populateOnJoin == nil then mode == "match"', "sim/Match.spec", "is the full match by default"),
 # --- elimination: the fallen rulers spectate
 ("FL-0125", MATCH, '		self:_eliminateRulers()\n', '', "sim/Match.spec", "takes a fallen kingdom's rulers out of it as spectators"),
 ("FL-0125", MATCH, 'if self.spectators[userId] ~= nil then\n		return false, "eliminated"', 'if false then\n		return false, "eliminated"', "sim/Match.spec", "takes a fallen kingdom's rulers out of it as spectators"),
 ("FL-0125", MATCH, '				sim:removeRuler(userId)\n				table.insert(self._events, {', '				table.insert(self._events, {', "sim/Match.spec", "takes a fallen kingdom's rulers out of it as spectators"),
 ("FL-0125", MATCH, 'if self.spectators[userId] == nil and (self.sim.rulerOf[userId] == nil or regroup) then', 'if self.sim.rulerOf[userId] == nil or regroup then', "sim/Match.spec", "takes a fallen kingdom's rulers out of it as spectators"),
 ("FL-0125", HOST, '	player.Neutral = team == nil', '	player.Neutral = false', "MatchKingdomServices", "tells a ruler whose kingdom has fallen with Match.Spectate"),
 ("FL-0125", HOST, '			self:_sendSpectate(player, "eliminated")\n		end\n		self._membershipChanged = true', '		end\n		self._membershipChanged = true', "MatchKingdomServices", "tells a ruler whose kingdom has fallen with Match.Spectate"),
 ("FL-0125", HOST, '	if not ok then\n		self:_sendSpectate(player, result)\n	end', '', "MatchKingdomServices", "tells a player who cannot be seated that they are watching"),
 ("FL-0125", HOST, '					self._remotes:fire("Match.Spectate", player, false)', '', "MatchKingdomServices", "Match.Spectate(false) when seated later"),
 ("FL-0125", HOST, 'local ok, err = pcall(self._handleEvent, self, event)', 'local ok, err = true, self:_handleEvent(event)', "MatchKingdomServices", "keeps handling a tick's events when one handler fails"),
 # --- the Crown Arena hooks
 ("FL-0125", MATCH, 'elseif not self:_beginArena() then', 'elseif true then', "sim/Match.spec", "asks the host to begin the duel between the top two"),
 ("FL-0125", MATCH, 'if winner ~= nil and (a.kingdomId == winner) ~= (b.kingdomId == winner) then', 'if false then', "sim/Match.spec", "asks the host to begin the duel between the top two"),
 ("FL-0125", MATCH, 'local champion = if winner ~= nil and table.find(arena.qualifiers, winner) ~= nil then winner else nil', 'local champion = winner', "sim/Match.spec", "falls back to the Crown Points result when the duel has no winner"),
 ("FL-0125", MATCH, 'if sim.time - arena.startedAt >= self.options.arenaMaxSeconds then', 'if false then', "sim/Match.spec", "cuts off an arena that never reports"),
 ("FL-0125", MATCH, '		self:_cancelArena("conquest")\n', '', "sim/Match.spec", "ends by conquest, not by duel, when a kingdom takes the rest during the arena"),
 ("FL-0125", MATCH, 'local ok, begun = pcall(host.beginArena, qualifiers)\n	if not ok or begun ~= true then', 'local ok, begun = true, host.beginArena(qualifiers)\n	if not ok or begun ~= true then', "sim/Match.spec", "gives the Crown Points result at once when there is no host"),
 ("FL-0125", MATCH, 'if #qualifiers < 2 then', 'if #qualifiers < 0 then', "sim/Match.spec", "never asks for a duel with fewer than two kingdoms standing"),
 # --- restart, the debug phase jump
 ("FL-0125", MATCH, '			self.sim.diplomacy.graceSeconds = self.phaseEnds.Expansion', '			local _ = self.phaseEnds.Expansion', "sim/Match.spec", "moves Diplomacy's war grace with the phase jump"),
 ("FL-0125", MATCH, 'newWorld = newWorld == true,', 'newWorld = false,', "sim/Match.spec", "restarts in another mode with a fresh world"),
 ("FL-0125", SVC, '	self.host.match:restart(mode, durations)', '	self.mode = self.mode', "MatchKingdomServices", "restarts in slice or match mode on the match.mode debug command"),
 ("FL-0125", SVC, '	self.mode = mode\n	local durations = self:_pacedDurations()', '	local durations = self:_pacedDurations()', "MatchKingdomServices", "restarts in slice or match mode on the match.mode debug command"),
 # --- the governors
 ("FL-0125", AI, '				local issued = tryUpgrade(sim, kingdom, "barracks", 4)\n', '				local issued = nil\n', "sim/RulerAI", "builds more bunks when they are all that hold the army back"),
 ("FL-0125", AI, 'and army + training + 2 > Military.recruitCap(sim, kingdom)', 'and army + training + 2 > 1e9', "sim/RulerAI", "builds more bunks when they are all that hold the army back"),
 ("FL-0125", AI, 'if resting[key] ~= nil and sim.time < resting[key] then', 'if false then', "sim/RulerAI", "rests for a minute after a placement search finds nothing"),
 ("FL-0125", AI, 'resting[key] = sim.time + NO_SPOT_RETRY', 'resting[key] = sim.time', "sim/RulerAI", "rests for a minute after a placement search finds nothing"),
 ("FL-0125", AI, 'local NO_SPOT_RETRY = 60 -- seconds', 'local NO_SPOT_RETRY = 6000 -- seconds', "sim/RulerAI", "rests for a minute after a placement search finds nothing"),
 # --- D-055: the per-kingdom caps (60 citizens, 15 soldiers)
 ("FL-0125", SIM, 'math.min(kingdom.popCap, tuning.maxPerKingdom or math.huge)', 'kingdom.popCap', "sim/Simulation.spec", "stops births at config Citizens.maxPerKingdom"),
 ("FL-0125", G + "config/Citizens.luau", 'maxPerKingdom = 60,', 'maxPerKingdom = 600,', "sim/Simulation.spec", "stops births at config Citizens.maxPerKingdom"),
 ("FL-0125", G + "config/Military.luau", 'maxSoldiers = 15,', 'maxSoldiers = 150,', "sim/Simulation.spec", "stops births at config Citizens.maxPerKingdom"),
 ("FL-0125", MIL, 'if #kingdom.unitIds + queuedCount(sim, kingdom) + count > armyCap(sim) then', 'if false then', "sim/Military.spec", "caps standing soldiers (living + training) at config Military.maxSoldiers"),
 ("FL-0125", AI, 'and army + training + 2 <= math.min(Military.recruitCap(sim, kingdom), Military.armyCap(sim))', 'and army + training + 2 <= Military.recruitCap(sim, kingdom)', "sim/RulerAI", "never recruits past the army cap"),

 # --- D-054: senior ruler, asks, newcomer lock (Sim/Authority, Commands, MatchHost)
 ("FL-0125", AUTH, 'return if name == "DeclareWar" then "ask" else "not_senior"', 'return "not_senior"', "sim/Authority", "a non-senior's DeclareWar is an ask"),
 ("FL-0125", AUTH, 'if Authority.seniorOf(sim, kingdom) ~= by then', 'if false then', "sim/Authority", "only the senior declares war"),
 ("FL-0125", AUTH, 'if by == nil then\n\t\treturn nil -- AI governors', 'if false then\n\t\treturn nil -- AI governors', "sim/Authority", "AI governors (by = nil) are exempt"),
 ("FL-0125", AUTH, 'late = sim.active == true and sim.time > 0,', 'late = false,', "sim/Authority", "a ruler seated after Founding began"),
 ("FL-0125", AUTH, 'late = sim.active == true and sim.time > 0,', 'late = true,', "sim/Authority", "rulers seated before the first tick are exempt"),
 ("FL-0125", AUTH, 'elseif name == "MoveBuilding" then', 'elseif false then', "sim/Authority", "a ruler seated after Founding began"),
 ("FL-0125", AUTH, 'return sim.time - seat.lastActive >= setting(sim, "idleSeniorSeconds")', 'return false', "sim/Authority", "an idle senior yields"),
 ("FL-0125", AUTH, 'return firstActive or first', 'return first', "sim/Authority", "an idle senior yields"),
 ("FL-0125", AUTH, '	if seat then\n		seat.lastActive = sim.time\n	end', '	if seat then\n	end', "sim/Authority", "an idle senior yields"),
 ("FL-0125", AUTH, 'if last ~= nil and sim.time - last < setting(sim, "askCooldownSeconds") then', 'if false then', "sim/Authority", "spaced by the ask cooldown"),
 ("FL-0125", AUTH, 'if #list >= setting(sim, "maxAsks") then', 'if false then', "sim/Authority", "at most maxAsks asks stay open"),
 ("FL-0125", AUTH, 'if sim.time >= list[i].expiresAt then', 'if false then', "sim/Authority", "asks expire after askSeconds"),
 ("FL-0125", AUTH, '			if list[i].from == userId then', '			if false then', "sim/Authority", "a requester who leaves takes their asks"),
 ("FL-0125", DIPL, '		Authority.clearAsks(s, kingdom.id, target.id)\n', '', "sim/Authority", "the senior's declaration clears them"),
 ("FL-0125", CMD, '		Authority.touch(sim, by)', '		local _ = by', "sim/Authority", "a command counts as activity"),
 ("FL-0125", HOST, '	elseif name == "WarAsked" then\n		local senior = self:_player(event.seniorId)', '	elseif name == "WarAsked" then\n		local senior = nil', "sim/MatchKingdomServices", "a co-ruler's declareWar is an ask"),
 ("FL-0125", HOST, 'if ask.kingdomId == mine then', 'if true then', "sim/MatchKingdomServices", "a co-ruler's declareWar is an ask"),
 ("FL-0125", HOST, '		local locked = raw.locks[player.UserId]\n		if locked then', '		local locked = next(raw.locks)\n		if locked then', "sim/MatchKingdomServices", "a ruler who arrives after Founding began is locked"),
 ("FL-0125", HOST, '			table.insert(parts, `W:{r.a}:{r.b}`)', '			table.insert(parts, "W")', "sim/MatchKingdomServices", "state signature"),
 ("FL-0125", HOST, '			table.insert(parts, `P:{p.from}:{p.to}`)', '			table.insert(parts, "P")', "sim/MatchKingdomServices", "state signature"),
 ("FL-0125", HOST, '			table.insert(parts, `A:{a.kingdomId}:{a.from}:{a.target}`)', '			table.insert(parts, "A")', "sim/MatchKingdomServices", "state signature"),
 ("FL-0125", HOST, '		table.insert(parts, "L:" .. table.concat(locks, ","))', '		table.insert(parts, "L:")', "sim/MatchKingdomServices", "state signature"),
 ("FL-0125", HOST, '		table.insert(parts, "S:" .. table.concat(seniors, ","))', '		table.insert(parts, "S:")', "sim/MatchKingdomServices", "each diplomacy fact is in the state signature"),
 # --- FORGE-07 review of #187: M1 (a turned-away player is seated in the next world), L1 (a host that reports from inside beginArena)
 ("FL-0125", MATCH, '	for _, userId in waiting do\n		self:join(userId)\n	end', '', "sim/Match.spec", "seats a player who was turned away"),
 ("FL-0125", MATCH, '		if not table.find(self.waiting, userId) then\n			table.insert(self.waiting, userId)\n		end\n		return false, "match_full"', '		return false, "match_full"', "sim/Match.spec", "seats a player who was turned away"),
 ("FL-0125", MATCH, '	local waiting = table.find(self.waiting, userId)\n	if waiting then\n		table.remove(self.waiting, waiting)\n	end\n	self.sim:removeRuler(userId)', '	self.sim:removeRuler(userId)', "sim/Match.spec", "forgets a waiting player who leaves"),
 ("FL-0125", MATCH, '	self._arena = { qualifiers = qualifiers, startedAt = self.sim.time }\n	local ok, begun = pcall(host.beginArena, qualifiers)', '	local ok, begun = pcall(host.beginArena, qualifiers)\n	self._arena = { qualifiers = qualifiers, startedAt = self.sim.time }', "sim/Match.spec", "hears a host that reports the result from inside beginArena"),
]
