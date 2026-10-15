--!strict
--[[
	Feedback/Requests (game-001, FORGE-04, FL-0115 B16): open citizen requests ("!" thoughts) that the
	aerial view does not show. Pure; CitizenBubbleIndicatorController draws and binds it.

		Requests.edge(point: Vector3, viewport: Vector2, inset: number | Insets, corner: Vector2?) -> Edge
			-- point is a camera projection in the area's pixels (X, Y; Z = depth, <= 0 behind the
			-- camera). On screen = in front and inside the inset rectangle (one number, or one per side:
			-- the HUD's rail, top row and bottom bar). Otherwise the indicator sits where the line from
			-- the centre towards the point leaves that rectangle, and `angle` (degrees, 0 = right,
			-- 90 = down) points from the centre to it. `corner`: the top-left HUD stack's size; an
			-- indicator that would land in it slides along its edge out of it.
		Requests.order(list: { Request }) -> { Request }   -- oldest request first (since), then id
		Requests.nextAfter(ids: { number }, current: number?, step: number?) -> number?
			-- the id after `current` in `ids` (step -1: before), wrapping; the first (last) when current
			-- is nil or gone; nil when there are none
		Requests.group(edges: { Placed }, gap: number, max: number) -> { Group }
			-- indicators closer than `gap` px share one (the first, oldest, leads it and counts the rest);
			-- at most `max` groups, in order, so a crowded edge never stacks arrows on each other

	Types: Request = { entityId: number, position: Vector3, since: number }
	       Insets = { left: number, right: number, top: number, bottom: number }
	       Edge = { onScreen: boolean, position: Vector2?, angle: number? }
	       Placed = { entityId: number, position: Vector2, angle: number }
	       Group = { entityId: number, position: Vector2, angle: number, count: number, ids: { number } }
]]

local Requests = {}

export type Request = { entityId: number, position: Vector3, since: number }
export type Insets = { left: number, right: number, top: number, bottom: number }
export type Edge = { onScreen: boolean, position: Vector2?, angle: number? }
export type Placed = { entityId: number, position: Vector2, angle: number }
export type Group = { entityId: number, position: Vector2, angle: number, count: number, ids: { number } }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Requests.edge(point: Vector3, viewport: Vector2, inset: number | Insets, corner: Vector2?): Edge
	if not (finite(point.X) and finite(point.Y) and finite(point.Z)) then
		return { onScreen = false }
	end
	local sides: Insets = if type(inset) == "number"
		then { left = inset, right = inset, top = inset, bottom = inset }
		else inset
	local width, height = viewport.X, viewport.Y
	local minX, maxX = sides.left, math.max(sides.left, width - sides.right)
	local minY, maxY = sides.top, math.max(sides.top, height - sides.bottom)
	if point.Z > 0 and point.X >= minX and point.X <= maxX and point.Y >= minY and point.Y <= maxY then
		return { onScreen = true }
	end
	local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
	local dx, dy = point.X - cx, point.Y - cy
	if point.Z <= 0 then
		-- behind the camera the projection is mirrored through the centre: point the other way
		dx, dy = -dx, -dy
	end
	if math.abs(dx) < 1e-6 and math.abs(dy) < 1e-6 then
		dx, dy = 0, 1 -- straight behind: show it at the bottom, towards the ruler's back
	end
	local halfW, halfH = (maxX - minX) / 2, (maxY - minY) / 2
	local scaleX = if math.abs(dx) > 1e-6 then halfW / math.abs(dx) else math.huge
	local scaleY = if math.abs(dy) > 1e-6 then halfH / math.abs(dy) else math.huge
	local scale = math.min(scaleX, scaleY)
	local x, y = cx + dx * scale, cy + dy * scale
	if corner ~= nil and x < corner.X and y < corner.Y then
		-- in the top-left HUD stack: slide along the edge it is on, out of the stack
		if scaleX <= scaleY then
			y = math.min(maxY, corner.Y)
		else
			x = math.min(maxX, corner.X)
		end
	end
	return {
		onScreen = false,
		position = Vector2.new(x, y),
		angle = math.deg(math.atan2(dy, dx)),
	}
end

function Requests.order(list: { Request }): { Request }
	local out = table.clone(list)
	table.sort(out, function(a, b)
		if a.since ~= b.since then
			return a.since < b.since
		end
		return a.entityId < b.entityId
	end)
	return out
end

function Requests.nextAfter(ids: { number }, current: number?, step: number?): number?
	local count = #ids
	if count == 0 then
		return nil
	end
	local direction = if step == -1 then -1 else 1
	local index = if current ~= nil then table.find(ids, current) else nil
	if index == nil then
		return if direction == 1 then ids[1] else ids[count]
	end
	return ids[(index - 1 + direction) % count + 1]
end

function Requests.group(edges: { Placed }, gap: number, max: number): { Group }
	local groups: { Group } = {}
	for _, placed in edges do
		local joined = false
		for _, group in groups do
			if (group.position - placed.position).Magnitude < gap then
				group.count += 1
				table.insert(group.ids, placed.entityId)
				joined = true
				break
			end
		end
		if not joined and #groups < max then
			table.insert(groups, {
				entityId = placed.entityId,
				position = placed.position,
				angle = placed.angle,
				count = 1,
				ids = { placed.entityId },
			})
		end
	end
	return groups
end

return table.freeze(Requests)
