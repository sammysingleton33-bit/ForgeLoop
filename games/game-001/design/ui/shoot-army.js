// Screenshots every FL-0060 prototype scene at phone 844x390, tablet 1024x768 and desktop 1920x1080.
// Run from games/game-001/design/ui: node shoot-army.js [filter]   (Playwright = the preinstalled global; never npm install it)
// Writes screenshots/prototype/army-<scene>[-guides]-<size>.png
const path = require("path");
const fs = require("fs");
const { chromium } = require("playwright");

const SIZES = { phone: [844, 390], tablet: [1024, 768], desktop: [1920, 1080] };
const SCENES = ["hud", "hud-open", "army", "army-short", "army-none", "army-sent", "army-nobarracks", "upgrade-tab", "summary", "summary-win", "summary-none"];
const GUIDES = ["hud", "army", "summary"]; // also shot with the device insets and the 44 px hit areas drawn
const filter = process.argv[2];
const out = path.join(__dirname, "screenshots", "prototype");
fs.mkdirSync(out, { recursive: true });

(async () => {
	const browser = await chromium.launch();
	for (const [size, [w, h]] of Object.entries(SIZES)) {
		const page = await browser.newPage({ viewport: { width: w, height: h } });
		page.on("pageerror", (e) => {
			console.error(`${size}: ${e.message}`);
			process.exitCode = 1;
		});
		for (const scene of SCENES) {
			if (filter && !scene.includes(filter) && size !== filter) continue;
			for (const guides of [false, true]) {
				if (guides && !GUIDES.includes(scene)) continue;
				const url = "file://" + path.join(__dirname, "army.html") + `?size=${size}&scene=${scene}${guides ? "&guides=1" : ""}`;
				await page.goto(url);
				await page.evaluate(() => window.__ready);
				const file = path.join(out, `army-${scene}${guides ? "-guides" : ""}-${size}.png`);
				await page.screenshot({ path: file });
				console.log(path.relative(__dirname, file));
			}
		}
		await page.close();
	}
	await browser.close();
})();
