# Handoff: FORGE-02 → FORGE-00 (CONTRACTS G10 rows) and FORGE-04 (EntityController, Feedback), cc FORGE-01 (wire) · FL-0128 · 2026-10-19

## What I need / what I'm giving you
The war kit is in the Kit, all additive and part-built (D-026, no CSG, no imported meshes): wall and gate at three levels, a war-ready watchtower L2, a battering ram (`Kit.siege`), soldier unit kinds in `Kit.character`, and damage states on building models (`Kit.applyDamage`).
- **FORGE-00:** add the rows in "Interfaces touched" to CONTRACTS G10 (all additive, no migration).
- **FORGE-04:** the ram and the damage states need a few client lines in your files (`EntityController`, the WorldView/Feedback side). The exact calls are under "Next actions". I did not edit them.
- **FORGE-01 / FORGE-00:** the wire does **not** carry the unit kind today, so a ram, a knight and an archer all arrive as the spear soldier. The smallest additive change is described under "Wire finding".

## Done (with commits)
Branch `forge/02-blender-fl0128-war` (worktree `forge-wt/fl0128`; no PR, the coordinator opens it). Head SHA and the part counts are in the worker report.
- Wall L1-3 and gate L1-3, `Kit.setGateOpen`, `Pieces.brazier` (`Kit/Buildings.luau`, `Kit/Pieces.luau`).
- Watchtower L2 war-ready (`Kit/Buildings.luau`).
- `Kit/Siege.luau` (the ram) and `Kit.siege`, `Kit.siegePose`, `Kit.siegeTransform`, `Kit.SIEGE_KINDS`.
- Soldier unit kinds in `Kit/Character.luau` (job = unit kind, the same convention as CharacterMesh's `soldier_<job>`).
- `Kit/Damage.luau` and `Kit.applyDamage`, `Kit.damageState`, `Kit.damageFromHp`, `Kit.DAMAGE_THRESHOLDS`; `Kit.setKingdomColor` also recolours the parts a damaged model has taken off.
- Specs: `tests/world/KitWarKit.spec.luau`, `KitUnitKinds.spec.luau`, `KitDamage.spec.luau`, `KitCeiling.spec.luau` (new); `KitBuildings`, `KitEmblems`, `KitStyles` (wall and gate now have three levels) and `KitCharacter` (the knight's sword and the archer's bow join the tool/head clearance rigs) extended, none weakened.

## FL-0128 fix round (after the first D-019 review: every family NEEDS-WORK)
What changed, for the receivers (none of it needs a new wire field; the names the client already uses are unchanged):
- **Ram (shape and pose).** The covered-wagon look is gone. The `Log` joint, its part names (`Log`, `RamHead`, `RamBand`, `Hanger` move with it) and `Kit.siegePose` / `Kit.siegeTransform` are unchanged: Transform is still a translation 0..3 studs along the model's Z with a 0.35 arc at mid-thrust, front -Z. The log is now the silhouette: a pale peeled timber 15 long and 3 across, slung from the roof on two hangers with three iron bands and a dark iron WEDGE head (`RamHead`, a `WedgePart`, never a round cap), the head projecting about 7 studs past the front edge of a low open-sided pent roof on four posts (`RoofSlab`, `RoofEdge`), on four wheels. The log is visible from the side, front and air at thrust 0. The kingdom colour is on the roof, its edge, a shield crest lying on the roof and a pennant at the rear only (`KitTint` parts are all above the log). Overall the model is about 19 studs long (z -12.5 to +6.2 at thrust 0, 3 studs more forward at thrust 1): space ranks and the hit range accordingly. 37-42 parts.
- **Gate.** Open, both leaves swing 65 degrees (`Buildings.GATE_OPEN_ANGLE`) about their hinges at the tower faces and stand inside the passage, face to the front, with the middle clear. The L3 portcullis is raised 7 studs into the lintel (hidden), never hanging in the open gap. The span (lintel) now reaches the top of the tower bodies and the voussoirs lie flush on it. The passage floor (`GateRoad`) is a light stone so the open gate reads against the dark stone. `Kit.setGateOpen` also poses the leaves a damaged gate has taken off (they come back posed correctly after a repair). No new attribute.
- **Wall L3** has its own outline (end piers with an arrow slit, four buttresses up the front reaching the walkway, two wider banners, a pedestal brazier on a plinth that rests on the walkway) at 50-58 parts (cap 60).
- **Damage.** Real geometry goes missing from Damage 0.25 (a bite of merlons or roof tiles, one gate leaf, from 0.75 the top corner and a stump slab). The translucent smoke balls are gone: `KitDamageKind` is now `"crack"` (thin flat slabs on the face), `"soot"` (opaque flat scorch streaks high on the right half), `"rubble"` and `"stump"`. Anything that tweened or filtered `"smoke"` parts (FORGE-04) has nothing to do any more; the parts are not kingdom-coloured and never intersect the roof or walls.
- **Units.** Spear soldier: the spear is 1.3x the body's height and held at the hand (before: 2.5x and beside the body). Knight: bulky (2.9 across), a large kingdom-coloured shield with an emblem that is never dark, a broad helm with a bigger crest, the sword at the fist. Archer: round head, a curved three-part bow at the hand with a visible string (the quiver is dropped). Crests: Emberhold a spire, Frostmere a flat plate, Thornwood an upright plume fin (a wedge, no longer a swept cylinder), Sunspire a dome cap. Still 11 parts with the crest; `Pose.JOINTS` unchanged. The detail welds are now `Tool` (spearhead, pennant, bowlimb, bowstring) and `LeftArm` (shield, shieldmark); nothing on the `Torso` any more.
- New EntityController-visible attribute: none. Values that changed meaning: `KitDamageKind` ("smoke" -> "soot"), the ram's extent (above).

## FL-0128 defect round (after the second fresh review: visible defects)
Defect-only round (no new features). What changed for the receivers; nothing needs a new wire field or attribute:
- **Gate L1 and L2, closed:** a recessed `Tympanum` (stone, 1 part, fixed, it stays when the leaves open) fills the point of the arch above the leaves, so no sky shows through. L3 keeps its portcullis there. The passage floor (`GateRoad`) is now chosen from the wall: light sand on dark stone (Emberhold), dark earth on the light stones (Frostmere, Thornwood, Sunspire).
- **Damage kinds** are now `"crack"`, `"soot"`, `"chip"`, `"leaf"`, `"rubble"`, `"stump"`. Cracks and soot are lit dark browns (never black), chips are small pale blocks of broken stone beside them, `"leaf"` is the broken gate leaf that stays at Damage 0.75 and above (one short board in the closed leaf's plane; `Kit.setGateOpen` does not move it, so the gate reads as ruined shut or open; repair removes it). Counts per state: cracks 2/3/3/3, soot 1/2/3/3, chips 1/2/2/3, rubble 0/2/3/3, removed 4/7/10/13; at most 14 extra parts. A gate's bite starts mid-span and alternates sides; a tower cap (cone, pyramid, hoarding roof, dome) falls whole or not at all. The watchtower (all but Thornwood) has a `CapSeat` stone course under its cap so the roof stands on the platform where the merlons are gone.
- **Units:** the spear is carried (butt 1 stud off the ground, leaning forward) with a pennant that hangs under the head; the knight's sword rises outward and forward from the fist, clear of the arm and torso; the Thornwood shield mark is a flat slanted bar (no glossy ball); the bow is 1.25 per limb, 30 degrees, held below the chin. Detail names and welds are unchanged (`Tool`: spearhead, pennant, bowlimb, bowstring; `LeftArm`: shield, shieldmark), 11 parts with the crest.
- **Walls:** L1 palisade logs, rails and posts are the same dark timber in every kingdom (the new part attribute `KitNoSkin = true` keeps `KingdomStyle.paint` off them; the banner carries the kingdom). Wall L3 has two stepped buttresses (three `Buttress` courses each, each narrower and shallower than the one below) beside the end piers instead of four flat piers: 52-60 parts (cap 60).
- **Counts now:** wall 26-30 / 36-40 / 52-60, gate 72-77 / 102-113 / 120-131, watchtower L1 107-116 and L2 105-122 (cap 130), ram 37-42, units 11. All-built worst case 26,322 of 27,000 (pinned at 26,900): +105 over the last round from the tympanum, the tower seats and the wall L3 courses.
- New EntityController-visible attribute: none (`KitNoSkin` is a build-time part attribute). `KitDamageKind` gains "chip" and "leaf".

## Evidence
Headless only (Lune, Selene, StyLua, Blender Cycles previews of Lune dumps); nothing was seen in Studio.
- Part counts (all four kingdoms, measured by `Kit.partCount`): wall L1/L2/L3 26-30 / 36-40 / 52-60 (caps 30 / 45 / 60); gate 72-77 / 102-113 / 120-131 (caps 90 / 120 / 150); watchtower L2 105-122 (cap 130); ram 37-42 (cap 45); soldier, knight, archer 11 with the kingdom crest (cap 11), 9-10 without; damage at most 14 extra parts (cap 14), none at Damage 0.
- All-built worst case (D-047, 27,000): 26,322 (WorldService 6869 + kingdoms 19,117 + neutral towers 336), pinned at 26,900 by `tests/world/KitCeiling.spec.luau`.
- Specs, run headless: see the worker report for the counts per folder.

## Interfaces touched
All additive; nothing existing changes meaning. Proposed CONTRACTS G10 rows:

| Name | Kind | Values / signature | Notes |
|---|---|---|---|
| `Kit.build("wall", level 1-3)`, `Kit.build("gate", level 1-3)` | existing function, new levels | wall <= 30 / 45 / 60 parts, gate <= 90 / 120 / 150 (`Buildings.PART_BUDGET_BY_LEVEL`) | `Kit.footprint` unchanged (wall 32x8, gate 32x12); Door, Rally (gate) attachments unchanged |
| `Kit.build("watchtower", 2)` | existing, new look | <= 130 parts (the existing cap) | no L3 |
| model attribute `KitGateOpen` | bool, gate models only | `false` as built | set by `Kit.setGateOpen`; absent on every other model |
| `Kit.setGateOpen(model, open: boolean)` | function | moves leaves, bands and the L3 portcullis by CFrame only: open = leaves swung 65 degrees into the passage, portcullis raised 7 studs into the lintel | adds and removes no part; reversible exactly; works on a moved and turned model (poses are stored relative to the Root); also poses the leaves a damaged gate has parked; no-op on a model without `KitGateOpen` (a construction stage, a keep) |
| part attributes `KitGateClosedCF`, `KitGateOpenCF` | CFrame, relative to the Root | on the movable parts only | internal; a client that moves a gate by itself must keep them |
| `Kit.siege(kind: "ram", kingdomColor: Color3)` | function -> Model | <= 45 parts incl. Root | client-only entity model (never replicated); unknown kind errors |
| ram rig | model | Root anchored, invisible, PivotOffset at the feet, Root centre 0.1 above the feet (`KitRootHeight` = 0.1), front = -Z, every other part unanchored, Massless, non-colliding, `Weld "RigWeld"` | attributes `KitKind = "siege"`, `KitSiege = "ram"` |
| ram joint | ONE `Motor6D` named `Log` (Root -> Log) | axis-aligned with the model, so `Transform` is a translation along the model's Z | NOT in `Pose.JOINTS`: a pose driver must not reset it (see below) |
| `Kit.siegePose(model, thrust: number)` | function | thrust 0..1: 0 = log drawn back (the built pose), 1 = log `Siege.THRUST_TRAVEL` (3.0) studs forward with a 0.35-stud arc at mid-thrust; clamped, NaN = 0 | sets `Log.Transform` |
| `Kit.siegeTransform(thrust)` | function -> CFrame | the same value | for a driver that sets Transform through its own adapter (`EntityController` does) |
| `Kit.SIEGE_KINDS` | `{ "ram" }` | | |
| `Kit.character("soldier", job, color, look, kingdom)` with `job` = `"soldier"` / `"knight"` / `"archer"` | existing function, new meaning of `job` for soldiers | any other job (and today's wire value `"soldier"`) = the spear soldier, unchanged | <= 11 parts with the crest; `Pose.JOINTS` joints only; details weld to `Tool` (spearhead, pennant, bowlimb, bowstring) or to `LeftArm` (shield, shield mark): amends D-048's "Head or Tool" welds for these kinds |
| model attribute `Damage` | number 0..1 | set by the client (for example `Kit.damageFromHp(Hp, MaxHp)` from the `Hp` and `MaxHp` attributes WorldView already writes) | read by `Kit.applyDamage` only |
| `Kit.applyDamage(model)` | function | builds or removes the damage parts for the model's `Damage`; idempotent; call again after every change | stage models (`KitStage ~= "complete"`) and models without a PrimaryPart ignore it |
| model attribute `KitDamageState` | number 1..4 | absent at state 0 | written by `Kit.applyDamage` |
| part attributes `KitDamage` (true), `KitDamageKind` ("crack" / "soot" / "chip" / "leaf" / "rubble" / "stump") | on the added parts | direct children of the model | anchored like every building part; `CanCollide`, `CanTouch` and `CanQuery` are false |
| `Kit.damageState(d)` -> 0..4, `Kit.damageFromHp(hp, maxHp)` -> 0..1, `Kit.DAMAGE_THRESHOLDS` | functions / table | `{ 0.25, 0.5, 0.75, 0.95 }` | |

Damage states (cumulative; totals at that state; budgets pinned by `KitDamage.spec`):

| state | Damage | cracks | soot | chips | rubble | crenellation / roof / thatch / palisade parts removed | gate leaves | collapse |
|---|---|---|---|---|---|---|---|---|
| 0 | < 0.25 | 0 | 0 | 0 | 0 | 0 | 0 | none: the model is exactly as built, **byte-identical** (signature equal, no `KitDamageState`) |
| 1 | >= 0.25 | 2 | 1 | 1 | 0 | 4 | 1 gone (+ bands) | |
| 2 | >= 0.5 | 3 | 2 | 2 | 2 | 7 | 1 gone | |
| 3 | >= 0.75 | 3 | 3 | 2 | 3 | 10 | both gone, one broken leaf stays (`"leaf"` part) | + the top of the front-right corner (merlons, roof tiles; a tower cap falls whole) and a stump slab where a cap fell |
| 4 | >= 0.95 | 3 | 3 | 3 | 3 | 13 | the same | the same |

At most 14 extra parts (12 marks, chips and rubble at state 4, plus a broken leaf on a gate or one "stump" slab when a tower cap fell; 0 at state 0). The removed parts are a contiguous BITE of the crenellation or the roof edge (nearest to a seed first; a gate starts mid-span and alternates sides), so 0.3 differs visibly from 0 on a wall, a tower, a gate and a house. Cracks are thin slabs lying on the outermost exposed wall block (nothing in front of them) and soot an opaque streak high on the right half, both lit dark browns (every colour channel above 40 / 255, never black); chips are small pale blocks of broken stone at their feet; rubble is blocks in the wall's own colour at the corner's foot. Removed parts are picked by a deterministic order seeded from `KitType | KitLevel | KitVariant`, so state 2 keeps what state 1 took, a repair gives the exact model back and the same `Damage` gives the same parts on any client in any order.

## How Damage and Burning coexist (FORGE-04)
- `Burning` stays what it is: a model attribute that FeedbackController reads, with the flames at the top of `model:GetBoundingBox()`. `Kit.applyDamage` never reads, writes or clears `Burning`, `Hp` or `MaxHp`.
- The top of the model is unchanged by damage: the highest part is never removed (it is not in the pool of parts that go missing), and every added mark lies inside the box. So the flames start at the same height on a damaged building as on a whole one; the soot streaks are on the walls below them. Spec: `KitDamage.spec` "top moved" check, every building type, every state.
- Suggested order on the client: set `Damage` (from `Hp / MaxHp`) and call `Kit.applyDamage(model)`; set `Burning` as today. The two are independent; a burning building at Damage 0.9 shows cracks, soot, missing merlons and the collapsed corner under the fire.
- The damage parts are plain opaque parts (`KitDamageKind` crack / soot / chip / leaf / rubble / stump); there is no smoke part any more. FORGE-04 may add its own smoke effect (a ParticleEmitter) at the top of the box.
- Repair: set `Damage` lower and call `Kit.applyDamage` again; the removed parts come back where they were. `Kit.setKingdomColor` recolours a damaged model and the parts waiting for a repair, and never touches the damage parts (cracks and soot are not kingdom-coloured; rubble copies the wall, with its tint).
- A pooled model: set `Damage` to 0 and call `Kit.applyDamage` before returning it to the pool.
- A damaged gate that is opened or closed keeps its broken leaf where it is (a damage part): call `Kit.setGateOpen` as before; it poses the parked leaf correctly for the repair.

## Wire finding: the unit kind does not reach the client (FORGE-01, FORGE-04)
- `config/Military.luau` has the unit types soldier, archer, knight, ram. `Sim/Replication.entityOf` returns `kind = "soldier"` for every `sim.units` entry, and `jobOf(e)` is `e.job or "soldier"`; sim units have no `job`. So `EventCodec` spawn carries `kind = "soldier"`, `job = "soldier"` for a ram, an archer and a knight alike, and `EntityController.buildRig` builds `Kit.character("soldier", "soldier", ...)` for all of them. (`EventCodec.JOBS` = `Types.JOB_IDS`; the job is a u8 index into it.)
- Smallest additive change: append `"archer", "knight", "ram"` to the END of `Types.JOB_IDS` (existing u8 codes keep their value; CONTRACTS G2 row, reviewed by FORGE-05) and make `jobOf` return the unit's `kind` for a unit: `return if e.job ~= nil then e.job else (e.kind or "soldier")`. Then the spawn event already says `job = "knight"` and so on, the pool key `kind|job|kingdom|look` is distinct per unit kind (no pooling change), `Pose.sample` treats unknown jobs as generic work (nothing changes), and `Kit.character` / `CharacterMesh` (`soldier_<job>`, FL-0135) pick the right look by themselves. `Catalog` rejects unknown jobs only for `config/Jobs` keys, which these are not. Check the specs that pin `#Types.JOB_IDS` or the codec table.
- Alternative if FORGE-01 prefers not to widen `JobId`: a separate `unit` field on the spawn event. Then pass it to the Kit as `job`.
- Until the wire changes nothing breaks: the Kit builds the spear soldier for `job = "soldier"`.

## Open issues and risks
- Studio: everything here is **unverified in Studio**. The gate poses, the ram joint (`Motor6D` on a Massless, welded, non-colliding rig) and the damage parts need one Studio pass; the Lune mock has no `Motor6D.Transform` default, so the specs read it through a `pcall`.
- The knight's shield mark is one primitive per kingdom (wedge, diamond, ball, disc): the 11-part cap leaves no room for the 3-5 part emblems. The large shield (1.9 x 2.6) is held 1.2 studs in front of the arm and 0.7 to the side so every `Pose` action keeps it clear of the head and torso; `KitUnitKinds.spec` sweeps every `Pose` action for clearance to the head, torso, legs and the other arm.
- Watchtower L2 for Thornwood (emerald) has 105 parts, fewer than its L1 (107): its hoarding roofs replace merlons and the new galleries and slits cost less. The war-ready cues (galleries, braziers, slits, banner) are in all four kingdoms; merlon count rises only where the style has merlons.
- Mesh kit: the imported-mesh rig (FL-0135) is untouched. Its knight and archer assemblies (`soldier_knight`, `soldier_archer`) already follow the same `job` convention.
- The ram has no far-LOD model; `Kit.lod("soldier", color)` (one box) is the stand-in until FORGE-02 adds one.
- Part ceiling: the all-built worst case is tight; if a later change pushes it over 27,000, cap the wall segments per kingdom in `config/Buildings.luau` (FORGE-00's preference) before thinning the art.

## Next actions for the receiver
1. **FORGE-00:** copy the table above into CONTRACTS G10 (additive); decide the wire change (G2 `JobId` append, or a `unit` field) with FORGE-01.
2. **FORGE-01:** `Types.JOB_IDS` append and `Replication.jobOf` as above, once decided; add the unit kinds to the spawn tests.
3. **FORGE-04, `EntityController`:**
   - `buildRig`: `local model = if job == "ram" then Kit.siege("ram", COLORS[kingdom] or Kit.NEUTRAL_COLOR) else (Kit.character :: any)(kind, job, COLORS[kingdom] or Kit.NEUTRAL_COLOR, look, crest)`. The rest of `buildRig` already works for the ram: `root.PivotOffset:Inverse()` is the feet offset, `motors.Log` is found by name.
   - `_animate`: the generic loop `setTransform(motor, joints[joint] or IDENTITY)` would reset the `Log` joint every frame. For a siege rig (`rig.model:GetAttribute("KitSiege") ~= nil`) skip `Pose.sample` and set `setTransform(rig.motors.Log, Kit.siegeTransform(thrust))`, with `thrust = if action == "fight" then 0.5 - 0.5 * math.cos(2 * math.pi * entity.phase) else 0` (one thrust per fight cycle; `Pose.rate("fight", ...)` is 1.4 cycles per second, a ram may want a slower phase). Dead: blend `thrust` to 0 or leave the pose.
   - Buildings: wherever WorldView/FeedbackController handle `Hp`, `MaxHp` and `Burning`, add `model:SetAttribute("Damage", Kit.damageFromHp(hp, maxHp)); Kit.applyDamage(model)` (both are cheap; `applyDamage` returns at once when the state did not change). Gates: `Kit.setGateOpen(model, true)` while friendly units pass (the sim has no open/closed state for a gate yet; FORGE-01 owns it).
4. **FORGE-02 (me):** a ram LOD, if wanted, and any proportion fixes from FORGE-05's Studio pass.

## Files to read
- `games/game-001/src/shared/Kit/Damage.luau`, `Siege.luau` — the headers have the full contracts
- `games/game-001/src/shared/Kit/Kit.luau` — "War kit" in the API header
- `games/game-001/tests/world/KitWarKit.spec.luau`, `KitUnitKinds.spec.luau`, `KitDamage.spec.luau`, `KitCeiling.spec.luau` — what is pinned, and the mutants
- `games/game-001/art/reviews/kit-architecture.md` — the FL-0128 section: renders and the D-019 record
