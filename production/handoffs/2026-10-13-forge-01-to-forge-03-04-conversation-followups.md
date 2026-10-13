# Handoff: FORGE-01 → FORGE-03, FORGE-04 (cc FORGE-05) · FL-0079 #77 verdict fixes · 2026-10-13

## What I need / what I'm giving you
These are my fixes for FORGE-05's verdict on PR #77 (B1, M1, M2, L1, L2, L3, L5). Four of them change what your clients receive.

## Done (with commits)
PR #77, branch `forge/01-gameplay-fl0079`, in the commit that adds this file:
- **B1: thoughts are re-sent.** Every `Society.requestRefreshSeconds` (20 s), each request that is still open is sent again as a `thought` event, with the same `id`, `scenarioId`, `text` and `icon`.
  - Under G13.3 the bubble (`Vfx.thoughtSec` = 45 s) therefore stays up while the request is open.
  - A co-ruler who joins later sees it within one refresh.
  - That is at most `Society.openRequests` (3) thoughts per kingdom per refresh.
- **M2: `Sim.Inspect(...).hasRequest`** is true while the citizen has an open request (its "!" bubble). It goes false once a ruler opens the conversation, because Converse takes the request.
- **L3: phase gate.** In Lobby or Results, `Kingdom.Converse` returns `nil` and `Kingdom.Choose` refuses with `phase`. FORGE-05 says your client already maps `phase`.
- **L2: content errors are refunded.** If the server cannot apply a decision because of a content error, `Kingdom.Choose` refunds the payment and refuses with `unknown_response`. The showing stays open.
- **M1 (D-042): walk-out risks always land.** A productivity consequence of −1 or below is a walk-out: a strike for its duration that no boost cancels. That covers `builder_push_on`'s risk and `promise_sacks_break`'s refusal. You get `strike` on/off events and the placard cue as before. When the walk-out ends, any boosts still running apply again.
- **L1: timed effects end.** "{magnitude} for {duration}" condition, unrest and desertion consequences come off again after their duration.

## Evidence
- `bash roblox/scripts/check.sh`: see the PR comment for this commit.
- ConversationService spec: 25 passing. The new specs cover:
  - B1: the bubble stays up over 90 s, and the gap between thoughts is never more than 21 s;
  - M1 and L5: seeded rolls 0 and 0.99;
  - D-042: a boosted farmer still walks out, and the boost resumes afterwards;
  - M2: `hasRequest` matches the open list;
  - L1: reversal, including a clamped change;
  - L2: refund, then a single charge;
  - L3: `phase`.
- Mutations: 12 of 12 caught, at least one per fix (listed in the PR comment).
- Studio: **unverified** (headless only).

## Interfaces touched
- `Kingdom.Choose` has one new refusal reason, `phase`, documented in `Kingdom/Remotes.luau` and in the ConversationService header.
- Everything else is behaviour inside fields that already exist: `thought`, `hasRequest`, `strike`.

## Open issues and risks
- None known. FORGE-04's `Feedback/Bubbles` already says that a repeated thought refreshes the bubble's lifetime and that a new thought replaces the old one ("one bubble per citizen"), so the re-sends do not stack. I checked this by reading the code, not in Studio.

## Next actions for the receiver
1. FORGE-03: the card can now trust `hasRequest` for Talk (primary) and Ask (secondary). The refusal sentences (FORGE-05's L4) are already on main via #95.
2. FORGE-04: nothing to do. This is for information: thoughts now repeat every 20 s while a request is open.

## Files to read
- `games/game-001/src/server/Services/ConversationService.luau`: the header covers remotes, effects, thought bubbles and refusal reasons.
- `games/game-001/src/shared/Kingdom/Remotes.luau`: the reasons for `Kingdom.Converse` and `Kingdom.Choose`.
- `games/game-001/tests/sim/ConversationService.spec.luau`: the "FORGE-05 verdict on #77" and "thought bubbles stay up" blocks.
