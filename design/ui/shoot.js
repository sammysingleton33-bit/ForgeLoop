// Screenshots the component sheet (kit.html) at phone 844x390, tablet 1024x768 and desktop 1920x1080.
// Run from design/ui: node shoot.js   (Playwright = the preinstalled global; never npm install it)
// Game screens have their own prototypes and shoot scripts (games/<game>/design/ui/).
const path = require("path");
const fs = require("fs");
const { chromium } = require("playwright");

const SIZES = { phone: [844, 390], tablet: [1024, 768], desktop: [1920, 1080] };
const out = path.join(__dirname, "screenshots", "prototype");
fs.mkdirSync(out, { recursive: true });

(async () => {
	const browser = await chromium.launch();
	for (const [size, [w, h]] of Object.entries(SIZES)) {
		const kit = await browser.newPage({ viewport: { width: w, height: h } });
		await kit.goto("file://" + path.join(__dirname, "prototype", "kit.html") + `?size=${size}`);
		await kit.evaluate(() => window.__ready);
		const file = path.join(out, `kit-${size}.png`);
		await kit.screenshot({ path: file, fullPage: true });
		console.log(path.relative(__dirname, file));
		await kit.close();
	}
	await browser.close();
})();
