# Handoff: forge-02 (mesh kit, worker B) → forge-02 (Kit runtime, worker K) and FORGE-00 · FL-0135 · 2026-10-19

## What I need / what I'm giving you
Kit data for variation pass (b): the idle citizen has a visible accessory (head item and back pack), the hat jobs keep a hair tuft, and FORGE-07's three lows on #226 are fixed (healer front cross, merchant scale off the face, knight body figure documented). `rig.json`, `citizen_kit.fbx` and the generated `Kit/CharacterMeshData.luau` are regenerated; no runtime or converter file was edited.

## Done (with commits)
- Branch `forge/02-blender-fl0135-idle`, stacked on `forge/02-blender-fl0135-silhouettes` (135edc6d, PR #226). Head SHA is in the worker report; no PR opened (the coordinator opens it, after #226).
- New piece ids the runtime sees by name: `tuft_01` to `tuft_06` (Head, slot hair, tint hair, 26 to 44 tris), `acc_03` (bandana, Head, cloth tint), `pack_01`, `pack_02` (empty, Torso), `pack_03` (rose bindle), `pack_04` (rose rucksack) (Torso, tint fixed, 48 to 50 tris). `acc_02` (headband) was simplified to ring + knot.
- Assembly changes: `idle` gets `acc: acc_%look.acc%` (3 variants, one empty) and a NEW slot key `pack: pack_%look.weapon%` (4 variants, two empty). Farmer, miner, builder, hauler, merchant get `hair: tuft_%look.hair%` under the hat; blacksmith gets `tuft: tuft_%look.hair%` (its `hair` key is the beard). The healer coif has an extra small cross on the front of the hood.
- Removed or merged to stay at 16 pieces: farmer `hat_ribbon` (removed), `hat_feather` (merged into `hat_merchant`), hatband on the merchant (removed). The farmer therefore has no kingdom ribbon on the hat.
- Merchant `tool_scale`: beam 4.0 studs on a 1.25 stud forward arm, held low in front of the chest.

## Evidence
- `~/forge-bpy/bin/python -I blender/scripts/charkit_budget.py`: citizens max 990 / 1,000 (merchant), body <= 898 / 900, tool <= 114 / 150; soldiers and governor <= 978 / 1,500 (`soldier_knight` body 906, inside the 1,500 soldier total; the 900 body figure is citizens only); pieces <= 16; PASS.
- `python3 games/game-001/art/char_kit/rig_to_luau.py`: 0 warnings, 323 lines. `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world`: 318 passed / 0 failed (20 files). `blender/scripts/charkit_runtime_checks.py`: 0 violations, worst tool-head clearance 0.204 (limit 0.1), lowest fall corner -0.133, highest body point 7.17 (< 7.2). `blender/tests`: 58 passed. `bash blender/scripts/check.sh`: PASS.
- D-019 delta: one fresh image-only reviewer, six sheets in `games/game-001/art/reviews/img/d057-var-review-r1/`, reply verbatim in `review.json`: BETTER (idle variation 3 to 4; farmer, builder, hauler, merchant 2 to 3; readability unchanged; healer front cross and merchant clear head: yes in the portrait). All headless / Blender renders, nothing seen in Studio.

## Interfaces touched
Additive in `rig.json` / `CharacterMeshData.luau`: new piece ids, one new assembly slot key (`pack`) and one more (`tuft`, blacksmith). No contract change; the Kit specs pass with them, so the runtime already builds any slot key generically.

## Open issues and risks
- Naming, read from `Kit/CharacterMesh.luau` (not run in Studio): the `hair` key's piece is named "Hair" and gets `KitHeadwear = <piece id>`, so on a hat job `KitHeadwear` now holds `tuft_0N` (the hat itself is the `hat` key, named by its piece id); the `acc` key's piece is "Accessory" with `KitAccessory`; the new `pack` key (and the blacksmith `tuft` key) take the piece id as the part name and set only `KitPiece` / `KitSlot`. If client code reads `KitHeadwear` to mean "the hat", it will now see a hair tuft on hat jobs; `grep GetAttribute("KitHeadwear")` finds no reader in `games/game-001/src`; the specs that read it (`KitCharacter.spec`, `KitPortrait.spec`) run on the part-built rig and are green; `KitCharacterMesh.spec` lines 514 to 521 only require KitHeadwear == KitPiece on the Hair part. Studio-unverified.
- The hat-job tufts show at the portrait and 40 studs only (invisible at 170); idle items are small and pale (reviewer: "partly" at 40 and 170). Not an aerial fix; see `char-mesh.md`, "Variation pass (b)".
- Piece budget is full on farmer, woodcutter, miner, builder, hauler, merchant, governor (16); a further accessory means merging pieces.

## Next actions for the receiver
1. Merge after #226; run `rig_to_luau.py` and the Kit specs on the merged tree.
2. In Studio after the owner's import: idle citizens (bandana, headband, bindle, rucksack), a hat job with a tuft in the card portrait, the healer's front cross in the portrait, the merchant's scale next to the face.

## Files to read
- `games/game-001/art/reviews/char-mesh.md` — "Variation pass (b)": changes, numbers, weaknesses
- `games/game-001/art/reviews/img/d057-var-review-r1/sheet_variation_idle.jpg`, `sheet_variation_merchant.jpg`, `sheet_variation_healer.jpg` — BEFORE vs AFTER
