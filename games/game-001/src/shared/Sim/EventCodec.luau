--!strict
--[[
	Sim/EventCodec — the reliable entity traffic of CONTRACTS G4: `Sim.Events` (one buffer per tick,
	batched) and `Sim.GetEntities` (one buffer with every live entity). Fields that rarely change
	(kind, job, kingdom, a citizen's look) travel here, never in the per-tick snapshot (Sim/SnapshotCodec).
	The G13.3 conversation events (thought, reaction, strike, kcue) use the same codec; EntityService
	sends them in their own batch to one kingdom's members only.

	Wire layout (little-endian `buffer`):
		header (6 B)   serverTime f32 (seconds since match start) · n u16 (records)
		records, each starting with a tag u8:
			1 spawn    id u16 · kind u8 · job u8 · kingdom u8 · look: skin u8 · hair u8 ·
			           hairColor u8 · outfit u8 (all 0 = no look, the Kit default)        (10 B)
			2 despawn  id u16                                                               (3 B)
			3 job      id u16 · job u8                                                      (4 B)
			4 cue      id u16 · cue u8 · arg u8   (deposit: arg = resource code, else 0)     (5 B)
			5 full     spawn fields + SnapshotCodec record fields (x/y/z i16 at 1/8 stud,
			           yaw u8, state u8)                                                   (18 B)
			6 reset    (no fields: a new match world; drop every entity, ids start over)      (1 B)
			7 thought  id u16 · icon u8 · scenarioId str · text str        (8 B + both strings)
			8 reaction id u16 · tone u8 · text str                                (6 B + text)
			9 strike   on u8 (1 = on, 0 = off) · occupation str                 (4 B + occupation)
			10 kcue    id u16 (0 = none) · cue u8 · occupation str (0 B = none)  (6 B + occupation)
		str = byte length u16 · UTF-8 bytes. text: 0..TEXT_MAX (1024) bytes; scenarioId and
		occupation: 1..ID_MAX (48) bytes.
	Codes (index in the list, from 1): KINDS = G2 EntityKind, JOBS = G2 JobId, KINGDOMS = G2 KingdomId,
	CUES = { deposit, hit, die, celebrate } (G4: looping work animations derive from action + job,
	so there are no per-swing cues), resources = SnapshotCodec.CARRYING, ICONS = { request, concern,
	idea }, TONES = { happy, angry, sad, neutral }, KINGDOM_CUES = the G13.3 consequence cue
	vocabulary { celebrate, grumble, salute, bow, cower, strike_placard, work_fast, rest, hammer }.
	kcue is the G13.3 `cue` event. It has its own type and tag because tag 4's CUES list is frozen
	and both lists hold "celebrate". A content cue outside KINGDOM_CUES cannot be encoded: the sender
	shows it through the reaction tone instead (G13.3).

	API
		EventCodec.encode(serverTime, events): buffer
		EventCodec.decode(buf): (Batch?, string?)    -- nil + reason for a malformed buffer; never errors
		EventCodec.CUES, KINDS, JOBS, KINGDOMS, ICONS, TONES, KINGDOM_CUES, TEXT_MAX, ID_MAX
	Event (input and decoded output), by type:
		{ type = "spawn", id, kind, job, kingdom, look? }   { type = "despawn", id }
		{ type = "job", id, job }                        { type = "cue", id, cue, resource? }
		{ type = "full", id, kind, job, kingdom, look?, x, y, z, yaw, action, carrying? }
	look = CitizenLook { skin, hair, hairColor, outfit } (G13.2): palette indices 1..255.
		{ type = "reset" }
		{ type = "thought", id, scenarioId, text, icon }   { type = "reaction", id, text, tone }
		{ type = "strike", occupation, on: boolean }       { type = "kcue", id?, occupation?, cue }
	encode errors on unknown codes, ids outside 1..65535, look fields outside 1..255, coordinates
	SnapshotCodec rejects, string fields that are not strings, not UTF-8 or outside their byte range,
	and a strike `on` that is not a boolean.
]]

local SnapshotCodec = require("./SnapshotCodec")
local Types = require("../Kingdom/Types")

export type Event = { [string]: any }
export type Batch = { serverTime: number, events: { Event } }

local EventCodec = {}

EventCodec.HEADER_BYTES = 6
EventCodec.KINDS = Types.ENTITY_KINDS
EventCodec.JOBS = Types.JOB_IDS
EventCodec.KINGDOMS = Types.KINGDOM_IDS
EventCodec.CUES = table.freeze({ "deposit", "hit", "die", "celebrate" })
EventCodec.ICONS = table.freeze({ "request", "concern", "idea" })
EventCodec.TONES = table.freeze({ "happy", "angry", "sad", "neutral" })
EventCodec.KINGDOM_CUES = table.freeze({
	"celebrate",
	"grumble",
	"salute",
	"bow",
	"cower",
	"strike_placard",
	"work_fast",
	"rest",
	"hammer",
})
EventCodec.TEXT_MAX = 1024 -- bytes of a thought or reaction text
EventCodec.ID_MAX = 48 -- bytes of a scenarioId or occupation (Kingdom.Choose takes string(1,48))

local TAGS = {
	spawn = 1,
	despawn = 2,
	job = 3,
	cue = 4,
	full = 5,
	reset = 6,
	thought = 7,
	reaction = 8,
	strike = 9,
	kcue = 10,
}
-- Fixed bytes per record; for 7..10 this counts each string's u16 length but not its bytes.
local SIZES = { [1] = 10, [2] = 3, [3] = 4, [4] = 5, [5] = 18, [6] = 1, [7] = 8, [8] = 6, [9] = 4, [10] = 6 }
local LOOK_FIELDS = { "skin", "hair", "hairColor", "outfit" }
local SPAWN_BYTES = 10 -- where a full record's state part starts
local TYPE_OF = { "spawn", "despawn", "job", "cue", "full", "reset", "thought", "reaction", "strike", "kcue" }
local HAS_ID = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true, [8] = true } -- required id

