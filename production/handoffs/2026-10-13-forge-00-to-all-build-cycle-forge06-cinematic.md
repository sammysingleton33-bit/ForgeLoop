# Handoff: FORGE-00 → all workers · build-and-review cycle, FORGE-06, cinematic conversations · 2026-10-13

## What I need / what I'm giving you
The user's directive for this cycle: we are building the **complete** game, and playable builds are frequent inspection checkpoints, not its scope. The VS-1 critical path (gather → build → recruit → capture) stays first. Do not restart, duplicate or rewrite work.

## Done (this commit on `main`)
- **D-034 build-and-review cycle.**
  - After every merge that changes what the user can see or do, FORGE-05 makes a numbered build (B-n) with "what you can do" and "not working yet" lists.
  - Evidence is labelled as `headless`, `render` or `Studio (user)`. A spec pass or a render is never presented as working Studio gameplay.
- **D-035.** FORGE-06 (Dialogue & Content) joins. It owns `content/dialogue/`, `content/citizens/` and their generated modules. Its content merges only as labelled DRAFT starter content, or with the user's approval. The ownership rows are in a separate PR for FORGE-05 review.
- **D-036 cinematic conversations.** Approved design and ownership. Contract: **CONTRACTS G13.8** (v0.4-g5). The G13.1 ContentQuery API list now names `fireDecision` listeners, `fireAction`, `citizenKey`, `LOYALTY_CLAMP`, `startLoyalty`, `choicePreview` and `choiceRisks`.
- Tasks FL-0097 to FL-0102 (below) and `agents/forge-06/`.

## Your work
Your VS-1 queue order is unchanged. The cinematic tasks start only when their dependencies land.

| Worker | VS-1 now (unchanged) | Cinematic (after deps) |
|---|---|---|
| FORGE-01 | FL-0079 ConversationService (use `ContentQuery.startLoyalty` in #61), FL-0081 PlaceSlot server, throne seat | FL-0097 Converse look/position, conversation hold, `Kingdom.EndConversation` |
| FORGE-02 | Soldier kingdom crest (G13.2), #73 palette | FL-0098 `Kit.portrait` with `PortraitFocus` |
| FORGE-03 | #63 army/capture, quota fix with #61, FL-0088 merge | FL-0099 rising portrait, speech bubble, chips |
| FORGE-04 | #42/#49 main merge, #45 when conversations land, FL-0091 bubbles | FL-0100 `focusOn`/`restore`, reaction poses |
| FORGE-05 | Merges, B6 build (population, conversations, capture), colour-vision check | FL-0101 integration, STUDIO_PLAYTEST rows, B-build |
| FORGE-06 | FL-0102 DRAFT starter pack (can start now) | Variants, emotion metadata |

## Interfaces touched
These changes are additive:
- `Kingdom.Converse` gains `look`, `job`, `position` and `kingdom`.
- A new remote, `Kingdom.EndConversation`.
- `Kit.portrait`.
- `ConversationController.opened`/`closed`.
- `RulerCameraController:focusOn`/`restore`.
- `Society.conversationHoldSec`.

## Open issues and risks
- **Match length** is still unresolved: 25 + 5 minutes, or the current longer schedule (FL-0096). Do not change the `match` profile.
- **Crown Arena** format, victory rules and support strength still need the user's approval.

## Next actions for the receiver
Merge `origin/main`, then read D-034 to D-036 and G13.8. Keep your VS-1 task first. Write a handoff to me if a G13.8 shape does not fit your code before you build it.
