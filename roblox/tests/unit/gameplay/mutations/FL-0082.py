"""FL-0082 mutation rows for the D-050 (1) follow-up (burning halts production, the building heals, rioters are
their own state), run by ../mutations.py (`mutations.py FL-0082`; the runner arrives with FL-0119's PR).

One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
SIM = G + "src/shared/Sim/Simulation.luau"
CONS = G + "src/server/Services/ConsequenceService.luau"
M = [
 # --- burning halts production
 ("FL-0082", SIM, 'for _, resource in if stats.gatherBonus and not b.burning and not settling then', 'for _, resource in if stats.gatherBonus and not settling then', "BurningBuildings", "takes no deliveries and gives no gather bonus"),
 ("FL-0082", SIM, 'if not b.destroyed and not b.burning and b.level >= 1 and def.dropoff and accepts and not settling then', 'if not b.destroyed and b.level >= 1 and def.dropoff and accepts and not settling then', "BurningBuildings", "takes no deliveries and gives no gather bonus"),
 ("FL-0082", SIM, 'if b.pendingLevel ~= nil and not b.destroyed and not b.burning and self:_freeSlot(b, "site", citizen) then', 'if b.pendingLevel ~= nil and not b.destroyed and self:_freeSlot(b, "site", citizen) then', "BurningBuildings", "offers no farm or build work"),
 ("FL-0082", SIM, '				and not b.burning\n', '', "BurningBuildings", "offers no farm or build work"),
 ("FL-0082", SIM, 'if c.target == b.id and (c.activity == "Farm" or c.activity == "Build") then', 'if false then', "BurningBuildings", "stop at once and choose again"),
 # --- it heals, no permanent damage
 ("FL-0082", SIM, 'b.hpBeforeFire = b.hpBeforeFire or b.hp', 'b.hpBeforeFire = nil', "BurningBuildings", "climbs at regenPerSecond"),
 ("FL-0082", SIM, 'local goal = math.min(b.maxHp, b.hpBeforeFire or b.hp)', 'local goal = b.maxHp', "BurningBuildings", "climbs at regenPerSecond"),
 ("FL-0082", SIM, 'b.hp = math.min(goal, b.hp + b.maxHp * (b.regenPerSecond or 0) * dt)', 'b.hp = math.min(goal, b.hp + b.maxHp * (b.regenPerSecond or 0) * dt * 100)', "BurningBuildings", "climbs at regenPerSecond"),
 ("FL-0082", G + "config/Society.luau", 'regenPerSecond = 0.002,', 'regenPerSecond = 0,', "ConsequenceService", "heals itself afterwards"),
 ("FL-0082", CONS, 'self:_sim():setBurning(riot.building, false, self.config.consequences.riot.regenPerSecond)', 'self:_sim():setBurning(riot.building, false)', "ConsequenceService", "heals itself afterwards"),
 # --- rioters are a state of their own
 ("FL-0082", SIM, 'citizen.riotUntil = math.max(citizen.riotUntil or 0, self.time + seconds)', 'citizen.strikeUntil = math.max(citizen.strikeUntil or 0, self.time + seconds)', "BurningBuildings", "stops work like a strike"),
 ("FL-0082", G + "src/shared/Sim/CitizenBrain.luau", 'if world:isRioting(citizen) then', 'if false then', "BurningBuildings", "stops work like a strike"),
 ("FL-0082", CONS, '	self:_announceRiot(kid, rioters, true)', '	self:_announceStrike(kid, rioters)', "ConsequenceService", "rioters wear their own placard"),
 ("FL-0082", CONS, '	self:_announceRiot(kid, riot.rioters, false)\n', '', "ConsequenceService", "rioters wear their own placard"),
 ("FL-0082", CONS, '	self:_holdOffWork(rioters, true)', '	self:_holdOffWork(rioters)', "ConsequenceService", "prolonged instability with an instigator"),
 ("FL-0082", G + "src/client/Controllers/EntityController.luau", 'local isRiot = e.occupation == EventCodec.RIOT', 'local isRiot = false', "EntityController", "turns a strike event marked EventCodec.RIOT"),
 # --- G9 ConsequenceChanged (v0.4-g10c): once per start and end, the signal's values plus a count
 ("FL-0082", CONS, '	GameEvents.ConsequenceChanged:fire(kid, rule, on, table.clone(info))\n', '', "ConsequenceService", "an occupation aggrieved for strike.sustainSeconds strikes"),
 ("FL-0082", CONS, '	GameEvents.ConsequenceChanged:fire(kid, rule, on, table.clone(info))\n', '	GameEvents.ConsequenceChanged:fire(kid, rule, on, table.clone(info))\n	GameEvents.ConsequenceChanged:fire(kid, rule, on, table.clone(info))\n', "ConsequenceService", "an occupation aggrieved for strike.sustainSeconds strikes"),
 ("FL-0082", CONS, 'info.count = if info.entityIds then #info.entityIds elseif info.buildingId then 1 else 0', 'info.count = 0', "ConsequenceService", "an occupation aggrieved for strike.sustainSeconds strikes"),
 ("FL-0082", CONS, 'info.count = if info.entityIds then #info.entityIds elseif info.buildingId then 1 else 0', 'info.count = if info.entityIds then #info.entityIds elseif info.buildingId then 2 else 0', "ConsequenceService", "the fire never burns below fireFloor"),
 ("FL-0082", CONS, '{ occupation = occupation, count = #still }', '{ occupation = occupation, count = 0 }', "ConsequenceService", "ends when the strikers' mean loyalty rises"),
 ("FL-0082", CONS, '{ count = shortage.count }', '{ count = 0 }', "ConsequenceService", "holds between fedBelow and endFedAbove"),
 ("FL-0082", CONS, '		state.shortage.count = #hungry', '		state.shortage.count = 0', "ConsequenceService", "holds between fedBelow and endFedAbove"),
 ("FL-0082", CONS, '	self.changed:fire(kid, rule, on, info)\n', '', "ConsequenceService", "an occupation aggrieved for strike.sustainSeconds strikes"),
]
