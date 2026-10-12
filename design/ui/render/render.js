#!/usr/bin/env node
/*
	render.js — screenshot Luau UI snapshots (from snapshot.luau) with a Roblox-layout emulation.

		node design/ui/render/render.js [snapshot.json ...] [--guides] [--debug] [--backdrop=world|plain] [--dpr=2] [--shots=<dir>]

	Default input: every design/ui/render/out/*.json snapshot. For each it writes
	  design/ui/screenshots/luau/<scene>-<device>.png    the screenshot (viewport = device size; 1x, or --dpr)
	  design/ui/render/out/<scene>-<device>.html         the page (open it in a browser to inspect)
	  design/ui/render/out/<scene>-<device>.layout.json  absolute rect of every GuiObject (device px),
	                                                     comparable with AbsolutePosition/AbsoluteSize
	Playwright is the preinstalled global (never npm install it).

	Emulation (engine.js does the layout itself; the browser only measures and draws text):
	- ScreenGui rect from ScreenInsets: None = device; DeviceSafeInsets = minus device insets;
	  CoreUISafeInsets = also below the top bar (top = max(inset.top, topbar)); TopbarSafeInsets =
	  the top bar band right of the Roblox controls. IgnoreGuiInset=true turns CoreUISafeInsets into
	  DeviceSafeInsets. ClipToDeviceSafeArea clips to the device safe area. Stacked by DisplayOrder.
	  Enabled=false is not drawn. Roblox's two top-bar buttons are drawn on top (CoreGui).
	- GuiObjects: Position/Size UDim2 against the parent's content box (UIPadding removed),
	  SizeConstraint, AnchorPoint, Rotation (about the centre), Visible, ZIndex among siblings
	  (ZIndexBehavior Sibling), ClipsDescendants (rectangular), AutomaticSize (Size is the minimum;
	  content = text bounds / children / layout content + padding), UISizeConstraint,
	  UIAspectRatioConstraint, UIScale (size x Scale about the AnchorPoint; the subtree is scaled).
	- UIListLayout (order, padding, alignment, Wraps, HorizontalFlex/VerticalFlex, ItemLineAlignment,
	  UIFlexItem), UIGridLayout (cells, padding, alignment, StartCorner, FillDirectionMaxCells).
	- Paint: background rgba; legacy border (BorderSizePixel/BorderMode, not with UICorner or a
	  border UIStroke); UICorner (scale part of the smaller side, capped at a pill); UIStroke
	  (Border: drawn outside the box, Round join; Contextual on text: text outline); UIGradient
	  (multiplied into the background / text colour; transparency sequence); images as labelled
	  placeholders unless design/ui/render/assets.json maps them to a local file; text with the
	  FORGELOOP fonts, alignment, wrapping, truncation, TextScaled, basic RichText.
	Every known deviation from Roblox: README.md "Known deviations". This is a headless
	approximation, not a substitute for the Studio check (gate G6).
*/
const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

const RENDER_DIR = __dirname;
const UI_DIR = path.dirname(RENDER_DIR);
const OUT_DIR = path.join(RENDER_DIR, "out");

function parseArgs(argv) {
	const opts = { guides: false, debug: false, backdrop: "world", dpr: 1, shots: path.join(UI_DIR, "screenshots", "luau"), files: [] };
	for (const a of argv) {
		if (a === "--guides") opts.guides = true;
		else if (a === "--debug") opts.debug = true;
		else if (a.startsWith("--backdrop=")) opts.backdrop = a.slice(11);
		else if (a.startsWith("--shots=")) opts.shots = path.resolve(a.slice(8));
		else if (a.startsWith("--dpr=")) opts.dpr = Math.max(1, Number(a.slice(6)) || 1);
		else if (a === "-h" || a === "--help") {
			console.log(fs.readFileSync(__filename, "utf8").split("*/")[0]);
			process.exit(0);
		} else if (a.startsWith("--")) {
			console.error(`render.js: unknown option ${a}`);
			process.exit(2);
		} else opts.files.push(path.resolve(a));
	}
	if (!opts.files.length && fs.existsSync(OUT_DIR)) {
		opts.files = fs
			.readdirSync(OUT_DIR)
			.filter((f) => f.endsWith(".json") && !f.endsWith(".layout.json"))
			.sort()
			.map((f) => path.join(OUT_DIR, f));
	}
	return opts;
}

