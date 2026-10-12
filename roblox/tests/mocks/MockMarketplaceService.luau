--[[
	MockMarketplaceService — ProcessReceipt slot with receipt simulation and redelivery, game-pass
	ownership answers and failures, and recorded purchase prompts.

	Imitates (creator-docs content/en-us/...):
	  reference/engine/classes/MarketplaceService.yaml  ProcessReceipt (receiptInfo: PurchaseId, PlayerId,
	      ProductId, CurrencySpent, CurrencyType, PlaceIdWherePurchased), UserOwnsGamePassAsync,
	      PromptProductPurchase, PromptGamePassPurchase, PromptGamePassPurchaseFinished
	  production/monetization/developer-products.md     granting rules
	Semantics kept:
	  - A receipt is resolved only when ProcessReceipt returns Enum.ProductPurchaseDecision.PurchaseGranted.
	    NotProcessedYet, an error, a nil/other return, or "the buyer is not in this server" leave it
	    pending; it is delivered again with the SAME PurchaseId on the next opportunity
	    (simulate with redeliverPending, e.g. after a rejoin).
	  - If no ProcessReceipt callback is set the receipt is auto-acknowledged (docs: "If you don't
	    implement a ProcessReceipt callback, your receipts will be auto-acknowledged") and recorded
	    with decision "AutoAcknowledged" — a spec can assert that this never happens.
	  - The callback runs in its own thread (`spawn`, MockEnv's when created through MockEnv), may
	    yield, and its decision is recorded when it returns.
	Not modelled: BindReceiptHandler (newer API), GetProductInfoAsync, real prompts/UI.

	Roblox API: ProcessReceipt (assignable), UserOwnsGamePassAsync(userId, passId),
	  PromptProductPurchase(player, productId), PromptGamePassPurchase(player, passId),
	  PromptGamePassPurchaseFinished (signal: player, passId, wasPurchased)
	Control API (tests only):
		MockMarketplaceService.new({ spawn = fn?, wait = fn?, players = playersControl? })
		    wait: UserOwnsGamePassAsync yields through it (MockEnv: one frame), like the web call
		mps:simulateReceipt({ PlayerId, ProductId, PurchaseId?, CurrencySpent?, PlaceIdWherePurchased? }) -> record
		    record = { receipt, done: boolean, decision: EnumItem | "AutoAcknowledged" | "Error" | "PlayerNotInServer" | "Invalid", error? }
		mps:redeliverPending(playerId?) -> { record }   -- one new delivery per pending receipt
		mps.deliveries: { record }                      -- every delivery attempt, in order
		mps:pending() / mps:resolved() -> { receipt }
		mps:setOwnsPass(userId, passId, owns)
		mps:failNext("UserOwnsGamePassAsync", count?, message?)
		mps:finishGamePassPrompt(player, passId, purchased)  -- fires PromptGamePassPurchaseFinished
		mps.prompts: { { kind = "product" | "pass", userId, id } }
		mps.ownershipCalls: { { userId, passId } }
]]

local MockSignal = require("./MockSignal")

local MockMarketplaceService = {}
MockMarketplaceService.__index = MockMarketplaceService

local DEFAULT_FAILURE = "HTTP 500 (Internal Server Error) [mock MarketplaceService]"

function MockMarketplaceService.new(options: { spawn: ((...any) -> ())?, wait: ((number) -> ())?, players: any? }?)
	local spawn = options and options.spawn
	local self = setmetatable({
		_wait = options and options.wait,
		ProcessReceipt = nil,
		PromptGamePassPurchaseFinished = MockSignal.new({ spawn = spawn, name = "PromptGamePassPurchaseFinished" }),
		PromptProductPurchaseFinished = MockSignal.new({ spawn = spawn, name = "PromptProductPurchaseFinished" }),
		deliveries = {},
		prompts = {},
		ownershipCalls = {},
		_spawn = spawn or function(fn, ...)
			local thread = coroutine.create(fn)
			local ok, err = coroutine.resume(thread, ...)
			if not ok then
				error(err, 0)
			end
		end,
		_players = options and options.players,
		_receipts = {}, -- PurchaseId -> { receipt, resolved }
		_order = {},
		_purchaseCounter = 0,
		_owns = {},
		_failures = {},
	}, MockMarketplaceService)
	return self
end

-- ------------------------------------------------------------------ Roblox API

function MockMarketplaceService:UserOwnsGamePassAsync(userId: number, passId: number): boolean
	assert(type(userId) == "number" and type(passId) == "number", "UserOwnsGamePassAsync(userId, passId)")
	table.insert(self.ownershipCalls, { userId = userId, passId = passId })
	if self._wait then
		self._wait(0) -- an async web call: yields at least one frame
	end
	local failure = self._failures.UserOwnsGamePassAsync
	if failure and failure.remaining > 0 then
		failure.remaining -= 1
		error(failure.message, 0)
	end
	return self._owns[`{userId}:{passId}`] == true
end

function MockMarketplaceService:PromptProductPurchase(player: any, productId: number)
	table.insert(self.prompts, { kind = "product", userId = player.UserId, id = productId })
end

function MockMarketplaceService:PromptGamePassPurchase(player: any, passId: number)
	table.insert(self.prompts, { kind = "pass", userId = player.UserId, id = passId })
end

-- ------------------------------------------------------------------ control API

function MockMarketplaceService:setOwnsPass(userId: number, passId: number, owns: boolean)
	self._owns[`{userId}:{passId}`] = owns
end

function MockMarketplaceService:failNext(method: string, count: number?, message: string?)
	assert(method == "UserOwnsGamePassAsync", "failNext supports UserOwnsGamePassAsync")
	self._failures[method] = { remaining = count or 1, message = message or DEFAULT_FAILURE }
end

function MockMarketplaceService:finishGamePassPrompt(player: any, passId: number, purchased: boolean)
	if purchased then
		self:setOwnsPass(player.UserId, passId, true)
	end
	self.PromptGamePassPurchaseFinished:Fire(player, passId, purchased)
end

function MockMarketplaceService:_playerInServer(userId: number): boolean
	if self._players == nil then
		return true
	end
	return self._players:get(userId) ~= nil
end

function MockMarketplaceService:_deliver(entry)
	local receipt = table.clone(entry.receipt)
	local record = { receipt = receipt, done = false, decision = nil, error = nil }
	table.insert(self.deliveries, record)
	if not self:_playerInServer(receipt.PlayerId) then
		record.done, record.decision = true, "PlayerNotInServer"
		return record
	end
	local callback = self.ProcessReceipt
	if callback == nil then
		record.done, record.decision = true, "AutoAcknowledged"
		entry.resolved = true
		return record
	end
	self._spawn(function()
		local ok, result = pcall(callback, receipt)
		record.done = true
		if not ok then
			record.decision, record.error = "Error", tostring(result)
		elseif result == Enum.ProductPurchaseDecision.PurchaseGranted then
			record.decision = result
			entry.resolved = true
		elseif result == Enum.ProductPurchaseDecision.NotProcessedYet then
			record.decision = result
		else
			record.decision = "Invalid"
		end
	end)
	return record
end

function MockMarketplaceService:simulateReceipt(spec: { [string]: any })
	assert(
		type(spec) == "table" and type(spec.PlayerId) == "number" and type(spec.ProductId) == "number",
		"simulateReceipt({ PlayerId = number, ProductId = number, ... })"
	)
	self._purchaseCounter += 1
	local receipt = {
		PurchaseId = spec.PurchaseId or `mock-purchase-{self._purchaseCounter}`,
		PlayerId = spec.PlayerId,
		ProductId = spec.ProductId,
		CurrencySpent = spec.CurrencySpent or 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = spec.PlaceIdWherePurchased or 0,
	}
	local entry = self._receipts[receipt.PurchaseId]
	if entry == nil then
		entry = { receipt = receipt, resolved = false }
		self._receipts[receipt.PurchaseId] = entry
		table.insert(self._order, receipt.PurchaseId)
	end
	return self:_deliver(entry)
end

function MockMarketplaceService:redeliverPending(playerId: number?)
	local records = {}
	for _, purchaseId in self._order do
		local entry = self._receipts[purchaseId]
		if not entry.resolved and (playerId == nil or entry.receipt.PlayerId == playerId) then
			table.insert(records, self:_deliver(entry))
		end
	end
	return records
end

function MockMarketplaceService:pending()
	local out = {}
	for _, purchaseId in self._order do
		local entry = self._receipts[purchaseId]
		if not entry.resolved then
			table.insert(out, table.clone(entry.receipt))
		end
	end
	return out
end

function MockMarketplaceService:resolved()
	local out = {}
	for _, purchaseId in self._order do
		local entry = self._receipts[purchaseId]
		if entry.resolved then
			table.insert(out, table.clone(entry.receipt))
		end
	end
	return out
end

return MockMarketplaceService
