# Studio tests — Experience (FORGE-04)

_Gate G6. Run by the user in Roblox Studio on the integrated build (`main`, or a PR build when asked). FORGE-04 never marks these as passed; record results with the BuildInfo sha in `production/quality-gates/studio-runs.md` (FORGE-05)._

Headless evidence already in place (not a substitute for these steps): Lune specs under `roblox/tests/unit/experience/` run the real Sound/ParticleEmitter instance-building code on Lune instances with engine methods (`Play`, `Emit`) stubbed. They cannot hear audio, see particles, or prove layout on a phone.

**Before you start:** some systems need other workers' code. Each section says what it needs; if that is not on the build yet, write "blocked: needs X" instead of a result.
- Remotes: RemoteService (FL-0009, on `main`). Persistence: DataService (FL-0008) is **not** needed for VS-1. Settings and onboarding progress last for the session (D-027).
- AI Kingdoms feedback (sounds/VFX on citizens' work, announcer, music): FL-0062, with steps in `games/game-001/STUDIO_PLAYTEST.md` via FORGE-05. It needs FORGE-01's G9 events and G4.1 client signals.
- Sounds: asset ids chosen or uploaded (handoff `2026-10-12-forge-04-to-user-sounds.md`). Until then every sound is skipped on purpose.

## E1 — Analytics trail (FL-0023)
Needs: nothing beyond the build (AnalyticsService has no hard dependencies).
1. Play Solo. In Output, filter `analytics`.
2. Expect once at start: `analytics: Studio session — calls are logged here but Roblox records nothing from Studio`.
3. When your kingdom is joined (game-001 starts sessions on `KingdomJoined`, FL-0063): `analytics event SessionStart ... sent=true`, then `analytics funnel VS1 step=1 stepName=Spawn`.
4. Play: one `analytics funnel VS1` line the first time each of gather, place, complete, recruit and capture happens, never twice.
5. Stop the session mid-match: `analytics event PhaseLeft value=<minute> CustomField01=<phase>`, then `analytics event SessionEnd value=<seconds> CustomField01=<last activity>`. The last activity is your own last logged step, not `ResourceGathered` from the citizens.
Pass: no analytics line at `error` level; no script error mentioning AnalyticsService.

## E2 — Settings (FL-0024)
Needs: RemoteService and a settings panel (FORGE-03 components; until it exists write "blocked: no settings UI"). Persistence across sessions also needs DataService (FL-0008, after VS-1).
1. Play Solo. Output shows `SettingsService: no DataService; settings and progress last for the session (D-027)` while FL-0008 is absent.
2. In the settings panel set Music to 20% and Reduced Motion on: music drops at once; effects lose their camera shake.
3. With DataService on the build only: leave, then Play Solo again; the values are still there.
Pass: step 2 holds; step 3 holds when DataService exists. No `SettingsService` error in Output.

## E3 — Audio budget and levels (FL-0024)
Needs: sound assets (at least the P0 list in the user handoff).
Budgets (initial, FL-0032 refines):

| Budget | Value | Enforced by |
|---|---|---|
| Concurrent SFX/UI/voice/ambience voices | ≤ 8 | AudioController (`Audio.spec.luau` "keeps at most 8 voices") |
| Music tracks | 1 (2 only during a 1.5 s crossfade) | AudioController.setMusic |
| Ambience beds | ≤ 2 | AudioController.setAmbience |
| Per-id instances / cooldown | per registry entry | AudioController |

Steps
1. Open the sandbox place, Play Solo, open the Developer Console → Memory → "Sounds" (performance-optimization/identify.md lists that label). Note the value.
2. Trigger a burst of 20 UI clicks quickly. Expect at most 2 overlapping clicks (maxInstances) and no audible clipping.
3. Listen at the default volumes on laptop speakers **and** a phone (or the phone's headphones): UI sounds sit below music; warnings (alarm bell) are clearly louder than ambience; no sound is harsh at full master volume.
4. Set Master to 0: everything is silent. Set Music to 0 with Master 100%: only music is silent.
Pass: all four hold; record the Sounds memory value.

## E4 — VFX budget and look (FL-0024)
Needs: nothing for the presets themselves (built-in textures); kingdom signals for the in-game triggers.
Budgets (initial, FL-0032 refines):

| Budget | Value | Enforced by |
|---|---|---|
| Emitters per preset | ≤ 2 | `VfxPresets.validate` (spec "every shipped preset is valid") |
| Estimated live particles per preset (burst + rate × max lifetime) | ≤ 300 | `VfxPresets.validate` |
| Emitter rate | ≤ 100 /s ("100 per second on mobile", effects/particle-emitters.md) | `VfxPresets.validate` |
| Particle lifetime | ≤ 5 s (house) | `VfxPresets.validate` |
| Live particles on screen, all presets | ≤ 600; ≤ 16 active effects | VFXController (spec "keeps live particles on screen within budget") |

Steps (until a debug panel exists, FORGE-05's tools or a temporary LocalScript can call `VFXController:play(id, { position = ... })` for each factory id in `roblox/src/shared/Experience/VfxPresets.luau` and each game id registered by FL-0062):
1. Play every preset once at a visible spot; screenshot each. Judge: readable at gameplay distance, matches its name, no square/blocky texture artefacts (built-in textures unverified).
2. Graphics quality 1 and 10 (Studio: File → Studio Settings → Rendering → Editor Quality Level, both lowest and highest, as effects/particle-emitters.md advises). Effects still read at quality 1.
3. Device emulator: a low-end phone profile. Play the heaviest looping preset on 12 spots plus the heaviest burst (the spec's stress case: about 576 + 160 estimated particles, so the on-screen cap evicts the lowest priority). Note FPS in the MicroProfiler (Ctrl+F6) or the Developer Console.
4. Turn the in-game Reduced Motion setting on (or the Roblox menu's Reduce Motion): a preset with shake (`levelup.column` has none; use a game preset with `shake`) shows fewer particles and **no** camera shake request.
Pass: screenshots reviewed (G5 note committed by FORGE-04 after the user shares them), FPS on the low-end profile ≥ 30 with the stress case, reduced motion behaves as above.

## E5 — AI Kingdoms feedback (moved)
The kingdom-specific feedback moved to the game tree with CONTRACTS v0.4-g2 (D-026): sounds and VFX on citizens' work, the announcer, the music by match phase, and citizen reactions. That is FL-0062 (`games/game-001/src/{shared/Feedback,client/Controllers/{Feedback,Music,Announcer}*}`). Its Studio steps go into `games/game-001/STUDIO_PLAYTEST.md` through FORGE-05. The framework parts it uses are checked by E3 and E4.

## E6 — Fresh-player onboarding walkthrough (FL-0025 framework, game-001 VS-1 flow)
Needs:
- RemoteService (on `main`).
- FORGE-01: KingdomService (`KingdomJoined`, `getKingdom().rulers`), the G9 producers (`ResourceGathered`, `BuildingPlaced`, `BuildingCompleted`, `UnitsRecruited`, `ObjectiveCaptured`), and WorldService's tags (`ResourceNode`, `BuildZone`, `ObjectiveZone`).
- FORGE-03: the HUD targets `HUD.BuildButton` and `HUD.Recruit`.
- DataService is not needed (session-only progress, D-027).

Fresh player = a new Play Solo session (VS-1 keeps no progress between sessions).
1. Play Solo on the game-001 place. Filter Output for `onboarding` and `analytics funnel Onboarding`. Start a stopwatch when you spawn.
2. At spawn: the card "Welcome, ruler. Your citizens are already at work.", then "Gather from a tree or rock", with an arrow and highlight on the **nearest** resource node.
3. Gather once. Record the time (target: first meaningful interaction ≤ 30 s from spawn). The card moves to "Build a House or a Farm" and the Build button is outlined.
4. Place a House or Farm. The card says "Your builders are on their way" until it completes.
5. Build a Barracks, recruit 3 soldiers, press Send to capture. The card points at the objective until the capture.
6. On any step with a target, wait 30–60 s without acting: the card border and arrow turn gold (escalation).

Expected `env.log` order (the adapter writes every call; `sent=true` means it was handed to Roblox, which records nothing from Studio):
```
info onboarding step ... flow=vs1 step=1 stepId=Spawn via=auto
info analytics funnel Onboarding ... step=1 stepName=Spawn sent=true
info onboarding step ... step=2 stepId=Gather via=bus
info analytics funnel Onboarding ... step=2 stepName=Gather sent=true
... step=3 PlaceBuilding (via=bus), 4 BuildingComplete (via=bus or via=satisfied when a co-ruler built first),
    5 Recruit (via=bus), 6 Capture (via=bus)
info analytics event OnboardingCompleted ... CustomField01=vs1 sent=true
```
The same order is asserted headlessly by `games/game-001/tests/experience/Onboarding.spec.luau` ("runs the whole slice for co-rulers with the G9 attribution rules").

**Skip path** (new session): at step 2 press **Skip tutorial**. Expect:
- `onboarding skipped ... lastStep=1`;
- `analytics event OnboardingSkipped value=1 CustomField01=Spawn`;
- the card disappears;
- **no further** `analytics funnel Onboarding` line for the rest of the session.

**Co-rulers** (Studio Party Simulator, 2 players in one party): both see their own card. When one ruler's building completes, the other's "BuildingComplete" step completes as soon as they reach it.

**Phone check** (Studio device emulator, a small phone):
- the card fits the width with margins and does not cover the thumbstick or jump button;
- Skip is tappable (≥ 44 px);
- the text is readable.

Pass: all timings recorded and within target; the log order matches; skip and co-ruler behaviour as above.

## Changelog
- 2026-10-12 FORGE-04: E1–E5 (FL-0023, FL-0024); E6 onboarding walkthrough (FL-0025).
- 2026-10-12 FORGE-04: aligned with CONTRACTS v0.4-g2 and D-027. Session-only settings and progress; E5 moved to FL-0062 (game tree); E6 rewritten for the VS-1 flow (KingdomJoined → gather → build → recruit → capture).
