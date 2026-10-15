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
3. When your kingdom is joined (game-001 starts sessions on `KingdomJoined`, FL-0063): `analytics event SessionStart ... sent=true`, then `analytics funnel VS1 step=1 stepName=Spawn`.
4. Play in order (gather, place, wait for the building, recruit, capture). One `analytics funnel VS1 ... sent=true` line appears the first time each happens. Repeats print nothing. A step done out of order (for example a capture before your first recruit) prints nothing either, and is credited only after the earlier steps.
5. Stop the session mid-match: `analytics event PhaseLeft value=<minute> CustomField01=<phase>`, then `analytics event SessionEnd value=<seconds> CustomField01=<last activity>`. The last activity is your own last logged step, not `ResourceGathered` from the citizens.
Pass: no analytics line at `error` level; no script error mentioning AnalyticsService.

History:
- 2026-10-12 FORGE-04: written (FL-0023); aligned with CONTRACTS v0.4-g2 and D-027.

## E2 — Settings (FL-0024)
Needs: RemoteService and a settings panel (FORGE-03 components; until it exists write "blocked: no settings UI"). Persistence across sessions also needs DataService (FL-0008, after VS-1).
1. Play Solo. Output shows `SettingsService: no DataService; settings and progress last for the session (D-027)` while FL-0008 is absent.
2. In the settings panel set Music to 20% and Reduced Motion on: music drops at once; effects lose their camera shake.
3. With DataService on the build only: leave, then Play Solo again; the values are still there.
Pass: step 2 holds; step 3 holds when DataService exists. No `SettingsService` error in Output.

History:
- 2026-10-12 FORGE-04: written (FL-0024); session-only settings (D-027).

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
- `fx.announce <kind>`: one sample moment. Kinds: buildingCompleted, buildingPlaced, defeat, keepUpgraded, kingdomFounded, objectiveCaptured, phase, rivalCaptured, unitsRecruited, victory.
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
  - the conversation panel, which reports `CitizenAnswered` after a successful `Kingdom.Choose`;
  - the Army rail button (`HUD.ArmyButton`, FL-0060).
- DataService is not needed (session-only progress, D-027).

