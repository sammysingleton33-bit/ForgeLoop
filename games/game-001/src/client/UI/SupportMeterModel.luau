--!strict
--[[
	UI/SupportMeterModel — the in-match support meter and its breakdown (FL-0073; design crown-arena.md §3, §8 "HUD
	support meter"; CONTRACTS G12.1 SupportView). Pure; no instances. UI/SupportMeter (the HUD chip) and
	UI/SupportPanel (the breakdown drawer) draw it.

		SupportMeterModel.view(supportView?, now?) -> View?   nil until the server sent a SupportView
			View = {
				tier { id, name, color },  score (0..100, whole),
				trend { arrow "▲" | "▼" | "▬", text, color },     -- trend > TREND_STEP: rising, < -TREND_STEP: falling
				chip   "Adoring 91 ▲" (always tier text plus colour, never colour alone),
				components: { { id, name, icon, weight (share of the score, %), value (0..100), bar (0..1) } } in config
				            Support.componentOrder,
				moments: { { text, component, delta, deltaText, positive } } newest first (≤ MOMENTS),
				noMoments: string?,  slots, slotsText,
				nextTier: string?   e.g. "9 points to Adoring" (the next tier's min from config)
			}
		The texts of moments are the server's pre-authored LeadershipMoment.text, never user input.
]]

local ArenaText = require("./ArenaText")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SupportMeterModel = {}

SupportMeterModel.TREND_STEP = 0.5
SupportMeterModel.MOMENTS = 6

SupportMeterModel.COMPONENTS = table.freeze({
	reputation = table.freeze({ name = "Reputation", icon = "laurel" }),
	happiness = table.freeze({ name = "Happiness", icon = "happiness" }),
	stability = table.freeze({ name = "Stability", icon = "stability" }),
	morale = table.freeze({ name = "Army morale", icon = "army" }),
	loyalty = table.freeze({ name = "Citizen loyalty", icon = "heart" }),
	conduct = table.freeze({ name = "Your conduct", icon = "scroll" }),
	valour = table.freeze({ name = "Your valour", icon = "rep_courage" }),
})

local function signed(n: number): string
	local r = math.floor(n + 0.5)
	if n < 0 then
		r = -math.floor(-n + 0.5)
	end
	return if r > 0 then `+{r}` elseif r < 0 then `−{-r}` else "0"
end

-- The trend window from config (Support.trendSeconds), not a literal (FORGE-07 L2 on #225).
local function window(): string
	local minutes = math.max(1, math.floor(Support.trendSeconds / 60 + 0.5))
	return `{minutes} min`
end

local function trendOf(t: any): any
	local v = if type(t) == "number" and t == t then t else 0
	if v > SupportMeterModel.TREND_STEP then
		return { arrow = "▲", text = `Rising {signed(v)} in {window()}`, color = Theme.color("vert") }
	elseif v < -SupportMeterModel.TREND_STEP then
		return { arrow = "▼", text = `Falling {signed(v)} in {window()}`, color = Theme.color("gules") }
	end
	return { arrow = "▬", text = "Steady", color = Theme.color("textMuted") }
end

-- Points to the next tier up (config Support.tiers[t].min), or nil at the top.
local function nextTier(score: number, tierId: string?): string?
	local order = Support.tierOrder
	for i, id in order do
		if id == tierId and i > 1 then
			local up = order[i - 1]
			local need = math.max(1, math.ceil(Support.tiers[up].min - score))
			return `{need} point{if need == 1 then "" else "s"} to {ArenaText.tier(up).name}`
		end
	end
	return nil
end

function SupportMeterModel.view(sv: any, _now: number?): any
	if type(sv) ~= "table" or type(sv.score) ~= "number" then
		return nil
	end
	local tierId = if type(sv.tier) == "string" then sv.tier else nil
	local tier = ArenaText.tier(tierId)
	local score = math.clamp(math.floor(sv.score + 0.5), 0, 100)
	local trend = trendOf(sv.trend)
	local components = {}
	local breakdown = if type(sv.breakdown) == "table" then sv.breakdown else {}
	for _, id in Support.componentOrder do
		local info = SupportMeterModel.COMPONENTS[id] or { name = id, icon = "info" }
		local raw = breakdown[id]
		local value = if type(raw) == "number" and raw == raw then math.clamp(raw, 0, 100) else nil
		table.insert(components, {
			id = id,
			name = info.name,
			icon = info.icon,
			weight = Support.components[id] and Support.components[id].weight or 0,
			value = if value then math.floor(value + 0.5) else nil,
			bar = if value then value / 100 else 0,
		})
	end
	local moments = {}
	local list = if type(sv.moments) == "table" then table.clone(sv.moments) else {}
	table.sort(list, function(a, b)
		return (type(a) == "table" and a.t or 0) > (type(b) == "table" and b.t or 0)
	end)
	for _, m in list do
		if #moments >= SupportMeterModel.MOMENTS then
			break
		end
		if type(m) == "table" and type(m.text) == "string" and m.text ~= "" then
			local delta = if type(m.delta) == "number" then m.delta else 0
			local info = SupportMeterModel.COMPONENTS[m.component]
			table.insert(moments, {
				text = m.text,
				component = if info then info.name else tostring(m.component or ""),
				delta = delta,
				deltaText = signed(delta),
				positive = delta >= 0,
			})
		end
	end
	local slots = if type(sv.slots) == "number" then sv.slots else tier.slots
	return {
		tier = { id = tierId, name = tier.name, color = Theme.color(tier.color) },
		score = score,
		trend = trend,
		chip = `{tier.name} {score} {trend.arrow}`,
		components = components,
		moments = moments,
		noMoments = if #moments == 0 then "Nothing has moved your support yet" else nil,
		slots = slots,
		slotsText = if slots == 1 then "1 perk slot in the arena" else `{slots} perk slots in the arena`,
		blessing = tier.blessing,
		nextTier = nextTier(score, tierId),
	}
end

return table.freeze(SupportMeterModel)
