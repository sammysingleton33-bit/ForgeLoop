# Handoff: forge-04 → forge-00 · AI Kingdoms first-session experience spec · FL-0023/0024/0025 · 2026-10-12

## What I need / what I'm giving you
The user named **AI Kingdoms** (medieval kingdom building, 30–45 min matches) as Game #1 in the FORGE-04 launch prompt on 2026-10-12. This file is FORGE-04's complete first-session experience specification for it, plus four requests: record the decision and create `games/game-001/`, review the analytics taxonomy, give FORGE-04 a design-doc home, and assign two small ownership gaps.

## Requests for FORGE-00
1. **Record the Game #1 decision** (user directive, 2026-10-12: "The first game is now AI Kingdoms") in `DECISIONS.md`, close FL-0035 accordingly, and write the game brief from `docs/standards/game-brief-template.md`. Sections 3 (first session), 11 (audio and VFX) and 13 (analytics) can link here. I assumed the folder id **`games/game-001/`** and wrote only my own config files there (`Analytics.luau`, `Onboarding.luau`, `Sounds.luau`, team.md Rules); rename freely, they have no path dependencies. The Rojo project still maps `games/sandbox/config`; switching the mapping is FORGE-05's call once `Game.luau` exists.
2. **Taxonomy review** (FL-0023 completion criterion): `analytics/schemas/events.md`. 21 custom events (house budget 60, Roblox cap 100), 6 funnels (house 8, cap 10). Questions for you in §13 below.
3. **Design-doc home for FORGE-04.** There is no FORGE-04 path for design text, so this spec lives in a handoff. Proposal: assign `games/*/design/experience.md` (and `design/experience/` for cross-game patterns) to FORGE-04; I will move this text there.
4. **Ownership gaps:**
   - per-game VFX presets: `games/*/config/Vfx.luau` → FORGE-04. Kingdom presets live in `roblox/src/shared/Experience/VfxPresets.luau` until then.
   - the kingdom feedback pipeline is hosted by `VFXController` (my path). If you prefer a separate `Controllers/Feedback*` / `Services/Feedback*`, assign it to FORGE-04; it is a one-file move.
5. **Assumptions to confirm with the user** (I proceeded on them; §13): human rulers plus AI rival kingdoms in one server; soft currency name "Crowns"; cosmetic-only monetization, no paid random items.

---

# AI Kingdoms — first-session experience specification (FORGE-04)

