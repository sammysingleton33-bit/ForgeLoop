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

	The duel on the server (Arena/DuelRunner):
	tick                   seconds per simulation step (the duel is stepped at a fixed rate whatever the frame rate)
	maxCatchup             the most real time one step() call may catch up on; a longer stall loses the rest, so a
	                       lag spike never fast-forwards a duel
	snapshotEvery          duel seconds between the public `snapshot` events for the HUD
	reach                  studs between the two duellists within which a swing can land
	facingMinDot           how squarely a duellist must face the other (dot product of their forward vector and the
	                       direction to the opponent) for a swing to land
	blockMaxSeconds        a block held longer than this is released by the server (a client that never sends blockEnd
	                       cannot turtle for ever)
	rate                   Arena.Action token bucket per champion (G12.4): burst and actions per second
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
	tick = 1 / 30,
	maxCatchup = 0.25,
	snapshotEvery = 0.2,
	reach = 6.5,
	facingMinDot = 0.5,
	blockMaxSeconds = 2.5,
	rate = { burst = 8, perSecond = 12 },
}
