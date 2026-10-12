local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Codec = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/SnapshotCodec")
local Interest = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Interest")

local function entity(id, overrides)
	local e = {
		id = id,
		x = 10.5,
		y = 3,
		z = -42.25,
		yaw = math.pi / 2,
		action = "carry",
		job = "woodcutter",
		kingdom = "azure",
		carrying = "wood",
		hpPct = 87,
	}
	for k, v in overrides or {} do
		e[k] = v
	end
	return e
end

describe("Kingdom/SnapshotCodec", function()
	it("round-trips every field at the documented sizes", function()
		local none = entity(4294967295, { action = "dead" })
		none.kingdom = nil -- a neutral entity carrying nothing
		none.carrying = nil
		local buf = Codec.encode({ entity(7), none }, 12, 1700000123.625)
		expect(buffer.len(buf)).toBe(15 + 2 * 22)
		local frame = Codec.decode(buf)
		expect(frame.version).toBe(1)
		expect(frame.seq).toBe(12)
		expect(frame.serverTime).toBe(1700000123.625) -- f64 keeps sub-second server time
		local a, b = frame.entities[1], frame.entities[2]
		expect(a.id).toBe(7)
		expect(a.x).toBe(10.5)
		expect(a.z).toBe(-42.25)
		expect(a.yaw).toBeNear(math.pi / 2, 0.025)
		expect(a.action).toBe("carry")
		expect(a.job).toBe("woodcutter")
		expect(a.kingdom).toBe("azure")
		expect(a.carrying).toBe("wood")
		expect(a.hpPct).toBe(87)
		expect(b.id).toBe(4294967295)
		expect(b.kingdom).toBeNil()
		expect(b.carrying).toBeNil()
		expect(b.action).toBe("dead")
	end)

	it("wraps yaw into one turn and clamps hp to 0..100", function()
		local frame = Codec.decode(Codec.encode({
			entity(1, { yaw = -math.pi / 2, hpPct = 150 }),
			entity(2, { yaw = 5 * math.pi, hpPct = -3 }),
		}, 1, 0))
		expect(frame.entities[1].yaw).toBeNear(3 * math.pi / 2, 0.025)
		expect(frame.entities[1].hpPct).toBe(100)
		expect(frame.entities[2].yaw).toBeNear(math.pi, 0.025)
		expect(frame.entities[2].hpPct).toBe(0)
	end)

	it("covers every contract enum value", function()
		local list = {}
		for i, action in Codec.ACTIONS do
			local job = Codec.JOBS[(i - 1) % #Codec.JOBS + 1]
			local kingdom = Codec.KINGDOMS[(i - 1) % #Codec.KINGDOMS + 1]
			local carrying = Codec.CARRYING[(i - 1) % #Codec.CARRYING + 1]
			table.insert(list, entity(i, { action = action, job = job, kingdom = kingdom, carrying = carrying }))
		end
		local frame = Codec.decode(Codec.encode(list, 1, 0))
		for i, e in frame.entities do
			expect(e.action).toBe(list[i].action)
			expect(e.job).toBe(list[i].job)
			expect(e.kingdom).toBe(list[i].kingdom)
			expect(e.carrying).toBe(list[i].carrying)
		end
	end)

	it("splits frames into chunks that fit an unreliable remote", function()
		local list = {}
		for i = 1, 100 do
			table.insert(list, entity(i))
		end
		local chunks = Codec.encodeChunks(list, 5, 10)
		expect(#chunks).toBe(3) -- 40 + 40 + 20
		local ids = {}
		for _, chunk in chunks do
			expect(buffer.len(chunk) <= 900).toBe(true)
			local frame = Codec.decode(chunk)
			expect(frame.seq).toBe(5)
			for _, e in frame.entities do
				table.insert(ids, e.id)
			end
		end
		expect(#ids).toBe(100)
		expect(ids[1]).toBe(1)
		expect(ids[100]).toBe(100)
		expect(#Codec.encodeChunks({}, 1, 0)).toBe(1) -- an empty frame still says "nothing here"
		expect(function()
			Codec.encodeChunks(list, 1, 0, 30)
		end).toThrow("maxBytes too small")
	end)

	it("refuses to encode garbage", function()
		expect(function()
			Codec.encode({ entity(1, { action = "dance" }) }, 1, 0)
		end).toThrow("unknown action")
		expect(function()
			Codec.encode({ entity(1, { job = "wizard" }) }, 1, 0)
		end).toThrow("unknown job")
		expect(function()
			Codec.encode({ entity(1, { kingdom = "k1" }) }, 1, 0)
		end).toThrow("unknown kingdom")
		expect(function()
			Codec.encode({ entity(1, { x = 0 / 0 }) }, 1, 0)
		end).toThrow("non-finite")
		expect(function()
			Codec.encode({ entity(-1) }, 1, 0)
		end).toThrow("u32")
		expect(function()
			Codec.encode({ entity(1.5) }, 1, 0)
		end).toThrow("u32")
		expect(function()
			Codec.encode({}, 1, math.huge)
		end).toThrow("serverTime")
	end)

	it("decodes malformed input to nil with a reason, never an error", function()
		expect(select(2, Codec.decode("hello"))).toBe("not a buffer")
		expect(select(2, Codec.decode(buffer.create(3)))).toBe("too short")
		local good = Codec.encode({ entity(1) }, 1, 0)
		local wrongVersion = buffer.create(buffer.len(good))
		buffer.copy(wrongVersion, 0, good)
		buffer.writeu8(wrongVersion, 0, 9)
		expect(select(2, Codec.decode(wrongVersion))).toContain("version")
		local truncated = buffer.create(buffer.len(good) - 1)
		buffer.copy(truncated, 0, good, 0, buffer.len(good) - 1)
		expect(select(2, Codec.decode(truncated))).toContain("length")
		local badEnum = buffer.create(buffer.len(good))
		buffer.copy(badEnum, 0, good)
		buffer.writeu8(badEnum, 15 + 17, 200)
		expect(Codec.decode(badEnum)).toBeNil()
		local badKingdom = buffer.create(buffer.len(good))
		buffer.copy(badKingdom, 0, good)
		buffer.writeu8(badKingdom, 15 + 19, 9)
		expect(Codec.decode(badKingdom)).toBeNil()
	end)
end)

describe("Kingdom/Interest", function()
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
		expect(bps).toBe((90 * 22 + 3 * 15) * 10)
		expect(bps < 50000).toBe(true)
	end)
end)
