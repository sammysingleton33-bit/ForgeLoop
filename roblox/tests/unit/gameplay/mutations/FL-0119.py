"""FL-0119 mutation rows, run by ../mutations.py (`mutations.py FL-0119`).

One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/. Add rows for
FL-0119 here only.
"""
SIM = G + "src/shared/Sim/Simulation.luau"
SVC = G + "src/server/Services/BuildingService.luau"
LAY = G + "src/shared/Kingdom/Layout.luau"
M = [
 # --- validation: where a building may stand
 ("FL-0119", SIM, '	if keepOnly then\n		return false\n	end\n', '', "BuildingMove", "destinations stay inside the keep's own circle"),
 ("FL-0119", SIM, '		if not b.destroyed and b.id ~= ignoreId then', '		if not b.destroyed then', "BuildingMove", "a building does not block itself"),
 ("FL-0119", SIM, 'if Footprint.overlapsCircle(shape, o.x, o.z, o.radius, gap) then', 'if false then', "BuildingMove", "refuses what Build.Place would refuse"),
 ("FL-0119", SIM, '	for _, area in self.noBuild do', '	for _, area in {} do', "BuildingMove", "the no-build areas"),
 ("FL-0119", SIM, 'if Footprint.overlapsCircle(shape, u.x, u.z, UNIT_BODY, 0) then', 'if false then', "BuildingMove", "placing or moving onto a soldier"),
 ("FL-0119", SIM, 'if Footprint.overlapsCircle(shape, pos.x, pos.z, clearance, 0) then', 'if false then', "BuildingMove", "keeps 3 studs clear"),
 # --- who and when
 ("FL-0119", SIM, '	if b.kind == "keep" then\n		return nil, "not_movable"', '	if false then\n		return nil, "not_movable"', "BuildingMove", "refuses the keep"),
 ("FL-0119", SIM, '	if sameSpot(b, x, z, yaw) then\n		return b, nil, true', '	if false then\n		return b, nil, true', "BuildingMove", "a move to the same spot and facing succeeds"),
 ("FL-0119", SIM, '	if kingdom.alarm then\n		return nil, "alarm"', '	if false then\n		return nil, "alarm"', "BuildingMove", "refuses while the alarm rings"),
 ("FL-0119", SIM, 'if kingdom.moveLockedUntil ~= nil and self.time < kingdom.moveLockedUntil then', 'if false then', "BuildingMove", "after a war declaration or a peace nothing"),
 ("FL-0119", SIM, 'if self:_underAttack(b, shape) then', 'if false then', "BuildingMove", "an at-war unit that targets or focuses the building"),
 ("FL-0119", SIM, 'if b.movedAt ~= nil and self.time - b.movedAt < tuning.moveCooldown then', 'if false then', "BuildingMove", "waits the cooldown between moves"),
 ("FL-0119", SIM, '	if b.burning then\n		return true', '	if false then\n		return true', "BuildingMove", "damaged in the last 10 seconds, and a burning one"),
 ("FL-0119", SIM, 'if b.damagedAt ~= nil and self.time - b.damagedAt < tuning.moveDamageWindow then', 'if false then', "BuildingMove", "damaged in the last 10 seconds, and a burning one"),
 ("FL-0119", SIM, 'or (focus and focus.kind == "building" and focus.id == b.id)', '', "BuildingMove", "targets or focuses the building"),
 ("FL-0119", SIM, 'range + tuning.moveThreatReach', 'range', "BuildingMove", "within its range plus 30 of where the building stands"),
 ("FL-0119", SIM, '\n				or Footprint.overlapsCircle(newShape, u.x, u.z, reach, 0)', '', "BuildingMove", "and of where it would stand"),
 ("FL-0119", SIM, '		if self:atWar(b.kingdomId, u.kingdomId) then', '		if true then', "BuildingMove", "a kingdom at peace is no threat"),
 # --- what stays with the building
 ("FL-0119", SIM, '	b.shape = self:shapeOf(b.kind, x, z, yaw)\n	b.slotId = slotId', '	b.slotId = slotId', "BuildingMove", "moves a finished house to free ground"),
 ("FL-0119", SIM, '	b.slotId = slotId\n	b.movedAt = self.time', '	b.movedAt = self.time', "BuildingMove", "a move frees the slot id"),
 ("FL-0119", SIM, '			if c.phase == "Work" or c.phase == "Rest" then\n				c.phase = "Go"\n			end', '', "BuildingMove", "farm workers, builders and sleepers walk"),
 ("FL-0119", SIM, '			c._route = nil\n		end\n	end\n	self:emit("BuildingMoved"', '		end\n	end\n	self:emit("BuildingMoved"', "BuildingMove", "farm workers, builders and sleepers walk"),
 ("FL-0119", SIM, '	self:emit("BuildingMoved", {', '	self:emit("BuildingPlaced", {', "BuildingMove", "moves a finished house to free ground"),
 # --- drop-offs settle
 ("FL-0119", SIM, 'b.settleUntil = self.time + self.catalog.tuning.moveSettle', 'b.settleUntil = nil', "BuildingMove", "a moved lumber camp settles"),
 ("FL-0119", SIM, 'def.dropoff and accepts and not settling then', 'def.dropoff and accepts then', "BuildingMoveExploits", "drop-off chasing"),
 ("FL-0119", SIM, 'if stats.gatherBonus and not b.burning and not settling then', 'if stats.gatherBonus and not b.burning then', "BuildingMove", "a moved lumber camp settles"),
 ("FL-0119", SIM, 'accepts and not settling then', 'accepts then', "BuildingMove", "a moved lumber camp settles"),
 ("FL-0119", SIM, 'b.settleUntil == nil or self.time >= b.settleUntil then', 'b.settleUntil == nil or false then', "BuildingMove", "a moved lumber camp settles"),
 # --- war lockout and damage stamp
 ("FL-0119", G + "src/shared/Sim/Diplomacy.luau", '		lockMoves(s, kingdom, target)\n', '', "BuildingMoveExploits", "peacetime trap"),
 ("FL-0119", G + "src/shared/Sim/Diplomacy.luau", '		lockMoves(s, kingdom, from)\n', '', "BuildingMove", "after a war declaration or a peace nothing"),
 ("FL-0119", G + "src/shared/Sim/Military.luau", '		target.damagedAt = sim.time', '', "BuildingMove", "a siege hit stamps the building"),
 # --- the command
 ("FL-0119", G + "src/shared/Sim/Commands.luau", '		or not finite(yaw)\n		or (slotId ~= nil and not isId(slotId))', '		or (slotId ~= nil and not isId(slotId))', "BuildingMove", "refuses bad arguments"),
 # --- the remotes
 ("FL-0119", SVC, 'b.slotId == slotId and b.id ~= ignoreId then', 'b.slotId == slotId then', "BuildingService", "seats a building on a free slot of its kingdom"),
 ("FL-0119", SVC, 'and Footprint.overlaps(rect, b.shape, sim.catalog.tuning.placementGap)', 'and Footprint.overlaps(rect, b.shape, 0)', "BuildingService", "within the placement gap of it"),
 ("FL-0119", SVC, '	if Def.NOT_ON_PLOT[b.kind] then\n		return false, "not_on_plot"', '	if false then\n		return false, "not_on_plot"', "BuildingService", "refuses an occupied slot, a foreign one"),
 ("FL-0119", SVC, '	if self:_occupant(kingdomId, slotId, b.id) then\n		return false, "slot_occupied"', '	if false then\n		return false, "slot_occupied"', "BuildingService", "refuses an occupied slot, a foreign one"),
 ("FL-0119", SVC, '				"%.2f|%.2f|%.3f",\n				b.x,\n				b.z,\n				b.yaw\n', '				"%.2f|%.2f|%.3f",\n				0,\n				0,\n				0\n', "BuildingService", "re-sends a moved building"),
 ("FL-0119", G + "src/shared/Build/Remotes.luau", 'name = "Build.Move",\n		kind = "function",\n		args = { BUILDING_ID, Validate.vector3(4000), Validate.integer(0, 3) },\n		rate = { burst = 4, perSecond = 2 },', 'name = "Build.Move",\n		kind = "function",\n		args = { BUILDING_ID, Validate.vector3(4000), Validate.integer(0, 3) },\n		rate = { burst = 400, perSecond = 200 },', "BuildingService", "rate-limits the remotes"),
 ("FL-0119", G + "src/shared/Build/Remotes.luau", 'args = { BUILDING_ID, Validate.string(1, 32), Validate.optional(Validate.integer(0, 3)) },', 'args = { BUILDING_ID, Validate.string(1, 32), Validate.optional(Validate.integer(0, 99)) },', "BuildingService", "drops bad arguments"),
 # --- the relay and the view
 ("FL-0119", G + "src/shared/Kingdom/MatchHost.luau", 'elseif name == "BuildingMoved" then', 'elseif name == "BuildingMovedX" then', "BuildingService", "CanMove agrees with Move"),
 ("FL-0119", G + "src/shared/Sim/WorldView.luau", '	elseif self._kitPose[key] ~= pose then', '	elseif false then', "WorldView", "re-pivots the same Kit model"),
 # --- the no-build areas
 ("FL-0119", LAY, 'for _, field in WorldLayout.features.fields do\n	table.insert(RESERVED,', 'for _, field in {} do\n	table.insert(RESERVED,', "NoBuildAreas", "lists 12 crop fields"),
 ("FL-0119", LAY, '		sim.noBuild = Layout.reservedAreas()', '		sim.noBuild = {}', "NoBuildAreas", "gives them to the simulation"),
 ("FL-0119", LAY, '	return table.clone(SLOTS)\nend', '	return {}\nend', "NoBuildAreas", "keepOutAreas lists every slot"),
 ("FL-0119", LAY, 'local SPAWN_PAD, PLOT_ROAD_REACH = 16, 130', 'local SPAWN_PAD, PLOT_ROAD_REACH = 16, 10', "NoBuildAreas", "covers the spawn point, the avenue"),
 ("FL-0119", LAY, 'local SPAWN_PAD, PLOT_ROAD_REACH = 16, 130', 'local SPAWN_PAD, PLOT_ROAD_REACH = 1, 130', "NoBuildAreas", "covers the spawn point, the avenue"),
]
