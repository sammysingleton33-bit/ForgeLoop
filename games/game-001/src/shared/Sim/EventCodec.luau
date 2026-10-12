--!strict
--[[
	Sim/EventCodec — the reliable entity traffic of CONTRACTS G4: `Sim.Events` (one buffer per tick,
	batched) and `Sim.GetEntities` (one buffer with every live entity). Fields that rarely change
	(kind, job, kingdom) travel here, never in the per-tick snapshot (Sim/SnapshotCodec).

	Wire layout (little-endian `buffer`):
		header (6 B)   serverTime f32 (seconds since match start) · n u16 (records)
		records, each starting with a tag u8:
			1 spawn    id u16 · kind u8 · job u8 · kingdom u8                                (6 B)
			2 despawn  id u16                                                               (3 B)
			3 job      id u16 · job u8                                                      (4 B)
			4 cue      id u16 · cue u8 · arg u8   (deposit: arg = resource code, else 0)     (5 B)
			5 full     spawn fields + SnapshotCodec record fields (x/y/z i16 at 1/8 stud,
			           yaw u8, state u8)                                                   (14 B)
			6 reset    (no fields: a new match world; drop every entity, ids start over)      (1 B)
	Codes (index in the list, from 1): KINDS = G2 EntityKind, JOBS = G2 JobId, KINGDOMS = G2 KingdomId,
	CUES = { deposit, hit, die, celebrate } (G4: looping work animations derive from action + job,
	so there are no per-swing cues), resources = SnapshotCodec.CARRYING.

	API
		EventCodec.encode(serverTime, events): buffer
		EventCodec.decode(buf): (Batch?, string?)    -- nil + reason for a malformed buffer; never errors
		EventCodec.CUES, KINDS, JOBS, KINGDOMS
	Event (input and decoded output), by type:
		{ type = "spawn", id, kind, job, kingdom }       { type = "despawn", id }
		{ type = "job", id, job }                        { type = "cue", id, cue, resource? }
		{ type = "full", id, kind, job, kingdom, x, y, z, yaw, action, carrying? }
		{ type = "reset" }
	encode errors on unknown codes, ids outside 1..65535 and coordinates SnapshotCodec rejects.
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

local TAGS = { spawn = 1, despawn = 2, job = 3, cue = 4, full = 5, reset = 6 }
local SIZES = { [1] = 6, [2] = 3, [3] = 4, [4] = 5, [5] = 14, [6] = 1 }
local TYPE_OF = { "spawn", "despawn", "job", "cue", "full", "reset" }

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

function EventCodec.encode(serverTime: number, events: { Event }): buffer
	assert(
		type(serverTime) == "number" and serverTime == serverTime and serverTime >= 0 and serverTime < math.huge,
		"EventCodec.encode: serverTime must be finite and >= 0"
	)
	assert(#events <= 65535, "EventCodec.encode: too many events")
	local size = EventCodec.HEADER_BYTES
	for _, e in events do
		local tag = TAGS[e.type]
		assert(tag ~= nil, `EventCodec: unknown event type '{tostring(e.type)}'`)
		size += SIZES[tag]
	end
	local buf = buffer.create(size)
	buffer.writef32(buf, 0, serverTime)
	buffer.writeu16(buf, 4, #events)
	local o = EventCodec.HEADER_BYTES
	for _, e in events do
		local tag = TAGS[e.type]
		buffer.writeu8(buf, o, tag)
		if tag ~= 6 then
			checkId(e.id)
			buffer.writeu16(buf, o + 1, e.id)
		end
		if tag == 1 or tag == 5 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.KINDS, e.kind, "kind"))
			buffer.writeu8(buf, o + 4, codeOf(EventCodec.JOBS, e.job, "job"))
			buffer.writeu8(buf, o + 5, codeOf(EventCodec.KINGDOMS, e.kingdom, "kingdom"))
		elseif tag == 3 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.JOBS, e.job, "job"))
		elseif tag == 4 then
			buffer.writeu8(buf, o + 3, codeOf(EventCodec.CUES, e.cue, "cue"))
			local arg = 0
			if e.resource ~= nil then
				arg = codeOf(SnapshotCodec.CARRYING, e.resource, "resource")
			end
			buffer.writeu8(buf, o + 4, arg)
		end
		if tag == 5 then
			-- reuse the snapshot record layout for the state part (id already written)
			local record = SnapshotCodec.encode({ e :: any }, 0, 0)
			buffer.copy(buf, o + 6, record, SnapshotCodec.HEADER_BYTES + 2, SnapshotCodec.RECORD_BYTES - 2)
		end
		o += SIZES[tag]
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
		if tag ~= 6 then
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
		end
		if tag == 5 then
			-- rebuild a one-record snapshot to decode the state part with the same rules
			local record = buffer.create(SnapshotCodec.HEADER_BYTES + SnapshotCodec.RECORD_BYTES)
			buffer.writeu8(record, 6, 1) -- chunk 0 of 1
			buffer.writeu8(record, 7, 1)
			buffer.writeu16(record, SnapshotCodec.HEADER_BYTES, e.id)
			buffer.copy(record, SnapshotCodec.HEADER_BYTES + 2, buf, o + 6, SnapshotCodec.RECORD_BYTES - 2)
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
