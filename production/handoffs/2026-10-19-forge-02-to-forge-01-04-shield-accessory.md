# Handoff: forge-02 → forge-01, forge-04 (cc forge-00) · FL-0072 follow-up, FL-0140 · 2026-10-19

## What I need / what I'm giving you
The sword-and-shield's shield belongs on the LEFT arm (FORGE-04's duel poses guard with it), but `Kit.weapon("swordShield")` carried it on the sword Tool. `Kit.shield(kingdomColor?)` is now an **Accessory on `LeftGripAttachment`**, and `Kit.weapon("swordShield", color, { shield = false })` is the sword alone. **Additive, no breaking window:** `Kit.weapon("swordShield", color)` with no third argument is exactly the old Tool (shield on it, 10 parts), so #271 and anything else calling it keeps working. FORGE-01: when you wire the loadout / equip (FL-0140, #271), use the new form (below). FORGE-04: nothing to change today; the pose notes below are for when a champion wears the shield.

## Done (with commits)
- `d0c10135` `Kit.shield`, `Kit.weapon` `opts`, `KitShield`, stand-in `LeftGripAttachment`, `Kit.VERSION` 0.6.1 (branch `forge/02-blender-shield-accessory`, no PR yet)
- `0b656191` `KitGear.spec` +15 tests (38 total), `1f1543d7` arena dump group `shield` and the preview sheet `games/game-001/art/reviews/img/fl0072_shield_hand.jpg`; later commits on the branch are docs only (see the branch head in the report)

## The API (exact)
```lua
Kit.shield(kingdomColor: Color3?): Accessory
-- Name "KitShield"; attributes KitPiece = "Shield", KitShield = "shield" (no KitArmour).
-- Handle (the rim) holds ONE Attachment named "LeftGripAttachment"; 3 more parts welded to the Handle (4 parts; cap 10);
-- every part unanchored, Massless, CanCollide / CanTouch / CanQuery false, no scripts. ShieldFace carries KitTint 1:
-- Kit.setKingdomColor(accessory, color) recolours it. nil colour = Kit.NEUTRAL_COLOR.

Kit.weapon(weapon: Weapon, kingdomColor: Color3?, opts: { shield: boolean? }?): Tool
-- "swordShield", no opts (or opts.shield ~= false): the old Tool, sword + ShieldRim / ShieldFace / ShieldBand / ShieldBoss = 10 parts.
-- "swordShield", { shield = false }: the sword alone, 6 parts; same Handle, Grip, KitHands = 1, KitReach = 4.72 (geometry top 4.95).
-- KitShield = "shield" on swordShield in BOTH forms; greatsword / spear / mace ignore opts and carry no KitShield.
```
`KitShield` says "this weapon goes with a shield", not "the shield is missing". **Do not equip both a default `swordShield` Tool and `Kit.shield`**: you would carry two shields. Either pass `{ shield = false }` whenever you also add the accessory, or test `tool:FindFirstChild("ShieldRim")`.

## What I found in the repo (grep, `origin/main` 9240266c and this branch)
Nothing inside `games/game-001/src` or `roblox/src` outside `Kit/` calls `Kit.weapon`, `Kit.armour` or `Kit.shield` today. The only callers are `games/game-001/tests/world/KitArenaDump.spec.luau` and `KitGear.spec.luau` (both mine). The other hits are `ArenaText.weapon` / `ArenaText.armour` (UI text lookups, not Kit), the string `"swordShield"` in `Arena/Types`, `Arena/Remotes`, `Arena/DuelModel`, `FeedbackDuelController` and `DuelPoses.STYLE`, and a comment in `DuelPoses.luau` line 45. `FeedbackDuelController`'s preview builds no gear (it only poses the avatar). FL-0140's text says #271 will call `Kit.weapon` and `Kit.armour` for each champion.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world <filter>`: KitGear 38 passed (23 before), KitCharacter group 145, KitArena group 33, ArenaLayout 23, Kit + KitWarKit 81, KitCeiling 1, KitCrowdFigure 19, KitUnitKinds 15, KitNoPluginWrites 2, WorldService 27, all 0 failed. Headless, **not Studio**. I did not run `roblox/scripts/check.sh` (the lead does).
- 17 hand-made mutants of `Gear.luau`, all killed: opts ignored, `KitShield` missing on the default path and on `{ shield = false }`, shield on `RightGripAttachment`, collidable / queryable / anchored / unwelded shield parts, 7 extra parts (> 10), shield mirrored to +X, shield sunk into the forearm, boss behind the rim, face without `KitTint`, `KitShield` on every weapon, shield removed from the default Tool, `KitArmour` on the shield, `KitReach` changed by opts.
- Part counts: sword 6 + shield 4 = 10 = the old Tool's 10. Gear is built client / loadout side only, so the all-built ceiling is unaffected (KitCeiling and WorldService green, no count changed).
- Render (Blender, from the real Kit parts on stand-in avatars; I looked at it): `games/game-001/art/reviews/img/fl0072_shield_hand.jpg`. The shield reads as carried on the left with the sword in the right hand. Defects I see: the disc (2.8 studs, as before) is wider than the torso, hides the left forearm and part of the left pauldron; the stand-in has no hands, so nothing shows what holds it and it stands 0.2 stud ahead of the arm's end. **Hanging arm: the disc lies flat under the fist like a tray and clips the thigh** (see the first caveat). **Not seen in Studio.**

