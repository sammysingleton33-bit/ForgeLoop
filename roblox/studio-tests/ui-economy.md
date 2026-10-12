# Studio tests — UI & Economy (FORGE-03, gate G6)

Run by the user in Roblox Studio on the integrated game-001 build (`main`; open the place built
from `games/game-001/default.project.json`). Quote the BuildInfo sha in every report. Headless
checks (`check.sh`, the Lune specs and the renders in `games/game-001/design/ui/screenshots/`) are
**not** Studio evidence; these steps are.

## Prerequisites (check first — skip the tests whose prerequisite is missing)
| # | Prerequisite | Needed for |
|---|---|---|
| P1 | FORGE-03 PRs FL-0058 (Treasury), FL-0020 (UI kit) and FL-0059 (HUD, build menu) merged | all |
| P2 | FORGE-01's `Kingdom`, `Match` and `Build` remotes and services merged (CONTRACTS G8) | U2–U9 |
| P3 | FORGE-04's InputModeController merged (G4.1; G13.6 `selected` for U10–U11) | U5 build-mode camera/taps, U10–U11 |
| P4 | Icons uploaded and their ids in `games/game-001/config/UITheme.luau` (`production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`) | U9 only; otherwise emoji fallbacks show |
| P5 | FORGE-01's army and objectives (FL-0052: `Army.Recruit`, `Army.Command`, `Army.Objectives` / `Army.GetObjectives`), `Match.Ended` and `Kingdom.Population` merged (CONTRACTS G8, G13.2) | U14 |

## U1 — the place boots with the kingdom UI (P1)
1. Play (F5). In Output, the client controllers list includes `KingdomHudController` and
   `BuildMenuController`, with no red errors from either.
2. Without P2, wait about 25 s: warnings like `KingdomHudController: cannot listen to
   Kingdom.State` arrive in two waves (around 15 s and 20 s, one per area each time), and there is
   **no** kingdom HUD (it stays hidden until you rule a kingdom). That is expected.

## U2 — kingdom, rulers, resources (P2)
1. Play. Top-left: a crest in your kingdom's colour, its name (e.g. Emberhold) and
   "Keep Lv 1 · 1 region · 0 Crown Points"; four pills Food / Wood / Stone / Gold with the starting
   stock; under them your name with "you" (and co-rulers with Test → Clients and Servers, 2 players).
2. Top bar: the phase ("FOUNDING") and the match time.
3. Tap the Food pill: a card explains Food. Gather a tree: the Wood pill rises with a green "+N".

## U3 — build menu and costs (P2)
1. Click **Build** (right edge). The drawer opens on Economy with each building's cost.
2. Click **Farm**: the detail shows "Economy · 34 × 28 studs", the build time and Wood 50 against
   what you have (✓). The button reads **Place Farm**.
3. Military → **Barracks** while short: the button is greyed and reads "Need … Wood and … Stone".

## U4 — place a building, desktop (P2)
1. **Place Farm**. The drawer closes; a translucent footprint follows the mouse with an arrow on
   its front; a bar at the bottom shows Farm, its cost, "✓ Good spot", Rotate / Cancel / Place and
   the hint "R rotates · Click places · Q cancels".
2. Move outside your land: the footprint turns red and the bar says why ("Outside your territory").
   Clicking does nothing.
3. Press **R**: the footprint turns 90°. Back on your land, click: within a second the footprint
   disappears, a toast says "Farm placed — Builders are on their way", a red "−50" floats under
   Wood, and a "Farm · waiting" chip appears at the bottom; it fills as builders work.
4. Place again and press **Q**: build mode ends, nothing is spent.

## U5 — place a building, phone (P2; P3 for camera/taps)
1. **Test → Device emulator** → an iPhone in **landscape** (e.g. iPhone 14, 844 × 390).
2. Expected HUD: crest with Crown Points on it, compact pills to its right, rail buttons without
   labels, phase and time inside the Roblox top bar; nothing under the notch.
3. Build → tap **Farm** (one pane; "‹ Economy" goes back) → **Place Farm**. Tap the ground: the
   footprint moves there. Tap **Place** to build; the ⟳ button rotates; ✕ cancels. A tap on the
   ground never builds by itself.
4. Screenshot the HUD, the build detail and the placement bar.

## U6 — tablet and desktop layout (P2)
1. Device emulator: an iPad in landscape (1024 × 768), then off at 1920 × 1080.
2. Expected: drawer with list and detail side by side to the right; desktop scaled up (~1.2×).
   Screenshot both with the Build drawer open.

## U7 — Kingdom panel and keep upgrade (P2)
1. Click **Kingdom** → Overview: rulers (you marked) and the standings of the four kingdoms by
   Crown Points (yours highlighted, AI kingdoms marked "AI").
2. Buildings tab → **Upgrade** on the Keep → "Upgrade to Lv 2" with its costs. With exactly enough
   resources a confirmation appears first. Confirm → toast "Keep upgrade started", the stock drops,
   a "Keep Lv 2" chip appears; when built, the plate reads "Keep Lv 2".

## U8 — two rulers (P2)
1. Test → Clients and Servers with 2 players in one party (Party Simulator). Both see the same
   kingdom, both names under the pills; a Farm placed by one lowers the Wood pill of both.

## U10 — build on a plot (P2 + FORGE-01 plots and FORGE-04 selection, FL-0087)
1. In the aerial view tap a free **plot**. The drawer opens titled "Build here" with one tab naming
   its size (e.g. "Medium plot") and only the structures that fit it, each with its cost.
2. Pick one: cost against your stock, "0:25 with builders", and a "Gives" line. Tap **Build … here**:
   a toast "… ordered — Builders are on their way", the drawer closes, the spend floats under the
   pills and a construction chip appears. The plot now shows the building rising.
