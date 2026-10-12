// Screenshots every prototype scene and the component sheet (kit.html) at phone 844x390, tablet 1024x768 and desktop 1920x1080.
// Run from design/ui: node shoot.js [sceneFilter]   (Playwright = the preinstalled global; never npm install it)
const path = require("path");
const fs = require("fs");
const { chromium } = require("playwright");

const SIZES = { phone: [844, 390], tablet: [1024, 768], desktop: [1920, 1080] };
const SCENES = ["hud", "build", "build-detail", "build-short", "build-locked", "built", "kingdom", "kingdom-buildings", "upgrade"];
const filter = process.argv[2];
const out = path.join(__dirname, "screenshots", "prototype");
fs.mkdirSync(out, { recursive: true });

(async () => {
	const browser = await chromium.launch();
	for (const [size, [w, h]] of Object.entries(SIZES)) {
		const page = await browser.newPage({ viewport: { width: w, height: h } });
		for (const scene of SCENES) {
			if (filter && !scene.includes(filter) && size !== filter) continue;
			for (const guides of [false, true]) {
				if (guides && scene !== "hud" && scene !== "build") continue;
				const url = "file://" + path.join(__dirname, "prototype", "kingdom.html") + `?size=${size}&scene=${scene}${guides ? "&guides=1" : ""}`;
				await page.goto(url);
				await page.evaluate(() => window.__ready);
				const file = path.join(out, `${scene}${guides ? "-guides" : ""}-${size}.png`);
				await page.screenshot({ path: file });
				console.log(path.relative(__dirname, file));
			}
		}
		await page.close();
		if (filter && filter !== "kit" && filter !== size) continue;
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