Status: **design + headless-tested systems; nothing seen or heard in Studio yet** (gate G6 is the user's: `roblox/studio-tests/experience.md`). Everything marked *target* is a tuning goal to check in playtests, not a measured result.

## 1. Experience pillars
1. **"This kingdom is mine."** Within 15 seconds the player knows which banner, castle and border are theirs.
2. **Every order gets an answer.** Every action the player takes produces a response within 0.2 s *(target)*: a citizen says "Aye!", dust rises, a number floats. Silence after a click is a bug.
3. **The town is alive.** Citizens visibly react to what happens to *their* kingdom: they cheer at a new building, grumble when hungry, and flee to the keep under siege. NPCs are never silent decoration.
4. **The match tells a story.** A safe opening grows into rivalry and then war, and ends with a clear victory or defeat inside 30–45 minutes, with a big moment about every five minutes and no stretch where the player has nothing meaningful to do.
5. **Honest rewards.** Rewards are earned by playing, granted server-side, and any random outcome shows its odds. No pressure timers, no fake near-misses (intelligence/retention/variable-rewards.md §8).

## 2. Match pacing (30–45 minutes)
Implemented as `roblox/src/shared/Experience/Pacing.luau`. Phases advance on **real signals**, and minute marks are only a soft fallback, so a quiet match still escalates. Phases never go back.

| Phase | Target minutes | Moves on when | What the player does | Big moment | Music |
|---|---|---|---|---|---|
| Opening | 0–5 | 3 own buildings done, or the first kingdom upgrade, or minute 6 | find the castle, read resources, give the first orders, place a farm | kingdom founded, first harvest | calm |
| Development | 5–15 | anyone recruits an army, or takes territory from a kingdom, or minute 16 | expand farms and production, assign professions, upgrade the Town Hall | kingdom tier up (fanfare, golden column) | build |
| Competition | 15–25 | the first battle or siege anywhere, or minute 28 | border disputes, diplomacy, recruit, fortify | first rival army sighted, territory claimed or lost | tension |
| Conflict | 25–38 | a kingdom is eliminated, the round enters Results, or minute 38 | battles, sieges, defend or strike, risky choices | siege breach / siege repelled | battle while fighting, else tension |
| Resolution | 38–45 | match end (RoundEnded) | hold territory, last push | victory or defeat presentation | victory / defeat |

**Dead air guard.** `Pacing:nudgeDue` fires once per idle spell when the local kingdom has made no meaningful action for 25 / 45 / 60 / 90 / 120 s (by phase). Meaningful actions are construction, upgrades, task orders, recruiting, combat and territory changes. `OnboardingController` then shows one phase hint (for example "Upgrade your Town Hall to unlock new buildings."), but only after the tutorial is done and only if the `showHints` setting is on. Analytics `IdleNudge` / `PhaseReached` are planned so this can be measured (events.md §4).

**How we evaluate it (playtests, not assumptions):**
- distribution of `MatchEnded.value` (target median 30–45 min);
- the minute each phase is reached (`PhaseReached`);
- `IdleNudge` per match (target < 3 for an active player);
- MatchProgress funnel drop-off between steps;
- `SessionEnd.lastActivity` for players who leave mid-match.
Tuning knobs: `Pacing.FALLBACK_MINUTE`, `Pacing.IDLE_SECONDS`, and FORGE-01's production rates and AI rival aggression (not mine).

## 3. First session, minute by minute

| Time *(target)* | Player experiences | System |
|---|---|---|
| 0:00 | Spawns at their castle. Founding horn, banner rises, toast "Your kingdom is founded". Calm music. | `KingdomFounded` cue; onboarding step 1 `Arrive` (auto) |
| 0:03 | Card: "Walk to your castle", with an arrow over the castle | step 2 `MoveRuler` (client detector, 8 studs) |
| ~0:11 | **First meaningful interaction** (≤ 30 s target): the ruler moves; the card says "Your banner marks your kingdom" | step 3 `FindKingdom` (within 15 studs of `OnboardingCastle`) |
| ~0:20 | "Tap your Food": the resource bar is outlined; tapping shows what each resource does | step 4 `CheckResources` (HUD report; auto-advances after 20 s) |
| ~0:35 | "Put a citizen to work": arrow over an idle citizen. They answer "Yes, my liege." | step 5 `AssignCitizen` (bus `CitizenTaskChanged`) |
| ~1:00 | "Build a farm": the Build button is outlined. Placing it gives a dust puff and thunk, and nearby citizens say "To work!" | step 6 `PlaceFarm` (bus `ConstructionStarted` Farm) |
| ~1:40 | **First reward**: the first harvest. Wheat motes, "+3 Food" floats, +25 Crowns | step 7 `FirstHarvest` (bus `ResourceProduced` Food; reward via EconomyService) |
| ~3:10 | "Upgrade your Town Hall". Fanfare and golden column, citizens cheer | step 8 `UpgradeHall` (bus `BuildingUpgraded` TownHall) |
| ~3:20 | "Your kingdom grows. Next: train soldiers before your rivals come." +50 Crowns | step 9 `NextGoal`; `OnboardingCompleted` |
| 3:20–15:00 | Free play in Development; dead-air hints if idle | Pacing + OnboardingController |
| 15:00+ | Rival armies, alarm bells, battles: the player learns combat by experiencing a raid with a clear warning, not from a lecture | Cues: `BattleStarted`/`SiegeStarted` (against) |

Teaching rules:
- one line per card (title ≤ 60 characters, body ≤ 140, enforced by `Onboarding.validate`);
- every step is an action, or the visible result of one;
- Skip is always visible;
- the card never blocks input, never pauses the match and never teleports;
- if the player has already done a later step (for example built a farm before being asked), that step completes the moment it comes up;
- a stuck step escalates after its nudge time (gold outline, `OnboardingHintEscalated`), but never forces anything.
Requirements covered: control the ruler (step 2), identify the kingdom (step 3), understand basic resources (step 4), order a citizen task (step 5), build (step 6) and upgrade (step 8), understand how to progress (step 9 and the dead-air hints).

## 4. Onboarding flow (implemented)
Config `games/game-001/config/Onboarding.luau`; engine `Experience/Onboarding.luau`; server `OnboardingService`; client `OnboardingController`. Rules enforced by specs:
- funnel steps are logged in order and none after a skip;
- client actions complete only the current step and can never carry a reward;
- a bus step done early is remembered;
- progress persists in `experience.onboarding` and resumes on another server;
- the first interaction must be within 30 s and the first reward within 180 s of the step estimates.
Studio walkthrough with the expected `env.log` order: `roblox/studio-tests/experience.md` E6.

Dependencies (all handed off):
- FORGE-01: `CitizenTaskChanged`, `ConstructionStarted`, `ResourceProduced` and `BuildingUpgraded` signals; the `OnboardingCastle`, `OnboardingTownHall` and `Citizen` tags.
- FORGE-03: `OnboardingTarget` attributes on `HUD.Resources` and `HUD.BuildButton`; `OnboardingController:report("ResourceInspected" | "GoalAcknowledged")`; the Crowns currency.

## 5. Kingdom feedback matrix (implemented)
`Experience/Cues.luau` + `Experience/CueDirector.luau`, played by AudioController / VFXController / NotificationController. Relation is from the local player's point of view.

| Signal | Mine | Against me | Others |
|---|---|---|---|
| KingdomFounded | horn, claim sparkle, "Your kingdom is founded", cheer, calm music | — | — |
| CitizenTaskChanged | "Aye!" bark + vocal ack, task floats | — | — |
| ResourceProduced | per-resource sound (scythe/axe/pick/coins) + motes, "+N Food" (one sound per 1.5 s per resource) | — | — |
| ConstructionStarted | thunk + dust, "To work!" | — | dust only |
| BuildingCompleted | flourish + gold sparkle, "Farm complete" (×N if several within 2 s), cheer | — | sparkle only, within 250 studs |
| BuildingUpgraded | flourish + level column, "Mill upgraded to level 2" | — | — |
| KingdomUpgraded | royal fanfare, golden column + small shake, achievement toast, celebration | — | "A rival kingdom reached tier N" |
| UnitsRecruited | war horn + dust stomp, "+5 Spearmen" | — | — |
| BattleStarted | clash sparks, battle music | alarm bell, "Your lands are under attack!", citizens flee, battle music | — |
| BattleEnded | won: cheer, "Battle won" / lost: "Battle lost"; music calms | won: "Attack repelled!" / lost: "Your army was defeated", grumble | — |
| SiegeStarted | launch creak, "The siege has begun" | alarm bell, "Your town is under siege!", panic | — |
| SiegeImpact | impact crunch + debris + shake | same + panic | debris only |
| SiegeEnded | Breached: collapse rumble, "The walls are breached!" / failed | Repelled: cheer, "Siege repelled!" / Breached: "Your walls were breached!", panic | — |
| TerritoryChanged | banner + bell, claim sparkle, "Territory claimed" | low horn, "You lost territory" | — |
| MoraleChanged (band crossings only) | joyful: chime, motes, cheer / recovered: "calmer" | unhappy: falling tone, "Your citizens are unhappy" + how to fix, grumble | — |
| KingdomEventStarted | Festival: pipes + confetti + cheer / Plague, Drought, Raid: ominous sting + warning | — | — |
| RoundResult | victory: fanfare music + victory effect / defeat: lament | | |

Rules, all with specs:
- every sound has a visual counterpart, for players with sound off (creator-docs accessibility.md);
- repeats coalesce: one sound per window, one toast with a count;
- the `notifications = "important"` setting keeps only important toasts;
- rivals' cosmetic effects beyond 250 studs are not drawn;
- morale cues fire only on band crossings (30 / 70), never per tick.

## 6. Living citizens
`Experience/CitizenReactions.luau` and `VFXController:react`:
- Five reactions: cheer, work, acknowledge, grumble, panic.
- Each reaction has short barks shown in a speech bubble, plus an emote id written to the citizen's `ForgeEmote` attribute for FORGE-01's animator.
- Picking rules: up to 1–4 nearest citizens of that kingdom within 35–70 studs; an 8 s cooldown per citizen; no line repeats twice in a row; the `citizenBarks` setting turns bubbles off.

Requested from FORGE-01 (behaviour signals, handoff `...-to-forge-01-kingdom-signals.md`):
- tag `Citizen` with attributes `CitizenId`, `KingdomId`, `Task`, `Mood`;
- citizens play the `ForgeEmote` animation if present;
- citizens walk to the keep during `SiegeStarted` against their kingdom;
- idle citizens gather at the square during a Festival.
Requested from FORGE-02: the emote animations (cheer, work, nod, slump, flee).

## 7. Audio direction (implemented registry and controller; no assets chosen yet)
- **Mix order (loudest first):** warnings (alarm, breach) > celebrations (fanfare) > own production and construction > UI > ambience > music bed.
- **Budget:** 8 voices plus 1 music track. When the budget is full, the oldest voice of strictly lower priority is stolen. Ambience is limited to 2 beds. Cooldowns and per-sound instance caps stop machine-gunning.
- **Music states:** calm → build → tension → battle → victory/defeat. Changes crossfade over 1.5 s with a 20 s minimum dwell. Battle starts at once on combat and rings out 8 s after it ends.
- **Positional sound:** a 3D sound is parented to an Attachment at the event, with roll-off (near 8–90 studs, far 20–260), so your own town is clear and rivals are faint.
- **Settings:** master × category volume (music, ambience, sfx/voice, ui).
- **API:** legacy `Sound`/`SoundGroup` behind a backend seam. creator-docs calls these "discouraged" in favour of AudioPlayer, but they are not deprecated, and the Creator Store inserts Sounds. An AudioPlayer backend is a follow-up.
- **Sound list:** 17 factory and 36 AI Kingdoms entries, each with a licence and source note. Selection and upload need the user's account (handoff `...-to-user-sounds.md`).

## 8. VFX direction (implemented presets and controller)
- Warm medieval palette: gold for rewards, dust brown for construction, grey for stone, ember orange for fire. Each reward tier keeps one colour and sound identity across games.
- **Budgets:**
  - per preset: ≤ 2 emitters, ≤ 300 estimated live particles, rate ≤ 100/s ("100 per second on mobile", creator-docs effects/particle-emitters.md), lifetime ≤ 5 s;
  - on screen: ≤ 600 live particles and ≤ 16 effects. When over budget, lower-priority looping effects are evicted.
- **Reduced motion:** the in-game setting, or the platform's Reduce Motion (`GuiService.ReducedMotionEnabled`), halves particles and removes camera shake. VFXController never moves the camera itself; it fires `shakeRequested` for FORGE-01's CameraController.
- **Textures:** built-in `rbxasset://textures/particles/*` for now (unverified in Studio). FORGE-02 may author flipbooks.

## 9. Notifications and celebrations (FL-0027, next)
- One stack in the top right (interfaces §9 notifications band, DisplayOrder 70–79), at most 3 visible.
- Priority: warning > achievement > reward > info. Coalesced by key (the "×N" counter).
- Celebration moments (`NotificationController:celebrate`), about one every 5 minutes *(target)*:
  - kingdom founded;
  - first harvest;
  - kingdom tier up;
  - siege repelled or breach;
  - quest or achievement complete;
  - daily streak;
  - victory.
- FORGE-03's reward reveal calls `celebrate` at its end; FORGE-04 never reacts to `RewardRolled` on its own.

## 10. Retention and replay (FL-0026 and proposals; monetization changes need user approval)
Built next (FL-0026), all server-authoritative:
- daily reward with streak and a one-day grace, on server UTC;
- quests: 3 daily, from bus events, e.g. "Complete 5 buildings", "Win a battle", "Reach tier 3";
- achievements, e.g. First Harvest, Master Builder (50 buildings), Siege Breaker, Unbreakable (repel 3 sieges), Beloved Ruler (end a match with morale ≥ 80), Conqueror (win), Peacemaker (win without losing territory).
- Every grant goes through EconomyService with a transaction id.

Proposals for FORGE-00 / the user (not built, need decisions):
- **Ruler archetypes** chosen at match start: Builder (cheaper upgrades), Merchant (more Gold), Warlord (faster recruits). Different strategies give replay value.
- **Ruler edicts:** 2–3 meaningful decisions per match (raise taxes vs morale, conscription vs production) with visible citizen reactions.
- **Citizen development:** citizens gain a profession level during a match; named veteran citizens give the player something to care about.
- **Match variation:** map seeds, random kingdom events (Festival, Plague, Drought, Raid), AI rival personalities (aggressive, turtle, trader).
- **Long-term progression:** Ruler level from match XP; a cosmetic "Chronicle" collection of banners, castle skins and citizen outfits (cosmetic only, never power); end-of-match earned chest with shown odds.
- **Social and co-op:** allied kingdoms (2v2), gifting resources to an ally, party join.

## 11. Analytics (implemented adapter; taxonomy for review)
`analytics/schemas/events.md`:
- funnels: Onboarding (9 steps), FirstMatch, MatchProgress (per matchId), FirstReward, Shop (GUID per open), Return (day-2);
- session start/end with the last activity (drop-off point);
- match end with duration (pacing).
Specs prove failure isolation, the rate cap (120 + 20×CCU per minute with a funnel reserve), undeclared-field warnings and the funnel session id. Every call is in `env.log` for Studio walkthroughs.

## 12. Systems map (FORGE-04, this sprint)
| Piece | Path | Task | State |
|---|---|---|---|
| Analytics adapter + router + schema | `Services/AnalyticsService`, `Experience/Analytics{Router,Schema}` | FL-0023 | built, 47 specs |
| Settings + experience namespace | `Services/SettingsService`, `Controllers/SettingsController`, `Experience/Schema` | FL-0024 | built; needs FL-0008 DataService to boot |
| Audio | `Controllers/AudioController`, `Experience/{Sounds,SoundRegistry,MusicDirector}` | FL-0024 | built; no assets |
| VFX + feedback pipeline | `Controllers/VFXController`, `Experience/{VfxPresets,Cues,CueDirector,CitizenReactions,Pacing}` | FL-0024 | built; needs kingdom signals |
| Onboarding | `Services/OnboardingService`, `Controllers/OnboardingController`, `Experience/Onboarding` | FL-0025 | built; needs FL-0008/0009 + signals |
| Notifications, celebrations | `Controllers/NotificationController` | FL-0027 | next |
| Daily rewards, quests, achievements | `Services/{DailyReward,Quest}*`, `Controllers/{DailyReward,Quest}*` | FL-0026 | next |

## 13. Open questions (assumptions I used; please confirm with the user)
1. **Who plays:** I assumed 1–8 human rulers per server plus AI rival kingdoms (the "AI" in AI Kingdoms), all in one 30–45 min match. Recommended. Alternative: 1 human vs AI only (simpler pacing, no PvP liquidity problem).
2. **Soft currency name:** "Crowns", used in onboarding rewards. FORGE-03 owns `Currencies.luau`.
3. **Monetization stance:** cosmetic-only purchases, no paid random items. Recommended; any change needs the user's approval.
4. **Taxonomy:** is `MatchProgress` (recurring per matchId) acceptable alongside `FirstMatch`? It uses one of the remaining funnel slots (6 of 10 used).

## Done (with commits) — branch `forge/04-experience`
- `f04a61e`, `077fcf4` FL-0023 analytics adapter, configs and taxonomy
- `9cc2e6b`, `8c74fbf`, `eeb239a` FL-0024 settings, audio, VFX, kingdom feedback
- `4bc54ec` FL-0025 onboarding (+ `roblox/tests/unit/experience/mutations.py`)
PRs: draft per task (D-013/D-016), links in `agents/forge-04/STATUS.md`.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS: 325 Lune specs (all files), Selene 0 errors / 0 warnings, StyLua 111 files, Rojo build OK, place check OK (36 scripts, 40 requires resolved). Run on eeb239a's tree, 2026-10-12, cloud session.
- `python3 roblox/tests/unit/experience/mutations.py` → 28/28 named specs fail when their rule is broken.
- **Unverified:** everything in Studio (audio, particles, UI layout, DataStore persistence, real remotes, phone layout); all sound assets (none chosen); built-in particle textures.

## Interfaces touched
Additive only, all within FORGE-04's area:
- `Experience/Remotes.luau` declares 5 Experience remotes;
- `experience` namespace schema v1.
**Proposed** (not edited): additive GameEvents for kingdom signals and two FORGE-01 client remotes (see the FORGE-01 handoff).

## Next actions for the receiver
1. Record the AI Kingdoms decision; create `games/game-001/` (`Game.luau`, brief).
2. Review `analytics/schemas/events.md`; answer §13.
3. Assign the paths in request 3 and 4.

## Files to read
- `analytics/schemas/events.md` — taxonomy for review
- `games/game-001/config/Onboarding.luau` — the first-session flow
- `roblox/src/shared/Experience/Cues.luau` — feedback matrix
- `roblox/studio-tests/experience.md` — what the user runs in Studio
