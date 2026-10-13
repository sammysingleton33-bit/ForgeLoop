"""FL-0027 mutation rows, run by ../mutations.py (FL-0027 only: `mutations.py FL-0027`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0027 here only (D-038 (7)).
"""
M = [
 ("FL-0027", X+"NotificationQueue.luau", 'if #self._visible < config.maxVisible then', 'if true then', "Notification", "shows at most 3", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if shown.priority < item.priority and', 'if shown.priority <= item.priority and', "Notification", "shows at most 3", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'item.expiresAt = math.min(refreshed, (item.shownAt :: number) + config.maxRefreshSec)', 'item.expiresAt = refreshed', "Notification", "not past maxRefreshSec", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if self.filter == "important" and not important then', 'if false then', "Notification", "the 'important' filter keeps only", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if #pending >= self._config.maxPending then', 'if false then', "Notification", "keeps at most maxPending waiting", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'if item.priority > waiting.priority then', 'if false then', "Notification", "keeps at most maxPending waiting", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if how == "shown" or how == "replaced" then', 'if how ~= "filtered" and how ~= "invalid" then', "Notification", "with a ×N badge", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'local cooling = last ~= nil and now - last.at < (spec.cooldownSec or 1)', 'local cooling = false', "Notification", "coalesces the same celebration", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if cooling and (key == nil or last.keys[key]) then', 'if cooling then', "Notification", "a different moment of the same kind", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'local data = if type(payload) == "table" then payload else nil', 'local data = payload', "Notification", "a payload that is not a table", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'root.stack.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, top)', 'root.stack.Position = Def.POSITION', "Notification", "place() follows the game's layout", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'top = math.max(top, px)', 'local _ = px', "Notification", "place() follows the game's layout", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", ' and spec.durationSec == spec.durationSec -- not NaN', '', "Notification", "a NaN duration gets the kind's default", "fw"),
 ("FL-0027", X+"NotificationQueue.luau", 'return if #text > limit then string.sub(text, 1, limit) .. "…" else text', 'return text', "Notification", "a NaN duration gets the kind's default", "fw"),
 ("FL-0027", C+"OnboardingController.luau", '	self:_reserve(Def.CARD_RESERVE)\n', '', "OnboardingController", "keeps the toast stack below the card", "fw"),
 ("FL-0027", C+"OnboardingController.luau", '		self:_reserve(nil)\n		return', '		return', "OnboardingController", "keeps the toast stack below the card", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'return if missing then nil else id', 'return id', "Notification", "never asks for the sound id", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'self:_announce(item, spec.silent == true)', 'self:_announce(item, false)', "Notification", "celebration toasts are important", "fw"),
 ("FL-0027", C+"NotificationController.luau", 'if spec.sound ~= nil and not hasVisual then', 'if false then', "Notification", "games register celebrations", "fw"),
 ("FL-0027", C+"NotificationController.luau", '				self.queue:setFilter(value)', '				local _ = value', "Notification", "applies the notifications setting live", "fw"),
 ("FL-0027", C+"OnboardingController.luau", 'if wasActive and state.done and not state.skipped then', 'if state.done then', "OnboardingController", "celebrates when the last step completes", "fw"),
]
