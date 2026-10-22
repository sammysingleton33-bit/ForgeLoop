--[[
	LineDoubles — FORGE-01's Build.PlaceLine (FL-0126 part 2 slice 1; handoff 2026-10-22-forge-01-to-all-place-line)
	for FL-0129c's specs and scenes. Written from the handoff, not from UI/WallLine, so a spec compares the client's
	ghosts with an independent copy of the server's rule.

		LineDoubles.REMOTES    { Build = { Build.PlaceLine(kind: string, from: Vector3, to: Vector3) } }
		                       (pass as KingdomWorld.new({ remotes = LineDoubles.REMOTES, services = { LineDoubles.service } }))
		LineDoubles.service    (world) -> server Def "LineDouble" (needs KingdomWorld's BuildingService):
			svc.calls          { { kind, from, to } } every Build.PlaceLine that reached the server
			svc.answer         nil = the rules below; { nil, reason } = refuse with that reason; "drop" = no answer
			Rules: kind "wall" only (else not_a_line_piece); both ends snap to Buildings.lineGrid; fewer than one grid
			step apart = too_short; round(length / 32) pieces, at least one, more than Buildings.maxLineSegments =
			too_long; every piece at (i - 0.5) * 32 from the start passes BuildingService:canPlace; the kingdom
			affords all of them; then every piece is added (state "planned") and pushed, ids in order.
]]

local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local LineDoubles = {}

LineDoubles.REMOTES = {
	Build = {
		{
			name = "Build.PlaceLine",
			kind = "function",
			args = { Validate.string(1, 32), Validate.vector3(4000), Validate.vector3(4000) },
			rate = { burst = 2, perSecond = 1 },
		},
	},
}

function LineDoubles.service(_world)
	return {
		name = "LineDouble",
		dependencies = { "RemoteService", "BuildingService", "TreasuryService", "KingdomService" },
		new = function(_env, registry)
			local remotes = registry:get("RemoteService")
			local buildings = registry:get("BuildingService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local svc = { calls = {}, answer = nil }
			local grid = (BuildingsConfig :: any).lineGrid or 4
			local max = (BuildingsConfig :: any).maxLineSegments or 12
			local function snap(v)
				return math.floor(v / grid + 0.5) * grid
			end
			function svc:start()
				remotes:handle("Build.PlaceLine", function(player, kind, from, to)
					table.insert(self.calls, { kind = kind, from = from, to = to })
					if self.answer == "drop" then
						return nil
					elseif type(self.answer) == "table" then
						return self.answer[1], self.answer[2]
					end
					local kingdom = kingdoms:getKingdomOf(player)
					if kingdom == nil then
						return nil, "not_in_match"
					elseif kind ~= "wall" then
						return nil, "not_a_line_piece"
					end
					local fx, fz, tx, tz = snap(from.X), snap(from.Z), snap(to.X), snap(to.Z)
					local dx, dz = tx - fx, tz - fz
					local length = math.sqrt(dx * dx + dz * dz)
					if length < grid then
						return nil, "too_short"
					end
					local count = math.max(1, math.floor(length / 32 + 0.5))
					if count > max then
						return nil, "too_long"
					end
					local spots = {}
					for i = 1, count do
						local at = (i - 0.5) * 32
						local spot = Vector3.new(fx + dx / length * at, from.Y, fz + dz / length * at)
						local ok, reason = buildings:canPlace(kingdom, "wall", spot)
						if not ok then
							return nil, reason
						end
						table.insert(spots, spot)
					end
					local total = {}
					for res, amount in Costs.building("wall", 1).cost do
						total[res] = amount * count
					end
					if not treasury:spend(kingdom, total, `line:{buildings.nextId}`, "construction") then
						return nil, "cannot_afford"
					end
					local ids = {}
					for _, spot in spots do
						local id = buildings:add(kingdom, "wall", 1, "planned", spot)
						buildings:push(id)
						table.insert(ids, id)
					end
					return ids
				end)
			end
			return svc
		end,
	}
end

return LineDoubles
