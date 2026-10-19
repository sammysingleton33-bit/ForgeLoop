"""FL-0141 mutation rows, run by ../mutations.py (FL-0141 only: `mutations.py FL-0141`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0141 here only (D-038 (7)).
"""
P = F + "DuelPoses.luau"
R = F + "DuelRig.luau"
A = C2 + "FeedbackDuelController.luau"
DP = "experience/DuelPoses"
FD = "experience/FeedbackDuel"
M = [
 # DuelPoses: events -> animations
 ("FL-0141", P, 'self:play("light", now)', 'local _ = now', DP, "a snapshot windup plays a light swing", "game"),
 ("FL-0141", P, 'if self:_attack(now) == nil then -- a second windup sample', 'if true then -- a second windup sample', DP, "a snapshot windup plays a light swing", "game"),
 ("FL-0141", P, 'anim.start = now - anim.windup', 'anim.start = anim.start', DP, "the hit jumps a winding-up swing", "game"),
 ("FL-0141", P, 'if now - self._lastStrike < DuelPoses.RECENT_STRIKE then\n\t\treturn\n\tend', '', DP, "the hit jumps a winding-up swing", "game"),
 ("FL-0141", P, 'return math.clamp(w, DuelPoses.HEAVY_WINDUP.min, DuelPoses.HEAVY_WINDUP.max)', 'return w', DP, "heavyWindup holds the wind-up", "game"),
 ("FL-0141", P, 'track:play("heavy", now, { windup = impactIn })', 'track:play("heavy", now)', DP, "heavyWindup holds the wind-up", "game"),
 ("FL-0141", P, 'if self.state == "block" then\n\t\tself:play("guardHit", now)', 'if false then\n\t\tself:play("guardHit", now)', DP, "the target of a hit flinches", "game"),
 ("FL-0141", P, 'self:play(if heavy then "flinchHeavy" else "flinch", now)', 'self:play("flinch", now)', DP, "the target of a hit flinches", "game"),
 ("FL-0141", P, 'self[OTHER[side]]:hitBy(heavy, now)', 'track:hitBy(heavy, now)', DP, "the target of a hit flinches", "game"),
 ("FL-0141", P, 'self:play("block", now, { start = now - 0.12 })', 'local _ = now', DP, "the target of a hit flinches", "game"),
 ("FL-0141", P, 'return self.state ~= "block" -- held while the snapshot says block', 'return false', DP, "the target of a hit flinches", "game"),
 ("FL-0141", P, 'dir = if self._dodges % 2 == 1 then -1 else 1', 'dir = -1', DP, "parry, dodge and stagger", "game"),
 ("FL-0141", P, 'if not (anim ~= nil and anim.name == kind and now - anim.start < 0.1) then', 'if true then', DP, "parry, dodge and stagger", "game"),
 ("FL-0141", P, 'if current ~= nil and DuelPoses.PRIORITY[name] < current.priority then', 'if false then', DP, "priorities: a stagger cuts a swing", "game"),
 ("FL-0141", P, 'if self.final and DuelPoses.PRIORITY[name] < 4 then', 'if false then', DP, "the end: KO kneels the loser", "game"),
 ("FL-0141", P, 'if reason == "ko" then "ko" elseif reason == "timeCap" then "yield" else nil', 'if reason == "ko" then "yield" elseif reason == "timeCap" then "ko" else nil', DP, "the end: KO kneels the loser", "game"),
 ("FL-0141", P, 'elseif reason == "draw" then', 'elseif false then', DP, "the end: KO kneels the loser", "game"),
 ("FL-0141", P, 'weight, body = fade, body * fade', 'weight, body = 1, body', DP, "the end: KO kneels the loser", "game"),
 ("FL-0141", P, 'if self._weight < 1e-3 then', 'if false then', DP, "the end: KO kneels the loser", "game"),
 ("FL-0141", P, 't.style = DuelPoses.STYLE[view.weapon] or "slash"', 't.style = "slash"', DP, "the weapon sets the style", "game"),
 ("FL-0141", P, 'Head = { 5, 28, 0 },', 'Head = { 5, 35, 0 },', DP, "every key pose stays within LIMITS", "game"),
 ("FL-0141", P, 'local u = smooth((now - self._fromAt) / DuelPoses.XFADE)', 'local u = 1', DP, "crossfades: no joint jumps", "game"),
 ("FL-0141", P, 'weight, body = 1, if anim.full then 1 else 0', 'weight, body = 1, 1', DP, "weights: upper-body swings leave", "game"),
 ("FL-0141", P, 'source, weight, body = "stop", 0, 0', 'weight, body = 0, 0', DP, "weights: upper-body swings leave", "game"),
 ("FL-0141", P, 'if moving and anim.name == "stagger" then', 'if anim.name == "stagger" then', DP, "reduced motion keeps every pose", "game"),
 ("FL-0141", P, 'elseif moving and anim.name == "victory" and t > anim.length then', 'elseif anim.name == "victory" and t > anim.length then', DP, "reduced motion keeps every pose", "game"),
 ("FL-0141", P, 'if moving then\n\t\t\ttarget.Waist[1] += 1.5', 'if true then\n\t\t\ttarget.Waist[1] += 1.5', DP, "reduced motion keeps every pose", "game"),
 # DuelRig: the same pose on every rig, over the Animator
 ("FL-0141", R, 'local framed = entry.rest:Inverse() * value * entry.rest', 'local framed = value', DP, "an arm swung forward 90", "game"),
 ("FL-0141", R, 'write(joints.LeftLeg, undo * pose.LeftLeg, weight, true, io)', 'write(joints.LeftLeg, pose.LeftLeg, weight, true, io)', DP, "a whole-body lean keeps the legs upright", "game"),
 ("FL-0141", R, 'local undo = root.Rotation:Inverse()', 'local undo = CFrame.new()', DP, "a whole-body lean keeps the legs upright", "game"),
 ("FL-0141", R, 'write(joints.Tool, pose.Tool, weight, false, io)\n\t\twrite(joints.LeftLeg, undo * pose.LeftLeg, weight * body, false, io)', 'write(joints.Tool, pose.Tool, weight, false, io)\n\t\twrite(joints.LeftLeg, undo * pose.LeftLeg, weight, false, io)', DP, "over an avatar's Animator", "game"),
 ("FL-0141", R, 'if not owned and weight <= 0 then', 'if false then', DP, "over an avatar's Animator", "game"),
 ("FL-0141", R, 'base = current -- the Animator', 'base = IDENTITY -- the Animator', DP, "over an avatar's Animator", "game"),
 ("FL-0141", R, 'and not same(current, entry.last) then', 'then', DP, "over an avatar's Animator", "game"),
 ("FL-0141", R, 'if rig.kind == "kit" or (ok and typeof(current) == "CFrame" and same(current, entry.last)) then', 'if rig.kind == "kit" then', DP, "over an avatar's Animator", "game"),
 ("FL-0141", R, 'scale = if type(hip) == "number" and hip > 0 then hip / DuelRig.KIT_HIP else 1', 'scale = 1', DP, "Root's lift scales with the rig's legs", "game"),
 ("FL-0141", R, 'RightHand = "Tool",', '', DP, "the weapon's angle goes to R15's RightWrist", "game"),
 ("FL-0141", R, 'elseif isA(instance, "AnimationConstraint") then', 'elseif false then', DP, "scan finds each rig's kind", "game"),
 ("FL-0141", R, 'then "r15" elseif humanoid ~= nil then "r6" else "kit"', 'then "r15" else "kit"', DP, "scan finds each rig's kind", "game"),
 # FeedbackDuelController: who, when, cost, preview
 ("FL-0141", A, 'dependencies = { "DuelController" }', 'dependencies = {}', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'duel.events:connect(function(event)', 'duel.events:connect(function(_event)', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'duel.stateChanged:connect(function(state)', 'duel.stateChanged:connect(function(_state)', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'if okSide and value == side then', 'if okSide then', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'elseif self._running then', 'elseif false then', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'self:_releaseAll() -- after the fade', 'local _ = 0 -- after the fade', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'self._env.log("info", `{Def.name}: champion {side} is a {rig.kind} rig, {rig.count} {rig.class} joints`)', 'local _ = 0', FD, "depends on DuelController", "game"),
 ("FL-0141", A, 'if key ~= self._pair then', 'if false then', FD, "a new pair resets both", "game"),
 ("FL-0141", A, 'if entry.rig == nil and entry.lookedAt ~= nil and now - entry.lookedAt < Def.RESOLVE_SEC then', 'if entry.lookedAt ~= nil and now - entry.lookedAt < Def.RESOLVE_SEC then', FD, "a new pair resets both", "game"),
 ("FL-0141", A, 'local motion = not self:_reducedMotion()', 'local motion = true', FD, "reduced motion (SettingsController)", "game"),
 ("FL-0141", A, 'return -- no duel: the preview goes on', 'local _ = 0', FD, "Studio preview: your character plays every action", "game"),
 ("FL-0141", A, 'if type(state) == "table" and Def.STAGES[state.stage] then\n\t\treturn false -- a real duel', 'if false then\n\t\treturn false -- a real duel', FD, "Studio preview: your character plays every action", "game"),
 ("FL-0141", A, 'function Controller:preview(spec: any): boolean\n\tif not self:_isStudio() then', 'function Controller:preview(spec: any): boolean\n\tif false then', FD, "Studio preview: your character plays every action", "game"),
]
