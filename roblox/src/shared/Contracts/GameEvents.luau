--!strict
--[[
	Contracts/GameEvents — the server event bus (docs/architecture/interfaces.md §4, contract v0.3).

	One Signal per event; the module is the bus, so every server script that requires it (relative
	or "@game/...") shares the same signals. Payloads are server-only: clients learn through remotes.

		GameEvents.PlayerReady:connect(function(player) ... end)
		GameEvents.RoundEnded:fire(result)

	| Event              | Producer                       | Payload |
	| PlayerReady        | FORGE-01 PlayerService         | (player) — profile loaded, character may not exist yet |
	| RoundStateChanged  | FORGE-01 RoundService          | (state: RoundState, info: { roundId: string, endsAt: number? }) |
	| PlayerEliminated   | FORGE-01                       | (player, info: { roundId: string, cause: string, by: Player? }) |
	| RoundEnded         | FORGE-01                       | (result: RoundResult) |
	| CurrencyChanged    | FORGE-03 EconomyService        | (player, currency: string, newBalance: number, delta: number, reason: string) |
	| ItemGranted        | FORGE-03 InventoryService      | (player, itemId: string, qty: number, source: string) |
	| PurchaseCompleted  | FORGE-03 PurchaseService       | (player, kind: "product" | "pass", id: number, robux: number?) |
	| RewardRolled       | FORGE-03 RewardService         | (player, tableId: string, result: RewardResult) |
	| OnboardingStep     | FORGE-04 OnboardingService     | (player, flow: string, step: number, stepName: string) |
	| ShopViewed         | FORGE-03 ShopService           | (player, shopId: string, itemId: string?) — one per shop open |
	Payload types (interfaces §4) are exported here too: GameEvents.RoundState, GameEvents.RoundResult,
	GameEvents.RewardResult (defined once in Contracts/Types, re-exported).

	EXACTLY-ONCE RULE: a producer fires its event exactly once per successful action — never on an
	idempotent replay (same txId / PurchaseId), never for a failed grant, never for a partial grant.
	Consumers (quests, analytics, onboarding) may therefore count events without de-duplicating.

	Guard rails: reading an undeclared event (a typo) or assigning a new field errors. New events
	are added by appending to EVENT_NAMES and the table above (additive contract change).

	Extra API
		GameEvents.EVENT_NAMES: { string }   -- declared events, in table order
		GameEvents.disconnectAll()           -- tests: drop every connection on every event
]]

local Signal = require("../Core/Signal")
local Types = require("./Types")

type SignalT = Signal.Signal

export type RoundState = Types.RoundState
export type RoundResult = Types.RoundResult
export type RewardResult = Types.RewardResult

export type GameEvents = {
	PlayerReady: SignalT,
	RoundStateChanged: SignalT,
	PlayerEliminated: SignalT,
	RoundEnded: SignalT,
	CurrencyChanged: SignalT,
	ItemGranted: SignalT,
	PurchaseCompleted: SignalT,
	RewardRolled: SignalT,
	OnboardingStep: SignalT,
	ShopViewed: SignalT,
	EVENT_NAMES: { string },
	disconnectAll: () -> (),
}

local EVENT_NAMES = table.freeze({
	"PlayerReady",
	"RoundStateChanged",
	"PlayerEliminated",
	"RoundEnded",
	"CurrencyChanged",
	"ItemGranted",
	"PurchaseCompleted",
	"RewardRolled",
	"OnboardingStep",
	"ShopViewed",
})

local events: { [string]: any } = {}
for _, name in EVENT_NAMES do
	events[name] = Signal.new()
end
events.EVENT_NAMES = EVENT_NAMES
events.disconnectAll = function()
	for _, name in EVENT_NAMES do
		events[name]:disconnectAll()
	end
end

local guarded = setmetatable({}, {
	__index = function(_, key)
		local value = events[key]
		if value == nil then
			error(`GameEvents.{tostring(key)} is not a declared event (interfaces §4)`, 2)
		end
		return value
	end,
	__newindex = function(_, key)
		error(`GameEvents is read-only; declare new events in Contracts/GameEvents.luau (tried '{tostring(key)}')`, 2)
	end,
	__iter = function()
		return next, events
	end,
})

return (guarded :: any) :: GameEvents
