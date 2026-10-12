# AI Kingdoms — first-session experience (FORGE-04)

_Status: design plus headless-tested systems. **Nothing has been seen or heard in Studio yet**; gate G6 belongs to the user (`roblox/studio-tests/experience.md`, `games/game-001/STUDIO_PLAYTEST.md`). Anything marked *target* is a tuning goal for playtests, not a measured result. Last updated 2026-10-12._

Companion docs:
- `PACING.md`: phase lengths and minute targets.
- `analytics/schemas/events.md`: what we measure.

Contracts:
- `games/game-001/CONTRACTS.md` v0.4-g2: G4.1 client signals, G9 events, G11 experience hooks.
- `DECISIONS.md` D-020–D-028.

## 1. Experience pillars
1. **"This kingdom is mine."** Within 15 seconds the player knows which banner, keep and border are theirs.
2. **Every order gets an answer.** Every action produces a response within about 0.2 s *(target)*. Examples: a chop sound with "+3 Wood", a dust puff and thunk on placement, a horn when soldiers form up. Silence after a click is a bug.
3. **The town is alive.** Citizens visibly work (procedural animation, FORGE-01/02), cheer when the keep reaches level 2, and react to a ruler's visit (CONTRACTS G5). FORGE-04 adds the sound, the particles and the speech bubbles on top of those reactions. NPCs are never silent decoration.
4. **The match tells a story.** Founding → Expansion → Conflict → Endgame → Results within 30–45 minutes, with a big moment about every five minutes and no long stretch with nothing meaningful to do (`PACING.md`).
5. **Honest rewards.** Rewards are earned by playing and granted server-side. Random outcomes show their odds. There are no pressure timers and no fake near-misses (`intelligence/retention/variable-rewards.md` §8).

## 2. First session: the VS-1 slice, minute by minute (*targets*; numbers in PACING.md §3)
_Onboarding v2 (D-030, FL-0092)._ The player rules from the throne in the aerial view (G13.6). Gathering by the ruler is optional.

| Time | Player experiences | System |
|---|---|---|
| 0:00 | The view opens high above their own keep, with the ruler seated on the throne (regalia in kingdom colours). Founding horn; card "Welcome, ruler. Your kingdom awaits." Calm music | step `Spawn` on `KingdomJoined` (auto); RulerCameraController `overview`; MusicController `Founding → calm` |
| 0:02–0:20 | "Tap a citizen to see what they think". A tap opens the citizen card: name, job, mood, loyalty | step `InspectCitizen` (client action `CitizenInspected`, sent by InputModeController's selection) |
| ~0:20 | **First meaningful interaction** (≤ 30 s, enforced by `Onboarding.validate`) | |
| 0:20–1:10 | "Build on a free plot", with the nearest plot marker highlighted. Pick a House or a Farm and confirm: a thunk and dust, then builders walk over | step `BuildOnPlot` (G9 `BuildingPlaced`, `placedBy`; BuildSlot tag) |
| 1:10–2:40 | A citizen shows a "!" request bubble. Tap them and choose an answer: the reaction line, the citizen's pose, and the visible consequence (resources, loyalty, a work boost or a strike) | step `AnswerCitizen` (client action `CitizenAnswered` from FORGE-03's panel until the proposed G9 `CitizenAnswered`); FL-0091 bubbles |
| 2:40–5:10 | Builds a Barracks, then recruits 3 soldiers: horn and armour rattle at the Rally | step `Recruit` (G9 `UnitsRecruited`) |
| 5:10–7:10 | "Send your soldiers to the watchtower"; a capture bar fills; capture sting, tower recolours, border flags, celebration, slice summary | step `Capture` (G9 `ObjectiveCaptured`); `OnboardingCompleted`; announcer |

Teaching rules (built into `Experience/Onboarding`, specs prove each one):
- One line per card: title ≤ 60 characters, body ≤ 140.
- Every step is an action, or the visible result of one.
- **Skip** is always visible. The card never blocks input, pauses the match or teleports the player.
- A step already done is remembered and completes the moment it comes up. Example: a co-ruler finished the building first.
- Client actions complete only the current step. Rewards can only come from server-verified steps.
- A stuck step escalates after its nudge time (gold outline, `OnboardingHintEscalated`) but never forces anything.
- VS-1 keeps progress for the session only (D-027). A new server starts the tutorial again.

## 3. Feedback layer (FL-0062; framework parts in FL-0024)
FORGE-04 hooks only these signals (CONTRACTS G4.1):
- G9 events on the server;
- `EntityController.rendered` / `.event` / `.released` and `InteractionController.gathered` on the client;
- `Match.State` (G8).

It never touches `Sim.*`. Everything plays through the framework AudioController, VFXController and NotificationController (D-026: no game-tree duplicates).

