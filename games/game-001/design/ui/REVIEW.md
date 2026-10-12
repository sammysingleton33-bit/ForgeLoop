# FL-0059 review — kingdom HUD, build menu, placement, Kingdom panel

Self-review by FORGE-03 (G5), 2026-10-12. Sizes: phone 844 × 390 (iPhone 14 class landscape,
notch insets 47/47, home bar 21), tablet 1024 × 768, desktop 1920 × 1080; Roblox top bar 58 px.
Studio evidence is still the user's (`roblox/studio-tests/ui-economy.md`).

## 1. HTML prototype (reviewed first)
`kingdom.html?size=…&scene=…` (`node shoot.js`) → `screenshots/prototype/<scene>-<size>.png`, scenes:
`hud` (+`hud-guides`), `build`, `build-detail`, `build-short`, `placing`, `placing-bad`, `placed`,
`kingdom`, `kingdom-buildings`, `upgrade` (33 screenshots when shot). Committed, palette-compressed
(D-007): `hud`, `build-detail`, `placing`, `placing-bad`, `kingdom` at 3 sizes (15); the rest are
regenerated with `node shoot.js`.

What the prototype settled:
- **Top-left stack** crest → name plate ("Keep Lv 1 · 1 region · 12 Crown Points") → four pills →
  rulers. Territory and Crown Points live on the plate (one line) instead of extra widgets; on
  phones the Crown Points sit on the crest and the rulers move to the Kingdom panel.
- **Phase + clock in the Roblox top bar** (TopbarSafeInsets): "FOUNDING · 3:12 match time" when
  untimed, a countdown when the phase has an end.
- **Placement** is a bottom bar, not the drawer: the world must stay visible while aiming. The
  ghost is a flat footprint with a front marker (rotation is readable), green/red from the server.
- **Standings** in the Kingdom panel (all four kingdoms, Crown Points, regions), yours highlighted.

Changes made after looking at the screenshots:
- "You you" on the local ruler's chip → the player's name plus a "you" tag.
- Standings regions cell wrapped under its number → inline flag + count.
- Phone placement bar: the worded Cancel left the building name no room → an ✕ icon button (44 px),
  bar 460 px wide. Same in Luau.
- Shortfall CTA "Need 20 more Wood and 10 more Stone" overflowed the button on tablet and phone
  (seen in the Luau render) → "Need 20 Wood and 10 Stone"; the red cost rows keep the detail.
- Esc belongs to the Roblox menu → cancel is **Q** (hint text and input).

## 2. Real Luau UI (headless render)
`design/ui/render` over the game-001 project, scenes in `scenes/` (they drive the real controllers on
the spec world: real RemoteService + TreasuryService, FORGE-01 doubles):

```
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=games/game-001/design/ui/screenshots/luau" \
  bash design/ui/render/shoot-luau.sh games/game-001/design/ui/scenes/{hud,build,build-short,placing,placing-bad,placed,kingdom,upgrade,confirm}.luau
```
→ `screenshots/luau/<scene>-{phone,tablet,desktop}.png` (27, committed palette-compressed with
`design/ui/compress-shots.py`).

Found by the Luau render, not by the prototype (fixed):
- The drawer's ✕ stopped ~150 px short of the right edge with short titles ("Build"): the kit Panel
  reserved a fixed 170 px for the title → the header slot now fills the rest (UIFlexItem Fill; FL-0020).
- The "−50" spend float vanished at once when tweens are off (reduced motion; the renderer has no
  TweenService): Motion applies a tween's end state immediately, and the end state was "faded out"
  → the delta now fades only when tweens run (FL-0020). This was the main visual confirmation.
- The timer label used the clock's size → its own smaller, dimmer label.

Prototype ↔ Luau differences that remain (on purpose):
- The renderer cannot draw 3D, so `placing*` show the bar without the ghost; the prototype shows it.
- Emoji fallbacks in Luau until icons are uploaded (`production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`).

## 3. Checklist
| Check | Result |
|---|---|
| Nothing under the notch / home bar / Roblox buttons | CoreUISafeInsets for HUD and menus, TopbarSafeInsets for the clock; the modal layer is full screen (its scrim must cover the notch strips, seen in the phone render) with the panel centred |
| Touch targets ≥ 44 px on phones | rail 48, placement buttons 44, CTA 44, Upgrade 44 on phones (32 on desktop) |
| World stays visible | HUD in corners; drawer on the right; placement bar 60 px at the bottom; chips hidden while placing |
| Every refusal explained | CTA text for shortfalls; server reasons as sentences (`UI/Text`); unknown reasons get a generic line |
| Visual confirmation of a spend | pill float (−50), pill border tint, toast, construction chip with progress |
| Colour is never the only signal | ghost verdict also in words on the bar; costs say "have N" |

## 4. FL-0087 — plot picker and upgrade panel (D-030, CONTRACTS G13.5/G13.6)
Prototype scenes (same `kingdom.html`): `plot-pick`, `plot-pick-list`, `plot-pick-large`,
`building-upgrade`, `building-max`, `building-foreign`; committed: `screenshots/prototype/plot-pick-*`
and `building-upgrade-*` (6). Luau scenes `scenes/{plot-pick,plot-pick-list,building-upgrade,building-foreign}.luau`
on the spec world with `tests/economy/doubles/SlotDoubles.luau`; committed:
`screenshots/luau/plot-pick-{phone,tablet,desktop}`, `plot-pick-list-phone`,
`building-upgrade-{phone,tablet,desktop}`, `building-foreign-desktop` (8). The build, build-short,
upgrade and confirm renders were re-shot because the detail pane now shows what a building gives.

What the prototype settled:
- The plot picker **is** the build drawer (same rows, costs and detail), with one tab naming the plot
  size and a CTA "Build <name> here"; only structures that fit the plot are listed (`UI/SlotFit`).
- The upgrade panel is the same detail pane: the next level's cost and time, plus two lines —
  **Now** (what the building gives) and **Lv N** (what the next level adds, green).
- A tapped building of another kingdom opens a read-only card.

Changed after looking:
- At the highest level the prototype still showed "0:00 with builders" → no build time without a
  next level (Luau hides it).
- Phone upgrade panel (Luau render): the "Lv 2" line sat below the fold under the costs → phones show
  only the next-level line; costs stay first so the price is always visible.
- The read-only card read "Recruits and trains soldiers for **your** kingdom" about Frostmere's
  barracks → no catalogue description on foreign buildings.
