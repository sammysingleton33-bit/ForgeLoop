# Studio tests — Experience (FORGE-04)

_Gate G6. Run by the user in Roblox Studio on the integrated build (`main`, or a PR build when asked). FORGE-04 never marks these as passed; record results with the BuildInfo sha in `production/quality-gates/studio-runs.md` (FORGE-05)._

Headless evidence already in place (not a substitute for these steps): Lune specs under `roblox/tests/unit/experience/` run the real Sound/ParticleEmitter instance-building code on Lune instances with engine methods (`Play`, `Emit`) stubbed. They cannot hear audio, see particles, or prove layout on a phone.

**Before you start:** some systems need other workers' code. Each section says what it needs; if that is not on the build yet, write "blocked: needs X" instead of a result.
- Settings, onboarding persistence: FORGE-01 DataService (FL-0008) and RemoteService (FL-0009).
- Kingdom feedback: FORGE-01 kingdom signals + `Gameplay.KingdomEvent` remote and the `Citizen` tag (handoff `2026-10-12-forge-04-to-forge-01-kingdom-signals.md`).
- Sounds: asset ids chosen/uploaded (handoff `2026-10-12-forge-04-to-user-sounds.md`). Until then every sound is skipped on purpose.

## E1 — Analytics trail (FL-0023)
Needs: nothing beyond the build (AnalyticsService has no hard dependencies).
1. Play Solo. In Output, filter `analytics`.
2. Expect once at start: `analytics: Studio session — calls are logged here but Roblox records nothing from Studio`.
3. Expect `analytics: waiting for bus events not declared yet events=...` listing the kingdom signals until FORGE-01 declares them.
4. When FORGE-01's PlayerReady exists: `analytics event SessionStart ... sent=true`.
5. Stop the session: `analytics event SessionEnd value=<seconds> CustomField01=<last activity>`.
Pass: no analytics line at `error` level; no script error mentioning AnalyticsService.

## E2 — Settings (FL-0024)
Needs: DataService, RemoteService, and a settings panel (FORGE-03 components; until it exists write "blocked: no settings UI").
1. Play Solo in a place with Studio access to API services enabled (DataStores).
2. In the settings panel set Music to 20% and Reduced Motion on. Leave, then Play Solo again.
Pass: values persist across sessions; Output shows no `SettingsService` warning other than "RemoteService not loaded" when RemoteService is absent.

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

