# Handoff: FORGE-00 → FORGE-04 · design reviews of events.md, PACING.md, EXPERIENCE.md and Subjects · 2026-10-13

## What I need / what I'm giving you
These are the FORGE-00 reviews you asked for on 2026-10-12 (handoff `2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md`), and they are completion criteria for FL-0023 and FL-0061.

How they were done: one reviewer per document checked it against BRIEF, CONTRACTS v0.4-g8, DECISIONS D-020 to D-038 and the platform docs, and a second reviewer re-checked every finding against `main`.

**All three documents need changes. Most findings are staleness:** they predate D-029 (Crown Arena), D-030 (VS-1 v2: seated ruler, aerial camera, conversations) and v0.4-g6 (funnel step order). They are not faults in your code.

Severity:
- **B** blocks acceptance.
- **M** must be fixed before VS-1 acceptance.
- **L** is optional.

Fix them in your next doc PRs. Per D-038 (7), split `events.md` per feature in the same pass.

**Do not decide open user decisions in these documents:** match length (FL-0096), Crown Arena details (FL-0077), PvP intensity, monetization.

## 1. Analytics taxonomy (`analytics/schemas/events.md`, `AnalyticsSchema.luau`, config `Analytics.luau`), for FL-0023 and FL-0063: **CHANGES NEEDED**

I re-checked every finding in the first review against origin/main 3bbf2a0 and the cited sources. B1 stands, so the verdict stays CHANGES NEEDED.

**What passes (re-verified):**
- **Platform facts:** the §1 and §3 quotes match creator-docs af5f853 word for word. I re-checked about 20 of them.
- **Naming:** names are PascalCase, and every event has 3 custom fields or fewer.
- **Personal data:** no custom field carries an id, a name, free text or a GUID.
- **Currency names:** nothing is called "Crowns".
- **VS1 funnel:** the steps match BRIEF §13.
- **Open user decisions:** nothing on main decides match length, the Crown Arena or monetization. §6 is the only near-miss (L1).

**Corrections to the first review:**
- **Duplicate:** B1 no longer repeats the changelog point; that stays in L2 only.
- **M3:** the proposed §2 rule "no analytics call is derived from a client remote" would contradict SettingChanged, an event that is already built (the client asks, the server validates and throttles). I reworded the rule.
- **Downgrade:** M6 (scope of the rate cap) is now L8. Expected load is far below either reading of the cap, and the reading itself is unverified.
- **Attribution:** #64's first review was FORGE-05's (CONTRACTS changelog line 582; FL-0063 log), not FORGE-07's. FORGE-07's re-review is pending.
- **#45 status:** it is not "held". It is unreviewed by FORGE-07 and conflicts with main, and D-038(1) allows an early merge.
- **#64 coverage:** #64 does not update the changelog to v0.4-g8. It also leaves the Return row saying "on PlayerReady".

**Added (missed by the first review):**
- **M8:** D-038(7) orders events.md split per feature in FORGE-04's next PR. A test merge confirms that #64 and #45 conflict in exactly the three files D-038(7) names.
- **M9:** the Onboarding row documents the v1 flow that BRIEF §4 v2 (D-030) replaced and that D-038(1) records as stalling.
- **PR notes:** #64's ConversationAnswered field combinations grow with the DRAFT content library. #64 also reads MatchService.mode, which is not in CONTRACTS G3.

**Blocking:**
- **B1:** the CONTRACTS G9 v0.4-g6 funnel-order rule is missing on main.

**Mediums:** M1 (sessions start on PlayerReady, which never fires), M2 (FirstGather and FirstRecruit are undefined), M3 (three events have no server producer), M4 (MatchEnded does not cover outcomes), M5 (the combination budget method), M7 (no milestone timing), M8 and M9.

**Once #64 merges:**
- B1 is resolved in the config, schema, adapter and VS1 row. Only the §4 bullet and the FL-0063 requirement line remain.
- M1 is fixed except for the Return row.
- The verdict would become APPROVED WITH CHANGES once the remaining mediums are closed.

**#45:** it must not merge its Onboarding row as written. The row claims an unlogged step is not counted, but Roblox counts skipped intermediate steps as completed.

- **B1 (B)** `analytics/schemas/events.md:64-67 (§4 attribution bullets), :91 (VS1 row 'G9 attribution, §4'), :30; roblox/src/shared/Experience/AnalyticsSchema.luau:15-17 (the funnel declaration cannot express step order); games/game-001/config/Analytics.luau:71-82 (VS1)`. §4 restates the G9 attribution rules: building completions and captures credit every current member of the kingdom. The VS1 row defers to §4. Nothing on main carries the v0.4-g6 rule that a step is credited only to a player who already holds the previous step, and the schema has no way to declare it.

Built as documented, a co-ruler who never placed a building or recruited would be credited FirstBuildingComplete and FirstCapture. Roblox counts skipped intermediate steps as completed (events.md:16), so FirstBuildPlaced and FirstRecruit would be inflated. That breaks the doc's own rule at :30.

