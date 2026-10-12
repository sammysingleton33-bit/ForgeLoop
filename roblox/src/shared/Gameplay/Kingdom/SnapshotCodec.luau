--!strict
--[[
	Gameplay/Kingdom/SnapshotCodec — the binary entity snapshot of CONTRACTS G4 (D-023).
	(Moves to games/game-001/src/shared/Sim/SnapshotCodec.luau with FL-0046.)

	Wire layout (little-endian, Luau `buffer`):
		header   version u8 · seq u32 · serverTime f64 · count u16                     (15 bytes)
		entity   id u32 · x f32 · y f32 · z f32 · yaw u8 · action u8 · job u8 · kingdom u8 ·
		         carrying u8 · hpPct u8                                               (22 bytes each)
	Codes (index in the list; 0 = none/unknown where noted):
		ACTIONS   idle walk work carry fight flee celebrate dead                        (1..8)
		JOBS      idle farmer woodcutter miner builder hauler soldier                    (1..7)
		KINGDOMS  0 = none, crimson azure emerald gold                                   (1..4)
		CARRYING  0 = nothing, food wood stone gold                                      (1..4)
	yaw: radians wrapped to [0, 2π) in 256 steps (1.4°). hpPct: 0..100.

	Snapshots travel on an UnreliableRemoteEvent, whose payloads over 1000 bytes are dropped, so
	encodeChunks splits a frame into self-contained buffers of at most `maxBytes` (default 900:
	(900 - 15) / 22 = 40 entities per chunk). Every chunk carries the same seq and serverTime.

	API
		SnapshotCodec.encode(entities, seq, serverTime): buffer
		SnapshotCodec.encodeChunks(entities, seq, serverTime, maxBytes?): { buffer }
		SnapshotCodec.decode(buf): (Frame?, string?)        -- nil + reason for a malformed buffer
		SnapshotCodec.HEADER_BYTES, ENTITY_BYTES, VERSION, ACTIONS, JOBS, KINGDOMS, CARRYING
	Entity (input and decoded output):
		{ id: number, x: number, y: number, z: number, yaw: number, action: string, job: string,
		  kingdom: string?, carrying: string?, hpPct: number }
	encode errors on programming mistakes (unknown action/job/kingdom/resource, id outside u32,
	non-finite position): the server must never send garbage. decode never errors.
]]

export type Entity = {
	id: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
	action: string,
	job: string,
	kingdom: string?,
	carrying: string?,
	hpPct: number,
}

export type Frame = { version: number, seq: number, serverTime: number, entities: { Entity } }

local SnapshotCodec = {}

SnapshotCodec.VERSION = 1
SnapshotCodec.HEADER_BYTES = 15
SnapshotCodec.ENTITY_BYTES = 22
SnapshotCodec.DEFAULT_MAX_BYTES = 900
SnapshotCodec.ACTIONS = table.freeze({ "idle", "walk", "work", "carry", "fight", "flee", "celebrate", "dead" })
SnapshotCodec.JOBS = table.freeze({ "idle", "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" })
SnapshotCodec.KINGDOMS = table.freeze({ "crimson", "azure", "emerald", "gold" })
SnapshotCodec.CARRYING = table.freeze({ "food", "wood", "stone", "gold" })

local TWO_PI = math.pi * 2
local U32_MAX = 4294967295

local function index(list: { string }, value: string?, what: string, allowNone: boolean): number
	if value == nil then
		if allowNone then
			return 0
		end
		error(`SnapshotCodec: {what} is required`, 3)
	end
	local i = table.find(list, value)
	if i == nil then
		error(`SnapshotCodec: unknown {what} '{tostring(value)}'`, 3)
	end
	return i
end

local function finite(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) ~= math.huge
end

local function writeEntity(buf: buffer, offset: number, e: Entity)
	if type(e.id) ~= "number" or e.id < 0 or e.id > U32_MAX or math.floor(e.id) ~= e.id then
		error(`SnapshotCodec: id must be a u32 integer (got {tostring(e.id)})`, 3)
	end
	if not (finite(e.x) and finite(e.y) and finite(e.z) and finite(e.yaw)) then
		error(`SnapshotCodec: entity {e.id} has a non-finite position or yaw`, 3)
	end
	buffer.writeu32(buf, offset, e.id)
	buffer.writef32(buf, offset + 4, e.x)
	buffer.writef32(buf, offset + 8, e.y)
	buffer.writef32(buf, offset + 12, e.z)
	local turn = (e.yaw % TWO_PI) / TWO_PI
	buffer.writeu8(buf, offset + 16, math.floor(turn * 256 + 0.5) % 256)
	buffer.writeu8(buf, offset + 17, index(SnapshotCodec.ACTIONS, e.action, "action", false))
	buffer.writeu8(buf, offset + 18, index(SnapshotCodec.JOBS, e.job, "job", false))
	buffer.writeu8(buf, offset + 19, index(SnapshotCodec.KINGDOMS, e.kingdom, "kingdom", true))
	buffer.writeu8(buf, offset + 20, index(SnapshotCodec.CARRYING, e.carrying, "carrying", true))
	local hp = if finite(e.hpPct) then e.hpPct else 0
	buffer.writeu8(buf, offset + 21, math.clamp(math.floor(hp + 0.5), 0, 100))
