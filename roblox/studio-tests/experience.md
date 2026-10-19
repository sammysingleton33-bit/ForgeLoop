# Studio tests — Experience (FORGE-04)

_Gate G6. Run by the user in Roblox Studio on the integrated build (`main`, or a PR build when asked). FORGE-04 never marks these as passed; record results with the BuildInfo sha in `production/quality-gates/studio-runs.md` (FORGE-05)._

Headless evidence already in place (not a substitute for these steps): Lune specs under `roblox/tests/unit/experience/` run the real Sound/ParticleEmitter instance-building code on Lune instances with engine methods (`Play`, `Emit`) stubbed. They cannot hear audio, see particles, or prove layout on a phone.

Each section ends with its own **History** (D-038 (7)): a change to one feature edits only its section, so PRs for different features never touch the same lines. There is no shared changelog.

**Before you start:** some systems need other workers' code. Each section says what it needs; if that is not on the build yet, write "blocked: needs X" instead of a result.
- Remotes: RemoteService (FL-0009, on `main`). Persistence: DataService (FL-0008) is **not** needed for VS-1. Settings and onboarding progress last for the session (D-027).
- AI Kingdoms feedback (sounds/VFX on citizens' work, announcer, music): FL-0062, with steps in `games/game-001/STUDIO_PLAYTEST.md` via FORGE-05. It needs FORGE-01's G9 events and G4.1 client signals.
- Sounds: asset ids chosen or uploaded (handoff `2026-10-12-forge-04-to-user-sounds.md`). Until then every sound is skipped on purpose.

## E1 — Analytics trail (FL-0023)
Needs: nothing beyond the build (AnalyticsService has no hard dependencies).
1. Play Solo. In Output, filter `analytics`.
2. Expect once at start: `analytics: Studio session — calls are logged here but Roblox records nothing from Studio`.
3. When your kingdom is joined (game-001 starts sessions on `KingdomJoined`, FL-0063): `analytics event SessionStart ... sent=true`, then `analytics funnel FirstMatch step=1 stepName=Spawn`.
4. Play in order (gather, place, wait for the building, recruit, capture). One `analytics funnel FirstMatch ... sent=true` line appears the first time each happens. Repeats print nothing. A step done out of order (for example a capture before your first recruit) prints nothing either, and is credited only after the earlier steps.
5. With FORGE-01's conversations: answer a citizen's "!" request. One `analytics event ConversationAnswered value=<seconds the request was open> CustomField01=<occupation> CustomField02=<decision> sent=true`, for you only (a co-ruler gets none). It comes from G9 `CitizenAnswered` (FL-0108); asking again without a new request logs nothing.
6. Stop the session mid-match: `analytics event PhaseLeft value=<minute> CustomField01=<phase>`, then `analytics event SessionEnd value=<seconds> CustomField01=<last activity>`. The last activity is your own last logged step, not `ResourceGathered` from the citizens.
Pass: no analytics line at `error` level; no script error mentioning AnalyticsService.

History:
- 2026-10-12 FORGE-04: written (FL-0023); aligned with CONTRACTS v0.4-g2 and D-027.

## E2 — Settings (FL-0024, panel FL-0103)
Needs: RemoteService. The panel is FORGE-04's SettingsPanelController (FL-0103): in game-001 it opens from the HUD rail button "Settings" into the menu drawer. Persistence across sessions also needs DataService (FL-0008, after VS-1).
1. Play Solo. Output shows `SettingsService: no DataService; settings and progress last for the session (D-027)` while FL-0008 is absent.
2. Tap the rail button "Settings": the panel opens in the drawer with three sections (Sound, Motion and effects, Gameplay). Tap it again, or open Build or Kingdom: it closes.
3. Set Music to 20% with the − button (four taps from 60%): music drops at each tap. The bar and the percentage follow; at 0% the − button greys out.
4. Turn Reduced motion on: effects lose their camera shake, and a conversation's camera cuts instead of gliding (FL-0100). With the device's Reduce Motion on and the toggle off, the row says "On in your device settings".
5. Effects quality → Reduced: build a House and watch the completion sparkle; it has visibly fewer particles than at Full, with the same motion.
6. Device emulator, a phone (844×390): every row reads on one line and every button can be tapped; scroll to reach Gameplay.
7. With DataService on the build only: leave, then Play Solo again; the values are still there.
Pass: steps 2–6 hold; step 7 holds when DataService exists. No `SettingsService` or `SettingsPanelController` error in Output. Screenshot the panel on PC and on the phone emulator (FL-0103's visual evidence; the headless render is `roblox/tests/unit/experience/scenes/settings.luau`).

History:
- 2026-10-12 FORGE-04: written (FL-0024); session-only settings (D-027).
- 2026-10-13 FORGE-04: the panel exists (FL-0103): rail button, sections, effects quality, phone layout.

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

History:
- 2026-10-12 FORGE-04: written (FL-0024).

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

History:
- 2026-10-12 FORGE-04: written (FL-0024).

## E5 — AI Kingdoms feedback: announcer, work sounds and effects, music (FL-0062, game-001)
Needs:
- the game-001 build with AnnouncerService, AnnouncerController, FeedbackController and MusicController;
- for real moments: FORGE-01's G9 producers (KingdomJoined, BuildingPlaced/Completed/Upgraded, UnitsRecruited, ObjectiveCaptured, MatchPhaseChanged, MatchEnded);
- for citizens' work: EntityController (G4.1) with the cues `deposit`, `celebrate` and the proposed client-only `swing`;
- InteractionController.gathered for the ruler's own gather;
- sounds chosen or uploaded (user sounds handoff). Until then every sound is skipped on purpose, and the effects and toasts still show.

The Studio debug panel (F8) has two commands for this section:
- `fx.announce <kind>`: one sample moment. The panel lists every kind (`AnnouncerService` SAMPLES), among them buildingCompleted, buildingPlaced, defeat, keepUpgraded, kingdomFounded, objectiveCaptured, phase, rivalCaptured, unitsRecruited, victory, and the war kinds of E14.
- `fx.burst`: six notices at once.

Rules under test (headless: `games/game-001/tests/experience/KingdomFeedback.spec.luau`):

| Rule | Value |
|---|---|
| Audience (G9 attribution) | placements and recruits: the co-rulers (the player who acted already has FORGE-03's toast); completions, upgrades and captures: the kingdom's members; a keep upgrade and a capture are also reported to rivals (a rival keep without its location); phases and the match end: everyone |
| Celebrations | kingdom founded, keep upgraded, watchtower captured, victory, defeat |
| Toasts | one line each; repeats coalesce ("House placed ×3"); silent when the moment has its own sound |
| Deposits | at most one clink per 1.5 s |
| Citizens' work sounds | at most one per citizen per 1.5 s, only within 150 studs of the camera focus (the centre of the aerial view, not the camera) |
| Placements | the placer sees FORGE-03's own notice only; co-rulers get "<building> placed" with the placer's name |
| Match end | Victory or Defeat only for a ruler who won or lost. A draw and a spectator get no toast: the slice summary shows the result line (FORGE-00 ruling). Only a client without the summary shows "A draw" / "<kingdom> wins the match". Neither plays the defeat music |
| Pooled rigs | a released rig keeps no effect |
| Music | Founding calm, Expansion build, Conflict/Endgame tension, Results calm; victory/defeat at once |

Steps
1. Play Solo. In F8, run `fx.announce kingdomFounded`: a gold burst over the ruler and "Emberhold is yours" with the founding horn (when chosen).
2. Run `fx.burst`: at most 3 toasts, "House placed ×2", the newest on top, the warning ("Frostmere took a watchtower") above info.
3. Run `fx.announce keepUpgraded`, then `objectiveCaptured`, then `victory`: each is a celebration (sound, effect, toast). The music changes to victory.
4. With FORGE-01's producers: place a House, wait for it to finish, recruit 3 soldiers and capture. Each step gives a sound, an effect at the building or rally and a toast. **One** toast for your own placement and **one** for your own recruit (FORGE-03's "House placed" and "3 soldiers recruited"). A co-ruler sees "House placed" and "+3 soldiers" with your name. The completion effect and the capture effect take your kingdom's colour.
   - Zoom the aerial view all the way out: work sounds and glints at the citizens under the view still play.
   - Join a match already in Conflict (a second client): the tension music plays at once, not only at the next phase.
   - The capture that ends the slice brings three things at once for the capturer: the "Watchtower captured" celebration, the "Victory!" celebration with its music, and FORGE-03's slice summary. Note how the stack reads: whether one hides another, whether the order is clear, and whether the summary's winner line and the toasts say the same thing twice (FORGE-05, #49 low; also STUDIO_PLAYTEST §9 step 3).
5. Watch citizens work from close up (40 studs) and far away (more than 150 studs): close up you hear the chops and hammering, with chips; far away, silence. Deposits at the storehouse clink at most about once a second and a half.
6. Phase changes (with FORGE-01's MatchService, or its `match.phase` debug command): an announcement for Expansion, "War is declared" with the war horn at Conflict, and the music changes after its minimum dwell.

Pass: all six hold. Note any sound that is too loud or repeats too often (the E3 levels), and any toast text that does not fit on a phone.

History:
- 2026-10-12 FORGE-04: moved to FL-0062 in the game tree (CONTRACTS v0.4-g2, D-026).
- 2026-10-12 FORGE-04: back in this file for FL-0062 (game-001 feedback, announcer, music) with the fx.announce and fx.burst debug commands.
- 2026-10-13 FORGE-04: FL-0062 merged (#49): one toast for your own placement and recruit (co-rulers get the announcer's); the end-of-slice stack check (FORGE-05, #49 low).
- 2026-10-13 FORGE-04: match end: no draw or spectator toast while the slice summary shows the result (FORGE-00 ruling on #49; #119).

## E6 — Fresh-player onboarding walkthrough (FL-0025 framework, game-001 onboarding v2, FL-0092)
Needs:
- RemoteService (on `main`).
- FORGE-01: KingdomService (`KingdomJoined`, `getKingdom().rulers`), the throne seat, EntityController (`pick` for citizen selection), and the G9 producers (`BuildingPlaced`, `UnitsRecruited`, `ObjectiveCaptured`); WorldService's tags (`BuildSlot`, `ObjectiveZone`).
- FORGE-04: InputModeController's selection (FL-0090, PR #29). It reports `CitizenInspected`.
- FORGE-03:
  - the citizen card;
  - the plot menu (`Build.PlaceSlot`, FL-0081, on `main`);
  - the conversation panel (`Kingdom.Choose`). The AnswerCitizen step follows FORGE-01's G9 `CitizenAnswered` from ConversationService (FL-0107), credited to the answering ruler (FL-0108); the panel reports nothing for it;
  - the Army rail button (`HUD.ArmyButton`, FL-0060).
- DataService is not needed (session-only progress, D-027).

No step waits for a system the build doesn't have:
- **Without FORGE-01's ConversationService on the build,** step 4 (AnswerCitizen) is passed over at once. Output shows `onboarding: a step's service is missing` at boot, and the card goes from the Build step straight to Recruit.
- **Without FORGE-01's MilitaryService and ObjectiveService (FL-0052),** Recruit and Capture are passed over too, and the tutorial completes after the Build step (and step 4).
- **With ConversationService but no citizen request in time,** the card nudges at 45 s and moves on at 120 s (`via=timeout`).

Each passed or timed-out step is still logged as its funnel step (Roblox counts skipped steps as done) and also as `analytics event OnboardingStepPassed` with `via=unavailable` or `via=timeout`. Write which case you saw.

Fresh player = a new Play Solo session (VS-1 keeps no progress between sessions).
1. Play Solo on the game-001 place. Filter Output for `onboarding` and `analytics funnel Onboarding`. Start a stopwatch when you spawn.
2. At spawn: the aerial view over your keep, and the card "Welcome, ruler. Your kingdom awaits.", then "Tap a citizen to see what they think".
3. Tap a citizen. Record the time (target: first meaningful interaction ≤ 30 s from spawn). The citizen card opens, and the tutorial card moves to "Build on a free plot", with the nearest plot marker highlighted.
4. Tap the highlighted plot marker (a small plot: the menu offers a House, not a Farm), choose a House and confirm. The card moves to 'A citizen with "!" has a request'. Tap a citizen with a "!" bubble and choose an answer.
5. Build a Barracks, then recruit 3 soldiers from the Army rail button (highlighted by the Recruit card), and press Send to capture. The card points at the objective until the capture, and then the "Tutorial complete" celebration plays.
6. On any step, wait 30–60 s without acting: the card border (and the arrow, where there is a target) turns gold (escalation).

Expected `env.log` order (the adapter writes every call; `sent=true` means it was handed to Roblox, which records nothing from Studio):
```
info onboarding step ... flow=vs1 step=1 stepId=Spawn via=auto
info analytics funnel Onboarding ... step=1 stepName=Spawn sent=true
info onboarding step ... step=2 stepId=InspectCitizen via=client
info analytics funnel Onboarding ... step=2 stepName=InspectCitizen sent=true
... step=3 BuildOnPlot (via=bus), 4 AnswerCitizen (via=bus), 5 Recruit (via=bus),
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

History:
- 2026-10-12 FORGE-04: written (FL-0025); rewritten for the VS-1 flow (KingdomJoined → gather → build → recruit → capture), session-only progress (D-027).
- 2026-10-12 FORGE-04: rewritten for onboarding v2 (D-030, FL-0092): inspect → build → answer → recruit → capture; passed-over steps (`requires`), the Build-button hint until FL-0081.
- 2026-10-13 FORGE-04: FL-0081 follow-ups (#99): the build hint points at the plot markers again, and the Recruit hint at the Army rail button (`HUD.ArmyButton`).
- 2026-10-13 FORGE-04: AnswerCitizen follows G9 `CitizenAnswered` (FL-0108, D-044 (3)); the panel's client report no longer counts.

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

History:
- 2026-10-12 FORGE-04: written (FL-0027).

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
| On screen | at most 8, within 160 studs of the camera focus in the overview (not the camera, so zoom never hides them) and of the camera in walk mode; reactions first, then the nearest; never on LOD-hidden rigs |
| `citizenBarks` off | hides reaction bubbles only; thoughts and placards stay (they are gameplay) |
| Targets (v0.4-g6) | a strike or cue marks exactly the citizens the server names (`entityIds`), never every citizen of the occupation; a cue with no ids shows on no citizen |
| Consequence cues | the G13.3 vocabulary in config `Vfx.luau`; a cue with a sound always has an effect; an unknown cue uses the reaction tone's pose; a continuous effect (`rest`) stops after its `seconds` (6), at the citizen's next cue, or when the rig is released |
| Conversation | the citizen's own bubble hides while their conversation panel is open |
| Aerial readability (B15, the user's first live Studio feedback) | always on top: roofs and trees never hide a bubble; a request is a round badge ("!" gold, "?" blue, "…" green, 46 px) and, with room, a card with 17 px words (2 lines at most, then "…"); bubbles keep their size at every zoom |
| Words | at most 3 bubbles show words (2 on a phone, 1 zoomed out past 150 studs), and only where the card covers no other bubble: a request is never hidden. Other requests show the badge alone; a reaction without room is not drawn (its pose, sound and effect still play) |
| New request | its badge pops twice (about 1 s); never with Reduce Motion on |
| Tap / click | a tap on a bubble selects that citizen (the card opens, as for a tap on the citizen); while placing a building, bubbles take no input |

Steps
1. Play Solo on the aerial view. Run `citizen.request <entityId> <scenarioId>`: a bubble with "!" and the scenario's thought text appears over that citizen and follows them as they walk.
2. Tap the citizen: the selection still works through the bubble (FORGE-03's card opens). Answer in the conversation panel: the bubble changes to the reaction line for about 4 s. The citizen poses (cheer, grumble, slump or salute) if FORGE-01's `playPose` exists; otherwise only the bubble shows.
3. `strike.start miner` (or the `vs1.strike` preset): every miner shows "On strike" until the strike ends, and citizens of other jobs show none. Reassign a striking miner to another job: the placard stays on the new rig, because the strike belongs to the citizen. (A consequence that strikes only the least loyal share of an occupation marks exactly those citizens; that case is covered headless in `CitizenBubbles.spec`, since no debug preset produces it before FL-0082.)
4. Zoom all the way out (about 220 studs): the bubbles under the view stay. Pan until a citizen is more than about 160 studs from the centre of the view: its bubble disappears. Pan back: it returns. With more than 8 requests open, at most 8 bubbles show, the nearest to the centre first.
   - A citizen with a request who changes job keeps the bubble on the new rig (and a striking citizen keeps the placard).
5. Settings → Citizen barks off: reaction bubbles no longer show; request bubbles and placards still do.
6. Device emulator, a small phone: bubble text is readable at the default zoom, and bubbles don't cover the HUD.
7. Answer a request whose consequence has a cue, for example `hammer` or `strike_placard`. The cue's effect plays on that citizen, with its sound if it has one. The citizen also poses if `playPose` exists. A `rest` cue shows motes on that citizen for about 6 s, then they stop.
8. Open a conversation with a citizen who has a request: their bubble hides while the panel is open and comes back when it closes. Switch to walk mode: bubbles on citizens next to the ruler show, wherever the overview was last centred.

9. Aerial readability: Play, stay in the aerial view at the start zoom, run `vs1.request` three or four times. Every request shows a badge you can spot at a glance, none hidden by a roof, tree or another bubble; the nearest ones show their words. A new request's badge pops once. Zoom all the way out: the badges stay the same size and at most one bubble keeps its words. Device emulator, a phone: badges, at most two with words.
10. Tap a request badge (and a card): the citizen is selected and FORGE-03's card opens, exactly as when tapping the citizen. Start placing a building and click where a bubble is: the placement gets the click, not the bubble.
11. Settings → Reduce Motion on, then `vs1.request`: the new badge does not pop.
12. With a mouse, in the aerial view: move over a citizen. A light outline shows on them, also through a roof, and goes when the mouse leaves them or moves over a HUD button. Click them: the outline turns gold and stays while they are selected; tap empty ground and it goes. While placing a building, and while the conversation stage shows, there is no outline.
13. Off-screen requests (B16): run `vs1.request` a few times, then pan the aerial view away from those citizens until their badges leave the screen. A gold "!" badge appears at the screen edge for each, with a gold tip pointing towards the citizen, never under the top bar, a phone's notch, the HUD rail, the crest and pills, or the bottom bar; requests that lie the same way share one badge with a count. Tap one: the camera glides there and the citizen's card opens. Pan away again and press the cycle key (table): it goes to the oldest open request, then the next, and wraps; the previous key goes back. While placing a building, in walk mode and while the conversation stage shows, there are no edge badges and the keys do nothing.

| Action | Windows | Mac | Gamepad |
|---|---|---|---|
| Next open request | F | F | DPad right |
| Previous open request | Shift+F | Shift+F | DPad left |

Probe for the Studio MCP operator (one `execute_luau`, Client context, read-only): what the bubbles show right now.
```lua
local out = {}
for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do
	if g.Name == "ForgeCitizenBubble" and g:IsA("BillboardGui") and g.Adornee then
		local text = g:FindFirstChild("Text", true)
		table.insert(out, string.format("%s %s %dx%d top=%s active=%s words=%s %q", tostring(g:GetAttribute("EntityId")),
			tostring(g:GetAttribute("BubbleKind")), g.Size.X.Offset, g.Size.Y.Offset, tostring(g.AlwaysOnTop),
			tostring(g.Active), tostring(text and text.Visible), text and text.Text or ""))
	end
end
return #out .. " bubbles\n" .. table.concat(out, "\n")
```
Expected: every bubble `top=true`; `active=true` in the aerial view (false while placing); requests `46x46 words=false` or `260x66 words=true`, at most 3 with words (2 on a phone, 1 zoomed out).

Probe for step 13 (Client context, read-only): the edge badges now.
```lua
local out = {}
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ForgeRequestIndicators")
for _, b in (gui and gui:GetChildren() or {}) do
	if b:IsA("TextButton") and b.Visible then
		local count = b:FindFirstChild("Count")
		table.insert(out, string.format("id=%s at=(%d,%d) angle=%d count=%s", tostring(b:GetAttribute("EntityId")),
			b.AbsolutePosition.X, b.AbsolutePosition.Y, b.Pointer.Rotation, count.Visible and count.Text or "1"))
	end
end
return (gui and "area " .. tostring(gui.AbsoluteSize) or "no indicator GUI") .. "\n" .. table.concat(out, "\n")
```
Expected: one line per off-screen request group, every badge inside `area`; none in build mode, walk mode or a conversation.

Pass: steps 1–13 hold. Record a short video of a request, an answer, the reaction and a strike (FL-0091's Studio evidence), and a screenshot at the start zoom and fully zoomed out with several requests (B15).

History:
- 2026-10-12 FORGE-04: written (FL-0091).
- 2026-10-13 FORGE-04: FL-0091 follow-up (#87): v0.4-g6 targets (only the citizens named), the `rest` effect ends, the speaker's bubble hides during a conversation, a placard survives a job change; step 3 expects a whole-occupation strike.
- 2026-10-15 FORGE-04: FL-0115 hover and selection outlines on citizens (step 12).
- 2026-10-15 FORGE-04: FL-0115 (B16) off-screen request badges and the cycle key (step 13, its probe; Windows/Mac/gamepad keys, D-049 (4)).
- 2026-10-15 FORGE-04: FL-0115 (B15) aerial readability (the user's first live Studio feedback): badges and cards always on top, words only where they hide nothing, new-request pop, tap selects the citizen; steps 9–11 and the operator probe.

## E9 — Reaction poses on the portrait and the world rig (FL-0100 (2/2), game-001)
Needs:
- FORGE-02's `Kit.posePortrait` (FL-0098, #85) and FORGE-03's cinematic panel (FL-0099, #126: `opened`/`closed`, `conversation.stage.portrait.model`);
- for the world rig: FORGE-01's `EntityController:playPose(entityId, name)` sampling `Feedback/ReactionPoses` (proposed in the FL-0100 handoff);
- ConversationService (FL-0079) and a citizen with a request.

Until those are on the build, write "blocked: needs posePortrait / FL-0099 / playPose".

Rules under test (headless: `games/game-001/tests/experience/ReactionPoses.spec.luau`):

| Rule | Value |
|---|---|
| Poses | cheer (happy), grumble (angry), slump (sad), salute (neutral); bow and cower for those consequence cues |
| Length | 1.4–2.0 s each, easing in over 0.25 s and out over 0.35 s; well inside the server's hold after Choose (until EndConversation, at most 12 s, v0.4-g9f) |
| Bounds | every joint within Sim/Pose limits (arms ≤ 150°, head ≤ 30°), torso lift ≤ 2 studs |
| Reduced motion | the key pose is held still until the panel closes; no movement |
| Portrait and rig | the same pose data drives both (`Feedback/ReactionPoses`) |

Steps
1. Open a conversation and give an answer whose reaction is happy, then one that is angry (or sad). The portrait plays the matching gesture for about 2 s and returns to rest; the citizen in the world plays the same gesture.
2. Answer a request whose consequence cue is `bow` or `cower`: the citizen in the world bows or cowers.
3. Settings → Reduced Motion on: the portrait holds the key pose without moving and rests when the panel closes.
4. A farmer or woodcutter holding a tool: note how the tool reads during cheer and cower (it follows the arm; a headless silhouette render showed the rake across the body).

Operator probe (one `execute_luau`, Client context, read-only; **unverified**), within about 2 s of an answer: the portrait's joints turned more than 5° from rest. Expected: two or more (both shoulders in a cheer), "at rest" about 2 s later; with Reduce Motion, held until the stage closes.
```lua
local out = {}
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("Motor6D") and d.Part0 and d.Part1 and d:FindFirstAncestorWhichIsA("ViewportFrame") then
		local _, angle = ((d.Part0.CFrame * d.C0 * d.C1:Inverse()):Inverse() * d.Part1.CFrame):ToAxisAngle()
		if math.deg(angle) > 5 then table.insert(out, d.Name .. "=" .. math.floor(math.deg(angle))) end
	end
end
return #out > 0 and table.concat(out, " ") or "at rest (or no portrait showing)"
```

Pass: steps 1–3 hold. Screenshot each gesture on the portrait (FL-0100's visual evidence; the headless render is a box silhouette, not Studio).

History:
- 2026-10-13 FORGE-04: written (FL-0100 (2/2)).
- 2026-10-15 FORGE-04: operator probe (B14 checklist); hold until EndConversation, at most 12 s (v0.4-g9f).

## E10 — Conversation camera (FL-0100 (1/2), game-001)
Needs:
- FORGE-03's cinematic panel (FL-0099, #126), firing `ConversationController.opened(entityId, position)` and `.closed(entityId)`;
- FORGE-01's ConversationService with the hold (FL-0097, #108);
- a citizen with a request.

Until those are on the build, write "blocked: needs FL-0099 / #108".

Rules under test (headless: `games/game-001/tests/experience/RulerCamera.spec.luau`):

| Rule | Value |
|---|---|
| Glide | about 0.6 s in and back; reduced motion cuts; durations clamped (≤ 3 s) |
| Framing | 30 studs from the citizen, citizen above the centre (6 studs; 12 on a phone: head at 28–30 % from the top, just under the HUD) |
| Facing | in front of the citizen's face: the line from the citizen to your ruler, which the server turns them along (v0.4-g9e) |
| Following | none once the citizen is released; without a ruler character, one turn within 1.5 s and 2 studs at most |
| Restore | the saved overview focus, rotation and zoom |

Steps
1. From the aerial view, open a conversation. The camera glides in about 0.6 s to the citizen, who stays visible above the portrait with the kingdom around them. You see the citizen's face, not their back.
2. Close it. The camera glides back to the same view: position, rotation and zoom.
3. Settings → Reduced motion on: steps 1 and 2 cut instead of gliding.
4. Pan during the glide in: the glide stops and the pan works.
5. A citizen near the map edge: the view stays inside the map.
6. Phone emulator: the citizen's head is just under the HUD stack. With short answers the whole citizen shows above the stage; with costed answers, at most the body is behind the question bubble.
7. Answer, and keep the panel open after the reaction (the stage reads for several seconds). When the citizen is released and walks off, the camera stays still; it doesn't swing round to follow them.
8. Open a conversation, switch to walk mode, close the panel, and come back to the aerial view a while later. The view is your normal overview, with no jump back to the old conversation.
9. During a conversation, zoom in (wheel or pinch): the camera doesn't move out. Zoom out: it does.

Operator probes (one `execute_luau` each, Client context, read-only; **unverified**). E10a, stage open: the rig nearest the view's line, its distance, pitch, head top on screen, and flat angles: its facing against your ruler (`facesRuler`, g9e) and the camera (`facesCam`), and the camera off the citizen-to-ruler line (`camOffLine`); -1 = no ruler character. Expected: `dist` about 30; phone `headTopY` 26–31 %; with a ruler, `facesRuler` and `camOffLine` small, so `facesCam` small (large `facesCam` with small `facesRuler` = the camera is off, not the citizen); without one, `facesCam` small after the followed turn.
```lua
local cam, best, bestOff = workspace.CurrentCamera, nil, nil
for _, m in workspace.KingdomEntities:GetChildren() do
	local rel = m:IsA("Model") and m:GetPivot().Position - cam.CFrame.Position
	local along = rel and rel:Dot(cam.CFrame.LookVector) or 0
	local off = along > 0 and (rel - cam.CFrame.LookVector * along).Magnitude
	if off and (not bestOff or off < bestOff) then best, bestOff = m, off end
end
if not best then return "no rig in front of the camera" end
local function flat(a, b) a, b = a * Vector3.new(1, 0, 1), b * Vector3.new(1, 0, 1) return (a.Magnitude < 1e-3 or b.Magnitude < 1e-3) and -1 or math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))) end
local cf, size = best:GetBoundingBox()
local head = cam:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y / 2, 0))
local char = game.Players.LocalPlayer.Character
local root, look, toCam = char and char:FindFirstChild("HumanoidRootPart"), best:GetPivot().LookVector, cam.CFrame.Position - cf.Position
local toRuler = root and root.Position - cf.Position
return string.format("id=%s dist=%.1f pitch=%.0f headTopY=%.0f%% facesRuler=%.0f facesCam=%.0f camOffLine=%.0f", tostring(best:GetAttribute("EntityId")), toCam.Magnitude, math.deg(math.asin(-cam.CFrame.LookVector.Y)), head.Y / cam.ViewportSize.Y * 100, toRuler and flat(look, toRuler) or -1, flat(look, toCam), toRuler and flat(toCam, toRuler) or -1)
```
E10b, before opening and after closing; the lines should match: `local cf = workspace.CurrentCamera.CFrame local _, yaw = cf:ToOrientation() return string.format("pos=(%.1f, %.1f, %.1f) yaw=%.1f", cf.X, cf.Y, cf.Z, math.deg(yaw))`

Pass: steps 1–9 hold. Record a short video of steps 1, 2 and 7 (FL-0100's Studio evidence).

History:
- 2026-10-13 FORGE-04: written (FL-0100 (1/2)), from the camera handoff's rows; released citizens, walk mode mid-conversation and zoom during a conversation added (FORGE-05's B14 review).
- 2026-10-15 FORGE-04: operator probes E10a/E10b; E10a also measures against the ruler direction (FORGE-05).

## E11 — Back key (FL-0053, game-001)

Needs: FORGE-03's #162 on the build (FL-0059 follow-up). In it, `KingdomHudController` holds one `InputModeController:onBack` handler while any drawer is open, the conversation stage included. Until #162 is on the build, write "blocked: needs #162". FORGE-03's U19 (`ui-economy.md`) checks each panel's own steps; E11 checks the keys and the order.

| Rule | Expected |
|---|---|
| Keys | gamepad B and keyboard Backspace (a Mac's delete key); Esc only opens Roblox's menu |
| One step per press | an open detail goes back first: the Kingdom panel's building detail to its tab; on a phone, the Build, Reputation and plot details to their lists; the conversation's confirm to its question. Otherwise the drawer closes. Closing the conversation ends it as X does, and the camera comes back. A handler registered over the drawer (topmost) goes first |
| Build mode | B and X leave build mode; that press never also counts as back |
| GUI first | Backspace while typing in a text box closes nothing; with a gamepad on a GUI button, the first B leaves the selection and the next B is back |

Steps
1. Play Solo. Open a conversation with a citizen. Press Backspace: the stage closes, and the camera glides back to where it was. Open it again and press Esc: Roblox's menu opens, and the stage stays open behind it. Talk again and pick a costly answer that asks to confirm: Backspace goes back to the question, and the next Backspace closes the stage.
2. With a gamepad (or the emulator's gamepad), open a conversation and press B: the stage closes. Open it again, move the selection onto an answer button, and press B: the selection leaves the button and the stage stays open. Press B again: it closes.
3. Open the build menu and start placing. Press B: placement ends (explore mode) and nothing else closes. Press B again: back now acts as usual.
4. Type in any text box (chat, a name field), including Backspace: no panel closes.
5. Open the Kingdom panel, then a building's detail. Backspace: back to the tab. Backspace again: the drawer closes. On the phone emulator, with a gamepad or a keyboard, do the same with a Build, a Reputation and a plot detail: each goes back to its list first. On a Mac, the delete key works like Backspace.
6. During a building move (E12; needs #140 and #148), press B: the move ends with nothing moved (B leaves edit mode; the move registers no back handler).

Pass: steps 1–6 hold.

History:
- 2026-10-13 FORGE-04: written (FL-0053 follow-up, FORGE-05's #126 L6).
- 2026-10-15 FORGE-04: topmost wins (`onBack`, FORGE-07's #130 L1); step 5, Mac delete key.
- 2026-10-15 FORGE-04: follows FORGE-03's wiring (#162): one handler for every drawer and one step per press. The confirm step and the detail steps are added, the stacked-panels case goes (one drawer at a time), and step 6 covers a move.

## E12 — Base editing: input and camera in the Move flow (FL-0121, game-001)

B17 ships the Move flow (D-052 (1)): tap your building, then **Move** in its panel; a ghost follows the pointer; then confirm with **Move here**. E12 checks the input and the camera around a move. FORGE-03's U18 (`ui-economy.md`) checks the move itself: the panel, the ghost and its tint, the words, the plot snap and the refusals.

Needs on the build:
- FORGE-01's move remotes (FL-0119, #140).
- FORGE-03's Move flow (FL-0120, #148), including its fix for FORGE-07's B1: tapping your own plot or building during a move must not open a panel or end the move.

Until both are on the build, write "blocked: needs FL-0119 / FL-0120".

| Rule | Expected |
|---|---|
| Entering | **Move** puts input in edit mode. The view is the aerial one (from walk mode it switches to it), and the building you tapped no longer has the gold selection outline |
| Taps during a move | Touch: a tap aims the ghost. On the ground it carries the ghost there; on one of your free plots the ghost snaps into it; the bar's **Move here** confirms. Mouse: the ghost follows the pointer, and a left click is **Move here** when the ghost is green (FORGE-03's PlacementInput, the same as placing). A tap or click never opens a panel or moves the camera, even on one of your buildings, and it ends the move only by confirming it. Citizens and rivals' buildings or plots are ignored |
| No hover | Citizens get no hover outline, and their bubbles take no taps |
| Camera during a move | The ghost can be carried to a spot off screen. Mouse: pan with WASD or the arrow keys and zoom with the wheel; don't pan with a left drag, because a left press confirms the move. Touch: a one-finger drag pans and pinch zooms; the press only aims, it never confirms. Q and E don't turn the view, because Q cancels the move and R / Shift+R turn the building. The right mouse button, a two-finger twist and the right stick still turn the view |
| Leaving | Move here (accepted), Cancel, Q, X or gamepad B end the move and edit mode, with nothing moved unless it was accepted. The previous view comes back (walk mode if you were walking), unless you chose a view during the move. Esc opens only Roblox's menu |
| Parked: drag gesture (FL-0123) | Not in B17; skip and write "parked, FL-0123". These rows apply once the press-and-drag gesture exists: dragging a building never pans the view, and holding the pointer within about 48 px of a screen edge pans that way, faster nearer the edge (`setEditDrag`, edge-pan) |

Steps
1. Play Solo. Press V to walk. Tap one of your houses, then **Move** in its panel. The view switches to the aerial view, the house has no gold outline, and the ghost appears where the house stands.
2. Hover a citizen: no outline. Move the pointer next to another of your buildings: the ghost follows. Click that building itself (the ghost is red over it, so the click can't move anything): no panel opens, the move stays open, and the view doesn't jump to the building.
3. Phone emulator: start a move. Tap the ground, then tap one of your free plots. The ghost moves, then snaps into the plot. No "Build here" drawer opens, and the view stays still.
4. During a move: pan with WASD and zoom with the wheel. The move stays open. Press E: the view doesn't turn. Right-drag: the view turns, and the move stays open. Phone emulator: a one-finger drag pans, the ghost goes to where the finger first touched, and the move stays open until **Move here**. (A left press confirms on a mouse, so a left drag is not a pan during a move; FORGE-07's #157 M1.)
5. Confirm with **Move here** on a free spot. After the toast, you are back in walk mode (from step 1) and tapping a citizen opens their card again. Repeat from the aerial view: the aerial view stays.
6. Start a move, then press X (or gamepad B): the move ends, nothing moved, the house is no longer dimmed, and taps select again. Repeat with Q (FORGE-03's cancel): same. Start a move and press Esc: only Roblox's menu opens.
7. (Needs FORGE-03's drag gesture, #234.) Phone emulator, two touches: hold a building 0.5 s to drag it, then put a second finger down near the right edge and move it (as if pinching). The view does not edge-pan. Move the first finger, the one holding the building, to the right edge: the view pans right. Lift it: the pan stops at once. Then the two-thumb case (FORGE-07 #239 M1): rest the left thumb on the world first, then hold a building with the right thumb until the drag starts. Slide the left thumb to the left edge: no pan. Move the right thumb to the right edge: the view pans right. Last, park a building at the right edge, hold it and don't move: the view starts panning as soon as the drag starts (#239 L2). (FORGE-07 on #234; FORGE-03's U30 step 6 checks the same.)

Pass: steps 1–6 hold.

History:
- 2026-10-15 FORGE-04: written (FL-0121, CONTRACTS G13.9 v0.4-g9j).
- 2026-10-15 FORGE-04: rewritten to the Move flow that B17 ships (D-052 (1)). The drag and edge-pan rows are parked (FL-0123). A selection in edit mode no longer pans the camera (FORGE-07's #148 B1 side effect).
- 2026-10-15 FORGE-04: on a mouse a left press confirms the move (PlacementInput), so pan with WASD during a move, and step 2 clicks the building, not the ground (FORGE-07's #157 M1).

## E13 — Consequences read from the air: riot placard, fire, notices (FL-0091, game-001)

Needs:
- FORGE-01's riot (FL-0082, on main) and its `vs1.riot` preset (`roblox/studio-tests/gameplay.md` K12).
- The notices come from G9 `ConsequenceChanged`, which FORGE-01's ConsequenceService fires (#173, on main since dd9e356).

| Rule | Expected |
|---|---|
| Riot placard | Each rioter shows a "Rioting" placard, fire orange with dark words, above its head. It is not the dark red "On strike" placard. It shows at every aerial zoom and goes when that citizen stops rioting |
| Fire | The burning building shows flames and a tall smoke column above its roof, plainly visible from the start zoom of the aerial view. They go when the fire is out. Never on the keep |
| Crackle | A crackle loop at the building. It is silent until `kingdom.fire` has an asset (P1, handoff `2026-10-16-forge-04-to-user-fire-sound.md`; status "needed"); write "silent (no asset)" |
| Notices | Each ruler of the kingdom gets one toast at the start and one at the end; a rival ruler gets none. Riot: "Riot at the storehouse!" (the burning building's name), "N rioters set it alight. Nobody works there while it burns.", then "The riot is over". Strike: "The farmers are on strike" (the job), then "The farmers are back at work". Food: "Food is running out", then "Your people have food again" |

Steps
1. Play Solo; stay in the aerial view at its start zoom. In the debug panel (F8) run the preset `vs1.riot`. Within about 2 minutes one building catches fire (K12). The flames and smoke stand clearly above its roof. Screenshot **E13-1**.
2. The rioters show orange "Rioting" placards, not "On strike". Zoom all the way out: the placards stay readable, and the fire is still visible. Screenshot **E13-2**.
3. When the riot starts, a toast reads "Riot at the <building>!" with the rioters' count, and a horn plays when sounds exist. When it ends (within 90 s), "The riot is over" replaces it, and the fire and the placards go.
4. Two players (Test → Local Server, 2 players) in different kingdoms: only the burning kingdom's ruler gets the riot toasts.
5. Phone emulator (667×375): the placards and the toast fit, with nothing cut off.

Pass: steps 1–3 hold (4 and 5 when run). Copy every red line from Output.

History:
- 2026-10-16 FORGE-04: written (FL-0091; FORGE-01's FL-0082 handoff, G9 `ConsequenceChanged` v0.4-g10c/d).

## E14 — War notices: a kingdom falls, war and peace, siege, raid, the full match's phases (FL-0130 part 1, game-001)

Needs:
- Steps 1–4 need nothing new: they use the `fx.announce` samples (F8).
- Step 5 needs the full match on the build (FORGE-01's FL-0125, `Match.mode = "match"`).
- Step 6 needs FORGE-01 to fire the proposed G9 events `WarChanged`, `SiegeChanged` and `RaidChanged` (handoff `production/handoffs/2026-10-18-forge-04-to-forge-01-war-events.md`). Until then, write "blocked: needs the war events" for step 6.
- Every sound is silent until the owner picks assets. Write "silent (no asset)"; the toasts and celebrations still show.

| Moment | Expected |
|---|---|
| `conflictTimed` | Toast "The age of war begins", body "Kingdoms may now declare war. This phase lasts 15 minutes." |
| `fallen` | A celebration: "Your keep has fallen", "You can watch the rest of the match." |
| `conquest` | A gold celebration: "You conquered Frostmere!", "Half its treasury is yours." |
| `rivalFell` | Warning toast "Frostmere has fallen", "Emberhold took its keep." |
| `warOnYou` | Warning toast "Frostmere declares war on you!", "Its soldiers may now attack your lands." |
| `peace` | Toast "Peace with Frostmere". It is a separate toast from the declaration, never "… ×2" |
| `siege` / `siegeLifted` | "Your keep is under siege!" with "Frostmere soldiers attack your keep.", then "The siege is lifted" as its own toast |
| `raid` / `raidOver` | "Enemies in your lands!" with "6 Frostmere soldiers crossed your border.", then "Your lands are clear" |

Steps
1. Play Solo. In F8, run `fx.announce conflictTimed`, then `fallen`, then `conquest`. Each reads as in the table. The two celebrations are full celebrations, not plain toasts. Screenshot **E14-1** (the conquest).
2. Run `warOnYou`, then `peace` within 5 s. Two toasts stand on screen; neither shows "×2". Then run `rivalFell`.
3. Run `raid`, then `siege`. The music changes to battle when sounds exist (otherwise check Output for no errors). Run `raidOver`, wait 10 s, run `siegeLifted`: the music returns to the phase music about 8 s later. Screenshot **E14-2** (the raid and siege toasts).
4. Phone emulator (667×375): run `raid` and `conquest`. Nothing is cut off.
5. (Needs FL-0125.) Start a full match and play, or speed up the phases. Expansion, Conflict and Endgame each show their toast with the minutes from Pacing (12, 15, 10 in `match` mode). When an AI kingdom is eliminated, every other ruler sees "<Kingdom> has fallen".
6. (Needs the war events.) Two players (Test → Local Server, 2 players) in different kingdoms. Player 1 declares war on player 2's kingdom. Player 1 gets no toast (the war panel answers them). Player 2 gets "<Kingdom> declares war on you!" with the horn. When player 2's lands are raided, player 2 gets "Enemies in your lands!".

Pass: steps 1–4 hold (5 and 6 when their features are on the build). Copy every red line from Output.

History:
- 2026-10-18 FORGE-04: written (FL-0130 part 1; D-053, Operation Crownfall).

## E15 — Battles from the air: hit flashes, kneel-and-fade deaths, building shake and collapse, raid ping, spectate camera (FL-0130 part 2, game-001)

Needs:
- Step 1 needs nothing new: `fx.announce raid` (F8).
- Steps 2–5 need a real war on the build: FORGE-01's FL-0125, where AI kingdoms fight in Conflict. The `match.phase` jump also moves the war grace (D-054 (5)). Until then, write "blocked: needs FL-0125".
- The hit flash needs FORGE-01 to send the G4 `hit` cue. The kneel needs FORGE-01's death pose. Handoff: `production/handoffs/2026-10-18-forge-04-to-forge-01-war-events.md`. Without the cue, write "no flash: no hit cue yet".
- Every sound is silent until the owner picks assets (`war.hit`, `war.collapse`). Write "silent (no asset)".
- The camera's interest focus report (`Sim.Focus`, D-055 (5)) has nothing visible. FORGE-05's bandwidth probe measures it once FORGE-01's remote exists.

| Rule | Expected |
|---|---|
| Raid beacon | A red column of sparks rises where the raid is, visible from the aerial start zoom, until "Your lands are clear" |
| Ping | G (keyboard, Windows and Mac) or D-pad up (gamepad) moves the aerial camera to the raid, also from walk mode |
| Siege beacon | While your keep is under siege, the same red column rises over your keep, and G (or FORGE-03's rail button) goes there first, even during a raid. When the siege lifts its beacon goes, and G goes to the raid again if one is still on |
| Hit flash | A soldier or citizen that is hit flashes white for a moment, with a few bright sparks. No blood, ever |
| Death | The fallen kneel or lie down, then fade out over about a second. Nobody stays on the field. A rig reused later is fully visible |
| Building hit | Dust and stone chips at the roof, and the building jolts briefly (no jolt with Reduced motion on). It stands exactly where it was afterwards |
| Collapse | A destroyed building leaves a large dust cloud and debris where it stood. The camera shakes a little if it is near (not with Reduced motion or Camera shake off). A cancelled construction site never collapses. A new match never collapses the old world. Known limit: if two kingdoms' keeps fall in the same update, that batch looks like a new world and shows no collapse |
| Spectate | When your keep falls, the camera moves to the first battle or a standing keep. `.` (period) or R1 goes to the next target and `,` (comma) or L1 to the previous one. You can still pan and zoom. Results ends it, and it never starts again during Results or Lobby; a player who joins during Results starts watching when the next match begins, if still not seated |

Steps
1. Play Solo, aerial view. Run `fx.announce raid`: the toast, plus a red beacon at the map centre. Press G: the camera goes there. Switch to walk mode (V), press G again: the aerial view comes back, at the beacon. Run `fx.announce raidOver`: the beacon goes. Screenshot **E15-1** (the beacon from the start zoom).
2. (Needs FL-0125.) Start a full match, jump to Conflict (`match.phase Conflict`), and watch an AI war from the air. Hits flash (when the cue exists), the dead fade out, and buildings under attack jolt and throw dust. Screenshot **E15-2**.
3. (Needs FL-0125.) Turn Reduced motion on (Settings) and watch an attack again: the dust stays, and no building jolts.
4. (Needs FL-0125.) Watch a building being destroyed: dust cloud and debris. When a whole kingdom falls, at most six collapse at once, with one crash. Screenshot **E15-3**.
5. Still in Play Solo: run `fx.announce raid`, then `fx.announce siege`. Two beacons: the map centre and 40 studs from it (the stand-in keep). G goes to the keep's. `fx.announce raidOver`: the centre beacon goes, the keep's stays, G still goes to the keep. `fx.announce siegeLifted`: no beacon left. (Needs FL-0125 for a real one: in an AI war, when an enemy first hits your keep, the beacon rises over your keep.) Screenshot **E15-4**.
6. (Needs FL-0125; two players, or let an AI conquer you.) When your keep falls: "Your keep has fallen", then the camera moves to a battle or a standing keep. Cycle with `.` and `,` (R1 / L1). At Results the camera is yours again.

Pass: steps 1 and 5 hold (2–4 and 6 when FL-0125 is on the build). Copy every red line from Output.

History:
- 2026-10-18 FORGE-04: written (FL-0130 part 2).
- 2026-10-18 FORGE-04: spectating never starts during Results or Lobby (FORGE-07's #189 M1); the two-keeps-in-one-batch limit noted (FORGE-07 on #183).
- 2026-10-19 FORGE-04: the siege beacon on your keep, ahead of a raid (step 5; FORGE-00's FL-0130 close-out).

## E16 — Duel controls: keyboard and mouse, gamepad, touch (FL-0075, game-001)

The Crown Arena duel (D-029, design `crown-arena.md` §5) is fought on foot. During the `duel` stage the champion's input switches to arena mode: five actions go to FORGE-01's DuelController, which sends them to the server. Spectators keep the camera only.

Needs:
- Steps 1–5: nothing beyond the build. They use the **Studio preview**: the duel controls without a duel. A press sends nothing and prints `InputModeArenaController preview: <action>` in Output.
- Steps 6–7: FORGE-01's arena (FL-0071: `Arena.State`, DuelController). Until then write "blocked: needs FL-0071".

| Action | Keyboard + mouse | Gamepad | Touch button |
|---|---|---|---|
| light | left click | R1 | **Light** (the biggest, left of jump) |
| heavy | R | R2 | **Heavy** |
| block (hold) | hold F | hold L1 | hold **Block** |
| parry | E | L2 | **Parry** |
| dodge | Q | B | **Dodge** |

Steps
1. Play Solo. In the command bar run `game.Players:GetPlayers()[1]:SetAttribute("ForgeDuelPreview", true)` (server or client view both work: a player's attributes replicate to its client). The camera goes from the aerial view to the walk camera behind your ruler. WASD walks and Space jumps. V does nothing.
2. Press each key in the table once. Output prints one `preview:` line per press with the right action. Hold F for 2 s, then release it: `block` on the press, `blockEnd` on the release, nothing in between. Q and E do not turn the camera; Backspace closes nothing. Click a HUD button (for example the rail's **Settings**): it opens, and Output prints **no** `preview: light` for that click (FORGE-07's #191 L1: the left click is bound at High priority for the duel; a GUI click must stay the GUI's). If it does print, write it down: that is a bug.
3. Gamepad (or Studio's gamepad emulator): R1, R2, L2 and B print light, heavy, parry and dodge. Holding L1 prints block, then blockEnd on release. The left stick walks.
4. Phone emulator (667×375, then an iPad size). Five round buttons stand around Roblox's jump button, right side, none covering it or each other; the labels read clearly, and the thumbstick still shows on the left. Tap each: one `preview:` line each. Hold **Block** and slide the finger off before lifting it: `blockEnd` prints when the finger lifts. Screenshot **E16-1** (the phone layout) and **E16-2** (the iPad layout).
5. Run `game.Players:GetPlayers()[1]:SetAttribute("ForgeDuelPreview", false)`. The buttons go, the aerial view comes back, V toggles the view again, and Q / E turn the view again.
6. (Needs FL-0071.) Two players (Test → Local Server, 2 players) qualify for the arena. At the `duel` stage both get the walk camera and the controls; every action works against the other champion. A third player watching gets neither the controls nor the buttons.
7. (Needs FL-0071.) Hold block when the duel ends: at `crowning` the controls and buttons go and the aerial view returns. Output shows no error.

Pass: steps 1–5 hold (6 and 7 when FL-0071 is on the build). Copy every red line from Output. Write down any button that is hard to reach with the right thumb on the phone emulator.

History:
- 2026-10-18 FORGE-04: written (FL-0075; G12.6 DRAFT).
- 2026-10-18 FORGE-04: step 2 checks that a HUD click is not also a light attack (FORGE-07's #191 L1).

## E17 — The arena crowd you hear and read: reactions, subtitles, ducking (FL-0074 part 2a, game-001)

The Crown Arena crowd reacts to the duel by each stand's support tier (crown-arena §3, §7), and every reaction has a subtitle. The stands' figures come later (part 2b, after FORGE-02's FL-0072).

Needs:
- Steps 1–4: nothing beyond the build. They use the **Studio preview**, a scripted duel played through the real code path.
- Step 5: FORGE-01's arena (FL-0071: `Arena.State`, `Arena.Events`). Until then write "blocked: needs FL-0071".
- Every crowd sound is silent until the owner picks assets (`production/handoffs/2026-10-18-forge-04-to-user-crowd-sounds.md`). Write "silent (no asset)". The subtitles show either way.

Steps
1. Play Solo. In the command bar run `game.Players:GetPlayers()[1]:SetAttribute("ForgeCrowdPreview", "adoring,hostile")`. Within 30 s, about every 3.5 s, one or two subtitle lines appear above the bottom HUD, for example "Crimson: (The crowd roars)" and "Azure: (The stand turns its back)". Each line goes after about 2.5 s. Screenshot **E17-1** with two lines on screen.
2. During the preview: "Crimson: Mara steps up: Reforge!" (a perk) stays about 4 s and is not replaced early. A chant line reads "Crimson: Crimson! Crimson!". The last step is the ending: "(The stand floods the arena to crown its ruler)" for Crimson and "(The stand empties)" for Azure.
3. Run it again with `"hostile,adoring"`: Crimson now boos or turns its back, and the ending reads "(A thin crowd watches the crowning)" for Crimson and "They fought for us! (The stand salutes)" for Azure. Then `""` stops it and the lines go.
4. Phone emulator (667×375): the two subtitle boxes fit inside the screen and don't cover the bottom HUD buttons. The longest lines, the ending's "(The stand floods the arena to crown its ruler)" and the salute, wrap onto a second line inside their box and are not cut off (FORGE-07's #199 M1). Screenshot **E17-2**. Then also turn on the duel preview (E16 step 1, `ForgeDuelPreview`) and run the crowd preview again: the boxes now sit left of the duel's touch buttons, just above the thumbstick, never on a button or on the thumbstick, and well below the top of the screen. Screenshot **E17-3**. Then hold and drag the thumbstick while the lines show (the champion can walk in the duel): the stick, its ring and your thumb stay below the lowest box, and every line stays readable. If they cover a line, note how far (FORGE-07 on #199).
5. (Needs FL-0071.) In a real duel, a big hit and a parry make both stands react, and an announcer line makes the crowd quieter for about 2.5 s (once sounds exist). At crowning, the ending lines show once, and they go at Results. A perk names its citizen and the perk ("Mara steps up: Reforge!"). A duel that is called off (a draw: cancelled, or both champions drop) shows "(The duel was called off)" for both stands and nothing else.

Pass: steps 1–4 hold (5 when FL-0071 is on the build). Copy every red line from Output.

History:
- 2026-10-18 FORGE-04: written (FL-0074 part 2a; G12 DRAFT).
- 2026-10-18 FORGE-04: step 4 checks the lines keep clear of the duel's touch buttons (FORGE-03 on #199).
- 2026-10-19 FORGE-04: two-line boxes and the kingdom's short name, so the longest lines are not cut off (FORGE-07's #199 M1).
- 2026-10-19 FORGE-04: step 4 also holds the thumbstick under the lowest box (FORGE-07 on #199).
- 2026-10-19 FORGE-04: step 5 checks the perk names and the called-off ending (DuelService's Arena.Events relay, FORGE-00's draw ruling).

## E18 — The arena intro: a camera pass over both stands, the arena music and the stingers (FL-0074 part 2b, game-001)

At the arena's intro, everyone's overview camera passes over the two stands and settles on the ring, so each side sees its own crowd (crown-arena §7 "Intro"). The arena music plays from the intro to the crowning. A horn opens the intro, and a fanfare crowns a winner.

Needs:
- Steps 1–3: FORGE-02's arena on the build (FL-0072, #217: `Workspace.World.Arena.CrownArena`). Without it, write "blocked: needs FL-0072". They use the **Studio preview**, the same pass the real intro plays.
- Steps 4–5: FORGE-01's arena (FL-0071: `Arena.State`). Until then write "blocked: needs FL-0071".
- The music and the stingers are silent until the owner picks them (`production/handoffs/2026-10-19-forge-04-to-user-arena-sounds.md`). Write "silent (no asset)". While `music.arena` has no asset, the arena keeps the match music (battle or phase) instead of going silent (FORGE-07 #231 M1).

Steps
1. Play Solo, aerial camera. In the command bar run `game.Players:GetPlayers()[1]:SetAttribute("ForgeArenaPreview", "a")`. The camera glides to stand **B** (about 4 s, the stand fills the view and its seats face the ring), then to stand **A**, then to the ring seen from stand A's side. It stops there; no snap back. Screenshot **E18-1** on each stand and on the ring.
2. Run it again with `"b"`: A first, then B, then the ring from B's side. Then `"neutral"`: A, B, the ring from A's side. During a pass, drag the view, turn it (Q / E) or scroll: the pass stops at once and the camera is yours. `""` ends a preview.
3. Settings → Reduced motion on, then the `"a"` preview: three cuts, each held about 4 s, with no gliding. Turn reduced motion off again.
4. (Needs FL-0071.) In a real arena: at the intro the horn plays once and the pass runs behind FORGE-03's versus card, the card stays readable, and the pass ends on the ring before the duel starts (it fits the intro, at most 15 s). Watch it as a ruler of each duelling kingdom and of a third one.
5. (Needs FL-0071.) The arena music plays from the intro and over any battle music, until the crowning ends. A crowning with a winner, or a single qualifier crowned without a duel, plays the fanfare once; a called-off duel shows "(The duel was called off)" and plays no fanfare. At Results the match's own music comes back.

Pass: steps 1–3 hold (4 and 5 when FL-0071 is on the build). Copy every red line from Output.

History:
- 2026-10-19 FORGE-04: written (FL-0074 part 2b; G12 v0.4-g11e).

## E19 — Full-match tips: war, siege, raid, ram and the Crown Arena (FL-0137, game-001)

Needs:
- The full match on the build (FORGE-01's FL-0125, `Match.mode = "match"`), with at least one AI rival.
- The war events on the server: `WarChanged` (MatchHost), `SiegeChanged` and `RaidChanged` (Sim/WarWatch). These are on `main`.
- For the siege tip's "Press G or tap the marked button": FORGE-04's siege alert (#235). Without it, G and the rail button answer raids only.
- For the gold stroke on the Kingdom button and the Raid rail button: FORGE-03's `HUD.KingdomButton` and `HUD.RaidButton` (#232). Without them the tips show with no mark.
- For the Crown Arena tip: FORGE-01's ArenaService (FL-0071). Without it that tip never shows (Output: `onboarding: a step's service is missing` for `tip_crown_arena`), because the build has no duel to promise.
- For the ram tip: FORGE-01's MilitaryService. Without it the ram tip never shows (Output: `onboarding: a step's service is missing` for `tip_ram`).
- DataService is not needed. Without it each tip shows once per session, not once ever (D-027).

| Tip | Shows when | Card |
|---|---|---|
| `tip_war_open` | Conflict starts | "Conflict: war is open" |
| `tip_war_on_you` | a rival declares war on your kingdom | "A rival declared war on you" |
| `tip_siege` | your keep is besieged | "Your keep is under siege!" |
| `tip_raid` | enemies enter your lands | "Raiders in your lands!" |
| `tip_ram` | your soldiers besiege an enemy keep | "Your army is at their keep" |
| `tip_crown_arena` | Endgame starts | "Endgame: the race for the crown" |

Rules for every tip:
- A tip uses the onboarding card. Its button reads "Got it", and it has no step counter.
- A tip hides by itself after 12 s, or sooner when its situation ends (the siege lifted, the raid over, peace made, you declared war, you recruited).
- A tip never freezes the camera, blocks taps or opens a panel.
- A tip shows over an unfinished tutorial step, and the tutorial's card comes back when the tip ends.

Steps
1. Play Solo in a full match. Filter Output for `onboarding`. Speed up the phases, or play to Conflict. When Conflict starts, "Conflict: war is open" shows and hides by itself about 12 s later. You can pan, zoom and tap while it shows. Screenshot **E19-1**.
2. Declare war on a rival from the Kingdom panel. If the war tip is still showing, it hides at once. Wait for (or provoke) a raid and a siege on your keep. "Raiders in your lands!" and "Your keep is under siege!" each show once. Press "Got it" on one: it hides at once, and Output shows `onboarding tip dismissed`. Screenshot **E19-2** (the siege tip).
3. Let a second raid or siege come. No tip shows again.
4. Send soldiers to an enemy keep. When the siege starts, "Your army is at their keep" shows (it needs MilitaryService). Recruit any unit: the tip hides.
5. (Needs ArenaService.) Reach Endgame. "Endgame: the race for the crown" shows. On a 667×375 phone, its body and the Conflict tip's body each fit inside the card, on two lines (FORGE-07 #236 L1).
6. Settings → turn hints off, then start a new session and repeat step 1. No tip shows. The tutorial card still shows.
7. Phone emulator (667×375): repeat step 2. The tip and its "Got it" button are not cut off, and the button is easy to tap.
8. (Two players, Test → Local Server, 2 players, different kingdoms.) Player 1 declares war on player 2's kingdom. Player 2 sees "A rival declared war on you"; player 1 does not.

Pass: steps 1–7 hold (8 when two players can join). Write which tips you saw, and copy every red line from Output.

History:
- 2026-10-19 FORGE-04: written (FL-0137; D-053, Operation Crownfall).
