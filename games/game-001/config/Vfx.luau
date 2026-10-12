--!strict
--[[
	AI Kingdoms (game-001) visual feedback config — owner FORGE-04 (FL-0091; kingdom presets join in
	FL-0062). Data only: CitizenBubbleController and Feedback/Bubbles read it.

	bubbles   tuning of citizen thought / reaction bubbles and strike placards (Feedback/Bubbles)
	cues      consequence cue -> what the citizen does: { pose: string?, sound: string?, vfx: string? }
	          Keys are the CONTRACTS G13.3 `cue` vocabulary (celebrate, grumble, salute, bow, cower,
	          strike_placard, work_fast, rest, hammer). `pose` is asked of EntityController:playPose
	          (FORGE-01, proposed); `sound` and `vfx` play at the citizen. The spec checks every sound is in
	          Sounds.luau and every effect is a registered VFX preset, and that a cue with a sound also has an
	          effect (accessibility: every sound has a visual, even before poses exist).
	          `celebrate` is pose-only here: FeedbackController (FL-0062) already plays its cheer and burst.
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
		celebrate = table.freeze({ pose = "cheer" }),
		grumble = table.freeze({ pose = "grumble" }),
		salute = table.freeze({ pose = "salute" }),
		bow = table.freeze({ pose = "bow" }),
		cower = table.freeze({ pose = "cower" }),
		strike_placard = table.freeze({ pose = "grumble", sound = "kingdom.capture.lost", vfx = "hit.generic" }),
		work_fast = table.freeze({ pose = "work_fast", vfx = "reward.burst" }),
		rest = table.freeze({ pose = "rest", vfx = "ambience.motes" }),
		hammer = table.freeze({ pose = "hammer", sound = "kingdom.hammer", vfx = "hit.generic" }),
	}),
})
