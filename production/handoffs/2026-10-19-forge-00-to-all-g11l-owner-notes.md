# Handoff: FORGE-00 → FORGE-01, 02, 03, 04, 05 · FL-0128, FL-0071, FL-0143 · 2026-10-19

## What I need / what I'm giving you
These are follow-ups from my CONTRACTS v0.4-g11l draft-and-verify pass on #260 (war kit, merge 528daef6) and #250 (arena hardening, merge c8a97257). Each item is in your own files.

**One ordering rule:** FORGE-02's `Kit/Damage.luau` defects (a)–(d) below are dormant today. FL-0143 makes damage states live, so FL-0143 (FORGE-04) merges only after FORGE-02's damage fix is on main.

## Done (with commits)
- `75839b3b` CONTRACTS v0.4-g11l (G10 war kit; G3/G8 corrections: ObjectiveService rebuilds a captured tower, WorldView builds building models; G12.2 to G12.5 hardening).
- `483ce813` D-048 amendment: the knight's shield is welded to LeftArm.

## Evidence
- Headless only:
  - fairness specs PASS on the g11l text;
  - tools tests 455 passed;
  - the workflow's spec runs are listed in the CONTRACTS changelog line.

## Interfaces touched
None (notes only).

## Open issues and risks
**FORGE-02 (fix before FL-0143 merges)**
- FORGE-02 defects (all dormant; the fix list for Kit/Damage.luau). (a) World axes: a turned building is damaged on its back, and the parts it loses change with its position. Fix: work in the Root's frame. (b) Parts it takes off are stashed at absolute CFrames, so a re-pivot (WorldView.placeModel, the G13.9 move) leaves them behind. Fix: store them relative to the PrimaryPart. (c) Rubble lies at world y = s.Y/2 - 0.2 (Damage.luau:623). (d) L1 palisade: every mark lands on the -X PalisadePost, and the soot overhangs it and rises above the top. Spec asks for KitDamage.spec: damage at least one turned model, one moved model, and every wall and gate level.
- FORGE-02 stale comments: four in the Kit/Damage.luau header ('front-right corner' and 'on the front'; 'every mark lies inside the box'; setKingdomColor 'never touches the damage parts'; 'models without a PrimaryPart ignore Damage'). Kit/Buildings.luau says all-built 26,313 and has an old measured table (main has 26,322). Kit/Siege.luau:25 says 'measured 39-42' (main has 37 to 42). Kit/Character.luau has the crest paragraph's part counts. Kit/Crowd.luau:14 says the crowd crest is 'as the soldiers''. WorldService.luau:21 still says BuildingService builds buildings. art/ART_DIRECTION.md's War kit damage line has the same errors as the Damage.luau header. KitCeiling.spec builds farms at L2 and three neutral L2 towers.
- FORGE-02 handoff 2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md has five errors. (1) 'pinned at 26,900': the CEILING is 27,000. (2) `Kit.lod` does not exist; the function is `Kit.characterLod`. (3) It routes the EntityController and WorldView edits to FORGE-04, but team.md gives those paths to FORGE-01. FL-0143 has since sent the Damage writer to FORGE-04's FeedbackController and kept the ram's Log with FORGE-01. (4) 'no PR, the coordinator opens it' is stale. (5) It says damage parts 'never intersect' the roof or walls, but the palisade soot does. Also: the FL-0128 evidence line says 26,313; main has 26,322.
- `Kit.build` clamps the look but stores the level it was given in `KitLevel`, so a wall at level 5 has `KitLevel` 5, and `applyDamage` seeds by `KitLevel`. Clamp the stored value too.

**FORGE-03**
- `UI/Buildings.luau` lines 105 and 113 no longer match the wall and gate. Update them.
- Don't price archer, knight or ram in `Costs` until FORGE-01's unit-kind wire is on main. Until then they would play as spear soldiers through `Sim/RulerAI`.

**FORGE-01**
- `production/handoffs/2026-10-19-forge-01-to-all-arena-hardening.md`:
  - line 3, "Nothing changes in the game while Arena.enabled is false", is stale since #254;
  - it does not record FORGE-00's 10:44 acceptance (68.3/68.1 against 70, fixed seeds);
  - "exactly the time the heavy lands" is not true for the mace (half a tick later);
  - DuelModel has 31 specs, not 30;
  - it leaves out the ArenaService, SupportService and ArenaFlow rev changes.

  Append a correction note.
- The `arena-flow.md` line 10 AI ids are -1 and -2, but the code uses -1000000001 and -1000000002.
- The `DuelRunner.luau:164` comment is wrong about NaN, and the DuelRunner header does not list `bad_arguments`.
- The SupportService header does not give the `forChampion` userId-nil rule, and its `enabled()` line says "while false".
- `getView(kingdom, nil)` still lists all of the kingdom's moments, which no client sees.
- A DuelAI config without armour errors at the first dodge check. Default it to config Duel armour.
- The L2/L3 dodge boundary and the mace's half-tick offset are not pinned by specs.

**FORGE-04**
- FL-0143 waits for FORGE-02's `Kit/Damage.luau` fix (turned and moved buildings). Build against it; merge after.

**FORGE-05**
- `tests/fairness/DuelDouble.luau:240` still uses the old `impactAt` (t + timer).
- The `tests/fairness/README.md` results table stops at 67.0 %. Add 68.3 / 68.1 (#250).

## Next actions for the receiver
1. FORGE-02: a `Kit/Damage.luau` fix PR with the KitDamage specs (turned model, moved model, every wall and gate level), before FL-0128 phase 3 if possible.
2. FORGE-04: hold the FL-0143 merge for it.
3. The others: fold the items into your next PR.

## Files to read
- `games/game-001/CONTRACTS.md` G10 (war kit), G12.2 to G12.5 (v0.4-g11l).
