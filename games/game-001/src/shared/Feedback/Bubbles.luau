--!strict
--[[
	Feedback/Bubbles (game-001, FORGE-04, FL-0091; CONTRACTS G13.3): which citizen bubbles exist and
	which are drawn. Pure and clock-injected; CitizenBubbleController draws the result.

		local bubbles = Bubbles.new({ now = env.clock, config = Vfx.bubbles })
		bubbles:thought(entityId, { text, icon = "request" | "concern" | "idea", scenarioId })
		bubbles:reaction(entityId, { text, tone = "happy" | "angry" | "sad" | "neutral" })
		bubbles:strike(entityId, on)                    -- a placard while the citizen strikes
		bubbles:riot(entityId, on)                      -- a placard while the citizen riots (G13.3 v0.4-g10c:
		                                                -- a strike with occupation "riot"; rioters are not strikers)
		bubbles:release(entityId)                       -- the rig went back to the pool (G4.1 released)
		bubbles:tick() -> { entityId }                  -- expired ids
		bubbles:pick(positions, origin) -> { entityId } -- what to draw this frame, nearest first
		bubbles:textLimit(zoom, phone) -> number           -- how many bubbles show words at this view
		bubbles:layout(picked, limit, anchors?, sizes?) -> { [entityId]: "words" | "badge" }
		                                                -- how each picked bubble is drawn (absent: not drawn)
		bubbles:requests() -> { { entityId, since } }   -- open requests ("!" thoughts), for B16's edge
		                                                -- indicators and the cycle key; `since` is when the
		                                                -- request first showed (a repeat keeps it)

	Rules (specs: games/game-001/tests/experience/CitizenBubbles.spec.luau)
		- One bubble per citizen. A reaction replaces that citizen's thought (the request was answered);
		  a new thought replaces an old one. A strike placard is a separate, lasting flag: while it is
		  on and no thought or reaction is showing, the placard shows.
		- Text comes from the event only (no invented text): an event without text is ignored; text
		  is cut to `maxChars` with an ellipsis.
		- Every bubble names its meaning in words or a glyph, never by colour alone (G13.3 "subtitled"):
		  thought icons are "!" (request), "?" (concern), "…" (idea); placards read "On strike" or
		  "Rioting" (a riot placard wins over a strike placard: a rioter is not a striker).
		- Lifetimes: thought `thoughtSec` (refreshed by a repeated thought), reaction `reactionSec`,
		  placard until strike (riot) off.
		- pick(): only citizens within `maxDistance` of the origin (the camera), at most `maxOnScreen`,
		  by priority (reaction > thought > placard) and then distance.
		- layout(): from the aerial camera the kingdom is small on screen, and full bubbles bury each
		  other (the user's first Studio playtest). At most `limit` bubbles show their words, and only
		  where their card covers no other bubble (`anchors`: the screen point under each bubble's
		  bottom edge; without anchors there is no overlap test). Placards (their meaning is their
		  words) and every thought's glyph badge are placed first, so a card never hides a request.
		  Then, nearest first:
		    1. thoughts: words when within the limit and their card is free, else the badge alone
		       (still tappable: requests are what the ruler acts on);
		    2. reactions: words when within the limit and free, else not drawn (the pose, sound and
		       effect still play).
		- textLimit(): `withText` bubbles, `withTextPhone` on a phone screen, `withTextFar` when the
		  camera is more than `farZoom` studs from the view's centre. Bubbles keep their size: words
		  stay readable at every zoom; fewer of them show.
	Pose for a reaction tone (for EntityController, when it offers poses): Bubbles.POSE[tone].
]]

local Bubbles = {}
Bubbles.__index = Bubbles

Bubbles.ICON = table.freeze({ request = "!", concern = "?", idea = "…" })
Bubbles.TONES = table.freeze({ "happy", "angry", "sad", "neutral" })
Bubbles.POSE = table.freeze({ happy = "cheer", angry = "grumble", sad = "slump", neutral = "salute" })
Bubbles.PRIORITY = table.freeze({ reaction = 3, thought = 2, strike = 1, riot = 1 })
Bubbles.STRIKE_TEXT = "On strike"
Bubbles.RIOT_TEXT = "Rioting"
-- the lasting placards: drawn as words, placed before any card (layout)
Bubbles.PLACARD = table.freeze({ strike = true, riot = true })
Bubbles.DEFAULTS = table.freeze({
	maxOnScreen = 8,
	maxDistance = 160,
	thoughtSec = 45,
	reactionSec = 4,
	maxChars = 80,
	withText = 3,
	withTextPhone = 2,
	withTextFar = 1,
	farZoom = 150,
	gapPixels = 4, -- the space kept between a card and other bubbles
})
-- On-screen sizes in pixels (CitizenBubbleController.SIZE draws them); layout() takes them as Vector2s.
Bubbles.SIZES = table.freeze({
	card = Vector2.new(260, 66),
	badge = Vector2.new(46, 46),
	placard = Vector2.new(150, 44),
})

export type Bubble = {
	entityId: number,
	kind: "thought" | "reaction" | "strike" | "riot",
	text: string,
	glyph: string?,
	tone: string?,
	scenarioId: string?,
	shownAt: number,
	since: number?, -- thoughts: when this request first showed (a repeated thought keeps it)
	expiresAt: number?,
}

local function cut(text: any, limit: number): string?
	if type(text) ~= "string" then
		return nil
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end
	local length = utf8.len(trimmed)
	if length and length > limit then
		local stop = utf8.offset(trimmed, limit) or (limit + 1)
		return string.sub(trimmed, 1, stop - 1) .. "…"
	end
	return trimmed
end

-- An entity id: a number, never NaN (NaN cannot be a table key).
local function isId(value: any): boolean
	return type(value) == "number" and value == value
end

function Bubbles.new(opts: { now: () -> number, config: { [string]: any }? })
	local config = table.clone(Bubbles.DEFAULTS)
	for key, value in opts.config or {} do
		config[key] = value
	end
	return setmetatable({
		_now = opts.now,
		_config = config,
		_bubbles = {} :: { [number]: Bubble },
		_striking = {} :: { [number]: boolean },
		_rioting = {} :: { [number]: boolean },
		stats = { ignored = 0 },
	}, Bubbles)
end

-- The bubble that shows for a citizen now (a thought or reaction; else the placard if rioting or striking).
function Bubbles:get(entityId: number): Bubble?
	local bubble = self._bubbles[entityId]
	if bubble ~= nil then
		return bubble
	end
	if self._rioting[entityId] then
		return {
			entityId = entityId,
			kind = "riot",
			text = Bubbles.RIOT_TEXT,
			glyph = nil,
			shownAt = 0,
		}
	end
	if self._striking[entityId] then
		return {
			entityId = entityId,
			kind = "strike",
			text = Bubbles.STRIKE_TEXT,
			glyph = nil,
			shownAt = 0,
		}
	end
	return nil
end

function Bubbles:thought(entityId: any, data: any): Bubble?
	if not isId(entityId) or type(data) ~= "table" then
		self.stats.ignored += 1
		return nil
	end
	local text = cut(data.text, self._config.maxChars)
	if text == nil then
		self.stats.ignored += 1
		return nil
	end
	local current = self._bubbles[entityId]
	if current ~= nil and current.kind == "reaction" then
		-- the answer is still on screen: the next request waits until the reaction has played
		self.stats.ignored += 1
		return nil
	end
	local now = self._now()
	local scenarioId = if type(data.scenarioId) == "string" then data.scenarioId else nil
	local repeated = current ~= nil
		and current.kind == "thought"
		and current.scenarioId == scenarioId
		and current.text == text
	local bubble: Bubble = {
		entityId = entityId,
		kind = "thought",
		text = text,
		glyph = Bubbles.ICON[data.icon] or Bubbles.ICON.request,
		scenarioId = scenarioId,
		shownAt = now,
		since = if repeated and current then current.since or current.shownAt else now,
		expiresAt = now + self._config.thoughtSec,
	}
	self._bubbles[entityId] = bubble
	return bubble
end

function Bubbles:reaction(entityId: any, data: any): Bubble?
	if not isId(entityId) or type(data) ~= "table" then
		self.stats.ignored += 1
		return nil
	end
	local text = cut(data.text, self._config.maxChars)
	if text == nil then
		self.stats.ignored += 1
		return nil
	end
	local now = self._now()
	local tone = if table.find(Bubbles.TONES, data.tone) then data.tone else "neutral"
	local bubble: Bubble = {
		entityId = entityId,
		kind = "reaction",
		text = text,
		tone = tone,
		shownAt = now,
		expiresAt = now + self._config.reactionSec,
	}
	self._bubbles[entityId] = bubble
	return bubble
end

function Bubbles:strike(entityId: any, on: boolean)
	if not isId(entityId) then
		self.stats.ignored += 1
		return
	end
	self._striking[entityId] = if on then true else nil
end

function Bubbles:riot(entityId: any, on: boolean)
	if not isId(entityId) then
		self.stats.ignored += 1
		return
	end
	self._rioting[entityId] = if on then true else nil
end

function Bubbles:release(entityId: number)
	if not isId(entityId) then
		return
	end
	self._bubbles[entityId] = nil
	self._striking[entityId] = nil
	self._rioting[entityId] = nil
end

-- Open requests: "!" thoughts that have not expired, in no particular order (Feedback/Requests orders).
function Bubbles:requests(): { { entityId: number, since: number } }
	local now = self._now()
	local out = {}
	for entityId, bubble in self._bubbles do
		local live = bubble.expiresAt == nil or bubble.expiresAt > now
		if bubble.kind == "thought" and bubble.glyph == Bubbles.ICON.request and live then
			table.insert(out, { entityId = entityId, since = bubble.since or bubble.shownAt })
		end
	end
	return out
end

-- Removes expired thoughts and reactions; returns their ids.
function Bubbles:tick(): { number }
	local now = self._now()
	local expired = {}
	for entityId, bubble in self._bubbles do
		if bubble.expiresAt ~= nil and bubble.expiresAt <= now then
			self._bubbles[entityId] = nil
			table.insert(expired, entityId)
		end
	end
	table.sort(expired)
	return expired
end

-- Which citizens' bubbles to draw: positions = { [entityId]: Vector3 } of rendered citizens.
function Bubbles:pick(positions: { [number]: Vector3 }, origin: Vector3): { number }
	local config = self._config
	local candidates = {}
	for entityId, position in positions do
		local bubble = self:get(entityId)
		if bubble ~= nil then
			local distance = (position - origin).Magnitude
			if distance <= config.maxDistance then
				table.insert(
					candidates,
					{ id = entityId, priority = Bubbles.PRIORITY[bubble.kind], distance = distance }
				)
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	local out = {}
	for index = 1, math.min(#candidates, config.maxOnScreen) do
		table.insert(out, candidates[index].id)
	end
	return out
end

-- How many thoughts show their words at this view (see Rules).
function Bubbles:textLimit(zoom: number?, phone: boolean?): number
	local config = self._config
	local limit = config.withText
	if phone then
		limit = math.min(limit, config.withTextPhone)
	end
	if type(zoom) == "number" and zoom > config.farZoom then
		limit = math.min(limit, config.withTextFar)
	end
	return limit
end

-- How each picked bubble is drawn (see Rules): { [entityId] = "words" | "badge" }; absent = not drawn.
-- anchors[id]: the screen point (Vector2) under the bubble's bottom edge, centred; sizes: Bubbles.SIZES.
function Bubbles:layout(
	picked: { number },
	limit: number?,
	anchors: { [number]: Vector2 }?,
	sizes: { [string]: Vector2 }?
): { [number]: string }
	local most = if type(limit) == "number" then limit else self._config.withText
	local gap = self._config.gapPixels
	local size = sizes or Bubbles.SIZES
	local placed = {} -- { rect, owner }: what a card may not cover
	local function rectOf(entityId: number, box: Vector2): { number }?
		local at = anchors and anchors[entityId]
		if at == nil then
			return nil
		end
		return { at.X - box.X / 2, at.Y - box.Y, at.X + box.X / 2, at.Y }
	end
	local function free(rect: { number }?, owner: number): boolean
		if rect == nil then
			return true
		end
		for _, other in placed do
			local r = other.rect
			if
				other.owner ~= owner
				and rect[1] < r[3] + gap
				and r[1] < rect[3] + gap
				and rect[2] < r[4] + gap
				and r[2] < rect[4] + gap
			then
				return false
			end
		end
		return true
	end
	local function place(rect: { number }?, owner: number)
		if rect ~= nil then
			table.insert(placed, { rect = rect, owner = owner })
		end
	end
	local out = {}
	for _, entityId in picked do -- placards and every request's badge first: nothing may hide them
		local bubble = self:get(entityId)
		if bubble ~= nil and Bubbles.PLACARD[bubble.kind] then
			out[entityId] = "words"
			place(rectOf(entityId, size.placard), entityId)
		elseif bubble ~= nil and bubble.kind == "thought" then
			out[entityId] = "badge"
			place(rectOf(entityId, size.badge), entityId)
		end
	end
	local words = 0
	for _, kind in { "thought", "reaction" } do
		for _, entityId in picked do
			local bubble = self:get(entityId)
			if bubble ~= nil and bubble.kind == kind and words < most then
				local card = rectOf(entityId, size.card)
				if free(card, entityId) then
					words += 1
					out[entityId] = "words"
					place(card, entityId)
				end
			end
		end
	end
	return out
end

return table.freeze(Bubbles)
