--[[
	Test doubles of the kingdom API FORGE-03 proposes to FORGE-01
	(production/handoffs/2026-10-12-forge-03-to-forge-01-kingdom-api.md). They implement the
	proposal faithfully enough to drive the real economy and UI end to end, and FORGE-01 may use
	them as a starting point. Nothing here ships in the place.

	RemoteDecl — the proposed Gameplay remote declarations (FORGE-01 owns the real ones):
		Gameplay.KingdomState     serverEvent  (snapshot: KingdomSnapshot)
		Gameplay.GetKingdomState  function     () -> KingdomSnapshot?
		Gameplay.Build            function     (buildingId: string(1,32), plotId: string(1,32)?) -> (ok, reason?, uid?)
		Gameplay.Upgrade          function     (uid: string(1,32)) -> (ok, reason?)
		Gameplay.AssignWorkers    function     (uid: string(1,32), count: integer(0,50)) -> (ok, reason?)
		Gameplay.RoundState / GetRoundState    as interfaces §4 v0.3 (fired by specs directly)

	serviceDefinition() — Loader definition "KingdomService" (server):
		:createKingdom(player, { name: string?, tincture: string? }?) -> kingdomId
		:kingdomOf(player) -> kingdomId?        :snapshot(kingdomId) -> KingdomSnapshot
		:build(player, buildingId, plotId?) -> (ok, reason?, uid?)
		:upgrade(player, uid) -> (ok, reason?)  :assignWorkers(player, uid, count) -> (ok, reason?)
		:step()  completes constructions, grows citizens, pays production (every PRODUCTION_SEC)
		start() runs step() every second on env time.
		Spending: Construction:check, then EconomyTreasuryService:spend(kingdomId, cost,
		"build:<kingdomId>:<n>", "build:<buildingId>") — never trusts the client.
		Production: Construction:production per minute, paid every 10 s via
		EconomyTreasuryService:grant(kingdomId, bundle, "prod:<kingdomId>:<tick>", "production").

	controllerDefinition() — Loader definition "KingdomController" (client):
		.state: KingdomSnapshot?   .changed: Signal (state)
		:build(buildingId, plotId?) / :upgrade(uid) / :assignWorkers(uid, count) -> (ok, reason?, uid?)

	KingdomSnapshot = { kingdomId, name, ownerUserId, tincture, version, hall,
		territory = { tiles }, rank, kingdoms,
		citizens = { total, housing, idle, working, building },
		builders = { busy, total },
		buildings = { { uid, buildingId, level, state, workers, startedAt?, completesAt? } } }
		Times are server time (workspace:GetServerTimeNow / env.serverTimeNow).
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Construction = require("@game/ReplicatedStorage/Forge/Economy/Construction")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local RemoteDoubles = require("./RemoteDoubles")

local V = RemoteDoubles.Validate

local KingdomDoubles = {}

KingdomDoubles.PRODUCTION_SEC = 10
KingdomDoubles.CITIZEN_SEC = 8
KingdomDoubles.START_CITIZENS = 6
KingdomDoubles.BUILDERS = 2

KingdomDoubles.RemoteDecl = {
	{ name = "Gameplay.KingdomState", kind = "serverEvent" },
	{ name = "Gameplay.GetKingdomState", kind = "function", args = {} },
	{ name = "Gameplay.Build", kind = "function", args = { V.string(1, 32), V.optional(V.string(1, 32)) } },
	{ name = "Gameplay.Upgrade", kind = "function", args = { V.string(1, 32) } },
	{ name = "Gameplay.AssignWorkers", kind = "function", args = { V.string(1, 32), V.integer(0, 50) } },
	{ name = "Gameplay.RoundState", kind = "serverEvent" },
	{ name = "Gameplay.GetRoundState", kind = "function", args = {} },
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

function KingdomDoubles.serviceDefinition()
	return {
		name = "KingdomService",
		dependencies = { "EconomyTreasuryService", "RemoteService" },
		new = function(env, registry)
			local service = {
				_env = env,
				_treasury = registry:get("EconomyTreasuryService"),
				_remotes = registry:get("RemoteService"),
				_catalog = Construction.default(),
				_kingdoms = {},
				_byUser = {},
				_seq = 0,
				_running = false,
			}

			local function view(k)
				return { buildings = k.buildings, builders = k.builders }
			end

			local function refreshCitizens(k)
				local working = 0
				for _, b in k.buildings do
					working += b.workers or 0
				end
				k.citizens.housing = service._catalog:housing(view(k))
				k.citizens.working = working
				k.citizens.building = k.builders.busy
				k.citizens.idle = math.max(0, k.citizens.total - working - k.builders.busy)
			end

			function service:snapshot(kingdomId)
				local k = assert(service._kingdoms[kingdomId], `unknown kingdom {kingdomId}`)
				refreshCitizens(k)
				local snap = deepCopy(k)
				snap._members = nil
				snap._nextTx = nil
				snap._prodTick = nil
				snap._fraction = nil
				snap._citizenAt = nil
				snap._lastTickAt = nil
				snap._uidSeq = nil
				return snap
			end

			function service:_publish(k)
				k.version += 1
				local snap = service:snapshot(k.kingdomId)
				for _, player in k._members do
					service._remotes:fire("Gameplay.KingdomState", player, snap)
				end
			end

			function service:createKingdom(player, opts)
				opts = opts or {}
				service._seq += 1
				local id = `k{service._seq}`
				local now = env.serverTimeNow()
				local k = {
					kingdomId = id,
					name = opts.name or "Aldmere",
					ownerUserId = player.UserId,
					tincture = opts.tincture or "azure",
					version = 0,
					hall = 1,
					territory = { tiles = opts.tiles or 6 },
					rank = opts.rank or 1,
					kingdoms = opts.kingdoms or 1,
					citizens = {
						total = opts.citizens or KingdomDoubles.START_CITIZENS,
						housing = 0,
						idle = 0,
						working = 0,
						building = 0,
					},
					builders = { busy = 0, total = KingdomDoubles.BUILDERS },
					buildings = {},
					_members = { player },
					_nextTx = 1,
					_prodTick = 0,
					_fraction = {},
					_citizenAt = now,
					_lastTickAt = now,
					_uidSeq = 0,
				}
				for _, def in service._catalog:buildings() do
					if def.building.prebuilt then
						k._uidSeq += 1
						table.insert(
							k.buildings,
							{ uid = `u{k._uidSeq}`, buildingId = def.id, level = 1, state = "ready", workers = 0 }
						)
					end
				end
				service._kingdoms[id] = k
				service._byUser[player.UserId] = id
				service._treasury:open(
					id,
					{ members = { player }, start = opts.start, caps = service._catalog:storageCaps(view(k)) }
				)
				service:_publish(k)
				return id
			end

			function service:kingdomOf(player)
				return service._byUser[player.UserId]
			end

			local function own(player)
				local id = service._byUser[player.UserId]
				return id and service._kingdoms[id]
			end

			local function startWork(k, check, instance)
				local txId = `build:{k.kingdomId}:{k._nextTx}`
				k._nextTx += 1
				local ok, reason = service._treasury:spend(k.kingdomId, check.cost, txId, `build:{check.buildingId}`)
				if not ok then
					return false, reason
				end
				local now = env.serverTimeNow()
				instance.startedAt = now
				instance.completesAt = now + check.buildSec
				k.builders.busy += 1
				service:_publish(k)
				return true
			end

			function service:build(player, buildingId, _plotId)
				local k = own(player)
				if not k then
					return false, "no_kingdom"
				end
				local check = service._catalog:check(view(k), service._treasury:balances(k.kingdomId), buildingId)
				if not check.ok then
					return false, check.reason
				end
				k._uidSeq += 1
				local instance =
					{ uid = `u{k._uidSeq}`, buildingId = buildingId, level = 0, state = "constructing", workers = 0 }
				table.insert(k.buildings, instance)
				local ok, reason = startWork(k, check, instance)
				if not ok then
					table.remove(k.buildings, table.find(k.buildings, instance))
					return false, reason
				end
				return true, nil, instance.uid
			end

			function service:upgrade(player, uid)
				local k = own(player)
				if not k then
					return false, "no_kingdom"
				end
				local instance
				for _, b in k.buildings do
					if b.uid == uid then
						instance = b
					end
				end
				if not instance then
					return false, "not_found"
				end
				local check =
					service._catalog:check(view(k), service._treasury:balances(k.kingdomId), instance.buildingId, uid)
				if not check.ok then
					return false, check.reason
				end
				instance.state = "upgrading"
				return startWork(k, check, instance)
			end

			function service:assignWorkers(player, uid, count)
				local k = own(player)
				if not k then
					return false, "no_kingdom"
				end
				refreshCitizens(k)
				for _, b in k.buildings do
					if b.uid == uid then
						local lv = b.level >= 1 and service._catalog:level(b.buildingId, b.level)
						local slots = lv and lv.workers or 0
						if slots == 0 or b.state == "constructing" then
							return false, "no_slots"
						end
						local available = k.citizens.idle + (b.workers or 0)
						local target = math.clamp(count, 0, slots)
						if target > available then
							return false, "no_idle"
						end
						b.workers = target
						service:_publish(k)
						return true
					end
				end
				return false, "not_found"
			end

			function service:step()
				local now = env.serverTimeNow()
				for _, k in service._kingdoms do
					local changed = false
					local capsBefore = service._catalog:storageCaps(view(k))
					for _, b in k.buildings do
						if b.state ~= "ready" and b.completesAt and b.completesAt <= now then
							b.level += 1
							b.state = "ready"
							b.startedAt, b.completesAt = nil, nil
							k.builders.busy -= 1
							if b.buildingId == "townhall" then
								k.hall = b.level
							end
							changed = true
						end
					end
					local caps = service._catalog:storageCaps(view(k))
					if not Bundle.equals(caps, capsBefore) then
						service._treasury:setCaps(k.kingdomId, caps)
					end
					refreshCitizens(k)
					if k.citizens.total < k.citizens.housing and now - k._citizenAt >= KingdomDoubles.CITIZEN_SEC then
						k.citizens.total += 1
						k._citizenAt = now
						changed = true
					elseif k.citizens.total >= k.citizens.housing then
						k._citizenAt = now
					end
					if now - k._lastTickAt >= KingdomDoubles.PRODUCTION_SEC then
						k._lastTickAt = now
						k._prodTick += 1
						local perMinute = service._catalog:production(view(k))
						local pay = {}
						for currency, rate in perMinute do
							local exact = rate * KingdomDoubles.PRODUCTION_SEC / 60 + (k._fraction[currency] or 0)
							local whole = math.floor(exact)
							k._fraction[currency] = exact - whole
							if whole > 0 then
								pay[currency] = whole
							end
						end
						if next(pay) then
							service._treasury:grant(k.kingdomId, pay, `prod:{k.kingdomId}:{k._prodTick}`, "production")
						end
					end
					if changed then
						service:_publish(k)
					end
				end
			end

			function service:start()
				service._remotes:handle("Gameplay.GetKingdomState", function(player)
					local id = service._byUser[player.UserId]
					return id and service:snapshot(id) or nil
				end)
				service._remotes:handle("Gameplay.Build", function(player, buildingId, plotId)
					return service:build(player, buildingId, plotId)
				end)
				service._remotes:handle("Gameplay.Upgrade", function(player, uid)
					return service:upgrade(player, uid)
				end)
				service._remotes:handle("Gameplay.AssignWorkers", function(player, uid, count)
					return service:assignWorkers(player, uid, count)
				end)
				service._running = true
				env.spawn(function()
					while service._running do
						env.wait(1)
						if service._running then
							service:step()
						end
					end
				end)
			end

			function service:destroy()
				service._running = false
			end

			return service
		end,
	}
end

function KingdomDoubles.controllerDefinition()
	return {
		name = "KingdomController",
		dependencies = {},
		new = function(env)
			local controller = { state = nil, changed = Signal.new(), _rc = nil }
			local function accept(snapshot)
				if snapshot and (controller.state == nil or snapshot.version > controller.state.version) then
					controller.state = snapshot
					controller.changed:fire(snapshot)
				end
			end
			function controller:start()
				controller._rc = env.sharedModules("RemoteClient").Core
				controller._rc.on("Gameplay.KingdomState", accept)
				env.spawn(function()
					accept(controller._rc.invoke("Gameplay.GetKingdomState"))
				end)
			end
			function controller:build(buildingId, plotId)
				return controller._rc.invoke("Gameplay.Build", buildingId, plotId)
			end
			function controller:upgrade(uid)
				return controller._rc.invoke("Gameplay.Upgrade", uid)
			end
			function controller:assignWorkers(uid, count)
				return controller._rc.invoke("Gameplay.AssignWorkers", uid, count)
			end
			function controller:destroy()
				controller.changed:disconnectAll()
			end
			return controller
		end,
	}
end

return KingdomDoubles
