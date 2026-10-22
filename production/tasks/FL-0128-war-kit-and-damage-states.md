---
id: FL-0128
title: "War kit: wall, gate and tower levels, siege ram, kingdom soldier variants and weapons, damaged and burning building states"
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-19
depends_on: [FL-0127]
evidence:
  - tests/world 29 spec files green (KitWarKit, KitUnitKinds, KitDamage, KitCeiling new); all-built worst case 26,326 of 27,000 at the time (this line said 26,313: a stale measurement; 26,322 after the defect-only round; the ceiling is 27,000, not a 26,900 pin; 26,402 on main since FL-0136 phase 3, see the last Log line)
  - damage frames (forge/02-blender-damage-frames), headless: KitDamage 38, KitWarKit 64, Kit.spec 20, KitCeiling 26,326 (26,402 on main since #274), KitBuildings 17, KitStyles 20, KitEmblems 14, KitUnitKinds 15, KitCharacter 144 (5 files), ArenaLayout 23, WorldService 27, all green; Studio unverified
---

# War kit: wall, gate and tower levels, siege ram, kingdom soldier variants and weapons, damaged and burning building states

## Outcome
Warfare looks like warfare from the air: walls, gates and towers with a clear silhouette, a siege ram model, soldiers that read as a kingdom's army (kingdom-coloured tabard and shield, spear/sword/bow by unit kind), and buildings that visibly show damage before they fall.

## Context
- BRIEF §4 VS-2 rows 3-5; Military units in `config/Military.luau` (FORGE-01). D-048 rig cap (≤ 11 parts). Kit is primitives only (D-021).

## Requirements
- Kit pieces for wall segment, gate (open/closed state), tower (levels 1-2), siege ram, all kingdom-tinted via the FL-0127 style table.
- Soldier looks per unit kind in `Kit.character` within 11 parts; the kingdom crest stays (D-033).
- Damage states: a `Damage` attribute (0-1) on building models drives cracked/missing parts and smoke at thresholds; the riot `Burning` look (FORGE-04's VFX) stays compatible. Write the additive attribute contract in your handoff.
- D-019 renders at aerial and close range.

## Validation
Automated Kit specs and part counts. Visual D-019. Studio rows with FORGE-05.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
- 2026-10-19 forge-02: READY → BUILDING. built on forge/02-blender-fl0128-war (head see worker report): wall and gate L1-3, Kit.setGateOpen, watchtower L2 war-ready, Kit.siege ram, soldier kinds, Kit.applyDamage; handoff production/handoffs/2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md; D-019 sheets art/reviews/img/kit_fl0128_*.jpg (not yet reviewed by a fresh reviewer; Studio unverified)
- 2026-10-19 forge-02: FIX ROUND after the first fresh D-019 review (every family NEEDS-WORK): all-built worst case 26,217; wall L3 own outline, gate open leaves/portcullis/shape, ram log silhouette, damage with real geometry loss, unit kinds reworked; new 170-stud sheets and a BEFORE/AFTER sheet (art/reviews/img/kit_fl0128_*.jpg); second fresh review is the coordinator's (headless evidence only, Studio unverified)
- 2026-10-19 forge-02: DEFECT-ONLY ROUND after the second fresh review (FORGE-00 ruling): gate tympanum and contrasting floor, lit-brown soot and cracks with chips, seated tower caps and whole-cap collapse, broken gate leaf at 0.9, unit weapons at the fist, stepped wall L3 buttresses, one dark L1 palisade; all-built 26,322 of 27,000; sheets regenerated (headless evidence only, Studio unverified); see art/reviews/kit-architecture.md 'defect-only round'
- 2026-10-19 forge-02: DEFECTS ROUND B (branch forge/02-blender-fl0128-defects, stacked on the war branch; FORGE-00 ruling after the 'any visible defects?' review): breach marks rebuilt as broken stone in the wall's own value (KitDamageKind 'soot' -> 'breach'; KitDamage band rule), gate L3 closed has a stone panel behind the portcullis bars, open-gate floor is mid-tone in all four kingdoms; all-built 26,326 of 27,000; targeted specs green (headless evidence only, Studio unverified, roblox check.sh not run by me); see art/reviews/kit-architecture.md 'defects round B' and the handoff 2026-10-19-forge-02-to-forge-00-04-fl0128-defects-b.md
- 2026-10-19 forge-02: DAMAGE FRAMES (P1 before FL-0143; branch forge/02-blender-damage-frames, stacked on defects round B): Kit.applyDamage works in the model's own frame (a turned or moved building damages like one at the origin), parked parts are stored relative to the PrimaryPart (repair after a move exact), rubble on the base plane and inside the footprint (at most 2 studs in front), L1 palisade marks spread over logs and posts, Kit.build stores the clamped KitLevel, part attribute KitOrder fixes the walk order; FORGE-07's three lows pinned; stale comments fixed; errata handoff 2026-10-19-forge-02-war-kit-handoff-errata.md and handoff ...-fl0128-damage-frames.md; all-built 26,326 of 27,000; headless evidence only, Studio unverified
- 2026-10-19 forge-02: LOWS AFTER #277 (branch forge/02-blender-damage-lows; FORGE-07's L1 and L2, FORGE-05's gate follow-ups): ceiling figures in the texts are the measured 26,402 of 27,000 (WorldService 6,945 with FL-0136 phase 3's 76 node-marker parts + four kingdoms 19,121 + neutral towers 336; farms at level 3: 26,438), KitOrder is pinned by CHECKS.order in KitDamage.spec (every Kit.build part but the Root has a unique integer 1..n; reversing the numbers changes the choice for wall, gate, house, keep and watchtower; a 1e-4 nudge changes no choice where the numbers decide, and does without them for keep L1 and L3, barracks L4 and granary L2 at state 1) with three in-spec mutants plus two source mutants (Damage.register removed; ownParts ignoring the rank), all caught; KitDamage 42 passed; L4 (palisade marks barely read in the render) is held for FORGE-00's yes/no on a lighter-wood chip band; headless only, Studio unverified
- 2026-10-22 forge-02: FOLLOW-UPS AFTER #277: #281 merged (KitOrder pinned by a spec with mutants; ceiling texts 26,402 / 6,945). L4 (the palisade marks barely read in the render) is a KNOWN ITEM: FORGE-00 2026-10-19 said no for now, 2026-10-22 said YES if it costs no parts (a chip band in a lighter wood on the L1 palisade), to fold into a later war-kit PR after the visual P0 work (it changes the look: a fresh D-019 review then). Stays BUILDING.
