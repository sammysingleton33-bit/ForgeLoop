--[[
	FallenDoubles — FL-0129's spectate screen's partners, as their handoffs describe them:
		FORGE-01's Match.Spectate(spectating, info?) serverEvent (FL-0125, branch forge/01-gameplay-full-match)
		FORGE-04's RulerSpectateController (#183, handoff 2026-10-18-forge-04-to-forge-03-spectate-and-raid-ping)

		FallenDoubles.REMOTES                  extra declarations (KingdomWorld opts.remotes)
		FallenDoubles.service                  (world) -> server Def "SpectateDouble":
		                                         svc:send(player, spectating, info?)
		FallenDoubles.camera(state) -> client Def "RulerSpectateController" over state.targets:
		                                         active, changed, targetChanged, targets(), select(i),
		                                         cycle(±1), setActive(on); state.camera, state.setActive
		FallenDoubles.keep(kingdom, name, x)  FallenDoubles.battle(kingdom, name, x, count)
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local FallenDoubles = {}

FallenDoubles.REMOTES = { Match = { { name = "Match.Spectate", kind = "serverEvent" } } }

function FallenDoubles.service(_world)
	return {
		name = "SpectateDouble",
		dependencies = { "RemoteService" },
		new = function(_env, registry)
			local remotes = registry:get("RemoteService")
			return {
				send = function(_self, player, spectating, info)
					remotes:fire("Match.Spectate", player, spectating, info)
				end,
			}
		end,
	}
end

function FallenDoubles.camera(state)
	return {
		name = "RulerSpectateController",
		new = function()
			local cam = {
				active = false,
				changed = Signal.new(),
				targetChanged = Signal.new(),
				index = 0,
			}
			function cam.targets()
				return table.clone(state.targets)
			end
			function cam:select(i)
				self.index = i
				local t = state.targets[i]
				self.targetChanged:fire(t)
				return t
			end
			function cam:cycle(step)
				local n = #state.targets
				if n == 0 then
					return nil
				end
				self.index = ((self.index - 1 + step) % n) + 1
				return self:select(self.index)
			end
			function cam:setActive(on)
				state.setActive = on
				if self.active ~= on then
					self.active = on
					self.changed:fire(on)
				end
				return true
			end
			state.camera = cam
			return cam
		end,
	}
end

function FallenDoubles.keep(kingdom, name, x)
	return { kind = "keep", position = Vector3.new(x, 0, 0), kingdom = kingdom, kingdomName = name }
end

function FallenDoubles.battle(kingdom, name, x, count)
	return { kind = "battle", position = Vector3.new(x, 0, 0), kingdom = kingdom, kingdomName = name, count = count }
end

return FallenDoubles
