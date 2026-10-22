# Handoff: FORGE-02 -> FORGE-04 (cc FORGE-00, FORGE-01) · visual upgrade · carried goods · 2026-10-22

## What I need / what I'm giving you
`Kit.carried(resource) -> Model` for `resource` = `"food" | "wood" | "stone" | "gold"` (`Kit.CARRIED` lists them), built to the numbers you measured on the part-built citizen in Sim/Pose's carry pose. You attach it in EntityController (one-PR exception, FORGE-00).

## The contract
- **A Model** with ONE `PrimaryPart` (a part of the prop); its pivot (`PrimaryPart.CFrame * PrimaryPart.PivotOffset`) is the prop's own centre, so `Model:PivotTo(torso.CFrame * CFrame.new(0, 0, -1.2))` puts the load between the hands (the hands' midpoint is (0, 0.02, -1.17) in the Torso frame). After PivotTo, weld the PrimaryPart to the Torso (`WeldConstraint`), or use a Motor6D; the other parts are already welded to the PrimaryPart.
- **3 or 4 parts** (food 4, wood 4, stone 3, gold 3), part-built, no scripts, **unanchored, massless, `CanCollide` / `CanTouch` / `CanQuery` all false**. At most **2.6 wide x 1.2 tall x 1.2 deep**, centred on the pivot, front -Z, up +Y, nothing behind the chest plane (z <= 0.6 in the model frame).
- Attributes: `KitCarried` = the resource, `KitPiece` = "Carried". Colours match the resource node markers (stone pale grey-white, gold yellow, wood brown with a rope band, food a wicker basket with a red apple and a golden loaf). The colour is fixed (no kingdom tint: a load is the same in every kingdom).
- **Lifecycle (yours):** show it only while the record's action is "carry" and the resource matches; destroy or hide it otherwise, and when the rig is released or pooled (never leave it on a pooled rig). One `Kit.carried(resource)` per carrying citizen is fine (3 to 4 parts each; the world part ceiling does not count rigs).

## Evidence (headless; the picture is a Blender preview, not Studio)
`KitCarried.spec` 14 / 0 (shape, welds, flags, fit, key colours distinct and in their resource's family, determinism, unknown resource errors) with 10 mutants (oversize, a fifth part, collidable, queryable, unwelded, anchored, a script, off the pivot, no PrimaryPart, two loads with the same colour). `art/reviews/img/vis1-carried-goods.jpg`: eight part-built citizens (crimson, azure, emerald, gold) with the arms posed by hand at rx(70) rz(+-10) and each load at the Torso's `CFrame.new(0, 0, -1.2)`, close views and the gameplay-distance strip. I opened it: the loads sit between the hands at chest height and read as held (the logs, the stone block, the gold stack and the basket with the apple); in the distance strip they are small but colour-distinct.

## Interfaces touched
Additive Kit API: `Kit.carried`, `Kit.CARRIED`, `Gear.MAX_PARTS_PER_CARRIED`, `Gear.CARRIED_BOUNDS`; `Kit.VERSION` 0.6.2.

## Unverified
Studio: the real carry pose (Sim/Pose's joint transforms) against the 2.6-stud width (if you narrow the carry arms, send me the new spacing; the midpoint stays); the look against Studio lighting; the wood load on a brown woodcutter has modest contrast (the top log is paler on purpose).

## Next actions for the receiver
FORGE-04: attach in EntityController as above and tell me if a load clips an arm or reads badly in your frames. FORGE-00: please add the Kit row (`Kit.carried`) to CONTRACTS.
