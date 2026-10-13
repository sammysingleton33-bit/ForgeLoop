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

-- SAMPLE encoded at serverTime 12.5 by the codec before the G13.3 records existed (FL-0079)
local SAMPLE_HEX = "0000484108000101000102010306080101ffff0207040000000003010006040100010204020003000202"
	.. "000507000104020102ff04aef51800e00c311b06"

local function hex(buf: buffer): string
	return (string.gsub(buffer.tostring(buf), ".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

-- G13.3 conversation events, mixed with G4 records so offsets after variable records are exercised
local WHEAT = "Sire, le blé manque — 🌾 ¿qué hacemos?" -- multibyte UTF-8
local CONVERSATION = {
	{ type = "thought", id = 3, scenarioId = "farmer_drought_request", text = WHEAT, icon = "concern" },
	{ type = "spawn", id = 4, kind = "citizen", job = "miner", kingdom = "gold" },
	{ type = "reaction", id = 3, text = "", tone = "sad" }, -- empty text
	{ type = "thought", id = 65535, scenarioId = "x", text = "Idea!", icon = "idea" },
	{ type = "reaction", id = 4, text = "Long live the crown!", tone = "happy" },
	{ type = "strike", occupation = "farmer", on = true, entityIds = { 3, 4, 65535 } },
	{ type = "cue", id = 4, cue = "celebrate" }, -- the G4 entity cue (tag 4)
	{ type = "strike", occupation = "blacksmith", on = false, entityIds = {} }, -- an empty list is still a list
	{ type = "kcue", id = 3, cue = "bow" },
	{ type = "kcue", occupation = "farmer", cue = "strike_placard", entityIds = { 3, 4 } },
	{ type = "kcue", cue = "celebrate" }, -- kingdom-wide, HUD only
	{ type = "kcue", id = 65535, occupation = "miner", cue = "hammer" },
	{ type = "despawn", id = 4 },
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
		expect(hex(buf)).toBe(SAMPLE_HEX) -- the G4 records are byte-identical to before G13.3
	end)

	it("round-trips the G13.3 conversation events at their documented sizes (FL-0079)", function()
		expect(#WHEAT > utf8.len(WHEAT) :: number).toBe(true) -- really multibyte
		local buf = EventCodec.encode(3.25, CONVERSATION)
		local expected = 6
			+ (8 + #"farmer_drought_request" + #WHEAT) -- thought
			+ 10 -- spawn
			+ 6 -- reaction, empty text
			+ (8 + 1 + 5) -- thought
			+ (6 + #"Long live the crown!") -- reaction
			+ (6 + 2 * 3 + #"farmer") -- strike, 3 ids
			+ 5 -- G4 cue
			+ (6 + #"blacksmith") -- strike, no ids
			+ 8 -- kcue, id only
			+ (8 + 2 * 2 + #"farmer") -- kcue, occupation and 2 ids
			+ 8 -- kcue, neither
			+ (8 + #"miner") -- kcue, id and occupation
			+ 3 -- despawn
		expect(buffer.len(buf)).toBe(expected)
		local batch = assert(EventCodec.decode(buf))
		expect(batch.serverTime).toBeNear(3.25, 1e-6)
		expect(batch.events).toEqual(CONVERSATION)
		expect(batch.events[1].text).toBe(WHEAT)
		expect(batch.events[3].text).toBe("")
		expect(batch.events[6].on).toBe(true)
		expect(batch.events[8].on).toBe(false)
		expect(batch.events[11].id).toBeNil()
		expect(batch.events[11].occupation).toBeNil()
		-- after the on flag: the id count and ids (u16 each), then the occupation (u16 byte length, bytes)
		local strike =
			EventCodec.encode(0, { { type = "strike", occupation = "farmer", on = true, entityIds = { 7, 258 } } })
		expect(hex(strike)).toBe(
			"00000000" .. "0100" .. "09" .. "01" .. "0200" .. "0700" .. "0201" .. "0600" .. "6661726d6572"
		)
		local kcue = EventCodec.encode(0, { { type = "kcue", id = 5, cue = "bow", entityIds = { 9 } } })
		expect(hex(kcue)).toBe("00000000" .. "0100" .. "0a" .. "0500" .. "04" .. "0100" .. "0900" .. "0000")
		-- the most ids a list may carry round-trip
		local many = {}
		for i = 1, EventCodec.ID_LIST_MAX do
			many[i] = i
		end
		local wide = { type = "strike", occupation = "farmer", on = false, entityIds = many }
		expect(assert(EventCodec.decode(EventCodec.encode(0, { wide }))).events[1]).toEqual(wide)
	end)

	it("covers every icon, tone and consequence cue, and text up to TEXT_MAX bytes", function()
		local events = {}
		for _, icon in EventCodec.ICONS do
			table.insert(events, { type = "thought", id = 1, scenarioId = "s", text = icon, icon = icon })
		end
		for _, tone in EventCodec.TONES do
			table.insert(events, { type = "reaction", id = 1, text = tone, tone = tone })
		end
		for _, cue in EventCodec.KINGDOM_CUES do
			table.insert(events, { type = "kcue", id = 2, cue = cue })
		end
		local longest = string.rep("é", EventCodec.TEXT_MAX // 2) -- 1024 bytes
		table.insert(events, { type = "reaction", id = 1, text = longest, tone = "neutral" })
		local longId = string.rep("o", EventCodec.ID_MAX)
		table.insert(events, { type = "strike", occupation = longId, on = true, entityIds = { 1 } })
		local batch = assert(EventCodec.decode(EventCodec.encode(0, events)))
		expect(batch.events).toEqual(events)
		expect(EventCodec.ICONS).toEqual({ "request", "concern", "idea" }) -- G13.3
		expect(EventCodec.TONES).toEqual({ "happy", "angry", "sad", "neutral" })
		expect(EventCodec.KINGDOM_CUES).toEqual({
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

	it("refuses to encode garbage conversation events", function()
		local function bad(event)
			return function()
				EventCodec.encode(0, { event })
			end
		end
		local function thought(extra)
			local e = { type = "thought", id = 1, scenarioId = "s", text = "t", icon = "idea" }
			for k, v in extra do
				e[k] = v
			end
			return bad(e)
		end
		expect(thought({ icon = "question" })).toThrow("unknown icon")
		expect(bad({ type = "thought", id = 1, scenarioId = "s", text = "t" })).toThrow("unknown icon")
		expect(thought({ id = 0 })).toThrow("outside 1..65535")
		expect(thought({ id = 65536 })).toThrow("outside 1..65535")
		expect(thought({ text = 42 })).toThrow("text must be a string")
		expect(bad({ type = "thought", id = 1, scenarioId = "s", icon = "idea" })).toThrow("text must be a string")
		expect(thought({ text = string.rep("a", EventCodec.TEXT_MAX + 1) })).toThrow("text is 1025 bytes")
		expect(thought({ text = string.rep("é", 513) })).toThrow("text is 1026 bytes") -- bytes, not characters
		expect(thought({ text = "bad \255 byte" })).toThrow("not valid UTF-8")
		expect(thought({ scenarioId = "" })).toThrow("scenarioId is 0 bytes")
		expect(thought({ scenarioId = string.rep("s", EventCodec.ID_MAX + 1) })).toThrow("scenarioId is 49 bytes")
		expect(bad({ type = "reaction", id = 1, text = "hm", tone = "furious" })).toThrow("unknown tone")
		expect(bad({ type = "reaction", id = 1, text = {}, tone = "sad" })).toThrow("text must be a string")
		expect(bad({ type = "reaction", text = "hm", tone = "sad" })).toThrow("outside 1..65535")
		expect(bad({ type = "strike", occupation = "farmer", on = 1, entityIds = {} })).toThrow("on must be a boolean")
		expect(bad({ type = "strike", occupation = "farmer", entityIds = {} })).toThrow("on must be a boolean")
		expect(bad({ type = "strike", on = true, entityIds = {} })).toThrow("occupation must be a string")
		expect(bad({ type = "strike", occupation = "", on = true, entityIds = {} })).toThrow("occupation is 0 bytes")
		expect(bad({ type = "strike", occupation = "farmer", on = true })).toThrow("entityIds must be a list")
		expect(bad({ type = "strike", occupation = "farmer", on = true, entityIds = { 0 } })).toThrow(
			"outside 1..65535"
		)
		expect(bad({ type = "kcue", cue = "bow", entityIds = { 1.5 } })).toThrow("outside 1..65535")
		expect(bad({ type = "kcue", cue = "bow", entityIds = "1,2" })).toThrow("entityIds must be a list")
		local tooMany = {}
		for i = 1, EventCodec.ID_LIST_MAX + 1 do
			tooMany[i] = i
		end
		expect(bad({ type = "kcue", cue = "bow", entityIds = tooMany })).toThrow("more than")
		expect(bad({ type = "kcue", id = 1, cue = "dance" })).toThrow("unknown cue")
		expect(bad({ type = "kcue", id = 1, cue = "deposit" })).toThrow("unknown cue") -- a G4 cue, not G13.3
		expect(bad({ type = "kcue", id = 70000, cue = "bow" })).toThrow("outside 1..65535")
		expect(bad({ type = "kcue", id = 1.5, cue = "bow" })).toThrow("outside 1..65535")
		expect(bad({ type = "kcue", occupation = "", cue = "bow" })).toThrow("occupation is 0 bytes")
		expect(bad({ type = "kcue", occupation = 7, cue = "bow" })).toThrow("occupation must be a string")
		expect(bad({ type = "cue", id = 1, cue = "grumble" })).toThrow("unknown cue") -- G4 CUES stay frozen
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

	it("decodes malformed conversation records to nil with a reason, never an error", function()
		-- one record each, so the offsets below are fixed: header 6 B, then tag at 6
		local function one(event)
			return EventCodec.encode(0, { event })
		end
		local function mutated(good: buffer, fn)
			local out = buffer.create(buffer.len(good))
			buffer.copy(out, 0, good)
			fn(out)
			return out
		end
		local function cut(good: buffer, drop: number)
			local out = buffer.create(buffer.len(good) - drop)
			buffer.copy(out, 0, good, 0, buffer.len(out))
			return out
		end
		local thought = one({ type = "thought", id = 1, scenarioId = "sc", text = "héllo", icon = "idea" })
		local reaction = one({ type = "reaction", id = 1, text = "ok", tone = "happy" })
		local strike = one({ type = "strike", occupation = "farmer", on = true, entityIds = { 5, 6 } })
		local kcue = one({ type = "kcue", id = 1, occupation = "farmer", cue = "bow" })
		local cases = {
			{ cut(thought, 1), "truncated text" }, -- the last byte of the text is missing
			{ cut(thought, 7), "truncated" }, -- the text's length prefix is cut
			{ cut(strike, 3), "truncated occupation" },
			{ cut(strike, 9), "truncated ids" }, -- 7 of 16 bytes: the second id is cut
			{
				mutated(strike, function(b)
					buffer.writeu16(b, 6 + 2, EventCodec.ID_LIST_MAX + 1) -- the count is checked first
				end),
				`{EventCodec.ID_LIST_MAX + 1} ids`,
			},
			{
				mutated(strike, function(b)
					buffer.writeu16(b, 6 + 2 + 2 + 2, 0) -- the second id
				end),
				"id 0 in entityIds",
			},
			{
				mutated(thought, function(b)
					buffer.writeu16(b, 6 + 4, 2000) -- scenarioId longer than the buffer and than ID_MAX
				end),
				"scenarioId of 2000 bytes",
			},
			{
				mutated(thought, function(b)
					buffer.writeu16(b, 6 + 4, 0) -- a required id string may not be empty
				end),
				"scenarioId of 0 bytes",
			},
			{
				mutated(reaction, function(b)
					buffer.writeu16(b, 6 + 4, EventCodec.TEXT_MAX + 1)
				end),
				"text of 1025 bytes",
			},
			{
				mutated(thought, function(b)
					buffer.writeu8(b, 6 + 3, 4) -- icon code out of range
				end),
				"bad icon",
			},
			{
				mutated(thought, function(b)
					buffer.writeu8(b, 6 + 3, 0)
				end),
				"bad icon",
			},
			{
				mutated(reaction, function(b)
					buffer.writeu8(b, 6 + 3, 5) -- tone code out of range
				end),
				"bad tone",
			},
			{
				mutated(strike, function(b)
					buffer.writeu8(b, 6 + 1, 2) -- on is 0 or 1
				end),
				"bad strike flag",
			},
			{
				mutated(kcue, function(b)
					buffer.writeu8(b, 6 + 3, #EventCodec.KINGDOM_CUES + 1)
				end),
				"bad cue",
			},
			{
				mutated(thought, function(b)
					buffer.writeu16(b, 6 + 1, 0) -- a thought needs an entity
				end),
				"id 0",
			},
			{
				mutated(reaction, function(b)
					buffer.writeu8(b, 6 + 6, 0xff) -- not UTF-8
				end),
				"not UTF-8",
			},
		}
		for _, case in cases do
			local ok, batch, reason = pcall(EventCodec.decode, case[1])
			expect(ok).toBe(true)
			expect(batch).toBeNil()
			expect(reason).toContain(case[2])
		end
		-- kcue: entity id 0 and an empty occupation are "none", not errors
		local bare = mutated(kcue, function(b)
			buffer.writeu16(b, 6 + 1, 0)
		end)
		expect(assert(EventCodec.decode(bare)).events[1]).toEqual({ type = "kcue", occupation = "farmer", cue = "bow" })
	end)
end)
