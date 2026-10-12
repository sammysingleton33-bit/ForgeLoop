# Handoff: forge-04 → forge-05 · merge order, boot dependencies, mock requests · FL-0023/0024/0025 · 2026-10-12

## What I need / what I'm giving you
I have four PRs: FL-0061 (independent), then FL-0023 → FL-0024 → FL-0025 (stacked). Before you merge, check the order below. I also have two small mock requests.

## Merge order and boot dependencies
| PR | Can merge after | Notes |
|---|---|---|
| FL-0061 PacingService (#15) | `main` | independent; game tree; no dependencies |
| FL-0023 AnalyticsService + Subjects | `main` | no hard dependencies; game-001 `Analytics.luau` validated by a game spec |
| FL-0024 Settings / Audio / VFX | FL-0023 | **no DataService dependency any more (D-027)**: SettingsService finds DataService in `start()` and keeps a session store when it is absent. AudioController skips cleanly when SoundService is not an Instance (the boot gate's unmocked guard) |
| FL-0025 Onboarding | FL-0024 | game-001 VS-1 flow + `Feedback/Signals.luau` (G9 attribution) |
The game-001 boot gate passes on each of these heads (`check.sh` step "game-001 specs").

## Mock requests (not blocking; I use local doubles meanwhile)
1. **Engine stubs for audio/VFX** (`roblox/tests/unit/experience/doubles/EngineStubs.luau`): `Sound:Play/Stop` and `ParticleEmitter:Emit` via `roblox.implementMethod`, registered once through `LuneInstances.once`.
   - `Sound.IsPlaying` cannot be stubbed with `implementProperty`: Lune reports "Failed to get property 'IsPlaying' - missing default value". My specs replace the backend's `isPlaying` instead.
   - If you want this in `roblox/tests/mocks/`, take it.
2. **GuiService / SoundService** in MockEnv: I pass `services = { GuiService = { ReducedMotionEnabled = false } }` and use `env.mock.dataModel:GetService("SoundService")`. A default mock would simplify specs, and would let the boot gate exercise audio for real instead of my "unavailable" skip.
3. Optional: **MockAnalyticsService caps** (100 event names, 10 funnels, steps 1–100, 3 custom-field keys). My adapter enforces them itself, so this is defence in depth only.

## Evidence
- Per-PR `check.sh` results are in each PR body. `python3 roblox/tests/unit/experience/mutations.py` → 40/40 named specs proven to fail (framework and game-001 rows).

## Interfaces touched
Additive: `Experience/Remotes.luau` (5 remotes), the `experience` namespace v1. A proposed (not edited) GameEvents addition for kingdom signals goes through FORGE-01 (handoff `2026-10-12-forge-04-to-forge-01-kingdom-signals.md`). You are the contract custodian, so you'll see that PR.

## Next actions for the receiver
1. Merge in the order above once the skeleton and DataService are on `main`.
2. Studio steps for the test plan: `roblox/studio-tests/experience.md` E1–E6.
