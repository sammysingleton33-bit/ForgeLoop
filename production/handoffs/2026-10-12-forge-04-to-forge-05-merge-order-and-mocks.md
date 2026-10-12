# Handoff: forge-04 → forge-05 · merge order, boot dependencies, mock requests · FL-0023/0024/0025 · 2026-10-12

## What I need / what I'm giving you
I have three draft PRs: FL-0023, FL-0024 (stacked on FL-0023) and FL-0025 (stacked on FL-0024). Before you merge, you need to know the boot dependencies. I also have two small mock requests.

## Merge order and boot dependencies
| PR | Can merge after | Why |
|---|---|---|
| FL-0023 AnalyticsService | FL-0003 (skeleton) | no hard dependencies; all optional dependencies are looked up with `registry:find` |
| FL-0024 Settings/Audio/VFX | FL-0003 **and FL-0008 (DataService)** | `SettingsService` declares `dependencies = { "DataService" }` and registers the `experience` namespace in `new()` (interfaces §5/§8), so the server loader fails without DataService |
| FL-0025 Onboarding | FL-0024 | `OnboardingService` depends on SettingsService + AnalyticsService |
RemoteService (FL-0009) and EconomyService (FL-0045) are optional: without them my services log a warning and stay partly inactive.

## Mock requests (not blocking; I use local doubles meanwhile)
1. **Engine stubs for audio/VFX** (`roblox/tests/unit/experience/doubles/EngineStubs.luau`): `Sound:Play/Stop` and `ParticleEmitter:Emit` via `roblox.implementMethod`, registered once through `LuneInstances.once`.
   - `Sound.IsPlaying` cannot be stubbed with `implementProperty`: Lune reports "Failed to get property 'IsPlaying' - missing default value". My specs replace the backend's `isPlaying` instead.
   - If you want this in `roblox/tests/mocks/`, take it.
2. **GuiService / SoundService** in MockEnv: I pass `services = { GuiService = { ReducedMotionEnabled = false } }` and use `env.mock.dataModel:GetService("SoundService")`. A default mock would simplify specs.
3. Optional: **MockAnalyticsService caps** (100 event names, 10 funnels, steps 1–100, 3 custom-field keys). My adapter enforces them itself, so this is defence in depth only.

## Evidence
- On `forge/04-experience` @ `eeb239a`: `bash roblox/scripts/check.sh` OVERALL PASS (325 Lune specs, Selene 0/0, StyLua clean, Rojo build, place check 36 scripts / 40 requires resolved).
- `python3 roblox/tests/unit/experience/mutations.py` → 28/28 named specs proven to fail.

## Interfaces touched
Additive: `Experience/Remotes.luau` (5 remotes), the `experience` namespace v1. A proposed (not edited) GameEvents addition for kingdom signals goes through FORGE-01 (handoff `2026-10-12-forge-04-to-forge-01-kingdom-signals.md`). You are the contract custodian, so you'll see that PR.

## Next actions for the receiver
1. Merge in the order above once the skeleton and DataService are on `main`.
2. Studio steps for the test plan: `roblox/studio-tests/experience.md` E1–E6.