// @font-face for every weight/style of the three FORGELOOP families that is installed.
function fontFaces() {
	const families = [
		["Grenze Gotisch", "grenze-gotisch"],
		["Merriweather", "merriweather"],
		["Montserrat", "montserrat"],
	];
	const out = [];
	for (const [family, pkg] of families) {
		for (let w = 100; w <= 900; w += 100) {
			for (const style of ["normal", "italic"]) {
				const file = path.join(UI_DIR, "node_modules", "@fontsource", pkg, "files", `${pkg}-latin-${w}-${style}.woff2`);
				if (fs.existsSync(file)) {
					out.push(`@font-face { font-family: "${family}"; font-weight: ${w}; font-style: ${style}; src: url("${pathToFileURL(file).href}") format("woff2"); }`);
				}
			}
		}
	}
	if (!out.length) console.warn("render.js: no @fontsource fonts found under design/ui/node_modules — text uses fallbacks");
	return out.join("\n");
}

// assets.json: { "<Image string or numeric id>": "<file path relative to design/ui/render, absolute, or file:// URL>" }
function loadAssets() {
	const file = path.join(RENDER_DIR, "assets.json");
	if (!fs.existsSync(file)) return {};
	const raw = JSON.parse(fs.readFileSync(file, "utf8"));
	const out = {};
	for (const [key, value] of Object.entries(raw)) {
		if (key.startsWith("_") || typeof value !== "string") continue;
		if (value.startsWith("file://")) out[key] = value;
		else {
			const abs = path.isAbsolute(value) ? value : path.join(RENDER_DIR, value);
			if (!fs.existsSync(abs)) console.warn(`render.js: assets.json ${key} -> ${value}: file not found`);
			out[key] = pathToFileURL(abs).href;
		}
	}
	return out;
}

const CSS = `
html, body { margin: 0; padding: 0; background: #000; }
#vp { position: relative; overflow: hidden; }
.lyr { position: absolute; }
.g { position: absolute; box-sizing: border-box; transform-origin: 0 0; isolation: isolate; }
.bg, .img, .txt, .kids { position: absolute; left: 0; top: 0; width: 100%; height: 100%; box-sizing: border-box; }
.ring, .bar, .canvas { position: absolute; box-sizing: border-box; }
.txt { display: flex; flex-direction: column; }
.txt > span { display: block; flex: none; }
.img.ph { border: 1px dashed; }
.tag { position: absolute; font: 600 9px/1.25 "Liberation Sans", sans-serif; color: #fff; padding: 0 3px; white-space: nowrap; pointer-events: none; z-index: 2147483000; }
.unknown { outline: 1px dashed rgba(255, 80, 200, 0.95); outline-offset: -1px; }
.dbg { outline: 1px dashed rgba(255, 0, 255, 0.55); outline-offset: -1px; }
.robloxbtn { position: absolute; width: 44px; height: 44px; border-radius: 22px; background: rgba(20, 20, 24, 0.55); display: flex; align-items: center; justify-content: center; font: 700 11px "Liberation Sans", sans-serif; color: #fff; z-index: 2147483100; }
.guides { position: absolute; inset: 0; z-index: 2147483200; pointer-events: none; }
.guides .band { position: absolute; background: rgba(217, 87, 63, 0.18); outline: 1px dashed rgba(217, 87, 63, 0.7); outline-offset: -1px; }
.guides .band.topbar { background: rgba(78, 139, 208, 0.16); outline-color: rgba(78, 139, 208, 0.8); }
.guides .band span { position: absolute; left: 4px; top: 2px; font: 600 10px "Liberation Sans", sans-serif; color: #fff; }
.errbanner { position: absolute; left: 0; right: 0; bottom: 0; z-index: 2147483300; background: rgba(190, 30, 30, 0.92); color: #fff; font: 700 12px/1.3 "Liberation Sans", sans-serif; padding: 4px 8px; }
.warnlist { position: absolute; left: 4px; bottom: 4px; max-width: 70%; z-index: 2147483250; background: rgba(0, 0, 0, 0.78); color: #ffd27a; font: 500 10px/1.3 "DejaVu Sans Mono", monospace; padding: 4px 6px; white-space: pre-wrap; }
`;

