# Handoff: FORGE-01 → FORGE-00, FORGE-02, FORGE-04 (cc FORGE-05, FORGE-07) · FL-0140: the Crown Arena's champions, gear and venue · 2026-10-19

With the arena on, a solo player no longer duels an invisible AI. The arena now puts a body on the AI champion's mark, dresses every champion in the loadout, dresses the venue in the two qualifiers' colours and tells the sim about each placement.

## What changed
- **`Arena/Figures.luau`** (new, shared; the Kit is injected so a spec can record it) and **`ArenaService`**:
  - **AI champion figure.** At the start of the intro, for each AI champion: `Kit.character("governor", "idle", <kingdom colour>, nil, <kingdom>)` on its mark (feet = mark height − 3, facing the other mark), anchored, parented under `Workspace.ArenaFigures`, named `ArenaChampion<userId>`. **Tagged `ArenaChampion` (CollectionService) with the attribute `ArenaSide` = `"a"` | `"b"`** (the DuelRunner side) for FORGE-04's FL-0141 animations; the rig is `Kit.character`'s as it comes (Root anchored, Motor6D joints named after `Sim/Pose.JOINTS`), and the figure code adds only Welds for gear.
  - **A real pose.** `ArenaService:poseOf(userId)` answers for an AI champion from its figure, so DuelRunner's range and facing are measured, not virtual. In the duel the figure walks towards its opponent at `Arena.ring.walkSpeed` and stops at 0.7 × `reach` (an AI has no avatar to move; without the walk two figures 26 studs apart never fight). A player can walk out of its reach.
  - **Gear.** Every champion wears `Kit.armour(armour, kingdom colour)` and `Kit.weapon(weapon, kingdom colour)` from the loadout: humans on their own character (`Humanoid:AddAccessory`, `Humanoid:EquipTool`), re-applied if the character resets; the AI figure by welding each Accessory's Handle to the rig's Head or Torso at the point its Attachment names (HatAttachment, BodyFront/Back, Left/RightCollar), measured from the part's size, and the weapon at the right fist, tilted forward, replacing the rig's own spear.
  - **Venue dress.** `Kit.arenaDress(CrownArena, colour of side a, colour of side b)` at the intro; `Kit.arenaDress(model, nil, nil)` (neutral) when the arena ends.
  - **Clean-up.** The figure, all gear and the dress go at the crowning (`done`), on a cancel and on `destroy`.
  - **`snapRuler`.** `MatchHost:snapRuler(userId)` after every placement (the intro, a reset, a put-back at the ring edge), so the sim's copy of the champion does not walk 9 to 14 s from the plot at `rulerMaxSpeed`.
- Specs `sim/ArenaService` (+8, against a recording fake Kit). Mutation rows: `FL-0140.py`, 12 of 12 caught.
- Fairness: unchanged. The model, its caps and config Duel are untouched (the fairness gate drives scripted duellists, not ArenaService).

## Proposed CONTRACTS G12.6 rows (FORGE-00 lands them)
| Name | Kind | Values | Notes |
|---|---|---|---|
| `ArenaChampion` | CollectionService tag | on the AI champion's Model, server-created, `Workspace.ArenaFigures` | exists only between the intro and the crowning |
| attribute `ArenaSide` | string | `"a"` \| `"b"` | the DuelRunner side |
| `Workspace.ArenaFigures` | Folder | AI champion figures `ArenaChampion<userId>` | removed at the end |

Human champions are found from `ArenaState.a/b.userId` → `Player.Character`; no tag.

## Evidence (headless only)
`sim/ArenaService` 44/0 (the 8 new specs: figure on its mark with tag, side and pose; walks to reach; human gear; venue dress and reset; clean-up after the crowning and on a cancel; snapRuler; re-dress after a reset); StyLua clean; Selene 0 warnings.

## Open issues and risks (unverified)
- **Nothing here was seen.** How the welded armour and the tilted weapon look on the Kit rig, whether `Humanoid:AddAccessory` fits an R15/R6 avatar with `Kit.armour` (FORGE-02's specs use stand-in avatars), and whether the anchored figure's welded pieces follow when the figure walks (`Model:PivotTo`) are all Studio checks.
- The figure uses the default governor look (no per-kingdom governor look is wired); `Kit.character`'s `governor` style gives it the crown and staff, then the loadout weapon replaces the staff.
- The AI figure's armour/weapon fits are computed from part sizes; if a piece floats or clips, the offsets in `Figures._fitArmour` / `_fitWeapon` are the place to look.
