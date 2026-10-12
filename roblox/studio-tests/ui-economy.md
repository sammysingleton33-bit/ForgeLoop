# Studio tests — UI & Economy (FORGE-03, gate G6)

> **Not runnable yet (2026-10-12).** The pre-contract framework kingdom UI these steps describe was
> removed. The kingdom HUD and build menu are being rebuilt in `games/game-001` against CONTRACTS G8
> (FL-0059); this file is rewritten with that PR. Do not run U1–U8 below until then.

Run by the user in Roblox Studio on the integrated build (`main`), setup as in
`roblox/STUDIO_TEST_PLAN.md`. Quote the BuildInfo sha in every report. Headless checks
(`check.sh`, the Lune specs and the snapshot screenshots in `design/ui/screenshots/`) are **not**
Studio evidence; these steps are.

## Prerequisites (check first — skip the tests whose prerequisite is missing)
| # | Prerequisite | Needed for |
|---|---|---|
| P1 | Skeleton (FL-0003) and FORGE-03's AI Kingdoms PRs merged into `main` | all |
| P2 | FORGE-01's RemoteService, Core/RemoteClient and KingdomService/KingdomController merged (API: `production/handoffs/2026-10-12-forge-03-to-forge-01-kingdom-api.md`) | U2–U7 |
| P3 | Icons uploaded and their ids in `games/sandbox/config/UITheme.luau` (`production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`) | U8 only; otherwise glyph fallbacks show |
| P4 | Products/passes published (FL-0019; needs your approval) | purchase tests, later |

## U1 — the place boots with the UI controller (P1)
1. Play (F5). In Output find `ForgeLoop client controllers started ... order=... UIController`.
2. Without P2 you should also see `UIController: no KingdomController yet` and **no** kingdom HUD on
   screen (it stays hidden until you own a kingdom). Pass = no red errors from `UIController`.

## U2 — resources and kingdom information (P2)
1. Play. Top-left: crest, kingdom name + "Town Hall Lv 1 · N tiles", pills for Food, Wood, Stone,
   Gold (amount / cap, +rate/min) and Citizens (total / housed, idle).
2. The values match the server (Output or the developer console `Economy.Treasury` payloads).

## U3 — build a building end to end (P2)
1. Click **Build** (right edge). The Construction drawer opens on Economy.
2. Click **Quarry**. The detail shows its cost per resource with what you have (✓ or "have N"),
   build time, workers and +stone/min.
3. Click **Build Quarry**. Expected within a second: the button turns green "Construction started",
   "Paid 20 Food · 50 Wood" with a progress bar, red "−50"/"−20" float under the Wood/Food pills,
   a toast "Quarry construction started", a Quarry chip at the bottom with a countdown.
4. After the build time the chip disappears and the Kingdom → Buildings tab shows Quarry Lv 1.
5. Spend down Wood and select Farm: the button reads "Need N more Wood" and does nothing when clicked.

## U4 — phone layout (P2)
1. **Test → Device emulator** (toolbar) → choose an iPhone in **landscape** (e.g. iPhone 14, 844×390).
2. Expected: compact pills to the right of the crest, a population chip under the crest, rail
   buttons without labels, the timer inside the Roblox top bar. Open **Build**: one pane (list);
   tapping a row shows its detail with "‹ Economy"; the Build button stays visible at the bottom.
3. Nothing sits under the notch or the Roblox top-bar buttons. Every button is easy to tap.
4. Screenshot the HUD, the list and the detail (attach to the report).

## U5 — tablet and desktop layout (P2)
1. Device emulator: an iPad in landscape (1024×768), then turn the emulator off at 1920×1080.
2. Expected: the drawer shows list and detail side by side; desktop is scaled up (≈1.2×) and stays
   inside the right half of the screen. Screenshot both.

## U6 — kingdom panel, workers, upgrade confirmation (P2)
1. Click **Kingdom** → Overview: citizens bar (working / building / idle) and production per resource.
2. Buildings tab → use **+ / −** on a Farm: the worker count changes and Food/min follows.
3. With enough resources, **Upgrade** the Town Hall: a confirmation appears (large spend); confirm →
   toast "Town Hall upgrade started".

## U7 — match timer (P2 + FORGE-01 round remotes)
1. Start a round. The timer appears in the Roblox top bar, counting down "until the match ends".

## U8 — icons (P3)
1. Pills, rail buttons and building tiles show the uploaded icons (no emoji fallbacks).

## Report
Per test: pass/fail, BuildInfo sha, device/emulator, screenshots for U4/U5, and any Output errors.