function pageHtml(snap, opts, assets) {
	const json = JSON.stringify(snap).replace(/</g, "\\u003c");
	const options = JSON.stringify({ guides: opts.guides, debug: opts.debug, backdrop: opts.backdrop, assets }).replace(/</g, "\\u003c");
	return `<!doctype html>
<html><head><meta charset="utf-8"><title>${snap.scene} @ ${snap.device.name}</title>
<style>
${fontFaces()}
${CSS}
</style></head>
<body><div id="vp"></div>
<script>window.SNAPSHOT = ${json};
window.RENDER_OPTIONS = ${options};</script>
<script src="${pathToFileURL(path.join(RENDER_DIR, "engine.js")).href}"></script>
</body></html>
`;
}

async function main() {
	const opts = parseArgs(process.argv.slice(2));
	if (!opts.files.length) {
		console.error("render.js: no snapshots (run snapshot.luau first, or pass JSON files)");
		process.exit(1);
	}
	const { chromium } = require("playwright");
	const assets = loadAssets();
	fs.mkdirSync(opts.shots, { recursive: true });
	fs.mkdirSync(OUT_DIR, { recursive: true });
	const browser = await chromium.launch();
	let failed = 0;
	try {
		for (const file of opts.files) {
			const snap = JSON.parse(fs.readFileSync(file, "utf8"));
			if (snap.tool !== "forgeloop-luau-snapshot") {
				console.error(`skip ${path.relative(process.cwd(), file)}: not a snapshot.luau output`);
				continue;
			}
			const base = `${snap.scene}-${snap.device.name}`;
			const htmlFile = path.join(OUT_DIR, `${base}.html`);
			fs.writeFileSync(htmlFile, pageHtml(snap, opts, assets));
			const page = await browser.newPage({ viewport: { width: snap.device.width, height: snap.device.height }, deviceScaleFactor: opts.dpr });
			const pageErrors = [];
			page.on("pageerror", (e) => pageErrors.push(String(e)));
			await page.goto(pathToFileURL(htmlFile).href);
			await page.waitForFunction(() => window.__done === true, null, { timeout: 60000 });
			const result = await page.evaluate(() => ({ error: window.__error, warnings: window.__warnings || [], layout: window.__layout || [] }));
			const png = path.join(opts.shots, `${base}.png`);
			await page.screenshot({ path: png });
			await page.close();
			fs.writeFileSync(path.join(OUT_DIR, `${base}.layout.json`), JSON.stringify(result.layout, null, "\t"));
			const snapErrors = Array.isArray(snap.errors) ? snap.errors : [];
			const snapWarnings = Array.isArray(snap.warnings) ? snap.warnings : [];
			console.log(`${path.relative(process.cwd(), png)}  (${result.layout.length} objects, ${result.warnings.length + snapWarnings.length} note(s)${snapErrors.length ? `, ${snapErrors.length} SNAPSHOT ERROR(S)` : ""})`);
			for (const w of [...snapWarnings, ...result.warnings]) console.log(`  note: ${w}`);
			for (const e of snapErrors) console.log(`  SNAPSHOT ERROR: ${String(e).split("\n")[0]}`);
			for (const e of [result.error, ...pageErrors].filter(Boolean)) {
				failed += 1;
				console.log(`  RENDER ERROR: ${e}`);
			}
		}
	} finally {
		await browser.close();
	}
	process.exit(failed ? 1 : 0);
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
