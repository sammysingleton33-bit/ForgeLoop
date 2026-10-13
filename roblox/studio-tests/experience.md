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

## E5 — AI Kingdoms feedback: announcer, work sounds and effects, music (FL-0062, game-001)
Needs:
- the game-001 build with AnnouncerService, AnnouncerController, FeedbackController and MusicController;
- for real moments: FORGE-01's G9 producers (KingdomJoined, BuildingPlaced/Completed/Upgraded, UnitsRecruited, ObjectiveCaptured, MatchPhaseChanged, MatchEnded);
- for citizens' work: EntityController (G4.1) with the cues `deposit`, `celebrate` and the proposed client-only `swing`;
- InteractionController.gathered for the ruler's own gather;
- sounds chosen or uploaded (user sounds handoff). Until then every sound is skipped on purpose, and the effects and toasts still show.

The Studio debug panel (F8) has two commands for this section:
- `fx.announce <kind>`: one sample moment. Kinds: buildingCompleted, buildingPlaced, defeat, keepUpgraded, kingdomFounded, objectiveCaptured, phase, rivalCaptured, unitsRecruited, victory.
- `fx.burst`: six notices at once.

Rules under test (headless: `games/game-001/tests/experience/KingdomFeedback.spec.luau`):

| Rule | Value |
|---|---|
| Audience (G9 attribution) | buildings, recruits, captures: the kingdom's members; a keep upgrade and a capture are also reported to rivals (a rival keep without its location); phases and the match end: everyone |
| Celebrations | kingdom founded, keep upgraded, watchtower captured, victory, defeat |
| Toasts | one line each; repeats coalesce ("House placed ×3"); silent when the moment has its own sound |
| Deposits | at most one clink per 1.5 s |
| Citizens' work sounds | at most one per citizen per 1.5 s, only within 150 studs of the camera |
| Pooled rigs | a released rig keeps no effect |
| Music | Founding calm, Expansion build, Conflict/Endgame tension, Results calm; victory/defeat at once |

