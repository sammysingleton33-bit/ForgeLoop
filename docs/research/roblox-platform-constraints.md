# Roblox platform constraints for FORGELOOP-01

Research for FL-0004, done 2026-10-12. Every fact has an ID so a verifier can check it and record corrections.

**Legend.** Conf = high / med / low. Type: **O** = observed (the source says it), **I** = inferred (our analysis). "Not found" means we searched and found no source for it. It does not mean the thing doesn't exist.

**Access during this research (O).** The session proxy blocked `create.roblox.com` (DNS failure) and `devforum.roblox.com` (HTTP 403). That means:
- **Official docs** were read from `github.com/Roblox/creator-docs` at commit `af5f853`, dated **2026-10-10**. That repo is the published source of create.roblox.com/docs. Its commit message is "update Open Source Docs from Roblox internal teams". Facts from it are **high** confidence as of that date.
- **DevForum and other third-party facts** come only from WebSearch snippets. They are capped at **med**.
- **Tool versions** come from `git ls-remote` and from `raw.githubusercontent.com`.

**Source keys** (used in the tables below):

| Key | URL | What it is |
|---|---|---|
| `CD:<path>` | `https://create.roblox.com/docs/<path>` | Official docs (snapshot 2026-10-10) |
| `REF:<Class>` | `https://create.roblox.com/docs/reference/engine/classes/<Class>` | Engine API reference (same snapshot) |
| `OA` | `https://create.roblox.com/docs/cloud/reference` (repo file `content/en-us/reference/cloud/openapi.json`) | Open Cloud OpenAPI spec, including the `x-roblox-stability`, `x-roblox-rate-limits` and `x-roblox-scopes` fields (same snapshot) |
| `OA:place-pub` | repo file `content/en-us/reference/cloud/universes-api/v1.json` | Place Publishing API spec (same snapshot) |

---

