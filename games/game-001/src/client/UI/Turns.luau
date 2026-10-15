--!strict
--[[
	UI/Turns — turning a building on its plot (CONTRACTS G13.5 v0.4-g9h; the user's first Studio
	feedback: placing on a plot could not be rotated). Pure; no instances.

	`Build.PlaceSlot(slotId, type, turn?)`: turn = quarter turns from the slot's facing (0 = facing the
	street), the same sense as `Build.Place`'s rot (+1 is a quarter counter-clockwise seen from above).
	The turned footprint must fit: FORGE-01's `Fit.fits(type, size, turn?)` (the one fit rule; it is
	never re-implemented here).

		Turns.supported() -> boolean       the shared Build/Remotes declares PlaceSlot's third argument,
		                                   so the server in this build takes a turn (and its Fit checks
		                                   it: FORGE-01 ships both together). Until then the plot picker
		                                   shows no Turn and PlaceSlot keeps its two arguments.
		Turns.allowed(type, size) -> { integer }   the turns that fit, ascending; { 0 } when unsupported
		Turns.next(allowed, turn) -> integer        the next allowed turn after `turn` (wraps)
		Turns.yaw(slotYaw, turn) -> number          radians: the slot's world yaw + turn quarter turns
		Turns.label(turn) -> string                 "Faces the street", "Faces right", "Faces away",
		                                            "Faces left" (seen from the street)
		Turns.useSeam({ supported: boolean?, fits: ((type, size, turn) -> boolean)? }?)
		                                   specs and scenes: stand in for the contract before FORGE-01's
		                                   server lands; nil restores the real one
	Labels: the street is in front of the slot (its -Z). Seen from the street a turn of +1 swings the
	front from the viewer to the viewer's right: the front (0, 0, -1) becomes (-1, 0, 0), and someone
	looking at the building along +Z has -X on their right.
]]

local BuildRemotes = require("@game/ReplicatedStorage/Game/Build/Remotes")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")

local Turns = {}

Turns.LABELS = table.freeze({
	[0] = "Faces the street",
	[1] = "Faces right",
	[2] = "Faces away",
	[3] = "Faces left",
})

local seam: { supported: boolean?, fits: ((string, string, number) -> boolean)? }? = nil

local function declared(): boolean
	for _, remote in BuildRemotes do
		if remote.name == "Build.PlaceSlot" then
			return type(remote.args) == "table" and #remote.args >= 3
		end
	end
	return false
end

function Turns.useSeam(value: { supported: boolean?, fits: ((string, string, number) -> boolean)? }?)
	seam = value
end

function Turns.supported(): boolean
	if seam and seam.supported ~= nil then
		return seam.supported
	end
	return declared()
end

local function fits(buildingType: string, size: string, turn: number): boolean
	if seam and seam.fits then
		return seam.fits(buildingType, size, turn)
	end
	return (Fit.fits :: any)(buildingType, size, turn) == true
end

function Turns.allowed(buildingType: string, size: string): { number }
	if not Turns.supported() then
		return { 0 }
	end
	local out = {}
	for turn = 0, 3 do
		if fits(buildingType, size, turn) then
			table.insert(out, turn)
		end
	end
	return out
end

function Turns.next(allowed: { number }, turn: number): number
	for _, candidate in allowed do
		if candidate > turn then
			return candidate
		end
	end
	return allowed[1] or 0
end

function Turns.yaw(slotYaw: number, turn: number): number
	return slotYaw + turn * math.pi / 2
end

function Turns.label(turn: number): string
	return Turns.LABELS[turn % 4]
end

return table.freeze(Turns)
