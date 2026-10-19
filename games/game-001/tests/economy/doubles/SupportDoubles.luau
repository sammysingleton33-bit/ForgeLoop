--[[
	SupportDoubles — a stand-in for FORGE-01's SupportService (FL-0071) and the CONTRACTS G12.4 support remotes, for
	the FL-0073 support meter specs and snapshot scenes. The numbers are the real ones: the SupportView is built with
	FORGE-01's Arena/SupportModel (score, tierOf, trend, offers) from fixture samples, and moments come from config
	Support.acts. Only the sampling is faked (a fixed component set every 30 s back to the match start).
	Plugs into doubles/KingdomWorld through its options:

		local Sup = require("./doubles/SupportDoubles")
		local world = KingdomWorld.new({
			remotes = Sup.REMOTES,                -- appended to the Kingdom area (do not combine with ArenaDoubles.REMOTES,
			                                      -- which declares the same two remotes for the arena specs)
			services = { Sup.service({ components = { happiness = 80 }, acts = { "fedRatioKept" } }) },
			clientDefinitions = { KingdomHudDef, SupportMeterDef },
		})
		local sup = world.server:get("SupportService")
		sup:act("starvation")          -- the local player; moves the component, adds the moment, pushes Kingdom.Support
		sup:set({ morale = 20 })       -- new components from now on; pushes too
		world:advance(0.1)

	Declarations (G12.4): Kingdom.Support serverEvent to the ruler; Kingdom.GetSupport function, no arguments.
	GetSupport answers nil for a player without a kingdom.

	Options of service(opts): components ({ [component]: 0..100 }, default 50 each), matchSeconds (how far back the
	samples go, default 1200), acts ({ actId } done in order before the start, the oldest first, one minute apart),
	earlier ({ [component]: 0..100 }: the samples older than
	Support.trendSeconds, for a trend), keyCitizens ({ KeyCitizen }, for the offers), samples (false: send no breakdown — an empty match).
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local SupportDoubles = {}

SupportDoubles.REMOTES = {
	Kingdom = {
		{ name = "Kingdom.Support", kind = "serverEvent" },
		{ name = "Kingdom.GetSupport", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	},
}

SupportDoubles.INTERVAL = 30

SupportDoubles.KEY_CITIZENS = {
	{ role = "blacksmith", citizenId = 101, name = "Bram", loyalty = 86, alive = true },
	{ role = "healer", citizenId = 102, name = "Elsa", loyalty = 97, alive = true },
	{ role = "captain", citizenId = 103, name = "Osric", loyalty = 62, alive = true },
}

function SupportDoubles.service(opts: { [string]: any }?)
	local o = opts or {}
	return function(world)
		return {
			name = "SupportService",
			dependencies = { "RemoteService", "KingdomService" },
			new = function(_, registry)
				local remotes = registry:get("RemoteService")
				local kingdoms = registry:get("KingdomService")
				local env = world.env
				local svc = { rulers = {}, pushes = 0 }

				local function components(over: { [string]: number }?)
					local c = {}
					for _, id in Support.componentOrder do
						c[id] = 50
					end
					for id, v in over or {} do
						c[id] = v
					end
					return c
				end

				local function record(userId: number)
					local r = svc.rulers[userId]
					if r == nil then
						local now = env.serverTimeNow()
						local current = components(o.components)
						local samples = {}
						if o.samples ~= false then
							local span = o.matchSeconds or 1200
							local earlier = if o.earlier then components(o.earlier) else current
							for t = now - span, now, SupportDoubles.INTERVAL do
								local old = t <= now - Support.trendSeconds
								table.insert(
									samples,
									{ t = t, components = table.clone(if old then earlier else current) }
								)
							end
						end
						r = { samples = samples, current = current, moments = {} }
						svc.rulers[userId] = r
						local acts = o.acts or {}
						for i, id in acts do
							local act = Support.acts[id]
							if act then
								table.insert(r.moments, {
									t = now - (#acts - i + 1) * 60,
									kingdom = "",
									userId = userId,
									act = id,
									component = act.component,
									delta = act.delta,
									text = act.text,
								})
							end
						end
					end
					return r
				end

				function svc:view(player)
					local kingdomId = kingdoms:getKingdomOf(player)
					if kingdomId == nil then
						return nil
					end
					local r = record(player.UserId)
					local ruler = { now = env.serverTimeNow() }
					local score, tier, breakdown = SupportModel.score(r.samples, ruler)
					local offers, slots = SupportModel.offers(o.keyCitizens or SupportDoubles.KEY_CITIZENS, tier)
					local moments = {}
					for _, m in r.moments do
						local copy = table.clone(m)
						copy.kingdom = kingdomId
						table.insert(moments, copy)
					end
					return {
						kingdom = kingdomId,
						userId = player.UserId,
						score = score,
						tier = tier,
						trend = SupportModel.trend(r.samples, ruler),
						breakdown = if #r.samples > 0 then breakdown else {},
						moments = moments,
						offers = offers,
						slots = slots,
					}
				end

				function svc:push(player)
					local view = self:view(player)
					if view then
						self.pushes += 1
						remotes:fire("Kingdom.Support", player, view)
					end
				end

				-- New components from now on (a fresh sample now).
				function svc:set(values: { [string]: number }, player: any?)
					local p = player or world.player
					local r = record(p.UserId)
					for id, v in values do
						r.current[id] = math.clamp(v, 0, 100)
					end
					table.insert(r.samples, { t = env.serverTimeNow(), components = table.clone(r.current) })
					self:push(p)
				end

				-- A leadership act (config Support.acts): moves its component by the act's delta and records the moment.
				function svc:act(id: string, player: any?)
					local p = player or world.player
					local act = assert(Support.acts[id], "unknown act " .. tostring(id))
					local r = record(p.UserId)
					table.insert(r.moments, {
						t = env.serverTimeNow(),
						kingdom = "",
						userId = p.UserId,
						act = id,
						component = act.component,
						delta = act.delta,
						text = act.text,
					})
					self:set({ [act.component] = r.current[act.component] + act.delta }, p)
				end

				function svc:start()
					remotes:handle("Kingdom.GetSupport", function(player)
						return self:view(player)
					end)
				end
				return svc
			end,
		}
	end
end

return SupportDoubles
