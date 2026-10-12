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
3. When FORGE-01's PlayerReady exists: `analytics event SessionStart ... sent=true`.
4. Stop the session: `analytics event SessionEnd value=<seconds> CustomField01=<last activity>`.
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

## E6 — Fresh-player onboarding walkthrough (FL-0025 framework, game-001 onboarding v2, FL-0092)
Needs:
- RemoteService (on `main`).
- FORGE-01: KingdomService (`KingdomJoined`, `getKingdom().rulers`), the throne seat, EntityController (`pick` for citizen selection), and the G9 producers (`BuildingPlaced`, `UnitsRecruited`, `ObjectiveCaptured`); WorldService's tags (`BuildSlot`, `ObjectiveZone`).
- FORGE-04: InputModeController's selection (FL-0090, PR #29). It reports `CitizenInspected`.
- FORGE-03:
  - the citizen card;
  - the plot menu;
  - the conversation panel, which reports `CitizenAnswered` after a successful `Kingdom.Choose`;
  - the HUD target `HUD.Recruit`.
- DataService is not needed (session-only progress, D-027).

If the conversation panel is not on the build yet, step 4 cannot complete: use Skip, and write "blocked: no CitizenAnswered".

Fresh player = a new Play Solo session (VS-1 keeps no progress between sessions).
1. Play Solo on the game-001 place. Filter Output for `onboarding` and `analytics funnel Onboarding`. Start a stopwatch when you spawn.
2. At spawn: the aerial view over your keep, and the card "Welcome, ruler. Your kingdom awaits.", then "Tap a citizen to see what they think".
3. Tap a citizen. Record the time (target: first meaningful interaction ≤ 30 s from spawn). The citizen card opens, and the tutorial card moves to "Build on a free plot", with the nearest plot marker highlighted.
4. Build a House or Farm on a plot. The card moves to 'A citizen with "!" has a request'. Tap a citizen with a "!" bubble and choose an answer.
5. Build a Barracks, recruit 3 soldiers, press Send to capture. The card points at the objective until the capture, and then the "Tutorial complete" celebration plays.
6. On any step, wait 30–60 s without acting: the card border (and the arrow, where there is a target) turns gold (escalation).

Expected `env.log` order (the adapter writes every call; `sent=true` means it was handed to Roblox, which records nothing from Studio):
```
info onboarding step ... flow=vs1 step=1 stepId=Spawn via=auto
info analytics funnel Onboarding ... step=1 stepName=Spawn sent=true
info onboarding step ... step=2 stepId=InspectCitizen via=client
info analytics funnel Onboarding ... step=2 stepName=InspectCitizen sent=true
... step=3 BuildOnPlot (via=bus), 4 AnswerCitizen (via=client), 5 Recruit (via=bus),
    6 Capture (via=bus, or via=satisfied when a co-ruler captured first)
info analytics event OnboardingCompleted ... CustomField01=vs1 sent=true
```
The same order is asserted headlessly by `games/game-001/tests/experience/Onboarding.spec.luau` ("runs the whole v2 slice for co-rulers with the G9 attribution rules").

**Skip path** (new session): at step 2 press **Skip tutorial**. Expect:
- `onboarding skipped ... lastStep=1`;
- `analytics event OnboardingSkipped value=1 CustomField01=Spawn`;
- the card disappears;
- **no further** `analytics funnel Onboarding` line for the rest of the session.

**Co-rulers** (Studio Party Simulator, 2 players in one party): both see their own card. When one ruler's soldiers capture the tower, the other's "Capture" step completes as soon as they reach it. Each player's own build counts only for them.

**Phone check** (Studio device emulator, a small phone):
- the card fits the width with margins and does not cover the HUD;
- Skip is tappable (≥ 44 px);
- the text is readable.

Pass: all timings recorded and within target; the log order matches; skip and co-ruler behaviour as above.

## Changelog
- 2026-10-12 FORGE-04: E1–E5 (FL-0023, FL-0024); E6 onboarding walkthrough (FL-0025).
- 2026-10-12 FORGE-04: aligned with CONTRACTS v0.4-g2 and D-027. Session-only settings and progress; E5 moved to FL-0062 (game tree); E6 rewritten for the VS-1 flow (KingdomJoined → gather → build → recruit → capture).
- 2026-10-12 FORGE-04: E6 rewritten for onboarding v2 (D-030, FL-0092): inspect → build on a plot → answer → recruit → capture.
