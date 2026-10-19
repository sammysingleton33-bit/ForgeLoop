# Handoff: FORGE-02 → FORGE-01 (cc FORGE-04) · FL-0135 optional: unit kinds and new jobs for the mesh kit · 2026-10-18

## What I need / what I'm giving you
No action is needed for FL-0135 to land. Two things the mesh citizen kit can use later, both additive:
1. **Soldier weapons per unit kind** (spear, sword and shield, bow). The wire gives the Kit only `job = "soldier"` (`Types.JOB_IDS`), so every soldier gets the `soldier` assembly. If a unit
   kind ever reaches `Kit.character` as `job` (for example `"archer"`), the Kit already looks up the assembly `soldier_archer` first and falls back to `soldier`. That needs the unit kind in
   the spawn event (EventCodec `job` is a u8 index into `JOB_IDS`) or a separate field; your call and FORGE-04's, with a migration note. Until then the weapon can only vary by look.
2. **New jobs** (blacksmith, merchant, healer): when they join `JOB_IDS`, the kit's assemblies are keyed by job id. An unknown job builds the `idle` assembly, so nothing breaks before the art exists.

## Done (with commits)
- Branch `forge/02-blender-fl0135-runtime` (`Kit/CharacterMesh.luau`): assembly lookup `job` → alias (`woodcutter` ↔ `lumberjack`) → `idle`; soldiers `soldier_<job>` → `soldier`; governors `governor`.

## Evidence
- `tests/world/KitCharacterMesh.spec.luau` "treats unknown jobs as idle and aliases woodcutter/lumberjack" (headless).

## Interfaces touched
None. G2 `JobId` / G13.2 `look` are read as they are; `Character.lookKey` stays the pool key.

## Open issues and risks
- Look-driven variation is a cosmetic mix of the four existing look fields (`CitizenLook` ranges 6/6/8/6): the hair axis spills over extra hair meshes, other axes (face, boots, accessory, weapon) mix the whole look. No new look field is needed.

## Next actions for the receiver
1. None required. Tell FORGE-02 when a unit kind or a new job is going on the wire.

## Files to read
- `games/game-001/src/shared/Kit/CharacterMesh.luau` — `assemblyKeys`
