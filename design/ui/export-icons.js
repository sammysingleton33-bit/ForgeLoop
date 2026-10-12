// Writes icons/<name>.svg, icons/png/<name>.png (128 px, transparent) and screenshots/icons-sheet.png.
// Run from design/ui: node export-icons.js   (Playwright = the preinstalled global; never npm install it)
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const Icons = require("./icons.js");

const here = __dirname;
const outSvg = path.join(here, "icons");
const outPng = path.join(here, "icons", "png");
const shots = path.join(here, "screenshots");
for (const dir of [outSvg, outPng, shots]) fs.mkdirSync(dir, { recursive: true });

(async () => {
	const browser = await chromium.launch();
	const page = await browser.newPage({ viewport: { width: 128, height: 128 } });
	for (const name of Icons.names) {
		const svg = Icons.svg(name);
		fs.writeFileSync(path.join(outSvg, `${name}.svg`), svg + "\n");
		await page.setContent(
			`<html><body style="margin:0;background:transparent">${Icons.svg(name, 128)}</body></html>`
		);
		await page.locator("svg").screenshot({ path: path.join(outPng, `${name}.png`), omitBackground: true });
	}
	const cells = Icons.names
		.map(
			(n) => `<figure>
				<div class="tile dark">${Icons.svg(n, 48)}</div>
				<div class="tile light">${Icons.svg(n, 48)}</div>
				<div class="tile small">${Icons.svg(n, 24)}</div>
				<figcaption>${n}</figcaption></figure>`
		)
		.join("");
	const sheet = await browser.newPage({ viewport: { width: 1200, height: 800 } });
	await sheet.setContent(`<html><head><style>
		body{margin:0;padding:16px;background:#18202F;font:12px Montserrat,sans-serif;color:#F4ECD8;display:flex;flex-wrap:wrap;gap:10px}
		figure{margin:0;display:grid;grid-template-columns:repeat(3,auto);gap:4px;align-items:center;justify-items:center;width:168px}
		figcaption{grid-column:1/4}
		.tile{width:56px;height:56px;display:flex;align-items:center;justify-content:center;border-radius:8px}
		.dark{background:#0B0F18}.light{background:#EADCBA}.small{background:#212B3F}
	</style></head><body>${cells}</body></html>`);
	await sheet.screenshot({ path: path.join(shots, "icons-sheet.png"), fullPage: true });
	await browser.close();
	console.log(`exported ${Icons.names.length} icons`);
})();
