--!strict
--[[
	Sim/SnapshotCodec — the binary entity snapshot of CONTRACTS G4, wire format v2 (D-025).

	One UnreliableRemoteEvent payload (`Sim.Snapshot`) is one buffer, little-endian:
		header (8 B)   serverTime f32 · seq u16 · chunk u8 · n u8
		               serverTime: seconds since match start (Match.State carries startedAtServerTime)
		               seq: per snapshot tick, compared with wrap-around (SnapshotCodec.newer)
		               chunk: index << 4 | count (both 0..15; count 0 means 16)
		               n: records in this buffer (≤ MAX_RECORDS)
		record (10 B)  id u16 · x i16 · y i16 · z i16 · yaw u8 · state u8
		               x/y/z: studs × 8 (1/8 stud; |coordinate| ≤ 4095.875, the world fits in ±4,000)
		               yaw: radians wrapped to [0, 2π) in 256 steps (1.4°)
		               state: action (bits 0-2) | carrying << 3 (bits 3-5)
	Codes (index in the list, from 0)
		ACTIONS   idle walk work carry fight flee celebrate dead      (0..7, 3 bits)
		CARRYING  0 = nothing, food wood stone gold                    (0..4, 3 bits)
	Kind, job and kingdom never change per tick, so they travel reliably in `Sim.Events` (EventCodec).

	Size: at most MAX_RECORDS = 80 records per buffer (8 + 800 = 808 B). The engine drops unreliable
	payloads over 1,000 B, so encode asserts the raw size ≤ MAX_BYTES (900) and never counts on
	compression. encodeChunks splits a tick into ≤ 16 self-contained buffers (≤ 1,280 entities).

	API
		SnapshotCodec.encode(records, seq, serverTime, chunkIndex?, chunkCount?): buffer
		SnapshotCodec.encodeChunks(records, seq, serverTime): { buffer }
		SnapshotCodec.decode(buf): (Frame?, string?)        -- nil + reason for a malformed buffer
		SnapshotCodec.newer(a, b): boolean                  -- seq a is newer than seq b (u16 wrap)
		SnapshotCodec.quantize(coordinate): number          -- what a client decodes for a coordinate
		SnapshotCodec.HEADER_BYTES, RECORD_BYTES, MAX_RECORDS, MAX_BYTES, MAX_COORD, ACTIONS, CARRYING
	Record (input and decoded output):
		{ id: number, x: number, y: number, z: number, yaw: number, action: string, carrying: string? }
	encode errors on programming mistakes (unknown action or resource, id outside 1..65535, a
	coordinate outside ±MAX_COORD, non-finite numbers, too many records): the server must never send
	garbage. decode never errors.
]]

export type Record = {
	id: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
	action: string,
	carrying: string?,
}

export type Frame = {
	serverTime: number,
	seq: number,
	chunkIndex: number,
	chunkCount: number,
	records: { Record },
}

local SnapshotCodec = {}

SnapshotCodec.HEADER_BYTES = 8
SnapshotCodec.RECORD_BYTES = 10
SnapshotCodec.MAX_RECORDS = 80
SnapshotCodec.MAX_BYTES = 900
SnapshotCodec.MAX_CHUNKS = 16
SnapshotCodec.SCALE = 8
SnapshotCodec.MAX_COORD = 32767 / 8 -- 4095.875
SnapshotCodec.ACTIONS = table.freeze({ "idle", "walk", "work", "carry", "fight", "flee", "celebrate", "dead" })
SnapshotCodec.CARRYING = table.freeze({ "food", "wood", "stone", "gold" })

local TWO_PI = math.pi * 2
local ACTION_CODE: { [string]: number } = {}
for i, name in SnapshotCodec.ACTIONS do
	ACTION_CODE[name] = i - 1
end
local CARRY_CODE: { [string]: number } = {}
for i, name in SnapshotCodec.CARRYING do
	CARRY_CODE[name] = i
end

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function coordinate(value: number, field: string, id: number): number
	if not finite(value) then
		error(`SnapshotCodec: entity {id} {field} is not a finite number`, 0)
	end
	if math.abs(value) > SnapshotCodec.MAX_COORD then
		error(`SnapshotCodec: entity {id} {field} = {value} is outside ±{SnapshotCodec.MAX_COORD} studs`, 0)
	end
	return math.round(value * SnapshotCodec.SCALE)
end

function SnapshotCodec.quantize(value: number): number
	return math.round(value * SnapshotCodec.SCALE) / SnapshotCodec.SCALE
end

-- seq a is newer than seq b when it is ahead by less than half the u16 range.
function SnapshotCodec.newer(a: number, b: number): boolean
	local diff = (a - b) % 65536
	return diff ~= 0 and diff < 32768
end

