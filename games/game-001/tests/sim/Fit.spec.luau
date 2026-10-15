local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

describe("Build/Fit (CONTRACTS G13.5)", function()
	it("fits a type when its largest-level Kit footprint fits the slot on both axes", function()
		for _, size in Fit.SIZES do
			local slot = WorldLayout.slotSizes[size]
			for _, kind in Types.BUILDING_TYPES do
				local fp = Kit.footprint(kind, Costs.maxLevel(kind))
				expect(Fit.largestFootprint(kind)).toEqual(fp)
				expect(Fit.fits(kind, size)).toBe(fp.X <= slot.X and fp.Y <= slot.Y)
			end
		end
	end)

	it("matches the contract's VS-1 picture: S, then M adds barracks, then L adds farm; no keep", function()
		local S = Fit.typesFor("S")
		for _, kind in { "house", "lumbercamp", "quarry", "storehouse", "watchtower" } do
			expect(table.find(S, kind)).never.toBeNil()
		end
		for _, kind in { "barracks", "farm", "keep" } do
			expect(table.find(S, kind)).toBeNil()
		end
		local M = Fit.typesFor("M")
		expect(table.find(M, "barracks")).never.toBeNil()
		expect(table.find(M, "farm")).toBeNil()
		local L = Fit.typesFor("L")
		expect(table.find(L, "farm")).never.toBeNil()
		expect(table.find(L, "keep")).toBeNil() -- keep level 1 (32 x 32) would fit L; level 3 does not
		for _, size in Fit.SIZES do
			for _, kind in Fit.typesFor(size) do
				local larger = if size == "S" then "M" elseif size == "M" then "L" else nil
				if larger then
					expect(Fit.fits(kind, larger)).toBe(true) -- slots nest
				end
			end
		end
	end)

	it("uses the largest level, not level 1", function()
		local kind = "keep"
		local first, last = Kit.footprint(kind, 1), Kit.footprint(kind, Costs.maxLevel(kind))
		local L = WorldLayout.slotSizes.L
		expect(first.X <= L.X and first.Y <= L.Y).toBe(true)
		expect(last.X <= L.X and last.Y <= L.Y).toBe(false)
		expect(Fit.fits(kind, "L")).toBe(false)
	end)

	it(
		"turns with turn: an odd turn swaps the footprint's axes; Fit.turns lists the turns that fit (CONTRACTS v0.4-g9h)",
		function()
			local sawAll, sawHalfOnly = false, false
			for _, size in Fit.SIZES do
				local slot = WorldLayout.slotSizes[size]
				for _, kind in Types.BUILDING_TYPES do
					local fp = Fit.largestFootprint(kind)
					local listed = Fit.turns(kind, size)
					if fp == nil then
						expect(listed).toEqual({})
						continue
					end
					local fitsStraight = fp.X <= slot.X and fp.Y <= slot.Y
					local fitsTurned = fp.Y <= slot.X and fp.X <= slot.Y
					local expected = {}
					for rot = 0, 3 do
						local want = if rot % 2 == 0 then fitsStraight else fitsTurned
						expect(Fit.fits(kind, size, rot)).toBe(want)
						if want then
							table.insert(expected, rot)
						end
					end
					expect(listed).toEqual(expected) -- ascending, only the rots that fit
					expect(Fit.fits(kind, size)).toBe(Fit.fits(kind, size, 0)) -- no rot is rot 0
					expect(Fit.fits(kind, size, 4)).toBe(Fit.fits(kind, size, 0)) -- turns wrap
					expect(Fit.fits(kind, size, -1)).toBe(Fit.fits(kind, size, 3))
					sawAll = sawAll or #listed == 4
					sawHalfOnly = sawHalfOnly or (#listed == 2 and listed[2] == 2)
				end
			end
			expect(sawAll).toBe(true) -- a square-ish type turns every way (a house in an S slot)
			expect(sawHalfOnly).toBe(true) -- a long one fits unturned or half-turned only (a barracks in an M slot)
			expect(Fit.turns("castle", "L")).toEqual({})
			expect(Fit.turns("house", "XL")).toEqual({})
		end
	)

	it("fits nothing for unknown types or sizes, and lists in Types.BUILDING_TYPES order", function()
		expect(Fit.fits("castle", "L")).toBe(false)
		expect(Fit.largestFootprint("castle")).toBeNil()
		expect(Fit.fits("house", "XL")).toBe(false)
		expect(Fit.fits("__index", "S")).toBe(false)
		expect(Fit.typesFor("XL")).toEqual({})
		local listed = Fit.typesFor("L")
		local last = 0
		for _, kind in listed do
			local index = table.find(Types.BUILDING_TYPES, kind) :: number
			expect(index > last).toBe(true)
			last = index
		end
		table.insert(listed, "castle")
		expect(table.find(Fit.typesFor("L"), "castle")).toBeNil() -- a fresh table every call
	end)
end)
