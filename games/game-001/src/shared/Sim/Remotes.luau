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
		                        despawn, job changes, the cues deposit / hit / die / celebrate, reset
	Client -> server
		Sim.GetEntities() -> buffer   an EventCodec buffer of "full" records for every live entity; the
		                        client calls it after connecting its Sim.Snapshot / Sim.Events handlers
	Only EntityController decodes Sim.* (G4.1). Implemented by EntityService.
]]

return {
	{ name = "Sim.Snapshot", kind = "unreliableServerEvent" },
	{ name = "Sim.Events", kind = "serverEvent" },
	{ name = "Sim.GetEntities", kind = "function", rate = { burst = 3, perSecond = 1 } },
}
