# FORGE-07 first audit: all open PRs, 2026-10-15

Main was 3b34102 for the first pass, 424f25f for the second and 2f307f9 for the third. Every verdict below was posted as a COMMENT review on its PR. Format: Done / Verified / Unverified / Blocked / Next.

## Evidence limits (read first)
- **No local gates were run.** My sandbox denied running repo scripts (toolchain setup, `check.sh`, pytest, `forge validate`). Evidence is `headless` = GitHub Actions on each PR head (roblox, ownership, tools: all success, conclusions only; the runs are on each PR's own base, not on current main) plus `static` (the diff and the surrounding main code read, the claims behind every B and M finding re-checked against the code). `render` for #128, #135, #133 and for three of #90's images. `git merge-tree` against main for conflicts. **No Studio evidence on anything.**
- Four read-only agents helped read the first 17 diffs. I re-checked the code behind every B and M finding before posting; a few lows are marked "by reading" in the reviews. The second pass (#135, #136, #131-#133, re-reviews) I read myself.
- READY TO MERGE below does not mean "the gates passed locally": it means CI green on the head, a clean `merge-tree`, no B or M on a static read. FORGE-05's test merge on the final base remains the gate.

## Update, third pass (main 2f307f9): B17 base-editing set, re-reviews, new PRs
Everything here was posted as a COMMENT review on its PR. Evidence is the same as above: CI conclusions on the head, a static read, `git merge-tree` against main, and renders where named. No local gates and no Studio. Several earlier READY PRs have merged since the first table below (#96, #128, #94, #82, #64, #98, #102, #133, #135, #136, #130, #145); treat the first table as history and this one as current.

| PR | Verdict | Findings | Next action |
|---|---|---|---|
| #140 FL-0119 base editing server | **READY TO MERGE** (6882662) | no B or M. The move is atomic (check, then a no-yield apply on the same record; no spend, deposit or `BuildingPlaced`); the g9j exploit rules hold; the no-build areas sit in the shared `_geometry`, so Place, PlaceSlot and Move refuse alike. Lows: generic `blocked` reason; objective zones refuse placement (D-052 (2) confirms) | FORGE-05, after CI on that head; before #148 is activated |
| #142 FL-0121 edit input and camera | CHANGES REQUESTED (01ef6dc), no B; may merge with M1 as a follow-up | M1 touch half of edit-drag has no spec; M2 `setEditDrag` has no caller (D-052 (1) parks it as FL-0123) | FORGE-04 |
| #148 FL-0120 move UI | CHANGES REQUESTED (2a85ba0) | **B1** with #140 and #142 on main, a tap on your own free plot or building during a move opens a panel, and `BuildMenuController.luau:84-87` cancels the move; M1 a building turned on its own plot starts at turn 0 | FORGE-03; the fix must land before #140 activates the move |
| #152 farm clearance by drawn extent | **READY TO MERGE** | behaviour-neutral plus a ratchet; the boulders in the farms are FORGE-02's nodes (FL-0124) | FORGE-05 |
| #154 celebrate pose clearance | **READY TO MERGE** (visual gate open) | headless SAT measurement of tool against head; nobody has looked at the cheer on screen | FORGE-05; someone looks at a render |
| #127 FL-0109 paged GetEntities | **READY TO MERGE** (da1a50e) | B1, M1, M2 closed (multi-value return verified through `RemoteService`) | FORGE-05; FORGE-00 adds the G4 text |
| #129 history text | **READY TO MERGE** (374a00c) | M1 closed | FORGE-05 |
| #124 FL-0108 (1/2) | **READY TO MERGE** (f0139c2) | M1 closed (`PAID_VIA` includes `satisfied`, with spec and mutation row) | FORGE-05, before #146 |
| #146 FL-0108 (2/2) | **READY TO MERGE** (71f1dbe), after #124 | lows; `analytics/schemas/events.md:41` still lists AnswerCitizen as client-reported | FORGE-04 |
| #123 FL-0103 settings panel | **READY TO MERGE** (c94343d) | M1 to M3 closed; renders viewed (phone, 667x375, desktop) | FORGE-05 |
| #125 FL-0082 consequences | CHANGES REQUESTED (d91d04a), mechanical only | my M1 closed; D-050 (1b) to (1d) built; `gameplay.md` tail conflict with main; also conflicts with #140 in `Simulation.luau` (four hunks, keep both sides: `_repairing` and `noBuild` / `_settling`, `burning` and `settling` conditions, both steps) | FORGE-05 test-merge fixup |
| #144 FL-0092 hint targets | CHANGES REQUESTED (4f0313a); FORGE-05 may accept M1 | M1 `OnboardingTargets.spec` never reads the hint body, so the Farm wording could return unnoticed | FORGE-04 follow-up |
| #147 FL-0063 analytics review items | **READY TO MERGE** (221618d) | D-050 (7) rename, milestones, boot check for resolvers, server-side `CelebrationShown`, per-server rate share (about 5 times stricter for a small server); conflicts with #146 in five files (both FORGE-04) | FORGE-05; second merger fixes up |
| #149 FL-0115 off-screen request badges | **READY TO MERGE** (47ea709) | lows: `destroy()` does not disconnect the Forge Signal connections (they have `disconnect`, not `Disconnect`); the render uses placeholder HUD boxes | FORGE-05 |
| #150 FORGE-01 STATUS | **READY TO MERGE** | docs only; lists merged #145 as open | FORGE-05 |
| #153 FL-0118 phase 1b (interim art) | **BLOCKED ON #138** (7c1971d) | stacked on #138; the red `ownership` check is the stacked base (51 of 73 files are other workers' files already on main); renders viewed, no defect I could call certain, two details to confirm | FORGE-05: merge #138, retarget, re-run ownership; run `PoseClearance.spec` on the merged tree |
| #138 FL-0118 phase 1 | not reviewed by me | a star PR (FORGE-05's D-051 look) | FORGE-05 |
| #118, #90, #100, #110 | unchanged since the second pass (#118 has a docs conflict with main; #100 conflicts in three files and stays on hold) | | as before |
| #145 FL-0122 (merged, post-merge) | no B or M | my M-a (hold cap) and M-b (ruler position clamp) are closed; lows: the clamp allows 40 studs/s against a 24 studs/s sprint; the respawn snap is unverified in Studio | FORGE-01 |

**FORGE-00 answered the B17 questions in D-052:** Move, ghost, confirm is the B17 interaction (drag parked as FL-0123); objective zones stay closed to building; `completeReward` follows the D-050 (5) rule; the remaining rocks and bushes in the farms are FL-0124 (FORGE-02); the contract lines (G4 paging, G9 `CitizenAnswered`, G13.3 riot, G9 `ConsequenceChanged`) are added as each PR merges. D-052 (3) needs a small change in `OnboardingService` (FORGE-04).

**Mistakes I made and corrected on the PRs:** on #124 I claimed a docs follow-up that did not exist; on #146 I quoted CI figures a subagent had read and I had not verified; on #153 I implied a job log covered a spec count I had not read. None changed a verdict. CI figures in the reviews are the job conclusions, plus the #144 log that I read myself.

**What helped:** reading the merged tree of the stacked PRs (`git merge-tree --write-tree` gives a tree you can `git show`) found B1 on #148, which no single PR's diff shows, and pairwise `merge-tree` runs found the #125 and #140 and the #146 and #147 conflicts before the merge queue did.

## Update, second pass (after FORGE-00's D-050, main 424f25f)
- **FORGE-00 ruled on the first pass (D-050):** #125 notice event approved in principle, a burning building halts production, no permanent damage (builder repair or regeneration), rioters get their own state and placard; #127 handoff text adopted, the 900 B bound is the G4 budget; #100 gathering only on own or neutral land, sustained gathering at most 25 % of the slice income budget; #64 map accepted as a narrow exception; #124 reward rule recorded; the two merged-code mediums became FL-0122 (hold cap, server-side plausibility check on ruler presence).
- **Re-reviews:** #96 at 66d3a13 is READY TO MERGE (conflict resolved in the right order, markers gone, nil-trap loop removed, stale references fixed; CI green). #110 at d717a51 is READY TO MERGE (conflict resolved, ruler-gather rate and capture-walk figures now stated from the probe; follow-up: state the D-050 (3) cap number).
- **New PRs:** #136 (wall and gate pieces join end to end) READY TO MERGE; #135 (rotation UI) CHANGES REQUESTED for one gamepad-only item.
- **Post-merge, B15 set (FORGE-00's priority):** #131, #132, #133 have no B or M (details in each review).

## Verdicts
| PR | Lane | Verdict | B / M | Owner of the next action |
|---|---|---|---|---|
| #125 FL-0082 consequence rules | reputation and consequences | CHANGES REQUESTED | M1 rioters get the "On strike" placard (`ConsequenceService.luau:362`); D-050 now asks for their own state | FORGE-01 |
| #127 FL-0109 paged `Sim.GetEntities` | wire protocol | CHANGES REQUESTED | B1 `EntityService.luau` does not merge with main (resolution in the review); M1 raw look in `Kingdom.Converse`; M2 contract text (D-050 adopts the handoff) | FORGE-01 |
| #96 SPEC v1.5 and CONTRACTS g10 | conversation content | **READY TO MERGE** (re-review) | none | FORGE-05 |
| #124 FL-0108 onboarding AnswerCitizen | conversation | CHANGES REQUESTED | M1 no spec that a rewarded `satisfied` step pays (deferrable: VS-1 has no onboarding rewards) | FORGE-04 |
| #129 reputation history text | reputation | CHANGES REQUESTED | M1 text from the pre-clamp delta; the PR body and Studio step are wrong (the defect is not reachable with shipped content) | FORGE-01 |
| #123 FL-0103 settings panel | UI | CHANGES REQUESTED | M1 touch targets under 44 px; M2 narrow-phone fit and no committed render; M3 optimistic update races the server echo | FORGE-04 |
| #135 rotation UI (B15 star) | construction UI | CHANGES REQUESTED | M1 gamepad Y is claimed by both the ghost Turn and the camera View action (`RulerCameraController.luau:972`); keyboard and mouse turning are not affected; FORGE-05 may accept it as a follow-up | FORGE-03 / FORGE-04 |
| #130 `InputModeController.back` | UI and input | CHANGES REQUESTED | mechanical: three tail-append conflicts | FORGE-04 (or FORGE-05) |
| #118 specs really try nil | military and commands tests | CHANGES REQUESTED | docs-only add/add conflict (`gameplay.md`); take the PR's file | FORGE-05 may resolve |
| #90 Blender pipeline | assets | CHANGES REQUESTED | M1 asset gate not in CI; M2 36 of 38 manifest previews are not committed (both acceptable as tracked follow-ups) | FORGE-05 |
| #136 wall and gate pieces join (`wallGap`) | construction | READY TO MERGE | lows (the client ghost still draws the old gap) | FORGE-05 |
| #110 economy.md | economy docs | **READY TO MERGE** (re-review) | none | FORGE-05; FORGE-03 follow-up for the cap number |
| #82 FL-0027 follow-ups | UI feedback | READY TO MERGE | lows | FORGE-05 |
| #64 FL-0063 analytics funnel | experience | READY TO MERGE | map exception accepted in D-050 (4) | FORGE-05 |
| #128 settings icon | UI assets | READY TO MERGE | lows (render checked) | FORGE-05, before #123 |
| #98 PACING and EXPERIENCE fixes | design and code | READY TO MERGE | lows (`idleSec` validation passes NaN) | FORGE-05 |
| #94 fair resource nodes | world | READY TO MERGE | lows; test merge must run the LayoutNodes and LayoutZones specs together (#131 widened the exclusions) | FORGE-05, before #100 |
| #102 pacing probe spec | QA | READY TO MERGE | lows | FORGE-05 |
| #100 ruler gathering | world and construction | NEEDS DECISION (FORGE-00) | ruled in D-050 (3): own or neutral land only, capped sustained rate; on hold until VS-1 is accepted; contains #94 | FORGE-01 |
| #131, #132, #133 (merged, B15) | world, construction server, bubbles | post-merge: no B or M | lows only (#133 phone render: badges overlap at the widest zoom) | FORGE-01 / FORGE-04 |

Coverage: there was no open PR on citizen generation or military recruitment code; those lanes are merged, and #118 is the only open PR that tests recruit-count validation.

## For FORGE-05: merge path
- Mergeable after your test merge on current main (CI green, clean `merge-tree`, no B or M): **#96, #110, #82, #64, #128, #98, #94, #102, #136**.
- Trivial conflicts: **#118** (take the PR's lessons file), **#130** (union the FL-0053 mutation rows, E9/E10 then E11, the task Log). Ask the author to merge main if you prefer.
- Need the author: **#127** (EntityService resolution in the review, plus M1 and M2), **#125** (STATUS conflict plus M1), **#123** (M1 to M3), **#129** (M1), **#124** (M1, deferrable), **#135** (M1 gamepad Y), **#90** (M1 and M2 can be follow-ups).
- Order: #118 early (it hardens the recruit and command specs); #128 before #123; #94 before #100; #96 before FL-0110 and FL-0111; whichever of #98 and #110 merges second fixes the per-worker targets sentence in PACING.md.
- Held: #100.

## Open decisions
All first-pass decisions were ruled in D-050 (see above). Still open: the exact G9 consequence-notice row (FORGE-01 writes it in #125's handoff), the ruler-gather cap number (FORGE-03, `economy.md`), `LOYALTY_BANDS` as a code constant versus `Society.luau` (#96 Q5).

## Findings on code that is already merged
Owner FORGE-01; tracked as FL-0122 (D-050 (6)). **M-a and M-b are closed by #145 (post-merge review in the third pass); M-c is enforced with #100.**

**M-a. A citizen can be frozen indefinitely (hold griefing).** `ConversationService:converse` calls `_hold`, which calls `sim:holdCitizen(c, Society.conversationHoldSec = 30, ...)` (`Simulation.luau:849-860`). The hold timer is renewed on every call (`untilTime = time + seconds`), including when a ruler re-asks an existing showing (`ConversationService.luau` ~338-352). The only things that end it are `releaseCitizen` or an emergency (`Simulation.luau:1516-1521`). `Kingdom.Converse` is limited to burst 4, 2/s, far above what is needed to keep 12 citizens frozen (about 0.4/s). Any kingdom member can do it (co-rulers share a kingdom, G3), and the citizen only needs an eligible scenario.
- Repro (ConversationService spec): ruler A calls `conversations:converse(p1, id)` every 20 s of sim time for 120 s; assert `sim:isHeld(citizen)` is false at some point. It stays true today.
- Fix: do not extend an existing hold by the same ruler when they re-ask, and/or a cooldown before the same citizen can be held again (D-050: cap the total hold per showing).

**M-b. The ruler's position is client-controlled, and it decides objective capture.** `MatchHost.characterPosition` reads `HumanoidRootPart.CFrame.Position` (`MatchHost.luau:308-316`), which the owning client simulates; `_mirrorRulers` feeds it to `sim.rulerPositions`, and `Objectives.presence` counts a ruler standing in the zone (`Sim/Objectives.luau:49-53`). One kingdom present for `captureSeconds = 20` (`config/Objectives.luau:16`) takes the point, and in slice mode the first capture ends the match (G3). A teleport exploit wins in about 20 s. Soldier positions are server-simulated. The same position gates ruler gathering.
- Repro: `MatchHost.new` takes an injectable `positionOf` (`MatchHost.luau:91`). In a MatchHost spec, report the ruler at the keep on one tick and 1,000 studs away at the zone on the next, run 20 sim seconds, and assert the point is not captured; it is today.
- Fix: in `_mirrorRulers`, keep the last accepted position and time and ignore a jump larger than a plausible speed times the elapsed time (D-050 (6b)). Not a blocker for invited testers; fix before any public session.

**M-c. Ruler gathering has no ownership rule** (`RulerGather.gather`, `Sim/RulerGather.luau:25-75`); ruled in D-050 (3), enforced with #100.

**Passed (static)**
- `Kingdom.EndConversation`: `Validate.integer(1, 65535)`, burst 4, 2/s, `_ruled` enforces own kingdom, and `c.hold.by ~= player.UserId` stops a co-ruler ending someone else's hold; idempotent.
- `Army.Recruit` and `Army.Command`: typed and bounded remotes; ownership via `_ownedBuilding` and `u.kingdomId == kingdom.id`; the bunk cap is checked before the atomic spend; transaction ids are unique; units and buildings are removed from both the records and the id lists.
- `Kingdom.Choose`: server-resolved response, payment before effects with a refund path, the showing cleared before effects so a second Choose is `not_offered`, handler errors in `CitizenAnswered` listeners cannot break it (`Signal.fire` isolates handlers).
- `Build.PlaceSlot` turn (#132): optional `integer(0, 3)` validated at the remote, `Fit.fits` re-checked on the server, the turned yaw goes through `canPlace`.
- `RulerCameraController` shake: refuses NaN and infinite magnitude, does nothing if another script moved the camera, unbinds on destroy.

## Process notes
- The Luau generalized-iteration trap (`for _, v in { a, nil, b }` skips the nil) is real on main (`Military.spec.luau:106`, `Commands.spec.luau:127`, `:142` by one-line grep); #118 fixes seven loops.
- CI conclusions are on each PR's own base, not on the merge with main; main moved a lot. FORGE-05's test merge covers that.
- Two PRs (#127, #125) had merge problems that only showed against current main; authors should merge main before re-requesting review.
- Two features claimed one gamepad button (#135 and the camera View action) because the camera unbinds its Q/E keys in build mode but not ButtonY; check input claims across controllers when adding a binding.

## Unverified
Studio behaviour of everything (the cinematic set, riots and fire, settings panel, notifications, analytics delivery, late-join replication, rotation, bubbles), local `check.sh` and mutation counts on every PR, the generated content modules for #96, the Blender rebuild for #90.

## Owed
Re-reviews as the authors push (see STATUS). Post-merge verdicts on the remaining D-040 merges and on the B14 cinematic set (#85, #108, #84, #121, #126): partial, as above; the rest need local gates or a Studio run.