end

function SnapshotCodec.encode(entities: { Entity }, seq: number, serverTime: number): buffer
	local count = #entities
	if count > 65535 then
		error("SnapshotCodec: at most 65535 entities per buffer", 2)
	end
	if not finite(serverTime) then
		error("SnapshotCodec: serverTime must be finite", 2)
	end
	local buf = buffer.create(SnapshotCodec.HEADER_BYTES + count * SnapshotCodec.ENTITY_BYTES)
	buffer.writeu8(buf, 0, SnapshotCodec.VERSION)
	buffer.writeu32(buf, 1, seq % (U32_MAX + 1))
	buffer.writef64(buf, 5, serverTime)
	buffer.writeu16(buf, 13, count)
	for i, e in entities do
		writeEntity(buf, SnapshotCodec.HEADER_BYTES + (i - 1) * SnapshotCodec.ENTITY_BYTES, e)
	end
	return buf
end

function SnapshotCodec.encodeChunks(
	entities: { Entity },
	seq: number,
	serverTime: number,
	maxBytes: number?
): { buffer }
	local limit = maxBytes or SnapshotCodec.DEFAULT_MAX_BYTES
	local perChunk = math.floor((limit - SnapshotCodec.HEADER_BYTES) / SnapshotCodec.ENTITY_BYTES)
	if perChunk < 1 then
		error("SnapshotCodec: maxBytes too small for one entity", 2)
	end
	local chunks = {}
	if #entities == 0 then
		table.insert(chunks, SnapshotCodec.encode({}, seq, serverTime))
		return chunks
	end
	for first = 1, #entities, perChunk do
		local slice = table.move(entities, first, math.min(first + perChunk - 1, #entities), 1, {})
		table.insert(chunks, SnapshotCodec.encode(slice, seq, serverTime))
	end
	return chunks
end

local function lookup(list: { string }, code: number): string?
	if code == 0 then
		return nil
	end
	return list[code]
end

function SnapshotCodec.decode(buf: any): (Frame?, string?)
	if type(buf) ~= "buffer" then
		return nil, "not a buffer"
	end
	local len = buffer.len(buf)
	if len < SnapshotCodec.HEADER_BYTES then
		return nil, "too short"
	end
	local version = buffer.readu8(buf, 0)
	if version ~= SnapshotCodec.VERSION then
		return nil, `unsupported version {version}`
	end
	local count = buffer.readu16(buf, 13)
	if len ~= SnapshotCodec.HEADER_BYTES + count * SnapshotCodec.ENTITY_BYTES then
		return nil, "length does not match entity count"
	end
	local entities = table.create(count)
	for i = 1, count do
		local o = SnapshotCodec.HEADER_BYTES + (i - 1) * SnapshotCodec.ENTITY_BYTES
		local action = lookup(SnapshotCodec.ACTIONS, buffer.readu8(buf, o + 17))
		local job = lookup(SnapshotCodec.JOBS, buffer.readu8(buf, o + 18))
		if action == nil or job == nil then
			return nil, `entity {i}: unknown action or job code`
		end
		local kingdomCode = buffer.readu8(buf, o + 19)
		local carryCode = buffer.readu8(buf, o + 20)
		if kingdomCode > #SnapshotCodec.KINGDOMS or carryCode > #SnapshotCodec.CARRYING then
			return nil, `entity {i}: unknown kingdom or carrying code`
		end
		entities[i] = {
			id = buffer.readu32(buf, o),
			x = buffer.readf32(buf, o + 4),
			y = buffer.readf32(buf, o + 8),
			z = buffer.readf32(buf, o + 12),
			yaw = buffer.readu8(buf, o + 16) / 256 * TWO_PI,
			action = action,
			job = job,
			kingdom = lookup(SnapshotCodec.KINGDOMS, kingdomCode),
			carrying = lookup(SnapshotCodec.CARRYING, carryCode),
			hpPct = math.min(100, buffer.readu8(buf, o + 21)),
		}
	end
	return {
		version = version,
		seq = buffer.readu32(buf, 1),
		serverTime = buffer.readf64(buf, 5),
		entities = entities,
	},
		nil
end

return SnapshotCodec
