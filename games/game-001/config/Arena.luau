--!strict
--[[
	Arena (ReplicatedStorage.Forge.Config.Arena) — the Crown Arena's stage flow (design `crown-arena.md` §2, CONTRACTS
	G12). Owner: FORGE-01. Read by Arena/ArenaFlow (pure) and ArenaService.

	PROVISIONAL timings (FORGE-04 owns the match-level phase lengths in Pacing; these are the stages inside the arena).

	voteSeconds            co-rulers of a qualified kingdom choose their champion (closes early when all have voted)
	loadoutSeconds         the champion picks weapon, armour and trigger perks; the offered defaults stand if they don't
	introSeconds           the versus card and the camera pass
	duelMaxSeconds         the safety clock of the duel stage: the duel's own caps (Duel rules timeCap and hardCap) end
	                       it first; if the clock still runs out the duel is a draw
	crowningSeconds        the winner's coronation; the match ends when it does
	simultaneousSeconds    a second champion leaving this soon after a forfeit makes it a draw (both_left)
	ai                     an AI kingdom's champion: weapon and armour (the AI duellist's skill is DuelAI's)
	defaultWeapon          what a human champion fights with if they never choose
	defaultArmour
	Last keep standing (one qualifier) skips straight to the crowning: a coronation, no duel.
]]

return {
	voteSeconds = 10,
	loadoutSeconds = 20,
	introSeconds = 12,
	duelMaxSeconds = 195,
	crowningSeconds = 15,
	simultaneousSeconds = 0.5,
	defaultWeapon = "swordShield",
	defaultArmour = "medium",
	ai = { weapon = "swordShield", armour = "medium" },
}
