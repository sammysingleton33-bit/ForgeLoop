"""FL-0140 mutation rows (the Crown Arena's bodies, gear and venue: ArenaService + Arena/Figures).
Run by ../mutations.py (`mutations.py FL-0140`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AS = G + "src/server/Services/ArenaService.luau"
FG = G + "src/shared/Arena/Figures.luau"
M = [
 ("FL-0140", AS, 'return figures:poseOf(userId) -- an AI champion stands where its figure does', 'return nil', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", AS, '\t\tself._match.host:snapRuler(userId)\n', '\t\tlocal _ = userId\n', "sim/ArenaService", "tells the sim a champion was moved"),
 ("FL-0140", AS, '\tself:_releaseAll()\n\tself:_clearFigures()\n\tself._flow, self._runner = nil, nil\n\tself._remotes:fireAll("Arena.State", IDLE_STATE)\n\tself._match:arenaEnded(winner)', '\tself:_releaseAll()\n\tself._flow, self._runner = nil, nil\n\tself._remotes:fireAll("Arena.State", IDLE_STATE)\n\tself._match:arenaEnded(winner)', "sim/ArenaService", "back to neutral"),
 ("FL-0140", AS, '\tflow:cancel(reason)\n\tself:_publish()\n\tself:_releaseAll()\n\tself:_clearFigures()\n', '\tflow:cancel(reason)\n\tself:_publish()\n\tself:_releaseAll()\n', "sim/ArenaService", "when the match calls the arena off"),
 ("FL-0140", AS, '\t\tfigures:dress(venue, colors.a, colors.b)\n', '\t\tlocal _ = colors\n', "sim/ArenaService", "dresses the venue in the two qualifiers' colours"),
 ("FL-0140", AS, '\t\tfigures:reset(venue)\n', '\t\tlocal _ = venue\n', "sim/ArenaService", "dresses the venue in the two qualifiers' colours"),
 ("FL-0140", AS, 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 0.7, ring)', 'local _ = step', "sim/ArenaService", "walks the AI figure up to its opponent"),
 ("FL-0140", AS, '\t\t\tself:_wear(champion, character) -- the gear stayed on the old character\n', '', "sim/ArenaService", "dresses a champion who resets again"),
 ("FL-0140", AS, '\t\t\t\tself:_wear(champion, character)\n', '', "sim/ArenaService", "puts the loadout's weapon and armour on a human champion"),
 ("FL-0140", FG, 'pcall(kit.character, "governor", "idle", spec.color, spec.look, spec.kingdom)', 'pcall(kit.character, "citizen", "idle", spec.color, spec.look, spec.kingdom)', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", FG, '\tmodel:SetAttribute("ArenaSide", spec.side)\n', '', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", FG, '\t\t\tself._collection:AddTag(model, "ArenaChampion")\n', '\t\t\tlocal _ = model\n', "sim/ArenaService", "stands an AI champion on its mark"),
 ("FL-0140", AS, 'local step = dt * self.config.ring.walkSpeed\n', 'local step = dt * self.config.ring.walkSpeed * 2\n', "sim/ArenaService", "never moves the AI figure faster than the fixed WalkSpeed"),
 ("FL-0140", FG, '\t\t\tif out > ring.radius then', '\t\t\tif false then', "sim/ArenaService", "keeps the AI figure inside the ring"),
 ("FL-0140", AS, 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 0.7, ring)', 'figures:approach(champion.userId, target.x, target.z, step, self.config.reach * 3, ring)', "sim/ArenaService", "stays within its reach"),
 ("FL-0140", FG, 'Figures.FEET_BELOW_MARK = 3', 'Figures.FEET_BELOW_MARK = 0', "sim/ArenaService", "stands the AI figure's feet on the floor"),
 ("FL-0140", FG, 'local position = pivotOf(model).Position -- the feet', 'local position = root.CFrame.Position -- the feet', "sim/ArenaService", "stands the AI figure's feet on the floor"),
 ("FL-0140", FG, 'root.CFrame = cframe * (if offsetOk and offset ~= nil then offset:Inverse() else CFrame.new())', 'root.CFrame = cframe', "sim/ArenaService", "stands the AI figure's feet on the floor"),
 ("FL-0140", FG, '\tlocal toolPart = stripOwnWeapon(model)\n', '\tlocal toolPart = partNamed(model, "Tool")\n', "sim/ArenaService", "holds the loadout weapon up from"),
 ("FL-0140", FG, '\ttoolPart.Transparency = 1\n', '', "sim/ArenaService", "holds the loadout weapon up from"),
 ("FL-0140", FG, 'if d.Part0 == toolPart and d.Part1 ~= nil then', 'if false then', "sim/ArenaService", "holds the loadout weapon up from"),
 ("FL-0140", FG, 'local carrier = toolPart or fist', 'local carrier = fist', "sim/ArenaService", "holds the loadout weapon up from"),
 ("FL-0140", FG, 'if gripOk then grip else nil', 'nil', "sim/ArenaService", "holds the loadout weapon up from"),
 ("FL-0140", FG, 'return head, if head then CFrame.new(0, head.Size.Y / 2, 0) else nil', 'return head, if head then CFrame.new(0, -head.Size.Y / 2, 0) else nil', "sim/ArenaService", "puts the armour on the body parts it names"),
 ("FL-0140", FG, 'local part, offset = fitOf(model, child.Name)', 'local part, offset = fitOf(model, "HatAttachment")', "sim/ArenaService", "puts the armour on the body parts it names"),
 ("FL-0140", FG, 'return { x = position.X, z = position.Z, fx = look.X / length, fz = look.Z / length }', 'return { x = position.X, z = position.Z, fx = -look.X / length, fz = -look.Z / length }', "sim/ArenaService", "turns the AI figure to face its opponent"),
 ("FL-0140", FG, 'CFrame.lookAt(Vector3.new(x, position.Y, z), Vector3.new(tx, position.Y, tz))', 'CFrame.lookAt(Vector3.new(x, position.Y, z), Vector3.new(2 * x - tx, position.Y, 2 * z - tz))', "sim/ArenaService", "turns the AI figure to face its opponent"),
 ("FL-0140", AS, 'math.clamp(now - last, 0, self.config.maxCatchup)', 'math.max(now - last, 0)', "sim/ArenaService", "lets a stall of the server's clock move the AI figure"),
 ("FL-0140", AS, 'figures:dress(venue, colors.a, colors.b)', 'figures:dress(venue, colors.b, colors.a)', "sim/ArenaService", "dresses the venue's side A"),
 ("FL-0140", AS, 'ring.x, ring.z, ring.height)\n\t\t\tself:_snap(champion.userId)\n', 'ring.x, ring.z, ring.height)\n', "sim/ArenaService", "tells the sim again when a champion is put back"),
 ("FL-0140", AS, '\tself:_releaseAll()\n\tself:_clearFigures()\n\tself.stageChanged:disconnectAll()', '\tself:_releaseAll()\n\tself.stageChanged:disconnectAll()', "sim/ArenaService", "when the arena is destroyed mid-duel"),
 ("FL-0140", FG, '\t\t\tself._folder:Destroy()\n', '\t\t\tlocal _ = self._folder\n', "sim/ArenaService", "takes the figure and the gear away after the crowning"),
]
