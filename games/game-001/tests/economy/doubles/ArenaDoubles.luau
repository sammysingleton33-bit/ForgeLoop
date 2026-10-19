--[[
	ArenaDoubles — the Crown Arena's server side for FL-0073's UI specs and scenes, as CONTRACTS G12.4 describes it
	(FORGE-01 builds the real ArenaService / SupportService in FL-0070 / FL-0071; #208 holds the shapes in
	src/shared/Arena/Types). The support numbers here are a STUB until FL-0070 lands (FORGE-00, 2026-10-19).

		ArenaDoubles.REMOTES      { Arena = { State, GetState, Choose, Events }, Kingdom = { Support, GetSupport } }
		ArenaDoubles.service      (world) -> server Def "ArenaDouble":
			svc.state                    the ArenaState GetState answers
			svc.getStateCalls            how many Arena.GetState requests reached the server
			svc:setState(state)          stores it and fires Arena.State to everyone
			svc:events(batch)            fires Arena.Events { { t, kind, side, data? } } to everyone
			svc.support[userId]          the SupportView Kingdom.GetSupport answers that player
			svc:sendSupport(player)      fires Kingdom.Support to that player
			svc.choices                  { { userId, weapon, armour, triggers } } every accepted Arena.Choose
			Arena.Choose(weapon, armour, triggers) answers like G12.4: (false, "stage") outside "loadout",
			(false, "not_champion"), (false, "not_offered"), (false, "too_many"), else (true) and the
			duellist's weapon / armour / triggers change
		ArenaDoubles.support(tier, userId, kingdom) -> a stub SupportView (offers from the design §4 table)
		ArenaDoubles.duellist(userId, kingdom, tier, extra?) -> a Duellist
		ArenaDoubles.REASONS      three pre-authored moment texts
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local ArenaDoubles = {}

local TRIGGERS =
	{ "reforge", "fieldRemedy", "calledWarning", "heartyRations", "rallyingHymn", "fineWares", "crowdRally" }

-- G12.4 argument shapes: (weapon: enum Weapon, armour: enum Armour, triggers: array(enum TriggerId, 3))
ArenaDoubles.REMOTES = {
	Arena = {
		{ name = "Arena.State", kind = "serverEvent" },
		{ name = "Arena.GetState", kind = "function" },
		{
			name = "Arena.Choose",
			kind = "function",
			args = {
				Validate.enum({ "swordShield", "greatsword", "spear", "mace" }),
				Validate.enum({ "light", "medium", "heavy" }),
				Validate.array(Validate.enum(TRIGGERS), 3),
			},
		},
		{ name = "Arena.Events", kind = "serverEvent" },
	},
	Kingdom = {
		{ name = "Kingdom.Support", kind = "serverEvent" },
		{ name = "Kingdom.GetSupport", kind = "function" },
	},
}

ArenaDoubles.REASONS = {
	"Kept the granary full through the Conflict",
	"Defended the mill at 22:14",
	"Fulfilled Bram's petition for stone",
}

local SLOTS = { adoring = 3, loyal = 3, divided = 2, restless = 1, hostile = 0 }
local SCORE = { adoring = 91, loyal = 72, divided = 52, restless = 31, hostile = 12 }

-- The design §4 offers, stub loyalty numbers.
local OFFERS = {
	{
		trigger = "reforge",
		citizenId = 101,
		citizenName = "Bram",
		role = "blacksmith",
		loyalty = 88,
		power = "pledged",
		condition = "Your HP first drops below 50%",
		effect = "Damage reduction +6% for 6 s",
	},
	{
		trigger = "fieldRemedy",
		citizenId = 102,
		citizenName = "Mira",
		role = "healer",
		loyalty = 96,
		power = "empowered",
		condition = "Your HP first drops below 35%",
		effect = "Regain 5% of your HP over 4 s",
	},
	{
		trigger = "heartyRations",
		citizenId = 103,
		citizenName = "Tom",
		role = "provisioner",
		loyalty = 82,
		power = "pledged",
		condition = "Your stamina first runs out",
		effect = "Stamina regeneration +6% for 8 s",
	},
	{
		trigger = "calledWarning",
		citizenId = 104,
		citizenName = "Hale",
		role = "captain",
		loyalty = 84,
		power = "pledged",
		condition = "Your opponent's first two heavy attacks",
		effect = "Their heavy attack shows 0.15 s earlier",
	},
}

local RALLY = {
	trigger = "crowdRally",
	power = "pledged",
	condition = "Your HP first drops below 20%",
	effect = "Damage reduction +5%, stamina regeneration +10% for 5 s",
}

function ArenaDoubles.support(tier, userId, kingdom)
	local offers = {}
	local slots = SLOTS[tier] or 0
	if slots > 0 then
		for i, o in OFFERS do
			if tier == "adoring" or i <= slots + 1 then
				table.insert(offers, table.clone(o))
			end
		end
		if tier == "adoring" then
			table.insert(offers, table.clone(RALLY))
		end
	end
	return {
		kingdom = kingdom or "crimson",
		userId = userId or 1,
		score = SCORE[tier] or 50,
		tier = tier,
		trend = 1,
		breakdown = {},
		moments = {},
		offers = offers,
		slots = slots,
	}
end

function ArenaDoubles.duellist(userId, kingdom, tier, extra)
	local d = {
		userId = userId,
		kingdom = kingdom,
		isAI = false,
		tier = tier,
		score = SCORE[tier] or 50,
		weapon = nil,
		armour = nil,
		triggers = {},
		reasons = table.clone(ArenaDoubles.REASONS),
	}
	for k, v in extra or {} do
		d[k] = v
	end
	return d
end

function ArenaDoubles.service(_world)
	return {
		name = "ArenaDouble",
		dependencies = { "RemoteService" },
		new = function(_env, registry)
			local remotes = registry:get("RemoteService")
			local svc = { state = { stage = "qualify" }, support = {}, choices = {}, getStateCalls = 0 }
			function svc:setState(state)
				self.state = state
				remotes:fireAll("Arena.State", state)
			end
			function svc:events(batch)
				remotes:fireAll("Arena.Events", batch)
			end
			function svc:sendSupport(player)
				remotes:fire("Kingdom.Support", player, self.support[player.UserId])
			end
			function svc:start()
				remotes:handle("Arena.GetState", function()
					self.getStateCalls += 1
					return self.state
				end)
				remotes:handle("Kingdom.GetSupport", function(player)
					return self.support[player.UserId]
				end)
				remotes:handle("Arena.Choose", function(player, weapon, armour, triggers)
					local st = self.state
					if st.stage ~= "loadout" then
						return false, "stage"
					end
					local side = nil
					for _, id in { "a", "b" } do
						if st[id] and st[id].userId == player.UserId then
							side = id
						end
					end
					if side == nil then
						return false, "not_champion"
					end
					local view = self.support[player.UserId] or { offers = {}, slots = 0 }
					if #triggers > view.slots then
						return false, "too_many"
					end
					for _, t in triggers do
						local found = false
						for _, o in view.offers do
							if o.trigger == t then
								found = true
							end
						end
						if not found then
							return false, "not_offered"
						end
					end
					st[side].weapon = weapon
					st[side].armour = armour
					st[side].triggers = table.clone(triggers)
					table.insert(
						self.choices,
						{ userId = player.UserId, weapon = weapon, armour = armour, triggers = table.clone(triggers) }
					)
					return true
				end)
			end
			return svc
		end,
	}
end

return ArenaDoubles
