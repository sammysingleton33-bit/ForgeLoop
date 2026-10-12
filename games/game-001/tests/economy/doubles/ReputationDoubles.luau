--[[
	ReputationDoubles — a stand-in for FORGE-01's ReputationService and the CONTRACTS G13.4 remotes,
	for the FL-0089 specs and the snapshot scenes. Plugs into doubles/KingdomWorld through its options:

		local Rep = require("./doubles/ReputationDoubles")
		local world = KingdomWorld.new({
			remotes = Rep.REMOTES,                      -- appended to the Kingdom area
			services = { Rep.service({ values = { fear = 80 }, history = { ... }, kingdom = { ... } }) },
			clientDefinitions = { KingdomHudDef, ReputationDef },
		})
		local rep = world.server:get("ReputationService")
		rep:apply("compassion", 4, "You fed the farmers.")   -- the local player; pushes Kingdom.Reputation
		rep:setCondition("stability", 30)                     -- my kingdom's condition; pushes too
		world:advance(0.1)

	Declarations (G13.4, kinds and rates as FL-0089 assumes them — the handoff asks FORGE-01 to confirm):
		Kingdom.Reputation     serverEvent, to the ruler
		Kingdom.GetReputation  function, no arguments, burst 5 / 2 per s
	Payload of both (assumed identical): { values: { [Category]: number }, history: { { t, category,
	delta, text, source } } (latest 30, in the order they happened: oldest first — the client must
	sort), kingdom: { happiness, stability, morale } }. `t` = env.serverTimeNow() seconds.
	GetReputation answers nil for a player without a kingdom.

	Options of service(opts): values ({ [Category]: number }, merged over 50 each and fear 0),
	history ({ { ago: seconds, category, delta, text, source? } }, oldest first), kingdom
	({ happiness, stability, morale }, default 50 each).
	Not the game's rules: no anti-farming, no decay, no trait weighting — those are FORGE-01's (FL-0080).
]]

local ReputationDoubles = {}

ReputationDoubles.IDS = { "compassion", "honor", "competence", "courage", "authority", "fear" }

ReputationDoubles.REMOTES = {
	Kingdom = {
		{ name = "Kingdom.Reputation", kind = "serverEvent" },
		{ name = "Kingdom.GetReputation", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	},
}

ReputationDoubles.HISTORY_LIMIT = 30

function ReputationDoubles.service(opts: { [string]: any }?)
	local o = opts or {}
	return function(world)
		return {
			name = "ReputationService",
			dependencies = { "RemoteService", "KingdomService" },
			new = function(_, registry)
				local remotes = registry:get("RemoteService")
				local kingdoms = registry:get("KingdomService")
				local env = world.env
				local svc = { rulers = {}, conditions = {}, pushes = 0 }

				local function record(userId: number)
					local r = svc.rulers[userId]
					if r == nil then
						local values = {}
						for _, id in ReputationDoubles.IDS do
							values[id] = if id == "fear" then 0 else 50
						end
						for id, v in o.values or {} do
							values[id] = v
						end
						local history = {}
						for _, e in o.history or {} do
							table.insert(history, {
								t = env.serverTimeNow() - (e.ago or 0),
								category = e.category,
								delta = e.delta,
								text = e.text,
								source = e.source or "decision",
							})
						end
						r = { values = values, history = history }
						svc.rulers[userId] = r
					end
					return r
				end

				local function conditionsOf(kingdomId: string)
					local c = svc.conditions[kingdomId]
					if c == nil then
						local k = o.kingdom or {}
						c = { happiness = k.happiness or 50, stability = k.stability or 50, morale = k.morale or 50 }
						svc.conditions[kingdomId] = c
					end
					return c
				end

				function svc:payload(player)
					local kingdomId = kingdoms:getKingdomOf(player)
					if kingdomId == nil then
						return nil
					end
					local r = record(player.UserId)
					local history = {}
					local first = math.max(1, #r.history - ReputationDoubles.HISTORY_LIMIT + 1)
					for i = first, #r.history do
						table.insert(history, table.clone(r.history[i]))
					end
					return {
						values = table.clone(r.values),
						history = history,
						kingdom = table.clone(conditionsOf(kingdomId)),
					}
				end

				function svc:push(player)
					local payload = self:payload(player)
					if payload then
						self.pushes += 1
						remotes:fire("Kingdom.Reputation", player, payload)
					end
				end

				-- The local player's reputation changes (G13.4 apply, without FORGE-01's rules).
				function svc:apply(category: string, delta: number, text: string, player: any?)
					local p = player or world.player
					local r = record(p.UserId)
					r.values[category] = math.clamp(r.values[category] + delta, 0, 100)
					table.insert(r.history, {
						t = env.serverTimeNow(),
						category = category,
						delta = delta,
						text = text,
						source = "decision",
					})
					self:push(p)
				end

				function svc:setCondition(id: string, value: number, player: any?)
					local p = player or world.player
					local kingdomId = kingdoms:getKingdomOf(p)
					if kingdomId then
						conditionsOf(kingdomId)[id] = value
						self:push(p)
					end
				end

				function svc:start()
					remotes:handle("Kingdom.GetReputation", function(player)
						return self:payload(player)
					end)
				end
				return svc
			end,
		}
	end
end

-- Sample category texts standing in for Content/Reputation.categories (FL-0083) in specs and scenes.
-- Not game content: the real text is FORGE-00's, edited by the user in the content library.
ReputationDoubles.SAMPLE_TEXT = {
	compassion = {
		description = "SAMPLE: How kindly your people think you treat them.",
		affects = "SAMPLE: Feeding the hungry and helping families raise it; harsh punishments lower it.",
	},
	honor = {
		description = "SAMPLE: Whether your word can be trusted.",
		affects = "SAMPLE: Keeping promises and truces raises it; breaking them lowers it.",
	},
	competence = {
		description = "SAMPLE: How well your kingdom is run.",
		affects = "SAMPLE: Buildings that meet a real need and full storehouses.",
	},
	courage = {
		description = "SAMPLE: Whether you stand and fight for your people.",
		affects = "SAMPLE: Defending your lands and leading attacks.",
	},
	authority = {
		description = "SAMPLE: How firmly your orders are followed.",
		affects = "SAMPLE: Settling disputes, enforcing laws, winning battles.",
	},
	fear = {
		description = "SAMPLE: How much your people dread your anger.",
		affects = "SAMPLE: Punishments, threats and atrocities. A lost battle makes it fall.",
	},
}

function ReputationDoubles.provider(id: string)
	return ReputationDoubles.SAMPLE_TEXT[id]
end

return ReputationDoubles
