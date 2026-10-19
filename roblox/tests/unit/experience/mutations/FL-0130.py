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
 ("FL-0130", F+"Moments.luau", 'to(out, except(mine, actor), own)', 'to(out, mine, own)', "KingdomFeedback", "WarChanged (proposed G9)", "game"),
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
 # --- part 2 (client): FeedbackWarController and RulerSpectateController
 ("FL-0130", C2+"FeedbackWarController.luau", 'if model == nil or now - (self._lastFlash[id] or -math.huge) < Def.FLASH_GAP_SEC then', 'if model == nil then', "WarFeedback", "a hit flashes the rig briefly", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if not self:_near(position) then\n\t\tself.stats.skipped += 1\n\t\treturn\n\tend\n\tself._lastFlash[id] = now', 'self._lastFlash[id] = now', "WarFeedback", "a hit flashes the rig briefly", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if live >= Def.FLASH_MAX then', 'if false then', "WarFeedback", "the pool never holds more than FLASH_MAX", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if now >= flash.ends then', 'if false then', "WarFeedback", "a hit flashes the rig briefly", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'local alpha = math.clamp((now - dying.at - fade.from) / (fade.to - fade.from), 0, 1)', 'local alpha = 1', "WarFeedback", "a death fades the rig out", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if dying ~= nil then\n\t\tself:_fade(dying.parts, 0)', 'if dying ~= nil then\n\t\tself:_fade(dying.parts, 1)', "WarFeedback", "a death fades the rig out", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if before ~= nil and hp ~= nil and before.hp ~= nil and hp < before.hp then', 'if before ~= nil and hp ~= nil and before.hp ~= nil then', "WarFeedback", "a building that loses hp gets dust", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if now - (self._lastHit[id] or -math.huge) < Def.HIT_GAP_SEC then', 'if false then', "WarFeedback", "a building that loses hp gets dust", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'moveParts(shake.parts, -shake.offset) -- back exactly where the server put it', '', "WarFeedback", "a building that loses hp gets dust", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if burning then\n\t\treturn -- a riot', 'if false then\n\t\treturn -- a riot', "WarFeedback", "reduced motion keeps the dust", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if model ~= nil and not self:_reducedMotion() then', 'if model ~= nil then', "WarFeedback", "reduced motion keeps the dust", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if Def.isWorldReset(views) then', 'if false then', "WarFeedback", "a standing building that is destroyed collapses", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'return count >= 2', 'return count >= 1', "WarFeedback", "a standing building that is destroyed collapses", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if before ~= nil and Def.STANDING[before.state or ""] then', 'if before ~= nil then', "WarFeedback", "a standing building that is destroyed collapses", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'for index = 1, math.min(#positions, Def.COLLAPSE_MAX) do', 'for index = 1, #positions do', "WarFeedback", "a kingdom's fall collapses at most", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if moment.on == true and typeof(moment.position) == "Vector3" then', 'if moment.on == true then', "WarFeedback", "a raid becomes the alert", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'elseif moment.kind == "kingdomFell" then\n\t\tself:_clearAlert()', 'elseif false then\n\t\tself:_clearAlert()', "WarFeedback", "a raid becomes the alert", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'pcall(camera.setMode, camera, "overview")\n\tend\n\tlocal ok, moved', 'local _ = 0\n\tend\n\tlocal ok, moved', "WarFeedback", "a raid becomes the alert", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if table.find(Def.ALERT_KEYS, input.KeyCode) then', 'if false then', "WarFeedback", "a raid becomes the alert", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if (spot.position - position).Magnitude <= Def.HOTSPOT_STUDS then', 'if false then', "WarFeedback", "hotspots merge within HOTSPOT_STUDS", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'if clock - spot.at <= Def.HOTSPOT_SEC then', 'if true then', "WarFeedback", "hotspots merge within HOTSPOT_STUDS", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'if type(state.mine) == "string" then', 'if true then', "WarFeedback", "starts when our kingdom falls", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'if mine ~= nil and mine.alive == false and not self.active then', 'if mine ~= nil and not self.active then', "WarFeedback", "starts when our kingdom falls", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'kingdom.alive ~= false and kingdom.id ~= self._mine', 'kingdom.alive ~= false', "WarFeedback", "ends at Results and Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'pcall(camera.setMode, camera, "overview") -- no character to walk with any more', '', "WarFeedback", "starts when our kingdom falls", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'local index = ((self._index - 1 + step) % count) + 1', 'local index = math.min(math.max(self._index + step, 1), count)', "WarFeedback", "cycles with . and ,", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", '\t\tif self.active then\n\t\t\tself:setActive(false)\n\t\tend\n\t\tif phase == "Lobby" then', '\t\tif phase == "Lobby" then', "WarFeedback", "ends at Results and Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'self._mine = nil -- a new match', 'local _ = nil -- a new match', "WarFeedback", "ends at Results and Lobby", "game"),
 # --- #178 review lows, carried in part 2
 ("FL-0130", G+A, 'if match.durationsSource == "defaults" then', 'if false then', "KingdomFeedback", "phase moments carry the Pacing length", "game"),
 ("FL-0130", C2+"FeedbackWarController.luau", 'self:_remember(position)\n\tself:_battleMusic()', 'self:_remember(position)', "WarFeedback", "a hit flashes the rig briefly", "game"),
 ("FL-0130", C2+"MusicController.luau", 'function MusicController:combatNear()\n\tself._director:combat(self._env.clock())', 'function MusicController:combatNear()\n\tlocal _ = self._env.clock()', "KingdomFeedback", "MusicController: a raid or a siege plays battle music", "game"),
 # --- D-055 (5) Sim.Focus and FL-0125 Match.Spectate (part 2)
 ("FL-0130", C2+"RulerCameraController.luau", 'if now - sentAt < rule.everySec then', 'if false then', "RulerCamera", "reports the overview's focus for interest", "game"),
 ("FL-0130", C2+"RulerCameraController.luau", 'if (focus - sent).Magnitude < rule.moveStuds and now - sentAt < rule.keepaliveSec then', 'if (focus - sent).Magnitude < rule.moveStuds then', "RulerCamera", "reports the overview's focus for interest", "game"),
 ("FL-0130", C2+"RulerCameraController.luau", 'if send == nil and not self:_focusRemoteReady() then', 'if false then', "RulerCamera", "without the Sim.Focus remote it sends nothing", "game"),
 ("FL-0130", C2+"RulerCameraController.luau", '	self:_reportFocus(target.focus)\n', '', "RulerCamera", "reports the overview's focus for interest", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'if spectating == true then\n\t\tself._pending = true\n\t\tself:setActive(true)', 'if false then\n\t\tself._pending = true\n\t\tself:setActive(true)', "WarFeedback", "follows FL-0125's Match.Spectate", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'self._mine = info.kingdomId -- our fallen kingdom', 'local _ = info.kingdomId -- our fallen kingdom', "WarFeedback", "follows FL-0125's Match.Spectate", "game"),
 # #189 M1: never during Results or Lobby; a Match.Spectate(true) then is kept pending
 ("FL-0130", C2+"RulerSpectateController.luau", 'if on and self._phase ~= nil and Def.END_PHASES[self._phase] then', 'if false then', "WarFeedback", "never starts during Results or Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", '\tself._phase = phase\n', '', "WarFeedback", "never starts during Results or Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", 'elseif self._pending and not self.active then', 'elseif false then', "WarFeedback", "never starts during Results or Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", '\t\tself._pending = true\n', '', "WarFeedback", "never starts during Results or Lobby", "game"),
 ("FL-0130", C2+"RulerSpectateController.luau", '\t\tself._pending = false\n', '', "WarFeedback", "never starts during Results or Lobby", "game"),
 ("FL-0130", C2+"RulerCameraController.luau", 'keepaliveSec = 1, moveStuds = 10 })', 'keepaliveSec = 1, moveStuds = 0 })', "RulerCamera", "reports the overview's focus for interest", "game"),
]
