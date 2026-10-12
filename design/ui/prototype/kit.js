// Component sheet: the 10 kit components x their states (FORGE-03, FL-0020).
// kit.html?size=phone|tablet|desktop renders at that breakpoint's scale (1 / 1.1 / 1.2).
(function () {
	const T = window.TOKENS;
	const I = (n, s) => window.Icons.svg(n, s);
	const size = new URLSearchParams(location.search).get("size") || "desktop";
	const scale = { phone: 1, tablet: 1.1, desktop: 1.2 }[size];

	const btn = (variant, state, label, icon) => {
		const cls = state === "disabled" ? "disabled" : variant;
		const inner = state === "loading" ? `<span class="spin"></span>${label}…` : `${icon ? I(icon, 20) : ""}${label}`;
		return `<div class="btn ${cls} ${state === "pressed" ? "pressed" : ""}">${inner}</div>`;
	};
	const iconBtn = (icon, label, o = {}) =>
		`<div class="railbtn ${o.sel ? "sel" : ""}" style="width:58px;height:58px;${o.disabled ? "opacity:.45" : ""}${o.pressed ? ";transform:translateY(2px);box-shadow:0 1px 0 rgba(5,7,12,.5)" : ""}">${I(o.locked ? "lock" : icon, 30)}<div class="lbl">${label}</div>${o.count ? `<div class="count">${o.count}</div>` : ""}</div>`;
	const pill = (res, amt, o = {}) =>
		`<div class="pill ${o.compact ? "compact" : ""} ${o.full ? "full" : ""} ${o.flash ? "flash-" + o.flash : ""}" style="position:relative">
			<div class="medallion" style="width:${o.compact ? 24 : 28}px;height:${o.compact ? 24 : 28}px;background:linear-gradient(180deg, ${T.resource[res]} 0%, color-mix(in srgb, ${T.resource[res]} 55%, #0B0F18) 100%)">${I(res, o.compact ? 19 : 22)}</div>
			<div class="stack"><div class="amt">${amt}${o.cap ? `<small> / ${o.cap}</small>` : ""}</div>${o.rate != null ? `<div class="rate ${o.rate ? "" : "zero"}">+${o.rate}/min</div>` : ""}</div>
			${o.delta ? `<div class="delta ${o.delta < 0 ? "neg" : "pos"}">${o.delta > 0 ? "+" : "−"}${Math.abs(o.delta)}</div>` : ""}</div>`;
	const card = (item, rarity, o = {}) =>
		o.empty
			? `<div class="card empty" style="width:104px;height:128px"><div class="note">Empty slot</div></div>`
			: `<div class="card" style="--r:${T.rarity[rarity]};width:104px;height:128px;${o.locked ? "opacity:.55" : ""}">
				${o.owned ? `<div class="owned">${I("check", 20)}</div>` : ""}${o.locked ? `<div class="owned">${I("lock", 20)}</div>` : ""}
				${I(item.icon, 56)}<div class="cn">${item.name}</div><div class="cr">${rarity}</div></div>`;
	const toast = (kind, icon, title, body) => {
		const k = { success: "var(--color-vert)", error: "var(--color-gules)", info: "var(--color-azure)", reward: "var(--color-gold400)", warning: "var(--color-amber)" }[kind];
		return `<div class="toast" style="--k:${k};width:300px">${I(icon, 28)}<div><div class="tt">${title}</div>${body ? `<div class="tb">${body}</div>` : ""}</div></div>`;
	};
	const bar = (pct, label, color) => `<div class="bar tall" style="width:220px"><i style="width:${pct}%;${color ? `background:${color}` : ""}"></i>${label ? `<div class="bl">${label}</div>` : ""}</div>`;
	const section = (title, body, note) => `<section><h2>${title}</h2>${note ? `<p class="note">${note}</p>` : ""}<div class="items">${body}</div></section>`;
	const lbl = (t, html) => `<div class="cell"><div class="cl">${t}</div>${html}</div>`;

	const items = [
		{ name: "Oak Banner", icon: "banner" },
		{ name: "Lion Banner", icon: "banner" },
		{ name: "Dragon Banner", icon: "banner" },
		{ name: "Phoenix Crest", icon: "crest" },
		{ name: "Sun Crest", icon: "crest" },
	];
	const rar = ["Common", "Uncommon", "Rare", "Epic", "Legendary"];

	const html = [
		section(
			"Button",
			["primary", "secondary", "danger", "success"]
				.map((v) => ["default", "pressed", "disabled", "loading"].map((st) => lbl(`${v} · ${st}`, btn(v, st, v === "danger" ? "Demolish" : v === "success" ? "Done" : v === "secondary" ? "Upgrade" : "Build", v === "primary" ? "build" : null))).join(""))
				.join(""),
			"44 px tall (touch target). Pressed = 2 px down, shadow shrinks. Loading keeps the width and blocks repeat taps."
		),
		section(
			"IconButton",
			[lbl("default", iconBtn("build", "Build")), lbl("selected", iconBtn("build", "Build", { sel: true })), lbl("pressed", iconBtn("kingdom", "Kingdom", { pressed: true })), lbl("badge", iconBtn("kingdom", "Kingdom", { count: 2 })), lbl("locked", iconBtn("army", "Army", { locked: true })), lbl("disabled", iconBtn("standings", "Ranks", { disabled: true }))].join("")
		),
		section(
			"CurrencyPill",
			[lbl("full", pill("food", 136, { cap: 500, rate: 18 })), lbl("compact (phone)", pill("wood", 85, { compact: true })), lbl("spent (delta)", pill("wood", 35, { cap: 500, rate: 18, delta: -50, flash: "neg" })), lbl("gained (delta)", pill("gold", 62, { cap: 300, rate: 3, delta: 12, flash: "pos" })), lbl("at cap", pill("stone", 300, { cap: 300, rate: 4, full: true })), lbl("loading", pill("gold", "…", { cap: "—" })), lbl("error / unknown", pill("food", "—"))].join("")
		),
		section("ProgressBar", [lbl("empty", bar(0, "0:18")), lbl("in progress", bar(45, "0:07")), lbl("complete", bar(100, "Ready", "linear-gradient(180deg,#78C57B,#5BAE5F)")), lbl("storage fill", bar(27, "136 / 500", T.resource.food))].join("")),
		section(
			"Tabs",
			lbl("default / selected / disabled", `<div class="tabs"><div class="tab sel">${I("food", 18)}Economy</div><div class="tab">${I("house", 18)}Civic</div><div class="tab" style="opacity:.45">${I("lock", 16)}Military</div></div>`) + lbl("icon-only (phone)", `<div class="tabs"><div class="tab sel">${I("food", 18)}Economy</div><div class="tab">${I("house", 18)}</div><div class="tab">${I("army", 18)}</div></div>`)
		),
		section(
			"ItemCard + Grid",
			`<div class="grid">${items.map((it, i) => card(it, rar[i], { owned: i === 0 })).join("")}${card(items[2], "Rare", { locked: true })}${card(null, null, { empty: true })}</div>`,
			"Rarity frame colours: Common argent, Uncommon vert, Rare azure, Epic purpure, Legendary or. Rarity is always written as text too (never colour only)."
		),
		section("Toast", [toast("success", "check", "Quarry construction started", "Ready in 0:18"), toast("info", "info", "Town Hall reached level 2", "Gold Mine and Barracks unlocked"), toast("warning", "warning", "Storage full", "Build a Storehouse to keep more Wood"), toast("error", "cross", "Couldn't start construction", "Not enough Wood: need 20 more"), toast("reward", "chest", "Royal Chest opened", "Lion Banner (Uncommon)")].map((t) => `<div class="cell">${t}</div>`).join("")),
		section(
			"Panel · empty / loading / error states",
			[
				`<div class="panel" style="position:relative;width:300px;height:170px;padding:12px"><div class="dtitle" style="font-size:22px">Buildings</div><div class="ornament"></div><div style="display:flex;flex-direction:column;align-items:center;gap:6px;margin-top:6px">${I("build", 36)}<div class="tt" style="font:700 13px var(--font-body)">No buildings yet</div><div class="note">Open Build to place your first Farm.</div></div></div>`,
				`<div class="panel" style="position:relative;width:300px;height:170px;padding:12px"><div class="dtitle" style="font-size:22px">Buildings</div><div class="ornament"></div>${[0, 1, 2].map(() => `<div style="height:30px;margin-top:6px;border-radius:8px;background:linear-gradient(90deg,#212B3F,#2C3953 50%,#212B3F)"></div>`).join("")}</div>`,
				`<div class="panel" style="position:relative;width:300px;height:170px;padding:12px"><div class="dtitle" style="font-size:22px">Buildings</div><div class="ornament"></div><div style="display:flex;flex-direction:column;align-items:center;gap:8px;margin-top:4px">${I("warning", 32)}<div class="note" style="color:var(--color-textSecondary)">Couldn't load your kingdom.</div><div class="btn secondary small">Retry</div></div></div>`,
			]
				.map((p) => `<div class="cell">${p}</div>`)
				.join("")
		),
		section(
			"Modal (confirm a large spend)",
			`<div style="position:relative;width:520px;height:250px;border-radius:12px;overflow:hidden;background:#6E9A4E"><div class="scrim"></div>
			<div class="panel" style="left:60px;top:22px;width:400px;height:206px;padding:14px"><div class="dtitle" style="font-size:24px">Upgrade Town Hall?</div><div class="ornament"></div>
			<div class="ddesc" style="margin-top:2px">This spends most of your treasury. Level 2 unlocks the Gold Mine and Barracks.</div>
			<div class="costs" style="margin-top:8px"><div class="crow">${I("wood", 18)}<span class="n">Wood</span><span class="v">150</span><span class="h">of 180</span></div><div class="crow">${I("stone", 18)}<span class="n">Stone</span><span class="v">100</span><span class="h">of 120</span></div></div>
			<div style="display:flex;gap:10px;margin-top:12px"><div class="btn secondary" style="flex:1">Cancel</div><div class="btn primary" style="flex:1">${I("build", 20)}Upgrade</div></div></div></div>`,
			"Shown when one action spends 50% or more of any resource, and always before a Robux purchase."
		),
	].join("");

	document.body.innerHTML = `<div id="sheet" style="transform:scale(${scale});transform-origin:0 0;width:${Math.round(window.innerWidth / scale)}px">
		<header><div class="dtitle" style="font-size:34px">AI Kingdoms · UI kit</div><div class="note">${size} · scale ${scale} · tokens from design/ui/tokens.json</div></header>${html}</div>`;
	window.__ready = document.fonts.ready.then(() => {
		const h = document.getElementById("sheet").getBoundingClientRect().height;
		document.body.style.height = h + "px";
		return true;
	});
})();
