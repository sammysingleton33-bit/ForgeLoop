local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Wallet = require("@game/ReplicatedStorage/Forge/Economy/Wallet")

local IDS = { "food", "wood", "stone", "gold" }

describe("Economy/Bundle", function()
	it("validates amounts: whole, positive, finite, bounded, known currencies", function()
		expect((Bundle.validate({ wood = 5 }))).toBe(true)
		expect((Bundle.validate({ wood = 0 }))).toBe(false)
		expect((Bundle.validate({ wood = 0 }, { allowZero = true }))).toBe(true)
		expect((Bundle.validate({ wood = -1 }))).toBe(false)
		expect((Bundle.validate({ wood = 1.5 }))).toBe(false)
		expect((Bundle.validate({ wood = 0 / 0 }))).toBe(false)
		expect((Bundle.validate({ wood = math.huge }))).toBe(false)
		expect((Bundle.validate({ wood = Bundle.MAX_AMOUNT + 1 }))).toBe(false)
		expect((Bundle.validate({ [1] = 5 }))).toBe(false)
		expect((Bundle.validate({}))).toBe(false)
		expect((Bundle.validate({}, { allowEmpty = true }))).toBe(true)
		local ok, problem = Bundle.validate({ mana = 1 }, { currencies = { wood = true } })
		expect(ok).toBe(false)
		expect(problem).toContain("mana")
	end)

	it("computes covers, missing and ordering without mutating inputs", function()
		local have = { wood = 30, food = 100 }
		local cost = { wood = 50, food = 20 }
		expect(Bundle.covers(have, cost)).toBe(false)
		expect(Bundle.missing(have, cost)).toEqual({ wood = 20 })
		expect(Bundle.missing({ wood = 50, food = 20 }, cost)).toEqual({})
		expect(have).toEqual({ wood = 30, food = 100 })
		expect(Bundle.ordered({ gold = 1, wood = 2, food = 0, zeta = 3 }, IDS)).toEqual({
			{ id = "wood", amount = 2 },
			{ id = "gold", amount = 1 },
			{ id = "zeta", amount = 3 },
		})
		expect(Bundle.equals({ wood = 1, food = 0 }, { wood = 1 })).toBe(true)
	end)
end)

