"""FL-0023 mutation rows, run by ../mutations.py (FL-0023 only: `mutations.py FL-0023`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0023 here only (D-038 (7)).
"""
M = [
 ("FL-0023", S+"AnalyticsService.luau", 'local floor = if kind == "event" then self._capacity * self._limits.customReserve else 0', 'local floor = 0', "AnalyticsService", "keeps a reserve for funnels", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if decl.kind == "recurring" and (type(sessionId) ~= "string" or sessionId == "") then', 'if false then', "AnalyticsService", "drops recurring funnel steps without a sessionId", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'local ok, err = pcall(service[method], service, ...)', 'local ok, err = true, service[method](service, ...)', "AnalyticsService", "never throws when Roblox errors", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'out[AnalyticsSchema.FIELD_KEYS[index]] = text', 'out[AnalyticsSchema.FIELD_KEYS[4 - index]] = text', "AnalyticsService", "maps the value field and CustomField01-03", "fw"),
 ("FL-0023", S+"AnalyticsService.luau", 'if state.tokens < 1 then', 'if false then', "AnalyticsService", "caps one player at perPlayerPerMinute", "fw"),
 ("FL-0023", X+"AnalyticsSchema.luau", 'if #fields > AnalyticsSchema.CAPS.customFields then', 'if false then', "AnalyticsSchema", "rejects more than 3 custom fields", "fw"),
 ("FL-0023", X+"Subjects.luau", 'local ok, result = pcall(resolver, args, ctx)', 'local ok, result = true, resolver(args, ctx)', "AnalyticsService", "isolates a resolver that errors", "fw"),
 ("FL-0023", X+"Subjects.luau", 'table.insert(out, { player = subject.player, info = Subjects.primitives(subject.info) })', 'table.insert(out, { player = subject.player, info = subject.info })', "AnalyticsSchema", "a game resolver wins over the default and its info is filtered too", "fw"),
]
