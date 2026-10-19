--!strict
--[[
	UI/LoadoutModel — the loadout and perk picker before the duel (FL-0073; design crown-arena.md §3-§5, CONTRACTS
	G12.1 ArenaState / SupportView / TriggerOffer, G12.4 Arena.Choose). Pure; no instances. UI/LoadoutPicker draws it.

		LoadoutModel.side(arena, userId) -> "a" | "b" | nil       which duellist the local player is
		LoadoutModel.choice(duellist?, support?) -> Choice        the starting choice: the duellist's weapon, armour and
		                         triggers when the server has them (else the defaults and the first offers up to the slots)
		                         (so a timeout still takes perks; the player changes them)
		LoadoutModel.toggle(choice, trigger, support) -> Choice   a perk in or out; a full set refuses a new one
		LoadoutModel.view(arena, support, userId, choice, now, sent?) -> View?   nil unless the stage is "loadout"
		                         and the local player is a champion
		Choice = { weapon: Weapon, armour: Armour, triggers: { TriggerId } }
		View = { side, clock, secondsLeft, urgent, tier { id, name, color }, slots, slotsText, chosen,
		         weapons / armour: { { id, name, short, icon, blurb, shortBlurb?, selected } },
		         offers: { { trigger, name, icon, citizen?, loyalty?, power?, effect, condition, selected, locked,
		                     crowd } },
		         noOffers: string?, confirm { label, enabled }, sent, status? }
		LoadoutModel.args(choice) -> (weapon, armour, triggers)   what Arena.Choose takes

	Slots are the server's (SupportView.slots: the lower of the tier's slots and the pledged key citizens, design §3);
	the picker never lets the player hold more, and the server checks again (Arena.Choose: triggers ⊆ own offers and
	≤ slots). Support numbers come from Kingdom.GetSupport; until FORGE-01's FL-0070 lands they are stubbed in the
	doubles only (tests/economy/doubles/ArenaDoubles).
]]

local ArenaText = require("./ArenaText")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local LoadoutModel = {}

LoadoutModel.URGENT_SEC = 5

function LoadoutModel.side(arena: any, userId: number?): string?
	if type(arena) ~= "table" or userId == nil then
		return nil
	end
	for _, id in { "a", "b" } do
		local d = arena[id]
		if type(d) == "table" and d.userId == userId and d.isAI ~= true then
			return id
		end
	end
	return nil
end

local function offered(support: any): { any }
	local out = {}
	for _, o in if type(support) == "table" and type(support.offers) == "table" then support.offers else {} do
		if type(o) == "table" and type(o.trigger) == "string" then
			table.insert(out, o)
		end
	end
	return out
end

local function slots(support: any): number
	local n = if type(support) == "table" and type(support.slots) == "number" then support.slots else 0
	return math.max(0, math.floor(n))
end

function LoadoutModel.choice(duellist: any?, support: any?): any
	local d = if type(duellist) == "table" then duellist else {}
	local triggers = {}
	if type(d.triggers) == "table" and #d.triggers > 0 then
		-- what the server already holds for this duellist (an earlier Arena.Choose): keep it (FORGE-07 L1)
		for _, t in d.triggers do
			if #triggers < slots(support) then
				table.insert(triggers, t)
			end
		end
	else
		for _, o in offered(support) do
			if #triggers >= slots(support) then
				break
			end
			table.insert(triggers, o.trigger)
		end
	end
	return {
		weapon = if ArenaText.weapon(d.weapon).id ~= "" then d.weapon else ArenaText.WEAPONS[1].id,
		armour = if ArenaText.armour(d.armour).id ~= "" then d.armour else ArenaText.ARMOUR[2].id,
		triggers = triggers,
	}
end