3. Tap a plot you cannot afford anything for: greyed buttons say what is missing ("Need 20 Wood …").

## U11 — upgrade a building (P2 + FORGE-04 selection, FL-0087)
1. Tap your Barracks: the drawer shows "Barracks · Lv 1", the level-2 cost, "0:18 with builders",
   **Now:** Recruit up to 5 soldiers and **Lv 2:** Recruit up to 10 (green). On a phone only the Lv 2
   line shows, under the costs.
2. Tap **Upgrade to Lv 2** (a confirmation appears if it costs half or more of a resource): toast
   "Barracks upgrade started"; the chip reads "Barracks Lv 2".
3. Tap another kingdom's building: a read-only card "Frostmere · Level 2 — Not your building".
4. Tap empty ground: the drawer closes.

## U12 — reputation (P2 + FORGE-01 `Kingdom.Reputation`/`GetReputation`, FL-0089)
1. Play as a ruler. Under the rulers row (tablet/desktop) or under the crest (phone) a strip shows six
   values, each with an icon, a **number** and a bar (Compassion, Honor, Competence, Courage,
   Authority, Fear). Without FORGE-01's reputation remotes the strip stays hidden and Output shows a
   warning: expected.
2. Open the Build drawer on a tablet or desktop: it starts below the strip and covers none of it.
3. Tap the strip: the Reputation screen opens. Tap a value: its number, Low/Medium/High word and recent
   changes (the About text appears only once FORGE-00's content library is in). On a phone: the grid,
   then the detail with "‹ Reputation" back.
4. Take a decision that changes reputation (a citizen conversation, FL-0088): the bar moves and a
   "+N"/"−N" chip floats on that value; History shows the line on top, "just now".
5. Kingdom tab: Happiness, Stability, Morale, each with a bar, a number and a word.
6. While the screen is open, let production tick: the screen does not flicker or lose its scroll.

## U13 — citizen card and a conversation (P2 + FORGE-01 `Sim.Inspect`, `Kingdom.Converse/Choose`, FORGE-04 selection, FL-0088)
1. Tap one of your citizens: the drawer (phone: the right-hand panel) shows the name, occupation,
   Loyalty / Mood / Obedience each with a bar **and a number**, what they are doing now, traits,
   family and friends. A citizen with something to say has a "!" on the portrait and a gold **Talk**.
2. Tap **Talk**: the question and 2–4 answers appear (phone 844 × 390: all four visible without
   scrolling; a very long question shows a "scroll for all" cue). Every word comes from the server:
   nothing in English is built into the client.
3. Tap an answer: all answers grey out at once; then the reaction and the "What changed" chips
   (resources, loyalty, reputation). The pills and the reputation strip move to match. **Done** closes.
4. Tap the same answer twice quickly, or tap during a resource tick: only one answer is sent, and the
   panel does not flicker or lose the tap.
5. Tap empty ground or enter build mode while the card or conversation is open: it closes.

## U14 — army, objectives and the slice summary (P2 + P5; FORGE-04 selection for step 6; FL-0060)
Phone first (844 × 390 landscape), then tablet and desktop. Screenshots: the army drawer and the
tracker on the phone, the summary on the phone and on desktop.
1. HUD: under the reputation strip, the objective tracker reads "Watchtower" with a "Neutral" chip and
   "Send soldiers to capture it". It covers neither the pills, the strip nor the rail, which now has a
   third button, **Army** (crossed swords).
2. Tap **Army**: the drawer shows your soldier count (the same number as the Kingdom/jobs panel),
   tabs "Barracks · Lv N" and "Army" once you have a barracks, the recruit block and **Send to
   capture**. Without a barracks: "Build a Barracks to recruit soldiers"; Send still works.
3. Recruit: − / + change the count from 1 to 10; Food and Wood are the cost × count against what you
   have. Short → the button reads "Need N Food" and does nothing. Tap **Recruit 3 soldiers**: the button
   shows "Recruiting…", then a toast "3 soldiers recruited", the Food and Wood pills drop, and the count
   rises when the server says so (soldiers appear at the barracks). Tap it twice quickly: one recruit.
4. Tap **Send to capture**: a toast "Soldiers sent", the button reads "Sent" for about 3 s (taps are
   ignored), and the idle soldiers march to the nearest tower you don't hold. With 0 soldiers the button
   reads "No soldiers yet".
5. While they capture: the tracker shows a bar "You" with a rising percentage (gold text); another
   kingdom contesting gets its own bar with its name and percentage. The bars move without the HUD
   flickering, and an open army drawer keeps the button under your finger. Tap the tracker: it expands
   (all objectives and bars) and collapses again.
6. Tap your barracks in the world: its upgrade panel has an **Army** tab → the army drawer for that
   barracks; its "Barracks" tab goes back. Another kingdom's barracks and your keep have no Army tab.
   Tapping empty ground closes the army drawer.
7. The first capture ends the slice: the screen dims (notch strips too) and a centred summary shows
   "Victory" + your kingdom (or "Match over" + the winner, or "No winner"), "Lasted m:ss" and the
   standings with Crown Points: you highlighted with a "you" tag, AI kingdoms tagged "AI", the winner
   with a crown. Tapping the dimmed area does nothing; **Continue** closes it. Phone: the panel sits
   clear of the notch, the Roblox top bar and the home bar.
8. Report: whether the soldier count, the bars and the summary always matched what happened in the
   world (the client shows only what the server sends).

## U9 — icons (P4)
1. Pills, crest emblem, rail buttons and building tiles show the uploaded icons (no emoji).

## Report
Per test: pass/fail, BuildInfo sha, device/emulator, screenshots for U5/U6 and U12, any Output errors.
