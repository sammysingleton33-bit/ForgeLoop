# selftest — what the screenshots must show

Scene: `selftest.luau` (plain `Instance.new`, no FORGELOOP UI modules). Screenshots:
`design/ui/screenshots/luau/selftest-{phone,tablet,desktop}.png`. Regenerate with
`bash design/ui/render/shoot-luau.sh selftest`. Zoom in with
`node design/ui/render/render.js design/ui/render/out/selftest-phone.json --dpr=3 --shots=/tmp/x`.
Each item states the Roblox rule it checks; a reviewer compares the image with this list (and the
same scene in Studio, for gate G6).

## Screen layers (ScreenInsets, DisplayOrder, Enabled)

| What | Where it must be |
|---|---|
| **Fullscreen** (None, DisplayOrder 0): 4 px magenta bars on all four device edges; magenta badge "None (fullscreen)" | bars at the very edges of the device, also over the phone notch areas and the bottom inset; badge at the device's bottom-left corner (phone: inside the left notch area) |
| **Core** (CoreUISafeInsets, DisplayOrder 1): a faint white tint (Root) with 8 px corner markers red TL, green TR, blue BL, yellow BR | tint covers exactly the core area: phone x 47–797, y 58–369; tablet y 58–748; desktop y 58–1080 (Root is integer-sized, so its right/bottom edge may stop ≤ 1.5 px short) |
| Core caption "Core · UIScale s" centred at the Root's bottom | s = 0.843 phone, 1.151 tablet, 1.500 desktop |
| **TopBar** (TopbarSafeInsets, DisplayOrder 2): light blue band, "◀ TopbarSafeInsets" at its left, dark pill "12:34" with gold stroke | band starts right of the Roblox controls (x = 151 phone, 104 tablet/desktop), ends at the right safe edge, height 58; pill centred in the band, 110 × 42 |
| **DeviceSafe** (DeviceSafeInsets): blue badge "DeviceSafeInsets" | top-right corner of the device safe area: y = 0 (inside the top-bar band), right edge 797 on phone, device edge on tablet/desktop |
| **IgnoreInset** (IgnoreGuiInset = true, ScreenInsets left at CoreUISafeInsets): teal badge "IgnoreGuiInset" | directly under the DeviceSafe badge (y = 20): it behaves as DeviceSafeInsets, NOT below the top bar |
| **StackLow** (DisplayOrder 5, red "Low") / **StackHigh** (DisplayOrder 6, green "High"), returned High first | at 3/4 of the top-bar band; green overlaps the red square and is drawn on top |
| **Disabled** (Enabled = false, full-screen red frame) | nowhere: no red wash anywhere |
| Roblox buttons "R" and "≡" | two dark circles at the top-left of the device safe area, above everything |

## The twelve cards (Core → Root → Cards, UIGridLayout of 140 × 150 cells)

Grid: centred block, cards in order 1–12 by LayoutOrder. Phone and tablet: 2 rows of 6; desktop:
8 + 4 (the last row starts at the left of the centred block). Each card: dark ink panel, 8 px
corners, thin gold UIStroke outside the edge, gold bold title at the top-left.

1. **Anchors / Z / clip** — light box (70 tall) with 10 px squares in its corners: red TL, green
   TR, blue BL, yellow BR (AnchorPoint 0/1 + scale Position 0/1), white 16 px square in the exact
   centre, orange bar rotated 30° clockwise below-centre. Cyan bar under the box, centred
   (Size 0.5 + 10, Position 0.25 − 5). Green square over a red square (green has ZIndex 2 although
   created first). Dark 50 × 24 frame with a magenta bar cut off at the frame's right edge
   (ClipsDescendants). No red full-card wash (Visible = false).
2. **List vertical** — light body, three gold chips stacked and centred both ways, top to bottom
   "1 · 40px" (40 wide), "2 · 60%", "3 · 90%" (LayoutOrder sort; created C, A, B), 4 px gaps; no red
   "hidden" chip and no gap for it; chip A ignores its Position (500, 500).
3. **List horizontal** — top half: orange chips 1, 2, 3 (heights 20 / 40 / 30) packed to the
   RIGHT and aligned to the BOTTOM, gaps = 5 % of the width. Bottom half: cyan chips 1, 2, 3
   vertically centred, first at the left edge, last at the right edge, middle centred
   (HorizontalFlex SpaceBetween).
