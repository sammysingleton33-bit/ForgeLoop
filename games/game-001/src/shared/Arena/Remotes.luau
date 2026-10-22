--!strict
--[[
	Arena/Remotes — remotes of the "Arena" area (CONTRACTS G12.4). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Arena.<Action>.

	Client -> server
		Arena.GetState() -> ArenaState         the public picture of the arena (stage "done" when there is none)
		Arena.Vote(candidateUserId: integer) -> boolean
		                                       co-rulers of a qualified kingdom, vote stage only
		Arena.Choose(weapon, armour, triggers: { TriggerId } (<= 3)) -> (ok, reason?)
		                                       the champion only, loadout stage only; triggers distinct, a subset of
		                                       the champion's own offers and at most their slots. reason: not_loadout_stage,
		                                       not_champion, bad_weapon, bad_armour, bad_arguments, too_many, duplicate,
		                                       not_offered
		Arena.Action(action: DuelAction)       the champion only, duel stage only; anything else is ignored quietly
		                                       (burst 8, 12 a second; the duel runner rate-limits again per champion)
	Server -> client
		Arena.State(ArenaState)                to everyone on every change (stage, endsAt, vote (vote stage), champions, coronation, winner)
		Arena.Events({ { t, kind, side, data? } })   batched duel events (shares only; see Arena/DuelRunner)
	Implemented by ArenaService.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local WEAPONS = { "swordShield", "greatsword", "spear", "mace" }
local ARMOURS = { "light", "medium", "heavy" }
local TRIGGERS =
	{ "reforge", "fieldRemedy", "calledWarning", "heartyRations", "rallyingHymn", "fineWares", "crowdRally" }
local ACTIONS = { "light", "heavy", "block", "blockEnd", "parry", "dodge" }

return {
	{ name = "Arena.GetState", kind = "function", args = {}, rate = { burst = 3, perSecond = 1 } },
	{ name = "Arena.State", kind = "serverEvent" },
	{
		name = "Arena.Vote",
		kind = "function",
		args = { Validate.integer(1, 9007199254740991) },
		rate = { burst = 3, perSecond = 1 },
	},
	{
		name = "Arena.Choose",
		kind = "function",
		args = { Validate.enum(WEAPONS), Validate.enum(ARMOURS), Validate.array(Validate.enum(TRIGGERS), 3) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Arena.Action",
		kind = "event",
		args = { Validate.enum(ACTIONS) },
		rate = { burst = 8, perSecond = 12 },
	},
	{ name = "Arena.Events", kind = "serverEvent" },
}