-- String fields of the variable records, in wire order, after `head` fixed bytes. An optional
-- field travels as 0 bytes when absent, so present it must be at least 1 byte.
type StringField = { field: string, min: number, max: number, optional: boolean }
local STRINGS: { [number]: { head: number, fields: { StringField } } } = {
	[7] = {
		head = 4,
		fields = {
			{ field = "scenarioId", min = 1, max = EventCodec.ID_MAX, optional = false },
			{ field = "text", min = 0, max = EventCodec.TEXT_MAX, optional = false },
		},
	},
	[8] = { head = 4, fields = { { field = "text", min = 0, max = EventCodec.TEXT_MAX, optional = false } } },
	[9] = { head = 2, fields = { { field = "occupation", min = 1, max = EventCodec.ID_MAX, optional = false } } },
	[10] = { head = 4, fields = { { field = "occupation", min = 0, max = EventCodec.ID_MAX, optional = true } } },
}
local NO_STRINGS: { string } = table.freeze({})

local function codeOf(list: { string }, value: any, what: string): number
	local index = table.find(list, value)
	assert(index ~= nil, `EventCodec: unknown {what} '{tostring(value)}'`)
	return index :: number
end

local function checkId(id: any)
	assert(
		type(id) == "number" and id >= 1 and id <= 65535 and id % 1 == 0,
		`EventCodec: id {tostring(id)} outside 1..65535`
	)
end