The VS1 funnel is one-time and cannot be corrected after the first publish. No runtime effect today: main has `track = {}`.
  - **Conflicts with:** CONTRACTS.md:297-300 (G9 funnel order, v0.4-g6) and changelog :582; AnalyticsService.yaml LogFunnelStepEvent: 'if any steps are skipped, the intermediate steps will be considered completed'; PROJECT_STATUS.md:43 (#64 M2)
  - **Fix:** 1. Add a §4 bullet after :67: "Funnel order (CONTRACTS G9 v0.4-g6): a VS1 step n > 1 is credited only to a player who already holds step n−1 in this server visit (no persistence in VS-1, D-027). Otherwise it is counted in stats.dropped.outOfOrder and not sent. The G9 events, onboarding and the announcer still react kingdom-wide."
2. Mark VS1 `inOrder = true` in Analytics.luau.
3. Add `inOrder: boolean?` to the AnalyticsSchema funnel declaration, validate it, and reject it on the onboarding funnel.
4. Enforce the rule in AnalyticsService:funnel before _admit.
5. Leave Return unordered: its step 2 is logged on a later day, when step 1 is not in this visit's state.
6. Add `inOrder` to the VS1 row.
7. FORGE-00 adds the rule to FL-0063 Requirements (production/tasks/FL-0063…md:23), which still lists only kingdom-wide credit.

PR #64 (7ddc7cf) does steps 2–4 and 6. Steps 1 and 7 remain.
- **M1 (M)** `analytics/schemas/events.md:76 (SessionStart on PlayerReady), :92 (Return row on PlayerReady), :143 (§10 step 2); games/game-001/config/Analytics.luau:18, :90; roblox/src/server/Services/AnalyticsService.luau:151-157`. SessionStart, and with it the Return funnel, starts only on PlayerReady. On main, nothing fires PlayerReady: there is no PlayerService, and the only fire calls are in specs. VS-1 has no profiles (D-027). As a result:
- SessionStart never fires.
- `joinedAt` stays nil, so SessionEnd never fires (AnalyticsService.luau:643) and the drop-off point (lastActivity) is lost.
- §10 step 2 tells the user to expect `analytics event SessionStart ... sent=true` first, and that line never appears.
  - **Conflicts with:** D-027 ('Onboarding starts on KingdomJoined, not PlayerReady'); production/quality-gates/integration-log.md:29 (#22 medium 'session analytics never fire without PlayerReady'); BRIEF §13 'disconnects' (BRIEF.md:125)
  - **Fix:** 1. Add `session.startOn` to the schema and the adapter (default PlayerReady). game-001 sets `startOn = "KingdomJoined"`, once per server visit.
2. Update the SessionStart row, the Analytics.luau:18 description and the Return row (:92): 'at session start (config.session.startOn; game-001: KingdomJoined, D-027)'.
3. §10 step 2: 'When the kingdom is joined: SessionStart, then VS1 step=1 Spawn; the Onboarding step=1 Spawn line may come before or after them.'
4. State that spectators (no kingdom) get no session events.

PR #64 does all of this except the Return row, which still says 'AnalyticsService on PlayerReady'.
- **M2 (M)** `analytics/schemas/events.md:91 (VS1 'G9 attribution, §4'), :130 (§8 'VS1 funnel steps 2–4')`. G9 defines attribution for spawn, first build placed, completions and captures. It does not define 'first gather' or 'first recruit', yet the VS1 row cites G9 for every step. Two readings diverge:
- **Ruler-only:** this is how the Onboarding Gather step works (config Onboarding.luau:50, `source = "ruler"`). Under D-030, ruler gathering is optional and the ruler sits on the throne in the aerial view (G13.6). With the v0.4-g6 order rule, FirstGather would then block steps 3–6 for most players.
- **Kingdom-wide:** this is how the Signals resolver works (Signals.luau:115-121): a citizen gather credits every member. The step then means 'the economy started' and converts at about 100 %.

Once published, the one-time funnel's step meaning is frozen.
  - **Conflicts with:** BRIEF.md:124 (§13); D-030(1) (ruler gathering optional); CONTRACTS G9 (:293-300) and G13.6; games/game-001/src/shared/Feedback/Signals.luau:115-121; config Onboarding.luau:50
  - **Fix:** 1. Define both steps in the VS1 row:
   - **FirstGather:** the first ResourceGathered credited by Feedback/Signals. A ruler gather credits that player; a citizen gather credits every member. It measures that the kingdom's economy started.
   - **FirstRecruit:** the player named in UnitsRecruited.
2. FORGE-00 confirms this reading with one line in BRIEF §13. That is a FORGE-00 call, not a user decision.
3. Measure conversations as a custom event, not as a funnel step, until a server-side conversation event exists.
4. Settle any step change before the first publish.

PR #64 documents the kingdom-wide reading and asks FORGE-00 to rule. It does not define FirstRecruit.
- **M3 (M)** `analytics/schemas/events.md:82 (PhaseLeft), :83 (IdleHintShown), :84 (CelebrationShown); games/game-001/config/Analytics.luau:47-60`. Three planned events have no server-side producer:
- **PhaseLeft** names no emitter.
- **IdleHintShown** names no emitter. The hint is shown by the client `OnboardingController:showIdleHint(phase)` 'when FL-0062 detects dead air' (config Onboarding.luau:27-28), and nothing says that detection runs on the server.
- **CelebrationShown** names `NotificationController:celebrate` '(reported by the server)'. NotificationController is a client controller (roblox/src/client/Controllers/NotificationController.luau) and has no server path.

Roblox accepts analytics only from the server (events.md:13). As written, these events would need a client report, so the client could author or spoof them.
  - **Conflicts with:** AGENTS.md (the server is authoritative; validate every remote argument); events.md:13 (CE/FE/EE 'Events can only be sent from the server'); CONTRACTS G9 ('FORGE-04 (announcer, onboarding, analytics) ... subscribe')
  - **Fix:** Name a server producer and trigger in each row:
- **PhaseLeft:** FORGE-04 MatchAnalyticsService, through `session.leftInfo` at PlayerRemoving, logged before SessionEnd (as #64 does).
- **IdleHintShown:** logged by the FL-0062 server service that decides dead air, when it sends the hint. Never on a client report.
- **CelebrationShown:** logged on the server at the G9 event that causes the moment (BuildingCompleted, ObjectiveCaptured, OnboardingCompleted, via AnnouncerService or FL-0062), with `kind` taken from that event. Otherwise drop the event.

Add to §2: 'Only server code calls AnalyticsService. An event caused by a client request (e.g. SettingChanged) is logged only after the server has validated and applied it, under the per-player bucket. No event is logged on a client's report alone that something was shown or done.'

The first review's wording, 'no analytics call is derived from a client remote', would ban SettingChanged (SettingsService.luau:234), which is already built.
- **M4 (M)** `analytics/schemas/events.md:81 (MatchEnded), :131; games/game-001/config/Analytics.luau:42-46`. BRIEF §13 asks for kingdom outcomes, and MatchEnded falls short in four ways:
- **`won` is only true or false.** When G9 MatchEnded has `winner = nil` (no single winner: a tie, or the G3 PROVISIONAL 'ties share the win'), every ruler is logged as a loss (Signals.luau:146). The VS-1 slice cannot tie, because the first capture names the winner (G3), but full matches can.
- **`phase` is undefined.** When MatchEnded fires, MatchService is moving to Results.
- **`mode` lists only slice and match.** D-030(6) and BRIEF §16.10 add a non-default `match30` evaluation profile.
- **KingdomEliminated (G9) is not mentioned.**
  - **Conflicts with:** BRIEF.md:125 ('match length, kingdom outcomes, disconnects'); CONTRACTS.md:93 (G3, ties share the win, PROVISIONAL), :288 (G9 MatchEnded payload); D-030(6); BRIEF.md:166 (§16.10)
  - **Fix:** 1. CustomField01: values `true | false | draw` (draw = `winner` nil). Better, rename the field to `result` with values `won | lost | draw`. This labels the outcome and decides no victory rule.
2. Define `phase` as the last playing phase before Results (Founding..Endgame; Arena from VS-2, G12.1).
3. Define `mode` = `MatchService.mode` with values `slice | match | match30 | unknown`. Note that these are comparison labels, not a match-length decision (§16.10).
4. Add: 'KingdomEliminated is not logged in VS-1 (the slice has no elimination); VS-2 adds it as a custom event.'
5. Recompute the combinations (see M5 and L5).

PR #64 does steps 1–3. Step 4 remains.
- **M5 (M)** `analytics/schemas/events.md:49 (the combinations row); §1 :11-26 (no daily reset); :85 and games/game-001/config/Analytics.luau:61-64 (SettingChanged)`. The 8,000 cap is per experience, across all custom fields:
- AS: 'across the three custom fields per experience'.
- ET: 'After 8,000 combined values across all custom fields'.

The row budgets only the largest event and names the wrong one. SettingChanged is 5 volume keys × 101 values (Schema.checkSetting rounds to 0.01) + 4 booleans × 2 + 1 enum × 2 = 515 combinations. MatchEnded, the one the row names, is 24.

The main total of about 600 is safe. But the method hides growth: with #64 the total is about 1,850, not the 'about 1,300' it states. One of #64's new events grows with the DRAFT content library (see the PR notes). §1 also omits that limits reset daily (ET; research N3).
  - **Conflicts with:** creator-docs af5f853 AnalyticsService.yaml (customFields: 'Limited to 8,000 unique combinations of values across the three custom fields per experience'), event-types.md limitations table and 'Limitations reset daily'; custom-fields.md; roblox/src/shared/Experience/Schema.luau:95-104; docs/research/roblox-platform-constraints.md N3
  - **Fix:** 1. Replace the 'AI Kingdoms uses' cell with a per-event list of combinations and their sum, plus a house rule: 'total across all events < 2,000'.
2. Bucket SettingChanged volume values to tenths before logging (5 × 11 + 8 + 2 = 65).
3. Optionally rename SettingChanged's field `value` to `setting`.
4. Add a §1 row: 'Limitations reset daily' (ET).
- **M7 (M)** `analytics/schemas/events.md:130 (§8 'VS1 funnel steps 2–4'), :91`. Two sources expect milestone timings from analytics:
- PACING.md:85-86 promises the 'VS-1 funnel ... with step times compared against §3'.
- config Pacing.luau:14-15 calls its targets (firstGatherSec 45 … firstCaptureSec 450) 'tuning goals for playtests and analytics (FL-0063)'.

LogFunnelStepEvent carries no value, the creator docs describe no step-timing view, and funnel filters apply only to step 1 (FE). No event in the taxonomy measures seconds from spawn to a milestone, so the pacing targets cannot be checked from live data.
  - **Conflicts with:** games/game-001/design/pacing/PACING.md:85-86; games/game-001/config/Pacing.luau:14-15, :39-44; creator-docs funnel-events.md 'Use funnel filters' ('filters only apply to the first step')
  - **Fix:** Add a custom event MilestoneReached:
- value = seconds since this player's Spawn in this visit;
- CustomField01 milestone = the VS1 step name (5 values);
- CustomField02 mode;
- logged by AnalyticsService right after each VS1 step n ≥ 2 is sent: at most 5 per player per visit, 20 combinations.

Add a §8 row: 'Milestone timing vs Pacing targets → MilestoneReached (median value by milestone)'. If this is not wanted, remove the analytics claim from PACING.md §7 and Pacing.luau and say the timings come from Studio env.log timestamps only.
- **M8 (M)** `analytics/schemas/events.md (whole file; the shared §5 tables at :71-96)`. D-038(7) rules that FORGE-04's shared append-only files, analytics/schemas/events.md among them, are split per feature in FORGE-04's next PR, so its PRs stop conflicting. On main the file is still one page.

Both open FORGE-04 PRs edit its §5 tables. A test merge (git merge-tree) of #45 onto main+#64 conflicts in events.md, roblox/studio-tests/experience.md and roblox/tests/unit/experience/mutations.py: exactly the three files D-038(7) names. #64 alone merges cleanly onto main 3bbf2a0. Taxonomy acceptance should target the split layout, not a page that is about to be split.
  - **Conflicts with:** DECISIONS.md D-038(7); PROJECT_STATUS.md:37, :43 (both PRs conflict with main or each other)
  - **Fix:** 1. In FORGE-04's next push (whichever of #64 and #45 goes first), split events.md into:
   - an index page that keeps the platform facts, naming rules, budget and dashboard sections (§1–3, §7);
   - per-feature pages, for example game-001 session, onboarding, VS1 funnel, match, living kingdom and sandbox, each with its own rows and changelog.
2. Rebase the other PR onto the split.
3. FORGE-00 records the taxonomy review against the index and those pages.
- **M9 (M)** `analytics/schemas/events.md:90 (Onboarding funnel row); mirrors games/game-001/config/Onboarding.luau:37-100 (flow vs1, version 1)`. The Onboarding row documents the v1 steps: Spawn, Gather (ruler's ResourceGathered), PlaceBuilding, BuildingComplete, Recruit, Capture. BRIEF §4 v2 (D-030) replaced them with: inspect a citizen → build on a plot → answer a citizen → recruit → capture. Under D-030 ruler gathering is optional, and D-038(1) records the live stall at 'Gather' on main.

LogOnboardingFunnelStepEvent has no funnel name or version (events.md:22). If v1 is ever published, its step meanings mix permanently with v2. The row is accurate to the config, but the config is out of date.

The FORGE-00 answers handoff §2 ('gather → build → recruit → capture') predates D-030 for onboarding.
  - **Conflicts with:** BRIEF.md:43 (§4 'First minutes guided'); D-030(1); D-038(1); events.md:22 (the onboarding funnel has no name or session id)
  - **Fix:** 1. Do not accept the Onboarding row as is.
2. Accept it together with #45's v2 row, after #45's B is fixed (see the PR notes).
3. Until #45 merges, mark the row: 'v1, superseded by BRIEF §4 v2 (D-030); stalls at Gather on main (D-038(1)); never to be published'.
- **L1 (L)** `analytics/schemas/events.md:98-115 (esp. :106 IAP, :111 daily streak, :112 tutorial reward, :113 'speed up construction'), :135`. §6 is a framework txType mapping, but it sits in a page budgeted for AI Kingdoms. Its examples include Robux currency packs, daily streaks, tutorial rewards and 'speed up construction', which is a construction-game impulse purchase.

game-001 has no meta-currency, and monetization and persistence are the user's decisions. Nothing is decided, but the section reads like a plan FORGE-03 could follow.
  - **Conflicts with:** BRIEF.md:94-98 (§7), :157 (§16.1), :161 (§16.5); FORGE-00 answers handoff §2 ('No currency rewards in VS-1'); creator-docs economy-events.md ('e.g. extra lives')
  - **Fix:** 1. Retitle: '§6 Economy — framework mapping (sandbox and later games). game-001 logs no economy events until the user decides §16.1 and §16.5.'
2. Replace 'speed up construction' with Roblox's own example, 'extra lives' (EE).
3. In §8 :135, append '(pending §16.1/§16.5)' to quests and daily rewards.
- **L2 (L)** `analytics/schemas/events.md:3 (status line), :64, :148 (changelog); games/game-001/config/Analytics.luau:10-12, :89`. The page is out of date in three places:
- The changelog says the page is aligned with CONTRACTS v0.4-g2. Main is v0.4-g8 and adds the G9 order rule (v0.4-g6).
- §4 says 'game-001 uses Feedback/Signals.luau', but main's Analytics.luau has no `subjects` and `track = {}`, so analytics uses no game resolver yet.
- The status line still points at the original handoff.
  - **Conflicts with:** CONTRACTS.md:1 (v0.4-g8), :582; games/game-001/config/Analytics.luau:89-90
  - **Fix:** 1. Add a changelog entry: 'aligned with CONTRACTS v0.4-g8 (G9 order rule v0.4-g6)'.
2. §4: 'from FL-0063: config `subjects = Signals.subjects`'.
3. Point the status line at the FL-0063 handoff.

PR #64 wires `subjects` and `track`. It adds an FL-0063 changelog entry but no CONTRACTS version, and it leaves the status line unchanged.
- **L3 (L)** `analytics/schemas/events.md:50-52 (house budgets: 3 currencies, 12 transaction types, 80 SKUs) vs roblox/src/shared/Experience/AnalyticsSchema.luau:49-53 (HOUSE has only events, funnels and steps)`. events.md:5 says 'the config wins and this page is the bug'. Yet the code holds none of the three economy house budgets, and AnalyticsService:economy enforces none of them. It only validates the arguments and warns on custom transaction types.
  - **Conflicts with:** events.md:5; AnalyticsSchema.luau:49-53; AnalyticsService.luau:457-495
  - **Fix:** Either:
- add HOUSE.currencies = 3, transactionTypes = 12 and itemSkus = 80, and have AnalyticsService:economy warn once and drop past them (with a spec); or
- label those three cells 'guidance, not enforced'.
- **L4 (L)** `analytics/schemas/events.md:39`. The sentence 'Every call is written to env.log; nothing in a field may be personal data' reads as if the log lines carry no identifiers. Every analytics log line includes the player's UserId (AnalyticsService.luau:335, :374, :467). That is fine in server Output, but the sentence is inaccurate. This is wording only, with no privacy defect.
  - **Conflicts with:** roblox/src/server/Services/AnalyticsService.luau:335, :374, :467; AGENTS.md (no personal data)
  - **Fix:** Reword: 'Custom fields never carry personal data. env.log analytics lines include the UserId for Studio debugging; they are not forwarded off-platform.'
- **L5 (L)** `analytics/schemas/events.md:81-83 (`phase` fields), :49 (phase(6))`. The values of `phase` are never listed. The FORGE-00 answers require the contract MatchPhase names. At VS-2 MatchPhase gains Arena, so the cardinality becomes 7, and 8 counting 'unknown'.
  - **Conflicts with:** CONTRACTS.md:54 (G2 MatchPhase), :376 (G12.1); FORGE-00 answers handoff §2 'Phases'
  - **Fix:** State once in §5: 'phase values = CONTRACTS G2 MatchPhase: Lobby, Founding, Expansion, Conflict, Endgame, Results (+ Arena at VS-2, G12.1)'. Use that count in the M5 budget.
- **L6 (L)** `analytics/schemas/events.md:46, :90-91; games/game-001/config/Analytics.luau:71`. Funnel identity is not durable:
- 'VS1' names a milestone, but after VS-1 the same funnel keeps measuring first-match progress. Renaming it later would start a new funnel against the 10-funnel cap. FORGE-04's original proposal, `FirstMatch`, was already accepted in the FORGE-00 answers §5.4.
- LogOnboardingFunnelStepEvent has no name or version. Once published, changing what a step number means would mix data permanently.
  - **Conflicts with:** AnalyticsService.yaml LogFunnelStepEvent ('Limited to 10 unique funnels per experience'); events.md:22; FORGE-00 answers handoff §5.4
  - **Fix:** 1. Before the first publish, FORGE-00 picks the durable name (recommended: `FirstMatch`, keeping the BRIEF §13 steps).
2. Add a §2 rule: 'After the first publish, funnel step numbers and meanings are frozen. A new onboarding flow gets a new one-time funnel (LogFunnelStepEvent "OnboardingV2") instead of renumbering.'
- **L7 (L)** `analytics/schemas/events.md:29, :143-144 (§10)`. §10 tells the user to expect `sent=true` in Studio. Roblox says 'Events can't be sent from ... Studio'. Whether the Log* calls return silently in Studio (the adapter then logs sent=true) or throw (sent=false reason=error, AnalyticsService.luau:283-294) is unverified.
  - **Conflicts with:** creator-docs custom-events.md:19 and funnel-events.md:25; AnalyticsService.luau:278-300
  - **Fix:** Write: 'In Studio, either sent=true or sent=false reason=error is acceptable (unverified which); judge the order and the fields only. Real delivery: a private published place and View Events (user).'
- **L8 (L)** `analytics/schemas/events.md:53, :55-61; roblox/src/shared/Experience/AnalyticsSchema.luau:43-44; roblox/src/server/Services/AnalyticsService.luau:224-257`. Downgraded from M6. ET lists '120 + (20 * CCU)' under 'Global Rate Limit', and FE says repeated steps count toward the 'global rate limit'. CCU counts the whole experience. The adapter nevertheless gives every server 0.8 × (120 + 20 × players).

If every server bursts at once, the sum passes the experience cap once 96·S > 120 + 4·CCU. Examples: 4 full 16-player servers, or 2 servers of 4 players each. So 'adapter enforces it' overclaims.

Expected load (about 2 requests per player-minute, unverified) is far below either reading. This is a guard and documentation issue, not a live risk.
  - **Conflicts with:** creator-docs af5f853 event-types.md ('Global Rate Limit ... 120 + (20 * CCU)'), funnel-events.md:125; docs/research/roblox-platform-constraints.md N3
  - **Fix:** 1. Describe the cap as experience-wide (scope unverified).
2. Size the server bucket from the per-player share only: floor(0.8 × 20 × players), with a floor of 20/min. Keep the 25 % custom-event reserve and the 30/min per-player bucket.
3. Add the scope question to research N3 as 'unverified until a published test place'.

**Open PRs:** **PR #64** (origin/forge/04-experience-fl0063 at 7ddc7cf)
- Base: merged main at a75de0f. It merges cleanly onto main 3bbf2a0 (git merge-tree).
- Review history: the first review was FORGE-05's (CONTRACTS changelog line 582; FL-0063 log). FORGE-07's re-review is pending (PROJECT_STATUS.md:43).

What it fixes:
- **B1, mostly:** VS1 is `inOrder`. AnalyticsSchema validates the flag and rejects it on the onboarding funnel. AnalyticsService:funnel counts out-of-order steps (stats.dropped.outOfOrder) before _admit instead of sending them, and the VS1 row states the rule. Still missing: the §4 attribution bullet, and FORGE-00's line in FL-0063 Requirements (line 23 is unchanged in the PR). The changelog is not moved to v0.4-g8: the PR adds an FL-0063 entry but no CONTRACTS version, contrary to the first review.
- **M1, mostly:** `session.startOn = KingdomJoined`, once per visit; §10 and the spectators note are updated. The Return row still says 'AnalyticsService on PlayerReady', although the adapter now logs Return at session start (L).
- **M3, partly:** PhaseLeft is produced by MatchAnalyticsService through `session.leftInfo` and logged before SessionEnd. IdleHintShown and CelebrationShown still have no server producer.
- **M4, mostly:** `won` takes true, false or draw (draw = no single winner); `phase` is the decided phase; `mode` adds match30 and unknown. The KingdomEliminated line is missing.
- **M2, partly:** documents the kingdom-wide FirstGather and asks FORGE-00 to rule. FirstRecruit is still undefined. Recommended ruling: accept the kingdom-wide reading for VS-1 and keep conversations as a custom event.
- **L2, partly:** `subjects` and the track rules are wired; the status line and the CONTRACTS version are not.
- The log flood from duplicate steps (FORGE-05 #64 M1) is fixed: repeats are counted, not logged.

Still open after #64: M3 (two producers), M5, M7, M8, M9, L1, L3–L8, and the B1 and M1 residue above.

New in #64:
- **M — ConversationAnswered combinations grow with content.** Its `decision` field is the content farm_key: 12 occupations × 6 phases × 15 farm_keys = 1,080 today (decisions.csv: 49 decisions, 15 farm_keys). That content is DRAFT and FORGE-06 is adding to it (D-035). At about 100 farm_keys the event alone passes 7,000, and the whole budget passes 8,000. The PR's 'about 1,300' total also leaves out SettingChanged's 515; the real figure is about 1,850. Fix: drop `phase` from ConversationAnswered or bucket decisions by category, and adopt the M5 house rule with a per-event list.
- **M — one moment, two mechanisms.** #64 asks FORGE-01 to call AnalyticsService:event directly when Kingdom.Choose succeeds. #45 proposes a G9 `CitizenAnswered` event for the same moment. Pick one. Recommended: FORGE-00 adds G9 `CitizenAnswered(player, kingdomId, entityId, scenarioId, farmKey)`, produced by ConversationService. It would feed both an analytics track rule and onboarding v2's AnswerCitizen step. ReputationShifted can stay a direct call.
- **L — non-contract field.** MatchAnalyticsService reads `MatchService.mode`. That field is documented in the MatchService.luau:16 header ('slice' | 'match', PROVISIONAL) but is not in CONTRACTS G3. Ask FORGE-00 to add it to G3 additively. The 'unknown' fallback already protects against its absence.
- **L — §10 order.** §10 step 2 orders SessionStart → VS1 Spawn → Onboarding Spawn. Only the first two share a handler; the Onboarding line depends on the order of KingdomJoined subscribers. Say 'in any order'.
- **No open user decision is decided.** `match30` is only a label; MatchService cannot select it yet (#45 Pacing.luau comment). 'draw' labels the G3 PROVISIONAL tie without deciding victory. 'Founding..Arena' uses the additive G12.1 phase. The '30-minute match' load estimate is neutral; 'per 30 minutes of play' would be cleaner.

**PR #45** (origin/forge/04-experience-fl0092 at 414bbbc, base c1ba099)
- Status: not reviewed by FORGE-07, and it conflicts with main in studio-tests/experience.md and mutations.py. It is not 'held': D-038(1) allows an early merge if a spec proves the tutorial auto-advances past AnswerCitizen and FORGE-07 verifies it (PROJECT_STATUS.md:37).

What it fixes:
- **M9:** the Onboarding row moves to the v2 steps of BRIEF §4 / D-030, which removes the live stall at 'Gather'.
- The `match30` profile is non-default and labelled an evaluation profile. MatchService cannot select it, which is consistent with D-030(6) and BRIEF §16.10, so it decides no match length. Its `Arena` key assumes the additive VS-2 phase (G12.1), while the G11 signature still lists only slice and match.

It introduces a **B**:
- The new row says 'neither a passed-over nor a timed-out interactive step is logged, so the funnel counts what players did'. That is false.
- OnboardingService keeps the flow index, so Recruit is still logged as step 5 while step 4 (AnswerCitizen) is skipped. Roblox then counts step 4 as completed (AS: 'if any steps are skipped, the intermediate steps will be considered completed'; events.md:16 and :30).
- So every player whose AnswerCitizen step was passed over (no ConversationService on main) or auto-advanced after 120 s is reported as having answered a citizen.
- Fix before merge: take AnswerCitizen out of the funnel numbering. Either log only the mandatory steps as 1..5, or make step 4 reachable only by a real answer. Log the optional step's outcome as a custom event, e.g. OnboardingStepPassed (value = step; fields stepName and how = answered | timedOut | unavailable). Correct the row text.

It introduces an **M**:
- InspectCitizen and AnswerCitizen are client-reported (`clientActions`) but feed funnel steps 2 and 4. Every funnel step on main is bus- or auto-triggered.
- CONTRACTS G11 (line 348) says 'Steps are triggered by G9 events', and the FORGE-00 answers say 'via G9 events'.
- FORGE-00 rules on one of two paths: server triggers (G9 `CitizenAnswered`, and InspectCitizen from a successful server `Sim.Inspect`), or a G11 amendment that allows client-reported steps which grant nothing. Either way, the rows mark both steps 'client-reported'.

**Merge order:**
- I test-merged #45 onto main+#64: it conflicts in events.md, studio-tests/experience.md and mutations.py, the exact files D-038(7) orders split.
- Whichever PR FORGE-04 pushes next should do the split (M8). That removes the conflict.
- Moving onboarding from v1 to v2 before the first publish is harmless; adopt the L6 freeze rule now.

Method note: the merge tests used `git merge-tree`, plus one `git commit-tree` for the stacked test. That left one unreferenced local commit object; no branch or ref was changed.

## 2. Match pacing (`games/game-001/design/pacing/PACING.md`), for FL-0061: **CHANGES NEEDED**

I re-checked every finding against origin/main 3bbf2a0, which has moved on from the reviewed 9466820; PACING.md is unchanged. I also re-read every cited source and both PR branches.

B1 and B2 both stand, so the verdict stays CHANGES NEEDED. All five M findings and all three L findings also hold, with these corrections:
- **M1:** two line references were off by one (Barracks 45 s is line 34, the rates are line 36). It also counted the stone rate as a mismatch, but 8/min agrees. It missed that line 36 ("rates not specified anywhere yet") is stale: FORGE-01's Jobs.luau and Citizens.luau have been on main since ccfa20f.
- **M5:** the proposed fix (lower Recruit nudgeAfterSec to 45) is replaced. The nudge logs OnboardingHintEscalated as a stuck point, and Recruit is expected to take 150–170 s, so a lower nudge would mark nearly every player as stuck during a planned wait.
- **M3:** now also lists §16.13 (walk mode).
- **M2:** now also covers the inOrder race: PR #64 drops an out-of-order step instead of deferring it.
- **B1:** now also covers Results 30 s against the roughly 60 s leadership recap, and requires the Arena row to carry the §16.9 PROVISIONAL tag.
- **B2:** the fix is re-based on the v2 timings #45 already puts in EXPERIENCE §2, so the two documents do not diverge again.

**Timeline correction.** c9376ac was authored on a branch that did not contain 4ae7bc6, and it matches the original BRIEF §3 (9477121) exactly. The staleness came in when PR #15 merged, 16 minutes after the D-029 re-time, and again with D-030 at 21:15.

**What is right:**
- The numbers match Pacing.luau and PacingService.DEFAULTS exactly: slice 0/untimed; match 20/480/720/900/600/30; targets 45/90/150/330/450; limits 30–45.
- The phase names are exactly the G2 MatchPhase names, and none of Opening, Development, Competition or Resolution appear.
- The G3 slice rules and the pull-only G11 wiring are described correctly.
- There is no 'Crowns' currency and nothing about monetization.
- The doc does not choose between 25+5 and the BRIEF §3 timing, and does not pick an Arena format.

**What is wrong on open decisions:**
- The §2 header labels the pre-D-029 split as 'BRIEF §3'.
- The doc says an early victory ends the full match.
- §9 treats §16.4 as open, although D-029 decided it, and leaves out §16.9, §16.10 and §16.13.

The `modes.match` config itself is under an explicit FORGE-00 hold (living-kingdom §6 'Nothing changes until the user decides'; the FL-0096 validation updates Pacing.luau only after the decision). So the B fixes change only the doc, the code comments, the spec name and two new targets. They do not change the match split.

**Task status.** Under D-038 (5), an unticked completion box means nothing. FL-0061 has merged code and work left, so it should go back to BUILDING, with this verdict in its Log. Neither #45 nor #64 touches FL-0061's task file, so FORGE-00 can reconcile it on main.

Fixes go to FORGE-04, which owns design/pacing, config Pacing.luau and Onboarding.luau, and PacingService. FORGE-00 items are marked.

- **B1 (B)** `games/game-001/design/pacing/PACING.md:20, 25-27, 29, 65-67, 77; also games/game-001/config/Pacing.luau:12-13, games/game-001/src/server/Services/PacingService.luau:15, games/game-001/tests/experience/PacingService.spec.luau:60-67`. The §2 column is headed 'match (BRIEF §3)', but its numbers are the pre-D-029 split: Conflict 900 s (20–35 min), Endgame 600 s (35–45 min), Results 30 s, and no Crown Arena.

The doc describes a match that no longer exists:
- Line 26 ('timer, or early victory') and line 29 say that an early victory (last keep standing) ends the full match in Endgame.
- §4 (lines 65–67) runs Conflict 20–35 and Endgame 35–45, then goes straight to 'victory / defeat' at 45.
- §5 line 77 keys a row to minute 35.
- The code comments and the spec name repeat 'BRIEF §3' for these numbers, and the spec asserts the 35-minute Conflict end.

This contradicts D-029 and the current BRIEF §3 / crown-arena §2 for the very mode it describes (the VS-2 full match). FORGE-00's handoff (20:13, after the re-time) said 'Use the BRIEF §3 timings'.

Two consequences:
- Adding the roughly 6-minute Arena to this split would give about 51 minutes, outside BRIEF §1's 30–45. PacingService's bound covers only Founding..Endgame, so it would not catch this.
- `match` Results is 30 s, while BRIEF §3 and crown-arena §2 give Results plus the leadership recap about 60 s (44–45 min).

The config is held on purpose (living-kingdom §6 records 'Pacing.luau match runs 45 minutes ... Nothing changes until the user decides'; FL-0096). The defect is the doc presenting a held, superseded split as the BRIEF's design and as the match's victory flow.
  - **Conflicts with:** BRIEF §3 (Conflict 20–32, Endgame 32–38, Crown Arena 38–44, Results and recap to 45); BRIEF §16.4 (decided by D-029) and §16.10; D-029; D-030 (6); crown-arena.md §2 (FORGE-04 owns these numbers; last keep standing becomes a coronation); CONTRACTS G3 clarification ('From VS-2 (D-029): the match ends in the Crown Arena'); G12.1 (MatchPhase gains Arena at VS-2); living-kingdom.md §6; FL-0096 validation; handoff 2026-10-12-forge-00-answers §FORGE-04 2
  - **Fix:** Change the doc and the comments only. Do not change `modes.match` before FL-0096 (living-kingdom §6).

1. **Line 20.** Change the header to 'match (config `modes.match`: pre-D-029 split, held until FL-0096; see note)'.
2. **New §2 row.** Add: 'Arena (VS-2; CONTRACTS G12.1 draft) | — | not in `match` until VS-2; BRIEF §3: 360 (38–44 min) | ArenaService stage `done` (crown-arena §2)'.
3. **Line 26, 'Ends when'.** Replace with: 'timer. In VS-1 config, the PROVISIONAL G3 default (Match.luau `victory`) may end it early. From VS-2 (D-029), Endgame always leads to the Crown Arena; last keep standing becomes a coronation there.'
4. **Line 29.** Replace with: 'BRIEF §3 (D-029) times the match as Founding 0–8, Expansion 8–20, Conflict 20–32, Endgame 32–38 and Crown Arena 38–44, then Results with the leadership recap to 45 (about 60 s; config Results is 30 s). `modes.match` keeps the pre-D-029 split for two reasons: MatchPhase has no Arena before VS-2 (G2, G12.1), and match length is open (BRIEF §16.10, FL-0096; living-kingdom §6 holds the config until the user decides). The split must be re-cut before VS-2 whatever FL-0096 decides, because adding an Arena to it gives about 51 min. When FL-0096 is decided or G12 freezes, whichever comes first, FORGE-04 re-splits `modes.match` and PacingService.DEFAULTS, and FORGE-01 updates Match.luau `durations.match`.'
5. **§4, lines 64–67.** Re-key the table to BRIEF §3 and mark it 'design target; differs from `modes.match` until FL-0096':
   - Conflict 20–32.
   - Endgame 32–38: 'sieges; Crown Points decide who reaches the arena'.
   - Add a row: '38–44 Crown Arena (VS-2; format PROVISIONAL, BRIEF §16.9): qualification → loadout → intro → duel → crowning, or a coronation if one keep stands'.
   - Results 44–45 with the leadership recap.
6. **Line 77.** Change 'By minute 35' to 'By minute 32 (Endgame starts)'.
7. **Code comments and spec.** In Pacing.luau:12–13 and PacingService.luau:15, replace 'BRIEF §3 (numbers)' with 'pre-D-029 split, held until FL-0096; see PACING.md §2'. In PacingService.spec.luau:60, drop '(BRIEF §3)' from the test name.
- **B2 (B)** `games/game-001/design/pacing/PACING.md:38-49 (esp. 40, 41, 42, 44, 45, 49), 55`. The §3 VS-1 minute-by-minute is still the pre-D-030 slice:
- Line 40: the ruler spawns at the keep, not seated on the throne in the aerial view.
- Line 41: onboarding step 2 and its 0:10–0:45 row are the ruler walking to a tree or rock to gather.
- Line 42: building is 'opens Build, places a House or Farm', with no plot.
- There is no 'inspect a citizen' and no citizen conversation (VS-1 row 9, the defining mechanic).
- The keep and Barracks upgrades (row 6) are missing.
- Line 49 cites 'a guided first two minutes', the old BRIEF wording.
- The line 55 mitigation relies on ruler gathering.

Onboarding.luau v1 on main implements exactly this order. D-038 (1) records the result: a live stall at 'Gather' on main. EXPERIENCE.md §2 says its numbers come from PACING §3, so the slice timeline that VS-1 acceptance relies on is the old one.

The FORGE-00 answers handoff (20:13: 'gather → build → recruit → capture') predates D-030 (21:15) and is superseded by BRIEF §4 for the onboarding order. Its 'triggered by G9 events' principle still stands.
  - **Conflicts with:** D-030 (1): VS-1 v2, aerial camera with the ruler seated on the throne by default, conversation decision, ruler gathering optional. BRIEF §4 rows 2, 4b, 6 and 9, and 'First minutes guided: inspect a citizen → build on a plot → answer a citizen → recruit → capture'. D-038 (1). CONTRACTS G13.3 (Kingdom.Converse/Choose), G13.5 (Build.PlaceSlot), G13.6 (throne, overview camera, selection). EXPERIENCE.md §2 ('numbers in PACING.md §3').
  - **Fix:** Rewrite §3 for VS-1 v2. Base it on the v2 timings #45 already puts in EXPERIENCE §2, so the two docs agree: PACING §3 holds the numbers and EXPERIENCE cites them.

Rows:
- **0:00.** The view opens above the keep with the ruler seated (Spawn; funnel 1).
- **0:02–0:20.** The player taps a citizen and the card opens (InspectCitizen, client-reported; first interaction ≤ 30 s = Onboarding `limits.firstInteractionSec`).
- **0:20–1:10.** The player taps a free plot, picks a House or Farm and confirms (Build.PlaceSlot → BuildingPlaced with placedBy; FirstBuildPlaced ≤ 90 s). Builders raise it (FirstBuildingComplete ≤ 150 s; a funnel step, but not an onboarding step in v2).
- **1:10–2:40.** The player answers a '!' request (Kingdom.Choose ok; AnswerCitizen; target ≤ 180 s).
- **2:40–5:10.** The player places the Barracks (8 builder-s) and recruits 3 soldiers (≤ 330 s).
- **5:10–7:10.** Capture (≤ 450 s).

Also:
- Place the keep L2 upgrade (BRIEF §4 row 6) in the timeline, or state that it comes after the capture, consistent with the slice length agreed in M1.
- Analytics column: FirstGather fires on the first citizen deposit credited to the player (M2). It is not a ruler action.
- State: 'Ruler gathering is optional (D-030): an accelerator, not a step.'
- Line 49: cite BRIEF §4 'First minutes guided' with the v2 order.
- Pacing.luau `targets`, plus PacingService TARGET_ORDER and DEFAULTS: add `firstInspectSec = 30` before `firstBuildPlacedSec`, and `firstAnswerSec = 180` between `firstBuildingCompleteSec` and `firstRecruitSec`. The validator requires ascending order.
- Line 55: drop ruler gathering as the main mitigation (see M5).

Cheapest path: carry this in #45, which already rewrites EXPERIENCE §2 and Onboarding.luau to v2.
- **M1 (M)** `games/game-001/design/pacing/PACING.md:3, 34, 36, 44-45, 49, 52, 74`. §3 says it will be re-timed when FL-0050 and FL-0058 land. FL-0058's balance sheet (design/economy.md) and Costs.luau are on main and disagree with it:
- **(a) Barracks time.** Barracks L1 is 8 builder-s (D-030 user proposal; Costs.luau:63), not 45 s (line 34). The '4:00–5:30 Barracks completes' row (line 45) is therefore wrong: completion follows placement within seconds.
- **(b) Gather rates.** economy.md's target rates are about 8 wood/min per woodcutter and ≥ 5 food/min per farmer, not 15 and 12 (line 36). Stone, at 8/min per miner, agrees.
- **(c) Slice length.** economy.md's slice goal is about 10 minutes including keep L2 (BRIEF §4 row 6 asks for a keep upgrade), not 6–8 minutes (line 49).
- **(d) Food.** At those rates, 3 farmers give 15 food/min against 12/min upkeep (+3/min), and 3 soldiers add 3/min of upkeep, so net food is about 0 after recruiting. Line 52 assumes +36/min from farmers (net +24/min). The sim also draws food for births (Citizens.luau birthFood 25) and, while `mealsChargeTreasury = true`, for meals.
- **(e) Income at minute 2.** §5's '~80/min at minute 2' (line 74) becomes about 55/min (24 + 15 + 16).
- **(f) Rates already exist.** Line 36 says gather and trip rates are 'not specified anywhere yet'. FORGE-01's Jobs.luau (gatherRate, harvestTime 6 s, carry 10) and Citizens.luau (citizenSpeed 12) have been on main since ccfa20f.

Line 3's 'numbers agreed as placeholders with FORGE-03' no longer holds: economy.md proposes a different slice length and Barracks time.
  - **Conflicts with:** games/game-001/design/economy.md lines 32, 39, 59-66 (FL-0058); config/Costs.luau:63; config/Jobs.luau; config/Citizens.luau; BRIEF §4 row 6 (Barracks levels 1–2 at about 8 s and 18 s, PROVISIONAL; keep upgrade); handoff 2026-10-12-forge-04-to-forge-03-pacing-numbers
  - **Fix:** - Re-time §3 and §5 from Costs.luau, economy.md and Jobs.luau:
  - Barracks: 8 builder-s.
  - Rates: economy.md's targets (8 wood, ≥ 5 food and 8 stone per worker per minute), cross-checked against the trip rates Jobs.luau implies. Mark them 'FL-0058 targets; FL-0050 measures; unverified'.
- Agree one slice length with FORGE-03: about 6–8 minutes without keep L2, or about 10 minutes with it. Record it in both docs.
- Recompute the food watch point: net about 0 food/min after 3 soldiers, before births and meals. Keep it marked 'unverified'.
- Line 3: change to 'placeholders; FL-0058 numbers applied <date>; open disagreements: ...'.
- Line 36: delete 'not specified anywhere yet'.
- **M2 (M)** `games/game-001/design/pacing/PACING.md:41, 86 (with config/Pacing.luau:40 targets.firstGatherSec)`. §3 describes FirstGather as the ruler's own gather, with a ≤ 45 s pacing target, and §7 compares step times against §3. But:
- Feedback/Signals.luau:115-120 on main credits citizen deposits to every member of the kingdom.
- PR #64 tracks VS1 step 2 on any ResourceGathered, with no source filter.

So FirstGather fires on the first citizen deposit for everyone. The ≤ 45 s 'ruler action' target is then met trivially and measures nothing.

The alternative is no better. Since D-030 made ruler gathering optional, a ruler-only step would strand most throne-seated players at step 2 under the v0.4-g6 funnel-order rule.

There is also a race. PR #64's inOrder rule drops an out-of-order step; it does not defer it. A ruler who places a building before their first citizen-deposit credit loses that FirstBuildPlaced, and the step then waits for their next placement.

CONTRACTS G9's attribution list does not cover ResourceGathered at all.
  - **Conflicts with:** CONTRACTS G9 funnel attribution and the v0.4-g6 funnel-order rule; D-030 (1); BRIEF §13; src/shared/Feedback/Signals.luau:115-120; PR #64: config/Analytics.luau track rules and AnalyticsService inOrder (stats.dropped.outOfOrder)
  - **Fix:** In PACING §3 and §7, define FirstGather as: 'the first ResourceGathered credited to the player: their own gather, or any citizen deposit into their kingdom (credited to every member, Feedback/Signals). It marks that the economy has started; it is not a ruler-action pacing target.' Add a sentence on the inOrder race.

In Pacing.luau, remove `targets.firstGatherSec` or rename it as a sim health check, for example `firstDepositSec` ≤ 45 s from Founding. `firstInspectSec` then becomes the first ruler target (B2).

FORGE-00:
- (a) Add ResourceGathered to the G9 funnel attribution, additively: 'ruler: the player; citizen: every current member'.
- (b) Rule on the BRIEF §13 v2 funnel: keep FirstGather, move it after FirstBuildPlaced, or replace it with FirstConversation once a G9 CitizenAnswered event exists. #64's events.md flags this.
- **M3 (M)** `games/game-001/design/pacing/PACING.md:95-98`. The open-questions list is stale.
- Line 97 lists BRIEF §16.4 'victory rules' as open, but D-029 decided that the match ends in the Crown Arena. Only what eliminated players do (and §16.9) is still open.

Three open user decisions that directly change this doc are missing:
- **§16.10 / FL-0096, match length:** about 25 + 5 min, or the BRIEF §3 arena at 38–44.
- **§16.9, Crown Arena format:** top-2 duel or bracket, champion choice, what the duel decides, support strength. A bracket would need a longer Arena phase.
- **§16.13, walk mode:** whether walk mode is offered outside the Crown Arena. §3's walking, gathering ruler presupposes it, while the VS-1 default is the throne and the aerial view.
  - **Conflicts with:** BRIEF §16.4, §16.9, §16.10, §16.13; D-029; D-030 (1), (6); FL-0096; living-kingdom.md §6 and §9
  - **Fix:** Replace line 97 with: 'BRIEF §16.4: the match ends in the Crown Arena (D-029). Still open: what eliminated players do. In VS-1 config, last keep standing may end the match early as a PROVISIONAL G3 default (Match.luau `victory`).'

Add three lines:
- 'BRIEF §16.10 / FL-0096: match length, about 25 + 5 min (`match30`, evaluation only, FL-0092) or the BRIEF §3 timing. This doc does not choose. `modes.match` stays as configured until the user decides.'
- 'BRIEF §16.9: Crown Arena format, champion choice, what the duel decides and support strength. A bracket changes the Arena length.'
- 'BRIEF §16.13: walk mode outside the arena. The VS-1 default is the throne and the aerial view (D-030), so no pacing step may require walking.'
- **M4 (M)** `games/game-001/design/pacing/PACING.md:81-82, 91`. 'Meaningful action' (line 81) lists gather, place, upgrade, recruit, command, capture and job quota. It leaves out the D-030 core loop: inspecting a citizen, answering a citizen's request, and building on a plot. A ruler who is busy with conversations would therefore count as idle. Idle hints would fire wrongly, and IdleHintShown, FL-0063's dead-air metric, would be inflated.

The per-phase idle thresholds (25/45/60/90 s) exist only in this doc. They are not in Pacing.luau or any other config, and §8 does not list them as tuning knobs. FL-0062 therefore has no config source for them; OnboardingController only shows the hint text.
  - **Conflicts with:** D-030 (1)-(2); BRIEF §4 rows 4b and 9; CONTRACTS G13.3, G13.5 and G13.6; config/Onboarding.luau idleHints; roblox/src/client/Controllers/OnboardingController.luau:27-29
  - **Fix:** - Line 81: add 'inspect a citizen (G13.6 selection), answer a citizen (Kingdom.Choose ok), build on a plot (Build.PlaceSlot)'. State that a camera pan or zoom alone does not count.
- Add `idleSec = { Founding = 25, Expansion = 45, Conflict = 60, Endgame = 90 }` to Pacing.luau, validated as positive numbers keyed by MatchPhase. Add no Arena entry until G12 freezes.
- List `idleSec` in §8 next to `modes.*` and `targets.*`.
- **M5 (M)** `games/game-001/design/pacing/PACING.md:53-56 vs 82 (with config/Onboarding.luau Recruit step)`. The slice's one named dead-air risk is the Barracks wait (2:30–4:00). Its main mitigation is 'the idle hint after 25 s'. But §6 (line 82) and OnboardingController.showIdleHint allow idle hints only after the tutorial. At 2:30–4:00 the tutorial is still on Recruit (v1) or AnswerCitizen/Recruit (v2), so the idle hint cannot fire there.

What does fire is the Recruit step's nudge escalation at 60 s, and that is itself miscalibrated. Recruit's expectSec is 170 s (v1) or 150 s (#45), so the nudge escalates for almost every player during a planned wait. That makes OnboardingHintEscalated, the 'stuck point' metric, meaningless for that step.

The original review's fix, lowering nudgeAfterSec to 45, would make this worse.
  - **Conflicts with:** PACING.md §6 line 82; roblox/src/client/Controllers/OnboardingController.luau:27-29 and 384-394; roblox/src/shared/Experience/Onboarding.luau:339-343 (nudge measured from step start, escalation logged); config/Onboarding.luau Recruit expectSec 170 / nudgeAfterSec 60 (main), expectSec 150 / nudgeAfterSec 60 (#45); analytics/schemas/events.md OnboardingHintEscalated
  - **Fix:** Lines 53–56: replace the idle-hint mitigation with: 'During the tutorial, this wait is guided by the Recruit card ("Build a Barracks, then recruit 3 soldiers"). In v2 it is also guided by the AnswerCitizen step and the citizens' request bubbles (FL-0091), which give the ruler something meaningful to do while the stockpile grows. Idle hints apply only after the tutorial (§6).'

Keep line 56's 45 s rule as a playtest measure (time from the first BuildingCompleted to the Barracks being placed), not as a hint trigger.

FORGE-04, in Onboarding.luau:
- Set Recruit `nudgeAfterSec` at or above its expectSec (for example 180), so that escalation means stuck.
- Or split the step into 'Build a Barracks' (BuildingPlaced matching buildingType barracks and placedBy) and 'Recruit', each with its own nudge.
- Do not lower it to 45.
- **L1 (L)** `games/game-001/design/pacing/PACING.md:64 (and 62-63, 98)`. The Conflict-start big moment assumes PvP is on: the 'War is declared' announcement and horn, and the earliest raid at minute 21–22. But config ships `pvp.enabled = false` (PROVISIONAL, VS-1 minimum), and PvP intensity is an open user decision. §9 line 98 mentions only the war-from-Conflict default, not that PvP is off by default.
  - **Conflicts with:** config/Match.luau:15-16 and 37; CONTRACTS G3 clarification (diplomacy/PvP PROVISIONAL, behind a config flag); BRIEF §16.2
  - **Fix:** Mark the minute-20 row and the first-conflict guard 'only when Match.luau `pvp.enabled` (BRIEF §16.2)'. Name the announcer line used when PvP is off, for example 'The Conflict begins: rivals arm themselves', so that no war is announced in a PvE-only match.
- **L2 (L)** `games/game-001/design/pacing/PACING.md:30`. 'PacingService rejects configs outside 30–45 minutes' is imprecise.
- PacingService logs an error and serves its built-in DEFAULTS for the whole config, including slice and targets. The match keeps running.
- The bound covers only Founding..Endgame. BRIEF §1's 30–45 minute match includes the Arena and the Results recap once the Arena exists.
  - **Conflicts with:** src/server/Services/PacingService.luau:99-116 and 138-144; BRIEF §1 and §3
  - **Fix:** Replace line 30 with: 'If Founding..Endgame falls outside 30–45 min, PacingService logs an error and serves its built-in defaults for the whole config; the match is never blocked. From VS-2 the bound must cover Founding..Arena (G12.1).'
- **L3 (L)** `games/game-001/CONTRACTS.md:346, 348 (G11), applies once #45 merges`. After #45 merges, G11 will be stale in two places:
- Line 346 types `phaseDurations(mode: "slice" | "match")` with six phases, but #45 adds a third mode, `match30`, that returns an extra `Arena` key before VS-2.
- Line 348 says onboarding 'Steps are triggered by G9 events', but v2's InspectCitizen and AnswerCitizen are completed by whitelisted client actions (CitizenInspected, CitizenAnswered) until a G9 event exists.

Both changes are additive and acceptable: the client steps grant nothing, and D-038 (1) allows the early merge. But consumers such as FORGE-01's MatchService and #64's MatchAnalyticsService learn about them only from handoffs.
  - **Conflicts with:** CONTRACTS G11 and G12.1; PR #45 PacingService.MODES / LATER_PHASES and Onboarding.luau v2 clientActions; D-030 (6); D-038 (1); handoff 2026-10-12-forge-04-to-forge-01-00-bubbles-events (proposed G9 CitizenAnswered)
  - **Fix:** FORGE-00, when #45 merges, add an additive changelog entry:
- **G11:346:** '`mode` may also be "match30", a non-default evaluation profile (D-030 (6), FL-0092). Only it may carry `Arena` before VS-2. MatchService does not select it in VS-1 (Match.durationsFor knows only slice and match).'
- **G11:348:** 'or, where no G9 event exists yet, by whitelisted client actions that complete only the current step and grant nothing.'

Also rule on the proposed G9 `CitizenAnswered` event.

**Open PRs:** **PR #45** (forge/04-experience-fl0092, head 414bbbc, FL-0092)

What it adds:
- A '`match30`: evaluation profile, not the default' subsection to PACING §2.
- A `match30` mode in Pacing.luau and PacingService: 20/300/420/480/300/Arena 270/30 = 1,820 s. This matches living-kingdom §6 and FL-0092 exactly.
- Validation that keeps `Arena` out of slice and match (Match.new would reject it there) and bounds match30's Founding..Arena at 25–35 min.

Config `Match.mode` stays "slice", and Match.durationsFor asserts slice|match, so match30 cannot run. It is evaluation-only and does not decide FL-0096. That part is correct and satisfies D-030 (6).

What it leaves or introduces:
1. **B1 becomes an internal contradiction.** The new subsection says 'the current timing puts the arena at 38–44 minutes', directly below a §2 table showing Endgame 35–45 with no Arena, and line 29's '45 minutes ... early victory'.
2. **B2 gets worse.** #45 moves Onboarding.luau and EXPERIENCE.md §2 to v2 (Spawn → InspectCitizen → BuildOnPlot → AnswerCitizen → Recruit → Capture, with ruler gathering optional), but leaves PACING §3 on v1. EXPERIENCE §2 still says its numbers come from PACING §3. #45 already contains the v2 timings, so it is the cheapest place to land the B2 rewrite; otherwise FORGE-04 lands it immediately after.
3. **Default-mode wording (L).** 'MatchService (FORGE-01) keeps `match` as the default' is wrong: the VS-1 default is `slice` (Match.luau:22, G3). The #45 handoff repeats 'Keep `match` as the default mode', which FORGE-01 could read as moving VS-1 off slice. Fix: 'The default stays `slice` in VS-1 and `match` for the full match; `match30` runs only when deliberately selected.'
4. **Selection wording (L).** 'Someone has to choose match30 deliberately, for example through a debug preset' overstates what exists. There is no G13.7 preset, and #45's own Pacing.luau comment says 'MatchService cannot select match30 yet'. Fix: 'Selecting it needs a FORGE-01 change to Match.durationsFor and MatchService, plus an optional FORGE-05 debug preset; both are pending. Until MatchPhase gains Arena, a match30 run ends after Endgame (25 min) without the final phase.' FL-0096 already allows a design-only decision, so this is wording, not a blocker.
5. **Results length (L, FORGE-00).** match30's Results of 30 s comes from living-kingdom §6, FORGE-00's own spec; it is not a #45 error. BRIEF §3 and crown-arena §2 imply about 60 s for the leadership recap. FORGE-00 should settle this together with FL-0096.
6. **Contract notes.** CONTRACTS G11 needs the two additive notes in L3: the match30/Arena mode, and the client-reported onboarding steps.
7. **M3 half-fixed.** The §16.10 conflict is now described in §2 but not added to §9.
8. **M5 persists in v2.** Recruit has expectSec 150 and nudgeAfterSec 60, so the stuck-point escalation still fires during the planned Barracks wait.

**PR #64** (forge/04-experience-fl0063, head 7ddc7cf, FL-0063)

It does not edit PACING.md, but it changes what §7 measures:
- It builds the VS1 track rules. Step 2 is any ResourceGathered, and Signals credits citizen deposits to every member, so PACING's 'FirstGather ≤ 45 s ruler gather' target is met trivially (M2).
- Its `inOrder` rule (FORGE-00's v0.4-g6 ruling) drops out-of-order steps rather than deferring them. That creates the FirstGather/FirstBuildPlaced race in M2.
- #64's events.md honestly flags FirstGather as 'measures the economy started' and asks FORGE-00 for a v2 funnel ruling.

It implements §7's other measures:
- MatchEnded with a mode field that includes match30 and unknown, consistent with #45.
- PhaseLeft, the phase a ruler was in when they disconnected.
- IdleHintShown stays planned for FL-0062.

These use funnel and custom events within the Roblox limits: 3 funnels of 10, 12 custom event names of 100, at most 3 fields, and no progression events (docs/research N1–N3). They log no ids or free text, so there is no privacy issue. One latent limit: ConversationAnswered's `decision` field grows with the content library. FORGE-04 should keep it bounded below the 8,000 custom-field combination cap. That is outside this doc.

MatchAnalyticsService counts Arena as a playing phase, ready for VS-2. Nit: its header (MatchAnalyticsService.luau:37) cites 'CONTRACTS G1 MatchPhase'; it should be G2.

Neither PR fixes B1, B2, M1, M4 or M5.

## 3. Experience spec (`games/game-001/design/pacing/EXPERIENCE.md`) and the Experience/Subjects pattern: **CHANGES NEEDED**

Verdict: CHANGES NEEDED, because one B finding holds up on re-check.

B1: On main, EXPERIENCE.md §2 still describes the v1 tutorial: the ruler walks to a node and gathers, places a building freely with a ghost, then waits for it to complete. D-030 and BRIEF §4 replaced that flow with inspect a citizen → build on a plot → answer a citizen → recruit → capture. The same v1 flow in config/Onboarding.luau is the live 'Gather' stall recorded in D-038(1). PR #45 fixes §2 and the config. Once #45 merges under the D-038(1) conditions and the M items below are addressed, the doc can be APPROVED WITH CHANGES.

Open user decisions: none is silently decided on main.
- Pillar 4's '30–45 minutes' is the BRIEF §1/§2 wording.
- The §7 retention items are labelled proposals pending §16.1.
- The Crown Arena is missing from the doc, not decided by it. M4 asks the doc to flag §16.9, §16.10 and §16.13.
- PR #45's match30 profile is not the default and MatchService cannot select it, so §16.10 stays open.

What holds (re-checked on main):
- The contract MatchPhase names are used.
- There is no 'Crowns' currency and no currency reward (no reward or completeReward in the config).
- The building is the keep, not a Town Hall.
- Notifications: band 70–79, at most 3 visible, priority order as in NotificationQueue.luau:17-18.
- Config→Game requires are allowed and Forge→Game requires are rejected (RequirePath.luau:441, 461-463).
- §7 is labelled as proposals.
- Four of the five §3 rules do have framework specs: the CueDirector sound-only check, coalescing, the 'important' filter, and particle-budget eviction (Vfx.spec:297). Only the rival 250-stud rule has none.

Subjects pattern: sound, with two M fixes.
- It complies with D-022/D-024 and interfaces §4.
- Resolver errors are caught by pcall.
- `info` keeps only primitives.
- M8: an event that the config references but no resolver covers fails silently.
- M9: the pattern is recorded only in events.md §4, not in interfaces.md or CONTRACTS.

Changes to the original review:
- Dropped L1. A game resolver overriding a default is the documented design (Subjects.luau:9). The cited interfaces §7 rule covers AnalyticsService:economy, which no resolver can reach.
- M5 is now L. §8 already defers to G9 and events.md, and PR #64 documents the order rule and FirstGather.
- M10 is now L. The stale header is cosmetic; the substance is in M1 and M4.
- M2 softened. §6:94 does name the Feedback remote area for announcer lines; the gap is the §3 matrix and the music row.
- M6 narrowed. :25 is accurate as a design-estimate check. The false claim is ':64 all enforced by specs'.
- M7: dropped pillar 1 (:14), which does not rely on colour. Added the rival toast at :57, which names no kingdom.
- M8 kept at M, as a latent issue with a concrete stall path.
- B1 corrected:
  - 'on open ground' is in config/Onboarding.luau:65, not in the doc.
  - The FORGE-00 answers handoff §2 and D-034(4) still say gather → build → recruit → capture. For onboarding they are superseded by D-030/BRIEF §4.
  - #45's client-action steps need a ruling on the wording of G11:348.
- PR #45's head is now dfefab2: main merged into 414bbbc, with the reviewed files unchanged.
- Added #45 issues in open_pr_notes: the G11 wording, and the tutorial on main still waiting at Recruit.

Outside this doc (for FORGE-00 and the PACING review):
- PACING.md §2 and the Pacing.luau `match` mode run Conflict 20–35 and Endgame 35–45 with no Arena. BRIEF §3 has Conflict 20–32, Endgame 32–38 and Arena 38–44.
- The FL-0062 task file still requires gather → build → recruit → capture.
- FORGE-00's own texts still name the v1 path: D-034(4) 'VS-1 gather → build → recruit → capture critical path', answers handoff §2, BRIEF §2 '30 s: walk to a job, gather', and BRIEF §13 'first gather'. Annotate them, or confirm that FirstGather stays in the VS1 funnel.

How this was checked:
- `git fetch`, then files read on origin/main 3bbf2a0 with `git show`.
- PR branches diffed against their merge-base: #64 at head 7ddc7cf, #45 at head dfefab2.
- Read-only: no checks were run.
- Unverified: 'Roblox counts skipped funnel steps as completed' rests on the events.md:16 quote, not re-checked against creator-docs. The particle-rate and 'Sound is discouraged' quotes were not re-checked either.

- **B1 (B)** `games/game-001/design/pacing/EXPERIENCE.md:23-27 (rows :24 Gather, :26 PlaceBuilding, :27 BuildingComplete); mirrored in games/game-001/config/Onboarding.luau:48-81`. §2 is the v1 tutorial: Spawn → Gather ('The ruler walks up and taps', G9 ResourceGathered source=ruler) → PlaceBuilding ('Ghost placement') → BuildingComplete → Recruit → Capture.

VS-1 v2 replaced it:
- the ruler is seated and the overview camera is the default;
- a tap selects;
- ruler gathering is optional;
- buildings go on plots;
- the guided row is inspect a citizen → build on a plot → answer a citizen → recruit → capture.

config/Onboarding.luau has the same steps, including 'place it on open ground' at :65. D-038(1) records the live stall at 'Gather' on main.

The FORGE-00 answers handoff §2 and D-034(4) still say 'gather → build → recruit → capture'. For onboarding, both are superseded by D-030 / BRIEF §4; the handoff's own rule is 'follow BRIEF §4'.
  - **Conflicts with:** DECISIONS D-030(1) (DECISIONS.md:36); BRIEF §4 'First minutes guided' (BRIEF.md:43); CONTRACTS G4.1 mobile input (167-171), G11 (348), G13.5 (519-524), G13.6 (540-551); D-038(1) (DECISIONS.md:44)
  - **Fix:** Adopt PR #45's §2:
1. Spawn: auto, overview camera.
2. InspectCitizen: client action CitizenInspected, reported by InputModeController's selection.
3. BuildOnPlot: G9 BuildingPlaced with the placer match, target the BuildSlot tag.
4. AnswerCitizen: client action CitizenAnswered, requires=ConversationService, autoAdvanceSec 120.
5. Recruit.
6. Capture.

In the same PR:
- Change the :35 example to 'a co-ruler captured first'. v2 has no completion step.
- Name the v2 steps in §8 (:114).

FORGE-00 rules on G11:348 ('Steps are triggered by G9 events') for the two client-action steps. Either amend G11 additively ('or by whitelisted client actions that grant nothing'), or ask FORGE-01 for server events.

Merge #45 only under D-038(1): a spec proves that the tutorial passes AnswerCitizen while Kingdom.Converse / ConversationService is absent, and FORGE-07 verifies it.
- **M1 (M)** `games/game-001/design/pacing/EXPERIENCE.md:40-62 (§3), :42-44 (hook list), :92-100 (§6)`. The experience spec does not cover FORGE-04's part of the living kingdom:
- none of the G13.3 thought, reaction, strike or cue presentations;
- none of the living-kingdom §5 consequence cues (placards, grumbles, hungry bubbles, fire/alarm, warnings);
- none of the D-036 / G13.8 presentation (camera focusOn/restore, reduced-motion instant cut, reaction poses on the portrait and the world rig).

The hook list (:42-44) omits InputModeController.selected and RulerCameraController (both in G4.1), and ConversationController.opened/.closed (G13.8).

BRIEF §4 row 9 names FORGE-04 for bubbles and reactions. CitizenBubbleController and Feedback/Bubbles (FL-0091) are already on main and are not documented here.
  - **Conflicts with:** CONTRACTS G13.3 (485-500), G13.8 (561-578), G4.1 (156-166); D-030; D-036; design/living-kingdom.md §2, §5 (100-114), §8 FORGE-04 (179-182); BRIEF §4 row 9 (BRIEF.md:42)
  - **Fix:** Add §3a 'Living-kingdom feedback', with one row per G13.3 kind:
- thought: icons !, ? and …;
- reaction: the tone sets the pose;
- strike: mark only the entityIds sent, never fan out by occupation (v0.4-g6);
- cue: the vocabulary celebrate, grumble, salute, bow, cower, strike_placard, work_fast, rest, hammer. An unknown cue falls back to the reaction tone. A cue with no entity ids shows only on the HUD or the keep.

State that citizenBarks=false hides reaction bubbles only.

Add §3b 'Conversation presentation (D-036, G13.8, FL-0100)': focusOn about 0.6 s to 25–35 studs, restore on close, an instant cut with reduced motion, and poses on the portrait and the world rig.

Extend the hook list. Add living-kingdom moments to §6, such as the first answered request and a strike resolved.
- **M2 (M)** `games/game-001/design/pacing/EXPERIENCE.md:48-61 (esp. :55-60) and :94`. Several matrix rows play client sounds, VFX and toasts from server-only G9 events: BuildingPlaced, BuildingCompleted, UnitsRecruited and ObjectiveCaptured. Row :60 drives the client music state from G9 MatchPhaseChanged.

§6:94 names the `Feedback` remote area, but only for announcer lines. Nothing says how the §3 matrix cues reach the client. No Feedback area is declared on main (there is no games/game-001/src/shared/Feedback/Remotes.luau).

The Mine vs Rival columns also need the local kingdom on the client.
  - **Conflicts with:** CONTRACTS G9 (292: client UI learns through G8 remotes, never from G9 directly); G1 remote areas (40-43); interfaces.md §4 (90: payloads are server-only); FL-0062 task ('Game remotes go in the area Feedback')
  - **Fix:** Add a 'Transport' column, and pick one of two options:
(a) A server relay (AnnouncerService or a FeedbackRelay) fires a `Feedback.Cue` serverEvent, to members or to all, with a primitive payload { signal, kingdom, buildingType?, count?, position? }. It is declared in games/game-001/src/shared/Feedback/Remotes.luau (G1: area Feedback → FORGE-04).
(b) The client derives the cues from G8 state remotes: Build.Buildings state changes, Army.Objectives owner changes, Kingdom.State.

In both cases:
- Music reads Match.State / Match.GetState (G8), never G9.
- Mine vs rival compares the payload's kingdom with Kingdom.State.mine.
- **M3 (M)** `games/game-001/design/pacing/EXPERIENCE.md:52, :56, :68`. The cull distances ('culled beyond 150 studs, matching entity LOD'; rival sparkle 'within 250 studs'; rival effects 'beyond 250 studs are not drawn') never say where they are measured from.

The default overview camera sits 40–220 studs away (G13.6). EntityController's LOD measures from the local character, which is the seated ruler (EntityController.luau:49-50). That is the #39 M1 defect, which D-038(6) requires to stay in the user build notes. Tying feedback culling to the entity LOD copies the defect into the feedback layer.
  - **Conflicts with:** CONTRACTS G13.6 (544); D-038(6); games/game-001/src/client/Controllers/CitizenBubbleController.luau header ('Distance is measured from the camera focus'); EntityController.luau:49-50, :71
  - **Fix:** State that every feedback distance is measured from the camera focus point (RulerCameraController:getFocus()), never from the camera position or the seated ruler. CitizenBubbleController already does this.

Drop 'matching entity LOD' until #39 M1 is fixed.

Add a spec for the rival 250-stud rule; none exists on main.
- **M4 (M)** `games/game-001/design/pacing/EXPERIENCE.md:17, :61, :80, :100, :123-126`. The match arc in pillar 4 (Founding→…→Endgame→Results) omits the Crown Arena, which D-029 made the official final phase. Pillar 4 also does not say that match length is open (§16.10).

Row :61 builds the VS-2 victory and defeat presentation on KingdomEliminated / MatchEnded rather than on the arena (G12.5 ArenaStarted / DuelEnded). From VS-2, last keep standing becomes a coronation (G3:93). FORGE-04 owns the crowd, intro and crowning payoff (crown-arena.md §7, §10).

§9 lists '§16.4: victory rules' as fully open, but D-029 decided that the match ends in the arena; only parts remain open. §9 also omits:
- §16.9: arena format, champion, what the duel decides, support strength;
- §16.10: match length;
- §16.13: walk mode.
  - **Conflicts with:** DECISIONS D-029, D-030(6); BRIEF §2-§3, §16.4/§16.9/§16.10/§16.13 (BRIEF.md:160-169); CONTRACTS G3 (93), G12.5 (425-432); design/crown-arena.md §7, §10, §11
  - **Fix:** Pillar 4: 'Founding → Expansion → Conflict → Endgame → Crown Arena (VS-2, D-029) → Results; lengths per BRIEF §3, pending §16.10 (match30 is a non-default evaluation profile)'.

Row :61: 'VS-2: arena intro, crowd director, chants and stingers, crowning payoff (crown-arena.md §7); format, winner rule and support strength are PROVISIONAL (§16.9)'.

:80: add an arena music state (VS-2).

§9:
- replace the §16.4 line with '§16.4 remainder: what eliminated players do';
- add §16.9, §16.10 and §16.13.

Decide none of them.
- **M6 (M)** `games/game-001/design/pacing/EXPERIENCE.md:64 (with :68), :23-29 System column, :25`. ':64 Rules, all enforced by specs' is false for :68, the rival 250-stud cull: no spec on main covers it. The other four rules do have framework specs:
- CueDirector.validate's sound-only check (Feedback.spec:113);
- coalescing (Feedback.spec:159);
- the 'important' filter (Notification.spec:99);
- particle-budget eviction (Vfx.spec:297).

The System column names FeedbackController, MusicController, AnnouncerService and a 'founding cue' as if they exist. None is on main; FL-0062 is READY.

:25 'enforced by Onboarding.validate' is true only as a check on the sum of design expectSec estimates (roblox/src/shared/Experience/Onboarding.luau:163-186). No player is measured.
  - **Conflicts with:** AGENTS.md evidence rules; D-034(3) honest evidence labels
  - **Fix:** Reword :64 to 'Rules (spec noted per rule)' and mark :68 'spec pending (FL-0062)'.

Tag each system 'built (spec: <file>)' or 'planned FL-0062'.

Reword :25 to 'design estimate ≤ 30 s, checked by Onboarding.validate; real timing from the OnboardingStep logs in playtests'.
- **M7 (M)** `games/game-001/design/pacing/EXPERIENCE.md:57, :59, :86`. The doc has no D-033(3) rule:
- claim and celebration effects are told apart by kingdom colour tint (:86);
- capture feedback is 'tower recolours' (:59);
- the rival toast 'A rival keep reached level N' (:57) names no kingdom.

D-033(3) says a kingdom is never identified by colour alone. FORGE-05's colour-vision check (D-033(4)) gates VS-1 acceptance.
  - **Conflicts with:** DECISIONS D-033(3)-(4); CONTRACTS G13.2 soldier crest (481); BRIEF §6 kingdom emblems (91)
  - **Fix:** Add a §3 rule: 'Every kingdom-attributed cue carries the kingdom name and/or emblem as well as colour.'
- Rival toasts and announcer lines name the kingdom, e.g. 'Frostmere's keep reached level 2'.
- Claim and capture effects pair the tint with the kingdom's banner emblem or crest (D-033(3); G13.2 crest shapes).
- **M8 (M)** `roblox/src/shared/Experience/Subjects.luau:146-149 and :165-181; roblox/src/server/Services/OnboardingService.luau:65-69, :280-283; roblox/src/server/Services/AnalyticsService.luau:109-113`. Subjects.resolve returns {} with err=nil when no resolver exists. Subjects.validate checks only the resolvers that were given; it never checks that each event the config references has one. The referenced events are flow.startOn, step trigger.bus, track.on, and PR #64's session.startOn.

An uncovered event (not in DEFAULTS and with no game resolver) makes its step or rule silently never fire. This is latent today, because Signals covers every event game-001 references. Two concrete paths:
- KingdomJoined is not in DEFAULTS, so a config without `subjects = Signals.subjects` never starts the flow.
- If the proposed G9 CitizenAnswered replaces the client action and Signals misses its resolver, AnswerCitizen stalls permanently, because bus steps may not auto-advance (Onboarding.luau:174-176). That is the same class of defect as the D-038(1) 'Gather' stall.
  - **Conflicts with:** interfaces.md §4 (typo-guarded bus); the pattern's own report-missing style (Bus.connectAll returns missing events); D-038(1)
  - **Fix:** Add Subjects.missing(eventNames, resolvers) -> { string }. An event is covered if it is in DEFAULTS or in resolvers.

OnboardingService.create and AnalyticsService.create report every declared, referenced event without a resolver as a validation problem, logged as an error like the existing ones.

Add a game-001 spec: every event referenced by config/Onboarding.luau and config/Analytics.luau has a resolver. Add a mutations.py row.
- **M9 (M)** `docs/architecture/interfaces.md:65-95 (§4), :155-169 (§8); games/game-001/CONTRACTS.md:276-300 (G9), :345-351 (G11)`. Subjects is a framework↔game extension point that every future game will use:
- the `subjects` config key in Onboarding.luau and Analytics.luau;
- the resolver signature;
- ctx = { byUserId, all, registry };
- info that keeps only primitives.

PR #64 extends it with the `session.startOn` and `session.leftInfo` callbacks. It is documented only in analytics/schemas/events.md §4 (lines 62-68), not in interfaces.md or CONTRACTS.

FORGE-04 asked FORGE-00 to confirm the pattern (handoff 2026-10-12, lines 28-33, 45), and no confirmation exists in the repo. The resolvers get the full registry, but nothing states that they must have no side effects.
  - **Conflicts with:** AGENTS.md shared-contract rule; D-022; D-024; production/handoffs/2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md §'What I'm giving you'
  - **Fix:** FORGE-00 confirms the pattern. It complies with D-022 and D-024, and RequirePath.luau:461-463 already routes game behaviour through Config.

Record it additively in interfaces §8 (v0.3.3): 'A game passes subjects = { [event] = (args, ctx) -> { {player, info} } } and session callbacks (startOn, leftInfo) in its config. Resolvers are pure, non-yielding, read-only and server-only, and info keeps primitives only. Framework defaults cover §4 events; a game resolves its own events.'

CONTRACTS G9: 'Attribution is implemented once, in Feedback/Signals.luau, and used by onboarding and analytics.'

Add a DECISIONS line.

Note that Signals lives in src/shared (replicated) because the replicated config requires it; its resolvers run only on the server.
- **M5 (L)** `games/game-001/design/pacing/EXPERIENCE.md:121, :124`. Was M; now L, because §8 already defers to G9 and events.md.

:121 says attribution follows G9 'via Signals.luau'. The v0.4-g6 order rule (a step is credited only after the previous step) is not in Signals; it is the funnel's `inOrder` flag in PR #64.

The §9 proposal (:124) says joiners are credited 'only their own actions'. That misstates G9: citizen gathers, building completions and captures credit every current member, gated by the order rule.
  - **Conflicts with:** CONTRACTS G9 funnel attribution (293-300, v0.4-g6); BRIEF §13; D-030(1)
  - **Fix:** :121: 'Attribution: G9 via Feedback/Signals; funnel order (v0.4-g6) via the VS1 `inOrder` rule (FL-0063)'.

:124: 'credited per G9 attribution and the order rule, from the moment they join'.

The FirstGather semantics under D-030 belong in events.md, where PR #64 documents them. FORGE-00 rules whether BRIEF §13 keeps FirstGather.
- **M10 (L)** `games/game-001/design/pacing/EXPERIENCE.md:3, :10-11`. Was M; now L, because the substance of the staleness is in M1 and M4.

The header cites CONTRACTS v0.4-g2 and D-020–D-028, and says 'Last updated 2026-10-12'. Current versions are v0.4-g8 (CONTRACTS.md:1) and D-020–D-038.
  - **Conflicts with:** CONTRACTS.md:1 and changelog (580-592); DECISIONS.md:26-44
  - **Fix:** Update the header to 'CONTRACTS v0.4-g8: G4.1, G9 (incl. v0.4-g6 funnel order), G11, G12 (VS-2 draft), G13.3, G13.6, G13.8' and 'DECISIONS D-020–D-038 (esp. D-027, D-029, D-030, D-033, D-036, D-038)'. Bump the date.
- **L2 (L)** `games/game-001/src/shared/Feedback/Signals.luau:109; games/game-001/config/Onboarding.luau:62`. `info.placedBy = true` reuses the name of the G2 field `Building.placedBy`, which holds a userId, as a boolean meaning 'this subject placed it'.
  - **Conflicts with:** CONTRACTS G2 Building.placedBy (58-60)
  - **Fix:** Rename it to `isPlacer = true` everywhere at once: in Signals, in the Onboarding.luau match (PR #45 BuildOnPlot), and in the Analytics track rule (PR #64).
- **L3 (L)** `roblox/src/shared/Experience/Schema.luau:50`. The framework settings schema hard-codes `citizenBarks`, a game-001 concept, in the shared `experience` namespace.
  - **Conflicts with:** FORGE-00 answers handoff 2026-10-12 §FORGE-04.4 (framework stays genre-agnostic); D-022
  - **Fix:** Rename it to the generic `npcBarks`, or let a game extend SETTINGS through config. VS-1 has no persistence (D-027), so no migration is needed.
- **L4 (L)** `games/game-001/design/pacing/EXPERIENCE.md:15-16`. The pillar examples depend on ruler actions that are optional or rare in VS-1 v2: '+3 Wood' from the ruler chopping, and citizens reacting to 'a ruler's visit'. The ruler is seated by default, and walk mode is §16.13.
  - **Conflicts with:** D-030(1); CONTRACTS G13.6 (542); BRIEF §16.13
  - **Fix:** Use v2 examples:
- selecting a citizen opens the card with a soft tap sound;
- an answered request plays its reaction pose and bubble;
- citizen deposits show '+N Wood'.
- **L5 (L)** `games/game-001/design/pacing/EXPERIENCE.md:36, :46`. The doc never says plainly that VS-1 grants no rewards. :36 only says rewards come from server-verified steps.

:46 cites D-026 for 'no game-tree duplicates', but that rule is CONTRACTS G11:347. D-026(5) covers unique names only.
  - **Conflicts with:** BRIEF §7 (98); CONTRACTS G11 (347); FORGE-00 answers handoff 2026-10-12 §FORGE-04.2
  - **Fix:** Add a teaching rule: 'VS-1 grants no rewards: no reward or completeReward in the game config, and limits.firstRewardSec unset (BRIEF §7; FORGE-00 answers §2)'.

Cite G11 at :46.
- **L6 (L)** `games/game-001/design/pacing/EXPERIENCE.md:102-111`. §7 cites only §16 (monetization):
- Account level and collection also fall under §16.5 (persistence scope).
- 'Ruler edicts' duplicates the D-030 conversation decisions.
  - **Conflicts with:** BRIEF §16.1, §16.5; docs/research/roblox-platform-constraints.md P1-P13; D-030(2)
  - **Fix:** Add §16.5 to the account-level/collection item.

Note that a paid chest would be a paid random item, needing §16.1 approval and the PolicyService gate.

Point edicts at the content library's decisions (living-kingdom §2) instead of proposing a parallel system.

**Open PRs:** PR #45 (origin/forge/04-experience-fl0092, FL-0092: match30 profile and onboarding v2):
- The head is now dfefab2, a merge of main into 414bbbc.
- Since 414bbbc, only mutations.py changed, and only by the union with main. EXPERIENCE.md, Onboarding.luau, OnboardingService and events.md are unchanged.

Fixes:
- B1: the EXPERIENCE.md §2 table and config/Onboarding.luau move to v2: Spawn → InspectCitizen (client) → BuildOnPlot (BuildingPlaced with the placer match, BuildSlot) → AnswerCitizen (client, requires=ConversationService, autoAdvanceSec 120) → Recruit → Capture.
- InputModeController reports CitizenInspected.
- The idle hint drops gathering.
- match30 is added as a non-default profile that MatchService cannot select. Its PACING.md text keeps §16.10 open. This is correct.

Leaves unfixed:
- M1–M4, M6–M9 and all L items.
- The header still says v0.4-g2 / D-028.
- The row that replaces :25 still says 'enforced by Onboarding.validate'.
- The :35 example still names a completed building, although v2 has no completion step.
- §3, §8 and §9 are unchanged.

Introduces (M), funnel:
- OnboardingService no longer logs the Onboarding funnel step for a step that was passed over ('unavailable') or an interactive step that timed out ('the funnel counts what players did').
- Roblox counts skipped funnel steps as completed (events.md:16 and :30; the reason for G9 v0.4-g6). So once Recruit (step 5) is logged, AnswerCitizen (step 4) counts as done anyway. The intent fails silently, and step 4 really means 'reached step 5'.
- Fix: log every step as it completes, and add a custom event OnboardingStepPassed (value = step; fields stepName and via) for 'unavailable' and 'timeout'. Alternatively, measure answering through #64's ConversationAnswered and document what step 4 means.

Introduces (M), contract wording:
- G11:348 says onboarding steps are triggered by G9 events. InspectCitizen and AnswerCitizen are client actions.
- They grant nothing and complete only the current step, so the risk is low. FORGE-00 must still rule:
  - either amend G11 additively ('or whitelisted client actions that grant nothing');
  - or ask FORGE-01 for server events. Sim.Inspect is server-side and could fire a G9 CitizenInspected, and the proposed G9 CitizenAnswered still needs a ruling.

Remaining gap on main after #45 (M, for the build notes):
- D-038(1)'s 'fixes the stall at Gather' is true, but the v2 tutorial still cannot finish on main:
  - Build.PlaceSlot and Build.GetSlots are not declared (FL-0081), yet PlotPickerController invokes them. The BuildOnPlot hint's plot path therefore fails, although placing through the Build button (Build.Place) still completes the step.
  - Main has no Army remote area, no MilitaryService or ObjectiveService, and no HUD.Recruit target, and FORGE-03 hides the Army item (D-038(2)). The tutorial therefore waits at Recruit indefinitely.
- Fix: guard Recruit and Capture with `requires = "MilitaryService"` / `"ObjectiveService"` the way AnswerCitizen is guarded, or have FORGE-05 list the wait in the B-n 'not working yet' notes (D-038(6)).

For FORGE-07 to verify under D-038(1):
- `requires` checks for ConversationService through registry:find. D-038(1) speaks of Kingdom.Converse being absent.
- Neither exists on main: Kingdom/Remotes.luau declares no Converse. The two conditions are equivalent only if FL-0079 lands both together.
- The specs exist: 'without ConversationService, AnswerCitizen is passed over…' and 'with ConversationService but no answer reported… moves on after autoAdvanceSec'.

Housekeeping: #45's post-D-038 merge still edits mutations.py and events.md in place. D-038(7) asks FORGE-04 to split those files per feature in its next PR.

PR #64 (origin/forge/04-experience-fl0063, head 7ddc7cf; FL-0063 analytics):
- It does not touch EXPERIENCE.md.
- It is consistent with the Subjects pattern:
  - Analytics.luau passes `subjects = Signals.subjects`;
  - the VS1 funnel sets `inOrder = true`, which implements G9 v0.4-g6;
  - sessions start on KingdomJoined. On main, SessionStart never fires in game-001, because nothing fires PlayerReady (D-027); #64 fixes that.
- No privacy issue: ConversationAnswered (occupation, phase, decision = content farm_key) and ReputationShifted (category, source, phase) carry no player or entity ids and no free text. They add about 1,300 value combinations, against Roblox's 8,000 cap.
- The `mode` field includes match30 as an analytics label only, so it decides nothing.
- It adds the `session.startOn` and `session.leftInfo` callbacks, which belong in the M9 interfaces record.
- It documents FirstGather under D-030 (former M5). FORGE-00 should rule; keeping FirstGather for VS-1 is recommended.
- It keeps the `placedBy = true` match (L2).

Conflict between the two PRs:
- Both edit the analytics/schemas/events.md §5 onboarding row, and #64's row still lists the v1 steps (Gather, PlaceBuilding, BuildingComplete).
- Whichever PR merges second must switch that row to the v2 step names, and should do the D-038(7) per-feature split.

## Interfaces touched
None yet. If you change the Subjects pattern (M8/M9 of review 3), it becomes a framework contract change: propose it with a note for `docs/architecture/interfaces.md` §8.

## Next actions for the receiver
1. **Order:** fix the B findings first. B1 in `events.md` is the v0.4-g6 step order, which #64 implements. Then the B findings in PACING.md and EXPERIENCE.md: the D-029 arena and the D-030 v2 onboarding.
2. **Ask for re-review.** Reply with one PR per document, or one combined PR after #45, #49 and #64. FORGE-07 reviews the code and FORGE-00 re-reviews the docs.
3. **What closes each criterion:** FL-0023's 'Taxonomy reviewed by FORGE-00' is met once B1 is fixed; FL-0061's 'FORGE-00 review of the pacing doc' is met once B1 and B2 are fixed.
