--!strict
--[[
	UI/Slots — where build slots stand in the world (world/Layout plots[*].buildSlots, FORGE-02's shape;
	CONTRACTS G13.5). Pure; no instances. The plot picker's ghost (FL-0114) and the move ghost's plot snap
	(FL-0120) both read it.

		Slots.frame(slotId) -> { center: Vector3, yaw: number, size: Vector2 }?
			centre, yaw (radians, CFrame.Angles(0, yaw, 0); the street is in front) and size in studs
		Slots.contains(frame, position) -> boolean   the point is over the plot (its rectangle, on XZ)
]]

local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

local Slots = {}

function Slots.frame(slotId: any): { center: Vector3, yaw: number, size: Vector2 }?
	for _, plot in WorldLayout.plots or {} do
		for _, slot in plot.buildSlots or {} do
			if slot.id == slotId then
				local size = WorldLayout.slotSizes[slot.size]
				if typeof(slot.center) ~= "Vector3" or type(slot.rot) ~= "number" or typeof(size) ~= "Vector2" then
					return nil
				end
				return { center = slot.center, yaw = slot.rot, size = size }
			end
		end
	end
	return nil
end

function Slots.contains(frame: { center: Vector3, yaw: number, size: Vector2 }, position: Vector3): boolean
	local cf = CFrame.new(frame.center) * CFrame.Angles(0, frame.yaw, 0)
	local p = cf:PointToObjectSpace(Vector3.new(position.X, frame.center.Y, position.Z))
	return math.abs(p.X) <= frame.size.X / 2 and math.abs(p.Z) <= frame.size.Y / 2
end

return table.freeze(Slots)
