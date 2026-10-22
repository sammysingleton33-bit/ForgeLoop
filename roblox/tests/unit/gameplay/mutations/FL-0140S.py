"""FL-0140S mutation rows (the sword-and-shield champion's shield on the left hand: Arena/Figures, over Kit.shield #279).
Run by ../mutations.py (`mutations.py FL-0140S`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
FG = G + "src/shared/Arena/Figures.luau"
SW = "pcall(kit.weapon, spec.weapon, spec.color, if shielded then { shield = false } else nil)"
M = [
 ("FL-0140S", FG, 'if weapon ~= "swordShield" or kit.shield == nil then', 'if kit.shield == nil then', "sim/ArenaService", "gives another weapon no shield"),
 ("FL-0140S", FG, SW + "\n\tif weaponOk and tool ~= nil then\n\t\tif self:_fitWeapon", "pcall(kit.weapon, spec.weapon, spec.color)\n\tif weaponOk and tool ~= nil then\n\t\tif self:_fitWeapon", "sim/ArenaService", "puts the shield on the AI figure's left hand and the sword alone"),
 ("FL-0140S", FG, SW + "\n\tif weaponOk and tool ~= nil then\n\t\tlocal equipped", "pcall(kit.weapon, spec.weapon, spec.color)\n\tif weaponOk and tool ~= nil then\n\t\tlocal equipped", "sim/ArenaService", "gives a human champion the shield accessory and the sword alone"),
 ("FL-0140S", FG, 'hasGrip = character:FindFirstChild("LeftGripAttachment", true) ~= nil', 'hasGrip = true', "sim/ArenaService", "keeps the shield on the Tool for a human whose character has no grip attachment"),
 ("FL-0140S", FG, 'return arm, if arm then CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0) else nil', 'return arm, if arm then CFrame.new(0, arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0) else nil', "sim/ArenaService", "puts the shield on the AI figure's left hand and the sword alone"),
 ("FL-0140S", FG, 'local arm = partNamed(model, "LeftArm")', 'local arm = partNamed(model, "RightArm")', "sim/ArenaService", "puts the shield on the AI figure's left hand and the sword alone"),
 ("FL-0140S", FG, 'return arm, if arm then CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0) else nil', 'return arm, if arm then CFrame.new(0, -arm.Size.Y / 2, 0) else nil', "sim/ArenaService", "puts the shield on the AI figure's left hand and the sword alone"),
 ("FL-0140S", FG, 'hasGrip = character:FindFirstChild("LeftGripAttachment", true) ~= nil', 'hasGrip = character:FindFirstChild("LeftGripAttachment") ~= nil', "sim/ArenaService", "gives a human champion the shield accessory and the sword alone"),
 ("FL-0140S", FG, 'CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0) else nil', 'CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, math.pi, 0) else nil', "sim/ArenaService", "puts the shield on the AI figure's left hand and the sword alone"),
]
