local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")

local Decision = Enum.ProductPurchaseDecision

describe("MockMarketplaceService", function()
	describe("ProcessReceipt", function()
		it("PurchaseGranted resolves the receipt", function()
			local env = MockEnv.new()
			env.mock.players:add({ userId = 1 })
			local mps = env.MarketplaceService
			local seen
			mps.ProcessReceipt = function(receipt)
				seen = receipt
				return Decision.PurchaseGranted
			end
			local record = mps:simulateReceipt({ PlayerId = 1, ProductId = 77, CurrencySpent = 25 })
			expect(record.done).toBe(true)
			expect(record.decision).toBe(Decision.PurchaseGranted)
			expect(seen.ProductId).toBe(77)
			expect(seen.CurrencySpent).toBe(25)
			expect(seen.CurrencyType).toBe(Enum.CurrencyType.Robux)
			expect(type(seen.PurchaseId)).toBe("string")
			expect(#mps:pending()).toBe(0)
			expect(#mps:resolved()).toBe(1)
		end)

		it("NotProcessedYet and errors stay pending and are redelivered with the same PurchaseId", function()
			local env = MockEnv.new()
			env.mock.players:add({ userId = 1 })
			local mps = env.MarketplaceService
			local attempt = 0
			local purchaseIds = {}
			mps.ProcessReceipt = function(receipt)
				attempt += 1
				table.insert(purchaseIds, receipt.PurchaseId)
				if attempt == 1 then
					return Decision.NotProcessedYet
				elseif attempt == 2 then
					error("profile not loaded")
				end
				return Decision.PurchaseGranted
			end
			local first = mps:simulateReceipt({ PlayerId = 1, ProductId = 5, PurchaseId = "P-1" })
			expect(first.decision).toBe(Decision.NotProcessedYet)
			local second = mps:redeliverPending(1)
			expect(second[1].decision).toBe("Error")
			expect(second[1].error).toContain("profile not loaded")
			local third = mps:redeliverPending()
			expect(third[1].decision).toBe(Decision.PurchaseGranted)
			expect(purchaseIds).toEqual({ "P-1", "P-1", "P-1" })
			expect(#mps:redeliverPending()).toBe(0)
			expect(#mps.deliveries).toBe(3)
		end)

		it("a receipt for a player who is not in the server stays pending and is not processed", function()
			local env = MockEnv.new()
			local mps = env.MarketplaceService
			local calls = 0
			mps.ProcessReceipt = function()
				calls += 1
				return Decision.PurchaseGranted
			end
			local record = mps:simulateReceipt({ PlayerId = 42, ProductId = 1 })
			expect(record.decision).toBe("PlayerNotInServer")
			expect(calls).toBe(0)
			env.mock.players:add({ userId = 42 })
			expect(mps:redeliverPending(42)[1].decision).toBe(Decision.PurchaseGranted)
		end)

		it("without a callback the receipt is auto-acknowledged (documented hazard)", function()
			local env = MockEnv.new()
			env.mock.players:add({ userId = 1 })
			local record = env.MarketplaceService:simulateReceipt({ PlayerId = 1, ProductId = 1 })
			expect(record.decision).toBe("AutoAcknowledged")
		end)

		it("a yielding callback records its decision when it finishes (virtual time)", function()
			local env = MockEnv.new()
			env.mock.players:add({ userId = 1 })
			env.MarketplaceService.ProcessReceipt = function()
				env.wait(2) -- e.g. saveNow() with data-store latency
				return Decision.PurchaseGranted
			end
			local record = env.MarketplaceService:simulateReceipt({ PlayerId = 1, ProductId = 1 })
			expect(record.done).toBe(false)
			env.mock:advance(2)
			expect(record.done).toBe(true)
			expect(record.decision).toBe(Decision.PurchaseGranted)
		end)

		it("an unexpected return value leaves the receipt pending", function()
			local env = MockEnv.new()
			env.mock.players:add({ userId = 1 })
			env.MarketplaceService.ProcessReceipt = function()
				return true
			end
			expect(env.MarketplaceService:simulateReceipt({ PlayerId = 1, ProductId = 1 }).decision).toBe("Invalid")
			expect(#env.MarketplaceService:pending()).toBe(1)
		end)
	end)

	describe("game passes", function()
		it("UserOwnsGamePassAsync answers per user/pass and can fail", function()
			local mps = MockEnv.new().MarketplaceService
			mps:setOwnsPass(1, 100, true)
			expect(mps:UserOwnsGamePassAsync(1, 100)).toBe(true)
			expect(mps:UserOwnsGamePassAsync(2, 100)).toBe(false)
			mps:failNext("UserOwnsGamePassAsync", 1, "HTTP 503")
			expect(function()
				mps:UserOwnsGamePassAsync(1, 100)
			end).toThrow("HTTP 503")
			expect(mps:UserOwnsGamePassAsync(1, 100)).toBe(true)
			expect(#mps.ownershipCalls).toBe(4)
		end)

		it("prompts are recorded; finishing a prompt fires the signal and grants ownership", function()
			local env = MockEnv.new()
			local player = env.mock.players:add({ userId = 7 })
			local mps = env.MarketplaceService
			local finished
			mps.PromptGamePassPurchaseFinished:Connect(function(p, passId, purchased)
				finished = { p.UserId, passId, purchased }
			end)
			mps:PromptGamePassPurchase(player, 200)
			mps:PromptProductPurchase(player, 300)
			expect(mps.prompts).toEqual({
				{ kind = "pass", userId = 7, id = 200 },
				{ kind = "product", userId = 7, id = 300 },
			})
			mps:finishGamePassPrompt(player, 200, true)
			expect(finished).toEqual({ 7, 200, true })
			expect(mps:UserOwnsGamePassAsync(7, 200)).toBe(true)
		end)
	end)
end)
