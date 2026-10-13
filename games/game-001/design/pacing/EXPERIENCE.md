# AI Kingdoms — first-session experience (FORGE-04)

_Status: design plus headless-tested systems, revised after FORGE-00's review (`production/handoffs/2026-10-13-forge-00-to-forge-04-doc-reviews.md` §3). **Nothing has been seen or heard in Studio yet**; gate G6 belongs to the user (`roblox/studio-tests/experience.md`, `games/game-001/STUDIO_PLAYTEST.md`). Anything marked *target* is a tuning goal for playtests, not a measured result. Last updated 2026-10-13._

Companion docs:
- `PACING.md`: phase lengths and minute targets.
- `analytics/schemas/events.md`: what we measure.

Contracts:
- `games/game-001/CONTRACTS.md` v0.4-g9c: G3 (`MatchService.mode`), G4.1, G9 (incl. the v0.4-g6 funnel order), G11 (client-reported steps, D-044 (4)), G12 (VS-2 draft), G13.3, G13.6, G13.8.
- `DECISIONS.md` D-020–D-044 (esp. D-027, D-029, D-030, D-033, D-036, D-038, D-044).

## 1. Experience pillars
1. **"This kingdom is mine."** Within 15 seconds the player knows which banner, keep and border are theirs.
2. **Every order gets an answer.** Every action produces a response within about 0.2 s *(target)*. Examples: selecting a citizen opens the card with a soft tap sound; an answered request plays its reaction pose and bubble; citizen deposits show "+N Wood". Silence after a click is a bug.
3. **The town is alive.** Citizens visibly work (procedural animation, FORGE-01/02), think out loud ("!" requests), react to the ruler's answers, cheer when the keep reaches level 2, and strike when neglected (CONTRACTS G5, G13.3). FORGE-04 adds the sound, the particles and the bubbles on top of those reactions. NPCs are never silent decoration.
4. **The match tells a story.** Founding → Expansion → Conflict → Endgame → Crown Arena (VS-2, D-029) → Results; lengths per BRIEF §3, pending §16.10 (`match30` is a non-default evaluation profile). A big moment about every five minutes and no long stretch with nothing meaningful to do (`PACING.md`).
5. **Honest rewards.** Rewards are earned by playing and granted server-side. Random outcomes show their odds. There are no pressure timers and no fake near-misses (`intelligence/retention/variable-rewards.md` §8).

## 2. First session: the VS-1 slice, minute by minute (*targets*; numbers in PACING.md §3)
_Onboarding v2 (D-030, FL-0092)._ The player rules from the throne in the aerial view (G13.6). Gathering by the ruler is optional.

