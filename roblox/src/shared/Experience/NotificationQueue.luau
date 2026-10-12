--!strict
--[[
	Experience/NotificationQueue — the toast queue behind NotificationController (FL-0027).
	Pure and clock-injected, so every rule is a Lune spec (roblox/tests/unit/experience/Notification.spec.luau).

		local queue = NotificationQueue.new({ now = env.clock })
		local item, how = queue:push({ title = "House complete", kind = "success", key = "built:house" })
		queue:tick()                 -- expires items, promotes waiting ones; returns { shown, hidden }
		queue:visible() / queue:pending()

	Items
		{ id, title, body?, kind, key, count, priority, durationSec, shownAt?, expiresAt?, important }
		kind: "info" | "success" | "warning" | "error" | "reward" | "achievement" (interfaces §8 plus
		FORGE-03's Toast kinds). Unknown kinds become "info".

	Rules
		- At most `maxVisible` (3) toasts show at once. Others wait in `pending`, ordered by priority
		  (error = warning > achievement > reward > success = info), then by arrival.
		- Coalescing: a toast whose key (default kind .. ":" .. title) is already visible or waiting adds
		  to that toast's count ("×N") instead of adding a toast. A visible one gets its time refreshed,
		  but never beyond `maxRefreshSec` after it first showed.
		- A higher-priority toast that arrives while the stack is full replaces the oldest visible
		  toast of strictly lower priority (that toast is hidden, not re-queued). Otherwise it waits.
		- At most `maxPending` (8) wait. When full, the lowest-priority, oldest waiting toast is dropped
		  (counted in stats.dropped); a new toast that ranks below everything waiting is dropped itself.
		- Filter "important" (the `notifications` setting): only error, warning and achievement toasts,
		  and toasts with important = true, are accepted; the rest are counted in stats.filtered.
		- durationSec defaults by kind and is clamped to [minSec, maxSec].
		- Title and body are cut to 60 and 140 characters (one-line cards, EXPERIENCE.md §2).
]]

local NotificationQueue = {}
NotificationQueue.__index = NotificationQueue

NotificationQueue.KINDS = table.freeze({ "info", "success", "warning", "error", "reward", "achievement" })
NotificationQueue.PRIORITY =
	table.freeze({ info = 1, success = 1, reward = 2, achievement = 3, warning = 4, error = 4 })
NotificationQueue.IMPORTANT = table.freeze({ warning = true, error = true, achievement = true })
NotificationQueue.DURATION =
	table.freeze({ info = 3.5, success = 3.5, reward = 4, achievement = 5, warning = 5, error = 5 })
NotificationQueue.DEFAULTS = table.freeze({
	maxVisible = 3,
	maxPending = 8,
	minSec = 1,
	maxSec = 10,
	maxRefreshSec = 12,
	titleMax = 60,
	bodyMax = 140,
})

export type Item = {
	id: number,
	title: string,
	body: string?,
	kind: string,
	key: string,
	count: number,
	priority: number,
	durationSec: number,
	important: boolean,
	arrived: number,
	shownAt: number?,
	expiresAt: number?,
	icon: string?,
}

local function cut(text: any, limit: number): string?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	if utf8.len(text) and (utf8.len(text) :: number) > limit then
		local stop = utf8.offset(text, limit) or (limit + 1)
		return string.sub(text, 1, stop - 1) .. "…"
	end
	return text
end

function NotificationQueue.new(opts: { now: () -> number, config: { [string]: any }? })
	local config = table.clone(NotificationQueue.DEFAULTS)
	for key, value in opts.config or {} do
		config[key] = value
	end
	return setmetatable({
		_now = opts.now,
		_config = config,
		_visible = {} :: { Item },
		_pending = {} :: { Item },
		_nextId = 0,
		filter = "all",
		stats = { shown = 0, coalesced = 0, dropped = 0, filtered = 0, replaced = 0, invalid = 0 },
	}, NotificationQueue)
end

function NotificationQueue:visible(): { Item }
	return table.clone(self._visible)
end

function NotificationQueue:pending(): { Item }
	return table.clone(self._pending)
end

function NotificationQueue:setFilter(filter: string)
	self.filter = if filter == "important" then "important" else "all"
end

local function ranksBelow(a: Item, b: Item): boolean
	-- true when `a` should leave before `b` (lower priority, then older)
	if a.priority ~= b.priority then
		return a.priority < b.priority
	end
	return a.arrived < b.arrived
end

function NotificationQueue:_show(item: Item, now: number)
	item.shownAt = now
	item.expiresAt = now + item.durationSec
	table.insert(self._visible, item)
	self.stats.shown += 1
end

function NotificationQueue:_insertPending(item: Item): boolean
	local pending = self._pending
	if #pending >= self._config.maxPending then
		local lowest, lowestIndex = nil, nil
		for index, waiting in pending do
			if lowest == nil or ranksBelow(waiting, lowest) then
				lowest, lowestIndex = waiting, index
			end
		end
		if lowest == nil or item.priority < lowest.priority then
			self.stats.dropped += 1
			return false
		end
		table.remove(pending, lowestIndex :: number)
		self.stats.dropped += 1
	end
	local at = #pending + 1
	for index, waiting in pending do
		if item.priority > waiting.priority then
			at = index
			break
		end
	end
	table.insert(pending, at, item)
	return true
end

-- Returns (item?, how): how = "shown" | "waiting" | "coalesced" | "replaced" | "filtered" | "dropped" | "invalid"
function NotificationQueue:push(spec: { [string]: any }): (Item?, string)
	local config = self._config
	local title = cut(spec.title, config.titleMax)
	if title == nil then
		self.stats.invalid += 1
		return nil, "invalid"
	end
	local kind = if table.find(NotificationQueue.KINDS, spec.kind) then spec.kind else "info"
	local important = NotificationQueue.IMPORTANT[kind] == true or spec.important == true
	if self.filter == "important" and not important then
		self.stats.filtered += 1
		return nil, "filtered"
	end
	local now = self._now()
	local key = if type(spec.key) == "string" and spec.key ~= "" then spec.key else kind .. ":" .. title
	local body = cut(spec.body, config.bodyMax)

	for _, item in self._visible do
		if item.key == key then
			item.count += 1
			item.body = body or item.body
			local refreshed = now + item.durationSec
			item.expiresAt = math.min(refreshed, (item.shownAt :: number) + config.maxRefreshSec)
			self.stats.coalesced += 1
			return item, "coalesced"
		end
	end
	for _, item in self._pending do
		if item.key == key then
			item.count += 1
			item.body = body or item.body
			self.stats.coalesced += 1
			return item, "coalesced"
		end
	end

	self._nextId += 1
	local duration = if type(spec.durationSec) == "number" then spec.durationSec else NotificationQueue.DURATION[kind]
	local item: Item = {
		id = self._nextId,
		title = title,
		body = body,
		kind = kind,
		key = key,
		count = 1,
		priority = NotificationQueue.PRIORITY[kind],
		durationSec = math.clamp(duration, config.minSec, config.maxSec),
		important = important,
		arrived = now,
		icon = if type(spec.icon) == "string" then spec.icon else nil,
	}
	if #self._visible < config.maxVisible then
		self:_show(item, now)
		return item, "shown"
	end
	local victim, victimIndex = nil, nil
	for index, shown in self._visible do
		if shown.priority < item.priority and (victim == nil or ranksBelow(shown, victim)) then
			victim, victimIndex = shown, index
		end
	end
	if victim ~= nil then
		table.remove(self._visible, victimIndex :: number)
		self.stats.replaced += 1
		self:_show(item, now)
		return item, "replaced"
	end
	if self:_insertPending(item) then
		return item, "waiting"
	end
	return nil, "dropped"
end

-- Expires visible toasts and promotes waiting ones. Returns the items shown and hidden by this tick.
function NotificationQueue:tick(): ({ Item }, { Item })
	local now = self._now()
	local shown, hidden = {}, {}
	for index = #self._visible, 1, -1 do
		local item = self._visible[index]
		if (item.expiresAt :: number) <= now then
			table.remove(self._visible, index)
			table.insert(hidden, 1, item)
		end
	end
	while #self._visible < self._config.maxVisible and #self._pending > 0 do
		local item = table.remove(self._pending, 1) :: Item
		self:_show(item, now)
		table.insert(shown, item)
	end
	return shown, hidden
end

-- Removes one toast (a tap dismisses it); the next waiting toast shows on the next tick.
function NotificationQueue:dismiss(id: number): boolean
	for index, item in self._visible do
		if item.id == id then
			table.remove(self._visible, index)
			return true
		end
	end
	return false
end

function NotificationQueue:clear()
	table.clear(self._visible)
	table.clear(self._pending)
end

return table.freeze(NotificationQueue)
