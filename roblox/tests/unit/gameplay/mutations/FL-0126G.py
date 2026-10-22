"""FL-0126G mutation rows (Build.PlaceGate: Simulation:placeGate, Commands.PlaceGate, BuildingService.placeGate).
Run by ../mutations.py (`mutations.py FL-0126G`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
SM = G + "src/shared/Sim/Simulation.luau"
CM = G + "src/shared/Sim/Commands.luau"
M = [
 ("FL-0126G", SM, 'if wall.kind ~= "wall" then', 'if false then', "sim/Gate", "refuses what is not the player's wall"),
 ("FL-0126G", SM, 'if def.maxCount and self:countOf(kingdom, "gate") >= def.maxCount then', 'if false then', "sim/Gate", "allows one gate per kingdom"),
 ("FL-0126G", SM, 'if wall.level > 0 and wall.pendingLevel ~= nil then', 'if false then', "sim/Gate", "refuses a wall being upgraded, or under attack"),
 ("FL-0126G", SM, 'if self:_underAttack(wall, self:shapeOf("gate", wall.x, wall.z, wall.yaw)) then', 'if false then', "sim/Gate", "refuses a wall being upgraded, or under attack"),
 ("FL-0126G", SM, 'self:_geometry(kingdom, "gate", wall.x, wall.z, wall.yaw, wall.id)', 'self:_geometry(kingdom, "gate", wall.x, wall.z, wall.yaw, nil)', "sim/Gate", "turns a wall piece into a gate in place"),
 ("FL-0126G", SM, 'refund[res] = math.floor(amount * self.catalog.tuning.cancelRefund)', 'refund[res] = amount', "sim/Gate", "turns a wall piece into a gate in place"),
 ("FL-0126G", SM, 'refund[res] = math.floor(amount * self.catalog.tuning.cancelRefund)', 'refund[res] = 0', "sim/Gate", "turns a wall piece into a gate in place"),
 ("FL-0126G", SM, 'if self:balance(kingdom.id, res) + (refund[res] or 0) < amount then', 'if self:balance(kingdom.id, res) < amount then', "sim/Gate", "counts the wall's refund towards the gate's price"),
 ("FL-0126G", SM, '\tself:_removeBuilding(wall)\n\tlocal gate = self:_createBuilding(kingdom, "gate", wall.x, wall.z, wall.yaw)', '\tlocal gate = self:_createBuilding(kingdom, "gate", wall.x, wall.z, wall.yaw)', "sim/Gate", "turns a wall piece into a gate in place"),
 ("FL-0126G", SM, 'local gate = self:_createBuilding(kingdom, "gate", wall.x, wall.z, wall.yaw)', 'local gate = self:_createBuilding(kingdom, "gate", wall.x, wall.z, 0)', "sim/Gate", "turns a wall piece into a gate in place"),
 ("FL-0126G", CM, 'if not isBuildingId(wallId) then', 'if false then', "sim/Gate", "is the PlaceGate command"),
]
