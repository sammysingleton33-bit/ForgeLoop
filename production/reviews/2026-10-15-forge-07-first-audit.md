# FORGE-07 first audit: all 17 open PRs, 2026-10-15

Main was 3b34102. Every verdict below was posted as a COMMENT review on its PR. Format: Done / Verified / Unverified / Blocked / Next.

## Evidence limits (read first)
- **No local gates were run.** My sandbox denied running repo scripts (toolchain setup, `check.sh`, pytest, `forge validate`). Evidence is `headless` = GitHub Actions on each PR head (roblox, ownership, tools: all success, conclusions only; the runs are on each PR's older base, not on current main) plus `static` (the diff and the surrounding main code read, the claims behind every B and M finding re-checked against the code). `render` for #128 and for three of #90's images. `git merge-tree` against main for conflicts. **No Studio evidence on anything.**
- Four read-only agents helped read the diffs. I re-checked the code behind every B and M finding before posting; a few lows are marked "by reading" in the reviews.
- No READY TO MERGE below means "the gates passed locally": it means CI green on the head, a clean `merge-tree`, no B or M on a static read. FORGE-05's test merge on the final base remains the gate.

## Verdicts
| PR | Lane | Verdict | B / M | Owner of the next action |
|---|---|---|---|---|
| #125 FL-0082 consequence rules | reputation and consequences | CHANGES REQUESTED | M1 rioters get the "On strike" placard (`ConsequenceService.luau:362`); Q1, Q2 for FORGE-00 | FORGE-01; FORGE-00 for Q1 and Q2 |
| #127 FL-0109 paged `Sim.GetEntities` | wire protocol | CHANGES REQUESTED | B1 `EntityService.luau` does not merge with main (resolution in the review); M1 raw look in `Kingdom.Converse`; M2 contract text | FORGE-01; FORGE-00 (G4 text) |
| #96 SPEC v1.5 and CONTRACTS g10 | conversation content | CHANGES REQUESTED | B1 `CONTRACTS.md` conflict (order g10, g9h, g9g, g9f) | FORGE-00 |
| #124 FL-0108 onboarding AnswerCitizen | conversation | CHANGES REQUESTED | M1 no spec that a rewarded `satisfied` step pays (deferrable: VS-1 has no onboarding rewards) | FORGE-04 |
| #129 reputation history text | reputation | CHANGES REQUESTED | M1 text from the pre-clamp delta; the PR body and Studio step are wrong (the defect is not reachable with shipped content) | FORGE-01 |
| #123 FL-0103 settings panel | UI | CHANGES REQUESTED | M1 touch targets under 44 px; M2 narrow-phone fit and no committed render; M3 optimistic update races the server echo | FORGE-04 |
| #130 `InputModeController.back` | UI and input | CHANGES REQUESTED | mechanical: three tail-append conflicts | FORGE-04 (or FORGE-05) |
| #118 specs really try nil | military and commands tests | CHANGES REQUESTED | docs-only add/add conflict (`gameplay.md`); take the PR's file | FORGE-05 may resolve |
| #110 economy.md | economy docs | CHANGES REQUESTED | `agents/forge-03/STATUS.md` conflict only; L1 ruler gathering numbers | FORGE-05 may resolve; FORGE-00 / FORGE-03 for L1 |
| #90 Blender pipeline | assets | CHANGES REQUESTED | M1 asset gate not in CI; M2 36 of 38 manifest previews are not committed (both acceptable as tracked follow-ups) | FORGE-05 to accept or hand off |
| #82 FL-0027 follow-ups | UI feedback | READY TO MERGE | lows | FORGE-05 |
| #64 FL-0063 analytics funnel | experience | READY TO MERGE | Q1 for FORGE-00 (private membership map) | FORGE-05 |
| #128 settings icon | UI assets | READY TO MERGE | lows (render checked) | FORGE-05, before #123 |
| #98 PACING and EXPERIENCE fixes | design and code | READY TO MERGE | lows (`idleSec` validation passes NaN) | FORGE-05 |
| #94 fair resource nodes | world | READY TO MERGE | lows | FORGE-05, before #100 |
| #102 pacing probe spec | QA | READY TO MERGE | lows | FORGE-05 |
| #100 ruler gathering | world and construction | NEEDS DECISION (FORGE-00) | M1 no ownership rule on gather; M2 client-controlled position; Q1 gather rate. On hold until VS-1 is accepted; contains #94 | FORGE-00 |

Coverage: the review queue lanes you listed are all covered where a PR is open. There is no open PR on citizen generation or military recruitment code; those lanes are merged, and #118 is the only open PR that tests recruit-count validation.

## For FORGE-05: merge path
- Mergeable after your test merge on current main (CI green, clean `merge-tree`, no B or M): **#82, #64, #128, #98, #94, #102**.
- Trivial conflicts you may resolve in the integration merge: **#118** (take the PR's lessons file), **#110** (take main's STATUS and re-apply the estimate-table hunk), **#130** (union the FL-0053 mutation rows, E9/E10 then E11, the task Log).
- Need the author: **#127** (EntityService resolution in the review, plus M1 and M2), **#125** (STATUS conflict plus M1), **#96** (CONTRACTS conflict), **#123** (M1 to M3), **#129** (M1), **#124** (M1, deferrable), **#90** (M1 and M2 can be follow-ups).
- Order: #118 early (it hardens the recruit and command specs); #128 before #123; #94 before #100; #96 before FL-0110 and FL-0111; whichever of #98 and #110 merges second fixes the per-worker targets sentence in PACING.md.
- Held: #100.
- Merge-conflict map against main 3b34102: conflicts only in #127 (`EntityService.luau`), #96 (`CONTRACTS.md`), #125 (`agents/forge-01/STATUS.md`), #130 (3 files above), #118 (`docs/lessons-learned/gameplay.md`), #110 (`agents/forge-03/STATUS.md`). The other 11 merge cleanly.

## For FORGE-00: decisions
1. **#125** a G9 `Kingdom.Consequence` notice event (the task requires "a cue and a notice"; the PR proposes it to FORGE-05). Riot design: `living-kingdom.md:111` says "production halt", but nothing reads `burning`, and one riot leaves a building "Damaged" for the match (no repair path in `src`). Is that intended for VS-1? Also the rioters' placard (M1).
2. **#127 / M2** adopt the handoff's G4, G13.2 and G5 text for the new `Sim.GetEntities` signature (CONTRACTS G4 line 138 still says one buffer). Is the 900 B bound real for a RemoteFunction, or a self-imposed budget? Say which in G4.
3. **#100 / merged code** should ruler gathering be limited to the ruler's own nodes? Today any ruler within range gathers any kingdom's node. And the rate: shipped `RulerGather.CONFIG` is about 150 wood/min for a continuous gatherer, against the 44 wood/min that #110's slice budget assumes (`economy.md:69`, `:85` says "5-10 per harvest").
4. **#64** is the private userId-to-kingdom map in `MatchAnalyticsService` an accepted exception to "attribution lives in `Signals`"?
5. **#124** one line in G9 funnel attribution for `CitizenAnswered`; record the onboarding reward rule change in DECISIONS?
6. **#96** `thought_bubble_s` and `delivery_mode` are not carried to any client (extend `thought` or mark them reserved); five questions for FL-0110 are in the review (loyalty before or after the answer, trait variants need `c.profile.traits`, pin `cond:` variants per showing, a runtime tag allowlist, bands in `Society.luau`).

## Findings on code that is already merged (no PR to comment on)
These are on main now. FORGE-01 owns the fixes unless noted; FORGE-05 decides whether they ride the next gameplay PR.

**M-a. A citizen can be frozen indefinitely (hold griefing).** `ConversationService:converse` calls `_hold`, which calls `sim:holdCitizen(c, Society.conversationHoldSec = 30, ...)` (`Simulation.luau:849-860`). The hold timer is renewed on every call (`untilTime = time + seconds`), including when a ruler re-asks an existing showing (`ConversationService.luau` ~338-352). The only things that end it are `releaseCitizen` or an emergency (`Simulation.luau:1516-1521`). `Kingdom.Converse` is limited to burst 4, 2/s, which is far above what is needed to keep 12 citizens frozen (about 0.4/s). Any kingdom member can do it (co-rulers share a kingdom, G3), and the citizen only needs an eligible scenario. Effect: a hostile co-ruler stops the whole workforce.
- Repro (ConversationService spec): ruler A calls `conversations:converse(p1, id)` every 20 s of sim time for 120 s; assert `sim:isHeld(citizen)` is false at some point. It stays true today.
- Fix: do not extend an existing hold by the same ruler when they re-ask, and/or a cooldown before the same citizen can be held again.

**M-b. The ruler's position is client-controlled, and it decides objective capture.** `MatchHost.characterPosition` reads `HumanoidRootPart.CFrame.Position` (`MatchHost.luau:308-316`), which the owning client simulates; `_mirrorRulers` feeds it to `sim.rulerPositions`, and `Objectives.presence` counts a ruler standing in the zone (`Sim/Objectives.luau:49-53`). One kingdom present for `captureSeconds = 20` (`config/Objectives.luau:16`) takes the point, and in slice mode the first capture ends the match (G3). A teleport exploit therefore wins in about 20 s. Soldier positions are server-simulated and are not affected. The same position gates ruler gathering.
- Repro: `MatchHost.new` takes an injectable `positionOf` (`MatchHost.luau:91`). In a MatchHost spec, report the ruler at the keep on one tick and 1,000 studs away at the zone on the next, run 20 sim seconds, and assert the point is not captured; it is today.
- Fix: in `_mirrorRulers`, keep the last accepted position and time and ignore a jump larger than a plausible speed times the elapsed time (treat the ruler as absent until the position is plausible again). Not a blocker for invited testers; fix before any public session.

**M-c. Ruler gathering has no ownership rule** (see #100): `RulerGather.gather` (`Sim/RulerGather.luau:25-75`) never checks which kingdom a node belongs to.

**Passed (static)**
- `Kingdom.EndConversation` (G4 review the status doc asked for): `Validate.integer(1, 65535)`, burst 4, 2/s, `_ruled` enforces own kingdom, and `c.hold.by ~= player.UserId` stops a co-ruler ending someone else's hold; idempotent.
- `Army.Recruit` and `Army.Command`: typed and bounded remotes; ownership via `_ownedBuilding` and `u.kingdomId == kingdom.id`; the bunk cap is checked before the atomic spend; transaction ids are unique; units and buildings are removed from both the records and the id lists, so the unguarded loops are safe.
- `Kingdom.Choose`: server-resolved response, payment before effects with a refund path, the showing cleared before effects so a second Choose is `not_offered`, and a handler error in `CitizenAnswered` listeners cannot break it (`Signal.fire` isolates handlers).
- `RulerCameraController` shake: refuses NaN and infinite magnitude, does nothing if another script moved the camera, unbinds on destroy.

## Process notes
- The Luau generalized-iteration trap (`for _, v in { a, nil, b }` skips the nil) is real on main (`Military.spec.luau:106`, `Commands.spec.luau:127`, `:142` by one-line grep); #118 fixes seven loops. Specs across the repo were otherwise free of it where I looked.
- CI conclusions are on each PR's older base, not on the merge with main; main moved a lot (for example Simulation.luau by about 228 lines since #94's base). FORGE-05's test merge is what covers that.
- #125, #127 and #96 each had a merge problem that only shows against current main; authors should merge main before re-requesting review.

## Unverified
Studio behaviour of everything (the cinematic set, riots and fire, settings panel, notifications, analytics delivery, late-join replication), local `check.sh` and mutation counts on every PR, the generated content modules for #96, the Blender rebuild for #90.

## Owed
Re-reviews as the authors push (see STATUS). Post-merge verdicts on the 25 D-040 merges and on the B14 cinematic set (#85, #108, #84, #121, #126): partial, as above; the rest need local gates or a Studio run.
