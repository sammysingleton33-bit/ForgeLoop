# FL-0099 review — cinematic conversation (G13.8)

Self-review by FORGE-03, 2026-10-13. Sizes: phone 844 × 390 (CoreUISafeInsets 750 × 311), tablet
1024 × 768, desktop 1920 × 1080. Contract: CONTRACTS G13.8 (UI), with G13.3 for the conversation
itself. Everything here is headless; Studio is U16 in `roblox/studio-tests/ui-economy.md`
(FORGE-05, FL-0101).

## How the renders were made
- Scenes `stage-asking`, `stage-four`, `stage-confirm`, `stage-answered`, `stage-refused`,
  `stage-long` (`scenes/_stage.luau`): the real HUD, card and conversation controllers on the spec
  world with the FORGE-01 #108 double (look, job, position, kingdom; `Kingdom.EndConversation`).
- Shot on a **local merge** of this branch with #108, #84 and #85, so the portrait is FORGE-02's own
  `Kit.portrait` framed by `Kit.portraitCamera` (on this branch alone the scenes use the contract
  stand-in, `tests/economy/doubles/PortraitDoubles`).
- The renderer now draws ViewportFrames (`design/ui/render/README.md`, deviations 23–24): flat
  shading (the head looks faceted; Roblox shades it smoothly), and a stand-in face instead of the
  face texture. The framing and proportions are the real ones; the surface look is not.
- Committed (uncompressed, 0.87 MB in all; palette compression banded the portrait's gradient):
  `screenshots/luau/stage-asking-desktop.png`, `stage-asking-tablet.png`, `stage-answered-desktop.png`,
  `stage-four-phone.png`, `stage-confirm-phone.png`, `stage-long-phone.png`, `stage-refused-phone.png`.

## What I looked at, and what changed after looking
- **Layout.** Portrait bottom left, bubble and answers to its right, the whole stage centred left
  of the rail and never above the HUD stack; the world (and where the camera puts the citizen,
  above the centre) stays visible. Phone 844 × 390: four answers in two rows of two, no overlaps
  (checked in `out/stage-four-phone.layout.json`), the portrait clear of the answers.
- **Close button over the confirm card (phone).** Without the question bubble, the first row ran
  under the X. Fixed: a head row as tall as the X sits beside it whenever the column does not start
  with a bubble (the confirm step's kicker on phones, the "You: …" echo after an answer).
- **The dim band stopped at the notch insets (phone).** Hard vertical edges at 47 px. Fixed: the
  band lives on a new whole-device layer under the menus (`KingdomBackdrop`, ScreenInsets None,
  not clipped to the safe area), anchored to the device's bottom.
- **The bubble's tail pointed at empty space above the portrait.** Moved low on the bubble's left
  edge, toward the portrait.
- **Phone name truncated ("Edda Thorn…").** Portrait 104 → 112 px and the phone name 12 → 11 px:
  "Edda Thornbury" fits.
- **A thin scroll bar on the tablet's four answers.** The height estimate was exact; the body's
  1 px padding tipped it over. 4 px of slack added; no body overflows in any scene now.
- Long question on a phone: the stage grows up to the HUD stack, the kicker says "YOUR ANSWER ·
  SCROLL FOR ALL 3" and the body scrolls (as the panel does).

## Unverified
- Studio: the rise, the camera framing next to the stage, the portrait against the world rig, the
  reduced-motion cut, real fonts and the Done timer bar (tweens are not drawn by the renderer).
