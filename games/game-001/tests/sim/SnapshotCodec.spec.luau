--[[
	Sim/SnapshotCodec v2 (CONTRACTS G4, D-025) and Sim/Interest.
	Every packet must stay ≤ 900 B raw (the engine drops unreliable payloads over 1,000 B), at 50 and
	at 300 entities; quantisation stays within half a step; seq compares across the u16 wrap.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Interest = require("@game/ReplicatedStorage/Game/Sim/Interest")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")

local C = SnapshotCodec

local function records(count: number, seed: number?)
	local rng = Random.new(seed or 1)
	local out = {}
	for i = 1, count do
		table.insert(out, {
			id = i,
			x = rng:NextNumber(-4000, 4000),
			y = rng:NextNumber(-20, 120),
			z = rng:NextNumber(-4000, 4000),
			yaw = rng:NextNumber(-10, 10),
			action = C.ACTIONS[rng:NextInteger(1, #C.ACTIONS)],
			carrying = if i % 3 == 0 then C.CARRYING[rng:NextInteger(1, #C.CARRYING)] else nil,
		})
	end
	return out
end

local function yawError(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	return math.min(d, 2 * math.pi - d)
end

describe("Sim/SnapshotCodec v2", function()
	it("round-trips every field at 8 + 10 B per record, within half a quantisation step", function()
		local input = records(80, 3)
		local buf = C.encode(input, 4242, 2700.125)
		expect(buffer.len(buf)).toBe(8 + 80 * 10)
		local frame = assert(C.decode(buf))
		expect(frame.seq).toBe(4242)
		expect(frame.serverTime).toBeNear(2700.125, 1e-3) -- f32: well under a millisecond at 45 minutes
		expect(frame.chunkIndex).toBe(0)
		expect(frame.chunkCount).toBe(1)
		expect(#frame.records).toBe(80)
		for i, r in frame.records do
			local original = input[i]
			expect(r.id).toBe(original.id)
			for _, axis in { "x", "y", "z" } do
				expect(math.abs(r[axis] - original[axis]) <= 1 / 16 + 1e-9).toBe(true)
				expect(r[axis]).toBe(C.quantize(original[axis]))
			end
			expect(yawError(r.yaw, original.yaw) <= math.pi / 256 + 1e-9).toBe(true)
			expect(r.action).toBe(original.action)
			expect(r.carrying).toBe(original.carrying)
		end
	end)

	it("encodes every action and carried resource in the 3-bit fields", function()
		local input = {}
		for i, action in C.ACTIONS do
			table.insert(input, { id = i, x = 0, y = 0, z = 0, yaw = 0, action = action })
		end
		for i, resource in C.CARRYING do
			table.insert(input, { id = 100 + i, x = 0, y = 0, z = 0, yaw = 0, action = "carry", carrying = resource })
		end
		local frame = assert(C.decode(C.encode(input, 1, 0)))
		for i, r in frame.records do
			expect(r.action).toBe(input[i].action)
			expect(r.carrying).toBe(input[i].carrying)
		end
		expect(#C.ACTIONS).toBe(8)
		expect(#C.CARRYING <= 7).toBe(true)
	end)

	it("keeps every packet at or under 900 B at 50 and at 300 entities, and loses nobody", function()
		for _, count in { 50, 300 } do
			local input = records(count, count)
			local chunks = C.encodeChunks(input, 7, 12.5)
			expect(#chunks).toBe(math.ceil(count / 80))
			local seen = {}
			for index, buf in chunks do
				expect(buffer.len(buf) <= 900).toBe(true)
				local frame = assert(C.decode(buf))
				expect(frame.seq).toBe(7)
				expect(frame.chunkIndex).toBe(index - 1)
				expect(frame.chunkCount).toBe(#chunks)
				for _, r in frame.records do
					expect(seen[r.id]).toBeNil()
					seen[r.id] = true
				end
			end
			for i = 1, count do
				expect(seen[i]).toBe(true)
			end
		end
		expect(buffer.len(C.encodeChunks({}, 1, 0)[1])).toBe(8) -- an empty tick still says "nothing"
	end)

	it("compares seq across the u16 wrap", function()
		expect(C.newer(1, 65535)).toBe(true)
		expect(C.newer(65535, 1)).toBe(false)
		expect(C.newer(5, 5)).toBe(false)
		expect(C.newer(100, 99)).toBe(true)
		expect(C.newer(99, 100)).toBe(false)
		local frame = assert(C.decode(C.encode({}, 65536 + 3, 0)))
		expect(frame.seq).toBe(3)
	end)

	it("refuses to encode garbage", function()
		local function one(overrides)
			local r = { id = 1, x = 0, y = 0, z = 0, yaw = 0, action = "idle" }
			for k, v in overrides do
				r[k] = v
			end
			return function()
				C.encode({ r }, 1, 0)
			end
		end
		expect(one({ id = 0 })).toThrow("outside 1..65535")
		expect(one({ id = 65536 })).toThrow("outside 1..65535")
		expect(one({ id = 1.5 })).toThrow("outside 1..65535")
		expect(one({ x = 4096 })).toThrow("outside")
		expect(one({ z = -4096 })).toThrow("outside")
		expect(one({ y = 0 / 0 })).toThrow("finite")
		expect(one({ yaw = math.huge })).toThrow("finite")
		expect(one({ action = "dance" })).toThrow("unknown action")
		expect(one({ carrying = "iron" })).toThrow("unknown resource")
		expect(function()
			C.encode(records(81), 1, 0)
		end).toThrow("81 records")
		expect(function()
			C.encodeChunks(records(80 * 16 + 1), 1, 0)
		end).toThrow("chunks")
		expect(function()
			C.encode({}, 1, -1)
		end).toThrow("serverTime")
	end)

	it("decodes malformed input to nil with a reason, never an error", function()
		local good = C.encode(records(2), 1, 0)
		local function copyOf(source, len)
			local out = buffer.create(len or buffer.len(source))
			buffer.copy(out, 0, source, 0, math.min(buffer.len(out), buffer.len(source)))
			return out
		end
		local cases = { "text", buffer.create(3), copyOf(good, buffer.len(good) - 1) }
		local badState = copyOf(good)
		buffer.writeu8(badState, 8 + 9, 0xFF)
		table.insert(cases, badState)
		local zeroId = copyOf(good)
		buffer.writeu16(zeroId, 8, 0)
		table.insert(cases, zeroId)
		local badChunk = copyOf(good)
		buffer.writeu8(badChunk, 6, 0x22) -- index 2 of 2
		table.insert(cases, badChunk)
		local tooMany = buffer.create(8)
		buffer.writeu8(tooMany, 7, 81)
		table.insert(cases, tooMany)
		for _, case in cases do
			local ok, frame, reason = pcall(C.decode, case)
			expect(ok).toBe(true)
			expect(frame).toBeNil()
			expect(type(reason)).toBe("string")
		end
		expect((C.decode(good))).toBeTruthy()
	end)
end)

describe("Sim/Interest", function()
	local function grid()
		local list = {}
		for i = 1, 20 do
			table.insert(list, { id = i, x = i * 20, z = 0 })
		end
		return list
	end

	it("sends near entities every tick and spreads far ones over farEvery ticks", function()
		local list = grid()
		local seen = {}
		for tick = 0, 4 do
			for _, e in Interest.select(list, { x = 0, z = 0 }, tick, { nearRadius = 100, farEvery = 5 }) do
				seen[e.id] = (seen[e.id] or 0) + 1
			end
		end
		for id = 1, 5 do
			expect(seen[id]).toBe(5) -- within 100 studs: every tick
		end
		for id = 6, 20 do
			expect(seen[id]).toBe(1) -- far: exactly once per 5 ticks
		end
	end)

	it("treats everything as far without a viewer, and always includes listed ids", function()
		local list = grid()
		local selected = Interest.select(list, nil, 0, { farEvery = 5, always = { [3] = true } })
		local ids = {}
		for _, e in selected do
			ids[e.id] = true
		end
		expect(ids[3]).toBe(true)
		expect(ids[5]).toBe(true) -- (5 + 0) % 5 == 0
		expect(ids[4]).toBeNil()
	end)

	it("estimates bandwidth for the budget log", function()
		-- 40 near + 250 far at 10 Hz, far every 5 ticks: 90 entities/tick
		local bps = Interest.bytesPerSecond(40, 250, 10, { farEvery = 5 })
		expect(bps).toBe((90 * 10 + 2 * 8) * 10) -- 90 records in 2 buffers of ≤ 80
		expect(bps < 50000).toBe(true)
	end)
end)
