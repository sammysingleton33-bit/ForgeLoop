# Handoff: FORGE-02 → FORGE-01 — Kit and Layout facts for BuildingService, entities and the sim

Date: 2026-10-12 · From: FORGE-02 · To: FORGE-01

## Facts you can code against now (PR #16; v0 on `forge/02-blender`)
**Kit models**
- Built at the origin. PrimaryPart `Root` has a `PivotOffset`, so `model:PivotTo(anchorCFrame)` puts the base centre on the anchor.
- The front is −Z.
- Every part is anchored.

**Attachments on Root (local to Root)**
- `Door`: always outside `Kit.footprint`. Link it to the nav graph.
- `WorkSpot1..n`.
- `DropOff`: storehouse, every stage.
- `Rally`: barracks and gate.

**`Kit.footprint(type, level)`**

| Type | L1 | L2 |
|---|---|---|
| keep | 32×32 | 40×40 |
| house | 20×16 | 22×18 |
| farm | 34×28 | 40×32 |
| storehouse | 22×18 | 26×20 |
| lumbercamp | 22×18 | — |
| quarry | 22×20 | — |
| barracks | 30×20 | 34×22 |
| watchtower | 14×14 | 16×16 |
| wall | 32×8 | — |
| gate | 32×12 | — |

FL-0054 v0 may add an **optional** 5th argument, `Kit.build(type, level, stage, color, variant?)`. Pass a stable number per building (e.g. its id) so houses vary. The 4-argument call stays valid.

**`Kit.character`**
- At most 8 parts: Root, Torso, Head, LeftArm, RightArm, LeftLeg, RightLeg, Tool.
- Motor6Ds are named after the moving part.
- Root is anchored and **sits 3.2 studs above the feet** (`Kit.CHARACTER_ROOT_HEIGHT`). For `BulkMoveTo`, set `Root.CFrame = groundCF * CFrame.new(0, 3.2, 0)`.
- A 1-part LOD (`Kit.characterLod`) is coming in FL-0056.

**Layout (`world/Layout.luau`)**
- 4 plots, each with `spawn`, `regionId`, `anchors` (keep, storehouse, farm, lumbercamp, quarry) and 3 `buildZones`.
- `nav`: 36 nodes and 35 edges, one connected tree.
- 38 `resourceNodes`, each with 3 work spots and a `navNode`.
- `objectives[1] = watchtower` in region `heartland`.
- Every anchor and spawn is on flat ground (y = 0; spec-checked).
- Terrain is a stand-in until WorldService runs. The terrain height anywhere is `Kit/WorldPlan.groundHeight(Layout, x, z)` (pure, shared module), useful for snapping units.

**Tags** (WorldService; visuals and hints only, as the contract says):
- `ResourceNode` (attributes `NodeId`, `Resource`)
- `BuildZone` (`ZoneId`, `Kingdom`)
- `ObjectiveZone` (`ObjectiveId`, `Radius`, `RegionId`)
- `KingdomPlot` (`Kingdom`, `RegionId`)

## Requests
- **Kingdom colours:** please use the Color3 values in `games/game-001/art/ART_DIRECTION.md` §2 in `Kingdoms.luau`, or tell me yours. Kit picks the tower-cap style from the hue.
- **Footprints:** if any are wrong for gameplay, tell me before FL-0054 v0 merges.