function SnapshotCodec.encode(
	records: { Record },
	seq: number,
	serverTime: number,
	chunkIndex: number?,
	chunkCount: number?
): buffer
	local n = #records
	if n > SnapshotCodec.MAX_RECORDS then
		error(`SnapshotCodec.encode: {n} records > {SnapshotCodec.MAX_RECORDS}`, 0)
	end
	assert(finite(serverTime) and serverTime >= 0, "SnapshotCodec.encode: serverTime must be finite and >= 0")
	assert(finite(seq), "SnapshotCodec.encode: seq must be a number")
	local index, count = chunkIndex or 0, chunkCount or 1
	assert(index >= 0 and index < count and count >= 1 and count <= 16, "SnapshotCodec.encode: bad chunk")
	local size = SnapshotCodec.HEADER_BYTES + n * SnapshotCodec.RECORD_BYTES
	if size > SnapshotCodec.MAX_BYTES then
		error(`SnapshotCodec.encode: {size} B > {SnapshotCodec.MAX_BYTES} B`, 0)
	end
	local buf = buffer.create(size)
	buffer.writef32(buf, 0, serverTime)
	buffer.writeu16(buf, 4, seq % 65536)
	buffer.writeu8(buf, 6, bit32.bor(bit32.lshift(index, 4), count % 16))
	buffer.writeu8(buf, 7, n)
	local offset = SnapshotCodec.HEADER_BYTES
	for _, r in records do
		local id = r.id
		if not (type(id) == "number" and id >= 1 and id <= 65535 and id % 1 == 0) then
			error(`SnapshotCodec: id {tostring(id)} outside 1..65535`, 0)
		end
		local action = ACTION_CODE[r.action]
		if action == nil then
			error(`SnapshotCodec: entity {id} has unknown action '{tostring(r.action)}'`, 0)
		end
		local carry = 0
		if r.carrying ~= nil then
			carry = CARRY_CODE[r.carrying] :: number
			if carry == nil then
				error(`SnapshotCodec: entity {id} carries unknown resource '{tostring(r.carrying)}'`, 0)
			end
		end
		if not finite(r.yaw) then
			error(`SnapshotCodec: entity {id} yaw is not a finite number`, 0)
		end
		buffer.writeu16(buf, offset, id)
		buffer.writei16(buf, offset + 2, coordinate(r.x, "x", id))
		buffer.writei16(buf, offset + 4, coordinate(r.y, "y", id))
		buffer.writei16(buf, offset + 6, coordinate(r.z, "z", id))
		buffer.writeu8(buf, offset + 8, math.round((r.yaw % TWO_PI) / TWO_PI * 256) % 256)
		buffer.writeu8(buf, offset + 9, bit32.bor(action, bit32.lshift(carry, 3)))
		offset += SnapshotCodec.RECORD_BYTES
	end
	return buf
end

function SnapshotCodec.encodeChunks(records: { Record }, seq: number, serverTime: number): { buffer }
	local total = #records
	local count = math.max(1, math.ceil(total / SnapshotCodec.MAX_RECORDS))
	if count > SnapshotCodec.MAX_CHUNKS then
		error(`SnapshotCodec.encodeChunks: {total} entities need {count} chunks > 16`, 0)
	end
	local out = {}
	for index = 0, count - 1 do
		local first = index * SnapshotCodec.MAX_RECORDS + 1
		local last = math.min(total, first + SnapshotCodec.MAX_RECORDS - 1)
		table.insert(out, SnapshotCodec.encode(table.move(records, first, last, 1, {}), seq, serverTime, index, count))
	end
	return out
end

function SnapshotCodec.decode(buf: any): (Frame?, string?)
	if type(buf) ~= "buffer" then
		return nil, "not a buffer"
	end
	local len = buffer.len(buf)
	if len < SnapshotCodec.HEADER_BYTES then
		return nil, "too short"
	end
	local n = buffer.readu8(buf, 7)
	if n > SnapshotCodec.MAX_RECORDS or len ~= SnapshotCodec.HEADER_BYTES + n * SnapshotCodec.RECORD_BYTES then
		return nil, "length does not match the record count"
	end
	local chunk = buffer.readu8(buf, 6)
	local count = bit32.band(chunk, 15)
	if count == 0 then
		count = 16
	end
	local index = bit32.rshift(chunk, 4)
	if index >= count then
		return nil, "bad chunk index"
	end
	local records = table.create(n)
	local offset = SnapshotCodec.HEADER_BYTES
	for i = 1, n do
		local state = buffer.readu8(buf, offset + 9)
		local carry = bit32.rshift(state, 3)
		if carry > #SnapshotCodec.CARRYING or bit32.rshift(state, 6) ~= 0 then
			return nil, `record {i}: bad state byte`
		end
		local id = buffer.readu16(buf, offset)
		if id == 0 then
			return nil, `record {i}: id 0`
		end
		records[i] = {
			id = id,
			x = buffer.readi16(buf, offset + 2) / SnapshotCodec.SCALE,
			y = buffer.readi16(buf, offset + 4) / SnapshotCodec.SCALE,
			z = buffer.readi16(buf, offset + 6) / SnapshotCodec.SCALE,
			yaw = buffer.readu8(buf, offset + 8) / 256 * TWO_PI,
			action = SnapshotCodec.ACTIONS[bit32.band(state, 7) + 1],
			carrying = if carry > 0 then SnapshotCodec.CARRYING[carry] else nil,
		}
		offset += SnapshotCodec.RECORD_BYTES
	end
	return {
		serverTime = buffer.readf32(buf, 0),
		seq = buffer.readu16(buf, 4),
		chunkIndex = index,
		chunkCount = count,
		records = records,
	},
		nil
end

return table.freeze(SnapshotCodec)
