--!strict
--[[
	Sim/Remotes — entity replication remotes (CONTRACTS G4, area "Sim"). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Sim.<Action>.

	Server -> client
		Sim.Snapshot(buffer)    UnreliableRemoteEvent; one SnapshotCodec v2 buffer per event (≤ 900 B);
		                        seq keeps increasing across matches (a reset never restarts it),
		                        ~10 per second; moving entities every snapshot, idle and working ones
		                        round-robin about once per second. Slice: every client gets every entity; full match: interest tiers (Sim.Focus).
		Sim.Events(buffer)      reliable; one EventCodec buffer per tick when anything happened: spawn,
		                        despawn, job changes, the cues deposit / hit / die / celebrate, reset; and
		                        per kingdom, to its members only, the G13.3 conversation events (thought,
		                        reaction, strike, kcue) in their own buffer (EntityService:sendKingdomEvent)
	Client -> server
		Sim.Focus(focus: Vector3)  one-way (no answer): where the player's camera looks, for interest tiers (D-055 (5)).
		                        Y is ignored, X/Z are clamped to the wire's range; at most ~5 per second (the client
		                        sends <= 4/s with a 1 s keepalive); anything older than config Match.interest.
		                        focusStaleSeconds (3 s) is ignored and the character's position is used instead.
		                        Interest only: it changes which entities a player's snapshots carry, never the
		                        simulation or what the player may do.
		Sim.Inspect(entityId: integer) -> CitizenService:inspect result, own kingdom only (G8); nil otherwise
		Sim.GetEntities(afterId?) -> (buffer, nextAfterId?)   an EventCodec buffer of "full" records, one
		                        page (<= 900 B) of the live entities with id > afterId by ascending id;
		                        nextAfterId is nil on the last page. The client calls it after connecting
		                        its Sim.Snapshot / Sim.Events handlers, then again with nextAfterId (FL-0109)
	Only EntityController decodes Sim.* (G4.1). Implemented by EntityService.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

return {
	{ name = "Sim.Snapshot", kind = "unreliableServerEvent" },
	{ name = "Sim.Events", kind = "serverEvent" },
	{
		name = "Sim.GetEntities",
		kind = "function",
		args = { Validate.optional(Validate.integer(0, 65535)) },
		-- a page per call: 24 at once covers 1,176 entities, the refill keeps a reconnect loop cheap
		rate = { burst = 24, perSecond = 6 },
	},
	{
		name = "Sim.Focus",
		kind = "event",
		args = { Validate.vector3(4000) },
		rate = { burst = 8, perSecond = 5 },
	},
	{
		name = "Sim.Inspect",
		kind = "function",
		args = { Validate.integer(1, 65535) },
		rate = { burst = 6, perSecond = 3 },
	},
}
