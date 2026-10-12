local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ItemRegistry = require("@game/ReplicatedStorage/Forge/Economy/ItemRegistry")
local Items = require("@game/ReplicatedStorage/Forge/Config/Items")

local NIL = table.freeze({}) -- marks a field to remove in an override

-- A valid cosmetic definition with fields replaced (or removed with NIL).
local function cosmetic(overrides: { [string]: any }?)
	local def: { [string]: any } = {
		id = "hat",
		kind = "cosmetic",
		name = "Hat",
		description = "A hat.",
		icon = "hat",
		rarity = "Common",
	}
	for key, value in overrides or {} do
		def[key] = if value == NIL then nil else value
	end
	return def
end

local function problemsOf(defs: any): { string }
	local ok, problems = ItemRegistry.validate(defs)
	expect(ok).toBe(#problems == 0)
	return problems
end

-- Exactly one problem, containing every given substring.
local function expectOneProblem(defs: any, ...: string)
	local problems = problemsOf(defs)
	expect(problems).toHaveLength(1)
	for _, part in { ... } do
		expect(problems[1]).toContain(part)
	end
end

describe("Economy/ItemRegistry", function()
	describe("constants", function()
		it("lists rarities in rank order and the three kinds, frozen", function()
			expect(ItemRegistry.RARITIES).toEqual({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })
			expect(ItemRegistry.KINDS).toEqual({ "building", "unit", "cosmetic" })
			expect(table.isfrozen(ItemRegistry.RARITIES)).toBe(true)
			expect(table.isfrozen(ItemRegistry.KINDS)).toBe(true)
		end)

		it("ranks rarities 1..5 and returns nil for anything else", function()
			expect(ItemRegistry.rarityRank("Common")).toBe(1)
			expect(ItemRegistry.rarityRank("Legendary")).toBe(5)
			expect(ItemRegistry.rarityRank("legendary")).toBeNil()
			expect(ItemRegistry.rarityRank(3)).toBeNil()
		end)

		it("accepts ids matching ^[a-z][a-z0-9_]*$ up to 32 bytes", function()
			expect(ItemRegistry.isValidId("banner_oak2")).toBe(true)
			expect(ItemRegistry.isValidId(string.rep("a", 32))).toBe(true)
			expect(ItemRegistry.isValidId(string.rep("a", 33))).toBe(false)
			expect(ItemRegistry.isValidId("Banner")).toBe(false)
			expect(ItemRegistry.isValidId("2banner")).toBe(false)
			expect(ItemRegistry.isValidId("banner-oak")).toBe(false)
			expect(ItemRegistry.isValidId("")).toBe(false)
			expect(ItemRegistry.isValidId(nil)).toBe(false)
		end)
	end)

	describe("default()", function()
		it("validates Config.Items with no problems", function()
			local ok, problems = ItemRegistry.validate(Items)
			expect(problems).toEqual({})
			expect(ok).toBe(true)
		end)

		it("holds every config item in config order and is cached", function()
			local registry = ItemRegistry.default()
			expect(ItemRegistry.default()).toBe(registry)
			local all = registry:all()
			expect(all).toHaveLength(#Items)
			for index, def in Items do
				expect(all[index].id).toBe(def.id)
				expect(registry:get(def.id)).toBe(all[index])
			end
		end)

		it("returns deep-frozen copies and leaves the config tables unfrozen and unchanged", function()
			local registry = ItemRegistry.default()
			local townhall = registry:require("townhall")
			local source
			for _, def in Items do
				if def.id == "townhall" then
					source = def
				end
			end
			expect(townhall).never.toBe(source)
			expect(townhall).toEqual(source) -- building sub-table passed through with the same contents
			expect(table.isfrozen(townhall)).toBe(true)
			expect(table.isfrozen(townhall.building)).toBe(true)
			expect(table.isfrozen((townhall.building :: any).levels[2].cost)).toBe(true)
			expect(table.isfrozen(source)).toBe(false)
			expect(table.isfrozen(source.building)).toBe(false)
			expect(function()
				(townhall :: any).name = "Changed"
			end).toThrow()
			expect(table.isfrozen(registry:all())).toBe(true)
		end)

		it("groups items by kind in config order", function()
			local registry = ItemRegistry.default()
			local ids = {}
			for _, def in registry:ofKind("cosmetic") do
				table.insert(ids, def.id)
			end
			expect(ids).toEqual({ "banner_oak", "banner_lion", "banner_dragon", "crest_phoenix", "crest_sun" })
			expect(#registry:ofKind("building") + #registry:ofKind("unit") + #ids).toBe(#Items)
		end)
	end)

	describe("lookups", function()
		local registry = ItemRegistry.new({
			cosmetic(),
			cosmetic({ id = "cape", equipSlot = "back", maxStack = 3 }),
			{
				id = "hut",
				kind = "building",
				name = "Hut",
				description = "d",
				icon = "hut",
				rarity = "Common",
				building = {},
			},
		})

		it("get returns the definition or nil (also for non-string ids)", function()
			expect((registry:get("cape") :: any).maxStack).toBe(3)
			expect(registry:get("nope")).toBeNil()
			expect(registry:get(nil :: any)).toBeNil()
			expect(registry:get(5 :: any)).toBeNil()
		end)

		it("require errors on an unknown id, naming it", function()
			expect(registry:require("hat").id).toBe("hat")
			expect(function()
				registry:require("nope")
			end).toThrow('unknown item id "nope"')
		end)

		it("ofKind returns an empty list for a kind with no items and errors on an unknown kind", function()
			expect(registry:ofKind("unit")).toEqual({})
			expect(#registry:ofKind("cosmetic")).toBe(2)
			expect(function()
				registry:ofKind("cosmetics")
			end).toThrow('unknown kind "cosmetics"')
		end)
	end)

	describe("validation", function()
		it("accepts a minimal cosmetic and every optional field", function()
			expect(problemsOf({ cosmetic(), cosmetic({ id = "cape", maxStack = 99, equipSlot = "back" }) })).toEqual({})
		end)

		it("rejects ids that break the pattern or the 32-byte limit", function()
			expectOneProblem({ cosmetic({ id = "Hat" }) }, "item 1", "id must be")
			expectOneProblem({ cosmetic({ id = "hat-2" }) }, "id must be", '"hat-2"')
			expectOneProblem({ cosmetic({ id = string.rep("h", 33) }) }, "id must be", "32 bytes")
			expectOneProblem({ cosmetic({ id = NIL }) }, "item 1:", "id must be", "got nil")
		end)

		it("rejects duplicate ids, naming the first occurrence", function()
			expectOneProblem({ cosmetic(), cosmetic({ name = "Other" }) }, 'item 2 ("hat")', "id duplicates item 1")
		end)

		it("rejects an unknown kind", function()
			expectOneProblem({ cosmetic({ kind = "pet" }) }, 'item 1 ("hat")', "kind must be one of", '"pet"')
		end)

		it("rejects empty or missing name, description and icon", function()
			expectOneProblem({ cosmetic({ name = "" }) }, "name must be a non-empty string")
			expectOneProblem({ cosmetic({ description = NIL }) }, "description must be a non-empty string")
			expectOneProblem({ cosmetic({ icon = 7 }) }, "icon must be a non-empty string", "got 7")
		end)

		it("rejects an unknown rarity", function()
			expectOneProblem({ cosmetic({ rarity = "Mythic" }) }, "rarity must be one of", '"Mythic"')
		end)

		it("rejects maxStack that is not an integer >= 1", function()
			expectOneProblem({ cosmetic({ maxStack = 0 }) }, "maxStack must be nil or an integer >= 1")
			expectOneProblem({ cosmetic({ maxStack = 1.5 }) }, "maxStack")
			expectOneProblem({ cosmetic({ maxStack = math.huge }) }, "maxStack")
			expectOneProblem({ cosmetic({ maxStack = "3" }) }, "maxStack")
		end)

		it("allows equipSlot only on cosmetics, as a non-empty string", function()
			expectOneProblem({ cosmetic({ equipSlot = "" }) }, "equipSlot must be a non-empty string")
			expectOneProblem({
				{
					id = "hut",
					kind = "building",
					name = "Hut",
					description = "d",
					icon = "hut",
					rarity = "Common",
					building = {},
					equipSlot = "roof",
				},
			}, 'item 1 ("hut")', "equipSlot is only allowed on cosmetic items")
		end)

		it("requires the kind's sub-table and rejects the other kind's", function()
			expectOneProblem({ cosmetic({ kind = "building" }) }, 'building must be a table when kind is "building"')
			expectOneProblem({ cosmetic({ kind = "unit", unit = true }) }, 'unit must be a table when kind is "unit"')
			expectOneProblem({ cosmetic({ unit = {} }) }, 'unit is only allowed when kind is "unit"')
			expectOneProblem(
				{ cosmetic({ kind = "unit", unit = {}, building = {} }) },
				'building is only allowed when kind is "building"'
			)
		end)

		it("rejects unknown top-level fields (typo guard)", function()
			expectOneProblem({ cosmetic({ maxstack = 2 }) }, 'item 1 ("hat")', 'unknown field "maxstack"')
		end)

		it("rejects entries and lists of the wrong shape", function()
			expectOneProblem({ cosmetic(), "hat" }, "item 2: must be a table")
			expectOneProblem("items", "items: must be a list of item definitions")
			local withKey: any = { cosmetic() }
			withKey.extra = cosmetic({ id = "extra" })
			expectOneProblem(withKey, "items: must be a list")
		end)

		it("collects every problem, not just the first", function()
			local problems = problemsOf({
				cosmetic({ rarity = "Mythic", maxStack = 0, colour = "red" }),
				cosmetic({ id = "Bad" }),
			})
			expect(problems).toHaveLength(4)
			local text = table.concat(problems, "\n")
			expect(text).toContain('unknown field "colour"')
			expect(text).toContain("rarity must be one of")
			expect(text).toContain("maxStack must be nil")
			expect(text).toContain('item 2 ("Bad"): id must be')
		end)

		it("new() errors listing every problem", function()
			expect(function()
				ItemRegistry.new({ cosmetic({ rarity = "Mythic" }), cosmetic({ id = "hat2", icon = "" }) })
			end).toThrow("invalid item definitions (2)")
			local ok, err =
				pcall(ItemRegistry.new, { cosmetic({ rarity = "Mythic" }), cosmetic({ id = "hat2", icon = "" }) })
			expect(ok).toBe(false)
			expect(tostring(err)).toContain("rarity must be one of")
			expect(tostring(err)).toContain('item 2 ("hat2"): icon must be a non-empty string')
		end)
	end)
end)
