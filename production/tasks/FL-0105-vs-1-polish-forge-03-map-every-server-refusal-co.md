---
id: FL-0105
title: "VS-1 polish (FORGE-03): map every server refusal code, dark emblem on light tinctures, Toast achievement accent"
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0059]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 2
evidence:
  - "bash roblox/scripts/check.sh PASS (framework 512/0, game-001 940/0); 17/17 mutations killed; renders looked at: crests-900x420, kingdom-*, placing-bad-*, kit-1280x1400 (toast row)"
  - "main 2a6a247: check.sh PASS on 4502935+#86 (game-001 1101/0); ownership PASS 72 files; CI 3/3 on 5eb2d61; e2e refusal texts in words for 9 cases; mutations 27/34 caught"
  - "#86 at 5eb2d61: FORGE-05 test merge check.sh PASS (516/0, game-001 1101/0), 27/34 mutations caught (7 survivors addressed in the follow-ups PR)"
  - "main f2d430a: check.sh PASS on 2570c47+#103 (game-001 1103/0); combined 1111/0; CI 3/3 on bf1e245; 2/2 mutations; renders kingdom-phone, hud-phone, crests checked by eye"
---

# VS-1 polish (FORGE-03): map every server refusal code, dark emblem on light tinctures, Toast achievement accent

## Outcome
When the server refuses a build or an order, the player reads the real reason (outside your territory, cannot afford, needs a bigger keep) instead of 'That didn't work'. Sunspire's sun emblem is readable on gold.

## Context
- Backlog audit 2026-10-13: UI/Text.luau maps territory/zone/overlap/blocked/cost, but the server returns out_of_territory, out_of_bounds, cannot_afford, requires_keep_level, limit_reached, not_placeable, unknown_building (handoff 2026-10-13-forge-01-to-forge-03-refusal-codes.md); #79 review Medium (sun emblem on the new gold); #33 L2 Toast `achievement` accent (FORGE-04 asks in #82).

## Requirements
- Map every refusal code FORGE-01 returns (Build and, after #70, Army) to player text; a spec iterates the server's code list.
- Dark emblem on light tinctures; render all 4 crests.
- Toast `achievement` accent and icon.

## Validation
- Automated: refusal-code coverage spec; Toast spec.
- Render: 4 crests and refusal toasts reviewed.
- Studio (user): ui-economy.md U4 step 2, STUDIO_PLAYTEST section 8 step 3.

## Completion criteria
- [ ] All codes mapped
- [ ] Emblem readable
- [ ] Toast accent

## Log
- 2026-10-13 forge-00: created from the backlog audit (D-038) (READY).
- 2026-10-13 forge-03: READY → BUILDING. Started in #86 (forge/03-ui-economy-crest): server refusal codes, gold crest sunburst on ivory roundel, Toast achievement accent
- 2026-10-13 forge-03: BUILDING → REVIEW. PR #86: Text maps every code of Build/Remotes Reasons + Upgrade/Gather/SetJobQuota (Army codes are UI/ArmyText's, #63); drawn sunburst on ivory roundel (FORGE-02 design), >=3:1 for all 4 canonical colours; Toast achievement = purpure + laurel (FORGE-04 can drop KIND_ICON). Studio unverified.
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #86 (2a6a247, FORGE-05 D-040 fallback verdict on 5eb2d61; promoted by FORGE-00). Every server refusal code is worded (Build, PlaceSlot incl. #89 codes, Upgrade, Army.Recruit bunks per D-041; not_on_plot per v0.4-g9a); D-039 emblems and gem badge. REVIEW: remaining non-Studio item M1 (ui-economy.md:41 U4 step 2 and prototype kingdom.js:236,439 still say 'Outside your territory'); then G6 (STUDIO_PLAYTEST row 6 step 3, U4, U7). Lows L1-L9 in the review. FORGE-07 post-merge review owed.
- 2026-10-13 forge-03: REVIEW → REVIEW. #86 merged (FORGE-05 D-040 READY). Follow-ups PR for its M1 (U4 step 2 sentence) and L2-L9. Final coverage: Build/Remotes Reasons (incl. PlaceSlot) and Army.Recruit reasons parsed by spec; not_on_plot worded ahead of the server.
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #103 (f2d430a, FORGE-05 D-040 fallback verdict on bf1e245; star by FORGE-00): #86 M1 (Studio U4 text) and L2-L9 done; FORGE-02 judged the midrib fine. REVIEW, only G6 pending (U4, U4.5, U7, STUDIO_PLAYTEST row 6 step 3).
