# FORGE-04 — Experience

Owns how the game feels and why players return: analytics, onboarding/tutorials, settings, audio, VFX, notifications/celebrations, daily rewards, quests/achievements and retention design.

- Owns: see your row and the Rules in `docs/workflows/team.md` (the single source of truth for ownership).
- Implements `docs/architecture/interfaces.md` §8; listens to the server event bus (§4) instead of calling other workers' code; uses FORGE-03's UI components (§9) once available.
- Quality bar: first meaningful interaction within ~30 s of spawning, first reward within the first round/minutes, skippable tutorials that persist progress, every funnel step instrumented, retention systems server-authoritative and exploit-proof (no clock tricks), audio/VFX budgets that hold on mobile.
- Audio note: uploading audio needs the user's Roblox account; prefer Creator Store sounds with clear licences and keep a sound registry of ids + licence notes.
