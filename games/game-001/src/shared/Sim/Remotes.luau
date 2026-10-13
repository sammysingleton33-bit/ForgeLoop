--!strict
--[[
	Sim/Remotes — entity replication remotes (CONTRACTS G4, area "Sim"). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Sim.<Action>.

	Server -> client
		Sim.Snapshot(buffer)    UnreliableRemoteEvent; one SnapshotCodec v2 buffer per event (≤ 900 B);
		                        seq keeps increasing across matches (a reset never restarts it),
		                        ~10 per second; moving entities every snapshot, idle and working ones
		                        round-robin about once per second. VS-1: every client gets every entity.
		Sim.Events(buffer)      reliable; one EventCodec buffer per tick when anything happened: spawn,
		                        despawn, job changes, the cues deposit / hit / die / celebrate, reset; and
		                        per kingdom, to its members only, the G13.3 conversation events (thought,
		                        reaction, strike, kcue) in their own buffer (EntityService:sendKingdomEvent)
	Client -> server
		Sim.Inspect(entityId: integer) -> CitizenService:inspect result, own kingdom only (G8); nil otherwise
		Sim.GetEntities() -> buffer   an EventCodec buffer of "full" records for every live entity; the
		                        client calls it after connecting its Sim.Snapshot / Sim.Events handlers
	Only EntityController decodes Sim.* (G4.1). Implemented by EntityService.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

return {
	{ name = "Sim.Snapshot", kind = "unreliableServerEvent" },
	{ name = "Sim.Events", kind = "serverEvent" },
	{ name = "Sim.GetEntities", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{
		name = "Sim.Inspect",
		kind = "function",
		args = { Validate.integer(1, 65535) },
		rate = { burst = 6, perSecond = 3 },
	},
}
