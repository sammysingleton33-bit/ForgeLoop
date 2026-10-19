---
id: FL-0137
title: "Full-match onboarding: skippable war, siege, raid, ram and Crown Arena tips from G9 events (Crownfall P3, FL-0092 follow-on)"
track: build
owner: forge-04
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: [FL-0092, FL-0134]
evidence: []
---

# Full-match onboarding: skippable war, siege, raid, ram and Crown Arena tips from G9 events (Crownfall P3, FL-0092 follow-on)

## Outcome
In a full match (D-053), a new ruler gets one short tip the first time each war situation comes up: the Conflict phase opens (declare war or propose peace), a rival declares war on them, their keep is besieged (go defend: G or the alert button), raiders enter their lands, their own army reaches an enemy keep (a ram breaks it), and Endgame starts (the top 2 kingdoms by Crown Points fight in the Crown Arena). Each tip shows once per player, ever. It hides by itself after a few seconds, has a "Got it" button, and never blocks, freezes or gates play. Players who switched hints off see none.

## Context
- D-053 (full match, PvP, Crown Arena victory); FL-0092 (onboarding v2, `games/game-001/config/Onboarding.luau`); FL-0025 engine (`roblox/src/shared/Experience/Onboarding.luau`, `OnboardingService`, `OnboardingController`).
- G9 events (`roblox/src/shared/Contracts/GameEvents.luau`): `WarChanged`, `SiegeChanged`, `RaidChanged` (FL-0134), `MatchPhaseChanged`.
- FL-0130: `Feedback/Moments` already turns the same events into notices; the siege and raid alert (`FeedbackWarController:goToAlert`, key G, the HUD Raid rail button) is what the siege and raid tips point at.
- Rams train at a level-2 Barracks (`config/Buildings.luau`, `config/Military.luau`).
- The idle hints for Conflict and Endgame still describe VS-1 ("Recruit soldiers... send them to a tower", "Hold your towers"); this task updates them for the full match.

## Requirements
- **Tips are flows of a new kind.** A flow with `tip = true` has exactly one step, no reward, no funnel and an `autoAdvanceSec` (it can never wait for anything). `startMatch` filters the start event on the subject's info (e.g. `{ role = "target", atWar = true }`). Validation rejects a tip without these. Progress is persisted like any flow, so a finished or dismissed tip never shows again.
- **Six tips** in `config/Onboarding.luau`:
  - `tipWarOpen`: MatchPhaseChanged into Conflict;
  - `tipWarOnYou`: WarChanged, I am the target;
  - `tipSiege`: SiegeChanged on, my keep;
  - `tipRaid`: RaidChanged on, my lands;
  - `tipRam`: SiegeChanged on, my kingdom is an attacker;
  - `tipCrownArena`: MatchPhaseChanged into Endgame.

  Each tip is one line of title and one of body. The siege and raid tips end early when their situation ends.
- **Who a tip is for** comes from new `Feedback/Signals` subject resolvers:
  - WarChanged: both kingdoms' members, with role declarer or target;
  - SiegeChanged and RaidChanged: the defender's members (role defender) and the attackers' members (role attacker).
- **Client.** `OnboardingController` keeps one state per flow. The tutorial card wins. A tip uses the same card with "Got it" (which skips the tip flow) and no step counter. A finished tip never celebrates. No tip shows while `showHints` is off.
- **Idle hints.** Conflict and Endgame are updated for the full match.
- **Ownership and contracts.** Only FORGE-04 paths change. The `Experience.OnboardingState` snapshot gains an additive `tip` field; there is no new remote and no contract break. UI targets are optional: tips name `HUD.KingdomButton` and the Raid rail button only if FORGE-03 adds those `OnboardingTarget` attributes (request by handoff, never by editing their files).
- **Text** stays inside what the build does (no ally, alliance or betrayal wording: VS-3).

## Validation
- Automated (headless):
  - framework specs (Onboarding validate/handle for tip flows, OnboardingService start match, OnboardingController per-flow state and "Got it");
  - game specs (Signals resolvers, each tip starts only for the right rulers, once);
  - a mutations file `FL-0137.py` (all rows caught);
  - `bash roblox/scripts/check.sh`, `python tools/forge.py validate`.
- Interactive (Studio, not done by headless checks): a new section in `roblox/studio-tests/experience.md`. Run a full match with one rival at war; check each tip appears once, hides by itself, "Got it" works, nothing blocks input, and none shows with hints off.

## Completion criteria
- [ ] Engine: `tip` flows with `startMatch`, validated; tip progress persisted; never blocks
- [ ] Six tips and the two idle hints in `config/Onboarding.luau`
- [ ] Signals resolvers for WarChanged, SiegeChanged, RaidChanged with roles
- [ ] Client per-flow state, tutorial first, "Got it", no celebration for tips, hidden with hints off
- [ ] Specs + `FL-0137.py` mutations caught; gate green
- [ ] Studio steps written (unverified until run)

## Log
- 2026-10-19 forge-04: SPECIFIED. Opened for FORGE-00's 04:22 order (3), the full-match onboarding follow-on to FL-0092. Scope sent to FORGE-00 for acceptance.
