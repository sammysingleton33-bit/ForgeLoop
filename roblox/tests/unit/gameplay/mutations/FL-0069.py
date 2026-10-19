"""FL-0069 mutation rows (leadership: Arena/Ledger and LeadershipService; CONTRACTS G12.2).
Run by ../mutations.py (`mutations.py FL-0069`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
LG = G + "src/shared/Arena/Ledger.luau"
LS = G + "src/server/Services/LeadershipService.luau"
M = [
 # --- the ledger
 ("FL-0069", LG, 'if def == nil then\n\t\treturn nil, "unknown_act"', 'if false then\n\t\treturn nil, "unknown_act"', "sim/Ledger", "refuses an unknown act"),
 ("FL-0069", LG, 'local scale = clamp(if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1, 0, 2)', 'local scale = if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1', "sim/Ledger", "scales the delta by the magnitude"),
 ("FL-0069", LG, 'local scale = clamp(if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1, 0, 2)', 'local scale = clamp(if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1, -2, 2)', "sim/Ledger", "scales the delta by the magnitude"),
 ("FL-0069", LG, 'local scale = clamp(if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1, 0, 2)', 'local scale = clamp(if type(magnitude) == "number" then magnitude else 1, 0, 2)', "sim/Ledger", "scales the delta by the magnitude"),
 ("FL-0069", LG, 'ledger.levels[key] = clamp((ledger.levels[key] or Ledger.START_LEVEL) + delta, 0, 100)', 'ledger.levels[key] = (ledger.levels[key] or Ledger.START_LEVEL) + delta', "sim/Ledger", "keeps a ruler level inside 0..100"),
 ("FL-0069", LG, 'return `{kingdom}|{if userId then tostring(userId) else "-"}|{component}`', 'return `{kingdom}|-|{component}`', "sim/Ledger", "moves that ruler\'s level only"),
 ("FL-0069", LG, 'if component == "valour" and delta > 0 then', 'if false then', "sim/Ledger", "caps valour gained per rolling minute"),
 ("FL-0069", LG, 'if room <= 0 then\n\t\t\t\treturn nil, "capped"', 'if room < -1000 then\n\t\t\t\treturn nil, "capped"', "sim/Ledger", "caps valour gained per rolling minute"),
 ("FL-0069", LG, 'delta = math.min(delta, room)', 'delta = delta', "sim/Ledger", "trims a valour gain that only half fits"),
 ("FL-0069", LG, 'if gain.t > t - VALOUR_WINDOW then', 'if true then', "sim/Ledger", "lets it recover after the window"),
 ("FL-0069", LG, 'ledger.offsets[key] = clamp((ledger.offsets[key] or 0) + delta, -Ledger.MAX_OFFSET, Ledger.MAX_OFFSET)', 'ledger.offsets[key] = (ledger.offsets[key] or 0) + delta', "sim/Ledger", "bounds it"),
 ("FL-0069", LG, 'if moment.kingdom == kingdom and (userId == nil or moment.userId == nil or moment.userId == userId) then', 'if moment.kingdom == kingdom then', "sim/Ledger", "not a co-ruler\'s"),
 ("FL-0069", LG, 'if moment.kingdom == kingdom and (userId == nil or moment.userId == nil or moment.userId == userId) then', 'if (userId == nil or moment.userId == nil or moment.userId == userId) then', "sim/Ledger", "for that kingdom only"),
 ("FL-0069", LG, 'if #out >= count then', 'if #out > count then', "sim/Ledger", "at most the limit"),
 # --- the service
 ("FL-0069", LS, 'if k == nil then\n\t\treturn nil\n\tend\n\tlocal moment, reason', 'if false then\n\t\treturn nil\n\tend\n\tlocal moment, reason', "sim/LeadershipService", "refuses an unknown act, an unknown kingdom"),
 ("FL-0069", LS, 'if reason == "unknown_act" and not self._warned[act] then', 'if reason == "unknown_act" then', "sim/LeadershipService", "logging an unknown act once"),
 ("FL-0069", LS, 'self.acted:fire(kingdom, userId, act, moment.component, moment.delta)', 'self.acted:fire(kingdom, userId, act, moment.component, 0)', "sim/LeadershipService", "fires acted"),
 ("FL-0069", LS, 'stability = clamp100(if conditions then Consequences.effectiveStability(k) else NEUTRAL),', 'stability = clamp100(if conditions then conditions.stability or NEUTRAL else NEUTRAL),', "sim/LeadershipService", "stability net of unrest pressure"),
 ("FL-0069", LS, 'if c and c.alive ~= false then\n\t\t\ttotal += c.loyalty or NEUTRAL', 'if c then\n\t\t\ttotal += c.loyalty or NEUTRAL', "sim/LeadershipService", "leaves out the dead"),
 ("FL-0069", LS, 'return clamp100(mean + Ledger.offset(self._ledger, kingdom, "reputation"))', 'return clamp100(mean)', "sim/LeadershipService", "adds a kingdom reputation act as an offset"),
 ("FL-0069", LS, 'if now - self._lastSampleAt < self.config.sampling.intervalSeconds - 1e-6 then', 'if false then', "sim/LeadershipService", "does not sample twice inside one interval"),
 ("FL-0069", LS, 'if not sim.active then\n\t\treturn\n\tend\n\tlocal now = sim.time', 'if false then\n\t\treturn\n\tend\n\tlocal now = sim.time', "sim/LeadershipService", "takes no sample while the match is not running"),
 ("FL-0069", LS, 'components.conduct = Ledger.level(self._ledger, kingdom, userId, "conduct")', 'components.conduct = 50', "sim/LeadershipService", "conduct and valour levels in their own series"),
 ("FL-0069", LS, 'components.valour = Ledger.level(self._ledger, kingdom, userId, "valour")', 'components.valour = Ledger.level(self._ledger, kingdom, userId, "conduct")', "sim/LeadershipService", "conduct and valour levels in their own series"),
 ("FL-0069", LS, 'if match.roundId ~= self._round then', 'if false then', "sim/LeadershipService", "starts a new round with an empty ledger"),
]
