--!strict
--[[
	Where a kingdom's citizens stand 30 s after the start, for the world preview (FORGE-02's WorldDump, FORGE_WORLD_CITIZENS=sim).
	Provenance: FORGE-04's sim (EntityService, D-059 work slots ~3.5 studs apart), seed 11, sampled 30 s after the start; 13 rows per
	kingdom: { kingdom, job, x, z, yaw, action } (action "work" | "walk" | "carry"); y is WorldPlan.groundHeight at (x, z).
	The data is StartCitizens.json beside this file (read from the repo root, like the other specs' fixtures).
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PATH = "games/game-001/tests/world/support/StartCitizens.json"

export type Row = { any } -- { kingdom: string, job: string, x: number, z: number, yaw: number, action: string }

local StartCitizens = {}

function StartCitizens.rows(): { Row }
	return serde.decode("json", fs.readFile(PATH)) :: { Row }
end

return StartCitizens