## Interfaces touched
Additive: `Kit.shield` (new export), `Kit.weapon` third parameter `opts`, Tool attribute `KitShield`, `Kit.VERSION` "0.6.1". No breaking change: I dumped every part (name, class, size, CFrame, colour, material, KitTint, KitPart), the Grip and the KitReach / KitHands of all four weapons and all armour pieces with the old `Gear.luau` (9240266c) and the new one: identical. The only addition on the default `swordShield` Tool is the attribute `KitShield`. **FORGE-00:** CONTRACTS G12.6's Kit rows (`Kit.weapon(weapon: Weapon, kingdomColor: Color3?): Tool`, line 1115) need the extra parameter and the new `Kit.shield` row; I did not touch CONTRACTS.md.

## Open issues and risks
- **Grip frame (unverified in Studio).** The shield is modelled in the left hand's grip frame: the frame the hand has when the arm points forward (+Y up, -Z forward along the arm toward the fingers, +X right). I assume a real R15 `LeftHand` carries `LeftGripAttachment` turned Rx(-90) from the hand part (the same assumption the weapons already make for the right hand). If Studio shows something else, the fix is one constant, `SHIELD_CF` in `Kit/Gear.luau` (FORGE-02 will adjust it from your look).
- **Hanging arm.** The shield's face points along the arm toward the fingers, so with the arm hanging it faces the ground (a tray under the fist). Equip it only for the duel, with the left arm raised. The poses decide how it faces: it follows the arm direction, so from `DuelPoses` (hand arithmetic from the slash numbers, **not rendered**): ready (LeftArm 65, Rz -10) about 25 degrees below level, slightly outward; block (95, Rz +25) level and turned in across the chest; light windup (60, Rz -20) about 30 below level; light strike (25, Rz -30) about 65 below level, i.e. nearly face down. FORGE-04: if a champion wears the shield, keep `LeftArm` at 60 or more through the strike, or accept a dipping shield; a left-arm elbow bend (`LeftElbow`) would be the better fix.
- **R6 is unverified.** I do not know that R6's `Left Arm` carries `LeftGripAttachment`. If it does not, `Humanoid:AddAccessory` cannot place the shield. At equip time check `character:FindFirstChild("LeftGripAttachment", true)`; when it is nil, fall back to `Kit.weapon("swordShield", color)` (shield on the Tool, as today) and skip `Kit.shield`.
- With `{ shield = false }` the sword has **no** kingdom-coloured part (it never had one; the shield face carried the colour). The kingdom colour of a sword-and-shield champion is the shield's face only.
- Cleaning up: the shield has no `KitArmour` attribute (it is not armour). Remove gear by `KitPiece` (set on every armour piece and on the shield), or by the name `KitShield`, not by `KitArmour`.
- A later PR may drop the shield from `Kit.weapon("swordShield")` once nothing uses the old form (FORGE-00's call; then `KitShield` can stay as the marker).

## Next actions for the receiver
1. FORGE-01 (FL-0140 equip path, #271): for a `swordShield` loadout:
   ```lua
   local tool = Kit.weapon("swordShield", color, { shield = false })  -- Backpack, then EquipTool as for every weapon
   if tool:GetAttribute("KitShield") and character:FindFirstChild("LeftGripAttachment", true) then
       humanoid:AddAccessory(Kit.shield(color))  -- the equip path the armour uses; remove it with the armour
   else
       tool = Kit.weapon("swordShield", color)   -- R6 without the attachment: the shield stays on the Tool
   end
   ```
   Recolour with `Kit.setKingdomColor(accessory, color)` as for armour. Remove the shield at the crowning, on a cancel and on destroy, like the armour pieces. Until you switch, nothing changes.
2. FORGE-04: nothing required. If a champion will wear the shield, read the pose notes above and the guard / ready / strike LeftArm values in `DuelPoses.luau`; do not edit `Kit/Gear.luau` (ask FORGE-02 for a different shield pitch or position).
3. FORGE-00: add the G12.6 rows (see Interfaces touched); decide when the old form may be dropped.
4. FORGE-02 (me): after a Studio look, tune `SHIELD_CF`; consider a smaller buckler (2.2 to 2.4 studs) so the forearm and cop show.

### Studio steps (user, Windows; none were run)
1. On a real **R15** avatar in a test place, in the command bar: `local Kit = require(game.ReplicatedStorage.Game.Kit.Kit)`, then `print(char:FindFirstChild("LeftGripAttachment", true), char.LeftHand.LeftGripAttachment.Orientation)` (expect `(-90, 0, 0)`; write down what you see) and `char.Humanoid:AddAccessory(Kit.shield(Color3.fromRGB(46, 108, 196)))`.
2. With the left arm hanging: the shield will lie flat under the hand (known). Raise the arm (`char.LeftUpperArm` shoulder `LeftShoulder.Transform = CFrame.Angles(math.rad(95), 0, math.rad(25))` or a DuelPoses guard): the shield should stand in front of the fist, facing forward, on the outside of the forearm, clear of the face. Screenshot from the front and the left side.
3. Equip `Kit.weapon("swordShield", color, { shield = false })` in the right hand: the sword upright, the shield on the left; no second shield.
4. On an **R6** avatar: `print(char["Left Arm"]:FindFirstChild("LeftGripAttachment"))`; if nil the accessory will not attach (use the fallback above).
5. Send FORGE-02 the orientation printout and the screenshots; if the shield is rotated or offset, only `SHIELD_CF` changes.

## Files to read
- `games/game-001/src/shared/Kit/Gear.luau` — `Gear.shield`, `roundShieldSpecs`, `SHIELD_CF`, `Gear.weapon` opts; the header says it all
- `games/game-001/tests/world/KitGear.spec.luau` — the shield and opts specs
- `games/game-001/tests/world/support/AvatarStandIn.luau` — `LeftGripAttachment`, `{ guard = true }`
- `games/game-001/art/reviews/kit-architecture.md` — "FL-0072 follow-up — the shield on the left hand"
- `games/game-001/art/reviews/img/fl0072_shield_hand.jpg` — the render
