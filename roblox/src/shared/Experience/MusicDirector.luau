--!strict
--[[
	Experience/MusicDirector — picks the music state from the match phase, combat and the result,
	with hysteresis so the music never flip-flops. Pure; AudioController:setMusic plays the state.
	Generic: the game maps its phases to states (game-001: MatchPhase -> state in its MusicController).

		local music = MusicDirector.new({ phaseStates = { Founding = "calm", Expansion = "build", ... },
		                                  minDwellSec = 20, combatHoldSec = 25, calmTailSec = 8 })
		music:combat(now)                  -- a combat cue happened
		music:calm(now)                    -- combat ended for us: battle rings out for calmTailSec
		music:update(now, { phase: string?, inMatch: boolean, result: ("won" | "lost")?, scene: string? })
			-> string?   returns the new state when it changes, else nil
		MusicDirector.soundFor(state) -> string   STATE_SOUNDS[state], else "music.<state>" (a game's scene)

	States -> sound ids: STATE_SOUNDS (music.calm ... music.defeat); a game registers those ids in its
	Sounds.luau, and "music.<scene>" for each scene it uses (game-001: music.arena). Rules
		result won/lost              -> victory/defeat at once (overrides everything)
		scene (e.g. "arena")         -> that state at once, held while set; leaving it does not wait
		                                for the dwell (game-001's Crown Arena, FL-0074)
		combat within combatHoldSec  -> battle at once; leaves battle only when the hold has passed
		otherwise                    -> phaseStates[phase] (default "calm"); not in a match -> calm
		phase changes wait until the current state has played minDwellSec (urgent states do not wait)
]]

local MusicDirector = {}
MusicDirector.__index = MusicDirector

MusicDirector.STATE_SOUNDS = table.freeze({
	calm = "music.calm",
	build = "music.build",
	tension = "music.tension",
	battle = "music.battle",
	victory = "music.victory",
	defeat = "music.defeat",
})

export type Options = {
	phaseStates: { [string]: string }?,
	minDwellSec: number?,
	combatHoldSec: number?,
	calmTailSec: number?,
}

function MusicDirector.new(options: Options?)
	local opts = options or {}
	return setmetatable({
		_phaseStates = opts.phaseStates or {},
		state = nil :: string?,
		_since = -math.huge,
		_lastCombat = -math.huge,
		_minDwell = opts.minDwellSec or 20,
		_hold = opts.combatHoldSec or 25,
		_calmTail = opts.calmTailSec or 8,
		_scene = false, -- the current state came from a scene
	}, MusicDirector)
end

function MusicDirector:combat(now: number)
	self._lastCombat = now
end

function MusicDirector:calm(now: number)
	-- combat is over: battle music rings out for calmTail seconds instead of the full hold
	self._lastCombat = math.min(self._lastCombat, now - self._hold + self._calmTail)
end

-- The sound id that plays a state: the built-in states' ids, else "music.<state>" (a game's scene).
function MusicDirector.soundFor(state: string): string
	return MusicDirector.STATE_SOUNDS[state] or ("music." .. state)
end

function MusicDirector:_set(state: string, now: number, scene: boolean?): string?
	self._scene = scene == true
	if state == self.state then
		return nil
	end
	self.state = state
	self._since = now
	return state
end

function MusicDirector:update(
	now: number,
	inputs: { phase: string?, inMatch: boolean?, result: string?, scene: string? }
): string?
	if inputs.result == "won" then
		return self:_set("victory", now)
	elseif inputs.result == "lost" then
		return self:_set("defeat", now)
	end
	if type(inputs.scene) == "string" and inputs.scene ~= "" then
		return self:_set(inputs.scene, now, true)
	end
	local fromScene = self._scene == true
	self._scene = false
	if inputs.inMatch and now - self._lastCombat < self._hold then
		return self:_set("battle", now)
	end
	local desired = if inputs.inMatch then (self._phaseStates[inputs.phase or ""] or "calm") else "calm"
	if self.state == nil then
		return self:_set(desired, now)
	end
	local leavingUrgent = fromScene or self.state == "battle" or self.state == "victory" or self.state == "defeat"
	if not leavingUrgent and now - self._since < self._minDwell then
		return nil
	end
	return self:_set(desired, now)
end

return MusicDirector