Steps
1. Play Solo. In F8, run `fx.announce kingdomFounded`: a gold burst over the ruler and "Emberhold is yours" with the founding horn (when chosen).
2. Run `fx.burst`: at most 3 toasts, "House placed ×2", the newest on top, the warning ("Frostmere took a watchtower") above info.
3. Run `fx.announce keepUpgraded`, then `objectiveCaptured`, then `victory`: each is a celebration (sound, effect, toast). The music changes to victory.
4. With FORGE-01's producers: place a House, wait for it to finish, recruit 3 soldiers and capture. Each step gives a sound, an effect at the building or rally and a toast. A co-ruler sees the same toasts, with your name on "placed".
5. Watch citizens work from close up (40 studs) and far away (more than 150 studs): close up you hear the chops and hammering, with chips; far away, silence. Deposits at the storehouse clink at most about once a second and a half.
6. Phase changes (with FORGE-01's MatchService, or its `match.phase` debug command): an announcement for Expansion, "War is declared" with the war horn at Conflict, and the music changes after its minimum dwell.

Pass: all six hold. Note any sound that is too loud or repeats too often (the E3 levels), and any toast text that does not fit on a phone.

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

## E7 — Notifications and celebrations (FL-0027)
Needs:
- the build with NotificationController (this PR's stack);
- for steps 2–3, FORGE-03's kingdom HUD (PR #19), which sends its notices through `NotificationController:show`;
- for step 4, the E6 tutorial run.
Until FL-0062 adds the `fx.announce` debug commands (F8 panel), the toasts come from real play.

Rules under test (headless specs: `roblox/tests/unit/experience/Notification.spec.luau`):

| Rule | Value |
|---|---|
| Visible at once | 3, in the top right (or where the HUD places them), newest on top; ScreenGui DisplayOrder 70 with CoreUISafeInsets; below the onboarding card while it shows |
| Priority | error = warning > achievement > reward > success = info; a higher one replaces the oldest lower one when full |
| Waiting | at most 8; the rest are dropped, lowest priority and oldest first |
| Repeats | the same notice adds "×N" and refreshes its time (at most 12 s after it first showed); no repeated sound |
| Durations | info/success 3.5 s, reward 4 s, warning/error/achievement 5 s (clamped 1–10 s) |
| Setting `notifications = important` | only warnings, errors, achievements and celebrations |
| Celebrations | own sound + effect + silent toast; the same moment within 1 s plays once; a different moment of that kind within 1 s shows its toast without a second fanfare |

Steps
1. Play Solo, filter Output for `NotificationController`: expect no error line.
2. Place three buildings quickly (FORGE-03's build menu). You see one toast per kind of notice, with "×2"/"×3" on repeats, never more than 3 cards, and the newest on top. A tap on a card dismisses it.
3. Settings → Notifications → Important. Place a building: no "placed" toast. A warning or error notice from the HUD, if one comes up, still shows. Set it back to All.
4. Finish the tutorial (E6): a "Tutorial complete" toast with the onboarding.complete sound (when chosen, user sounds handoff) and the gold burst over the ruler. Skipping the tutorial in a new session shows no celebration.
5. Device emulator, a small phone: the stack stays inside the safe area, does not cover the top bar or the thumbstick, and its text is readable; each card is at most about half the screen wide.
6. Same phone, during the tutorial (E6) with HUD notices coming in: the toasts start below the onboarding card, and Skip and the step counter stay visible and tappable.

Pass: steps 1–6 hold. Note anything that feels noisy (too many toasts in a busy minute) for the FL-0062 tuning.

## E8 — Citizen bubbles, reactions and strike placards (FL-0091, game-001)
Needs:
- FORGE-01's EntityController (G4.1) re-emitting the G13.3 `Sim.Events` kinds as `EntityController.event(entityId, "thought" | "reaction" | "strike" | <cue>, payload, model)`;
- ConversationService (FL-0079) and FORGE-03's conversation panel;
- the debug presets `citizen.request` and `strike.start` (G13.7, FORGE-05).

Until those are on the build, write "blocked: needs EntityController thought/reaction events".

Rules under test (headless: `games/game-001/tests/experience/CitizenBubbles.spec.luau`):

| Rule | Value |
|---|---|
| Bubbles per citizen | 1. A reaction replaces the thought; a strike placard shows when nothing else does |
| Text | only from the event, at most 80 characters (an ellipsis beyond) |
| Meaning | "!" request, "?" concern, "…" idea; placards say "On strike"; never colour alone |
| Lifetimes | thought 45 s or until answered; reaction 4 s; placard until the strike ends |
| On screen | at most 8, within 160 studs of the camera focus (not the camera, so zoom never hides them); reactions first, then the nearest; never on LOD-hidden rigs |
| `citizenBarks` off | hides reaction bubbles only; thoughts and placards stay (they are gameplay) |
| Consequence cues | the G13.3 vocabulary in config `Vfx.luau`; a cue with a sound always has an effect; an unknown cue uses the reaction tone's pose |

Steps
1. Play Solo on the aerial view. Run `citizen.request <entityId> <scenarioId>`: a bubble with "!" and the scenario's thought text appears over that citizen and follows them as they walk.
2. Tap the citizen: the selection still works through the bubble (FORGE-03's card opens). Answer in the conversation panel: the bubble changes to the reaction line for about 4 s. The citizen poses (cheer, grumble, slump or salute) if FORGE-01's `playPose` exists; otherwise only the bubble shows.
3. `strike.start miner`: each striking miner shows "On strike" until the strike ends.
4. Zoom all the way out (about 220 studs): the bubbles under the view stay. Pan until a citizen is more than about 160 studs from the centre of the view: its bubble disappears. Pan back: it returns. With more than 8 requests open, at most 8 bubbles show, the nearest to the centre first.
   - A citizen with a request who changes job keeps the bubble on the new rig.
5. Settings → Citizen barks off: reaction bubbles no longer show; request bubbles and placards still do.
6. Device emulator, a small phone: bubble text is readable at the default zoom, and bubbles don't cover the HUD.
7. Answer a request whose consequence has a cue, for example `hammer` or `strike_placard`. The cue's effect plays on that citizen, with its sound if it has one. The citizen also poses if `playPose` exists.

Pass: steps 1–7 hold. Record a short video of a request, an answer, the reaction and a strike (FL-0091's Studio evidence).

## Changelog
- 2026-10-12 FORGE-04: E1–E5 (FL-0023, FL-0024); E6 onboarding walkthrough (FL-0025).
- 2026-10-12 FORGE-04: aligned with CONTRACTS v0.4-g2 and D-027. Session-only settings and progress; E5 moved to FL-0062 (game tree); E6 rewritten for the VS-1 flow (KingdomJoined → gather → build → recruit → capture).
- 2026-10-12 FORGE-04: E7 notifications and celebrations (FL-0027).
- 2026-10-12 FORGE-04: E8 citizen bubbles, reactions and strike placards (FL-0091).
- 2026-10-12 FORGE-04: E6 rewritten for onboarding v2 (D-030, FL-0092): inspect → build on a plot → answer → recruit → capture.
- 2026-10-12 FORGE-04: E5 back in this file for FL-0062 (game-001 feedback, announcer, music) with the fx.announce and fx.burst debug commands.
