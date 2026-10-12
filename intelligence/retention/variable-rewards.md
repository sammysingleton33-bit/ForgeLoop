# Earned variable rewards: design guide (FORGELOOP-01)

- **Prepared:** 2026-10-12 by the Game Design function. **Status:** design guidance, not a decision. Monetization changes need the user's approval (`AGENTS.md`).
- **Scope:** randomized rewards that players **earn by playing**, meaning no Robux and no currency bought with Robux anywhere in the path. Paid random items are covered only as a pointer (§9).
- **Labels:** O = observed (source states it), I = inferred or proposed by us. All tier numbers below are **illustrative design parameters (I)**, not observed data. FL-0022 (balance simulator) and live analytics should replace them.
- **Contract:** `docs/architecture/interfaces.md` §7: `RewardTables.odds(tableId, pityState)` is the single distribution the server samples from; `pityRule()` gives the text shown to players; `displayPercents()` uses largest-remainder rounding so shown odds sum to exactly 100.00%.

## 1. Rules that decide whether a reward is "earned"

| # | Rule | O/I | Source | Conf |
|---|---|---|---|---|
| R1 | Random rewards for actions with **no** Robux or currency payment need no odds disclosure and need not be reported in the maturity questionnaire (the doc's example is a key found in the world) | O | PC P7: creator-docs `production/monetization/paid-random-items.md` ([raw](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/paid-random-items.md)), read 2026-10-12, commit af5f853 (2026-10-10) | high |
| R2 | A random item bought **directly or indirectly** with Robux (including currency, keys or tickets bought with Robux) is a paid random item | O | PC P1, P5 (same doc) | high |
| R3 | Luck boosts, **pity systems**, enhanced drops and rate-up scrolls are paid random items when they are bought | O | PC P2 | high |
| R4 | Rewarded-video rewards must be developer products and **cannot be randomized items** | O | `production/promotion/rewarded-video-ads.md` ([raw](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/promotion/rewarded-video-ads.md)), read 2026-10-12 | high |
| R5 | House rule: earned random rewards still **show possible outcomes**; never fake odds or reveal animations | O | `AGENTS.md`; interfaces §7 | high |
| R6 | Consequence: keys, tickets, rerolls and boosts for earned chests must **never** be sold for Robux, or the whole chest becomes paid random | I | from R2, R3 | — |

## 2. Tier structure (proposed default)

| Tier | Role | Typical content (I) | Colour/sound |
|---|---|---|---|
| Common | frequent small win | soft currency, consumables | grey, short tick |
| Uncommon | "something new" | basic cosmetics, gear variants | green |
| Rare | session highlight | trails, emotes | blue |
| Epic | weekly highlight | full skin sets | purple, distinct sting |
| Legendary | story-worthy, clip-able | signature cosmetic | gold, unique reveal |

Rules (I): keep it to five tiers, because more tiers make the odds panels harder to read. Rewards are **cosmetic or convenience only**, never competitive power in PvP. Each tier keeps one visual and audio identity across all games so players learn it once.

## 3. Setting probabilities from target drops per session

Method (I): fix the **design target** for each tier first, then derive the per-open probability. `n` = expected opens per session, which comes from analytics later. Until then it is an assumption.

- Target "≥1 of tier T in a fraction q of sessions": `p = 1 − (1 − q)^(1/n)`
- Target "on average c drops of tier T per session": `p = c / n`
- Work with **cumulative** probabilities (Rare-or-better and so on), then subtract to get each tier. Common takes the remainder.
- Check value with expected value: EV = Σ value × probability. This is Roblox's own balancing method (O: `production/game-design/balance-virtual-economies.md`, read 2026-10-12. Note that its worked example lists Salmon as "30 Gold × 30% = 3G", which is internally inconsistent with the stated 10% chance; the 3G result matches 10%).

Worked example (I, illustrative; assumption n = 4 opens per session):

| Target | Formula | Cumulative p |
|---|---|---|
| Uncommon+ in 85% of sessions | 1 − 0.15^(1/4) | 0.3777 |
| Rare+ on average once every 2 sessions (c = 0.5) | 0.5 / 4 | 0.1250 |
| Epic+ once every 10 sessions (c = 0.1) | 0.1 / 4 | 0.0250 |
| Legendary once every 50 sessions (c = 0.02) | 0.02 / 4 | 0.0050 |

Resulting per-open odds: **Legendary 0.50%, Epic 2.00%, Rare 10.00%, Uncommon 25.27%, Common 62.23%** (sum 100.00%). Computed with a script; `displayPercents()` must reproduce the rounding.

## 4. Pity and bad-luck protection

Precedents (O):

| Game | Rule | Source | Conf |
|---|---|---|---|
| Hearthstone | Guaranteed legendary in the first 10 packs of a set (from Knights of the Frozen Throne); legendary pity timer 40 packs, with exact timers reportedly published by Blizzard on 2023-03-14 | [hearthstone.wiki.gg Card pack statistics](https://hearthstone.wiki.gg/wiki/Card_pack_statistics), [TechRaptor](https://techraptor.net/content/hearthstones-card-pack-system-is-changing) | med (secondary) |
| Hearthstone | A bug reset pity timers; Blizzard compensated players with 2,000 Arcane Dust. This shows that pity state is a player-trust asset. | [Mein-MMO](https://mein-mmo.de/en/hearthstone-bug-pity-timer-legendaries,167086) | low-med |
| Genshin Impact | 5★ base 0.6%, guaranteed by the 90th wish; average ~1.6% with pity; soft-pity start reported at ~74–75 | [Genshin fandom wiki](https://genshin-impact.fandom.com/wiki/Wish), [Android Authority](https://www.androidauthority.com/pity-count-genshin-impact-3185882) | low-med (not HoYoverse primary) |

Mechanics (I):
- **Hard pity:** guarantee tier T on open N if none dropped in N−1. Choose N from the share **f** of players you accept will ever need it: `N = 1 + ln(f) / ln(1 − p)`.
- Pity raises the effective rate, `E[opens] = (1 − (1 − p)^N) / p`. Lower the base `p` if the average must stay on target.

| Epic+ (p = 2.5%) | E[opens] | Effective rate | Share of players reaching pity |
|---|---|---|---|
| Hard pity N = 40 | 25.47 | 3.93% | 37.3% |
| Hard pity N = 60 | 31.24 | 3.20% | 22.5% |
| Hard pity N = 92 (f = 10%) | 36.11 | 2.77% | 10.0% |
| Soft pity +2 pp per open from open 60, hard at 92 | 32.70 | 3.06% | ≈0% |

- **Soft pity:** the odds ramp after S opens. The odds shown must be the **current state's** odds, from `RewardTables.odds(tableId, pityState)`, and the panel shows the counter ("Epic or better guaranteed within 12 opens").
- **Counters:** keep one per table and tier group, stored server-side in the `economy` namespace (interfaces §5), and reset only on a qualifying drop. A migration must never reset counters silently (see the Hearthstone bug above).
- **Streak breaker (I):** optionally block 4+ Commons in a row. Disclose it like pity.

## 5. Duplicates

Options (I), best first:
1. **Convert to shards/dust at a fixed, shown rate** per tier, with a crafting shop where any owned-tier item has a fixed shard price. This gives every player a **deterministic path** to a chosen item. Example (illustrative): dust 1/3/10/40/200 per tier gives EV ≈ 4.18 dust per open, all-duplicate case, using the §3 odds.
2. **Exclude owned items** from one-per-player pools. The shown odds must then be recalculated for that player (Roblox requires this for paid items, PC P4; we do it for earned items too).
3. Stacking duplicates (consumables only).

Never show a duplicate as "NEW!".

## 6. Outcome disclosure (house standard)

- Before opening: a worded **"Odds"** or **"Details"** control (a bare (i) icon is not enough for paid items, PC P4; we use the same UI for earned items). It lists every outcome and its current percentage, summing to exactly 100.00%, plus the pity rule and a rounding note.
- After opening: an **inventory history** (last N opens with tier), which players use to check fairness.
- Analytics: log `RewardRolled` (rarity, pity state, `pityTriggered`), and compare the observed distribution with the configured odds in FL-0018/FL-0045 specs (displayed odds equal the sampled distribution for every pity state).

## 7. Deterministic progression alongside

Variable rewards are **spice, not the meal** (I). Each game also ships:
- player XP levels with fixed rewards (FL-0026 quests feed XP);
- a daily reward and streak (MR 12.5 reports streak effects fading after ~day 14, low confidence, so use it to buy time for the intrinsic loop);
- a collection log that shows what is left to get;
- a season track if approved. Roblox guidance: free and premium tracks, ~10 tiers to start, catch-up XP late in the season, and missions that **never require hard currency** (O: `production/game-design/season-pass-design.md`, read 2026-10-12, high).

Target (I): a player who never gets lucky can still reach every reward category through levels, shards or the season track.

## 8. Honest reveal

| Rule (I unless noted) | Why |
|---|---|
| The result is rolled and saved **server-side before** any animation; the client only plays it back | Server authority (AGENTS.md); disconnects can't reroll |
| The animation shows the real tier from its first frame (colour and sound); no fake near-misses, no "slowing on Legendary then slipping" | AGENTS.md "never fake … reveal animations" |
| Reveal ≤ ~3 s, skippable, and "Open all" for batches | Respect the session (MR 12.1 onboarding guidance) |
| No countdown pressure or "last chance" on earned chests | Avoid the FOMO patterns criticised in MR 10.4 and 10.5 |
| The same reveal component is used for earned and paid chests, but paid ones also show price and policy gating | One honest UI (FL-0021) |

Context for why we hold this line (O):
- Loot-box spending is linked to problem-gambling severity (n = 7,422; η² = 0.054 vs 0.004 for other purchases). Causality is unresolved. [Zendle & Cairns 2018, PLOS ONE](https://eprints.whiterose.ac.uk/139116/) (high). This concerns **paid** loot boxes.
- Apple has required odds disclosure for paid loot boxes since Dec 2017 and Google Play since May 2019: [TouchArcade](https://toucharcade.com/2017/12/21/apple-quietly-updated-the-app-store-review-guidelines-to-require-disclosure-of-loot-box-iap-odds/), [PocketGamer.biz](https://www.pocketgamer.biz/google-play-developers-must-now-disclose-loot-box-odds) (med; current policy text not re-read).
- UK Ukie principles (2023-07-18) cover **paid** loot boxes only (earned ones are excluded) and include drop-probability disclosure and under-18 purchase restrictions. They are voluntary. [Inside Global Tech](https://www.insideglobaltech.com/2023/08/23/ukie-publishes-industry-principles-on-paid-loot-boxes/), [gov.uk](https://www.gov.uk/guidance/loot-boxes-in-video-games-update-on-improvements-to-industry-led-protections) (med).
- Disclosure compliance is often poor: 64% under Apple self-regulation (UK study) vs 95.6% in mainland China where it is legally required; only 5.5% showed odds on the purchase page itself. [Xiao et al., Durham repository](https://durham-repository.worktribe.com/output/1238986/gaming-the-system-suboptimal-compliance-with-loot-box-probability-disclosure-regulations-in-china) (med).
- On Roblox: 14 of 15 top-earning games used deceptive or misleading purchase designs, including opaque random rewards (MR 10.4); there is an FTC complaint about "gambling-like" mechanics (MR 8.8); and in Brazil under-18s cannot access paid random items (MR 8.7).

## 9. Paid random items: pointer only

Not designed here. If the user approves them for a game, follow `docs/research/roblox-platform-constraints.md` §1 (P1–P16) and interfaces §7:
- `PurchaseService:canBuyPaidRandom(player)`, cached at join with `pcall` and **false when unknown** (fail closed);
- numerical odds for every outcome before purchase, live updates while boosts are active (P6), odds updated when an outcome can only be obtained once (P4);
- one P11 treatment for restricted players; a trading gate on `IsPaidItemTradingAllowed` (P12); questionnaire answers (P14);
- a pass promoted on the Buy Robux page cannot grant paid random items (P15).

## 10. Checklist for any earned reward table

- [ ] No Robux path to keys, rerolls, boosts or currency used by the table (R6)
- [ ] Targets per session written down, with `p` derived per §3 and EV checked
- [ ] Pity rule chosen (N from f), shown text from `pityRule()`, counters persisted
- [ ] Duplicate policy plus a deterministic path (§5)
- [ ] Odds panel (worded control, sums to exactly 100.00%, current pity state)
- [ ] Server rolls before reveal; reveal honest and skippable
- [ ] Analytics `RewardRolled` plus a distribution test in CI

## Gaps

- Our own opens-per-session and session length: unknown until a playtest (n is assumed).
- Hearthstone and Genshin figures are from secondary sources; primaries were not read.
- Apple and Google current guideline text was not re-read (secondary coverage from 2017/2019).
- No Roblox first-party data on how earned chests affect retention: not found.
