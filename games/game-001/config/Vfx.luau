--!strict
--[[
	AI Kingdoms (game-001) visual feedback config — owner FORGE-04 (FL-0091; kingdom presets join in
	FL-0062). Data only: CitizenBubbleController and Feedback/Bubbles read it.

	bubbles   tuning of citizen thought / reaction bubbles and strike placards (Feedback/Bubbles)
	cues      consequence cue id -> what plays at the citizen: { sound: string?, vfx: string? }
	          Ids follow the consequences in design/living-kingdom.md §5. They are PROPOSALS until the
	          content library (FORGE-00, content/SPEC.md) fixes its cue column; the spec checks every
	          sound exists in Sounds.luau and every effect is a registered VFX preset, and that no cue is
	          sound-only (accessibility: every sound has a visual).
	          A cue arrives as EntityController.event(entityId, "consequence", { cue = id }, model)
	          (proposed to FORGE-01; G13.3 does not name it yet).
]]

return table.freeze({
	bubbles = table.freeze({
		maxOnScreen = 8, -- citizen bubbles drawn at once (nearest first, reactions before thoughts)
		maxDistance = 160, -- studs from the camera; matches the entity LOD distance
		thoughtSec = 45, -- a request stays this long unless answered (requests refresh every 20 s, G13.3)
		reactionSec = 4,
		maxChars = 80,
	}),
	cues = table.freeze({
		work_boost = table.freeze({ sound = "kingdom.cheer", vfx = "reward.burst" }),
		strike = table.freeze({ sound = "kingdom.capture.lost", vfx = "hit.generic" }),
		strike_end = table.freeze({ sound = "kingdom.cheer", vfx = "reward.burst" }),
		loyalty_up = table.freeze({ vfx = "reward.burst" }),
		loyalty_down = table.freeze({ vfx = "hit.generic" }),
		hunger = table.freeze({ vfx = "ambience.motes" }),
	}),
})