| Signal | Mine | Against me / rival | Notes |
|---|---|---|---|
| `KingdomJoined` (me) | founding horn, claim sparkle, "Your kingdom is founded" | — | once per session |
| `InteractionController.gathered` | chop / mine / harvest sound, chips, "+N Wood" float | — | one sound per 1.5 s per resource (coalescing) |
| `EntityController.event` work loop (chop, mine, hammer) | positional work sounds near the camera, cheap particles | quieter by distance (roll-off) | culled beyond 150 studs, matching entity LOD |
| `EntityController.event` `deposit` | small clink + coin glint at the storehouse | — | coalesced; a busy storehouse never chatters |
| `EntityController.event` `celebrate` | cheer, a speech bubble over a few citizens | — | keep level 2 (G5) |
| `BuildingPlaced` | thunk + dust | dust only | `placedBy` me → onboarding |
| `BuildingCompleted` | flourish + sparkle, toast "House complete" (×N within 2 s) | sparkle only, within 250 studs | |
| `BuildingUpgraded` (keep) | royal fanfare, golden column, small camera shake request | toast "A rival keep reached level N" | the biggest moment before a capture |
| `UnitsRecruited` | horn + dust stomp, "+3 Soldiers" | — | |
| `ObjectiveCaptured` | capture sting, recolour sparkle, celebration, announcer | low horn, warning toast | the slice ends here (G3) |
| `MatchPhaseChanged` | announcer line + music state | same | e.g. "War is declared" at Conflict |
| `KingdomEliminated` / `MatchEnded` | victory / defeat music and presentation | | VS-2 |
| `EntityController.released` | clean-up of any effect attached to that rig | | pooled rigs (spec required by FL-0062) |

Rules, all enforced by specs:
- Every sound has a visual counterpart (accessibility, creator-docs `production/publishing/accessibility.md`).
- Repeats coalesce.
- The `notifications = important` setting keeps only important toasts.
- Rivals' cosmetic effects beyond 250 studs are not drawn.
- The on-screen particle budget evicts low-priority looping effects first.

## 4. Audio and music (FL-0024 framework, FL-0062 game)
- **Mix, loudest first:** warnings (war horn, lost capture) > celebrations (fanfare, capture) > own work and construction > UI > ambience > music bed.
- **Budget:**
  - 8 voices plus 1 music track; the oldest voice of strictly lower priority is stolen;
  - at most 2 ambience beds (birds, river, wind);
  - cooldowns and per-sound instance caps.
- **Music** (MusicController maps MatchPhase → state):
  - Founding → calm, Expansion → build, Conflict / Endgame → tension;
  - battle while our soldiers fight or our lands are raided, ringing out 8 s after the fight;
  - victory or defeat at the end;
  - crossfades of 1.5 s and a 20 s minimum dwell.
- **API:** legacy `Sound` objects behind a backend seam. creator-docs calls them "discouraged", not deprecated, and Creator Store sounds insert as Sounds. An AudioPlayer backend is a follow-up.
- **Sound list:** `games/game-001/config/Sounds.luau` (licence and source note per entry); user handoff for selection and upload.

## 5. VFX (FL-0024 framework, FL-0062 game presets)
- Warm medieval palette: gold for rewards, dust brown for construction, grey for stone, ember for fire. Each kingdom colour tints claim and celebration effects.
- **Budgets:**
  - per preset: ≤ 2 emitters, ≤ 300 estimated live particles, rate ≤ 100/s ("100 per second on mobile", creator-docs effects/particle-emitters.md), lifetime ≤ 5 s;
  - on screen: ≤ 600 particles and ≤ 16 effects.
- **Reduced motion:** the in-game setting or the platform's Reduce Motion halves particles and removes shake. VFXController never moves the camera; it fires `shakeRequested`, and FL-0053's RulerCameraController applies it.

## 6. Notifications, announcer, celebrations (FL-0027, FL-0062)
- **Stack:** one stack in the top right (notifications band DisplayOrder 70–79), at most 3 visible. Priority: warning > achievement > reward > info. Repeats coalesce by key ("×N").
- **Announcer:** AnnouncerService turns G9 events into kingdom-scoped lines (your kingdom, your rivals, everyone) through the `Feedback` remote area. NotificationController shows them.
- **Celebration moments, about one per 5 minutes** *(target)*:
  - kingdom founded;
  - first building;
  - keep level 2;
  - first capture;
  - victory.

## 7. Retention and replay (after VS-1; FL-0026 is P3; monetization needs the user's approval, BRIEF §16)
Proposals for FORGE-00 and the user, **not built**:
- **Ruler archetypes** at match start: Builder, Merchant or Warlord.
- **Ruler edicts:** 2–3 meaningful decisions per match, such as taxes vs morale, with visible citizen reactions.
- **Named veteran citizens:** citizen memory already exists (G5).
- **Match variation:** layout seeds, kingdom events, governor personalities.
- **Account level and collection:** an account level from match XP; a cosmetic collection of banners, keep skins and outfits. Cosmetic only, never power.
- **End-of-match chest:** earned, with odds shown.
- **Daily reward and quests** (FL-0026).
- **Co-op play:** co-ruler roles.

## 8. Analytics (FL-0023 adapter, FL-0063 funnel)
- Onboarding funnel (6 steps above);
- VS1 funnel (BRIEF §13);
- session start and end with the last activity;
- match length and outcome;
- disconnect phase;
- idle hints.

Attribution follows CONTRACTS G9 (`games/game-001/src/shared/Feedback/Signals.luau`). Details: `analytics/schemas/events.md`.

## 9. Open questions (the user's, BRIEF §16)
- §16.3: mid-match joiners. Do they get the tutorial if Founding is long past? *Proposal:* yes, but the VS1 funnel still credits only their own actions.
- §16.4: victory rules, which change the end-of-match presentation.
- §16.1: monetization, which affects any reward or collection systems after VS-1.
