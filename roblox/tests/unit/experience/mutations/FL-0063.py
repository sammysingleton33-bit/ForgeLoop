"""FL-0063 mutation rows, run by ../mutations.py (FL-0063 only: `mutations.py FL-0063`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0063 here only (D-038 (7)).
"""
M = [
 ("FL-0063", S+"AnalyticsService.luau", 'local startOn = (self._config.session or {}).startOn or "PlayerReady"', 'local startOn = "PlayerReady"', "AnalyticsService", "starts on config.session.startOn", "fw"),
 ("FL-0063", S+"AnalyticsService.luau", '{ sessionSec = seconds, lastActivity = lastActivity }', '{ sessionSec = seconds, lastActivity = state.lastActivity }', "AnalyticsService", "starts on config.session.startOn", "fw"),
 ("FL-0063", S+"AnalyticsService.luau", '			self:event(player, session.leftEvent, fields)', '			local _ = fields', "AnalyticsService", "starts on config.session.startOn", "fw"),
 ("FL-0063", S+"AnalyticsService.luau", 'local ok, fields = pcall(session.leftInfo, player, self:_lookup())', 'local ok, fields = true, session.leftInfo(player, self:_lookup())', "AnalyticsService", "a leftInfo that errors or returns nil", "fw"),
 ("FL-0063", X+"AnalyticsSchema.luau", 'if (session.leftEvent == nil) ~= (session.leftInfo == nil) then', 'if false then', "AnalyticsSchema", "pairs leftEvent with a leftInfo function", "fw"),
 ("FL-0063", X+"AnalyticsSchema.luau", 'session.startOn ~= nil and (type(session.startOn) ~= "string" or not table.find(knownEvents, session.startOn))', 'false', "AnalyticsSchema", "checks session.startOn against the bus", "fw"),
 ("FL-0063", S+"AnalyticsService.luau", '		if sent then\n			self:_state(subject.player).lastActivity = eventName', '		if true then\n			self:_state(subject.player).lastActivity = eventName', "MatchAnalytics", "SessionEnd keeps the player's own last step", "game"),
 ("FL-0063", G+"config/Analytics.luau", '		startOn = "KingdomJoined",\n', '', "MatchAnalytics", "starts the session on KingdomJoined", "game"),
 ("FL-0063", G+"config/Analytics.luau", '{ on = "ObjectiveCaptured", funnel = "VS1", step = 6 },', '{ on = "ObjectiveCaptured", funnel = "VS1", step = 6, match = { kingdom = "frost" } },', "MatchAnalytics", "runs the BRIEF §13 funnel", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", 'then "draw" else kingdomId == result.winner', 'then "draw" else true', "MatchAnalytics", "logs MatchEnded per ruler still here", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", '	elseif Def.PLAYING[phase] then\n		self.decidedPhase = phase\n', '	elseif Def.PLAYING[phase] then\n		local _ = phase\n', "MatchAnalytics", "logs MatchEnded per ruler still here", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", '		if kingdomId ~= nil then', '		if true then', "MatchAnalytics", "logs MatchEnded per ruler still here", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", 'if phase == nil or not Def.PLAYING[phase] or self._startedAt == nil then', 'if phase == nil or self._startedAt == nil then', "MatchAnalytics", "logs PhaseLeft (minute, phase) before SessionEnd", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", 'return { phase = phase, minute = math.floor((self._env.clock() - self._startedAt) / 60) }', 'return { phase = phase, minute = 0 }', "MatchAnalytics", "logs PhaseLeft (minute, phase) before SessionEnd", "game"),
 ("FL-0063", S+"AnalyticsService.luau", '		self:_count("duplicate")\n		return false', '		return self:_drop("funnel", funnel, "duplicate", logFields)', "MatchAnalytics", "logs each funnel step once per player", "game"),
 ("FL-0063", S+"AnalyticsService.luau", 'if decl.inOrder and step > 1 and not state.sentSteps', 'if false and not state.sentSteps', "MatchAnalytics", "runs the BRIEF §13 funnel", "game"),
 ("FL-0063", G+"config/Analytics.luau", '			inOrder = true, -- FORGE-00', '			-- FORGE-00', "MatchAnalytics", "runs the BRIEF §13 funnel", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", 'own.won = if type(result.winner) ~= "string" then "draw" else kingdomId == result.winner', 'own.won = kingdomId == result.winner', "MatchAnalytics", "a draw is logged as won = draw", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", 'self._kingdomOf[player.UserId] = nil -- a ruler again only after a new KingdomJoined', 'local _ = player', "MatchAnalytics", "a draw is logged as won = draw", "game"),
 ("FL-0063", X+"AnalyticsSchema.luau", 'if decl.inOrder ~= nil and (type(decl.inOrder) ~= "boolean" or decl.kind == "onboarding") then', 'if false then', "AnalyticsSchema", "a funnel's inOrder is a boolean", "fw"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", '		self:_forgetDeparted()\n', '', "MatchAnalytics", "a new match restarts the clock and forgets rulers who left", "game"),
 ("FL-0063", G+"src/server/Services/MatchAnalyticsService.luau", '		self._startedAt = self._env.clock()', '		self._startedAt = self._startedAt or self._env.clock()', "MatchAnalytics", "a new match restarts the clock", "game"),
 ("FL-0063", S+"SettingsService.luau", '		value = math.floor(value * 10 + 0.5) / 10', '		value = value', "Settings", "reports SettingChanged at most once per key", "fw"),
]
