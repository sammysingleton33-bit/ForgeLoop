// AI Kingdoms (game-001) reputation strip, reputation screen and kingdom conditions prototype (FORGE-03, FL-0089).
// URL: reputation.html?size=phone|tablet|desktop&scene=<name>&guides=1
// The layout maths is the spec for the `reputation` zone added to games/game-001/src/client/UI/Layout.luau;
// the HUD drawing helpers are copied from kingdom.js (FL-0059).
// Data shapes follow CONTRACTS G13.4: Kingdom.GetReputation -> { values: { [Category]: 0..100 },
// history: { { t, category, delta, text, source } } (latest 30), kingdom: { happiness, stability, morale } }.
// Category descriptions and "what affects it" come from the content library (Content/Reputation.categories,
// FL-0083) — the texts below are SAMPLE placeholders for the prototype only; without the content the
// screen shows names, values and history and no prose.
(function () {
	const T = window.TOKENS;
	const I = (name, size) => window.Icons.svg(name, size);
	const q = new URLSearchParams(location.search);

	// ------------------------------------------------------------------ emulated devices (as kingdom.js)
	const DEVICES = {
		phone: { w: 844, h: 390, inset: { l: 47, r: 47, t: 0, b: 21 }, topbar: 58, controls: 104 },
		tablet: { w: 1024, h: 768, inset: { l: 0, r: 0, t: 0, b: 20 }, topbar: 58, controls: 104 },
		desktop: { w: 1920, h: 1080, inset: { l: 0, r: 0, t: 0, b: 0 }, topbar: 58, controls: 104 },
	};
	const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

	// Layout.compute(width, height) with the FL-0089 reputation zone (see Layout.luau).
	function layout(w, h) {
		const bp = h < 420 || w < 640 ? "phone" : w >= 1400 && h >= 760 ? "desktop" : "tablet";
		const scale = bp === "desktop" ? clamp(h / 850, 1, 1.5) : bp === "tablet" ? clamp(h / 630, 1, 1.25) : 1;
		const W = Math.floor(w / scale), H = Math.floor(h / scale);
		const phone = bp === "phone";
		const margin = phone ? 8 : 16;
		const railButton = phone ? 48 : 58;
		const hud = { x: margin, y: phone ? 6 : margin, crest: phone ? 34 : 52 };
		hud.pills = phone ? { x: hud.x + hud.crest + 8, y: hud.y + 2 } : { x: hud.x, y: hud.y + hud.crest + 8 };
		hud.members = phone ? null : { x: hud.x, y: hud.pills.y + 34 + 6 };
		const drawerRight = margin + railButton + 12;
		let drawer;
		if (phone) {
			const x = hud.x + 34 + 8 + 4 * 66 + 3 * 6 + 12;
			const width = Math.max(260, W - drawerRight - x);
			drawer = { x: W - drawerRight - width, y: hud.y, width, height: H - hud.y - margin, single: true };
		}
		// Reputation strip: phones one row of six under the crest (its Crown Points badge hangs to y + crest + 8),
		// items 50 px or narrower (down to 44) to stay left of the phone drawer; tablet/desktop 3 x 2 under the rulers.
		const rep = phone
			? { x: hud.x, y: hud.y + hud.crest + 12, columns: 6, item: { w: 50, h: 22 }, gx: 3, gy: 0, pad: 4 }
			: { x: hud.x, y: hud.members.y + 22 + 6, columns: 3, item: { w: 118, h: 22 }, gx: 8, gy: 6, pad: 6 };
		if (phone) rep.item.w = clamp(Math.floor((drawer.x - hud.x - margin - 2 * rep.pad - 5 * rep.gx) / 6), 44, 50);
		const rows = 6 / rep.columns;
		rep.width = rep.columns * rep.item.w + (rep.columns - 1) * rep.gx + 2 * rep.pad;
		rep.height = rows * rep.item.h + (rows - 1) * rep.gy + 2 * rep.pad;
		hud.reputation = rep;
		hud.bottom = rep.y + rep.height;
		if (!phone) {
			const width = bp === "tablet" ? 560 : 620;
			const y = hud.bottom + 10;
			drawer = { x: W - drawerRight - width, y, width, height: Math.min(bp === "tablet" ? 470 : 480, H - y - margin), single: false };
		}
		return { bp, scale, W, H, margin, hud, rail: { right: margin, button: railButton, gap: 10 }, drawer, toast: { width: phone ? 250 : 300 } };
	}

	function metrics(d) {
		const core = { x: d.inset.l, y: Math.max(d.inset.t, d.topbar), w: d.w - d.inset.l - d.inset.r, h: d.h - Math.max(d.inset.t, d.topbar) - d.inset.b };
		const top = { x: d.inset.l + d.controls, y: d.inset.t, w: d.w - d.inset.l - d.inset.r - d.controls, h: d.topbar };
		return Object.assign(layout(core.w, core.h), { core, top });
	}

	// ------------------------------------------------------------------ sample state (matches the Lune doubles)
	const RES = ["food", "wood", "stone", "gold"];
	const NAMES = { food: "Food", wood: "Wood", stone: "Stone", gold: "Gold" };
	const state = {
		kingdom: { id: "crimson", name: "Emberhold", rulers: ["Sam", "Mira"], crownPoints: 12, regions: ["crimson_home"] },
		treasury: { food: 120, wood: 100, stone: 50, gold: 0 },
	};
	// UI/ReputationText: ids in display order, names, icons, bar colours (palette names).
	const CATS = [
		{ id: "compassion", name: "Compassion", icon: "rep_compassion", color: "vert" },
		{ id: "honor", name: "Honor", icon: "rep_honor", color: "azure" },
		{ id: "competence", name: "Competence", icon: "rep_competence", color: "amber" },
		{ id: "courage", name: "Courage", icon: "rep_courage", color: "gules" },
		{ id: "authority", name: "Authority", icon: "rep_authority", color: "purpure" },
		{ id: "fear", name: "Fear", icon: "rep_fear", color: "textSecondary" },
	];
	const CONDITIONS = [
		{ id: "happiness", name: "Happiness", icon: "happiness" },
		{ id: "stability", name: "Stability", icon: "stability" },
		{ id: "morale", name: "Army morale", icon: "banner" },
	];
	const catOf = (id) => CATS.find((c) => c.id === id);
	const color = (name) => `var(--color-${name})`;
	// SAMPLE text standing in for Content/Reputation.categories (FL-0083) — prototype only.
	const SAMPLE = {
		compassion: { description: "How kindly your people think you treat them.", affects: "Feeding the hungry, helping families, sparing the weak. Harsh punishments lower it." },
		honor: { description: "Whether your word can be trusted.", affects: "Keeping promises and truces. Breaking them, or burning farms, lowers it." },
		competence: { description: "How well your kingdom is run.", affects: "Buildings that meet a real need, full storehouses, smooth work." },
		courage: { description: "Whether you stand and fight for your people.", affects: "Defending your lands and leading attacks. Fleeing lowers it." },
		authority: { description: "How firmly your orders are followed.", affects: "Settling disputes, enforcing laws, winning battles." },
		fear: { description: "How much your people dread your anger.", affects: "Punishments, threats and atrocities. A lost battle can make it fall fast." },
	};
	const NOW = 10000; // serverTimeNow at render (seconds)
	const PROFILES = {
		balanced: {
			values: { compassion: 62, honor: 48, competence: 55, courage: 40, authority: 70, fear: 15 },
			kingdom: { happiness: 68, stability: 54, morale: 41 },
			history: [
				{ t: NOW - 40, category: "compassion", delta: 4, text: "You gave grain from the royal stores to the hungry farmers.", source: "decision" },
				{ t: NOW - 190, category: "authority", delta: 2, text: "You settled the millers' quarrel yourself.", source: "decision" },
				{ t: NOW - 420, category: "honor", delta: -5, text: "You broke your promise to the miners.", source: "decision" },
				{ t: NOW - 700, category: "competence", delta: 2, text: "The new farm feeds twelve families.", source: "building" },
				{ t: NOW - 1500, category: "fear", delta: 3, text: "You had the thief flogged in the square.", source: "decision" },
				{ t: NOW - 4000, category: "courage", delta: 3, text: "You led the defence of the watchtower.", source: "battle" },
			],
		},
		fear: {
			values: { compassion: 12, honor: 31, competence: 58, courage: 66, authority: 81, fear: 88 },
			kingdom: { happiness: 22, stability: 18, morale: 74 },
			history: [
				{ t: NOW - 25, category: "fear", delta: 6, text: "You burned the rebels' farms.", source: "decision" },
				{ t: NOW - 25, category: "honor", delta: -4, text: "You burned the rebels' farms.", source: "decision" },
				{ t: NOW - 300, category: "compassion", delta: -3, text: "You turned the beggars away from the gate.", source: "decision" },
				{ t: NOW - 900, category: "authority", delta: 3, text: "The striking quarrymen went back to work under guard.", source: "decision" },
			],
		},
		empty: { values: { compassion: 50, honor: 50, competence: 50, courage: 50, authority: 50, fear: 0 }, kingdom: { happiness: 50, stability: 50, morale: 50 }, history: [] },
	};

	// UI/ReputationModel
	const signed = (d) => (d > 0 ? "+" : d < 0 ? "−" : "") + Math.abs(Math.round(d * 10) / 10);
	function ago(t, now) {
		const s = Math.max(0, now - t);
		if (s < 10) return "just now";
		if (s < 60) return `${Math.floor(s)} s ago`;
		if (s < 3600) return `${Math.floor(s / 60)} min ago`;
		return `${Math.floor(s / 3600)} h ago`;
	}
	const band = (v) => (v < 34 ? "Low" : v < 67 ? "Medium" : "High");
	const bandColor = (v) => (v < 34 ? "#FF8A73" : v < 67 ? "var(--color-amber)" : "#A9E57C");

	// ------------------------------------------------------------------ HUD (from kingdom.js)
	const crest = (px, extra = "") => `<div class="crest tinted k-crimson" style="width:${px}px;height:${px}px">${I("emblem_crown", Math.round(px * 0.66))}${extra}</div>`;
	const medallion = (res, px) => {
		const c = T.resource[res];
		return `<div class="medallion" style="width:${px}px;height:${px}px;background:linear-gradient(180deg, ${c} 0%, color-mix(in srgb, ${c} 55%, #0B0F18) 100%)">${I(res, Math.round(px * 0.78))}</div>`;
	};
	const pill = (res, compact) =>
		`<div class="pill ${compact ? "compact" : ""}">${medallion(res, compact ? 24 : 28)}<div class="stack"><div class="amt">${state.treasury[res]}</div>${compact ? "" : `<div class="rate zero">${NAMES[res]}</div>`}</div></div>`;
	function hud(M) {
		const k = state.kingdom;
		const h = M.hud;
		const phone = M.bp === "phone";
		let html = `<div class="badge" style="left:${h.x}px;top:${h.y}px">
			${crest(h.crest, phone ? `<div class="pop cp">${I("gem", 11)}${k.crownPoints}</div>` : "")}
			${phone ? "" : `<div class="plate"><div class="kname" style="font-size:26px">${k.name}</div>
				<div class="ksub">Keep <b>Lv 1</b> · 1 region · <b>${k.crownPoints}</b> Crown Points</div></div>`}</div>`;
		html += `<div class="pills" style="left:${h.pills.x}px;top:${h.pills.y}px">${RES.map((r) => pill(r, phone)).join("")}</div>`;
		if (h.members) {
			html += `<div class="members" style="left:${h.members.x}px;top:${h.members.y}px">${k.rulers
				.map((n, i) => `<div class="member ${i === 0 ? "you" : ""}" style="--k:var(--tincture-crimson)"><div class="av">${n[0]}</div>${n}${i === 0 ? ` <span class="tag">you</span>` : ""}</div>`)
				.join("")}</div>`;
		}
		return html;
	}
	function timer(M) {
		const phone = M.bp === "phone";
		const w = phone ? 120 : 190;
		return `<div class="timer" style="left:${(M.top.w - w) / 2}px;top:${(M.top.h - 40) / 2}px;width:${w}px">${I("timer", 28)}
			<div><div class="ph">Founding</div><div class="t" style="font-size:${phone ? 15 : 18}px">3:12${phone ? "" : `<span class="l" style="margin-left:6px">match time</span>`}</div></div></div>`;
	}
	function rail(M, sel) {
		const b = M.rail.button;
		const items = [{ id: "build", icon: "build", label: "Build" }, { id: "kingdom", icon: "kingdom", label: "Kingdom" }];
		const top = (M.H - (items.length * b + (items.length - 1) * M.rail.gap)) / 2;
		return `<div class="rail" style="right:${M.rail.right}px;top:${top}px">${items
			.map((it) => `<div class="railbtn ${sel === it.id ? "sel" : ""}" style="width:${b}px;height:${b}px">${I(it.icon, M.bp === "phone" ? 30 : 32)}${M.bp === "phone" ? "" : `<div class="lbl">${it.label}</div>`}</div>`)
			.join("")}</div>`;
	}

	// ------------------------------------------------------------------ HUD reputation strip (UI/ReputationStrip)
	function strip(M, profile, o = {}) {
		const r = M.hud.reputation;
		const compact = M.bp === "phone";
		const deltas = o.deltas || {};
		const items = CATS.map((c) => {
			const v = profile.values[c.id];
			const d = deltas[c.id];
			return `<div class="it" style="width:${r.item.w}px;height:${r.item.h}px">
				<div class="ln">${I(c.icon, compact ? 15 : 14)}${compact ? "" : `<span class="nm">${c.name}</span>`}<span class="v">${v}</span></div>
				<div class="rbar"><i style="width:${v}%;--c:${color(c.color)}"></i></div>
				${d ? `<div class="fl ${d > 0 ? "pos" : "neg"}">${signed(d)}</div>` : ""}</div>`;
		}).join("");
		const hit = o.guides ? `<div class="hitguide" style="top:${(r.height - Math.max(44, r.height)) / 2 - 1}px;height:${Math.max(44, r.height)}px"></div>` : "";
		return `<div class="repstrip ${compact ? "compact" : ""}" title="tap: open the reputation screen"
			style="left:${r.x}px;top:${r.y}px;width:${r.width}px;height:${r.height}px;--pad:${r.pad}px;--gx:${r.gx}px;--gy:${r.gy}px;grid-template-columns:repeat(${r.columns}, ${r.item.w}px)">${items}${hit}</div>`;
	}

	// ------------------------------------------------------------------ reputation screen (UI/ReputationPanel)
	function drawer(M, tab, body, guides) {
		const d = M.drawer;
		const phone = M.bp === "phone";
		const tabs = [
			{ id: "values", label: "Reputation", icon: "crest" },
			{ id: "history", label: "History", icon: "timer" },
			{ id: "kingdom", label: "Kingdom", icon: "kingdom" },
		];
		const close = phone ? 44 : 36;
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.width}px;height:${d.height}px">
			<div class="dhead">${phone ? "" : `<div class="dtitle">Reputation</div>`}
			<div class="tabs" style="${phone ? "" : "margin-left:12px"}">${tabs
				.map((t) => `<div class="tab ${t.id === tab ? "sel" : ""}">${I(t.icon, 18)}${phone && t.id !== tab ? "" : t.label}${phone && guides ? `<div class="hit"></div>` : ""}</div>`)
				.join("")}</div>
			<div class="closebtn" style="width:${close}px;height:${close}px">${I("close", 20)}</div></div>
			${phone ? "" : `<div class="ornament"></div>`}
			<div class="dbody">${body}</div></div>`;
	}
	const rtile = (c, px) => `<div class="rtile" style="width:${px}px;height:${px}px;--c:${color(c.color)}">${I(c.icon, px - 8)}</div>`;
	function catRow(c, v, sel, compact) {
		return `<div class="rrow ${sel ? "sel" : ""}">${rtile(c, compact ? 28 : 32)}<div class="mid"><div class="top"><span class="rn">${c.name}</span><span class="num">${v}</span></div>
			<div class="rbar"><i style="width:${v}%;--c:${color(c.color)}"></i></div></div></div>`;
	}
	function historyRow(e, now, o = {}) {
		const c = catOf(e.category);
		return `<div class="hrow ${o.fresh ? "fresh" : ""}"><div class="dchip ${e.delta > 0 ? "pos" : "neg"}">${signed(e.delta)}</div>
			<div class="hm"><div class="ht">${e.text}</div><div class="hs">${I(c.icon, 12)}<span class="cat" style="--c:${color(c.color)}">${c.name}</span> · ${ago(e.t, now)}</div></div></div>`;
	}
	function detail(M, profile, id, o = {}) {
		const c = catOf(id);
		const v = profile.values[id];
		const text = o.content === false ? null : SAMPLE[id];
		const mine = profile.history.filter((e) => e.category === id).sort((a, b) => b.t - a.t).slice(0, 3);
		return `<div class="rdetail">
			${o.back ? `<div class="back" style="margin:0"><span>‹ Reputation</span></div>` : ""}
			<div class="dh">${rtile(c, M.bp === "phone" ? 36 : 44)}<div><div class="dname">${c.name}</div><div class="dmeta">${band(v)}</div></div>
			<div class="big"><b>${v}</b><span>of 100</span></div></div>
			<div class="rbar"><i style="width:${v}%;--c:${color(c.color)}"></i></div>
			${text ? `<div class="para"><div class="ph">About</div><div class="pt">${text.description}</div></div>
				<div class="para"><div class="ph">What affects it</div><div class="pt">${text.affects}</div></div>` : ""}
			<div class="subhead">${I("timer", 14)}Recent changes</div>
			${mine.length ? mine.map((e) => historyRow(e, NOW)).join("") : `<div class="empty">No changes yet.</div>`}</div>`;
	}
	function valuesTab(M, profile, sel, o = {}) {
		const phone = M.bp === "phone";
		if (phone) {
			if (o.phoneView === "detail") return detail(M, profile, sel, { back: true, content: o.content });
			return `<div class="scroller" style="flex:1"><div class="rgrid">${CATS.map((c) => catRow(c, profile.values[c.id], false, true)).join("")}</div>
				<div class="hintline">Tap a value to see what changes it.</div></div>`;
		}
		const listW = M.bp === "tablet" ? 230 : 250;
		return `<div class="rlist" style="width:${listW}px">${CATS.map((c) => catRow(c, profile.values[c.id], c.id === sel, false)).join("")}</div>${detail(M, profile, sel, { content: o.content })}`;
	}
	function historyTab(M, profile, o = {}) {
		const list = [...profile.history].sort((a, b) => b.t - a.t);
		if (!list.length) return `<div class="scroller"><div class="empty">Nothing has changed yet. What you decide and do as ruler shows up here.</div></div>`;
		return `<div class="scroller fade">${list.map((e, i) => historyRow(e, NOW, { fresh: o.fresh && i === 0 })).join("")}</div>`;
	}
	function kingdomTab(M, profile) {
		return `<div class="scroller"><div class="caption">How your kingdom is doing. These are separate from your reputation.</div>
			${CONDITIONS.map((c) => {
				const v = profile.kingdom[c.id];
				return `<div class="crowc"><div class="medallion" style="width:36px;height:36px;background:linear-gradient(180deg, var(--color-ink600), var(--color-ink900))">${I(c.icon, 26)}</div>
					<div class="mid"><div class="top"><span class="cn">${c.name}</span><span class="band" style="color:${bandColor(v)}">${band(v)}</span><span class="num">${v}</span></div>
					<div class="rbar"><i style="width:${v}%;--c:${bandColor(v)}"></i></div></div></div>`;
			}).join("")}</div>`;
	}

	// ------------------------------------------------------------------ backdrop (as kingdom.js)
	function world(w, h) {
		const rnd = (i) => ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;
		const houses = [];
		for (let i = 0; i < 22; i++) {
			const x = 0.14 + rnd(i) * 0.4, y = 0.5 + rnd(i + 99) * 0.38, s = 10 + y * 22;
			houses.push(`<g transform="translate(${x * w} ${y * h})"><rect x="${-s / 2}" y="${-s * 0.6}" width="${s}" height="${s * 0.6}" fill="#E9DCB8"/><path d="M${-s * 0.62} ${-s * 0.55} L0 ${-s * 1.05} L${s * 0.62} ${-s * 0.55} Z" fill="${i % 3 ? "#B8402E" : "#7D2E22"}"/></g>`);
		}
		const fields = [];
		for (let i = 0; i < 12; i++) {
			const x = rnd(i + 7) * w * 0.6, y = h * (0.6 + rnd(i + 3) * 0.35), fw = 90 + rnd(i) * 160, fh = 30 + rnd(i + 1) * 50;
			fields.push(`<rect x="${x}" y="${y}" width="${fw}" height="${fh}" rx="6" fill="${["#7FA44A", "#C9B15A", "#5E8A3A", "#A9B65A"][i % 4]}" opacity="0.85" transform="skewX(-18)"/>`);
		}
		const trees = [];
		for (let i = 0; i < 40; i++) {
			const x = w * (0.72 + rnd(i + 40) * 0.28), y = h * (0.36 + rnd(i + 80) * 0.3), r = 10 + rnd(i + 5) * 12;
			trees.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="${i % 2 ? "#3E7A3A" : "#4E8F45"}"/>`);
		}
		return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
			<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FB0D9"/><stop offset="1" stop-color="#D7E3D0"/></linearGradient></defs>
			<rect width="${w}" height="${h}" fill="url(#sky)"/>
			<path d="M0 ${h * 0.34} Q ${w * 0.2} ${h * 0.22} ${w * 0.4} ${h * 0.32} T ${w * 0.8} ${h * 0.28} T ${w} ${h * 0.3} V ${h} H 0 Z" fill="#8FAE7A"/>
			<path d="M0 ${h * 0.42} Q ${w * 0.25} ${h * 0.36} ${w * 0.5} ${h * 0.44} T ${w} ${h * 0.4} V ${h} H 0 Z" fill="#6E9A4E"/>
			${fields.join("")}${trees.join("")}
			<path d="M${w * 0.5} ${h * 0.42} C ${w * 0.44} ${h * 0.6} ${w * 0.56} ${h * 0.72} ${w * 0.48} ${h}" stroke="#5C9BC7" stroke-width="${h * 0.035}" fill="none" opacity="0.9"/>
			${houses.join("")}
			<g transform="translate(${w * 0.3} ${h * 0.6})"><rect x="-40" y="-70" width="80" height="70" fill="#CFC3A6"/><rect x="-58" y="-95" width="26" height="95" fill="#BDB295"/><rect x="32" y="-95" width="26" height="95" fill="#BDB295"/><path d="M-62 -95 L-45 -125 L-28 -95 Z M28 -95 L45 -125 L62 -95 Z" fill="#B8402E"/><path d="M-44 -70 L0 -105 L44 -70 Z" fill="#7D2E22"/></g>
		</svg>`;
	}

	// ------------------------------------------------------------------ build drawer stand-in (overlap check with the strip)
	function buildStandIn(M) {
		const phone = M.bp === "phone";
		const d = M.drawer;
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.width}px;height:${d.height}px">
			<div class="dhead">${phone ? "" : `<div class="dtitle">Build</div>`}<div class="tabs" style="${phone ? "" : "margin-left:12px"}"><div class="tab sel">${I("food", 18)}Economy</div><div class="tab">${I("house", 18)}${phone ? "" : "Homes"}</div><div class="tab">${I("army", 18)}${phone ? "" : "Military"}</div></div>
			<div class="closebtn">${I("close", 20)}</div></div>${phone ? "" : `<div class="ornament"></div>`}
			<div class="dbody"><div class="empty" style="flex:1">Build drawer (FL-0059): its top edge is pushed below the reputation strip on tablet and desktop.</div></div></div>`;
	}

	// ------------------------------------------------------------------ scenes
	const P = PROFILES;
	const SCENES = {
		hud: (M, g) => hud(M) + strip(M, P.balanced, { guides: g }) + rail(M),
		"hud-change": (M) => hud(M) + strip(M, P.balanced, { deltas: { compassion: 4, fear: -2 } }) + rail(M),
		screen: (M, g) => hud(M) + strip(M, P.balanced) + rail(M) + drawer(M, "values", valuesTab(M, P.balanced, "compassion"), g),
		"screen-detail": (M) => hud(M) + strip(M, P.balanced) + rail(M) + drawer(M, "values", valuesTab(M, P.balanced, "honor", { phoneView: "detail" })),
		history: (M) => hud(M) + strip(M, P.balanced) + rail(M) + drawer(M, "history", historyTab(M, P.balanced, { fresh: true })),
		conditions: (M) => hud(M) + strip(M, P.balanced) + rail(M) + drawer(M, "kingdom", kingdomTab(M, P.balanced)),
		fear: (M) => hud(M) + strip(M, P.fear) + rail(M) + drawer(M, "values", valuesTab(M, P.fear, "fear", { phoneView: "detail" })),
		empty: (M) => hud(M) + strip(M, P.empty) + rail(M) + drawer(M, "history", historyTab(M, P.empty)),
		"no-content": (M) => hud(M) + strip(M, P.balanced) + rail(M) + drawer(M, "values", valuesTab(M, P.balanced, "compassion", { phoneView: "detail", content: false })),
		build: (M) => hud(M) + strip(M, P.balanced) + rail(M, "build") + buildStandIn(M),
	};
	window.FL0089_SCENES = Object.keys(SCENES);

	function render() {
		const size = q.get("size") || "desktop";
		const scene = q.get("scene") || "hud";
		const d = DEVICES[size];
		const M = metrics(d);
		const guides = q.get("guides") === "1";
		const core = SCENES[scene](M, guides);
		document.body.innerHTML = `<div class="viewport" style="width:${d.w}px;height:${d.h}px">
			<div class="world">${world(d.w, d.h)}</div>
			<div class="robloxbtn" style="left:${d.inset.l + 12}px;top:7px">R</div><div class="robloxbtn" style="left:${d.inset.l + 60}px;top:7px">≡</div>
			<div class="layer" style="left:${M.top.x}px;top:${M.top.y}px;width:${M.top.w}px;height:${M.top.h}px">${timer(M)}</div>
			<div class="layer" style="left:${M.core.x}px;top:${M.core.y}px;width:${M.core.w}px;height:${M.core.h}px">
				<div class="scaled" style="width:${M.W}px;height:${M.H}px;transform:scale(${M.scale})">${core}</div></div>
			${guides ? `<div class="guides">
				<div class="band" style="left:0;top:0;width:${d.inset.l}px;height:${d.h}px"><span>notch</span></div>
				<div class="band" style="right:0;top:0;width:${d.inset.r}px;height:${d.h}px"></div>
				<div class="band" style="left:0;bottom:0;width:${d.w}px;height:${d.inset.b}px"></div>
				<div class="band topbar" style="left:${d.inset.l}px;top:0;width:${d.w - d.inset.l - d.inset.r}px;height:${d.topbar}px"><span>Roblox top bar</span></div></div>` : ""}
		</div>`;
		document.title = `${scene} @ ${size} (${M.bp}, scale ${M.scale.toFixed(2)})`;
	}
	render();
	window.__ready = document.fonts.ready.then(() => true);
})();
