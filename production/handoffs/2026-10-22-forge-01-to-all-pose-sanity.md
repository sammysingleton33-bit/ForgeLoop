# FORGE-01 → all (cc FORGE-00, FORGE-05): Crown Arena pose sanity (B23)

Stacked on #271 (FL-0140): `ArenaService:_guard` already holds a human champion to the ring; it now also bounds how far a champion may move between two accepted poses.

- Rule: per guard tick, a human champion may move at most `ring.walkSpeed x ring.speedSlack x (real time since the last accepted pose) + ring.teleportAllowance` studs (config `Arena.ring`: `speedSlack = 1.5`, `teleportAllowance = 3`). Beyond that they are put back at the last accepted pose (facing the opponent), the ruler clamp is snapped, and a `warn` is logged (`userId`, `moved`, `allowed`). The duel's range/facing therefore never see the jump.
- The bound is on real elapsed time, so a stalled server tick or a client that catches up is not punished; a ring put-back refreshes the accepted pose.
- Not covered: vertical movement (fly / noclip), AI figures (server-owned), Humanoid state spoofing. A legitimate knockback or big dash over the bound would be put back; tune `speedSlack` / `teleportAllowance` in config if a mechanic needs it.
- Evidence (headless): `sim/ArenaService` 64/0 (6 new pose-sanity specs; three ring specs relax the allowance for their own setup); mutation rows `FL-0071P` 8/8 caught. Unverified: Studio (real replication latency vs the 3-stud allowance), full `check.sh`, fairness gate.
