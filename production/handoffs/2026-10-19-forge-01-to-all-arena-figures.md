# Handoff: FORGE-01 → FORGE-00, FORGE-02, FORGE-04 (cc FORGE-05, FORGE-07) · FL-0140: the Crown Arena's champions, gear and venue · 2026-10-19

With the arena on, a solo player no longer duels an invisible AI. The arena now puts a body on the AI champion's mark, dresses every champion in the loadout, dresses the venue in the two qualifiers' colours and tells the sim about each placement.

## What changed
- **`Arena/Figures.luau`** (new, shared; the Kit is injected so a spec can record it) and **`ArenaService`**:
  - **AI champion figure.** At the start of the intro, for each AI champion: `Kit.character("governor", "idle", <kingdom colour>, nil, <kingdom>)` on its mark (feet = mark height − 3, facing the other mark), anchored, parented under `Workspace.ArenaFigures`, named `ArenaChampion<userId>`. **Tagged `ArenaChampion` (CollectionService) with the attribute `ArenaSide` = `"a"` | `"b"`** (the DuelRunner side) for FORGE-04's FL-0141 animations; the rig is `Kit.character`'s as it comes (Root anchored, Motor6D joints named after `Sim/Pose.JOINTS`), and the figure code adds only Welds for gear.
  - **A real pose.** `ArenaService:poseOf(userId)` answers for an AI champion from its figure, so DuelRunner's range and facing are measured, not virtual. In the duel the figure walks towards its opponent at `Arena.ring.walkSpeed` and stops at 0.7 × `reach` (an AI has no avatar to move; without the walk two figures 26 studs apart never fight). A player can walk out of its reach.
  - **Gear.** Every champion wears `Kit.armour(armour, kingdom colour)` and `Kit.weapon(weapon, kingdom colour)` from the loadout: humans on their own character (`Humanoid:AddAccessory`, `Humanoid:EquipTool`), re-applied if the character resets; the AI figure by welding each Accessory's Handle to the rig's Head or Torso at the point its Attachment names (HatAttachment, BodyFront/Back, Left/RightCollar), measured from the part's size, and the weapon welded at the right fist to the rig's own `Tool` part, `Tool.Grip` as the weld's C1 (the plain Grip rest, the blade square to the arm, as a human's `EquipTool` has it; FORGE-04's wrist poses assume it). The `Tool` part stays, invisible, with every part welded to it destroyed (the spearhead, the pennant, the governor's orb), because the rig's `Tool` joint (Sim/Pose.JOINTS) drives it: the wrist angle of #269 reaches the AI's weapon.
  - **Venue dress.** `Kit.arenaDress(CrownArena, colour of side a, colour of side b)` at the intro; `Kit.arenaDress(model, nil, nil)` (neutral) when the arena ends.
  - **Clean-up.** The figure, all gear, the `ArenaFigures` folder and the dress go at the crowning (`done`), on a cancel, on `destroy` and after a mid-duel leaver forfeit.
  - **`snapRuler`.** `MatchHost:snapRuler(userId)` after every placement (the intro, a reset, a put-back at the ring edge), so the sim's copy of the champion does not walk 9 to 14 s from the plot at `rulerMaxSpeed`.
- Specs `sim/ArenaService` (against a recording fake Kit whose rig has the Kit's own rules: Root 3.2 above the feet with `PivotOffset`, a `Tool` part driven by a `Tool` Motor6D with a detail welded to it, a weapon with `Grip`, armour holding named Attachments). Mutation rows: `FL-0140.py`, 32 of 32 caught.
- **Checked for FORGE-00's list:** the AI figure never runs faster than `Arena.ring.walkSpeed` (a spec measures its path over a stretch against the clock) and never leaves the ring (the walk is clamped to the ring's radius; a spec asks it to walk 60 studs outside); a human running circles at the ring edge at the AI's own speed (16) stays within its reach on every sample (237 of 237, closest 1.7 studs): running is no escape from the AI, only blocking, parrying and dodging are (a finding for pose sanity, B23); the figure is removed on a cancel, at the crowning, on destroy and after a mid-duel leaver forfeit (specs for each).
- Fairness: unchanged. The model, its caps and config Duel are untouched (the fairness gate drives scripted duellists, not ArenaService).

## Proposed CONTRACTS G12.6 rows (FORGE-00 lands them)
| Name | Kind | Values | Notes |
|---|---|---|---|
| `ArenaChampion` | CollectionService tag | on the AI champion's Model, server-created, `Workspace.ArenaFigures` | exists only between the intro and the crowning |
| attribute `ArenaSide` | string | `"a"` \| `"b"` | the DuelRunner side |
| `Workspace.ArenaFigures` | Folder | AI champion figures `ArenaChampion<userId>` | removed at the end |

Human champions are found from `ArenaState.a/b.userId` → `Player.Character`; no tag.

## Evidence (headless only)
`sim/ArenaService` passes (counts in the PR, run on the merge with main); geometry specs pin the feet height over 200 duel steps, the facing sign (dot > 0.9) after walking, the weapon's tip above the hand and not out to the side, the rig's own held item gone with its joint intact, the helm on top of the head and the plate on the chest, the walk's catch-up clamp, the venue's side A in the colour of the kingdom on mark A, the snap after a ring put-back, and the clean-up on destroy; StyLua clean; `selene games roblox` 0 warnings.

## Open issues and risks (unverified)
- **Nothing here was seen.** How the welded armour and the tilted weapon look on the Kit rig, whether `Humanoid:AddAccessory` fits an R15/R6 avatar with `Kit.armour` (FORGE-02's specs use stand-in avatars), and whether the anchored figure's welded pieces follow when the figure walks (`Model:PivotTo`) are all Studio checks.
- The figure uses the default governor look (no per-kingdom governor look is wired); `Kit.character`'s `governor` style gives it the crown and staff, then the loadout weapon replaces the staff.
- The AI figure's armour/weapon fits are computed from part sizes; if a piece floats or clips, the offsets in `Figures._fitArmour` / `_fitWeapon` are the place to look.
- **The rule changed on purpose (FORGE-00's ruling).** Before, a duel against an AI ignored range and facing. Now the human must be within reach (6.5) of the figure and face it for a swing to land. The fairness gate cannot see this (G12.3 note).
- **A human can probably unequip the weapon** (`Humanoid:EquipTool` with the default Backpack on). Unverified in Studio. It is cosmetic: the duel reads the loadout server-side.
- **The AI figure glides** while it closes in (nothing animates its legs): FORGE-04's FL-0141 follow-up.
- `Kit.shield` (FORGE-02) will get an ArenaService follow-up (sword-and-shield champions: `Kit.weapon(..., { shield = false })` plus the shield, and for the AI figure the shield welded to the left arm).