Steps (until a debug panel exists, FORGE-05's sandbox tools or a temporary LocalScript can call `VFXController:play(id, { position = ... })` for each id in `roblox/src/shared/Experience/VfxPresets.luau`):
1. Play every preset once at a visible spot; screenshot each. Judge: readable at gameplay distance, matches its name, no square/blocky texture artefacts (built-in textures unverified).
2. Graphics quality 1 and 10 (Studio: File → Studio Settings → Rendering → Editor Quality Level, both lowest and highest, as effects/particle-emitters.md advises). Effects still read at quality 1.
3. Device emulator: a low-end phone profile. Play `kingdom.siege.burning` on 12 buildings plus `kingdom.victory`. Note FPS in the MicroProfiler (Ctrl+F6) or the Developer Console.
4. Turn the in-game Reduced Motion setting on (or the Roblox menu's Reduce Motion): `kingdom.siege.impact` shows fewer particles and **no** camera shake request.
Pass: screenshots reviewed (G5 note committed by FORGE-04 after the user shares them), FPS on the low-end profile ≥ 30 with the stress case, reduced motion behaves as above.

## E5 — Kingdom feedback (FL-0024)
Needs: FORGE-01 kingdom signals, `Gameplay.KingdomEvent`, `Citizen` tags, `KingdomId` player attribute; NotificationController (FL-0027) for toasts.
1. Start a match. Expect: founding horn + toast "Your kingdom is founded", calm music.
2. Assign a citizen: an "Aye!"-style bubble over that citizen, acknowledgement sound.
3. Place a farm: dust puff + thunk; nearby citizens say "To work!". When it completes: sparkle + flourish + toast "Farm complete"; two farms completing within 2 s show one toast that counts "×2".
4. Harvest: "+N Food" floats over the farm; one harvest sound per 1.5 s even with many farms.
5. Upgrade the kingdom: fanfare, golden column, achievement toast.
6. Have a rival attack you: alarm bell + warning toast + citizens "Raiders!", music switches to battle within 1 s and returns to the match music about 8 s after the fight ends.
7. Win the match: victory fanfare/music and the victory effect.
8. Mute the game: every event above still shows a visual (accessibility rule, spec "with a visual for every sound").
Pass: every step observed; note anything that felt late (> 0.2 s), noisy or repetitive.

## E6 — Fresh-player onboarding walkthrough (FL-0025)
Needs: DataService + RemoteService (FORGE-01); for the AI Kingdoms flow also the kingdom signals, the `OnboardingCastle`, `OnboardingTownHall` and `Citizen` tags, the HUD targets `HUD.Resources` / `HUD.BuildButton` with `ResourceInspected` / `GoalAcknowledged` reports (FORGE-03), and the `Crowns` currency. The sandbox flow (`games/sandbox/config/Onboarding.luau`) needs only DataService, RemoteService, ShopViewed and the round events.

Fresh player: in Studio use a test place with an empty DataStore (or delete key `u_<UserId>` of `ForgeProfiles_v1` first).
1. Play Solo; filter Output for `onboarding` and `analytics funnel Onboarding`. Start a stopwatch at spawn.
2. Within 3 s: the card "Welcome, ruler. This land is yours." then "Walk to your castle" with an arrow over the castle. Record the time.
3. Walk 8+ studs: card advances to "Your banner marks your kingdom". Record the time (target: first meaningful interaction ≤ 30 s from spawn).
4. Walk to the castle; tap the Food counter; assign a citizen; place a farm; wait for the first harvest; record the time of "+25 Crowns" (target ≤ 3 min).
5. Upgrade the Town Hall; acknowledge the goal card (or wait 10 s).
6. Do nothing for 15 s on any step with an arrow: the card border and arrow turn gold (escalation).

Expected `env.log` order (the adapter writes every call; `sent=true` means it was handed to Roblox, which records nothing from Studio):
```
info onboarding step ... step=1 stepId=Arrive via=auto
info analytics funnel Onboarding ... step=1 stepName=Arrive sent=true
info onboarding step ... step=2 stepId=MoveRuler via=client
info analytics funnel Onboarding ... step=2 stepName=MoveRuler sent=true
... step=3 FindKingdom, 4 CheckResources (via=client or via=timeout), 5 AssignCitizen (via=bus),
    6 PlaceFarm (via=bus or via=satisfied), 7 FirstHarvest (via=bus), 8 UpgradeHall (via=bus), 9 NextGoal
info analytics event OnboardingCompleted ... CustomField01=first_session sent=true
```
The same order is asserted headlessly by `Onboarding.spec.luau` ("a full first session logs every funnel step in order").

Skip path (new fresh player): at step 2 press **Skip tutorial**. Expect `onboarding skipped ... lastStep=2`, `analytics event OnboardingSkipped value=2 CustomField01=MoveRuler`, the card disappears, and **no further** `analytics funnel Onboarding` line for the rest of the session or after rejoining.

Resume path: complete up to "Build a farm", leave, rejoin. Expect the card to resume at "Build a farm" (or the next step if the farm was placed) and no repeated `analytics funnel Onboarding step=1` line.

Phone check (Studio device emulator, a small phone): the card fits the width with 16 px margins, does not cover the thumbstick or jump button, Skip is tappable (≥ 44 px), text is readable.

Pass: all timings recorded and within target, the log order matches, skip and resume behave as above.

## Changelog
- 2026-10-12 FORGE-04: E1–E5 (FL-0023, FL-0024); E6 onboarding walkthrough (FL-0025).
