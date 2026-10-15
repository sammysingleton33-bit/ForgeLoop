"""FL-0122 mutation rows, run by ../mutations.py (`mutations.py FL-0122`; the runner arrives with FL-0119's PR).

One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/. Add rows for
FL-0122 here only.
"""
CONV = G + "src/server/Services/ConversationService.luau"
HOST = G + "src/shared/Kingdom/MatchHost.luau"
GATH = G + "src/shared/Sim/RulerGather.luau"
M = [
 # --- Converse hold cap (D-050 (6a))
 ("FL-0122", CONV, 'local left = SocietyConfig.conversationHoldMaxSec - (showing.holdGranted or 0)', 'local left = math.huge', "ConversationService", "asking again can't hold a citizen for ever"),
 ("FL-0122", CONV, '	if extra <= 0 then\n		return payload', '	if false then\n		return payload', "ConversationService", "asking again can't hold a citizen for ever"),
 ("FL-0122", CONV, 'showing.holdGranted = (showing.holdGranted or 0) + extra', 'showing.holdGranted = (showing.holdGranted or 0) + SocietyConfig.conversationHoldSec', "ConversationService", "asking again can't hold a citizen for ever"),
 ("FL-0122", CONV, 'showing.holdGranted = math.max(0, showing.holdGranted - math.max(0, c.hold.untilTime - sim.time))', 'showing.holdGranted = showing.holdGranted', "ConversationService", "closing the panel gives the unused hold back"),
 ("FL-0122", G + "config/Society.luau", 'conversationHoldMaxSec = 90,', 'conversationHoldMaxSec = 9000,', "ConversationService", "asking again can't hold a citizen for ever"),
 # --- ruler position clamp (D-050 (6b))
 ("FL-0122", HOST, '		if distance > reach then', '		if false then', "RulerPresence", "does not capture it until the walk is done"),
 ("FL-0122", HOST, 'self._rulerMaxSpeed * math.max(0, self._clock - last.t)', 'self._rulerMaxSpeed * 1', "RulerPresence", "does not capture it until the walk is done"),
 ("FL-0122", HOST, 'if last ~= nil and not self._snap[userId] then', 'if last ~= nil then', "RulerPresence", "taken at once"),
 ("FL-0122", HOST, '	self._accepted[userId] = { x = x, z = z, t = self._clock }', '	self._accepted[userId] = nil', "RulerPresence", "does not capture it until the walk is done"),
 ("FL-0122", HOST, '		local x, z = self:_rulerPosition(player)\n		if x == nil or z == nil then\n			return false, "no_character"', '		local x, z = self._positionOf(player)\n		if x == nil or z == nil then\n			return false, "no_character"', "RulerPresence", "Kingdom.Gather uses the clamped position"),
 ("FL-0122", HOST, '	self._clock += dt\n', '', "RulerPresence", "does not capture it until the walk is done"),
 ("FL-0122", HOST, '			self._accepted[userId] = nil -- no longer a ruler (left the match)\n', '', "RulerPresence", "a ruler who left is forgotten"),
 ("FL-0122", G + "config/Match.luau", 'rulerMaxSpeed = 40,', 'rulerMaxSpeed = 4000,', "RulerPresence", "does not capture it until the walk is done"),
 ("FL-0122", G + "src/server/Services/KingdomService.luau", '		self._match.host:snapRuler(userId)', '		local _ = userId', "MatchKingdomServices", "tells the match host when it moves a ruler"),
 # --- ruler gathering (D-050 (3))
 ("FL-0122", GATH, 'if owner ~= nil and owner ~= kingdom.id then', 'if false then', "RulerGather", "only gathers on its own kingdom's land"),
 ("FL-0122", GATH, 'if cap ~= nil and used + amount > cap then', 'if false then', "RulerGather", "share a per-minute allowance"),
 ("FL-0122", GATH, 'if cap ~= nil and used + amount > cap then', 'if cap ~= nil and used + amount > cap * 2 then', "RulerGather", "share a per-minute allowance"),
 ("FL-0122", GATH, 'sim.time - taken[1].t >= config.window', 'sim.time - taken[1].t >= math.huge', "RulerGather", "the window moves on"),
 ("FL-0122", GATH, '	perMinute = { food = 4, wood = 9, stone = 6, gold = 6 },\n	window = 60,', '	perMinute = { food = 4, wood = 90, stone = 6, gold = 6 },\n	window = 60,', "RulerGather", "share a per-minute allowance"),
]