4. **Flex / grow / wrap** — three gold tabs "Eco Civ Mil" filling the width equally (HorizontalFlex
   Fill); a "−" chip, a cyan bar filling the remaining width (UIFlexItem Grow), a "+" chip at the
   right; orange chips 1–4 on the first line and 5–7 on the second (Wraps); a dark strip labelled
   "VideoFrame" with a dashed pink outline (unknown class).
5. **Grid** — green cells 1 2 3 / 4 5 6 / 7, each 30 % of the width and 24 tall, block centred (7
   at the left of the block); a white "in a Folder" chip along the card's bottom edge (GuiObject in
   a Folder: drawn, not part of the grid).
6. **Corners / strokes** — four gold squares: 1 px white stroke with slightly rounded outer corners
   (Round join); 6 px corners with a 3 px white stroke outside; a circle (corner scale 0.5) with a
   half-transparent red 2 px stroke; a square with a 3 px white legacy border (BorderSizePixel,
   Outline). "Outlined" in white ExtraBold with a dark outline around the glyphs (Contextual
   stroke). "Boxed button" (TextButton) with a gold 1 px box outline and rounded corners (Border
   stroke on text). "TextStroke (legacy)" cream text with a red 1 px outline.
7. **Gradients** — bars: red→blue left to right; gold (top) → ink (bottom) (Rotation 90); green →
   black (green background × white→black gradient); white fading to transparent at the right (the
   card shows through); red→blue with the red section reaching ~¼ of the width before the blend
   starts (Offset 0.25). "Gradient text" coloured yellow→red across the label.
8. **Text align / wrap** — light boxes: "Left", "Center", "Right" aligned accordingly; "Top" at the
   top of its box, "Bottom" at the bottom of its box; "Truncated text that c…" ending in an
   ellipsis; "Wrapped text / continues on a second" on two lines with the word "line" NOT drawn
   (the third line does not fit the 28 px box).
9. **Fonts / rich / emoji** — "Aldmere Kingdom" in Grenze Gotisch (blackletter, gold);
   "Merriweather 900" (heavy serif); "Montserrat Regular" (light sans); "MONTSERRAT HEAVY";
   "Rich: **bold** *italic* red" with "red" in red; colour emoji ⚔️ 🏰 👑 🪙 ⚒ and a bullet;
   "<b>not rich</b>" shown literally (RichText off).
10. **AutoSize / scaled** — gold pill "Auto X" just wide enough for its text + 8 px each side;
    "BIG" filling its 52 × 36 box (TextScaled); a light box hugging three cyan "row" chips
    (AutomaticSize Y: 3 × 10 + 2 × 2 gaps + 2 × 4 padding = 42 tall); a full-width light box
    whose height fits a 3-line paragraph starting "Auto Y:" (AutomaticSize Y + TextWrapped).
11. **ScrollingFrame** — dark frame with alternating orange/gold rows; scrolled 30 px: "Row 1"
    is hidden, "Row 2" is cut at the top, "Row 8" is cut at the bottom; a gold 5 px scroll bar at
    the right, its thumb ~¾ of the height, slightly below the top.
12. **Scale / constraints** — gold 30 × 15 box centred in a 60 × 30 white outline (UIScale 0.5
    about the anchor); cyan 60 × 30 box at the top of a 60 × 40 outline (UIAspectRatioConstraint
    2); a grey-white box with a dark red bar inside, both at 50 % (CanvasGroup
    GroupTransparency 0.5); a green bar only 50 wide (UISizeConstraint MaxSize); an orange square
    (SizeConstraint RelativeYY); "cap 14" text no larger than 14 although TextScaled
    (UITextSizeConstraint); a gold-tinted hatched placeholder "#1234567" (ImageLabel, ScaleType
    Fit) and a round white-tinted placeholder "#7654321" (ImageButton with UICorner 0.5).

## Expected notes from render.js

Exactly these three per device (anything else is new and worth a look):

- `Folder 'Core.Root.Cards.Card5.Body.Extras': its GuiObjects are drawn as children of 'Body' and left out of any layout`
- `VideoFrame 'Core.Root.Cards.Card4.Body.Video' is not emulated: drawn as a plain box`
- `IgnoreInset: IgnoreGuiInset=true with ScreenInsets=CoreUISafeInsets -> DeviceSafeInsets (the engine couples the two properties)`

Numbers can be checked in `design/ui/render/out/selftest-<device>.layout.json` (device px), e.g.
desktop: `Core.Root` (0, 58) 1920 × 1021.5; `TopBar.Timer` (957, 8) 110 × 42;
`Card12.Body.Scaled` 45 × 22.5; `Card12.Body.Aspect` 90 × 45; `Card10.Body.AutoYStack` 105 × 63.
