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

## Evidence
Headless only (Lune, Selene, StyLua, Blender Cycles previews of Lune dumps); nothing was seen in Studio.
- Part counts (all four kingdoms, measured by `Kit.partCount`): wall L1/L2/L3 26-30 / 36-40 / 52-60 (caps 30 / 45 / 60); gate 71-76 / 101-112 / 120-131 (caps 90 / 120 / 150); watchtower L2 105-121 (cap 130); ram 38-43 (cap 45); soldier, knight, archer 11 with the kingdom crest (cap 11), 9-10 without; damage at most 13 extra parts (cap 14), none at Damage 0.
- All-built worst case (D-047, 27,000): see the worker report for the measured number and the command (`tests/world/KitCeiling.spec.luau`).
- Specs, run headless: see the worker report for the counts per folder.

## Interfaces touched
All additive; nothing existing changes meaning. Proposed CONTRACTS G10 rows:

| Name | Kind | Values / signature | Notes |
|---|---|---|---|
| `Kit.build("wall", level 1-3)`, `Kit.build("gate", level 1-3)` | existing function, new levels | wall <= 30 / 45 / 60 parts, gate <= 90 / 120 / 150 (`Buildings.PART_BUDGET_BY_LEVEL`) | `Kit.footprint` unchanged (wall 32x8, gate 32x12); Door, Rally (gate) attachments unchanged |
| `Kit.build("watchtower", 2)` | existing, new look | <= 130 parts (the existing cap) | no L3 |
| model attribute `KitGateOpen` | bool, gate models only | `false` as built | set by `Kit.setGateOpen`; absent on every other model |
| `Kit.setGateOpen(model, open: boolean)` | function | moves leaves, bands and the L3 portcullis by CFrame only | adds and removes no part; reversible exactly; works on a moved and turned model (poses are stored relative to the Root); no-op on a model without `KitGateOpen` (a construction stage, a keep) |
| part attributes `KitGateClosedCF`, `KitGateOpenCF` | CFrame, relative to the Root | on the movable parts only | internal; a client that moves a gate by itself must keep them |
| `Kit.siege(kind: "ram", kingdomColor: Color3)` | function -> Model | <= 45 parts incl. Root | client-only entity model (never replicated); unknown kind errors |
| ram rig | model | Root anchored, invisible, PivotOffset at the feet, Root centre 0.1 above the feet (`KitRootHeight` = 0.1), front = -Z, every other part unanchored, Massless, non-colliding, `Weld "RigWeld"` | attributes `KitKind = "siege"`, `KitSiege = "ram"` |
| ram joint | ONE `Motor6D` named `Log` (Root -> Log) | axis-aligned with the model, so `Transform` is a translation along the model's Z | NOT in `Pose.JOINTS`: a pose driver must not reset it (see below) |
| `Kit.siegePose(model, thrust: number)` | function | thrust 0..1: 0 = log drawn back (the built pose), 1 = log `Siege.THRUST_TRAVEL` (3.0) studs forward with a 0.35-stud arc at mid-thrust; clamped, NaN = 0 | sets `Log.Transform` |
| `Kit.siegeTransform(thrust)` | function -> CFrame | the same value | for a driver that sets Transform through its own adapter (`EntityController` does) |
| `Kit.SIEGE_KINDS` | `{ "ram" }` | | |
| `Kit.character("soldier", job, color, look, kingdom)` with `job` = `"soldier"` / `"knight"` / `"archer"` | existing function, new meaning of `job` for soldiers | any other job (and today's wire value `"soldier"`) = the spear soldier, unchanged | <= 11 parts with the crest; `Pose.JOINTS` joints only; details weld to `Tool` (spearhead, pennant, bowstring), to `LeftArm` (shield, shield mark) or to `Torso` (quiver): amends D-048's "Head or Tool" welds for these kinds |
| model attribute `Damage` | number 0..1 | set by the client (for example `Kit.damageFromHp(Hp, MaxHp)` from the `Hp` and `MaxHp` attributes WorldView already writes) | read by `Kit.applyDamage` only |
| `Kit.applyDamage(model)` | function | builds or removes the damage parts for the model's `Damage`; idempotent; call again after every change | stage models (`KitStage ~= "complete"`) and models without a PrimaryPart ignore it |
| model attribute `KitDamageState` | number 1..4 | absent at state 0 | written by `Kit.applyDamage` |
| part attributes `KitDamage` (true), `KitDamageKind` ("crack" / "rubble" / "smoke") | on the added parts | direct children of the model | anchored like every building part; `CanCollide`, `CanTouch` and `CanQuery` are false |
| `Kit.damageState(d)` -> 0..4, `Kit.damageFromHp(hp, maxHp)` -> 0..1, `Kit.DAMAGE_THRESHOLDS` | functions / table | `{ 0.25, 0.5, 0.75, 0.95 }` | |

Damage states (cumulative; totals at that state; budgets pinned by `KitDamage.spec`):

| state | Damage | cracks | rubble | smoke | roof / merlon / thatch / palisade parts removed | collapse |
|---|---|---|---|---|---|---|
| 0 | < 0.25 | 0 | 0 | 0 | 0 | none: the model is exactly as built, **byte-identical** (signature equal, no `KitDamageState`) |
| 1 | >= 0.25 | 2 | 0 | 0 | 2 | |
| 2 | >= 0.5 | 4 | 0 | 1 | 5 | |
| 3 | >= 0.75 | 6 | 3 | 2 | 8 | + the top of the front-right corner (caps, merlons, roof parts) |
| 4 | >= 0.95 | 7 | 3 | 3 | 10 | the same, more smoke |

At most 14 extra parts (13 at state 4, 0 at state 0). Cracks are thin dark wedges placed on the outermost exposed wall block (nothing in front of them); rubble is blocks in the wall's own colour at the corner's foot; smoke is translucent grey Balls kept inside the model's bounding box. Removed parts are picked by a deterministic shuffle seeded from `KitType | KitLevel | KitVariant`, so state 2 keeps what state 1 took, a repair gives the exact model back and the same `Damage` gives the same parts on any client in any order.

## How Damage and Burning coexist (FORGE-04)
- `Burning` stays what it is: a model attribute that FeedbackController reads, with the flames at the top of `model:GetBoundingBox()`. `Kit.applyDamage` never reads, writes or clears `Burning`, `Hp` or `MaxHp`.
- The top of the model is unchanged by damage: the highest part is never removed (it is not in the pool of parts that go missing), and the smoke Balls are placed inside the box. So the flames start at the same height on a damaged building as on a whole one; the smoke sits at the front-right corner under them. Spec: `KitDamage.spec` "top moved" check, every building type, every state.
- Suggested order on the client: set `Damage` (from `Hp / MaxHp`) and call `Kit.applyDamage(model)`; set `Burning` as today. The two are independent; a burning building at Damage 0.9 shows cracks, missing merlons and the collapsed corner under the fire.
- The smoke parts are plain parts with `KitDamageKind = "smoke"`: FORGE-04 may tween their `Transparency` or `Position` (drift upward); keep them inside the box.
- Repair: set `Damage` lower and call `Kit.applyDamage` again; the removed parts come back where they were. `Kit.setKingdomColor` recolours a damaged model and the parts waiting for a repair, and never touches the damage parts (cracks and smoke are not kingdom-coloured; rubble copies the wall, with its tint).
- A pooled model: set `Damage` to 0 and call `Kit.applyDamage` before returning it to the pool.

## Wire finding: the unit kind does not reach the client (FORGE-01, FORGE-04)
- `config/Military.luau` has the unit types soldier, archer, knight, ram. `Sim/Replication.entityOf` returns `kind = "soldier"` for every `sim.units` entry, and `jobOf(e)` is `e.job or "soldier"`; sim units have no `job`. So `EventCodec` spawn carries `kind = "soldier"`, `job = "soldier"` for a ram, an archer and a knight alike, and `EntityController.buildRig` builds `Kit.character("soldier", "soldier", ...)` for all of them. (`EventCodec.JOBS` = `Types.JOB_IDS`; the job is a u8 index into it.)
- Smallest additive change: append `"archer", "knight", "ram"` to the END of `Types.JOB_IDS` (existing u8 codes keep their value; CONTRACTS G2 row, reviewed by FORGE-05) and make `jobOf` return the unit's `kind` for a unit: `return if e.job ~= nil then e.job else (e.kind or "soldier")`. Then the spawn event already says `job = "knight"` and so on, the pool key `kind|job|kingdom|look` is distinct per unit kind (no pooling change), `Pose.sample` treats unknown jobs as generic work (nothing changes), and `Kit.character` / `CharacterMesh` (`soldier_<job>`, FL-0135) pick the right look by themselves. `Catalog` rejects unknown jobs only for `config/Jobs` keys, which these are not. Check the specs that pin `#Types.JOB_IDS` or the codec table.
- Alternative if FORGE-01 prefers not to widen `JobId`: a separate `unit` field on the spawn event. Then pass it to the Kit as `job`.
- Until the wire changes nothing breaks: the Kit builds the spear soldier for `job = "soldier"`.

## Open issues and risks
- Studio: everything here is **unverified in Studio**. The gate poses, the ram joint (`Motor6D` on a Massless, welded, non-colliding rig) and the damage parts need one Studio pass; the Lune mock has no `Motor6D.Transform` default, so the specs read it through a `pcall`.
- The knight's shield mark is one primitive per kingdom (wedge, diamond, ball, disc): the 11-part cap leaves no room for the 3-5 part emblems. The shield is held 0.28 studs in front of the forearm so the cheer pose (arm up and out) does not sweep it through the torso; `KitUnitKinds.spec` sweeps every `Pose` action for clearance to the head, torso, legs and the other arm.
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
