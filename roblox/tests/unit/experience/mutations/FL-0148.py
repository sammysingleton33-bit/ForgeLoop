"""FL-0148 mutation rows (D-059: the start citizens look alive), run by ../mutations.py (`mutations.py FL-0148`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes S, C, X, G,
C2 and F come from mutations.py. The files are FORGE-01's (Sim/CitizenActions, Sim/Replication, Sim/Pose,
EntityController), edited by FORGE-04 under the one-PR exception forge04-citizens-alive.
"""
CA = G + "src/shared/Sim/CitizenActions.luau"
R = G + "src/shared/Sim/Replication.luau"
P = G + "src/shared/Sim/Pose.luau"
E = C2 + "EntityController.luau"
SC = "sim/CitizenActions"
SR = "sim/Replication"
SP = "sim/Pose.spec"
SE = "sim/EntityController"
SPREAD = "workers on one node stand apart on its reach circle"
RADIUS = "stands at each activity's own arrive radius"
LOWEST = "takes the lowest free slot"
KEEP = "on the keep itself"
MID = "on a middling target"
FACE = "at work with faceX/faceZ it faces them"
BLOWS = "works in blows that read from the air"
CARRY = "carries with both arms forward"
LOAD = "a carrying citizen holds Kit.carried(resource)"
PHASE = "a citizen that starts to work starts its blow from the beginning"
MOVED = "a moved farm or site gives its workers a new slot"
NOKINGDOM = "measures from +X for a worker without a kingdom"
DRAWN = "spaces slots for the drawn citizen"
SCALED = "draws every rig RIG_SCALE x the Kit size"
M = [
 # (a) work slots: Sim/CitizenActions
 ("FL-0148", CA, 'return if index % 2 == 1 then k else -k', 'return k', SC, SPREAD, "game"),
 ("FL-0148", CA, 'while used[index] do', 'while false do', SC, SPREAD, "game"),
 ("FL-0148", CA, 'if o ~= nil and o ~= c and o.target == c.target and o.slotTarget == c.target then', 'if o ~= nil and o ~= c and o.slotTarget == c.target then', SC, LOWEST, "game"),
 ("FL-0148", CA, 'if c.slotTarget ~= c.target or c.slotX == nil or c.slotAtX ~= x or c.slotAtZ ~= z then', 'if true then', SC, LOWEST, "game"),
 ("FL-0148", CA, 'or c.slotAtX ~= x or c.slotAtZ ~= z then', 'then', SC, MOVED, "game"),
 ("FL-0148", CA, 'if kingdom ~= nil then\n\t\t\tax, az', 'if true then\n\t\t\tax, az', SC, NOKINGDOM, "game"),
 ("FL-0148", CA, 'ax, az = kingdom.x - x, kingdom.z - z', 'ax, az = 1, 0', SC, SPREAD, "game"),
 ("FL-0148", CA, 'local side = if ax * ax + az * az > 1e-6 then math.atan2(az, ax) else 0', 'local side = if ax * ax + az * az > 1e-6 then math.atan2(az, ax) else math.pi', SC, KEEP, "game"),
 ("FL-0148", CA, 'local step = math.min(CitizenActions.SLOT_SPACING / radius, CitizenActions.SLOT_MAX_TURN)', 'local step = CitizenActions.SLOT_SPACING / radius', SC, RADIUS, "game"),
 ("FL-0148", CA, 'local step = math.min(CitizenActions.SLOT_SPACING / radius, CitizenActions.SLOT_MAX_TURN)', 'local step = CitizenActions.SLOT_MAX_TURN', SC, MID, "game"),
 ("FL-0148", CA, 'CitizenActions.SLOT_SPACING = 3.5 * 1.25', 'CitizenActions.SLOT_SPACING = 2.5', SC, KEEP, "game"),
 ("FL-0148", CA, 'CitizenActions.SLOT_SPACING = 3.5 * 1.25', 'CitizenActions.SLOT_SPACING = 3.5', SC, DRAWN, "game"),
 ("FL-0148", CA, 'CitizenActions.SLOT_MAX_TURN = math.rad(60)', 'CitizenActions.SLOT_MAX_TURN = math.rad(40)', SC, DRAWN, "game"),
 ("FL-0148", CA, 'c.faceX, c.faceZ = x, z', 'local _ = x', SC, SPREAD, "game"),
 ("FL-0148", CA, 'c.x, c.z = x, z\n\t\treturn true', 'return true', SC, SPREAD, "game"),
 ("FL-0148", CA, 'node.x, node.z, node.footprint + 1)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then', 'node.x, node.z, node.footprint + 1)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) then', SC, SPREAD, "game"),
 ("FL-0148", CA, 'b.x, b.z, b.footprint)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then', 'b.x, b.z, b.footprint)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) then', SC, RADIUS, "game"),
 ("FL-0148", CA, 'b.x, b.z, b.footprint + 1)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then', 'b.x, b.z, b.footprint + 1)\n\t\tif CitizenActions.moveTo(sim, c, sx, sz, 0, dt) then', SC, RADIUS, "game"),
 ("FL-0148", CA, 'local sx, sz = CitizenActions.workSpot(sim, c, b.x, b.z, b.footprint)\n', 'local sx, sz = b.x, b.z\n', SC, RADIUS, "game"),
 ("FL-0148", CA, 'if c.slotTarget ~= nil and c.slotTarget ~= c.target then', 'if false then', SC, LOWEST, "game"),
 # the hoe's top stays below the farmer's hat brim (FORGE-02's Kit tool/head clearance)
 ("FL-0148", P, 'out.RightArm = rx(45 + 60 * h)', 'out.RightArm = rx(45 + 75 * h)', "world/KitCharacter", "keeps every part welded to the tool clear of the head", "game"),
 # facing: Sim/Replication
 ("FL-0148", R, 'elseif e.phase == "Work" and e.faceX ~= nil and e.faceZ ~= nil then', 'elseif e.faceX ~= nil and e.faceZ ~= nil then', SR, FACE, "game"),
 ("FL-0148", R, 'elseif e.phase == "Work" and e.faceX ~= nil and e.faceZ ~= nil then', 'elseif false then', SR, FACE, "game"),
 ("FL-0148", R, 'if fx * fx + fz * fz > 1e-4 then\n\t\t\t\tyaw = math.atan2(-fx, -fz)', 'if true then\n\t\t\t\tyaw = math.atan2(-fx, -fz)', SR, FACE, "game"),
 # (b) swings: Sim/Pose
 ("FL-0148", P, 'out.RightArm = rx(35 + 105 * h)', 'out.RightArm = rx(35 + 55 * h)', SP, BLOWS, "game"),
 ("FL-0148", P, 'out.RightArm = rx(30 + 110 * h)', 'out.RightArm = rx(30 + 60 * h)', SP, BLOWS, "game"),
 ("FL-0148", P, 'out.Tool = rx(10 - 40 * h)', 'out.Tool = rx(10 + 40 * h)', "world/KitCharacter", "keeps every part welded to the tool clear of the head", "game"),
 ("FL-0148", P, 'out.RightArm = rx(40 + 80 * h)', 'out.RightArm = rx(40 + 40 * h)', SP, BLOWS, "game"),
 ("FL-0148", P, 'out.RightArm = rx(45 + 60 * h)', 'out.RightArm = rx(45 + 45 * h)', SP, BLOWS, "game"),
 ("FL-0148", P, 'chop = table.freeze({ 0.55, 0.15 }),', 'chop = table.freeze({ 0.4, 0.45 }),', SP, BLOWS, "game"),
 ("FL-0148", P, 'return 0\nend', 'return 0.5\nend', SP, BLOWS, "game"),
 ("FL-0148", P, 'lean = 35 - 30 * b', 'lean = 5', SP, BLOWS, "game"),
 ("FL-0148", P, 'lean = 30 - 22 * h', 'lean = 10', SP, "animates work by job", "game"),
 ("FL-0148", P, 'out.Torso = torso(-4 * k, 0, 0.18 * k * (1 - c2) / 2)', 'out.Torso = torso(-4 * k, 0, 0.08 * k * (1 - c2) / 2)', SP, CARRY, "game"),
 ("FL-0148", P, 'out.Torso = torso(-4 * k, 0, 0.18 * k * (1 - c2) / 2)', 'out.Torso = torso(0, 0, 0.18 * k * (1 - c2) / 2)', SP, CARRY, "game"),
 ("FL-0148", P, '\t\twork(o, Pose.workStyle(job), p)', '\t\twork(o, Pose.workStyle(job), (p + 0.5) % 1)', SP, BLOWS, "game"),
 # (c) carried loads and (d) the blow's start: EntityController
 ("FL-0148", E, 'self:_holdLoad(entity, nil, nil) -- never left on a pooled rig', 'local _ = entity', SE, LOAD, "game"),
 ("FL-0148", E, 'self:_holdLoad(entity, rig, if action == "carry" then state.carrying else nil)', 'self:_holdLoad(entity, rig, state.carrying)', SE, LOAD, "game"),
 ("FL-0148", E, 'if resource == entity.loadResource then\n\t\treturn\n\tend', '', SE, LOAD, "game"),
 ("FL-0148", E, 'cached = if ok and model ~= nil and model.PrimaryPart ~= nil then model else false', 'cached = if ok and model ~= nil and model.PrimaryPart ~= nil then model else nil', SE, "without Kit.carried a carrying citizen holds nothing", "game"),
 ("FL-0148", E, 'self._loads[resource] = cached', 'local _ = cached', SE, LOAD, "game"),
 ("FL-0148", E, 'weld.C0 = Def.CARRY_OFFSET.Rotation + Def.CARRY_OFFSET.Position * rig.scale', '', SE, LOAD, "game"),
 ("FL-0148", E, 'weld.C0 = Def.CARRY_OFFSET.Rotation + Def.CARRY_OFFSET.Position * rig.scale', 'weld.C0 = Def.CARRY_OFFSET', SE, SCALED, "game"),
 # the rig scale (D-059, FORGE-00 15:50): one named constant, the rig, its lift, its load, the pick
 ("FL-0148", E, 'Def.RIG_SCALE = 1.25', 'Def.RIG_SCALE = 1', SE, SCALED, "game"),
 ("FL-0148", E, 'adapter.scaleModel(model, Def.RIG_SCALE)', 'adapter.scaleModel(model, 1)', SE, SCALED, "game"),
 ("FL-0148", E, '\t\tscale = Def.RIG_SCALE\n', '', SE, SCALED, "game"),
 ("FL-0148", E, 'joints.Torso = torso.Rotation + torso.Position * rig.scale', 'joints.Torso = torso', SE, SCALED, "game"),
 ("FL-0148", E, 'self.adapter.scaleModel(cached, Def.RIG_SCALE)', 'local _ = cached', SE, SCALED, "game"),
 ("FL-0148", E, 'Def.PICK_HEIGHT = 2.75 * Def.RIG_SCALE', 'Def.PICK_HEIGHT = 2.75', SE, SCALED, "game"),
 ("FL-0148", C2 + "CitizenBubbleController.luau", 'Def.HEIGHT = 3.2 * EntityController.RIG_SCALE', 'Def.HEIGHT = 3.2', "experience/CitizenBubbles", "sits the bubble as far above the drawn citizen", "game"),
 ("FL-0148", C2 + "CitizenBubbleIndicatorController.luau", 'Def.HEIGHT = 3.2 * EntityController.RIG_SCALE', 'Def.HEIGHT = 3.2', "experience/RequestIndicators", "aims at the bubble where CitizenBubbleController draws it", "game"),
 ("FL-0148", C2 + "RulerCameraController.luau", 'phoneOffset = Vector2.new(0, -6.7),', 'phoneOffset = Vector2.new(0, -7.5),', "experience/RulerCamera", "on a phone the citizen's head", "game"),
 ("FL-0148", E, 'weld.C1 = load.PrimaryPart.PivotOffset', 'local _ = load', SE, LOAD, "game"),
 ("FL-0148", E, 'weld.Part0 = torso', 'weld.Part0 = rig.root', SE, LOAD, "game"),
 ("FL-0148", E, 'entity.phase = 0 -- a blow starts from its beginning', 'local _ = 0 -- a blow starts from its beginning', SE, PHASE, "game"),
 ("FL-0148", E, 'if action == "work" and entity.action ~= "work" then', 'if action == "work" then', SE, PHASE, "game"),
 ("FL-0148", E, '\tentity.action = action\n', '', SE, PHASE, "game"),
]
