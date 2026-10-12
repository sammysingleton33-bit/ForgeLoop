--[[
	MockPolicyService — GetPolicyInfoForPlayerAsync with per-player answers and failures.

	Imitates: creator-docs content/en-us/reference/engine/classes/PolicyService.yaml
	  GetPolicyInfoForPlayerAsync(player) -> { ArePaidRandomItemsRestricted, AreAdsAllowed,
	  IsContentSharingAllowed, IsEligibleToPurchaseCommerceProduct, IsEligibleToPurchaseSubscription,
	  IsPaidItemTradingAllowed, IsPhotoToAvatarAllowed, IsSubjectToChinaPolicies,
	  AllowedExternalLinkReferences (legacy, always {}), IsEndlessContentLoadAllowed,
	  IsEndlessContentAutoplayAllowed }.
	  It is an async web call that can fail ("wrap in pcall"); a non-Player argument errors with
	  "Instance was not a player".
	Default answer: the permissive policy below (paid random items NOT restricted). Specs for
	paid-random gating must set the restricted case explicitly with setPolicy.

	Control API (tests only):
		MockPolicyService.new({ wait = fn? })   -- wait: each call yields through it (MockEnv: one frame)
		ps:setPolicy(userId, overrides)     -- merged over the default for that player
		ps:setDefault(overrides)
		ps:failNext(count?, message?)       -- next calls error
		ps:failFor(userId, message?)        -- every call for that player errors until clearFailures()
		ps:clearFailures()
		ps.calls: { userId }
]]

local MockPolicyService = {}
MockPolicyService.__index = MockPolicyService

local DEFAULT_FAILURE = "HTTP 500 (Internal Server Error) [mock PolicyService]"

local function defaultPolicy()
	return {
		ArePaidRandomItemsRestricted = false,
		AreAdsAllowed = true,
		IsContentSharingAllowed = true,
		IsEligibleToPurchaseCommerceProduct = true,
		IsEligibleToPurchaseSubscription = true,
		IsPaidItemTradingAllowed = true,
		IsPhotoToAvatarAllowed = true,
		IsSubjectToChinaPolicies = false,
		AllowedExternalLinkReferences = {},
		IsEndlessContentLoadAllowed = true,
		IsEndlessContentAutoplayAllowed = true,
	}
end

function MockPolicyService.new(options: { wait: ((number) -> ())? }?)
	return setmetatable({
		_wait = options and options.wait,
		calls = {},
		_default = defaultPolicy(),
		_byUser = {},
		_failNext = 0,
		_failMessage = DEFAULT_FAILURE,
		_failFor = {},
	}, MockPolicyService)
end

function MockPolicyService:GetPolicyInfoForPlayerAsync(player: any)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("Instance was not a player", 2)
	end
	local userId = player.UserId
	table.insert(self.calls, userId)
	if self._wait then
		self._wait(0) -- an async web call: yields at least one frame
	end
	if self._failFor[userId] then
		error(self._failFor[userId], 2)
	end
	if self._failNext > 0 then
		self._failNext -= 1
		error(self._failMessage, 2)
	end
	local policy = table.clone(self._default)
	for key, value in self._byUser[userId] or {} do
		policy[key] = value
	end
	policy.AllowedExternalLinkReferences = table.clone(policy.AllowedExternalLinkReferences)
	return policy
end

function MockPolicyService:setPolicy(userId: number, overrides: { [string]: any })
	self._byUser[userId] = table.clone(overrides)
end

function MockPolicyService:setDefault(overrides: { [string]: any })
	for key, value in overrides do
		self._default[key] = value
	end
end

function MockPolicyService:failNext(count: number?, message: string?)
	self._failNext = count or 1
	self._failMessage = message or DEFAULT_FAILURE
end

function MockPolicyService:failFor(userId: number, message: string?)
	self._failFor[userId] = message or DEFAULT_FAILURE
end

function MockPolicyService:clearFailures()
	self._failNext = 0
	table.clear(self._failFor)
end

return MockPolicyService