describe("Economy/Wallet", function()
	local wallet
	beforeEach(function()
		wallet = Wallet.new({
			currencies = IDS,
			start = { food = 100, wood = 150, stone = 50, gold = 50 },
			caps = { food = 500, wood = 500, stone = 300, gold = 300 },
		})
	end)

	it("spends a bundle all-or-nothing and reports the signed change", function()
		local ok, reason, result = wallet:spend({ wood = 50, food = 20 }, "tx-1")
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		expect(result.applied).toEqual({ wood = -50, food = -20 })
		expect(wallet:balances()).toEqual({ food = 80, wood = 100, stone = 50, gold = 50 })
	end)

	it("refuses a spend it cannot cover, changes nothing and leaves the txId usable", function()
		local ok, reason, result = wallet:spend({ wood = 50, stone = 60 }, "tx-short")
		expect(ok).toBe(false)
		expect(reason).toBe("insufficient")
		expect(result.missing).toEqual({ stone = 10 })
		expect(wallet:balances()).toEqual({ food = 100, wood = 150, stone = 50, gold = 50 })
		expect(wallet:seen("tx-short")).toBe(false)
		wallet:grant({ stone = 10 }, "earn")
		local retried = wallet:spend({ wood = 50, stone = 60 }, "tx-short")
		expect(retried).toBe(true)
		expect(wallet:balance("stone")).toBe(0)
	end)

	it("never goes below zero", function()
		expect((wallet:spend({ gold = 50 }, "a"))).toBe(true)
		local ok, reason = wallet:spend({ gold = 1 }, "b")
		expect(ok).toBe(false)
		expect(reason).toBe("insufficient")
		expect(wallet:balance("gold")).toBe(0)
	end)

	it("is idempotent per txId: a replay changes nothing and says so", function()
		expect((wallet:spend({ wood = 50 }, "build:1"))).toBe(true)
		local ok, reason, result = wallet:spend({ wood = 50 }, "build:1")
		expect(ok).toBe(true)
		expect(reason).toBe("replay")
		expect(result.applied).toEqual({})
		expect(wallet:balance("wood")).toBe(100)
		local gOk, gReason = wallet:grant({ food = 10 }, "build:1")
		expect(gOk).toBe(true)
		expect(gReason).toBe("replay")
		expect(wallet:balance("food")).toBe(100)
	end)

	it("clamps grants at the cap, reports overflow and still consumes the txId", function()
		local ok, _, result = wallet:grant({ food = 450, gold = 10 }, "harvest")
		expect(ok).toBe(true)
		expect(result.applied).toEqual({ food = 400, gold = 10 })
		expect(result.overflow).toEqual({ food = 50 })
		expect(wallet:balance("food")).toBe(500)
		local _, _, full = wallet:grant({ food = 5 }, "harvest-2")
		expect(full.applied).toEqual({})
		expect(full.overflow).toEqual({ food = 5 })
		expect(wallet:seen("harvest-2")).toBe(true)
	end)

	it("guards overflow even without a configured cap", function()
		local open = Wallet.new({ currencies = { "crowns" } })
		local _, _, result = open:grant({ crowns = Bundle.MAX_AMOUNT }, "a")
		expect(result.applied).toEqual({ crowns = Bundle.MAX_AMOUNT })
		local _, _, more = open:grant({ crowns = 5 }, "b")
		expect(more.overflow).toEqual({ crowns = 5 })
		expect(open:balance("crowns")).toBe(Bundle.MAX_AMOUNT)
	end)

	it("rejects bad transactions without changing anything", function()
		local cases = {
			{ { wood = -5 }, "t1", "invalid_amount" },
			{ { wood = 2.5 }, "t2", "invalid_amount" },
			{ { mana = 5 }, "t3", "invalid_amount" },
			{ {}, "t4", "invalid_amount" },
			{ { wood = 5 }, "", "invalid_tx" },
			{ { wood = 5 }, string.rep("x", 101), "invalid_tx" },
		}
		for _, case in cases do
			local ok, reason = wallet:spend(case[1], case[2])
			expect(ok).toBe(false)
			expect(reason).toBe(case[3])
			local gOk, gReason = wallet:grant(case[1], case[2])
			expect(gOk).toBe(false)
			expect(gReason).toBe(case[3])
		end
		expect(wallet:balances()).toEqual({ food = 100, wood = 150, stone = 50, gold = 50 })
	end)

	it("persists balances and processed txIds in the data table it was given", function()
		local data = {}
		local first = Wallet.new({ currencies = IDS, data = data, start = { wood = 10 } })
		first:grant({ wood = 5 }, "quest:1")
		expect(data.balances.wood).toBe(15)
		expect(data.txOrder).toEqual({ "quest:1" })
		local reloaded = Wallet.new({ currencies = IDS, data = data, start = { wood = 999 } })
		expect(reloaded:balance("wood")).toBe(15)
		local _, reason = reloaded:grant({ wood = 5 }, "quest:1")
		expect(reason).toBe("replay")
		expect(reloaded:balance("wood")).toBe(15)
	end)

	it("forgets the oldest txIds beyond txLimit", function()
		local small = Wallet.new({ currencies = IDS, txLimit = 2 })
		small:grant({ wood = 1 }, "a")
		small:grant({ wood = 1 }, "b")
		small:grant({ wood = 1 }, "c")
		expect(small:seen("a")).toBe(false)
		expect(small:seen("b")).toBe(true)
		expect(small:seen("c")).toBe(true)
	end)

	it("raises caps without touching balances", function()
		wallet:setCaps({ wood = 750 })
		expect(wallet:caps().wood).toBe(750)
		local _, _, result = wallet:grant({ wood = 700 }, "big")
		expect(result.applied).toEqual({ wood = 600 })
		expect(function()
			wallet:setCaps({ mana = 5 })
		end).toThrow("mana")
	end)
end)
