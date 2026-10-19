# Handoff: FORGE-02 → FORGE-01 and FORGE-04 (cc FORGE-00, FORGE-03, FORGE-05) · FL-0072 Crown Arena venue, crowd figures, armour and weapons · 2026-10-18

## What I need / what I'm giving you
The Kit now builds the Crown Arena (`Kit.arena`), the crowd (`Kit.crowdFigure`), duel armour (`Kit.armour`) and weapons (`Kit.weapon`), and `world/Layout.luau` has `arena`; WorldService builds the neutral arena once, at the valley centre. Below: the additive text for CONTRACTS G12.6 (nobody edits CONTRACTS.md from this handoff; FORGE-00 pastes it), the exact signatures and names, and what ArenaService / DuelService (FORGE-01) and the crowd director (FORGE-04) read. **Nothing here was seen in Studio**: it is headless Lune plus Blender renders of the same parts.

## Done (with commits)
- Branch `forge/02-blender-fl0072-arena` (head in the report; no PR opened, the orchestrator opens it): `src/shared/Kit/{Arena,Crowd,Gear}.luau`, `Kit.luau` exports, `world/Layout.luau` (`arena`), `Kit/WorldPlan.luau` (arena keep-out, clearance and trim protection), `src/server/Services/WorldService.luau` (places the arena), `tests/world/{KitArena,KitCrowdFigure,KitGear,ArenaLayout}.spec.luau` (+ `support/AvatarStandIn.luau`), `KitArenaDump` and `WorldDump` specs, review section and images under `games/game-001/art/reviews/`.

## Additive contract text for G12.6 (paste into CONTRACTS.md)
```lua
-- Kit (FORGE-02), games/game-001/src/shared/Kit/Kit.luau; all pure Part builders, no yields, no scripts
Kit.arena(kingdomA: Color3?, kingdomB: Color3?): Model     -- neutral dress when a colour is nil
Kit.arenaDress(model: Model, kingdomA: Color3?, kingdomB: Color3?)   -- rebuild both dresses in place (server)
Kit.crowdFigure(kingdomColor: Color3, role: KeyRole?, variant: number?): Model   -- <= 4 parts (<= 8 with a role, v0.4-g11a), client-only
Kit.armour(armour: Armour, kingdomColor: Color3?): { Accessory }
Kit.weapon(weapon: Weapon, kingdomColor: Color3?): Tool
Kit.ARENA = { PART_BUDGET = { target = 700, cap = 900 }, FOOTPRINT = Vector2(75, 74), DUEL_RADIUS = 21, RING_RADIUS = 23,
              SPAWN_X = 13, SLAB_TOP = 0.8, FLOOR_TOP = 1.12, SEATS_PER_STAND = 72, SEAT_SPACING = 2.4, ... }
Kit.CROWD_ROLES, Kit.CROWD_MAX_PARTS (4), Kit.CROWD_ROLE_MAX_PARTS (8), Kit.CROWD_VARIANTS (12), Kit.CROWD_HEIGHT, Kit.crowdPoolKey(color, role?, variant?)
Kit.ARMOURS = { "light", "medium", "heavy" }, Kit.WEAPONS = { "swordShield", "greatsword", "spear", "mace" }  -- G12.1 names

-- Layout (FORGE-02), games/game-001/world/Layout.luau
Layout.arena = { cframe: CFrame,      -- the arena frame on the ground: X = gate axis (Gate A at -X), Z = stand axis (Stand A at -Z)
                 duelRadius: number,  -- 21, measured from cframe.Position (the painted ring)
                 spawnA: CFrame, spawnB: CFrame,  -- 26 studs apart, 3 above the ring floor, each looking at the other
                 footprint: Vector2,  -- 75 x 74 plate; the venue's real extents are 74 x 73.2
                 regionId: string }   -- "heartland"
-- A and B are the two qualified kingdoms in the order ArenaService fixes (suggestion: A = the higher Crown Points).
```

### The arena model (Workspace.World.Arena.CrownArena, tag `CrownArena`)
- WorldService builds it once with `Kit.arena()` (neutral). Find it with `CollectionService:GetTagged("CrownArena")[1]`. Attributes: `ArenaDuelRadius`, `ArenaSeatsPerStand`, `KitColorA`, `KitColorB`, `RegionId`.
- At the Arena phase ArenaService (server) calls `Kit.arenaDress(model, colorA, colorB)`: it destroys and rebuilds the two sub-models `DressA` / `DressB` (about 100 parts each, once), so every client sees the kingdoms' tower-cap silhouettes, banners, plaques and rugs with emblems. Never recolour the whole arena with `Kit.setKingdomColor(model, c)` (that paints both sides one colour); `Kit.setKingdomColor(model.DressA, c)` recolours one side's tint and emblems but not its cap shape.
- Attachments, all on `Root`, `attachment.WorldCFrame` looks at the ring (`-Z`): a figure placed there faces the ring.