-- The string values of a variable record, checked, in wire order (an absent optional one as "").
local function stringsOf(tag: number, e: Event): { string }
	local spec = STRINGS[tag]
	if spec == nil then
		return NO_STRINGS
	end
	local out = {}
	for _, f in spec.fields do
		local value = e[f.field]
		if value == nil and f.optional then
			table.insert(out, "")
			continue
		end
		local min = if f.optional then 1 else f.min
		assert(type(value) == "string", `EventCodec: {f.field} must be a string, got {typeof(value)}`)
		assert(#value >= min and #value <= f.max, `EventCodec: {f.field} is {#value} bytes, outside {min}..{f.max}`)
		assert(utf8.len(value) ~= nil, `EventCodec: {f.field} is not valid UTF-8`)
		table.insert(out, value)
	end
	return out
end

function EventCodec.encode(serverTime: number, events: { Event }): buffer
	assert(
		type(serverTime) == "number" and serverTime == serverTime and serverTime >= 0 and serverTime < math.huge,
		"EventCodec.encode: serverTime must be finite and >= 0"
	)
	assert(#events <= 65535, "EventCodec.encode: too many events")
	local size = EventCodec.HEADER_BYTES
	local strings = table.create(#events) :: { { string } }
	for index, e in events do
		local tag = TAGS[e.type]
		assert(tag ~= nil, `EventCodec: unknown event type '{tostring(e.type)}'`)
		strings[index] = stringsOf(tag, e)
		size += SIZES[tag]
		for _, s in strings[index] do
			size += #s
		end
	end
	local buf = buffer.create(size)
	buffer.writef32(buf, 0, serverTime)
	buffer.writeu16(buf, 4, #events)
	local o = EventCodec.HEADER_BYTES
	for index, e in events do
		local tag = TAGS[e.type]
		buffer.writeu8(buf, o, tag)
		if HAS_ID[tag] or (tag == 10 and e.id ~= nil) then
			checkId(e.id)
			buffer.writeu16(buf, o + 1, e.id)
		end
		if tag == 1 or tag == 5 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.KINDS, e.kind, "kind"))
			buffer.writeu8(buf, o + 4, codeOf(EventCodec.JOBS, e.job, "job"))
			buffer.writeu8(buf, o + 5, codeOf(EventCodec.KINGDOMS, e.kingdom, "kingdom"))
			local look = e.look
			for i, field in LOOK_FIELDS do
				local v = if look then look[field] else 0
				if look then
					assert(
						type(v) == "number" and v >= 1 and v <= 255 and v % 1 == 0,
						`EventCodec: look.{field} {tostring(v)} outside 1..255`
					)
				end
				buffer.writeu8(buf, o + 5 + i, v)
			end
		elseif tag == 3 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.JOBS, e.job, "job"))
		elseif tag == 4 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.CUES, e.cue, "cue"))
			local arg = 0
			if e.resource ~= nil then
				arg = codeOf(SnapshotCodec.CARRYING, e.resource, "resource")
			end
			buffer.writeu8(buf, o + 4, arg)
		elseif tag == 7 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.ICONS, e.icon, "icon"))
		elseif tag == 8 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.TONES, e.tone, "tone"))
		elseif tag == 9 then
			assert(type(e.on) == "boolean", `EventCodec: strike on must be a boolean, got {typeof(e.on)}`)
			buffer.writeu8(buf, o + 1, if e.on then 1 else 0)
		elseif tag == 10 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.KINGDOM_CUES, e.cue, "cue"))
		end
		if tag == 5 then
			-- reuse the snapshot record layout for the state part (id already written)
			local record = SnapshotCodec.encode({ e :: any }, 0, 0)
			buffer.copy(buf, o + SPAWN_BYTES, record, SnapshotCodec.HEADER_BYTES + 2, SnapshotCodec.RECORD_BYTES - 2)
		end
		local spec = STRINGS[tag]
		if spec then
			local p = o + spec.head
			for _, s in strings[index] do
				buffer.writeu16(buf, p, #s)
				buffer.writestring(buf, p + 2, s)
				p += 2 + #s
			end
			o = p
		else
			o += SIZES[tag]
		end
	end
	return buf
end

function EventCodec.decode(buf: any): (Batch?, string?)
	if type(buf) ~= "buffer" then
		return nil, "not a buffer"
	end
	local len = buffer.len(buf)
	if len < EventCodec.HEADER_BYTES then
		return nil, "too short"
	end
	local n = buffer.readu16(buf, 4)
	local events = table.create(n)
	local o = EventCodec.HEADER_BYTES
	for i = 1, n do
		if o >= len then
			return nil, `record {i}: missing`
		end
		local tag = buffer.readu8(buf, o)
		local size = SIZES[tag]
		if size == nil then
			return nil, `record {i}: unknown tag {tag}`
		end
		if o + size > len then
			return nil, `record {i}: truncated`
		end
		local e: Event = { type = TYPE_OF[tag] }
		if HAS_ID[tag] then
			e.id = buffer.readu16(buf, o + 1)
			if e.id == 0 then
				return nil, `record {i}: id 0`
			end
		end
		if tag == 1 or tag == 5 then
			e.kind = EventCodec.KINDS[buffer.readu8(buf, o + 3)]
			e.job = EventCodec.JOBS[buffer.readu8(buf, o + 4)]
			e.kingdom = EventCodec.KINGDOMS[buffer.readu8(buf, o + 5)]
			if e.kind == nil or e.job == nil or e.kingdom == nil then
				return nil, `record {i}: bad code`
			end
			local look = {}
			local set = 0
			for f, field in LOOK_FIELDS do
				look[field] = buffer.readu8(buf, o + 5 + f)
				if look[field] > 0 then
					set += 1
				end
			end
			if set == #LOOK_FIELDS then
				e.look = look
			elseif set > 0 then
				return nil, `record {i}: partial look`
			end
		elseif tag == 3 then
			e.job = EventCodec.JOBS[buffer.readu8(buf, o + 3)]
			if e.job == nil then
				return nil, `record {i}: bad job`
			end
		elseif tag == 4 then
			e.cue = EventCodec.CUES[buffer.readu8(buf, o + 3)]
			local arg = buffer.readu8(buf, o + 4)
			if e.cue == nil or arg > #SnapshotCodec.CARRYING then
				return nil, `record {i}: bad cue`
			end
			e.resource = if arg > 0 then SnapshotCodec.CARRYING[arg] else nil
		elseif tag == 7 then
			e.icon = EventCodec.ICONS[buffer.readu8(buf, o + 3)]
			if e.icon == nil then
				return nil, `record {i}: bad icon`
			end
		elseif tag == 8 then
			e.tone = EventCodec.TONES[buffer.readu8(buf, o + 3)]
			if e.tone == nil then
				return nil, `record {i}: bad tone`
			end
		elseif tag == 9 then
			local on = buffer.readu8(buf, o + 1)
			if on > 1 then
				return nil, `record {i}: bad strike flag`
			end
			e.on = on == 1
		elseif tag == 10 then
			local id = buffer.readu16(buf, o + 1)
			e.id = if id > 0 then id else nil
			e.cue = EventCodec.KINGDOM_CUES[buffer.readu8(buf, o + 3)]
			if e.cue == nil then
				return nil, `record {i}: bad cue`
			end
		end
		local spec = STRINGS[tag]
		if spec then
			-- the fixed size already covered every length prefix as if the strings were empty
			local p = o + spec.head
			for _, f in spec.fields do
				if p + 2 > len then
					return nil, `record {i}: truncated`
				end
				local bytes = buffer.readu16(buf, p)
				if bytes < f.min or bytes > f.max then
					return nil, `record {i}: {f.field} of {bytes} bytes`
				end
				if p + 2 + bytes > len then
					return nil, `record {i}: truncated {f.field}`
				end
				local value = buffer.readstring(buf, p + 2, bytes)
				if utf8.len(value) == nil then
					return nil, `record {i}: {f.field} is not UTF-8`
				end
				if bytes > 0 or not f.optional then
					e[f.field] = value
				end
				p += 2 + bytes
			end
			size = p - o
		end
		if tag == 5 then
			-- rebuild a one-record snapshot to decode the state part with the same rules
			local record = buffer.create(SnapshotCodec.HEADER_BYTES + SnapshotCodec.RECORD_BYTES)
			buffer.writeu8(record, 6, 1) -- chunk 0 of 1
			buffer.writeu8(record, 7, 1)
			buffer.writeu16(record, SnapshotCodec.HEADER_BYTES, e.id)
			buffer.copy(record, SnapshotCodec.HEADER_BYTES + 2, buf, o + SPAWN_BYTES, SnapshotCodec.RECORD_BYTES - 2)
			local frame, reason = SnapshotCodec.decode(record)
			if frame == nil then
				return nil, `record {i}: {reason}`
			end
			local state = frame.records[1]
			e.x, e.y, e.z, e.yaw, e.action, e.carrying =
				state.x, state.y, state.z, state.yaw, state.action, state.carrying
		end
		table.insert(events, e)
		o += size
	end
	if o ~= len then
		return nil, "trailing bytes"
	end
	return { serverTime = buffer.readf32(buf, 0), events = events }, nil
end

return table.freeze(EventCodec)
