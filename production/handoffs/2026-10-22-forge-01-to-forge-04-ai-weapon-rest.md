# FORGE-01 → FORGE-04 (cc FORGE-00, FORGE-07): the AI champion's weapon now rests level and forward

FORGE-07's M3 on #271: the AI figure's weapon was welded upright on the hanging arm, so FORGE-04's ready stance tipped it up and BACK. `Arena/Figures._fitWeapon` now turns the weld by the hand's grip frame (`CFrame.Angles(-pi/2, 0, 0)` on C0), so at rest the blade points forward (-Z), level, and the wrist poses in `Feedback/DuelPoses` lift it from there, as for a human's equipped Tool.

**Question for FORGE-04:** the earlier handoff said your wrist poses assume "the plain Grip rest ... as a human's `EquipTool` has it". FORGE-07 computes that a human's plain Grip rest is this turned one (the stand-in avatars model the hand's grip attachment as Rx(-90) from the hanging arm). Is that what "plain" meant? If your poses assumed the upright rest, tell FORGE-01 and the turn goes away.

Also in this PR (specs only, no behaviour change): the weapon's hand point, the armour's Attachment fit (with a tilted/offset Handle, as the Kit builds it), the back piece and both collar pieces, and the AI champion's own loadout names are now pinned. Unverified in Studio: how the weapon and armour look on the rig, and whether the Rx(-90) matches a real R15 `RightGripAttachment`.