| name | count per stand | meaning |
|---|---|---|
| `StandA_Row<r>_Seat<s>` (`StandB_...`) | 72 (r = 1 front/lowest .. 4 back; s = 1..18 from the viewer's left to right, contiguous; the royal gap is skipped) | crowd seats; attributes `Stand`, `Row`, `Seat`; the point is the plank top, feet go here |
| `StandA_Rail<n>` | 6 (n = 1..6 left to right) | key citizens, in `KeyRole` order of G12.1: blacksmith, healer, captain, provisioner, elder, merchant |
| `StandA_Royal<n>`, `StandA_RoyalBox` | 3 + 1 | the royal box's chairs and its centre (co-rulers who are not the champion) |
| `GateA`, `GateB` | – | where a champion appears, inside the gate passage, looking at the ring |
| `SpawnA`, `SpawnB`, `Centre` | – | the start marks (= `Layout.arena.spawnA/B` after placement) and the ring centre on the floor |

### Crowd director (FORGE-04): how to seat figures
1. Client only. Never build figures on the server. For each seat to fill: `local fig = Kit.crowdFigure(kingdomColor, role, variant)`; pool by `Kit.crowdPoolKey(color, role, variant)` (the crest shape follows the kingdom, so pool per kingdom); `fig:PivotTo(seatAttachment.WorldCFrame)`. The pivot is on the feet and the front is -Z, so the figure stands on the plank facing the ring.
2. A stand holds 72 seats; the design caps a stand at 60 figures (design §7), so there are at least 12 empty places for the "Restless / Hostile" crowds. Suggested fill order: from the centre outwards by row, or any deterministic function of the match seed; use `variant = (row * 5 + seat * 3) % Kit.CROWD_VARIANTS + 1` for a varied crowd (every figure is deterministic from its three arguments).
3. Key citizens: put the figure for role `KeyRole[n]` on `StandX_Rail<n>` with `Kit.crowdFigure(color, role, 1)` (they wear their role prop and replace the arms bar; the prop silhouettes are in `Kit/Crowd.luau`).
4. Figures are anchored, non-colliding, 4 parts: bob/cheer by `PivotTo` offsets or by moving the parts; the arms bar (`Arms`) is a separate part and can be tilted for a cheer. Beyond the LOD distance the director may drop figures to billboards (design §7); the Kit has no billboard stand-in.
5. 120 ordinary figures x 4 parts + 12 key citizens x 7 - 8 parts = about 580 client parts; the arena's 349 - 487 parts are in the world budget, the figures are not.

### Gear (FORGE-01 DuelService / loadout)
- `Kit.armour(armour, color)` returns Accessories named `KitLightCap`, `KitLightJerkin`, `KitLightCloak` (BodyBackAttachment), `KitMedium{Helm,Mail,PauldronLeft,PauldronRight}`, `KitHeavy{Helm,Plate,Back,PauldronLeft,PauldronRight}`; each has a `Handle` with one `Attachment` named for its body attachment (`HatAttachment`, `BodyFrontAttachment`, `BodyBackAttachment`, `LeftCollarAttachment`, `RightCollarAttachment`). Equip with `humanoid:AddAccessory(acc)` on the champion's character (R15 or R6).
- `Kit.weapon(weapon, color)` returns a `Tool` named for the weapon with a `Handle` and welded parts, no script. Put it in the `Backpack` and `EquipTool`. Held with Roblox's grip frame: blade up, front -Z. `KitReach` (studs above the grip), `KitHands` are attributes for animation and range choices (swordShield 4.9 / 1 hand, greatsword 7.8 / 2, spear 9.5 / 2, mace 3.8 / 1). The sword's shield rides the same hand (a Tool is one hand); a separate left-hand slot would be a follow-up.
- Visual only: the fairness numbers (G12.3) never read appearance. Every option shows its kingdom colour on the same kinds of places (plume, comb, tabard, ribbon), so none looks "best".

### What ArenaService / DuelService read
- Duel bounds: horizontal distance from `Layout.arena.cframe.Position` ≤ `Layout.arena.duelRadius`; floor height = `cframe.Position.Y + Kit.ARENA.FLOOR_TOP` (= `spawnA.Position.Y - 3`). Champions start on `spawnA` / `spawnB` (or `GateA` / `GateB` for an entrance walk of about 14 studs to the marks).
- A / B: Stand A and Gate A are the -Z / -X sides of the arena frame (west gate faces the hub and the watchtower); the kingdom you dress as A gets those; keep the same mapping for crowd seats, banners and the intro camera.
- The arena is a world model: no sim entity, no remote. Nothing in `Layout.objectives` changed; the heartland region is unchanged.

## Evidence
- `lune ... --specs games/game-001/tests/world KitArena KitCrowdFigure KitGear ArenaLayout WorldService`: see the report for the counts and mutants (headless, **not Studio**).
- Part counts (exact, round 3): arena neutral 349 (215 structure including the 10-part ground blend + 2 x 67 neutral dress); dressed 2 x crimson 421, 2 x azure 469, 2 x gold 459, 2 x emerald 487 (worst pairing, under the 700 target; hard cap 900). Ordinary crowd figure 4 parts for every variant and colour; key citizens (role set, G12.6 v0.4-g11a): blacksmith 8, healer 8, captain 7, provisioner 8, elder 8, merchant 8. Armour (all pieces): light 9 (cap 3, jerkin 4, cloak 2), medium 12, heavy 17 parts; weapons: spear 7, greatsword 8, mace 10, sword and shield 10.
- D-047: WorldService `stats.parts` includes the arena (`stats.arenaParts`); the last measured world ceiling on the FL-0086 branch was 25,861 / 27,000. Adding the neutral arena (+349) and the fourth neutral tower of FL-0127 (+115, estimate) gives about 26,325; dressed in the worst colours (+138) about 26,463, so about 535 parts of headroom remain before FL-0127 part 2 spends them. FORGE-05's ceiling spec sums `svc.stats.parts`, so it counts the arena by itself; it does not count the dress delta at the Arena phase (+0 to +138).

## Interfaces touched
Additive only: `Layout.arena` (G12.6 names plus `footprint`, `regionId`), the Kit exports above, `WorldService.stats.arenaParts`, `WorldPlan.arenaRect`, `WorldPlan.TRIM.arenaReach`. No breaking change.

## Open issues and risks
- **The valley centre is not free.** The four roads, the hub plaza and the watchtower zone meet there; the largest free disc in the heartland has a radius of about 62 studs, and the venue is 74 x 73 with the 20-stud clearance. The solved site is (141, -27), about 100 studs east of the centre, centre inside the heartland polygon, spawn B (x = 154) 4 studs outside its east edge (x = 150) and the east gate up to 28 studs outside. If ArenaService needs the champions inside a region, add a `regions.arena` polygon (FORGE-02 can add it) rather than moving the heartland.
- The arena sits on the road-free ground between the azure and gold roads and the east hill; hub-azure nav edge passes 19.9 studs from its north-west corner. No road leads to it yet (a spur from the hub is a follow-up).
- Armour and weapon fit on a real R15/R6 avatar, the Tool grip, and the accessory attachments are **unverified in Studio**; the specs use stand-in avatars with the attachment names from the Roblox attachment reference.
- The shield of sword-and-shield rides the sword hand.
- **D-019 is not passed (three fresh image-only rounds; scores in `games/game-001/art/reviews/kit-architecture.md`).** After round 3 the arena (aerial and ruler), the six key-citizen props, all three armours, sword and shield and the spear PASS; the crowd figures (variation 3, readability 3), the greatsword (variation 3, readability 3), the mace (silhouette 3, readability 3) and the ground blend (3 / 3 / 3, not a gating family) do not. FL-0072's completion criterion ("visual review scored per D-019") stays open; FORGE-00 opens the PR as interim art under D-051.
  Next art round (FORGE-02-only unless noted): a larger studded mace head or a bigger kingdom-coloured mace flag; a wider guard or a different tip for the greatsword; a crowd that survives 20 px (more hat-height and value variety per stand, a lighter emerald crowd and a short upright emerald plume); a lighter floor crown and a lobed oak leaf (the shared D-039 emblems, so a Kit-wide change); the stand-in avatar needs hands to show grips. The ground blend wants a higher-contrast sand ramp and a road spur from the hub (a Layout change).
- The crowd is a stylised 4-part person and the key citizens 7 - 8 parts; every look was judged from Blender renders only, never from Studio.

## Next actions for the receiver
1. FORGE-01: ArenaService calls `Kit.arenaDress` at the Arena phase and reads `Layout.arena`; DuelService reads `duelRadius` and the spawn marks; loadout equips `Kit.armour` / `Kit.weapon`.
2. FORGE-04: crowd director per the section above (client only).
3. FORGE-05: add the dress delta to the D-047 ceiling and run the Studio steps below.
4. FORGE-00: paste the G12.6 text above into CONTRACTS.md (v0.4-g10e or later).

### Studio steps (user, Windows; none were run)
1. Play the Studio place with Rojo; look at `Workspace.World.Arena.CrownArena` east of the watchtower: floor flat on the terrain, no trees through the stands, roads and the tower clear.
2. In the command bar run `Kit.arenaDress` on it with two kingdom colours and check both stands change; look from the aerial camera (170 studs, 50 degrees) and the ruler camera at a gate.
3. Insert 60 `Kit.crowdFigure`s on `StandB_Row*_Seat*` (the bar in the handoff's section) and check they stand on the planks, facing the ring.
4. On an R15 and an R6 avatar call `humanoid:AddAccessory` for each `Kit.armour` piece and equip each `Kit.weapon`: look for clipping, floating parts, a sideways Tool.

## Files to read
- `games/game-001/src/shared/Kit/Arena.luau` — the venue, the attachment names, the dress
- `games/game-001/src/shared/Kit/Crowd.luau`, `Gear.luau` — figures, armour, weapons
- `games/game-001/world/Layout.luau` — the arena block and how the site was chosen
- `games/game-001/art/reviews/kit-architecture.md` — the Crown Arena review section (D-019)
