local T = require("../../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local TICK = MatchConfig.tickSeconds

describe("WarProbe", function()
	for _, seed in { 15 } do
		it(`prints the war timeline seed {seed}`, function()
			local match = Match.new({
				random = Random.new(seed),
				minPlayers = 0,
				now = function()
					return 1700000000
				end,
			})
			local sim = match.sim
			local nextLog = 0
			local steps = 0
			while match.state ~= "Results" and steps < 200000 do
				match:update(TICK)
				steps += 1
				for _, e in match:drainEvents() do
					if
						e.name == "WarDeclared"
						or e.name == "PeaceMade"
						or e.name == "KingdomEliminated"
						or e.name == "SiegeChanged"
					then
						print(
							`[{string.format("%.0f", sim.time)}] {e.name} {e.kingdomId} {e.targetId or e.byKingdomId or ""} {if e.on
									~= nil
								then tostring(e.on)
								else ""}`
						)
					end
				end
				if sim.active and sim.time >= nextLog and sim.time > 1500 then
					nextLog += 300
					local parts = {}
					for _, kid in sim.kingdomOrder do
						local k = sim.kingdoms[kid]
						local kinds = {}
						local rams = 0
						for _, uid in k.unitIds do
							local u = sim.units[uid]
							kinds[u.order.kind] = (kinds[u.order.kind] or 0) + 1
							if u.kind == "ram" then
								rams += 1
							end
						end
						local ks = {}
						for kk, n in kinds do
							table.insert(ks, `{kk}{n}`)
						end
						table.sort(ks)
						local keep = sim.buildings[k.keepId]
						local dsum, dn, tgt = 0, 0, ""
						for _, uid in k.unitIds do
							local u = sim.units[uid]
							if u.order.kind == "Attack" then
								local tk = sim.kingdoms[u.order.kingdomId]
								tgt = u.order.kingdomId
								dsum += math.sqrt((u.x - tk.x) ^ 2 + (u.z - tk.z) ^ 2)
								dn += 1
							end
						end
						local dist = if dn > 0 then ` ->{tgt} d{math.floor(dsum / dn)}` else ""
						local bl = 0
						for _, bid in k.buildingIds do
							local b = sim.buildings[bid]
							if b.kind == "barracks" then
								bl = math.max(bl, b.level)
							end
						end
						table.insert(
							parts,
							`{kid}[B{bl} w{math.floor(sim:balance(kid, "wood"))} s{math.floor(sim:balance(kid, "stone"))} {sim.rulerAI.lastAction[kid]}]{dist}: u{#k.unitIds} r{rams} [{table.concat(
								ks,
								","
							)}] keep {if keep
								then math.floor(keep.hp) .. "/" .. keep.maxHp .. " L" .. keep.level
								else "x"} c{#k.citizenIds}`
						)
					end
					print(`t={string.format("%.0f", sim.time)} ` .. table.concat(parts, " | "))
				end
				if sim.time < 1500 and sim.time >= nextLog and sim.active then
					nextLog = 1500
				end
			end
			print(
				`seed {seed} END state {match.state} t={string.format("%.0f", sim.time)} reason {match:summary() and match:summary().reason}`
			)
		end)
	end
end)