| Time | Player experiences | System |
|---|---|---|
| 0:00 | The view opens high above their own keep, with the ruler seated on the throne (regalia in kingdom colours). Founding horn; card "Welcome, ruler. Your kingdom awaits." Calm music | step `Spawn` on `KingdomJoined` (auto); RulerCameraController `overview`; MusicController `Founding → calm` (planned FL-0062, #49) |
| 0:02–0:20 | "Tap a citizen to see what they think". A tap opens the citizen card: name, job, mood, loyalty | step `InspectCitizen` (client action `CitizenInspected`, sent by InputModeController's selection) |
| ~0:20 | **First meaningful interaction** (design estimate ≤ 30 s, checked by `Onboarding.validate` on the sum of `expectSec`; real timing from the OnboardingStep logs in playtests) | |
| 0:20–1:10 | "Build on a free plot", with the nearest free plot marker highlighted (#99). Tap it, pick a House or a Farm and confirm: a thunk and dust, then builders walk over | step `BuildOnPlot` (G9 `BuildingPlaced`, `placedBy`; BuildSlot tag, `Build.PlaceSlot` FL-0081) |
| 1:10–2:40 | A citizen shows a "!" request bubble. Tap them and choose an answer: the reaction line, the citizen's pose, and the visible consequence (resources, loyalty, a work boost or a strike) | step `AnswerCitizen` (client action `CitizenAnswered` from FORGE-03's panel until G9 `CitizenAnswered`, planned (D-044 (3); FL-0107, FL-0108)); FL-0091 bubbles |
| 2:40–5:10 | Builds a Barracks, then recruits 3 soldiers from the Army rail button: horn and armour rattle at the Rally | step `Recruit` (G9 `UnitsRecruited`; hint target `HUD.ArmyButton` (#99)) |
| 5:10–7:10 | "Send your soldiers to the watchtower"; a capture bar fills; capture sting, tower recolours, border flags, celebration, slice summary | step `Capture` (G9 `ObjectiveCaptured`); `OnboardingCompleted`; announcer |

Teaching rules (built into `Experience/Onboarding`, specs prove each one):
- One line per card: title ≤ 60 characters, body ≤ 140.
- Every step is an action, or the visible result of one.
- **Skip** is always visible. The card never blocks input, pauses the match or teleports the player.
- A step already done is remembered and completes the moment it comes up. Example: a co-ruler captured first.
- A step whose system is not on the server yet (`requires`) is passed over, and an interactive step can time out (`autoAdvanceSec`). Both are logged as `OnboardingStepPassed`, because the funnel counts them anyway (Roblox counts skipped steps as done).
- Client actions complete only the current step. Rewards can only come from server-verified steps.
- **VS-1 grants no rewards:** no `reward` or `completeReward` in the game config, and `limits.firstRewardSec` unset (BRIEF §7; FORGE-00 answers §2). Spec: game `Onboarding.spec` ("grants no rewards").
- A stuck step escalates after its nudge time (gold outline, `OnboardingHintEscalated`) but never forces anything.
- VS-1 keeps progress for the session only (D-027). A new server starts the tutorial again.

## 3. Feedback layer (FL-0062; framework parts in FL-0024)
FORGE-04 hooks only these signals (CONTRACTS G4.1, G8, G9, G13.8):
- G9 events on the server (AnnouncerService);
- on the client: `EntityController.rendered` / `.event` / `.released`, `InteractionController.gathered`, `InputModeController.selected`, `RulerCameraController` (focus, mode, `focusOn` / `restore`), and `ConversationController.opened` / `.closed` (G13.8, once FORGE-03 adds them);
- `Match.State` / `Match.GetState` (G8).

It never touches `Sim.*`. Everything plays through the framework AudioController, VFXController and NotificationController (CONTRACTS G11: no game-tree duplicates).

**Transport.** Client UI never reads G9 directly (G9: clients learn through G8 remotes). Server-side G9 moments reach clients through one relay, planned (#49): AnnouncerService fires the `Feedback.Moment` serverEvent (remote area `Feedback`, declared in `games/game-001/src/shared/Feedback/Remotes.luau`, FL-0062 #49) to the players the moment is about, with a primitive payload (kind, kingdom, buildingType?, count?, position?). The server decides each moment's audience (own kingdom, rivals, everyone) in `Feedback/Moments.luau`, including the phase moments; the client compares the payload's kingdom with `Kingdom.State.mine` only to pick the mine or rival presentation. Music reads `Match.State` / `Match.GetState`, never G9.

**Distances** are measured from the camera focus point (RulerCameraController:getFocus() in the overview; the camera in walk mode), never from the camera position or the seated ruler. CitizenBubbleController does this; FeedbackController, planned (#49), too. (EntityController's LOD still measures from the ruler: #39 M1, kept in the user build notes, D-038 (6).)

| Signal | Transport | Mine | Against me / rival | Notes | System |
|---|---|---|---|---|---|
| `KingdomJoined` (me) | Feedback.Moment | founding horn, claim sparkle, "Your kingdom is founded" | — | once per session | planned FL-0062 (#49) |
| `InteractionController.gathered` | local | chop / mine / harvest sound, chips, "+N Wood" float | — | one sound per 1.5 s per resource (coalescing) | planned FL-0062 (#49) |
| `EntityController.event` work loop (chop, mine, hammer) | local | positional work sounds near the focus, cheap particles | quieter by distance (roll-off) | culled beyond 150 studs from the camera focus | planned FL-0062 (#49) |
| `EntityController.event` `deposit` | local | small clink + coin glint at the storehouse | — | coalesced; a busy storehouse never chatters | planned FL-0062 (#49) |
| `EntityController.event` `celebrate` | local | cheer, a speech bubble over a few citizens | — | keep level 2 (G5) | planned FL-0062 (#49) |
| `BuildingPlaced` | Feedback.Moment | thunk + dust | dust only | `placedBy` me → onboarding | planned FL-0062 (#49) |
| `BuildingCompleted` | Feedback.Moment | flourish + sparkle, toast "House complete" (×N within 2 s) | sparkle only, within 250 studs of the focus | | planned FL-0062 (#49) |
| `BuildingUpgraded` (keep) | Feedback.Moment | royal fanfare, golden column, small camera shake request | toast naming the kingdom, e.g. "Frostmere's keep reached level 2" | the biggest moment before a capture | planned FL-0062 (#49) |
| `UnitsRecruited` | Feedback.Moment | horn + dust stomp, "+3 Soldiers" | — | | planned FL-0062 (#49) |
| `ObjectiveCaptured` | Feedback.Moment | capture sting, recolour sparkle with the kingdom's banner emblem, celebration, announcer | low horn, warning toast naming the kingdom | the slice ends here (G3) | planned FL-0062 (#49) |
| `MatchPhaseChanged` | Match.State | announcer line + music state | same | e.g. at Conflict, "War is declared" only when PvP is on (PACING §4) | planned FL-0062 (#49) |
| `MatchEnded` | Feedback.Moment, Match.State | victory / defeat music and presentation | | VS-1: the slice summary | planned FL-0062 (#49) |
| Crown Arena (G12.5 `ArenaStarted` / `DuelEnded`) | VS-2 | arena intro, crowd director, chants and stingers, crowning payoff (crown-arena.md §7) | | format, winner rule and support strength are PROVISIONAL (§16.9) | VS-2 |
| `EntityController.released` | local | clean-up of any effect attached to that rig | | pooled rigs | built (CitizenBubbleController; FeedbackController in #49) |

Rules (spec noted per rule):
- Every sound has a visual counterpart (accessibility, creator-docs `production/publishing/accessibility.md`). Spec: `Feedback.spec` (CueDirector.validate's sound-only check).
- Repeats coalesce. Spec: `Feedback.spec` (coalescing).
- The `notifications = important` setting keeps only important toasts. Spec: `Notification.spec`.
- Rivals' cosmetic effects beyond 250 studs from the focus are not drawn. Spec pending (FL-0062).
- The on-screen particle budget evicts low-priority looping effects first. Spec: `Vfx.spec`.
- **A kingdom is never identified by colour alone (D-033 (3)).** Every kingdom-attributed cue carries the kingdom name and/or emblem as well as colour: rival toasts and announcer lines name the kingdom; claim and capture effects pair the tint with the kingdom's banner emblem or crest (G13.2 crest shapes). FORGE-05's colour-vision check (D-033 (4)) gates VS-1 acceptance.

### 3a. Living-kingdom feedback (FL-0091; CONTRACTS G13.3)
CitizenBubbleController (built; FL-0091, follow-up #87) draws one bubble per citizen from `EntityController.event`:

| G13.3 kind | Shows | Rule |
|---|---|---|
| `thought` | a bubble with a glyph: "!" request, "?" concern, "…" idea | text from the event only, at most 80 characters |
| `reaction` | the reaction line for about 4 s; the tone sets the pose (cheer, grumble, slump, salute) | `citizenBarks = false` hides reaction bubbles only; poses, thoughts and placards stay |
| `strike` | an "On strike" placard while on | marks only the `entityIds` the server sends, never fans out by occupation (v0.4-g6) |
| `cue` | the cue's pose, sound and effect at the citizen: celebrate, grumble, salute, bow, cower, strike_placard, work_fast, rest, hammer (config `Vfx.luau`) | an unknown cue falls back to the reaction tone; a cue with no entity ids shows only on the HUD or the keep; a continuous effect stops after its `seconds` (#87) |

The living-kingdom consequences of `design/living-kingdom.md` §5 (placards, grumbles, hungry bubbles, fire and alarm, warnings) reach the player through these four kinds; nothing else is invented on the client.

### 3b. Conversation presentation (D-036, CONTRACTS G13.8; FL-0100)
- Planned (#84; `ConversationController.opened` / `.closed` are FORGE-03's, G13.8): on `ConversationController.opened(entityId, position)`, `RulerCameraController:focusOn(position, { duration = 0.6 })` eases to about 25–35 studs from the citizen, framing them off-centre so the portrait does not cover them. On `.closed`, `restore()` returns to the saved overview (FL-0100 part 1, #84).
- With reduced motion, the camera cuts instead of gliding (planned, #84). Main has only `focusOn(position)`, a plain pan.
- The citizen's own bubble hides while their conversation is open (the panel shows the same words; #87).
- Reaction poses play on the portrait (`Kit.posePortrait`, FORGE-02 #85) and on the world rig (`EntityController:playPose`, FORGE-01). FL-0100 part 2, pending both.

## 4. Audio and music (FL-0024 framework, FL-0062 game)
- **Mix, loudest first:** warnings (war horn, lost capture) > celebrations (fanfare, capture) > own work and construction > UI > ambience > music bed.
- **Budget:**
  - 8 voices plus 1 music track; the oldest voice of strictly lower priority is stolen;
  - at most 2 ambience beds (birds, river, wind);
  - cooldowns and per-sound instance caps.
- **Music** (MusicController maps MatchPhase from `Match.State` → state; planned FL-0062, #49):
  - Founding → calm, Expansion → build, Conflict / Endgame → tension;
  - battle while our soldiers fight or our lands are raided, ringing out 8 s after the fight;
  - an arena state for the Crown Arena (VS-2);
  - victory or defeat at the end;
  - crossfades of 1.5 s and a 20 s minimum dwell.
- **API:** legacy `Sound` objects behind a backend seam. creator-docs calls them "discouraged", not deprecated, and Creator Store sounds insert as Sounds. An AudioPlayer backend is a follow-up.
- **Sound list:** `games/game-001/config/Sounds.luau` (licence and source note per entry); user handoff for selection and upload.

## 5. VFX (FL-0024 framework, FL-0062 game presets)
- Warm medieval palette: gold for rewards, dust brown for construction, grey for stone, ember for fire. Each kingdom colour tints claim and celebration effects, always paired with the kingdom's emblem or crest (D-033 (3), §3).
- **Budgets:**
  - per preset: ≤ 2 emitters, ≤ 300 estimated live particles, rate ≤ 100/s ("100 per second on mobile", creator-docs effects/particle-emitters.md), lifetime ≤ 5 s;
  - on screen: ≤ 600 particles and ≤ 16 effects.
- **Reduced motion:** the in-game setting or the platform's Reduce Motion halves particles and removes shake. VFXController never moves the camera; it fires `shakeRequested`, and FL-0053's RulerCameraController applies it.

## 6. Notifications, announcer, celebrations (FL-0027, FL-0062)
- **Stack:** one stack in the top right (notifications band DisplayOrder 70–79), at most 3 visible. Priority: warning > achievement > reward > info. Repeats coalesce by key ("×N").
- **Announcer:** AnnouncerService turns G9 events into kingdom-scoped lines (your kingdom, your rivals, everyone) through the `Feedback` remote area (§3 Transport). NotificationController shows them.
- **Celebration moments, about one per 5 minutes** *(target)*:
  - kingdom founded;
  - first building;
  - first answered request;
  - keep level 2;
  - first capture;
  - a strike resolved;
  - victory (from VS-2: the crowning in the Crown Arena; what the duel decides is open, BRIEF §16.9c).

## 7. Retention and replay (after VS-1; FL-0026 is P3; monetization needs the user's approval, BRIEF §16)
Proposals for FORGE-00 and the user, **not built**:
- **Ruler archetypes** at match start: Builder, Merchant or Warlord.
- **Decisions with visible consequences:** use the content library's decisions (`design/living-kingdom.md` §2), not a parallel edict system.
- **Named veteran citizens:** citizen memory already exists (G5).
- **Match variation:** layout seeds, kingdom events, governor personalities.
- **Account level and collection** (BRIEF §16.5, persistence scope): an account level from match XP; a cosmetic collection of banners, keep skins and outfits. Cosmetic only, never power.
- **End-of-match chest:** earned, with odds shown. A paid chest would be a paid random item: it needs the user's §16.1 approval and the PolicyService gate.
- **Daily reward and quests** (FL-0026).
- **Co-op play:** co-ruler roles.

## 8. Analytics (FL-0023 adapter, FL-0063 funnel)
- Onboarding funnel: Spawn → InspectCitizen → BuildOnPlot → AnswerCitizen → Recruit → Capture (v2), plus `OnboardingStepPassed` for steps the player was moved past;
- VS1 funnel (BRIEF §13);
- session start and end with the last activity;
- match length and outcome;
- disconnect phase;
- idle hints.

Attribution: G9 via Feedback/Signals; funnel order (v0.4-g6) via the VS1 `inOrder` rule (FL-0063). Details: `analytics/schemas/events.md`.

## 9. Open questions (the user's, BRIEF §16; none is decided here)
- §16.3: mid-match joiners. Do they get the tutorial if Founding is long past? *Proposal:* yes; they are credited per G9 attribution and the order rule, from the moment they join.
- §16.4 remainder: what eliminated players do (the match ends in the Crown Arena, D-029).
- §16.9: the Crown Arena format, champion choice, what the duel decides and support strength. They shape the arena presentation.
- §16.10: match length (about 25 + 5 min, or the BRIEF §3 timing).
- §16.13: whether walk mode is offered outside the arena.
- §16.1: monetization, which affects any reward or collection systems after VS-1.
