"""FL-0140F mutation rows (follow-up to FL-0140, FORGE-07's M2/M3 on #271: the AI figure's weapon rest and grip point, the
armour fits, the AI champion's loadout names; Arena/Figures). Run by ../mutations.py (`mutations.py FL-0140F`).
One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
FG = G + "src/shared/Arena/Figures.luau"
M = [
 ("FL-0140F", FG, '* CFrame.new(0, -fist.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)', '* CFrame.new(0, -fist.Size.Y / 2, 0)', "sim/ArenaService", "holds the loadout weapon up from the AI figure's hand"),
 ("FL-0140F", FG, 'CFrame.new(0, -fist.Size.Y / 2, 0) * CFrame.Angles', 'CFrame.new(0, fist.Size.Y / 2, 0) * CFrame.Angles', "sim/ArenaService", "holds the loadout weapon up from the AI figure's hand"),
 ("FL-0140F", FG, 'weld(self._new, part, handle, offset * child.CFrame:Inverse())', 'weld(self._new, part, handle, offset)', "sim/ArenaService", "puts the armour where its Attachment names"),
 ("FL-0140F", FG, 'return torso, CFrame.new(-size.X / 2, size.Y / 2, 0)', 'return torso, CFrame.new(size.X / 2, size.Y / 2, 0)', "sim/ArenaService", "puts the armour where its Attachment names"),
 ("FL-0140F", FG, 'return torso, CFrame.new(size.X / 2, size.Y / 2, 0)', 'return torso, CFrame.new(-size.X / 2, size.Y / 2, 0)', "sim/ArenaService", "puts the armour where its Attachment names"),
 ("FL-0140F", FG, 'return torso, CFrame.new(0, 0, size.Z / 2)', 'return torso, CFrame.new(0, 0, -size.Z / 2)', "sim/ArenaService", "puts the armour where its Attachment names"),
 ("FL-0140F", FG, '\tmodel.Parent = self._folder\n\tlocal armourOk, accessories = pcall(kit.armour, spec.armour, spec.color)', '\tmodel.Parent = self._folder\n\tlocal armourOk, accessories = pcall(kit.armour, "light", spec.color)', "sim/ArenaService", "asks the Kit for the AI champion's own loadout"),
 ("FL-0140F", FG, 'pcall(kit.weapon, spec.weapon, spec.color)\n\tif weaponOk and tool ~= nil then\n\t\tif self:_fitWeapon', 'pcall(kit.weapon, "greatsword", spec.color)\n\tif weaponOk and tool ~= nil then\n\t\tif self:_fitWeapon', "sim/ArenaService", "asks the Kit for the AI champion's own loadout"),
]
