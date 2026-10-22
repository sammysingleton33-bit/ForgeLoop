# D-059 HUD pass at the start frame

The kingdom HUD at a match's first second (Founding 0:01, the starting treasury, nothing built), laid over
FORGE-02's start-frame render (`render_world.py`, FL-0147 camera: zoom 70, FOV 55, ahead 20, looking back at the
keep). Scenes `start` and `start-card-docked` (`scenes/_start.luau`), rendered with `--backdrop=none`;
composites in `screenshots/d059-start/` (desktop 1920×1080 shown at 1280×720; phone-wide 750×311 shown at 2×).
All judged by eye on the composites. A composite is not Studio: the real top bar, fonts and lighting can differ.

## Verdict

| Check | Desktop 1920×1080 | Phone 750×311 |
|---|---|---|
| Reads as a management game | Yes: banner, four resource pills, players, phase pill, two-button rail; the world stays the subject | Yes, tighter: crest badge, pills, phase pill, icon rail |
| Keep door / market cross / citizens | HUD clear of all three. **The onboarding card covers the keep's face and crest** | **The onboarding card covers the keep door, the market cross and the stall roofs** |
| Hierarchy | Kingdom name first, resources second, phase third; correct | Same |
| Contrast on the new lighting | Ink pills and gold strokes hold on grass, path and shadow | Same |
| Empty states at match start | "0 Gold", no queue, no toasts, menus closed: nothing to collapse | Same |
| Phase pill | Sits on the keep's roof between the tower caps, 52 px right of screen centre | On the keep's right tower |

## Fixed here

Nothing in the HUD needed a cheap fix at this frame. The pass adds the tooling to repeat it:
`--backdrop=none` (transparent PNG to lay over a world render), the `phone-wide` device (750×311), and the
`start` scenes with FORGE-04's real first onboarding step.

## Structural (not fixed; owners named)

1. **Onboarding card placement (FORGE-04, `OnboardingController`, `CARD_TOP = 72`, top centre).** At the start
   frame it lands on the keep, the one building the camera frames. `start-card-docked` shows the card docked bottom
   centre (16 px up): on desktop the keep, door, cross and stalls are all clear; on phone the door and cross are
   clear, the stall roofs are not. Proposal: dock it bottom centre, and on short screens (height < 400) cut it to
   one body line. Handoff `production/handoffs/2026-10-22-forge-03-to-forge-04-start-card.md`.
2. **Onboarding card styling (FORGE-04).** Gotham on a flat brown panel with a thin grey stroke; every other HUD
   surface uses the kit's ink gradient, gold stroke and Montserrat (`Style`, `Theme`). It reads as a debug panel.
3. **Phase pill over the keep (FORGE-03 + FORGE-04 camera).** It is centred in the top bar's free space
   (TopbarSafeInsets, documented in REVIEW.md), which at this camera is the keep's roof. Centring it on the screen
   needs runtime inset measurement the renderer cannot check, and it would still sit on the keep. Better fixed by
   the start camera's pitch (keep a little lower in frame) if FORGE-04 wants it; left as is.

## Repeat it

```sh
PROJECT=games/game-001/default.project.json RENDER_FLAGS="--shots=<dir> --backdrop=none" \
  DEVICES="desktop phone-wide" bash design/ui/render/shoot-luau.sh "$PWD/games/game-001/design/ui/scenes/start.luau"
# world: blender/scripts/render_world.py --views custom_crimson \
#   --camera "zoom=70;fov=55;ahead=20;yaw=throne+180;w=1920;h=1080"   (w=1500;h=622 for phone-wide at 2x)
# then alpha-composite the transparent PNG over the world render scaled to the same size
```
