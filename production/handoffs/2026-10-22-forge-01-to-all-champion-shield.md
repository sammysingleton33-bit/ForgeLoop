# FORGE-01 → all (cc FORGE-02, FORGE-04, FORGE-00): the sword-and-shield champion carries Kit.shield on the left hand

Uses FORGE-02's `Kit.shield` / `Kit.weapon(..., { shield = false })` (#279) as its handoff asked.

- **AI figure** (`Arena/Figures.spawn`): for a `swordShield` loadout the shield Accessory is welded at the end of the figure's `LeftArm` in the hand's grip frame (the mirror of the weapon's rest: `CFrame.new(0, -arm.Size.Y/2, 0) * Angles(-pi/2, 0, 0)`), and the sword is asked for alone (`{ shield = false }`) only when the shield was really fitted. A figure without a `LeftArm` keeps the old form: the shield on the Tool, never both.
- **Human champion** (`Figures:wear`): when the character has a `LeftGripAttachment` (searched recursively) the shield goes on with `Humanoid:AddAccessory` and the sword alone is equipped; otherwise (R6 without the attachment, or AddAccessory failing) the default Tool form with the shield on it, as FORGE-02's handoff recommends. Removed with the other gear (`Figures:clear`).
- Other weapons (greatsword, spear, mace) get no shield.
- **FORGE-04:** the shield follows the left arm. FORGE-02's notes: with the arm hanging the disc lies flat like a tray and clips the thigh; the duel poses keep the arm up. A champion wearing it in your strike poses may want `LeftArm` at 60 or more. Unverified in Studio.
- Unverified in Studio: the real R15 `LeftGripAttachment` orientation (assumed Rx(-90), as the weapons assume for the right), R6, and how the shield looks on the AI rig.
