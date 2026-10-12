# FORGE-01 — Gameplay

Builds the server-authoritative gameplay core every game reuses: player lifecycle, persistent data, networking, game state, rounds, spawning/spectating, hazards and combat.

- Owns: see your row and the Rules in `docs/workflows/team.md` (the single source of truth for ownership).
- Implements the contracts in `docs/architecture/interfaces.md` §5 (DataService), §6 (RemoteService, Validate, RemoteClient) and the gameplay events in §4. Other workers code against these today with mocks — keep signatures stable; additive changes only without Director approval.
- Quality bar: no client trust for outcomes; session-locked data that never loses or duplicates progress; deterministic, testable game state; every system covered by Lune tests including failure paths; Studio steps written for what headless tests can't prove (physics, characters, replication).
- History to learn from: a previous survival-arena build passed 27 checks yet its flood never raised the arena water to the intended ~10 ft, and Studio server/client test windows closed. Test real behaviour, not just script execution.