No step waits for a system the build doesn't have:
- **Without FORGE-01's ConversationService on the build,** step 4 (AnswerCitizen) is passed over at once. Output shows `onboarding: a step's service is missing` at boot, and the card goes from the Build step straight to Recruit.
- **Without FORGE-01's MilitaryService and ObjectiveService (FL-0052),** Recruit and Capture are passed over too, and the tutorial completes after the Build step (and step 4).
- **With ConversationService but without the panel's `CitizenAnswered` report,** the card nudges at 45 s and moves on at 120 s.

Each passed or timed-out step is still logged as its funnel step (Roblox counts skipped steps as done) and also as `analytics event OnboardingStepPassed` with `via=unavailable` or `via=timeout`. Write which case you saw.

Fresh player = a new Play Solo session (VS-1 keeps no progress between sessions).
1. Play Solo on the game-001 place. Filter Output for `onboarding` and `analytics funnel Onboarding`. Start a stopwatch when you spawn.
2. At spawn: the aerial view over your keep, and the card "Welcome, ruler. Your kingdom awaits.", then "Tap a citizen to see what they think".
3. Tap a citizen. Record the time (target: first meaningful interaction ≤ 30 s from spawn). The citizen card opens, and the tutorial card moves to "Build on a free plot", with the nearest plot marker highlighted.
4. Tap a plot marker, choose a House or Farm and confirm. The card moves to 'A citizen with "!" has a request'. Tap a citizen with a "!" bubble and choose an answer.
5. Build a Barracks, then recruit 3 soldiers from the Army rail button (highlighted by the Recruit card), and press Send to capture. The card points at the objective until the capture, and then the "Tutorial complete" celebration plays.
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

History:
- 2026-10-12 FORGE-04: written (FL-0025); rewritten for the VS-1 flow (KingdomJoined → gather → build → recruit → capture), session-only progress (D-027).
- 2026-10-12 FORGE-04: rewritten for onboarding v2 (D-030, FL-0092): inspect → build → answer → recruit → capture; passed-over steps (`requires`), the Build-button hint until FL-0081.
- 2026-10-13 FORGE-04: FL-0081 follow-ups (#99): the build hint points at the plot markers again, and the Recruit hint at the Army rail button (`HUD.ArmyButton`).

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

Pass: steps 1–12 hold. Record a short video of a request, an answer, the reaction and a strike (FL-0091's Studio evidence), and a screenshot at the start zoom and fully zoomed out with several requests (B15).

History:
- 2026-10-12 FORGE-04: written (FL-0091).
- 2026-10-13 FORGE-04: FL-0091 follow-up (#87): v0.4-g6 targets (only the citizens named), the `rest` effect ends, the speaker's bubble hides during a conversation, a placard survives a job change; step 3 expects a whole-occupation strike.
- 2026-10-15 FORGE-04: FL-0115 hover and selection outlines on citizens (step 12).
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

Needs: FORGE-03's conversation stage and drawer menus registered with `InputModeController:onBack` (#126 L6). Until they are on the build, write "blocked: needs FORGE-03's back subscription".

| Rule | Expected |
|---|---|
| Keys | gamepad B and keyboard Backspace (a Mac's delete key); Esc only opens Roblox's menu |
| Topmost wins | one press closes only the panel opened last (a drawer opened over the stage closes first) |
| Build mode | B and X leave build mode; that press never also counts as back |
| GUI first | Backspace while typing in a text box closes nothing; with a gamepad on a GUI button, the first B leaves the selection and the next B is back |

Steps
1. Play Solo. Open a conversation with a citizen. Press Backspace: the stage closes. Open it again and press Esc: Roblox's menu opens, and the stage stays open behind it.
2. With a gamepad (or the emulator's gamepad), open a conversation and press B: the stage closes. Open it again, move the selection onto an answer button, and press B: the selection leaves the button and the stage stays open. Press B again: it closes.
3. Open the build menu and start placing. Press B: placement ends (explore mode) and nothing else closes. Press B again: back now acts as usual.
4. Type in any text box (chat, a name field), including Backspace: no panel closes.
5. Open a drawer menu, then a conversation over it (or the reverse). Each press closes one panel, the last opened first. On a Mac, the delete key works like Backspace.

Pass: steps 1–5 hold.

History:
- 2026-10-13 FORGE-04: written (FL-0053 follow-up, FORGE-05's #126 L6).
- 2026-10-15 FORGE-04: topmost wins (`onBack`, FORGE-07's #130 L1); step 5, Mac delete key.

## E12 — Base editing: input and camera (FL-0121, game-001)

Needs: FORGE-01's move remotes (FL-0119: `Build.CanMove`, `Build.Move`, `Build.MoveToSlot`) and FORGE-03's edit UI (FL-0120), which sets `InputModeController:set("edit")` and calls `RulerCameraController:setEditDrag(true/false)` around a drag. Until both are on the build, write "blocked: needs FL-0119 / FL-0120".

| Rule | Expected |
|---|---|
| Taps while editing | only your own buildings and your own kingdom's plots are selected; citizens, a rival's buildings and plots, and the ground select nothing |
| Camera | edit mode uses the aerial view (walk mode comes back after, unless you chose a view meanwhile); selecting one of your buildings pans to it |
| Dragging a building | the drag never pans the view; holding the pointer near a screen edge (about 48 px) pans that way, faster nearer the edge |
| Leaving | X or gamepad B leaves edit mode; hover outlines and citizen bubbles take no input while editing |

Steps
1. Enter edit mode (FORGE-03's Edit button). Tap a citizen, a rival's building, the ground: nothing is selected. Tap one of your buildings: it is selected and the view pans to it. Tap a free plot of yours: it is selected as a target.
2. Drag a building across the screen: the view stays still. Hold it near the right edge: the view pans right; near the top: forward. Drop it: the panning stops.
3. Phone emulator: the same with one finger; a one-finger drag of the building never pans.
4. Press X (or gamepad B): edit mode ends; from walk mode, the walk view comes back.

Pass: steps 1–4 hold.

History:
- 2026-10-15 FORGE-04: written (FL-0121, CONTRACTS G13.9 v0.4-g9j).
