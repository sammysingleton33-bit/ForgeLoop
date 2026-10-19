---
id: FL-0074
title: Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff
track: build
owner: forge-04
status: BUILDING
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-19
depends_on: [FL-0071, FL-0072]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 16
evidence:
  - "part 2b: check.sh all PASS except 1 selene shadowing warning in a spec, fixed (selene 0 warnings, KingdomFeedback 49/49); mutations.py FL-0074 84/84 CAUGHT; unverified: Studio E18"
  - "part 2c: CrowdFigures spec on the real Kit.arena; mutations and gate in #237; unverified: Studio E20"
  - "headless: #237 check.sh OVERALL PASS on 08a53074 (lune 562/0, game-001 2439/0); FL-0074 mutations 126/126 CAUGHT; CI green; FORGE-07 READY. Studio E18/E20 not run"
---

# Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff

## Outcome
The crowd behind each ruler visibly and audibly reflects their leadership: Adoring stands chant and roar, Hostile stands boo and leave, key citizens step up when their perk fires, and the ending pays off the player's choices (design §7).

## Context
D-029; design §7; CONTRACTS G12.6 (client-only crowd from `ArenaState`, `Arena.Events`, population). **VS-1 experience tasks come first;** design the crowd director and chant list in slack time.

## Requirements
- `CrowdController` (client-only): fills stands from population (one figure per two citizens, ≤ 60 per stand, ≤ 120 total), key citizens at the rail, billboard fallback on low graphics levels; crowd frame time < 2 ms.
- Crowd director: tier behaviours (design §3 table), reactions to hit, parry, near-death, trigger, comeback, finish; at most one major reaction every 3 s; perk moments take priority; volume ducks under announcer lines.
- `ChantController` and config `Crowd.luau`: pre-written chants per kingdom; boos and turned backs as the strongest negative (no insults); subtitles for chants and announcer lines.
- Intro camera passes over both stands; music and stingers in `Sounds.luau`; four endings (win or loss × high or low support).
- Arena phase timings in `Pacing.luau` (design §2).

## Validation
Lune specs for director rationing and tier mapping. Studio video or screenshots of each tier and of a perk moment; MicroProfiler capture of crowd cost on a phone emulator.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-13 forge-00: READY → SPECIFIED. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): its dependencies are not built yet (FL-0018 economy core, or the Crown Arena FL-0070/FL-0071), so it is SPECIFIED, not READY.
- 2026-10-18 forge-00: SPECIFIED → READY. Operation Crownfall (D-053): arena work starts now; FORGE-01 order FL-0125 → FL-0069 → FL-0070 → FL-0071; defaults from crown-arena.md §11 apply
- 2026-10-18 forge-04: READY → BUILDING. Part 1 (pure, before FL-0071/FL-0072): Feedback/CrowdDirector (figures one per two citizens <= 60 a stand, <= 120 total; seats by tier; tier reactions per design §3; one major every 3 s, minor per stand every 0.75 s; perk moments and the ending always win and duck the crowd; near-death and comeback; full-hype chants for chanting tiers; four endings), config/Crowd.luau DRAFT (tiers, subtitles for every reaction, pre-written chants per kingdom, endings), Pacing.arena stage seconds (qualify 5, vote 10, loadout 20, intro 15, duel 120, crowning 20), 13 crowd sounds (P2, handoff 2026-10-18-forge-04-to-user-crowd-sounds.md). Part 2 (client crowd controller, intro camera, music) waits for FL-0071 and FL-0072.
- 2026-10-18 forge-04: BUILDING → BUILDING. Part 2a: FeedbackCrowdController feeds the crowd director from Arena.State / Arena.Events, plays the crowd sounds with the director's duck factor (announcer moments and perk stingers), shows a subtitle line per stand (ForgeCrowdCaptions; a perk or the ending holds its line), plays the ending once at crowning (no winner: quiet), drops it at done / Results / Lobby, and fires reacted(reaction, kingdom) for the stand figures (part 2b, after FL-0071 and FL-0072). Studio-only preview ForgeCrowdPreview = 'tierA,tierB' plays a scripted duel for E17.
- 2026-10-19 forge-04: BUILDING → BUILDING. Part 2b (progress log, still BUILDING): CrowdStageController plays the intro pass over the stands (away stand, home stand, then the ring; from the Root attachments of FORGE-02's CrownArena model, else Layout.arena ± 30 studs; capped by the intro's time left), the arena music scene (MusicDirector scene: over battle music, the result still wins; Results ends it), the herald horn at intro and the fanfare at a crowning with a winner (never when called off). RulerCamera gains playShots/stopShots (overview only; any player input takes over). Studio preview ForgeArenaPreview = a | b | neutral for E18. 3 sounds P2 (handoff 2026-10-19-forge-04-to-user-arena-sounds.md). Part 2c (stand figures) after #217.
- 2026-10-19 forge-04: BUILDING → BUILDING. Part 2c (progress log, still BUILDING; key citizens on the rails wait for FORGE-01's key-citizen data): CrowdFiguresController seats Kit.crowdFigure on the CrownArena seat attachments (centre-out, front row first; director counts from ArenaState citizens, else a full stand, then the tier's fill), hops, slumps or turns a stand on the crowd's reactions, empties the stands when the director goes, retries until the arena streams in (FORGE-07 #237 M1), seats half a stand with effectsQuality reduced and skips hops with reduced motion. Pacing.arena removed: arena stage timings are FORGE-01's config Arena and clients follow ArenaState.endsAt (FORGE-00's one-source ruling).
- 2026-10-19 forge-04: BUILDING → BUILDING. Parts 2b (#231, 9d7259bd) and 2c (#237, 67c6d921) merged. 2c: CrowdFiguresController seats each kingdom's people in the CrownArena stands (retries until the streamed arena arrives; reduced effects seat half; reduced motion, toggle or platform, stills the hops). Pacing.arena vote/loadout/intro/crowning read from FORGE-01's config Arena (FORGE-00 rulings 07:48, 08:02). Still BUILDING: key citizens on the stand rails wait for FORGE-01's key-citizen data on the client (FL-0069 slice 2).
