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
| P6 | The cinematic conversation set merged together (D-046, FL-0101): FORGE-01's #108 (Converse look/position, `Kingdom.EndConversation`), FORGE-04's #84 (camera) and FORGE-02's #85 (`Kit.portrait`) with FORGE-03's FL-0099 | U16 |

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
2. Move outside your land: the footprint turns red and the bar says why ("Build inside your kingdom").
   Clicking does nothing.
3. Press **R**: the footprint turns 90°. Back on your land, click: within a second the footprint
   disappears, a toast says "Farm placed — Builders are on their way", a red "−50" floats under
   Wood, and a "Farm · waiting" chip appears at the bottom; it fills as builders work.
4. Place again and press **Q**: build mode ends, nothing is spent.
5. Around the footprint a fainter outline shows the room the building keeps for its upgrades
   (largest level plus 2 studs). Move it towards a building or a tree: the ghost turns red with
   "Not enough room here" as the faint outline reaches them, not only when the slab does
   (#62: the server checks the largest level plus the gap). Rotate: the outline turns too.

## U5 — place a building, phone (P2; P3 for camera/taps)
1. **Test → Device emulator** → an iPhone in **landscape** (e.g. iPhone 14, 844 × 390).
2. Expected HUD: crest with Crown Points on it, compact pills to its right, rail buttons without
   labels, phase and time inside the Roblox top bar; nothing under the notch.
3. Build → tap **Farm** (one pane; "‹ Economy" goes back) → **Place Farm**. Tap the ground: the
   footprint moves there. Tap **Place** to build; the ⟳ button rotates; ✕ cancels. A tap on the
   ground never builds by itself.
4. Screenshot the HUD, the build detail and the placement bar.
5. Toasts (FORGE-04's NotificationController, placed by the HUD): with the Build drawer open, try
   to place something you can't afford, then something you can. The toasts appear under the
   pills, left of the drawer: the drawer's tabs and ✕ and the Build / Kingdom buttons stay
   tappable while they show. With the drawer closed they sit at the top, left of the rail.

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
2. Tap **Talk**: the question and 2–4 answers appear (phone 844 × 390: a 2-answer question is fully
   visible, costs and risks included; more answers may scroll, and then the kicker says "scroll for
   all N"). Every word comes from the server: nothing in English is built into the client.
3. **Before answering, check costs and every risk** (FORGE-05 M1; needs FORGE-01's options with
   `cost` / `risks`): an answer that costs something shows resource chips with the amounts; one the
   treasury can't pay has its short amount in red **and** "Need … <Resource>" in words and can't be
   tapped. Every risk of every answer is listed with its whole-percent chance ("40 %" + the server's
   sentence), none cut off or hidden. Compare with the scenario's preview on the server
   (`ContentQuery.choicePreview`): same cost, same number of risks, same chances.
4. Tap an answer with a cost or a risk (phone: the builder's "The kingdom needs walls…"): a confirm
   step shows that answer alone, whole, with its cost and every risk, and **Back** / **Choose**
   under it; nothing is spent yet. Back shows the answers again. A quick double tap on the answer
   only opens the step; it never chooses. An answer with neither is sent at once.
   Then Choose (or an answer with neither): all answers grey out at once; then the reaction and the "What changed" chips
   (resources, loyalty, reputation). The pills and the reputation strip move to match. **Done** closes.
5. Tap the same answer twice quickly, or tap during a resource tick: only one answer is sent, and the
   panel does not flicker or lose the tap. Gain the missing resource while the question is open: the
   disabled answer becomes tappable without the panel jumping.
6. Tap empty ground or enter build mode while the card or conversation is open: it closes. Tap Talk
   and open Build before the question arrives: Build stays open (no conversation pops up later).
7. Phone: the conversation sheet covers the reputation strip completely (no sliver above it); a
   notice during the conversation appears above the sheet, right of the pills, not over the answers.

## U16 — cinematic conversation (P2 + P6, FL-0099; FORGE-05 runs it under FL-0101)
1. Tap a citizen with a "!" and **Talk**: their portrait rises from the bottom left in about a third
   of a second, with their name and job on it; the question is in a parchment bubble beside it and
   the 2–4 answers below. **The portrait looks like the citizen in the world**: same skin, hair,
   clothes and tool (compare with the world rig the camera now frames).
2. **The world stays visible**: only a light darkening at the bottom (never more than a fifth), no
   full-screen cover. The camera glides to the citizen (FORGE-04) and the citizen stays visible
   above the stage, not under the portrait or the answers (also on the phone emulator).
3. Answers show their costs (resource chips; red and "Need …" when the treasury is short) and each
   risk as a chip with its chance ("⚠ 20 %"). An answer with a cost or a risk opens the confirm step
   with every risk written out in full; Back returns. Phone 844 × 390: four answers in two rows of
   two, nothing overlapping, the close button never covering an answer.
4. Choose an answer: the citizen's reaction in the bubble, "WHAT CHANGED" chips, and **Done** with a
   bar running down; after about 6–12 s the stage closes by itself (Done closes it sooner). The camera
   returns to where it was. The pills and the reputation strip show the change.
5. Open a conversation and close it **without answering** (the X, tapping the ground, or Build): the
   citizen starts walking again at once (the server's hold ends, `Kingdom.EndConversation`); Talk
   again shows the same question.
6. Settings → Reduced motion on: the portrait appears at once (no rise) and the camera cuts.
7. Output: no red errors from ConversationController; one info line at most from the camera.

## U14 — army, objectives and the slice summary (P2 + P5; FORGE-04 selection for step 6; FL-0060)
Phone first (844 × 390 landscape), then tablet and desktop. Screenshots: the army drawer and the
tracker on the phone, the summary on the phone and on desktop.
1. HUD: under the reputation strip, the objective tracker reads "Watchtower" with a "Neutral" chip and
   "Send soldiers to capture it". It covers neither the pills, the strip nor the rail, which now has a
   third button, **Army** (crossed swords). Without FORGE-01's army server (before #70) there is
   no Army button and no Army tab on the barracks: expected (D-038 (2)).
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

## U23 — Results and "Your reign" (FL-0129; the full match's end, FL-0125)
1. Play a match to the end (or the debug phase jump to Results): the Results summary shows the winner,
   the standings and how long it lasted, with **Continue** and **Your reign** side by side (phone: Your
   reign above Continue).
2. Your reign: the six reputation values from the start of the match to its end with each change
   (green up, red down, grey none), "Key decisions" (the three history lines that moved a value most,
   each with the value and change) and "Citizens N → M" with how many more or fewer. Back to results
   returns to the summary; Continue closes both.
3. A second match: Your reign shows only that match's decisions and its own start values.
4. Phone 667 × 375: the recap sits in the summary's own box (two columns), clear of the Roblox top bar.

## U15 — job panel (P2 + FORGE-01 `Kingdom.Population` / `GetPopulation`, FL-0065)
1. Open **Kingdom** → **Jobs**. The top line reads "N citizens · homes for M · K free"; then the Free
   citizens row, Farmers, Woodcutters, Miners, Builders, each with a **number** and − / + (44 px on a
   phone), and Soldiers (read-only). Without FORGE-01's population remotes the tab shows
   "Counting your citizens…", every number reads "–" and the buttons stay off: expected until
   FORGE-01 ships them.
2. Tap **+** on Woodcutters: the row says "Asking… 2 → 3" and its buttons wait; within about a second
   the count is 3 and Free citizens is one lower. In the world, a hauler walks off to cut wood.
3. Tap **−** on Farmers: Farmers goes down by one and Free citizens up by one.
4. Move citizens until Free citizens is 0: every + is greyed out and the row says
   "None free: lower a job".
5. Leave the panel open while resources tick or someone builds: the rows don't flicker and a tap
   always lands.
6. With 3 or more free citizens, tap **+** on Miners three times quickly (each after the "Asking…"
   clears): the row says "Moving… 1 → 4" and within a few seconds Miners is 4, not 2.
7. With 1 free citizen, tap **+** on Farmers and, before it fills, **+** on Builders: Builders' + is
   already greyed out ("None free"); only one citizen moves.
8. Two-kingdom test (if the match allows switching): after you move to another kingdom the numbers
   read "–" for a moment, then that kingdom's counts; − sends that kingdom's count − 1.

## U17 — turning a building (P2; the user's first Studio feedback 2026-10-13)
1. Desktop, aerial camera: **Build** → Farm → **Place Farm**. The bar's **Turn** button shows the rotate
   icon, the word "Turn" and a round dial with an arrow; above the bar: "… R turns (Shift+R back) …".
   On the ghost: a cream strip on one edge (the door side) and a cream arrow pointing out of it.
2. Press **R**: the ghost turns a quarter counter-clockwise (seen from above), the arrow with it, and
   the dial's arrow points the same way as the ghost's arrow on screen. **Shift+R** turns it back.
   Click **Turn** on the bar: the same as R.
3. Rotate the camera (Q/E or right-drag), then move the mouse a little: the dial follows the camera
   (it shows where the door faces on screen now). Place it: the building stands the way the arrow
   pointed (its door on the strip's side).
3b. Turn the camera about 45° off a street (an oblique view) and turn the ghost through all four turns:
   each time the dial's arrowhead (two strokes and a shaft) points the way the ghost's arrow points on
   screen, never the opposite way (the dial is drawn with frames since #148; renderer deviation 25).
4. Gamepad (if available): **R1** turns, **L1** turns back; **Y** still switches the camera view and the ghost does not turn on it.
5. Phone (emulator): the bar keeps Turn as a 70 × 44 button with the icon and the dial (no word); a tap
   turns the ghost. The name, cost and verdict stay readable.
6. Plot turn (FORGE-01's v0.4-g9h server, #132): tap a free medium plot, pick Storehouse. Under the
   build time: the dial, "Faces the street" and **Turn**; on the plot a ghost with the door strip and
   arrow, inside the plot's outline. Turn → "Faces right" (the ghost turns inside the outline), again
   → "Faces away", again → "Faces left". Build it: it stands that way.
7. Same plot, **Barracks**: Turn only switches between "Faces the street" and "Faces away" (34 × 22 does
   not fit the 36 × 30 plot turned a quarter).
8. Phone: the plot detail shows a "Faces …" chip beside the build time and a Turn button left of
   "Build … here"; the price stays visible without scrolling.

## U18 — move a building (FL-0120; needs FORGE-01's base editing server, FL-0119 #140)
Before #140 the building panel shows no Move: expected.
1. Tap one of your houses: beside "Upgrade" (or the disabled upgrade reason) is **Move**. Tap your keep or
   another kingdom's building: no Move.
2. Tap **Move**: the panel closes, the house turns see-through (dimmed, still drawn), a ghost stands where it
   is with the door strip and facing arrow, and the bar reads "Move House", no cost, "Move here".
3. Move the mouse (phone: tap the ground): the ghost follows, green on free ground; red over a tree, a road,
   a crop field or outside your land, with the reason ("Not enough room there", "Move it inside your keep's
   land"). R / Turn / R1 turn it; Shift+R / L1 turn back.
4. Move here on green ground: a toast "House moved"; the house now stands there, the dim is gone, its
   workers walk over. Open its panel at once: Move reads "Moved" (disabled) and comes back after about 10 s.
5. Pick it up again and aim at a free plot that fits: the ghost snaps into the plot's outline and the bar
   reads "✓ Faces the street"; Turn steps through only the turns that fit (a barracks on a medium plot:
   street or away). Move here: it stands on the plot, turned so; the plot it left (if any) reads free.
6. Aim at a plot that is built on, or move a wall over a plot: no snap.
7. Q / Cancel / another menu while moving: the ghost goes, the house is no longer dimmed, nothing moved.
8. Refusals (needs a rival for 8b): 8a move a house twice within 10 s from the second tap: "It just moved.
   Wait a few seconds"; 8b while the alarm rings / under attack: "Not while the alarm bell rings" / "Not
   while it's under attack".
9. Edit-mode taps (FORGE-04's FL-0121 edit mode, #142): while moving, tap another of your houses, a free
   plot of yours and the house itself: the move stays (ghost and dim stay, no panel or plot drawer opens).
   Cancel, then tap the same house: its panel opens as usual.
10. Pick up a house that stands turned on its plot (U17 step 6, "Faces right"): the snap starts at "Faces
   right", not "Faces the street". **Move here** without moving it: the move ends quietly (no toast, no
   "Moved" cooldown in its panel). Turn once and Move here: it turns on its plot and the toast shows.

## U19 — the back key (FORGE-04's #130: gamepad B, Backspace; a Mac's delete)
1. Desktop: open **Kingdom**, press Backspace: the drawer closes. Open Build, then Kingdom (one drawer
   replaces the other), Backspace once: closed; a second Backspace does nothing.
2. Kingdom → a building's detail, Backspace: back to the Buildings tab; again: the drawer closes.
3. Talk to a citizen (the cinematic stage, E11): pick an answer with a cost or risk (the confirm step),
   Backspace: back to the question, nothing chosen; Backspace again: the stage closes, the camera comes
   back and the citizen walks on (as with X).
4. Phone emulator with a gamepad (or a keyboard): Build → a building (the detail pane), B: back to the
   list; B again: the drawer closes. The same for Reputation (a category) and a plot's building detail.
5. Typing in any text box, Backspace deletes text and closes nothing. While placing, B leaves build mode
   (FORGE-04's rule) and closes nothing else.

## U20 — citizens waiting (FL-0115; needs FORGE-04's request badges, #149)
1. Aerial view, a few citizens with a gold "!" (an open request): under Kingdom on the rail a **Waiting**
   button (💬) with the number of them on an amber bubble. Nobody waiting: no button.
2. Tap Waiting: the camera centres on the oldest one and their card opens with Talk; tap again: the next
   one (wrapping). The count drops when a request is answered.
3. While placing or moving a building, and while talking to a citizen, the button hides; it comes back
   afterwards.
4. Walking view (V): the button hides; back in the aerial view it comes back (FORGE-04's active(), #170).
5. Phone: the button is the icon with the bubble (no word), 48 px, under the other rail buttons.

## U21 — phase bar and Rivals (FL-0129, Operation Crownfall; Rivals needs FORGE-01's diplomacy remote)
1. Full match, a timed phase (Founding → Results): the top timer pill shows the phase, the clock and a
   track of five segments (done gold, now bright, ahead dim) with "Next: <phase>"; before Conflict it
   says "Next: Conflict · war opens". The slice's untimed Founding and the Lobby show no track. Phone:
   phase and clock only.
2. With the server's `Kingdom.Diplomacy` remote: Kingdom → a fourth tab **Rivals** (crossed swords),
   one row per rival by rank: crest, name, "#rank · N Crown Points", a chip (At peace / At war / Truce
   / Fallen). Without the remote (today's main): no Rivals tab.
3. Before Conflict: Declare war is greyed with "War opens in Conflict" under it. In Conflict: Declare war
   → "Declare war on <name>?" with Confirm / Cancel; Cancel changes nothing; Confirm: a "War declared
   on <name>" notice, the chip turns red "At war", the row offers Propose peace.
4. Propose peace: "Offer sent · m:ss" counts down and the button stays off until it expires. A rival's
   offer: one notice "<name> proposes peace", a "1" bubble on the Kingdom rail button, the row says
   "Proposes peace · m:ss" with Accept peace. Accept: "Truce", "Truce · m:ss left", Declare war off
   with "Truce for m:ss"; the bubble goes.
5. A refusal (e.g. declaring during the grace period) is a warning in words, never "Something went
   wrong"; the row does not change.
6. Two players in one kingdom (D-054): the one seated second sees **Ask <senior> to declare war**
   (grey) instead of Declare war; Confirm asks "Ask <senior> to declare war on <name>?", says "Asked
   your senior ruler for war on <name>" and sends a notice to the senior ruler; nothing changes until
   they declare; the senior ruler sees "<name> asks for war on <kingdom>". Their Accept peace is off with "<senior> decides". A ruler who joined mid-match sees
   "New ruler · m:ss" under Declare war and Accept peace for 2 minutes. An ask stays on the rival's row ("<name> asks for
   war · m:ss" for the senior ruler, with a "1" on the Kingdom button; "You asked for war · m:ss" for
   the asker) until the senior declares or it runs out (60 s). When the kingdom falls, or in
   Results, every button is off ("Your kingdom has fallen" / "The match is over"). An offer that runs
   out takes the Kingdom bubble with it.
7. Raid (needs FORGE-04's #183): when enemies enter our lands ("Enemies in your lands!"), a **Raid** button
   (⚠) appears on the rail; a tap moves the aerial camera to the raid (also from walk mode). When the
   lands are clear it goes. On a phone it is the only way to the raid (no G / D-pad).
8. Phone 667 × 375 (Device emulator): Kingdom tabs are icons only (the selected one framed in gold),
   Close fully visible; rival names whole, score "#1 · 20 pts"; Accept peace and Propose peace side by
   side, both fully inside the drawer; the confirm question on its own line. Touch and gamepad (A on a
   focused button) both work.

## U9 — icons (P4)
1. Pills, crest emblem, rail buttons and building tiles show the uploaded icons (no emoji).

## U22 — spectating after a fall (FL-0129; needs FORGE-01's FL-0125 Match.Spectate and FORGE-04's #183 camera)
1. Full match, lose your keep (or use the debug elimination): a card at the top says "Fallen",
   "<your kingdom> has fallen", "<rival> took your keep" and how many kingdoms still stand, with
   **Stay and watch** and **Leave**. Any open drawer closes and the camera switches to spectating.
2. Stay: the card goes and a **Watching** panel on the left lists battles first ("Battle · <kingdom>",
   "N fighting" in red), then the standing keeps. Tap a row: the camera goes there and the row is
   framed in gold. Prev / Next (and FORGE-04's keys . , / R1 L1) move along the list; the frame follows.
   New battles appear in the list within a second or two.
3. Leave asks "Leave the match?" with Leave / Cancel; Cancel keeps watching; Leave disconnects you
   with "You left the match. Thanks for playing AI Kingdoms!".
4. A full server (all kingdoms full): the card says "This match is full" / "Watch now. You can rule in
   the next match". The phase pill at the top shows the phase and time left with "You'll join the next
   match" under it; there is no crest, resource row, Build/Kingdom rail or Rivals tab.
5. Results and the Lobby: the card and panel step aside for the results summary; in the next match's
   active phase they come back if you are still spectating, and go when you are seated again (the
   normal HUD returns).
   As a spectator the kingdom HUD (crest, pills, rail) is gone: the card and panel sit at the top left.
6. Phone 667 × 375: the card first, then (after Stay) the panel, never both; the panel stays above the
   construction chips and its list scrolls. Touch and gamepad (A on a focused button) both work.

## U24 — Crown Arena: loadout and perk picker, intro card, duel HUD (FL-0073; needs FORGE-01's FL-0070 / FL-0071 Arena remotes and SupportService)
Use FORGE-05's arena debug presets (Adoring vs Hostile) on a two-client Local Server; run on a desktop window, the
phone emulator (667 × 375) and with a gamepad.
1. Loadout (champion only): "Choose your loadout" opens over the arena with the support tier chip (name and colour,
   e.g. "Adoring support · Blessing +2%"), a countdown (red in the last 5 s), four weapons, three armours, the line
   "Every weapon and armour is a sidegrade: none is stronger overall.", and one card per offered perk: name, Pledged /
   Empowered, the citizen with their loyalty, the effect and "When: <condition>". The first offers up to your slots
   start chosen; "Perks 3 of 3" counts them.
2. With every slot taken, the other cards say "Slots full: drop a perk first" and do nothing; tap a chosen card to
   drop it, then the other one takes the slot. Adoring shows the Crowd Rally ("Your whole stand"); other tiers never do.
3. Ready: "Ready ✓" and "Ready. You can still change it until the time runs out"; a later change is sent by itself.
   Don't press Ready on the other client: its choice is sent by itself just before the time runs out.
4. Gamepad: the first weapon tile is selected when the picker opens; A on a tile keeps the selection on it.
5. The other ruler (not a champion) sees no picker and keeps the kingdom HUD during the loadout.
6. Intro: everyone sees the versus card: crest, champion, kingdom, "<Tier> support · <score>", weapon and armour,
   "Why they cheer" with up to three reasons, and the perks (with the citizen when the server sends it). The kingdom
   HUD and the phase bar are hidden.
7. Duel: a strip at the top: both champions with HP (percent, red under 25 %), stamina, and their perk icons (dim =
   armed, gold = just fired, crossed out = spent); the clock in the middle ("Sudden death" when it applies). On the
   phone emulator the strip stays clear of the duel buttons (bottom right) and the crowd captions.
8. After the duel the strip goes and the kingdom HUD returns.

## U25 — Support meter and breakdown (FL-0073; needs FORGE-01's SupportService serving `Kingdom.Support` / `Kingdom.GetSupport`)
Without those remotes nothing shows and the HUD keeps no gap (dark launch): check that first on today's build.
Then, with SupportService on, run a desktop window and the phone emulator (667 × 375).
1. Under the reputation strip a chip reads "Support <Tier> <score>" with a coloured dot and a trend arrow (▲ green,
   ▼ red, ▬ steady); on the phone it drops the word "Support". The tier is always written, never colour alone.
2. Tap it: the drawer "Support" opens with "<Tier> support · <score>", the trend ("Rising +3 in 5 min"), the points to
   the next tier, the arena line ("Blessing +1% · 3 perk slots in the arena"), "What it is made of" (seven rows: icon,
   name, bar, share in %, value) and "What moved it" (latest first, signed and coloured). Tap the chip again: it closes.
3. Do something that moves support (let food run out; fulfil a petition): within a push the chip's score and arrow
   move and the moment appears at the top of the open drawer without it jumping back to the top of its scroll.
4. Treasury income ticking does not flicker the chip or reset the drawer's scroll.
5. Phone emulator: the chip stays clear of the pills and the objective tracker; the drawer scrolls to the last moment.
6. On a real phone (not only the emulator): tap the chip with a thumb. It is 26 px tall, like the strip and pills
   beside it (FORGE-07 L3 on #225); note if it takes more than one try.

## U26 — Citizen card: arena perk preview and petitions (FL-0073; needs FORGE-01's `role` / `petition` on Sim.Inspect and `Kingdom.FulfilPetition`)
Run on a desktop window and the phone emulator (667 × 375).
1. Open the card of a key citizen (the blacksmith, healer, captain, provisioner, elder or merchant). A box
   "<Role> · arena perk" says "At 80 loyalty, <Name> will lend you <Perk>" (below 80, with "N more loyalty"), or
   "<Name> stands with you: <Perk> (Pledged)" with an "At 95: …" line, or "(Empowered)". The effect and the "When …"
   line match the loadout picker's card for that perk (U24). An ordinary citizen has no such box.
2. A key citizen with an open petition shows a "Petition" box: their request, its cost, the time left and Fulfil.
   Before FORGE-01 serves `Kingdom.FulfilPetition` there is no Petition box at all (check this on today's build).
3. With the treasury short: the missing amount in red ("Need 500 Gold") and Fulfil greyed; nothing happens on a tap.
4. With enough: Fulfil shows a busy state, then "Petition fulfilled"; the treasury drops by the cost, the Petition box
   goes and loyalty rises. A second quick tap sends nothing more.
5. Let a petition lapse, then press Fulfil: the reason ("That petition has lapsed.") appears under the button.
6. Phone emulator: the card is one scrolling column; an open Petition comes first (Fulfil in view without scrolling),
   then the opinion and the perk box; Fulfil is 44 px tall.

## U27 — Results recap: Arena & support (FL-0073; needs FORGE-01's SupportService and the Arena remotes)
Play a match to Results with the arena debug presets (your kingdom's champion Adoring, one with Restless), desktop and
the phone emulator (667 × 375).
1. Results → Your reign: next to "Back to results" an "Arena & support" button. Without the arena (no SupportService)
   there is no such button and Back is full width.
2. Arena & support: "Biggest moments" lists five moments of the whole match (not only the last few), the biggest
   change first, each with its component and a signed, coloured number.
3. "Perks": your champion's chosen perks; the ones that fired in the duel are gold with ✓; "2 of 3 perks fired".
4. "Crowd": won with Adoring/Loyal "Crowned by your people"; won lower "A quiet crowning"; lost with Adoring/Loyal
   "Saluted in defeat"; lost lower "The stand emptied"; a cancelled duel "No victor"; no champion "Not in the arena".
   Compare with what the crowd did in the arena (FORGE-04's crowd states).
5. "Your reign" switches back; closing and reopening the recap starts on the reign page.
6. Phone emulator: moments left (scroll to the fifth), perks and crowd right, both buttons 44 px in the bottom row.

## U28 — How to play (FL-0138; runs on today's build)
Desktop window and the phone emulator (667 × 375); screenshot each card on both.
1. During the Lobby countdown a "Rules" rail button (an "i" on phones) opens the cards; it is gone once Founding
   starts.
2. Kingdom menu → Overview → "How to play" (end of the tab) opens the cards; Close returns to the Kingdom menu.
3. Six cards: The match (the phase lengths match the phase bar), Crown Points, Build and lead, War, peace and sieges,
   The Crown Arena, Falling and watching. Each is short plain text with a picture; nothing mentions buying anything.
4. Back is greyed on the first card; Next walks through; the last card's button reads "Done" and closes.
5. Keyboard: Right arrow or Enter go on, Left goes back, and the camera does not pan meanwhile; Backspace / gamepad B
   steps back a card, then closes. Gamepad D-pad left/right also work.
6. Phone emulator: the panel sits below the Roblox top bar; Back and Next are thumb-sized.

## U29 — desktop window sizes (FL-0138; headless renders + desktop-audit.py are an approximation, this decides)
Studio's Device emulator (custom sizes) or a resizable Play window, one client, match in Conflict with the diplomacy
remote (Rivals tab) and the Arena debug preset for step 3.
1. 1280 × 720 (the tablet breakpoint): HUD stack top left, rail on the right edge, construction chip at the bottom
   centre; nothing overlaps. Open Build, Kingdom (each tab), Reputation, a citizen card and a conversation: each fits
   between the HUD stack and the bottom edge, left of the rail.
2. 1280 × 720 and 1024 × 768, Kingdom → Rivals: no "Kingdom" title in the drawer header; the four labelled tabs keep a
   clear gap before the close button. Before the Rivals tab exists (no diplomacy remote) the title shows.
3. 1920 × 1080 and 2560 × 1440: same checks as step 1; at 2560 × 1440 the UI is 1.5× (not tiny), the drawers keep the
   "Kingdom" title with four tabs, and Results / Your reign, Spectate, the loadout picker, intro card and duel strip
   sit centred (top-centre for the duel strip), not stuck in a corner.

## U30 — Drag a building (FL-0123; Build.Move served; FORGE-04's edit mode and edge-pan)
Mouse on a desktop window, then touch in the phone emulator (or a real phone).
1. Press and hold one of your houses (not the keep): after about half a second the ghost lifts where it stands, the
   house dims, the Move bar shows. A quick click/tap on it still opens its panel instead.
2. Keep holding and move: the ghost follows the pointer, tinted green/red as before; dragging does not pan the camera.
   Move the pointer to a screen edge: the view pans that way (FORGE-04 tunes the speed; say how it feels).
3. Let go on a green spot: the house moves (toast "House moved"), the bar closes. Let go on a red spot: nothing is
   sent, the bar stays open with the reason; aim again or Cancel.
4. Pressing and moving straight away (before the hold) pans the camera as usual and never lifts the house.
5. Right after a move the same house cannot be dragged until the move cooldown passes (its panel says "Moved").
6. Touch: one finger holds and drags; a second finger still pinches/rotates the camera.

## U31 — Siege on the rail (FORGE-04's siege alert, #235)
Desktop window and the phone emulator.
1. Let raiders into your lands: the rail shows "Raid" (a warning icon on the phone); a tap moves the aerial camera there.
2. Bring an enemy army to your keep: the same button now reads "Siege" (a siege ranks ahead of a raid); a tap goes to
   the keep. FORGE-04's siege tip marks this button.
3. Drive the attackers off the keep while raiders remain: it reads "Raid" again; once the lands are clear it is gone.

## U32 — Arena: the co-rulers' champion vote (FL-0142; needs FORGE-01's ArenaState.vote, see the 2026-10-19 handoff)
Without `ArenaState.vote` nothing shows (dark launch): check that first on today's build. Then two clients in one
kingdom (Studio "Start" with 2 players, both seated rulers of the same kingdom), desktop window and the phone emulator.
1. Play into the Crown Arena with that kingdom in the top two. Both clients see "Choose your champion" with a
   countdown, the two rulers ("You" for yourself) and "0 of 2 voted"; a client of another kingdom sees nothing.
2. Tap a ruler: it turns gold, the line reads "You voted for …", and the other client's count reads "1 of 2 voted".
   Tap the other ruler: the gold moves (the latest vote counts).
3. When both have voted, or the time runs out, the panel closes as the loadout opens, and each voter sees one toast:
   "<name> fights for <kingdom> in the Crown Arena" (or "You fight…"). The champion is the one most voted for; with a
   tie, the higher leadership.
4. Phone emulator (667 × 375): the panel sits below the Roblox top bar; the candidate buttons are thumb-sized. A long
   display name ends with "…" inside its button.
5. Tap each candidate ten times in a row, quickly, while the clock runs: every tap answers (the gold moves or the
   line says "Sending your vote…"); the buttons are not rebuilt by the countdown (FORGE-07 M1 on #265).
6. How to play → card 5 says co-rulers vote in 10 seconds and a tie goes to the higher leadership.

## U33 — Build: the wall line (FL-0129c; FORGE-01's Build.PlaceLine, #301)
Desktop window and the phone emulator, one client, the starting treasury (walls cost the level-1 price per piece).
1. Build → Military → Wall → Place: the bar reads "Wall line: the start", has no Turn button, and its button says
   "Set start". Aim at open ground inside your kingdom: "✓ Start here". Also aim right beside a building (one stud
   of gap): it still reads "✓ Start here" and Set start is on (the start is an end, not a piece). Tap Set start.
2. Move the aim away along the ground: one ghost per 32-stud piece appears from the start toward the cursor, all
   facing along the line; the bar reads "Wall line · N pieces" with the total price, "Builds in one go: all pieces
   or none" (no check mark: the ground is checked on Build wall), and "Build wall". Move the cursor back over the
   ghost pieces: the far end follows the ground under the cursor and never climbs onto the ghosts.
3. With the aim on the start: "✕ Move the far end out further" and Build wall is off. Drag past 12 pieces:
   "✕ Too long: 12 pieces at most". Aim at more pieces than the treasury pays for: the price turns red and
   "✕ Not enough for the whole wall".
4. Aim at two pieces on clear ground, tap Build wall: a toast "Wall of 2 pieces placed", build mode ends, and two
   wall construction sites appear where the ghosts stood, joined end to end. The treasury drops by twice the price.
5. Draw a line through an existing building or out of your territory and tap Build wall: nothing is built or
   charged, the line stays open with "✕ No room for part of it" (or "Part of it leaves your kingdom") and an error
   toast. Move the far end and build again.
6. Cancel (X, or Q on desktop) at any step: every ghost goes and build mode ends. Placing a farm or a house still
   uses the one-spot placement with Turn.
7. Phone emulator (667 × 375): the bar and its status line fit (no "…" in the status); the pieces are visible from
   the aerial camera.

## Report
Per test: pass/fail, BuildInfo sha, device/emulator, screenshots for U5/U6 and U12, any Output errors.
