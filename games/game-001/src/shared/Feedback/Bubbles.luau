--!strict
--[[
	Feedback/Bubbles (game-001, FORGE-04, FL-0091; CONTRACTS G13.3): which citizen bubbles exist and
	which are drawn. Pure and clock-injected; CitizenBubbleController draws the result.

		local bubbles = Bubbles.new({ now = env.clock, config = Vfx.bubbles })
		bubbles:thought(entityId, { text, icon = "request" | "concern" | "idea", scenarioId })
		bubbles:reaction(entityId, { text, tone = "happy" | "angry" | "sad" | "neutral" })
		bubbles:strike(entityId, on)                    -- a placard while the citizen strikes
		bubbles:release(entityId)                       -- the rig went back to the pool (G4.1 released)
		bubbles:tick() -> { entityId }                  -- expired ids
		bubbles:pick(positions, origin) -> { entityId } -- what to draw this frame, nearest first

	Rules (specs: games/game-001/tests/experience/CitizenBubbles.spec.luau)
		- One bubble per citizen. A reaction replaces that citizen's thought (the request was answered);
		  a new thought replaces an old one. A strike placard is a separate, lasting flag: while it is
		  on and no thought or reaction is showing, the placard shows.
		- Text comes from the event only (no invented text): an event without text is ignored; text
		  is cut to `maxChars` with an ellipsis.
		- Every bubble names its meaning in words or a glyph, never by colour alone (G13.3 "subtitled"):
		  thought icons are "!" (request), "?" (concern), "…" (idea); placards read "On strike".
		- Lifetimes: thought `thoughtSec` (refreshed by a repeated thought), reaction `reactionSec`,
		  placard until strike off.
		- pick(): only citizens within `maxDistance` of the origin (the camera), at most `maxOnScreen`,
		  by priority (reaction > thought > placard) and then distance.
	Pose for a reaction tone (for EntityController, when it offers poses): Bubbles.POSE[tone].
]]

local Bubbles = {}
Bubbles.__index = Bubbles

Bubbles.ICON = table.freeze({ request = "!", concern = "?", idea = "…" })
Bubbles.TONES = table.freeze({ "happy", "angry", "sad", "neutral" })
Bubbles.POSE = table.freeze({ happy = "cheer", angry = "grumble", sad = "slump", neutral = "salute" })
Bubbles.PRIORITY = table.freeze({ reaction = 3, thought = 2, strike = 1 })
Bubbles.STRIKE_TEXT = "On strike"
Bubbles.DEFAULTS = table.freeze({
	maxOnScreen = 8,
	maxDistance = 160,
	thoughtSec = 45,
	reactionSec = 4,
	maxChars = 80,
})

export type Bubble = {
	entityId: number,
	kind: "thought" | "reaction" | "strike",
	text: string,
	glyph: string?,
	tone: string?,
	scenarioId: string?,
	shownAt: number,
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
		stats = { ignored = 0 },
	}, Bubbles)
end

-- The bubble that shows for a citizen now (a thought or reaction; else the placard if striking).
function Bubbles:get(entityId: number): Bubble?
	local bubble = self._bubbles[entityId]
	if bubble ~= nil then
		return bubble
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
	local bubble: Bubble = {
		entityId = entityId,
		kind = "thought",
		text = text,
		glyph = Bubbles.ICON[data.icon] or Bubbles.ICON.request,
		scenarioId = if type(data.scenarioId) == "string" then data.scenarioId else nil,
		shownAt = now,
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

function Bubbles:release(entityId: number)
	if not isId(entityId) then
		return
	end
	self._bubbles[entityId] = nil
	self._striking[entityId] = nil
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

return table.freeze(Bubbles)