function LoadoutModel.toggle(choice: any, trigger: string, support: any): any
	local nextChoice = { weapon = choice.weapon, armour = choice.armour, triggers = {} }
	local had = false
	for _, t in choice.triggers do
		if t == trigger then
			had = true
		else
			table.insert(nextChoice.triggers, t)
		end
	end
	if not had then
		local isOffered = false
		for _, o in offered(support) do
			if o.trigger == trigger then
				isOffered = true
			end
		end
		if not isOffered or #nextChoice.triggers >= slots(support) then
			return choice -- not offered, or every slot is taken: nothing changes
		end
		table.insert(nextChoice.triggers, trigger)
	end
	return nextChoice
end

function LoadoutModel.args(choice: any): (string, string, { string })
	return choice.weapon, choice.armour, table.clone(choice.triggers)
end

local function rows(list: { any }, selected: string): { any }
	local out = {}
	for _, r in list do
		table.insert(out, {
			id = r.id,
			name = r.name,
			short = r.short,
			icon = r.icon,
			blurb = r.blurb,
			shortBlurb = r.shortBlurb,
			selected = r.id == selected,
		})
	end
	return out
end

function LoadoutModel.view(arena: any, support: any, userId: number?, choice: any, now: number, sent: any?): any
	if type(arena) ~= "table" or arena.stage ~= "loadout" then
		return nil
	end
	local side = LoadoutModel.side(arena, userId)
	if side == nil then
		return nil
	end
	local duellist = arena[side]
	local tierId = (if type(support) == "table" then support.tier else nil) or duellist.tier
	local tier = ArenaText.tier(tierId)
	local n = slots(support)
	local chosen: { [string]: boolean } = {}
	for _, t in choice.triggers do
		chosen[t] = true
	end
	local offers = {}
	for _, o in offered(support) do
		local info = ArenaText.trigger(o.trigger)
		local selected = chosen[o.trigger] == true
		local citizen = nil
		if type(o.citizenName) == "string" and o.citizenName ~= "" then
			local role = ArenaText.ROLES[o.role]
			citizen = if role then `{o.citizenName} · {role}` else o.citizenName
		end
		table.insert(offers, {
			trigger = o.trigger,
			name = info.name,
			icon = info.icon,
			citizen = citizen,
			loyalty = if type(o.loyalty) == "number" then math.floor(o.loyalty + 0.5) else nil,
			power = ArenaText.POWER[o.power],
			effect = if type(o.effect) == "string" then o.effect else info.short,
			condition = if type(o.condition) == "string" then o.condition else "",
			selected = selected,
			locked = not selected and #choice.triggers >= n, -- every slot taken: deselect one first
			crowd = o.trigger == "crowdRally",
		})
	end
	local secondsLeft = if type(arena.endsAt) == "number" then math.max(0, arena.endsAt - now) else nil
	local noOffers = nil
	if #offers == 0 then
		noOffers = if n == 0
			then `{tier.name} support: no perk slots this duel`
			else "No citizen is loyal enough to pledge a perk yet"
	end
	local status = nil
	if type(sent) == "table" then
		status = if sent.ok
			then "Ready. You can still change it until the time runs out"
			elseif sent.pending then "Sending…"
			else ArenaText.REASONS[sent.reason] or "That choice was not accepted"
	end
	return {
		side = side,
		secondsLeft = secondsLeft,
		clock = if secondsLeft then Format.clock(secondsLeft) else nil,
		urgent = secondsLeft ~= nil and secondsLeft <= LoadoutModel.URGENT_SEC,
		tier = { id = tierId, name = tier.name, color = Theme.color(tier.color), blessing = tier.blessing },
		slots = n,
		chosen = #choice.triggers,
		slotsText = if n == 0 then "No perk slots" else `Perks {#choice.triggers} of {n}`,
		weapons = rows(ArenaText.WEAPONS, choice.weapon),
		armour = rows(ArenaText.ARMOUR, choice.armour),
		offers = offers,
		noOffers = noOffers,
		sidegrades = ArenaText.SIDEGRADES,
		confirm = {
			label = if type(sent) == "table" and sent.ok then "Ready ✓" else "Ready",
			enabled = not (type(sent) == "table" and sent.pending),
		},
		sent = type(sent) == "table" and sent.ok == true,
		status = status,
	}
end

return table.freeze(LoadoutModel)