## 1. Paid random items

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| P1 | **Definition.** A paid random item is a random item bought directly or indirectly with Robux. This includes items bought with in-game currency that was bought with Robux. The doc's examples are "Paying Robux to spin a prize wheel" and "Paying Robux to buy gems or spin tickets that are spent at a prize wheel". | CD:production/monetization/paid-random-items | 2026-10-10 | high | O |
| P2 | **Covered types.** Capsule (spin a wheel, hatch an egg, open a chest). Enhancement (a potion with a random duration, an upgrade with a chance to work). Combination (fusing eggs for a better chance). Probability modifiers (luck boosts, **pity systems**, enhanced drops, rate-up scrolls). | same | 2026-10-10 | high | O |
| P3 | **Disclosure.** Under the Terms of Use and Community Standards, you must show all possible outcomes and the **actual numerical odds** before purchase. | same | 2026-10-10 | high | O |
| P4 | **Odds format.** Odds are shown as percentages, and all final outcomes must sum to **exactly 100%**. Long decimals may be rounded to 4 or more decimal places below the first non-zero digit, with a disclaimer such as "Probabilities are rounded…". A pop-up is allowed, but only behind a labelled "Info" or "Details" button; a bare (i) icon is **not** enough. One header "Odds for each item listed below: X%" is allowed when items share odds. If an outcome can be obtained only once, the remaining odds must be updated for that user. | same | 2026-10-10 | high | O |
| P5 | **Indirect purchases.** Keys, re-roll tokens and spin tickets bought with Robux are covered. Odds must be shown before the player spends the currency. | same | 2026-10-10 | high | O |
| P6 | **Paid odds modifiers.** For a paid "lucky potion" or "magic fishing rod", the effect must be explained numerically before purchase. While it is active, the displayed odds must update to show the player's true odds. | same | 2026-10-10 | high | O |
| P7 | **Earned random rewards are different.** Random rewards for actions that involve **no** Robux or currency payment need no odds disclosure (the doc's example is a key found in the world). They also need not be reported in the maturity questionnaire. | same; CD:production/promotion/content-maturity | 2026-10-10 | high | O |
| P8 | **`PolicyService:GetPolicyInfoForPlayerAsync(player)` returns these fields:** `AreAdsAllowed`, `ArePaidRandomItemsRestricted`, `IsContentSharingAllowed`, `IsEligibleToPurchaseCommerceProduct`, `IsEligibleToPurchaseSubscription`, `IsPaidItemTradingAllowed`, `IsPhotoToAvatarAllowed`, `IsSubjectToChinaPolicies`, `AllowedExternalLinkReferences` (legacy, always an empty array), `IsEndlessContentLoadAllowed`, `IsEndlessContentAutoplayAllowed`. | REF:PolicyService | 2026-10-10 | high | O |
| P9 | The result is "based on geolocation, age group, and platform". The call yields and must be wrapped in `pcall`. On the client it works only for the local player; the error is "cannot be called on the client for a non-local player". | REF:PolicyService | 2026-10-10 | high | O |
| P10 | The exact countries and age bands that set `ArePaidRandomItemsRestricted = true`: **not found**. Roblox does not publish them, so the API is the only source of truth. | REF:PolicyService; CD:paid-random-items | 2026-10-10 | high | O |
| P11 | **When the flag is `true`, the creator must apply one of these treatments:** a free, earnable path; outcomes in a fixed, non-random order disclosed before purchase; direct purchase priced at expected value (the doc's example: 10 R$ at 5% odds becomes 200 R$); remove or hide the item; block the purchase with a message; or move the player out of the area (for example, by teleport). | CD:paid-random-items | 2026-10-10 | high | O |
| P12 | When `IsPaidItemTradingAllowed` is false, the player must not be able to trade the results of paid random items or any other paid items. | same | 2026-10-10 | high | O |
| P13 | "If a user can use Robux or something else that was acquired with Robux to get a random reward, you are **required** to use `PolicyService` to block this feature" for users who aren't permitted. | CD:production/monetization (index) | 2026-10-10 | high | O |
| P14 | The Maturity & Compliance Questionnaire asks whether the game has paid random items and whether it respects `ArePaidRandomItemsRestricted`. | CD:production/promotion/content-maturity | 2026-10-10 | high | O |
| P15 | A pass promoted on the Buy Robux page cannot grant paid random items. | CD:production/monetization/passes | 2026-10-10 | high | O |
| P16 | Any change to these rules made in 2026: **not found**. A search snippet says the English page metadata reads "last updated 2026-08-19". | WebSearch snippet of the CD page | 2026-08-19 | med | O |

**Implications (I).**
- I-P1. Any currency that can be bought with Robux turns every random spend of that currency into a paid random item (P1, P5). The cheapest compliant design keeps random rolls on a **soft currency that cannot be bought with Robux**. If Game #1 sells luck boosts or pity systems, those are paid random items too (P2).
- I-P2. If a paid random item ships, it needs all of the following:
  - a server-side odds table that is the single source of truth;
  - an odds UI generated from that table, with a test that asserts the sum is exactly 100%;
  - a call to `GetPolicyInfoForPlayerAsync` on join, cached for the session, treated as **restricted** if the `pcall` fails (fail closed);
  - one P11 treatment;
  - a trading gate on `IsPaidItemTradingAllowed`;
  - the questionnaire answer.
- I-P3. The house rule in `AGENTS.md` asks us to "show possible outcomes" for earned random rewards as well. That is stricter than the platform requires (P7), but it is cheap to keep.

## 2. MarketplaceService

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| M1 | Set `ProcessReceipt` **once**, in one server `Script`. It must handle every developer product. If you don't implement it, receipts are **auto-acknowledged** and can't be recovered. | REF:MarketplaceService | 2026-10-10 | high | O |
| M2 | The callback runs for unresolved purchases when a purchase completes, when a successful purchase prompt appears, and when the user joins a server. | same | 2026-10-10 | high | O |
| M3 | **There is no time-based retry.** After `NotProcessedYet`, the callback runs again only if the user starts another developer product purchase or rejoins **any** server of the game. There is also no timeout: the callback can yield for as long as the server runs. | same | 2026-10-10 | high | O |
| M4 | The same purchase can run on **two servers at once** if the user joins a second server before the first callback returns. Pending purchases are processed in a non-deterministic order. A `PurchaseGranted` result can fail to record, in which case the purchase stays unresolved. Unresolved purchases are not refunded when escrow expires. The user must be on the server for the callback to run. | same | 2026-10-10 | high | O |
| M5 | `receiptInfo` fields: `PurchaseId`, `PlayerId`, `ProductId`, `PlaceIdWherePurchased`, `CurrencySpent`, `CurrencyType` (always Robux), `ProductPurchaseChannel`. | same | 2026-10-10 | high | O |
| M6 | **The official handling recipe:** (1) check that the `PurchaseId` is not already recorded in the player's data; (2) grant the item in memory; (3) record the `PurchaseId`; (4) save to the DataStore; (5) return `PurchaseGranted` only if the save succeeded, otherwise `NotProcessedYet`. If the `PurchaseId` is recorded but not yet saved, return `NotProcessedYet`. The recipe depends on **session locking** to avoid races between servers. | CD:cloud-services/data-stores/player-data-purchasing | 2026-10-10 | high | O |
| M7 | The minimal sample on the developer-products page does **not** deduplicate by `PurchaseId`. | CD:production/monetization/developer-products | 2026-10-10 | high | O |
| M8 | **`MarketplaceService:BindReceiptHandler(ReceiptType, handler, filter?)` is a newer alternative.** Types: `DeveloperProduct`, `RobuxTransferSender`, `RobuxTransferReceiver`. The handler returns `Enum.ReceiptDecision.Processed` or `NotProcessedYet`. Handlers can be filtered by product ID or catch-all. A bound handler takes precedence, and receipts it doesn't match fall through to `ProcessReceipt`. Registering a duplicate throws an error. It returns a connection. | REF:MarketplaceService | 2026-10-10 | high | O |
| M9 | To sell a developer product outside the game (the Store tab), it must be **Listed** and `ProcessReceipt` must be implemented correctly. Roblox checks this continuously, and a flagged product is hidden from external surfaces until it is fixed. Never grant items from `PromptProductPurchaseFinished`. | CD:developer-products | 2026-10-10 | high | O |
| M10 | Roblox does not record per-user purchase history for developer products, so the creator must store it. | same | 2026-10-10 | high | O |
| M11 | **`UserOwnsGamePassAsync`** works on the client and the server, and results are cached. The cache updates when `PromptGamePassPurchaseFinished` fires. A purchase made outside the game during a session can take "several minutes" to show up. The call always returns true on the first server join after a purchase. It supports transparent batching. | REF:MarketplaceService | 2026-10-10 | high | O |
| M12 | "Starting May 30, 2026, cross-game pass sales will be disabled." | CD:passes | 2026-10-10 | high | O |
| M13 | **Subscriptions.** Up to 50 per game. Check status **on the server** with `GetUserSubscriptionStatusAsync(player, id)`, which returns `{IsSubscribed, IsRenewing}`; `IsSubscribed` is false while payment is still processing. Listen to `Players.UserSubscriptionStatusChanged`. Gate sales on `PolicyService.IsEligibleToPurchaseSubscription`. | CD:production/monetization/subscriptions; REF:MarketplaceService; CD:monetization index | 2026-10-10 | high | O |
| M14 | **Subscription prices.** In Robux: at least 49 Robux, with regional pricing forced on, paying 70% every month. In local currency: tiers of $2.99, $4.99, $7.99, $9.99 or $14.99, requiring an ID- or phone-verified account, sold only on Web, App Store and Google Play, and not sold in 12 listed countries; it pays 70% in the first month and 100% after that. A Robux price can change once every 60 days, and an increase needs 30 days' notice. A local-currency price can't change. Robux earnings have the same ~5-day hold as passes; local-currency earnings have a 30-day hold. Webhooks exist for cancelled, purchased, refunded and renewed. | CD:subscriptions | 2026-10-10 | high | O |
| M15 | **Private servers** can be free or cost a monthly Robux fee. The game must be public. They can't be combined with paid access. Changing the price **cancels all active private-server subscriptions**. Minimum and maximum price: **not found**. | CD:production/monetization/private-servers | 2026-10-10 | high | O |
| M16 | **Price rules.** Developer product: 1 to 1,000,000,000 Robux. Paid access: 25 to 1000 Robux. Promoted pass, if on sale: more than 49 and less than 801 Robux. Regional prices are never more than 70% below the default and never above it. Robux transfers: 10 to 500 Robux, with 10% to the game. **Game pass minimum and maximum: not found** in the snapshot. | CD:developer-products; paid-access-robux; passes; regional-pricing; robux-transfers | 2026-10-10 | high | O |

**Implications (I).**
- I-M1. Build one `PurchaseService` that adopts `BindReceiptHandler(DeveloperProduct)` and keeps a `ProcessReceipt` fallback. It should implement M6 exactly: store a `PurchaseId` ledger inside the session-locked player record and return "processed" only after a save is confirmed. Don't copy the M7 sample.
- I-M2. A headless test must cover two cases: a duplicate `PurchaseId` grants only once, and a failed save returns `NotProcessedYet`.
- I-M3. Use passes for permanent perks and check them with `UserOwnsGamePassAsync` on join. Also listen to `PromptGamePassPurchaseFinished` so the perk applies in the same session.
- I-M4. Changing private-server prices is destructive (M15), so it needs owner approval.

## 3. DataStores

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| D1 | **Name limits.** Data store name, key name and scope: 50 characters each. Value: 4,194,304 characters per key, stored as a string (measure it with `JSONEncode`). Strings must be valid UTF-8. | CD:cloud-services/data-stores/error-codes-and-limits; REF:GlobalDataStore | 2026-10-10 | high | O |
| D2 | **User metadata.** Keys up to 50 characters, values up to 250, and 300 characters in total across all pairs. | error-codes-and-limits | 2026-10-10 | high | O |
| D3 | **Per-key throughput** (counted across all servers over the last 60 s; each request rounded up to the next KB): reads 25 MB/min, writes 4 MB/min. Exceeding it gives `DatastoreThrottled` or `KeyThrottled`. | same | 2026-10-10 | high | O |
| D4 | **Experience-wide budget, standard stores, requests/min.** Read 300 + CCU×40. Write 300 + CCU×20. List 300 + CCU×2. Remove 300 + CCU×40. `UpdateAsync` consumes **both** read and write. **Open Cloud shares this budget** with game servers. | same | 2026-10-10 | high | O |
| D5 | **Per-server defaults, requests/min.** StandardRead and StandardWrite: 60 + players×40. StandardList: 5 + players×2. StandardRemove: 60 + players×40. Ordered stores: Write and Remove 30 + players×5. Each server also gets a one-time startup burst. These can be configured with `SetRateLimitForRequestType` and checked with `GetRequestBudgetForRequestType`. Studio Run mode has separate, possibly lower, static limits. | same | 2026-10-10 | high | O |
| D6 | **Queues.** When throttled, requests queue (Set, Ordered set, Get, Ordered get), and each queue holds 30. Beyond that, requests fail with errors 301–306. | same | 2026-10-10 | high | O |
| D7 | **Storage.** Total latest-version storage is limited to 500 MB + 1 MB × lifetime users (compressed size; Roblox compresses for you, so don't pre-compress). Usage over quota shows "Est. Monthly Costs"; going beyond the defaults is a paid **Extended Services** program (ID-verified, 18+). | same; CD:cloud-services/extended-services; data-stores-manager | 2026-10-10 | high | O |
| D8 | **`UpdateAsync` semantics.** The callback receives `(currentValue, DataStoreKeyInfo)` and returns `(newValue, userIds?, metadata?)`. Returning `nil` cancels the write. If another server wrote in between, the callback **runs again** (possibly many times). It **cannot yield**. If you don't return `GetUserIds()` and `GetMetadata()`, they are cleared. Ordered stores aren't versioned. | REF:GlobalDataStore | 2026-10-10 | high | O |
| D9 | **A failed write may still have succeeded on the backend.** Verify it with `GetAsync` and `DataStoreGetOptions.UseCache = false`. `GetAsync` caches for **4 s** by default. Retry in order per key, with exponential backoff and jitter. | error-codes-and-limits; versioning-listing-and-caching; best-practices | 2026-10-10 | high | O |
| D10 | **Session locking (official pattern).** Every request goes through `UpdateAsync`. The transform function refuses to proceed if another server holds an unexpired `LockId` in the key **metadata**; it sets or clears its own GUID lock. The lock is refreshed by the autosave and released on the final save in `PlayerRemoving` or `BindToClose`. The official sample autosaves every **180 s**. The exact lock expiry value isn't stated in the prose (**not found**). | CD:player-data-purchasing; best-practices | 2026-10-10 | high | O |
| D11 | **`BindToClose`.** The server waits **30 seconds** for all bound functions; they run in parallel. Save all players in parallel. | REF:DataModel; player-data-purchasing | 2026-10-10 | high | O |
| D12 | **Versioning.** `Set`, `Update` and `Increment` create a backup at the first write to a key in each UTC hour. A backup expires 30 days after it is overwritten. The latest version never expires. Only the latest version counts toward storage. | CD:versioning-listing-and-caching; best-practices | 2026-10-10 | high | O |
| D13 | **Player identity.** Pass `userIds` (as an array) on writes for privacy/IP tracking. Use static keys such as `User_{UserId}` so automated right-to-be-forgotten (RTBF) processing can find player data; there is an RTBF webhook as an alternative. Use one key, or a few, per player. Don't use DataStore2 for new work. | CD:index; best-practices | 2026-10-10 | high | O |
| D14 | Shard hot **read** keys (for example `Weather_1..N`) only to address per-key read throttling. | best-practices | 2026-10-10 | high | O |

**Implications (I).**
- I-D1. Use one `PlayerData` store with key `User_<id>`, a single versioned record (`schemaVersion`), session-locked `UpdateAsync`, a `PurchaseIds` ledger and a jittered autosave of 180 s or less.
- I-D2. Ops scripts that use Open Cloud (D4) eat into live budget. Rate-limit them, and never run them against a production universe during a launch.
- I-D3. Headless tests need a mock DataStore that reproduces D8 (callback re-run, `nil` cancel) and D9 (unknown write outcome).

## 4. Luau: require-by-string and the type solver

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| L1 | **The engine's `require(string)` resolves relative to the calling script:** `./` starts at `script.Parent`, `../` at `script.Parent.Parent`, `@self/` at `script`, and `@game/` at `game`. Each component after that is a child, and `..` means parent. Resolution is **non-blocking**: it errors if the ModuleScript doesn't exist yet. Module results are cached per side of the client/server boundary. | CD:reference/engine/globals/LuaGlobals (`require`) | 2026-10-10 | high | O |
| L2 | **User-defined aliases (`.luaurc` `@alias`) in the Roblox engine: not found.** The engine docs list only the `./`, `../`, `@self/` and `@game/` prefixes. The launch post said aliases were "Not yet, but we're working on it!". We found no later announcement. | L1; DevForum "Introducing Require-by-String" (devforum.roblox.com/t/introducing-require-by-string/3405078) | DevForum date not shown | med | O |
| L3 | **`init.luau` semantics (Luau RFC, status Implemented).** Inside `pkg/init.luau`, `./foo` resolves to a **sibling of `pkg`**, not a child. Use `@self/foo` for children. This matches how Rojo maps `init.luau` to the folder instance. | github.com/luau-lang/rfcs `abstract-module-paths-and-init-dot-luau.md` | repo HEAD 2026-09-19 | high | O |
| L4 | Standalone Luau supports `.luaurc` alias maps (RFC status Implemented). That is the standalone/CLI behaviour, not proof that the engine supports them. | luau-lang/rfcs `require-by-string-aliases.md`, `amended-require-resolution.md` | 2026-09-19 | high | O |
| L5 | **New type solver.** It was announced as a general release around 20 Nov 2025 and is on by default for `nocheck` and `nonstrict` scripts, with `strict` users opting in. One unofficial source says the default switch was 2026-01-07. A removal date for the legacy solver: **not found**. The official docs snapshot doesn't mention the solver. | WebSearch snippets (DevForum "New Type Solver [Beta]" thread, third-party blogs) | 2025-11 to 2026-01 | low–med | O |

**Implications (I).**
- I-L1. D-004 stands: relative `./` and `../` requires mean the same thing in Roblox (L1) and in standalone Luau after the RFCs (L3). Keep "no aliases" (L2). Allow `@self/` only inside `init.luau`, and keep the existing rule in `interfaces.md` against mutually-requiring `init` children.
- I-L2. Because L1 is non-blocking, a client script that requires replicated modules by string could error if they haven't replicated yet. Studio smoke test S1 should require from `StarterPlayerScripts` into `ReplicatedStorage` on a cold join (unverified risk).
- I-L3. Don't depend on strict-mode behaviour of the new solver in CI. luau-lsp or Selene results may differ from what Studio shows (unverified).

## 5. Studio sync: Script Sync vs Rojo vs Argon

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| S1 | **Script Sync status: Beta.** The coding-harness guide says "Script Sync is a beta feature" and is enabled under File → Beta Features. The Script Sync page itself carries no beta label in this snapshot. A GA announcement: **not found**. The DevForum beta post is "Studio Script Sync – Now In Beta!" (t/4065468). | CD:ai/coding-harness; CD:scripting/sync; DevForum snippet | 2026-10-10 | high (beta) | O |
| S2 | **Script Sync scope.** It syncs only `Script`, `LocalScript`, `ModuleScript` and `Folder`, ignoring all other instances. It **ignores attributes and tags**, and Roblox warns this "can lead to data loss". It can't control the debugger. Limits: 10,000 scripts per top-level synced instance and 128 top-level synced instances. | CD:scripting/sync | 2026-10-10 | high | O |
| S3 | **Script Sync behaviour.** Conflicts open a Keep Studio / Keep Disk dialog. It works with Team Create but warns that simultaneous edits can overwrite each other. File naming: `x.luau` = ModuleScript; `.server`, `.client`, `.legacy` and `.plugin.luau` = Script with that RunContext; `.local.luau` = LocalScript; `name/init.*.luau` = a script with children. Status can be checked with `InstanceFileSyncService:GetStatus(instance)`. Studio must be open. | CD:scripting/sync; CD:ai/coding-harness | 2026-10-10 | high | O |
| S4 | **Rojo 7.7.1** was released 2026-10-01. 7.7.0 (2026-07-01) added hardening, including DNS-rebinding protection on `rojo serve`. **`rojo syncback`**, which pulls instances out of a `.rbxl` into the project and is controlled by `syncbackRules`, first appeared in 7.7.0-rc.1. Plugin↔server traffic now uses websockets. | rojo-rbx/rojo CHANGELOG.md (raw.githubusercontent.com) + `git ls-remote` tags | 2026-10-01 | high | O |
| S5 | Roblox's docs: use Script Sync if you only need code in an external editor or Git; use third-party tools such as Rojo for a whole project as files with the filesystem as the source of truth. They recommend Rokit for pinning versions. | CD:scripting/sync; CD:projects/external-tools | 2026-10-10 | high | O |
| S6 | **Argon** latest tag is 2.0.29, last commit 2026-05-18. It advertises two-way sync of code and instances with properties, builds and CI. | argon-rbx/argon (git, README) | 2026-05-18 | high | O |
| S7 | **Studio MCP server (built into Studio).** It connects any stdio MCP client; Claude Code and Codex CLI are on the quick-connect list. Tools include `execute_luau` (Edit/Client/Server), `start_stop_play`, `get_console_output`, `screen_capture`, keyboard/mouse/navigation simulation, `multi_edit`, `search_game_tree`, `insert_asset` and `generate_mesh`. Each call targets a `studio_id`. It needs a running Studio on Windows or macOS. | CD:studio/mcp | 2026-10-10 | high | O |

**Recommendation (I).**
- I-S1. **Keep Rojo 7.7.1 as the single source of truth** (D-005). Workers edit files on their own branches and CI runs `rojo build` headlessly. Nobody syncs the same tree with Script Sync, because the naming conventions and ownership models differ, and S2 risks attribute and tag loss.
- I-S2. Use Studio only to check the built place: open it with the Rojo plugin, and drive playtests and screenshots through **Studio MCP** (S7) on the user's Windows or Mac machine. That produces the screenshot evidence AGENTS.md requires.
- I-S3. For Studio-authored instances (terrain, CSG, SurfaceAppearance, lighting), pull them back into Git with `rojo syncback` (S4) using explicit `syncbackRules`. Review the diffs like code. This is unverified in our project, so create a task to prove it on `games/sandbox`.
- I-S4. Argon is a viable fallback but adds no capability we need. Don't run two sync tools.

## 6. Open Cloud automation

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| O1 | **Place publishing.** `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Saved\|Published` with a `.rbxl` (octet-stream) or `.rbxlx` (xml) body. Scope `universe-places:write`. Stability **BETA**. Size limit 10,485,760 bytes. It returns `{versionNumber}`. Rate limit: **not found**. | OA:place-pub; CD:cloud/guides/usage-place-publishing | 2026-10-10 | high | O |
| O2 | **Place publishing "doesn't update"** `EditableImage`, `EditableMesh`, `PartOperation`, `SurfaceAppearance` or `BaseWrap`; Roblox says to publish from Studio after modifying them. | CD:usage-place-publishing | 2026-10-10 | high | O |
| O3 | **Assets API.** `POST /assets/v1/assets` (BETA, 120 req/min per API-key owner; scopes `asset:read` and `asset:write`). Long-running operations are polled with `GET /assets/v1/operations/{id}` (300/min). One asset per call, **up to 20 MB**. | OA; CD:cloud/guides/usage-assets | 2026-10-10 | high | O |
| O4 | **Assets API types.** <br>• **Model:** `.fbx`, `.gltf`, `.glb`, `.rbxm(x)`. It creates a Model of MeshParts and is **uploaded as a package**. <br>• **Image or Decal:** png, jpeg, bmp or tga, under 8000×8000, and not updatable. <br>• **Audio:** mp3, ogg, wav or flac, up to 7 min. The page says 100 per month when ID-verified and 10 when not, and it isn't updatable. <br>• **Animation:** `.rbxm(x)`. <br>• **Mesh:** only content re-uploaded from Asset Delivery. <br>• **Video:** mp4 or mov, up to 5 min, 4096×2160 and 3.75 GB; 20 per day for 13+ ID-verified accounts. <br>Only `.fbx` content can be updated in place, which creates a new version. | CD:usage-assets | 2026-10-10 | high | O |
| O5 | **Luau Execution API (STABLE).** Run Luau in a specific place, or place version, in the real engine. <br>• Create a task: 5 requests/min per API-key owner, scope `universe.place.luau-execution-session:write`. <br>• Get a task: 200/min. Logs: 45/min. | OA | 2026-10-10 | high | O |
| O6 | **Luau Execution limits.** <br>• Script up to 4 MB, run time up to **5 min** (the default timeout). <br>• Return values are JSON, up to 4 MB in total; logs are capped at 450 KB, with the oldest dropped. <br>• Task data is kept for 24 h. **At most 10 incomplete tasks per place**; more gives HTTP 429. <br>• Optional binary input up to 100 MiB, valid 15 min; binary output up to 256 MiB. <br>• **No physics runs, and the place's server and local scripts don't run automatically.** Changes to the data model aren't persisted, but **cloud-backed APIs such as DataStores really write**. | OA (schema `LuauExecutionSessionTask`) | 2026-10-10 | high | O |
| O7 | Roblox's own demo (`Roblox/place-ci-cd-demo`, last commit 2024-09-17) builds with Rojo, uploads to a **separate test place**, runs tests through Luau Execution, then deploys. Its README says a limit of "two concurrent request per universe". That figure is older than and conflicts with O6, which allows 10 incomplete tasks per place. | raw.githubusercontent.com Roblox/place-ci-cd-demo README | 2024-09-17 | med | O |
| O8 | **DataStores v2 and MemoryStore Open Cloud endpoints are STABLE.** DataStore calls share the experience budget (D4). MemoryStore quotas: memory 64 KB + 1.2 KB × users; request units 1000 + 120 × CCU per minute; values up to 32 KB; default expiry 45 days; up to 1,000,000 items or 100 MB per structure. | OA; CD:cloud-services/memory-stores (index, sorted-map, hash-map) | 2026-10-10 | high | O |
| O9 | **API keys.** Rate limits apply per **owner** (user or group) across all of that owner's keys. A key expires automatically after **60 days unused**. Keys can be restricted to CIDR IP ranges (but not when the key is used inside Roblox places), and expiry dates are optional. A key reaches everything its account can, so Roblox recommends a **dedicated alt account** for group automation. Handle HTTP 429 with `retry-after` or backoff. | CD:cloud/auth/api-keys; CD:cloud/reference/rate-limits | 2026-10-10 | high | O |
| O10 | **Cost.** No price for Open Cloud API usage was found in the docs (**not found**). Extended Services is a **paid** program for DataStore, MemoryStore and compute usage beyond the default quotas. | CD:cloud-services/extended-services | 2026-10-10 | high | O |
| O11 | **Rate-limit change.** After 2026-10-19, cookie-authenticated and unauthenticated web-API rate limits are cut (some from 10,000 to 100 per minute). Open Cloud limits are not affected. | DevForum "[API Update] API Rate Limit Tuning" (t/4906160) snippet; talkesport.com | 2026-10 | med | O |

**Implications (I).**
- I-O1. Automate only through Open Cloud API keys, never cookies (O11, and AGENTS.md).
- I-O2. Use one key per purpose, owned by a dedicated automation account, with the narrowest scopes: `universe-places:write`, `universe.place.luau-execution-session:write`, `asset:read`/`asset:write`, and `universe.analytics:read`. Store keys in GitHub Actions secrets.
- I-O3. O2 is a real constraint for the Blender pipeline. Anything that needs `SurfaceAppearance` (PBR) or CSG can't be refreshed by publishing a Rojo-built place through the API. Options: (a) use `MeshPart.TextureID` plus vertex colors and MaterialVariants for API-published content; (b) keep PBR models as packages updated from Studio or the Assets API, inserted by ID. This needs a spike: test whether a `SurfaceAppearance` already in a package survives an API place publish.
- I-O4. Use Assets API model uploads for FBX meshes. Upload each unique mesh **once**, store the returned asset ID in the manifest, and reuse it, which also enables instancing (A7).

## 7. Mesh import and performance

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| A1 | **Each mesh is limited to 20,000 triangles.** Solid-modeling results are simplified to 20,000, and models in the Creator Store need every mesh at 20,000 or fewer. The DevForum feature request to raise it is open, with no staff change found. | CD:art/modeling/specifications; CD:parts/solid-modeling; CD:parts/models; DevForum t/4650221 snippet | 2026-10-10 | high | O |
| A2 | **Geometry rules.** Watertight, quads where possible (no n-gons), not zero-thickness. At most 4 bone influences per vertex. One animation track per FBX. Cages are named `_InnerCage` / `_OuterCage`. | CD:art/modeling/specifications | 2026-10-10 | high | O |
| A3 | **Importer formats.** `.fbx`, `.obj` and `.gltf`. FBX and glTF support hierarchies, basic and PBR textures, cages, rigs, animation and **vertex colors**; OBJ is not listed with those. The Importer has an **Ignore Vertex Colors** toggle and **Merge Meshes**. The Assets API also accepts `.glb` (O4). | CD:studio/importer | 2026-10-10 | high | O |
| A4 | **Units.** The Importer's "Scale Unit" defaults to **Studs**; the full list of options is **not found**. Roblox's Blender guide sets Unit System to **None** (1 Blender unit = 1 stud), uses FBX "Apply Scalings: FBX Unit Scale" (or Scale 0.01), and imports with Scale Unit = Stud. Forward and up axes are set in the Importer (World Forward/Up). The physics conversion is **1 stud = 28 cm**, though "you're free to define your own" interpretation. | CD:studio/importer; CD:art/blender; CD:art/modeling/export-requirements; CD:physics/units | 2026-10-10 | high | O |
| A5 | **Textures.** Up to 4096×4096. Suggested sizes: 256² for a 5×5-stud object, 512² for 10×10, 1024² for 20×20. For images in general: most minor images under 256², and 512² at most unless the image takes up a large area of the screen. GPU memory depends on pixel count, not file size. One material per mesh. PBR uses `SurfaceAppearance` with up to 5 maps (color, normal, roughness, metalness, emissive); normal maps must be **OpenGL tangent-space**. Scripts generally can't change SurfaceAppearance properties at runtime. | CD:art/modeling/texture-specifications; CD:performance-optimization/improve; CD:art/modeling/surface-appearance | 2026-10-10 | high | O |
| A6 | **`RenderFidelity`.** `Automatic` (the default) uses highest detail under 250 studs, medium at 250–500, and lowest at 500+. `Precise` on many meshes is a known performance problem. **`CollisionFidelity`** options: Box, Hull, Default, PreciseConvexDecomposition, and Tunable (with a `CollisionPrecision` slider). Box uses the least memory; Default and Precise cost more. | CD:parts/meshes; CD:performance-optimization/improve | 2026-10-10 | high | O |
| A7 | **Draw calls.** Meshes with the same `MeshContent` are **instanced into one draw call** when their SurfaceAppearances are identical, or their TextureContent when there is no SurfaceAppearance, or their materials when they have neither. Importing a whole scene at once creates duplicate asset IDs, because the Importer doesn't deduplicate. Decals, textures and particles batch poorly. | CD:performance-optimization/improve | 2026-10-10 | high | O |
| A8 | **Devices.** Android is about 65% of a typical game's players; about 60% of those devices have 2–4 GB of RAM, and over 50% of all players are on devices scoring 10,000–20,000 on Passmark. The docs give an *example* budget of "below 1,000 draw calls and 1,000,000 triangles" for one baseline device. That is an illustration, **not an official limit**. Studio's device emulator doesn't measure memory accurately. | CD:performance-optimization/test-on-hardware; CD:performance-optimization/design | 2026-10-10 | high | O |
| A9 | **StreamingEnabled** is on by default for new places and can't be set from a script. Recommended settings: `ModelStreamingBehavior = Improved`, `StreamingMinRadius` 64 (the default), `StreamingTargetRadius` 1024 (the default), `StreamOutBehavior = Opportunistic`. `Model.LevelOfDetail = SLIM` gives distant models a lighter version. | CD:workspace/streaming; CD:performance-optimization/improve | 2026-10-10 | high | O |

**Implications (I).**
- I-A1. Blender validation gates: 20k triangles or fewer per mesh (hard fail); a lower per-asset budget set per game; a single material; textures sized by the A5 rule; vertex colors preferred for stylised art (cheaper memory, no UV textures); export as FBX with Unit System None and FBX Unit Scale.
- I-A2. Reuse beats triangle count: keep a manifest of mesh asset IDs (I-O4) and set `CollisionFidelity = Box` or `Hull` by default.
- I-A3. Pick a baseline Android device with 2–4 GB of RAM and record its draw-call and memory numbers (A8). Only on-device tests count as performance evidence.

## 8. AnalyticsService and Creator Dashboard

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| N1 | **Current methods.** `LogEconomyEvent`, `LogFunnelStepEvent`, `LogOnboardingFunnelStepEvent`, `LogCustomEvent`, `LogProgressionEvent`, `LogProgressionStartEvent`, `LogProgressionCompleteEvent`, `LogProgressionFailEvent`, `LogJourneyEvent` (non-linear paths, shown as a Sankey diagram) and `GetPlayerSegmentsAsync`. The `Fire*` methods are deprecated. | REF:AnalyticsService | 2026-10-10 | high | O |
| N2 | **Progression events "do not currently display in any Roblox-provided charts."** | REF:AnalyticsService | 2026-10-10 | high | O |
| N3 | **Limits** (reset daily): <br>• All `AnalyticsService` requests: 120 + 20 × CCU per minute. <br>• Custom fields: 3, with values beyond 8,000 combined grouped as "Other". <br>• Economy: 10 resource types; transactionTypes beyond 20 and itemSkus beyond 100 grouped as "Other". <br>• Funnels: 10, with up to 100 steps each. <br>• Custom events: 100 event names. <br>Data rolls off 90 days after it was last received, and charts take about 24 h to appear. | CD:production/analytics/event-types; custom-events; funnel-events | 2026-10-10 | high | O |
| N4 | **Dashboard metrics.** Retention D1, D7 and D30 (cohort definitions), average session time, new-user first-session retention, payer conversion rate, ARPPU and ARPDAU. | CD:production/analytics (retention, engagement, monetization) | 2026-10-10 | high | O |
| N5 | **Exports.** <br>• Per-chart CSV export, needing data for at least 48 h. <br>• Custom dashboards: "Download CSV". <br>• Monthly sales-data CSV: requested in the dashboard, delivered by email as a link valid for 48 h, regenerated every 48 h, covering up to 2 years back. | CD:production/analytics/analytics-dashboard; custom-dashboards | 2026-10-10 | high | O |
| N6 | **Analytics Query API (BETA).** `POST /analytics-query-api/v1/universes/{id}/metrics`, 30 requests/min, scope `universe.analytics:read`; slow queries become long-running operations. Example metrics: `ForwardD1Retention`, `ForwardD7Retention`, `ForwardD30Retention`, `AverageSessionLengthMinutes`, `DailyActiveUsers`, `PayingUsersCVR`, `AverageRevenuePerPayingUser`, `DailyRevenue`, `Funnel*`, `Economy*`, `CustomEvent*`, `ClientFps*`, `ClientCrashRate15m` and `DataStore*`. Data is kept for 1468 days. An alerts API also exists (EXPERIMENTAL). | CD:cloud/guides/analytics (index, metrics); OA | 2026-10-10 | high | O |

**Implications (I).**
- I-N1. Track progression with **funnel events**, because progression events aren't charted (N2). Encode variants as custom fields, not event names (N3).
- I-N2. Batch high-frequency events into valued custom events to stay under the global limit.
- I-N3. `analytics/` can pull KPIs automatically through N6. No scraping is needed.

## 9. Headless engine and CI

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| H1 | **Open Cloud Luau Execution** is the only official cloud runner for the real engine. See O5–O7 for limits; it has no physics and doesn't auto-run scripts. | OA | 2026-10-10 | high | O |
| H2 | **Studio command line** (Windows and macOS executables): `--task RunScript --runScriptFile <abs path> [--placeId --universeId \| --localPlaceFile] [--outputFile] [--quitAfterExecution]`. It runs at command-bar permission and writes verbose logs to stdout. There is also `--api`/`--fullApi`/`--apiV2 <path>` for API dumps. Undocumented arguments are internal. | CD:studio/command-line-interface | 2026-10-10 | high | O |
| H3 | **run-in-roblox.** The last release is v0.3.0 and the last commit was 2020-07-19. | rojo-rbx/run-in-roblox (git) | 2020-07-19 | high | O |
| H4 | We found no officially supported way to run Studio on a Linux machine with no display. | — | — | med | I |

**Implications (I).**
- I-H1. CI has three tiers: (1) Lune unit tests with Selene, StyLua and `rojo build`, run headlessly on Linux on every PR; (2) engine tests through Luau Execution against a **separate test universe**, run nightly or on PRs into `main` (the integrated build, D-011) with one task per run; (3) Studio playtests through MCP or the Studio CLI on the user's machine. H3 is unmaintained, so don't adopt it.
- I-H2. O6 rules apply to tier 2: no physics, and DataStores are real. Tests must call module APIs directly and must not touch production DataStores. That is the reason for a separate universe: DataStores are per-universe (I).

## 10. Audio

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| U1 | **Import rules.** You must have the legal rights and follow the Community Rules and ToS. One track, in mp3, ogg, wav or flac, **under 20 MB and under 7 minutes**, at most 48 kHz, mono/stereo/3.0/5.1. Uploads are moderated. | CD:audio/assets | 2026-10-10 | high | O |
| U2 | **Upload quota on the audio page:** ID-verified accounts get **2,000 free imports per 30 days**, unverified accounts 100; this replaces any earlier daily limit. **This conflicts with the Assets API page**, which says 100 per month verified and 10 unverified (O4). | CD:audio/assets vs CD:cloud/guides/usage-assets | 2026-10-10 | high (that the conflict exists) | O |
| U3 | **Creator Store audio** is "free-to-use … for creators to use within their games", including more than 100,000 professionally produced sound effects and music tracks from partners. | CD:audio/assets | 2026-10-10 | high | O |
| U4 | **Privacy.** Uploaded audio is private by default; usage can be granted to specific friends or games through asset privacy. Uploads are classified as sound effect or song. Sound effects can be distributed on the Creator Store. A song appears on the game page only if it passes moderation and copyright checks and meets minimum duration and play requirements, the uploader is ID-verified, and the Audio Upload License Agreement is acknowledged. | CD:audio/assets; CD:projects/assets/privacy | 2026-10-10 | high | O |
| U5 | You can't sell or distribute composite models containing Restricted assets you didn't create, **except** audio and video that are also on the Creator Store. | CD:production/creator-store | 2026-10-10 | high | O |
| U6 | **Use outside Roblox** (trailers, store videos) of Creator Store or licensed audio: **not found**. The Help Center says licensed (APM) music is for use on the Roblox platform only. | WebSearch snippet of en.help.roblox.com/hc/articles/360000927163 | unknown | med | O |

**Implications (I).**
- I-U1. Default to self-made or generated SFX that we hold the rights to, plus Creator Store audio used **in game only**. Record the source and asset ID of every sound in the asset manifest.
- I-U2. Don't use Creator Store or licensed tracks in marketing videos until the licence is confirmed.

---

## Decision-relevant summary

1. **Paid random items are a compliance feature, not just UI.** They require exact odds that sum to 100%, labelled pop-ups, live updates when boosters are active, a server gate on `ArePaidRandomItemsRestricted` (we'd fail closed), one of six alternative treatments, a trading gate, and a questionnaire answer (P1–P15). Recommendation: keep Game #1's random rolls on non-purchasable soft currency unless the user approves paid randomness (I-P1).
2. **Purchases follow the official recipe.** Keep a `PurchaseId` ledger inside session-locked player data and return granted only after a confirmed save. Adopt `BindReceiptHandler` with a `ProcessReceipt` fallback. Callbacks can run on two servers and only retry on purchase or rejoin (M3, M4, M6, M8).
3. **Player data.** Use one key per player, `UpdateAsync` only (it can re-run, can't yield, and clears metadata if not returned), a `LockId` stored in metadata, a 180 s jittered autosave, and a parallel save within the 30 s `BindToClose` window. Budgets: 60 + 40×players per server and 300 + 40/20×CCU per experience, and Open Cloud shares the experience budget (D4–D11).
4. **D-004 is correct.** The engine's `./`, `../`, `@self/` and `@game/` match standalone Luau's init semantics. Aliases aren't available in the engine (not found). `require` doesn't wait for modules. The new type solver is the default in non-strict modes (med).
5. **Rojo 7.7.1 stays the backbone.** Script Sync is still beta, scripts-only, and loses attributes and tags. Use `rojo syncback` for Studio-authored instances and Studio MCP (with `execute_luau`, play mode and screenshots) for agent playtests on the user's machine (S1–S7).
6. **The Place Publishing API is BETA, 10 MB, and won't update SurfaceAppearance, PartOperation, EditableMesh, EditableImage or BaseWrap** (O1, O2). The art pipeline must either avoid PBR in API-published places or ship PBR as Studio-updated packages. This needs a spike before FORGE-02 commits to a material workflow.
7. **Assets API.** FBX, glTF or GLB model uploads up to 20 MB at 120/min, created as packages; only FBX content is updatable. Upload each mesh once and reuse the asset ID; this is both a quota rule and the instancing rule (O3, O4, A7).
8. **Real-engine CI exists.** The Luau Execution API is STABLE: 5 task creations per minute per key owner, 10 or fewer pending per place, 5 minutes, no physics, and live DataStores. Run it against a separate test universe. Lune stays the PR gate. run-in-roblox is dead (2020) (O5–O7, H1–H3).
9. **Art budget.** 20k triangles per mesh is the hard cap. Textures go up to 4K but are sized by object size. Prefer vertex colors or one material. Use Box or Hull collisions, StreamingEnabled with Opportunistic stream-out, and an Android device with 2–4 GB as the baseline (most players). The 1,000 draw calls / 1M triangles figure is only an example (A1–A9).
10. **Analytics.** Use funnel, economy and custom events; progression events aren't charted. Limits: 120 + 20×CCU requests per minute, 3 custom fields, 10 funnels, 100 custom event names, 10 currencies. The Analytics Query API (BETA, 30/min) returns D1/D7/D30, session length, conversion and ARPPU programmatically (N1–N6).

## Open questions needing the user's account

1. **Ownership and verification.** Will games be owned by a **group** or a personal account? Is the owner ID-verified, 13+ or 18+? This decides the audio quota (U2), local-currency subscriptions (M14), video uploads (O4) and eligibility for Extended Services (D7).
2. **Automation account and keys.** Will you create a dedicated alt account for Open Cloud keys (O9), with the scopes in I-O2 on a **test universe** plus the production universe? Keys go only into GitHub Actions secrets.
3. **Test universe.** Please create a separate test experience and place (for Luau Execution tests and API publishes) and share the universe and place IDs. Do you want the place's API save access enabled? (`SavePlaceAsync` requires it.)
4. **A Studio machine.** Is there a Windows or macOS machine with Studio where we can enable the Studio MCP server and, optionally, Script Sync? Can it act as a self-hosted runner for `RobloxStudio --task RunScript` (H2)? Studio login and display requirements in that mode are unverified.
5. **Conflicting numbers to check in Creator Hub.** <br>• Audio upload quota: 2,000 or 100 per 30 days (U2). <br>• Game pass minimum and maximum price, not found in the docs (M16). <br>• Whether any Open Cloud usage appears under Finances → Billing (O10). <br>• Whether Script Sync still sits under Beta Features (S1). <br>• Whether the Luau Execution concurrency limit is 10 pending tasks per place (O6) or the demo's 2 per universe (O7).
6. **Monetisation approval gate.** Are paid random items allowed at all for Game #1, and is in-game trading of paid items planned? Each needs the P11/P12 work plus a questionnaire update.
7. **Marketing audio.** Will trailers or store videos use in-game music? If yes, we need a licence for use off the platform (U6).
