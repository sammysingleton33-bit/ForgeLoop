# design/ui/render — headless snapshots of the real Luau UI (FORGE-03)

Roblox Studio does not run on Linux. This tool runs the **actual Luau UI code** under Lune (same
module loader and globals as the spec harness), serialises the GUI instance tree it builds, and
draws it in headless Chromium with a Roblox-layout emulation, at phone / tablet / desktop sizes.

> **This is a headless approximation, not a substitute for the Studio check (gate G6).** It draws
> only what the instance properties say, following Roblox rules as closely as practical; every
> known gap is listed under [Known deviations](#known-deviations-from-roblox). Layout, fonts and
> touch feel are confirmed only in Studio / on a device (`roblox/STUDIO_TEST_PLAN.md`).

## Run

```bash
export PATH="$HOME/.cargo/bin:$PATH"                     # lune
lune run design/ui/render/snapshot.luau design/ui/render/scenes/selftest.luau phone
node design/ui/render/render.js                          # every out/*.json -> screenshots/luau/*.png

bash design/ui/render/shoot-luau.sh selftest             # snapshot + render at phone, tablet, desktop
bash design/ui/render/shoot-luau.sh                      # every scenes/*.luau except selftest
bash design/ui/render/shoot-luau.sh hud build            # scene names or paths
DEVICES=phone RENDER_FLAGS="--guides --dpr=2" bash design/ui/render/shoot-luau.sh hud
PROJECT=games/game-001/default.project.json bash design/ui/render/shoot-luau.sh kit   # game-001 Config (theme)
```

| Step | Command | Writes |
|---|---|---|
| snapshot | `lune run design/ui/render/snapshot.luau <scene.luau> <device> [out.json]` | `out/<scene>-<device>.json` |
| render | `node design/ui/render/render.js [json ...] [flags]` | `design/ui/screenshots/luau/<scene>-<device>.png`, `out/<scene>-<device>.html`, `out/<scene>-<device>.layout.json` |

`out/` is gitignored. The `.html` page can be opened in a browser to inspect the DOM; the
`.layout.json` lists the absolute rect of every GuiObject in device px — compare it with
`AbsolutePosition` / `AbsoluteSize` printed in Studio.

render.js flags: `--guides` (device insets and the top-bar band, as in the HTML prototypes),
`--debug` (outline + name of every object, the notes list on the image), `--backdrop=plain`
(neutral backdrop instead of the stylised world), `--dpr=2` (HiDPI screenshot for zooming in; the
layout is unchanged), `--shots=<dir>` (another output folder). Notes (approximations, unset
defaults, unknown classes) are printed per screenshot. Snapshot errors (a spawned thread errored)
make snapshot.luau exit 1 and put a red banner on the screenshot.

Playwright is the preinstalled global (`require('playwright')`); never `npm install` it or run
`playwright install`. Fonts come from `design/ui/node_modules/@fontsource` (Grenze Gotisch,
Merriweather, Montserrat); emoji from the system Noto Color Emoji.

## Devices

`devices.json` (same numbers as the HTML prototypes' `DEVICES`). `<W>x<H>` (e.g. `1280x720`) is
also accepted: no device insets, same top bar.

| Device | Size | Insets L / R / T / B | Top bar | Core (CoreUISafeInsets) | Top bar area (TopbarSafeInsets) |
|---|---|---|---|---|---|
| phone | 844 × 390 | 47 / 47 / 0 / 21 | 58 | 750 × 311 at (47, 58) | 646 × 58 at (151, 0) |
| tablet | 1024 × 768 | 0 / 0 / 0 / 20 | 58 | 1024 × 690 at (0, 58) | 920 × 58 at (104, 0) |
| desktop | 1920 × 1080 | 0 / 0 / 0 / 0 | 58 | 1920 × 1022 at (0, 58) | 1816 × 58 at (104, 0) |

The top bar (58 px band, ~104 px of Roblox controls on its left) is an estimate; in a live game
`GuiService.TopbarInset` gives the real rectangle.

## Scene contract

A scene is a Luau module (put it in `scenes/<name>.luau`) that returns one function:

```lua
return function(ctx)
	-- build ScreenGuis with the real UI modules
	return { guis = { screenGui, ... }, settle = function() ... end } -- settle is optional
end
```

- `ctx.device` = `{ name, width, height, inset = { left, right, top, bottom }, topbar, controls }`
- `ctx.core` = `{ width, height }` — the CoreUISafeInsets area (what a HUD ScreenGui's
  `AbsoluteSize` is in Roblox, and what `UI/Layout.compute` takes)
- `ctx.topbarArea`, `ctx.deviceArea` = `{ width, height }` for TopbarSafeInsets / DeviceSafeInsets
- `ctx.root` = the repository root (absolute path)
- `settle()` runs after the scene returns and before serialisation (e.g. `env.mock:advance(1)`
  so tweens and timers reach a steady state). Only the final property values are drawn.

The scene is loaded like one spec file of `roblox/tests/harness/run.luau`: `Globals.build` +
`ModuleLoader.new` over `roblox/default.project.json`, MockRandom loaded first as the global
`Random`, Core/Signal's error reporter routed to the run. So inside a scene:

- `require("@game/ReplicatedStorage/Forge/...")` (shared code, `Config/UITheme`) and
  `require("@game/ReplicatedStorage/Forge/UI/...")` (the UI kit, `roblox/src/shared/UI`) work;
- relative requires resolve on disk from the scene file, e.g. MockEnv from `scenes/`:
  `require("../../../../roblox/tests/mocks/MockEnv")`; absolute paths are rejected (harness rule);
- globals are the harness ones (`Instance`, `Enum`, `UDim2`, `Color3`, `Font`, `ColorSequence`,
  `NumberSequence`, `Vector2`, `task`, ...); `game`/`workspace`/`script` raise — use a MockEnv.
- The scene's own thread drives MockEnv virtual time (`env.wait` advances at once), as in a test.

Example with the real FORGE-03 modules (checked during development against the UI modules of
2026-10-12; adapt to their current API):

```lua
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Layout = require("@game/ReplicatedStorage/Forge/UI/Layout")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")

return function(ctx)
	Create.useTestConnector() -- event props ([Create.Event.Activated]) need it: Lune instances have no events
	local m = Layout.compute(ctx.core.width, ctx.core.height)
	local gui = Create("ScreenGui", { Name = "Hud", ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(math.floor(m.width), math.floor(m.height)), -- offsets must be integers
		Parent = gui,
	}, { Create("UIScale", { Scale = m.scale }), Style.text({ text = "Hello" }) })
	return { guis = { gui } }
end
```

## Snapshot format

`out/<scene>-<device>.json`: `{ tool, version, scene, scenePath, device, areas, guis, errors,
warnings, modules }`. Each node: `{ class, name, kind, props, children, unread?, defaulted? }`
with `kind` = `layer` (ScreenGui) / `gui` (GuiObject) / `modifier` (UIComponent) / `folder` /
`other` (not drawn). Children keep instance order. Values: UDim2 `{xs,xo,ys,yo}`, UDim `{s,o}`,
Vector2 `{x,y}`, Color3 `"#rrggbb"`, EnumItem name, Font `{family,weight,style}`, ColorSequence
`[{t,c}]`, NumberSequence `[{t,v,e}]`, Rect `{minX,minY,maxX,maxY}`, infinity `"inf"`. Properties
are read with `pcall`; `unread` lists what Lune could not read, `defaulted` what got the Roblox
default instead (below). `modules` lists every module the scene loaded (provenance).

Recorded: ScreenGui (Enabled, DisplayOrder, ScreenInsets, IgnoreGuiInset, ZIndexBehavior,
ClipToDeviceSafeArea, SafeAreaCompatibility); every GuiObject (Size, Position, AnchorPoint,
BackgroundColor3/Transparency, BorderColor3/Mode/SizePixel, Visible, ZIndex, LayoutOrder,
ClipsDescendants, Rotation, AutomaticSize, SizeConstraint); text (Text, TextColor3,
TextTransparency, TextSize, FontFace, TextX/YAlignment, TextWrapped, TextScaled, TextTruncate,
RichText, LineHeight, TextStrokeColor3/Transparency, MaxVisibleGraphemes; TextBox placeholder);
images (Image, ImageColor3, ImageTransparency, ScaleType, SliceCenter, SliceScale, TileSize,
ImageRectOffset/Size, ResampleMode); ScrollingFrame (CanvasSize, AutomaticCanvasSize,
ScrollingDirection, ScrollBarThickness, CanvasPosition, scroll bar colour/transparency/insets/
position); CanvasGroup (GroupTransparency, GroupColor3); UICorner, UIStroke, UIGradient,
UIPadding, UIListLayout (incl. Wraps, HorizontalFlex, VerticalFlex, ItemLineAlignment),
UIGridLayout, UIScale, UISizeConstraint, UIAspectRatioConstraint, UITextSizeConstraint,
UIFlexItem. Unknown classes: whatever of those is readable.

## Images

`rbxassetid://` content cannot be downloaded headless, so images draw as a hatched, labelled
placeholder (`#<id>`, tinted by ImageColor3). To draw a real file, create `assets.json` here:

```json
{ "123456789": "../icons/png/gold.png", "rbxassetid://987654321": "/abs/path/crown.png" }
```

Keys are the full `Image` string or its numeric id; paths are relative to this folder (or absolute,
or `file://` URLs). An `Image` that is itself a `file://` URL is drawn directly. Mapped images
support ScaleType Stretch / Fit / Crop / Tile / Slice, ImageRectOffset/Size, ImageColor3 (not on
Slice) and ImageTransparency. Empty `Image` draws nothing, as in Roblox.

## Emulation rules

Layout is computed by `engine.js` itself (Roblox rules, not CSS flow); the browser only measures
and draws text.

- **ScreenGui placement**: None = whole device; DeviceSafeInsets = minus device insets;
  CoreUISafeInsets = also below the top bar (top = max(inset.top, topbar)); TopbarSafeInsets =
  the band y ∈ [inset.top, topbar], x from inset.left + controls to width − inset.right.
  `IgnoreGuiInset = true` with CoreUISafeInsets acts as DeviceSafeInsets (the engine couples the
  two properties; Lune does not). `ClipToDeviceSafeArea` (default true) clips to the device safe
  area unless ScreenInsets is None. Stacked by DisplayOrder (ties: order returned by the scene).
  `Enabled = false` is not drawn. Roblox's two top-bar buttons are drawn above everything.
- **GuiObject**: `Position`/`Size` UDim2 against the parent's content box (parent size minus its
  UIPadding; padding scale is relative to the parent's size); `SizeConstraint` RelativeXX/YY;
  `AnchorPoint`; `Rotation` about the centre; `Visible = false` → not drawn and not laid out;
  `ZIndex` orders siblings (Sibling behaviour; ties keep instance order); children always above
  their parent; `ClipsDescendants` clips to the rectangle; ScrollingFrame and CanvasGroup always clip.
- **AutomaticSize** X / Y / XY: `Size` is the minimum; content = text bounds, children extents or
  the layout's content size, plus padding. A wrapped text with AutomaticSize X wraps at
  `UISizeConstraint.MaxSize.X` if set.
- **UISizeConstraint** clamps (after AutomaticSize); **UIAspectRatioConstraint**: FitWithinMaxSize
  shrinks one axis; ScaleWithParentSize keeps the DominantAxis.
- **UIScale**: the object's size × Scale about its AnchorPoint (a W×H Root at (0,0) with UIScale
  s covers W·s × H·s from the top-left); the whole subtree (strokes, corners, text) scales.
- **UIListLayout**: Position of items ignored, Size applies; sort by LayoutOrder (ties: instance
  order) or Name; `Padding` (scale = share of the parent's size along the fill direction);
  HorizontalAlignment / VerticalAlignment place the group along the fill direction and each item
  across it; `Wraps`; `HorizontalFlex`/`VerticalFlex` (Fill, SpaceBetween, SpaceAround,
  SpaceEvenly); `ItemLineAlignment` (Start, Center, End, Stretch); UIFlexItem Grow / Shrink /
  Fill / Custom ratios.
- **UIGridLayout**: fixed cells (CellSize / CellPadding against the parent's content box), as
  many per row (or column) as fit, `FillDirectionMaxCells`, alignment of the grid block,
  `StartCorner`, SortOrder.
- **ScrollingFrame**: children laid out on the canvas (CanvasSize against the frame size, at least
  the frame size; AutomaticCanvasSize grows it to the content), shifted by CanvasPosition (clamped
  to the scroll range); a scroll bar (ScrollBarThickness, colour, transparency) where the canvas
  is larger than the frame in a scrolling direction.
- **Paint**: background = BackgroundColor3 at 1 − BackgroundTransparency; legacy border
  (BorderSizePixel, BorderColor3, BorderMode Outline/Middle/Inset) only when the background is
  drawn and there is no UICorner or border UIStroke; **UICorner** radius = scale × the smaller
  side + offset, capped at half the smaller side (pill); **UIStroke** Border (or any UIStroke on a
  non-text object): a ring outside the box (BorderStrokePosition Outer / Center / Inner,
  BorderOffset), following the corner radius, outer corners rounded by the thickness for the Round
  join; Contextual on text: an outline around the glyphs; Transparency independent of the
  background. **UIGradient**: colours multiplied into the background (and into the text colour on
  text objects), Transparency sequence multiplied into the alpha, Rotation (0 = left→right,
  90 = top→bottom), Offset. **CanvasGroup**: GroupTransparency on the composited group.
- **Text**: FontFace family (GrenzeGotisch / Merriweather / Montserrat are the real fonts;
  BuilderSans and Gotham → Montserrat; Arial, LegacyArial, SourceSansPro, Roboto → Liberation
  Sans), weight (Thin 100 … Heavy 900), style; TextSize px with line height TextSize × LineHeight;
  colour and transparency; X/Y alignment; TextWrapped (lines that do not fit are not drawn, at
  least one line is); TextTruncate → ellipsis (single line or last visible line); TextScaled →
  largest size 1–100 that fits (wraps; UITextSizeConstraint clamps); RichText subset (`b i u s br
  font(color,size,weight,transparency) uc sc mark`, entities); MaxVisibleGraphemes (plain text);
  TextStrokeTransparency/Color3; emoji and symbols through Noto Color Emoji; TextBox shows
  PlaceholderText when empty.
- **Folder**: its GuiObjects are drawn as children of the Folder's parent, outside any layout.
- **Unknown classes** (ViewportFrame, VideoFrame, ...): a plain box with their background, a
  dashed outline and the class name. Unknown modifiers (UIPageLayout, UITableLayout, ...) are
  ignored with a note.

## Known deviations from Roblox

Things this tool does differently from (or cannot know about) the engine. "Unverified" = engine
behaviour not stated in creator-docs; the emulation follows the most likely behaviour and needs a
Studio check.

**From Lune (the snapshot side)**
1. Properties the code never sets have **Lune's defaults** (its reflection database), which can
   differ from Roblox's: `ScreenGui.ZIndexBehavior` Global (Roblox docs: Sibling), list/grid
   `SortOrder` Name, TextLabel `TextSize` 8, `TextColor3` #1B2A35, `FontFace` LegacyArial,
   `BackgroundColor3` #A3A2A5, `BorderSizePixel` 1. Set what matters explicitly; the renderer
   notes Global ZIndexBehavior (drawn as Sibling), Name sort order and LegacyArial.
2. Lune cannot read `UICorner.CornerRadius`, `Image` and `ScreenGui.IgnoreGuiInset` until they
   are set: the snapshot records Roblox's defaults (UDim(0, 8), "", false) and lists them in
   `defaulted`.
3. No engine runs under Lune: `AbsoluteSize`, `AbsolutePosition`, `TextBounds` cannot be read,
   instance events do not exist (use `Create.useTestConnector()`), and `Changed`-style signals
   are not provided (`roblox/README.md`). UI code that reads these fails in a scene.
4. **UDim offsets must be integers** in Lune (`UDim2.fromOffset(10.5, 0)` errors); Roblox stores
   Offset as int32 and accepts fractions. Round/floor computed offsets (e.g. `Layout.compute`
   results divided by a scale).
5. Writing the legacy `Font` property is accepted but does not update `FontFace` (in Roblox it
   does); reading `Font` fails. Use `FontFace`.

**Layout**
6. ZIndexBehavior Global is drawn with Sibling rules (a note is printed when ZIndex values differ).
7. UIScale pivot = the AnchorPoint (creator-docs only say it multiplies AbsoluteSize; unverified).
   UIScale directly under a ScreenGui scales the whole layer from its top-left (unverified).
8. AutomaticSize: children are measured against the provisional (minimum) size, so scale-sized
   children never make an automatic axis grow; exact engine rules unverified.
9. UIListLayout: AnchorPoint of items is ignored; wrapped lines are separated by Padding; flex
   shrink is weighted by item size (as CSS); `Name` sort is a plain code-point comparison; the
   cross-axis Flex property is ignored. All unverified details.
10. UIGridLayout: a partial last row is left-aligned inside the aligned grid block (unverified);
    a UISizeConstraint making an item span several cells, constraints parented to the grid
    layout, and item UIScale are not emulated.
11. ScrollingFrame: the canvas is never smaller than the frame (unverified, but required for the
    common `CanvasSize = 0` + AutomaticCanvasSize pattern); the scroll bar is a plain rounded bar
    over the content (`VerticalScrollBarInset`/`HorizontalScrollBarInset` ignored; Roblox draws
    its default bar images); no elastic overscroll.
12. ClipsDescendants also clips when the object or an ancestor is rotated (Roblox ignores it then
    unless `StarterGui.ClipsDescendantsSupportsRotation`); CanvasGroup clips to its rounded
    corners.
13. `SafeAreaCompatibility` (automatic extension of "fullscreen" objects into cutouts) is not
    emulated. The top-bar geometry is an estimate (see Devices).
14. Folder: GuiObjects inside a Folder are drawn as children of its parent and left out of layouts
    (unverified).
15. UIPadding directly under a ScreenGui is applied (unverified).

**Paint**
16. Text is shaped and drawn by Chromium, not Roblox's text engine: TextSize → CSS px 1:1
    (creator-docs: TextSize is the height of one line; LineHeight a multiple of the em); glyph
    metrics, kerning and wrap points can differ by a few px. Truncation draws "…" (Roblox "..."),
    AtEnd and SplitWord are not distinguished. Rich text: `<stroke>` without its outline, `font
    face/family` ignored, mixed sizes keep the label's line height.
17. Fonts other than Grenze Gotisch / Merriweather / Montserrat are stand-ins (BuilderSans and
    Gotham → Montserrat, Arial family → Liberation Sans; printed as notes). Emoji use Noto Color
    Emoji (Roblox ships its own emoji font); symbols missing from the font (e.g. ◀) also fall back
    to it and can appear as colour emoji.
18. UIStroke: Bevel join drawn as Miter; StrokeSizingMode ScaledSize drawn as px; a UIGradient on
    a stroke is drawn as its middle colour; UIStroke.ZIndex ignored (stroke above the object's own
    background, below its text and children); only the first text (Contextual) stroke is drawn;
    legacy TextStroke is a 1 px 8-direction outline.
19. UIGradient: exact for Rotation multiples of 90; other angles use CSS's gradient line; Offset is
    projected on the gradient direction; Type Radial/Conical drawn linear; Scale/TileMode ignored;
    a gradient on an image is not applied.
20. The legacy border is hidden when a UICorner is present (unverified).
21. Images: placeholders unless mapped in `assets.json`; ResampleMode ignored; Slice ignores
    ImageColor3. CanvasGroup `GroupColor3` tint is ignored.
22. No interaction states: hover/press colours (AutoButtonColor), Selected, TextBox cursor, tweens
    in flight. Only the property values present after `settle()` are drawn.

## Files

| File | What |
|---|---|
| `snapshot.luau` | Lune: run a scene through the harness loader, serialise its ScreenGuis to JSON |
| `render.js` | Node: snapshot JSON → HTML page → Playwright screenshot + layout dump |
| `engine.js` | in-page Roblox layout + paint emulation (used by render.js) |
| `devices.json` | emulated devices (shared with the prototypes' numbers) |
| `shoot-luau.sh` | snapshot + render for scenes × devices |
| `scenes/selftest.luau`, `scenes/selftest.expect.md` | renderer self-test and what it must look like |
| `assets.json` (optional, not committed by default) | asset id → local image file |
