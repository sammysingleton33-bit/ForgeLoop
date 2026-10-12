--[[
	Sim/EventCodec (CONTRACTS G4 reliable traffic): Sim.Events batches and the Sim.GetEntities buffer.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")

local SAMPLE = {
	{
		type = "spawn",
		id = 1,
		kind = "citizen",
		job = "farmer",
		kingdom = "crimson",
		look = { skin = 3, hair = 6, hairColor = 8, outfit = 1 },
	},
	{ type = "spawn", id = 65535, kind = "soldier", job = "soldier", kingdom = "gold" },
	{ type = "job", id = 1, job = "hauler" },
	{ type = "cue", id = 1, cue = "deposit", resource = "wood" },
	{ type = "cue", id = 2, cue = "die" },
	{ type = "despawn", id = 2 },
	{
		type = "full",
		id = 7,
		kind = "citizen",
		job = "miner",
		kingdom = "azure",
		look = { skin = 1, hair = 2, hairColor = 255, outfit = 4 },
		x = -330.3,
		y = 3,
		z = 412.06,
		yaw = 1.2,
		action = "carry",
		carrying = "stone",
	},
	{ type = "reset" },
}

describe("Sim/EventCodec", function()
	it("round-trips every record type at its documented size", function()
		local buf = EventCodec.encode(12.5, SAMPLE)
		expect(buffer.len(buf)).toBe(6 + 10 + 10 + 4 + 5 + 5 + 3 + 18 + 1)
		local batch = assert(EventCodec.decode(buf))
		expect(batch.serverTime).toBeNear(12.5, 1e-6)
		expect(#batch.events).toBe(#SAMPLE)
		for i = 1, 6 do
			expect(batch.events[i]).toEqual(SAMPLE[i])
		end
		local full = batch.events[7]
		expect(full.type).toBe("full")
		expect({ full.id, full.kind, full.job, full.kingdom }).toEqual({ 7, "citizen", "miner", "azure" })
		expect(full.look).toEqual(SAMPLE[7].look)
		expect(batch.events[2].look).toBeNil() -- no look (a soldier): Kit's default
		expect(full.x).toBe(SnapshotCodec.quantize(-330.3))
		expect(full.z).toBe(SnapshotCodec.quantize(412.06))
		expect(full.y).toBe(3)
		expect(full.yaw).toBeNear(1.2, math.pi / 256 + 1e-9)
		expect(full.action).toBe("carry")
		expect(full.carrying).toBe("stone")
		expect(batch.events[8]).toEqual({ type = "reset" })
	end)

	it("covers every kind, job, kingdom and cue", function()
		local events = {}
		local id = 0
		for _, kind in EventCodec.KINDS do
			for _, job in EventCodec.JOBS do
				for _, kingdom in EventCodec.KINGDOMS do
					id += 1
					table.insert(events, { type = "spawn", id = id, kind = kind, job = job, kingdom = kingdom })
				end
			end
		end
		for _, cue in EventCodec.CUES do
			table.insert(events, { type = "cue", id = 1, cue = cue })
		end
		local batch = assert(EventCodec.decode(EventCodec.encode(0, events)))
		expect(batch.events).toEqual(events)
		expect(EventCodec.CUES).toEqual({ "deposit", "hit", "die", "celebrate" }) -- G4 cue names
	end)

	it("an initial-state buffer for 300 entities stays small", function()
		local events = {}
		for i = 1, 300 do
			table.insert(events, {
				type = "full",
				id = i,
				kind = "citizen",
				job = "hauler",
				kingdom = "emerald",
				x = i,
				y = 0,
				z = -i,
				yaw = 0,
				action = "walk",
			})
		end
		local buf = EventCodec.encode(0, events)
		expect(buffer.len(buf)).toBe(6 + 300 * 18)
		expect(#assert(EventCodec.decode(buf)).events).toBe(300)
	end)

	it("refuses to encode garbage", function()
		local function bad(event)
			return function()
				EventCodec.encode(0, { event })
			end
		end
		expect(bad({ type = "spawn", id = 1, kind = "dragon", job = "farmer", kingdom = "gold" })).toThrow(
			"unknown kind"
		)
		expect(bad({ type = "spawn", id = 1, kind = "citizen", job = "baker", kingdom = "gold" })).toThrow(
			"unknown job"
		)
		expect(bad({ type = "spawn", id = 1, kind = "citizen", job = "farmer", kingdom = "violet" })).toThrow(
			"unknown kingdom"
		)
		expect(bad({ type = "cue", id = 1, cue = "chop" })).toThrow("unknown cue") -- no per-swing cues
		expect(bad({ type = "cue", id = 1, cue = "deposit", resource = "iron" })).toThrow("unknown resource")
		expect(bad({ type = "despawn", id = 0 })).toThrow("outside 1..65535")
		expect(bad({ type = "despawn", id = 70000 })).toThrow("outside 1..65535")
		expect(bad({ type = "teleport", id = 1 })).toThrow("unknown event type")
		local function withLook(look)
			return bad({ type = "spawn", id = 1, kind = "citizen", job = "farmer", kingdom = "gold", look = look })
		end
		expect(withLook({ skin = 0, hair = 1, hairColor = 1, outfit = 1 })).toThrow("look.skin")
		expect(withLook({ skin = 1, hair = 256, hairColor = 1, outfit = 1 })).toThrow("look.hair")
		expect(withLook({ skin = 1, hair = 1, hairColor = 1.5, outfit = 1 })).toThrow("look.hairColor")
		expect(withLook({ skin = 1, hair = 1, hairColor = 1 })).toThrow("look.outfit")
		expect(function()
			EventCodec.encode(0 / 0, {})
		end).toThrow("serverTime")
	end)

	it("decodes malformed input to nil with a reason, never an error", function()
		local good = EventCodec.encode(1, SAMPLE)
		local function mutated(fn)
			local out = buffer.create(buffer.len(good))
			buffer.copy(out, 0, good)
			fn(out)
			return out
		end
		local truncated = buffer.create(buffer.len(good) - 2)
		buffer.copy(truncated, 0, good, 0, buffer.len(truncated))
		local trailing = buffer.create(buffer.len(good) + 1)
		buffer.copy(trailing, 0, good)
		local cases = {
			42,
			buffer.create(2),
			truncated,
			trailing,
			mutated(function(b)
				buffer.writeu8(b, 6, 99) -- unknown tag
			end),
			mutated(function(b)
				buffer.writeu8(b, 6 + 3, 9) -- kind code out of range
			end),
			mutated(function(b)
				buffer.writeu16(b, 6 + 1, 0) -- id 0
			end),
			mutated(function(b)
				buffer.writeu16(b, 4, 200) -- more records than bytes
			end),
			mutated(function(b)
				buffer.writeu8(b, 6 + 7, 0) -- a look with one field missing
			end),
		}
		for _, case in cases do
			local ok, batch, reason = pcall(EventCodec.decode, case)
			expect(ok).toBe(true)
			expect(batch).toBeNil()
			expect(type(reason)).toBe("string")
		end
	end)
end)
