# D-059 arena UI pass

Every Crown Arena panel in real states, judged as the owner will see them for the first time. The UI is rendered
with `--backdrop=none` and laid over Blender renders of the arena venue: FORGE-02's `render_world.py` on the
`forge/02-blender-visual-yard` dump, with the camera on the arena at (141, 0, −27):
- the intro's ring shot: zoom 108, FOV 55, from Gate A;
- the duel's follow view: zoom 16, FOV 70, pitch 14, behind champion A's mark.

The vote, the loadout and Results show while the camera is still on the player's kingdom, so they lie over the
D-059 start frame. Composites are in `screenshots/d059-arena/`: `desktop-*` (1920 × 1080 shown at 1280 × 720) and `phone-*` (the
`phone` device, 844 × 390, over 1688 × 780 venue renders). The champions have no figures in the Blender dump, so white rings mark where they stand
(their marks, Layout.arena spawnA / spawnB). All are judged by eye. A composite is not Studio.

Device note: `phone-wide` (#314) treats 750 × 311 as the whole screen, then takes the 58 px top bar out of it, which
leaves 253 px of height. That is stricter than any real phone: the `phone` device keeps 750 × 311 below the top bar.
On `phone-wide` the loadout and the intro card overflowed their frames; on `phone` both fit. This pass uses `phone`.

## Verdict

| Stage | Reads? | Covers the champions? | Notes |
|---|---|---|---|
| Vote (incl. four rulers, long names, voted, "your pick left") | Yes | n/a (kingdom view) | The "your pick left" status is red and clear |
| Loadout | Yes | n/a (modal, kingdom view) | Large (1036 × 720) but it is the choice moment; phone fits |
| Intro, first 8 s (stand shots) | Yes | Was: the card hid the whole ring. **Fixed** | Card over the stand shots only |
| Intro, ring shot (last 4 s) | Yes | **No, after the fix** | |
| Duel (normal, sudden death, low HP) | Yes, on sky and stands | No: the strip sits in the sky above the far gate | |
| Duel ended | **Fixed**: "KO · You win" | No | The clock ran on into the crowning |
| Crowning | **Fixed**: the pill and a toast name it | No: the toast sits top right | Nothing named the winner for 15 s |
| Results / recap | Yes | n/a | |
| Spectate (watching, waiting, fallen) | Yes | n/a | |

Styling matches the kingdom HUD throughout: ink panels, gold strokes, the kit's type and accents. Empty and edge
states are clean: no votes yet, "1 of 4 voted", long names cut to fit, stamina unknown, a spent perk dimmed.

## Fixed here (FORGE-03's files)

1. **Phase pill during the arena** (`HudModel.timer`, `KingdomHudController:setArenaState`, `ArenaHudController`).
   The match waits in Endgame with a spent clock, so the pill read "ENDGAME 0:01 left · Next: Results" through the
   vote, the loadout and the crowning. It now reads "CROWN ARENA", the stage ("Choosing champions", "Champions arm",
   "Champions enter", "The duel", "Crowning") and the stage's own clock.
2. **The duel's end** (`ArenaHudModel`, `ArenaHud`). After a KO the clock kept running. The clock box now says how
   it ended ("KO", "Time", "Forfeit", "Draw") and who won ("You win", "You lost", "Frostmere wins"), in gold.
3. **The intro card steps aside for the ring shot** (`ArenaIntroController`). The 1080 × 494 card covered the whole
   ring for all 12 s, including the camera's last shot, which settles on the ring. It now hides for the last
   `Crowd.intro.ringSec` (4 s), so the champions are seen when the camera arrives on them.
4. **The crowning names the winner** (`ArenaHudController:crownToast`). One toast when the crowning starts: "<Kingdom>
   takes the crown", with "Your champion won the duel" (achievement accent) or "Their champion won the duel", or
   "Crowned without a duel" for a coronation. A draw gets none: FORGE-04's match-end line says it.

5. **The phone's clock box** (`ArenaHud.CLOCK.phone` 56 → 68, the note `TextScaled` between 6 px and its size). On
   the 844 × 390 phone "Sudden death" read "Sudden de…"; a spectator's "<Kingdom> wins" shrinks to fit instead of
   being cut.

## Structural (not fixed; owners named)

1. **No camera on the crowning (FORGE-04, `CrowdStageController` / camera).** After the duel the champions' follow
   camera ends, and nothing returns watchers to the ring. The fanfare plays, but the crowning itself may happen
   off screen. Proposal: hold the ring shot through `crowning`. Unverified in Studio.
2. **Nobody announces who qualified (FORGE-04, Lines).** When Endgame ends, the arena begins with the vote panel for
   co-rulers and nothing at all for everyone else. A line such as "Emberhold and Frostmere enter the Crown Arena"
   at the arena's start would frame the next three minutes.
3. **`qualify` is in the contract but never sent (FORGE-01 / FORGE-00).** `ArenaStage` lists `qualify`, but
   `ArenaFlow` starts at `vote`. The UI has nothing to show for it; either drop it from G12.1 or say what it is.
4. **Champion figures are not in these renders (FORGE-02 / FORGE-01).** Coverage is judged against the marks. The
   duel strip and the toast are far from the ring, but a real body's height is unverified.
5. **Studio still owed:** touch hints on a phone (the scenes use keyboard hints), the crowning toast against
   FORGE-04's own match-end banner a few seconds later, and the intro card's hand-off to the ring shot in motion.

## Repeat it

```sh
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=<dir> --backdrop=none" \
  DEVICES="desktop phone" bash design/ui/render/shoot-luau.sh "$PWD/games/game-001/design/ui/scenes/<scene>.luau"
# venue: blender/scripts/render_world.py --views custom_crimson --camera \
#   "zoom=108;fov=55;focus=141,4,-27;yaw=-90;w=1920;h=1080"            (the ring shot)
#   "zoom=16;fov=70;pitch=14;focus=128,7,-27;yaw=-90;w=1920;h=1080"    (the duel's follow view)
#   w=1688;h=780 for the phone (844 x 390 at 2x)
```
