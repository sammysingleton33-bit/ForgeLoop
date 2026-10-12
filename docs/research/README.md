# Research index (2026-10-12): 12 decision-relevant facts
Short codes: SL = [Game #1 shortlist](../../intelligence/game-opportunities/game-001-shortlist.md), MR = [market landscape](../../intelligence/market-research/2026-10-roblox-landscape.md), PC = [platform constraints](roblox-platform-constraints.md), AI = [AI providers](ai-providers.md). Confidence is in each row.
1. Recommended Game #1 (not approved): C2 Flood Island 73.2. Next: C6 68.8, C4 68.4 (fragile order); the prior concept C1 scores 57.6, 7th of 8 (SL summary, §3).
2. Nothing is built: 0 Luau files on any branch, the skeleton FL-0003 is BUILDING, and the framework tasks are READY (not started). Every 7-day estimate starts after Phase 1 (SL §1, E25).
3. C2's lead rests on F7 4 and MO 4; with both at 3 it ties C6 (SL §4).
4. Home recommendations rank on per-user signals from organic RFY users. The top tier is play-through, first-play bounce (<60 s, 61–180 s), play days and playtime, measured over D1, D2–7 and D8–28 (MR 5.2–5.3, high).
5. 2026 is a reset year: DAU fell for 3 quarters to 123M, and Q3 bookings guidance is −14% to −18% YoY (MR 0.2, 0.5).
6. Chat requires an age check (since 2026-01-07), so social design must work without chat (MR 8.1, 8.9).
7. Paid random items need exact odds, a fail-closed `PolicyService` gate and a P11 treatment; Brazil bans them for under-18s. Earned random rewards need no disclosure (PC P1–P15, MR 8.7).
8. Purchases: keep a `PurchaseId` ledger in session-locked data and return granted only after a confirmed save (PC M6, D10).
9. Creator Rewards pay 5 R$ per Active Spender who plays ≥10 min, if yours is among their first 3 games that day (MR 6.2, high).
10. The Place Publishing API is BETA, capped at 10 MB, and does not update SurfaceAppearance or CSG. Meshes are capped at 20k triangles; plan for 2–4 GB Android devices (PC O1–O2, A1, A8).
11. Demand (low confidence): co-op horror has the strongest 2026 tailwind. Disaster incumbents are small (NDS ~8–14K; others ~0.6–3K). PvP is large (RIVALS ~130–290K) (MR 9.4, 1.9; SL E1, E3).
12. The single root `CLAUDE.md` imports `AGENTS.md`. All Claude sessions share one usage pool, and `main` is guarded by process plus CI, not a ruleset (AI R4, C-U3, R5).
## Open questions that need your account
- Choose Game #1 (A–E, FL-0035), and say whether paid random items or trading are allowed. Also run the Windows inventory of your old survival-arena files (FL-0034).
- Who owns the games (a group or your account), and is the owner ID-verified and 13+/18+? This sets the audio quota, fiat subscriptions and Extended Services access (PC open Q1).
- Create a test universe and an Open Cloud key on a dedicated account (FL-0039), and run the Studio smoke test on your PC (FL-0036).
- Switch the repository to Private (D-015). Check your Codex Plus limits and confirm which product "AreaAI" is (AI §5).
