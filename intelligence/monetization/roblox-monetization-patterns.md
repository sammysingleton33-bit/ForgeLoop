# Roblox monetization patterns (FORGELOOP-01)

- **Prepared:** 2026-10-12 by the Game Design function. **Status:** reference, not a decision. Price lists, paid random items and trading each need the user's approval (`AGENTS.md`).
- **Sources:** official creator docs read from `github.com/Roblox/creator-docs` at commit af5f853 (2026-10-10), fetched 2026-10-12 (cited as `CD:<path>`; URL = `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/<path>`). Also `docs/research/roblox-platform-constraints.md` (PC), the market sweep (MR) and new WebSearch results.
- **Labels:** O = observed, I = inferred. Third-party price observations are **low** confidence: they come from search snippets of fan or guide sites, often undated, and prices change (Managed Pricing can vary them per region and user, so different readers may see different prices).

## 1. Product types

| Product | What it is (O) | Key limits/rules (O) | Source | Conf |
|---|---|---|---|---|
| Pass | One-time Robux purchase for a permanent privilege | Listed passes surface outside the game (homepage, search, post-purchase); a pass promoted on the Buy Robux page must be >49 and <801 R$ and **cannot grant paid random items**; cross-game pass sales disabled from 2026-05-30; game-pass min/max price: **not found** | CD:production/monetization/passes.md; PC P15, M12, M16 | high |
| Developer product | Repeatable purchase (consumables, currency) | 1 to 1,000,000,000 R$; must handle `ProcessReceipt`/`BindReceiptHandler` idempotently; **Listed** products can sell in the Store/Shop tab | CD:production/monetization/developer-products.md; PC M1–M9, M16 | high |
| Shop (Roblox-hosted) | Personalised in-game shop surface ranked by Roblox | Passes are always listed; products can be listed or unlisted | CD:production/monetization/shop.md | high |
| Subscription | Monthly recurring benefit | Up to 50 per game; Robux price ≥49 R$ (70% monthly payout) or fiat $2.99/$4.99/$7.99/$9.99/$14.99 (70% month 1, then 100%); fiat unavailable in 12 countries; battle passes may be sold as subscriptions | CD:production/monetization/subscriptions.md; PC M13, M14 | high |
| Private servers | Free or monthly-fee servers | Changing the price **cancels all active subscriptions**; min/max price not found | CD:production/monetization/private-servers.md; PC M15 | high |
| Paid access (Robux) | Pay to enter the game | 25–1,000 R$ | PC M16 | high |
| Paid access (local currency) | Pay to enter, bought on desktop/web | $9.99 → 50%, $29.99 → 60%, $49.99 → 70% developer revenue share | CD:production/monetization/paid-access-local-currency.md | high (resolves MR 11.9) |
| Roblox Plus incentives | Platform subscription ($4.99/mo, MR 6.5) | Roblox funds the 10% (months 1–2) and 20% (month 3+) discounts, so a 100 R$ item earns the creator 70 R$ either way; up to **750 R$ per new subscriber** prompted with `MarketplaceService.PromptRobloxSubscriptionPurchase`; up to 100 R$ per subscriber with ≥60 min/month in paid private servers; 10% of in-game Robux transfers by subscribers | CD:production/monetization/roblox-plus.md | high (resolves MR 6.6's API-name doubt) |
| Robux transfers | Player-to-player Robux in game | 10–500 R$, 10% to the game | PC M16 | high |
| Rewarded video ads | Ad watched for a developer-product reward | Reward must be a developer product, **never randomized**; recommended value **3–10 R$ equivalent**; publisher must be 13+, ID-verified, public game with ≥2,000 unique visitors/month and an approved questionnaire; viewers 13+ only (MR 11.8) | CD:production/promotion/rewarded-video-ads.md | high |
| Immersive ads | In-world image and portal ads | Ineligible users see a fallback | CD:production/monetization/immersive-ads.md | high |
| Creator Rewards | Platform payouts for engagement/acquisition | 5 R$ per active spender playing ≥10 min if yours is among their first 3 games that day; audience expansion share | MR 6.2, 6.3 | med-high |
| Managed / regional pricing | Roblox price tests + regional prices | Price tests need ~60,000 transactions in 30 days and rerun at least every 90 days; regional prices 30–100% of default; **hard-coded UI prices break tests and show Plus subscribers the wrong price** | CD:production/monetization/price-optimization.md, roblox-plus.md; MR 11.7 | high |
| Paid random items | Random outcome bought directly or indirectly with Robux | Odds before purchase, `PolicyService` gating, Brazil under-18 ban, questionnaire | PC §1 P1–P16; MR 8.7 | high |

## 2. Observed price points

| Game | Item | Price | O/I | Source | Date | Conf |
|---|---|---|---|---|---|---|
| Murder Mystery 2 | Elite pass (XP 1.5x, cosmetics) | 499 R$ | O | [Sportskeeda](https://www.sportskeeda.com/roblox-news/roblox-murder-mystery-2-official-links-gamepasses) | entry last updated 2019 | low-med |
| Murder Mystery 2 | Radio pass | 475 R$ | O | [Bloxodes wiki](https://bloxodes.com/wiki/murder-mystery-2/radios) | undated | low |
| Natural Disaster Survival | Gear passes: Green Balloon / Red Apple / Compass | Green Balloon 80 R$ (earnaldo); fan wiki: microtransactions "only costing 80 Robux"; Compass price **not found** (earlier "60 R$" withdrawn 2026-10-12). Unverified | O | [earnaldo](https://earnaldo.com/blog/natural-disaster-survival-free-robux-guide), [Perfection wiki](https://perfectionrobloxgames.miraheze.org/wiki/Natural_Disaster_Survival) (WebSearch 2026-10-12) | undated | low |
| Steal a Brainrot | VIP / 2x Money / Admin Commands | 499 / 299 (other listings 119 or 199) / 4,999 R$ ("discounted" from 9,999) | O | MR 11.1 | 2026 | low |
| Grow a Garden (original) | Season pass / skip 1 tier / skip all | 749 / 49 / 1,699 R$ | O | MR 11.2 | 2025 | low-med |
| 99 Nights in the Forest | Diamonds 20 / 100 / 250 / 700 | 99 / 400 / 900 / 2,500 R$ | O | [esports.gg](https://esports.gg/news/roblox/diamonds-99-nights-in-the-forest/), [Deltia's](https://deltiasgaming.com/?p=296205) | 2025–26 | low |
| BedWars | Battle pass (Season 1 and Season 7 guides) | 799 R$; a single pass level reported at 300 R$ (one guide) | O | [GameWith](https://gamewith.net/roblox/57450), [Gamer Journalist](https://gamerjournalist.com/bedwars-season-1-battle-pass-update/) | older seasons | low |
| RIVALS | Skin case / 3-pack | 249 / 724 R$ | O | [Eldorado.gg](https://www.eldorado.gg/blog/?p=13283) | ~May 2026 | low |
| DOORS | Lobby shop (knobs, revives, boosts) | entries at 49 / 99 / 129 / 199 R$ (item mapping not captured; wikis conflict) | O | [DOORS wiki (breezewiki mirror)](https://breezewiki.discard.no/doors-game/wiki/Shops) | undated | low |
| Roblox guidance | Rewarded-ad reward value | 3–10 R$ equivalent | O | CD:production/promotion/rewarded-video-ads.md | 2026-10-10 | high |

Observed ladder (I, from the table and MR 11.11): small utility items **49–99 R$**; core passes (VIP, multiplier, signature perk) **~299–499 R$**; season/battle passes **~400–800 R$**; currency packs scaling to **~2,500 R$**; prestige or admin passes **~1,999–4,999 R$**.

## 3. Fit by genre (I, grounded where cited)

| Genre (shortlist IDs) | Best-fit products | Earned variable rewards | Avoid |
|---|---|---|---|
| Disaster survival PvE (C2, C3) | Cheap utility gear passes (NDS model, ~80 R$ reported, unverified), cosmetics (skins, trails), season pass, paid private servers (Plus payout) | Relic caches from play, keys earned only | Selling keys for Robux (makes caches paid random); a revive that decides the round winner |
| Social deduction (C6) | Cosmetic weapons/emotes, Elite-style pass (MM2 499 R$), seasonal bundles | Shard crates | Paid mystery boxes without approval and gating (MM2 sells event boxes and packs, MR 1.2); trading (PC P12) |
| Co-op horror (C4) | Consumable revives and utility items sold in context (Roblox's own Doors example), classes via currency (99 Nights), cosmetics | Post-run chests | Robux-bought currency spent on random rolls (paid random, PC P1) |
| PvP arena / battle royale (C1, C5) | Cosmetic skins, battle pass, skin cases (RIVALS model, MR 11.3) | Free-track crates | Any stat advantage (pay-to-win) |
| Fishing / collection (C7) | Rods, bait, storage, cosmetics | Catches themselves are earned random | Selling luck rods or boosts without odds and gating (paid probability modifiers, PC P2, P6) |
| Party / minigames (C8) | Cosmetics, VIP, private servers | Daily crate | Pay-to-skip minigames |

Cross-genre: offer a season pass with free and premium tracks whose missions never need hard currency (CD:production/game-design/season-pass-design.md). Use contextual offers, and don't show a starter pack on the first-ever load screen (CD:production/game-design/contextual-purchases.md). Sell items whose value is obvious, like the Doors flashlight (CD:production/game-design/monetization-foundations.md).

## 4. Anti-patterns

| Anti-pattern | Why (O unless marked) | Source |
|---|---|---|
| Hiding prices behind multiple currencies, fake discounts, opaque random rewards | Found in 14 of 15 top-earning Roblox games; reputational and regulatory risk | MR 10.4 (Univ. of Sydney, 2026-05-17) |
| Paid random items without numerical odds, `PolicyService` gate, P11 treatment or questionnaire | Violates Roblox rules; Brazil under-18 ban; FTC complaint context | PC P3–P14; MR 8.7, 8.8 |
| Selling keys, rerolls or luck for **earned** chests | Turns them into paid random items | PC P1, P2, P5 |
| Randomized rewarded-ad rewards | Prohibited | CD:production/promotion/rewarded-video-ads.md |
| Hard-coded prices in UI | Breaks price optimization; shows Plus subscribers wrong prices | CD:production/monetization/price-optimization.md, roblox-plus.md |
| Granting from `PromptProductPurchaseFinished`, or a `ProcessReceipt` without a `PurchaseId` ledger | Lost or duplicated grants; Store listing hidden | PC M6, M7, M9 |
| Changing private-server price casually | Cancels all active subscriptions | CD:production/monetization/private-servers.md |
| Missions that require hard currency in a season pass | Excludes free players; Roblox advises against | CD:production/game-design/season-pass-design.md |
| Pay-to-win in PvP | Cheating and fairness are top complaints in shooters | MR 10.3 (I for the link) |
| FOMO "admin abuse" style timed spikes as the main lever | Criticised as concurrency manipulation; rushed events cause backlash | MR 3.2, 3.5, 10.1, 10.5 |
| Prestige 4,999 R$ "discounted from 9,999" anchoring | A fake-discount pattern of the kind flagged by the Sydney study | MR 11.1, 10.4 (I) |

## 5. Defaults proposed for Game #1 (I, need user approval)

- Direct-priced cosmetics and 1–3 passes on the observed ladder, all priced dynamically through `MarketplaceService` (no hard-coded prices).
- Earned-only variable rewards per `intelligence/retention/variable-rewards.md`; **no paid random items in v1**.
- Season pass with a free track after launch (not day 1); paid private servers enabled; Plus prompt optional; rewarded ads only if eligibility is met, with fixed rewards.

## Gaps

- No first-party per-game revenue or price data (Roblox doesn't publish it); every game price above is third-party and low confidence.
- Game-pass min/max price and private-server min/max: not found in the docs snapshot.
- RIVALS battle-pass and key prices: conflicting snippets, not pinned to a URL, so excluded.
- Conversion rates by price point on Roblox: not found.
