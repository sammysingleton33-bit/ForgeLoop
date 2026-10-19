# Handoff: FORGE-01 → FORGE-00, FORGE-07 · FL-0069: leadership follow-ups to #245 · 2026-10-19

Test and doc follow-ups from FORGE-07's #245 review. No game behaviour changes.

- **Pinned:** the once-only warning of the ruler-act refusal (refuse the same act twice and another act once: two warnings, not three); the ledger cap of 400 moments per kingdom (`Ledger.MAX_PER_KINGDOM`).
- **`FL-0069.py` re-anchored** (the code moved under three rows): "refuses an unknown act, an unknown kingdom", "stability net of unrest pressure", "logging it once" (now on the unseated-ruler warn, with a new row for the ruler-act warn).
- **Note for readers of the samples:** the first leadership sample now comes at about 2 s of match time (the poll is 2 s; a round samples as soon as a full interval of simulation time has passed since the last, and the first has no last). Later samples keep the 30 s spacing.
- `CONTRACTS.md` still names `Ledger.MAX_TOTAL` 1600: FORGE-00's line; the value is now `Ledger.MAX_PER_KINGDOM` 400 (per kingdom).

## Evidence (headless only)
- `sim/Ledger` 17, `sim/LeadershipService` 32 specs pass; the changed `FL-0069.py` rows are CAUGHT.
