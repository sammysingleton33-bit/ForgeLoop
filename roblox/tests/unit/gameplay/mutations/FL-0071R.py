"""FL-0071R mutation rows (Crown Arena duel runner: Arena/DuelRunner; CONTRACTS G12.2 / G12.4).
Run by ../mutations.py (`mutations.py FL-0071R`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
DR = G + "src/shared/Arena/DuelRunner.luau"
M = [
 # --- actions
 ("FL-0071R", DR, 'if not self._started or self._result ~= nil then\n\t\treturn false, "no_duel"', 'if false then\n\t\treturn false, "no_duel"', "sim/DuelRunner", "refuses actions quietly before the duel starts"),
 ("FL-0071R", DR, 'if not self._started or self._result ~= nil then\n\t\treturn false, "no_duel"', 'if not self._started then\n\t\treturn false, "no_duel"', "sim/DuelRunner", "refuses actions after the duel is over"),
 ("FL-0071R", DR, 'if not s.isAI and s.userId == userId then', 'if s.userId == userId then', "sim/DuelRunner", "the AI\'s id"),
 ("FL-0071R", DR, 'if side == nil then\n\t\treturn false, "not_champion"', 'if false then\n\t\treturn false, "not_champion"', "sim/DuelRunner", "refuses actions quietly before the duel starts"),
 ("FL-0071R", DR, 'if type(action) ~= "string" or not ACTIONS[action] then', 'if false then', "sim/DuelRunner", "refuses actions quietly before the duel starts"),
 ("FL-0071R", DR, 'bucket.tokens = math.min(rate.burst, bucket.tokens + math.max(0, now - bucket.at) * rate.perSecond)', 'bucket.tokens = bucket.tokens + math.max(0, now - bucket.at) * rate.perSecond', "sim/DuelRunner", "rate limits a champion"),
 ("FL-0071R", DR, 'if bucket.tokens < 1 then', 'if bucket.tokens < 0 then', "sim/DuelRunner", "rate limits a champion"),
 # --- geometry
 ("FL-0071R", DR, 'local inRange = distance <= self._cfg.reach', 'local inRange = true', "sim/DuelRunner", "a swing from too far away"),
 ("FL-0071R", DR, 'local inRange = distance <= self._cfg.reach', 'local inRange = distance < self._cfg.reach - 1', "sim/DuelRunner", "a swing from too far away"),
 ("FL-0071R", DR, '>= self._cfg.facingMinDot', '>= -1', "sim/DuelRunner", "facing away"),
 ("FL-0071R", DR, '>= self._cfg.facingMinDot', '>= 0.99', "sim/DuelRunner", "a swing 45 degrees off the line"),
 ("FL-0071R", DR, 'if missingHuman then\n\t\t\treturn false, false', 'if false then\n\t\t\treturn false, false', "sim/DuelRunner", "cannot hit"),
 ("FL-0071R", DR, 'if pose == nil then\n\t\treturn true, true', 'if pose == nil then\n\t\treturn false, false', "sim/DuelRunner", "virtual"),
 ("FL-0071R", DR, 'local missingHuman = (mine == nil and not self._sides[side].isAI)\n\t\t\tor (theirs == nil and not self._sides[other].isAI)', 'local missingHuman = (mine == nil and not self._sides[side].isAI)', "sim/DuelRunner", "cannot hit"),
 ("FL-0071R", DR, '\t\tfacing = true\n\tend', '\t\tfacing = false\n\tend', "sim/DuelRunner", "the same position is in range and facing"),
 # --- the caps
 ("FL-0071R", DR, 'local ok, reason = Caps.check(list)\n\tif ok then\n\t\treturn list\n\tend', 'local ok, reason = true, nil\n\tif ok then\n\t\treturn list\n\tend', "sim/DuelRunner", "drops the perks"),
 ("FL-0071R", DR, 'if type(modifier) == "table" and modifier.kind == "passive" and not modifier.slot then', 'if type(modifier) == "table" and modifier.kind == "passive" then', "sim/DuelRunner", "a slotted passive is a perk"),
 ("FL-0071R", DR, 'if Caps.check(blessing) then\n\t\treturn blessing\n\tend', 'if true then\n\t\treturn blessing\n\tend', "sim/DuelRunner", "drops everything when even the blessing breaks a cap"),
 # --- time
 ("FL-0071R", DR, 'local elapsed = math.min(math.max(0, now - (self._last :: number)), self._cfg.maxCatchup)', 'local elapsed = math.max(0, now - (self._last :: number))', "sim/DuelRunner", "never catches up on more than maxCatchup"),
 ("FL-0071R", DR, '\tif not self._started then\n\t\tself._started = true\n\t\tself._last = now\n\t\treturn out\n\tend', '\tif not self._started then\n\t\tself._started = true\n\t\tself._last = 0\n\t\treturn out\n\tend', "sim/DuelRunner", "the first step only starts the clock"),
 ("FL-0071R", DR, 'while self._acc >= tick - 1e-9 and self._result == nil do', 'if self._acc >= tick - 1e-9 and self._result == nil then', "sim/DuelRunner", "steps in fixed ticks"),
 ("FL-0071R", DR, 'self._nextSnapshot = model.t + cfg.snapshotEvery', 'self._nextSnapshot = model.t + 1', "sim/DuelRunner", "public snapshot every snapshotEvery"),
 ("FL-0071R", DR, 'if model.t >= self._nextSnapshot and not model.ended then', 'if model.t >= self._nextSnapshot then', "sim/DuelRunner", "the last word is ended"),
 # --- blocks
 ("FL-0071R", DR, 'if action == nil and model.t - since >= cfg.blockMaxSeconds then', 'if false then', "sim/DuelRunner", "releases a block the client never ends"),
 ("FL-0071R", DR, 'if action == nil and model.t - since >= cfg.blockMaxSeconds then', 'if action == nil and model.t - since >= 0.5 then', "sim/DuelRunner", "stays up"),
 ("FL-0071R", DR, '\t\telse\n\t\t\tself._blockSince[side] = nil\n\t\tend', '\t\telse\n\t\t\tlocal _ = 0\n\t\tend', "sim/DuelRunner", "a fresh block starts a fresh clock"),
 # --- the relay
 ("FL-0071R", DR, 'damageShare = data.damage / model.config.maxHp', 'damageShare = data.damage', "sim/DuelRunner", "shares only"),
 ("FL-0071R", DR, 'data = { impactIn = math.max(0, data.impactAt - event.t), warned = data.warned or 0 },', 'data = { impactAt = data.impactAt, impactIn = math.max(0, data.impactAt - event.t), warned = data.warned or 0 },', "sim/DuelRunner", "relays only the contract\'s kinds"),
 ("FL-0071R", DR, 'return (string.gsub(source, "^perk:", ""))', 'return source', "sim/DuelRunner", "a fired trigger is relayed by id"),
 ("FL-0071R", DR, 'data = { trigger = trigger, citizenName = if citizen then citizen.name else nil },', 'data = { trigger = trigger, citizenName = "Someone" },', "sim/DuelRunner", "the Crowd Rally has no citizen"),
 ("FL-0071R", DR, 'elseif kind == "parry" or kind == "stagger" or kind == "staminaOut" or kind == "hype" then', 'elseif kind == "parry" or kind == "stagger" or kind == "staminaOut" or kind == "hype" or kind == "miss" or kind == "dodged" then', "sim/DuelRunner", "a swing that misses is not relayed"),
 ("FL-0071R", DR, 'local winner = if model.winner == "a" or model.winner == "b" then model.winner else "draw"', 'local winner = "a"', "sim/DuelRunner", "play a duel to the end"),
 # --- forfeits
 ("FL-0071R", DR, 'local winner = if otherGone then "draw" else other', 'local winner = other', "sim/DuelRunner", "both champions gone is a draw"),
 ("FL-0071R", DR, 'local winner = if otherGone then "draw" else other', 'local winner = "draw"', "sim/DuelRunner", "a champion who leaves loses"),
 ("FL-0071R", DR, 'if self._result ~= nil then\n\t\treturn out\n\tend\n\tlocal side = if type(userId) == "number"', 'if false then\n\t\treturn out\n\tend\n\tlocal side = if type(userId) == "number"', "sim/DuelRunner", "a champion who leaves loses"),
]
