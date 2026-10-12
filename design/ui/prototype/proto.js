// AI Kingdoms HUD + construction + kingdom panel prototype (FORGE-03).
// URL: kingdom.html?size=phone|tablet|desktop&scene=<name>&guides=1
// The layout maths here is the spec for roblox/src/shared/UI/Layout.luau (same breakpoints, scale and zones).
(function () {
	const T = window.TOKENS;
	const I = (name, size) => window.Icons.svg(name, size);
	const q = new URLSearchParams(location.search);

	// ------------------------------------------------------------------ emulated devices (logical px)
	// Device insets: iPhone 14 class landscape (47 / 47 / 21). Roblox top bar band: 58 px tall with
	// the left controls about 104 px wide (estimates; GuiService.TopbarInset gives the real rect).
	const DEVICES = {
		phone: { w: 844, h: 390, inset: { l: 47, r: 47, t: 0, b: 21 }, topbar: 58, controls: 104 },
		tablet: { w: 1024, h: 768, inset: { l: 0, r: 0, t: 0, b: 20 }, topbar: 58, controls: 104 },
		desktop: { w: 1920, h: 1080, inset: { l: 0, r: 0, t: 0, b: 0 }, topbar: 58, controls: 104 },
	};

	function metrics(d) {
		const core = { x: d.inset.l, y: Math.max(d.inset.t, d.topbar), w: d.w - d.inset.l - d.inset.r, h: d.h - Math.max(d.inset.t, d.topbar) - d.inset.b };
		const top = { x: d.inset.l + d.controls, y: d.inset.t, w: d.w - d.inset.l - d.inset.r - d.controls, h: d.topbar };
		const bp = d.h < 500 || d.w < 700 ? "phone" : d.w >= 1400 && d.h >= 800 ? "desktop" : "tablet";
		const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
		const scale = bp === "desktop" ? clamp(d.h / 900, 1, 1.5) : bp === "tablet" ? clamp(d.h / 700, 1, 1.25) : 1;
		const W = core.w / scale, H = core.h / scale;
		const m = bp === "phone" ? 8 : 16;
		const railBtn = bp === "phone" ? 48 : 58;
		const z = { margin: m, railBtn };
		z.rail = { right: m, width: railBtn };
		z.hud = { x: m, y: bp === "phone" ? 6 : m };
		z.hudBottom = bp === "phone" ? z.hud.y + 36 : z.hud.y + 52 + 8 + 38;
		const drawerRight = m + railBtn + 12;
		if (bp === "phone") {
			// Single pane to the right of the resource pills (crest 34 + 4 compact pills), full height.
			const x = z.hud.x + 34 + 8 + 4 * 66 + 3 * 6 + 12;
			z.drawer = { x, y: z.hud.y, w: W - drawerRight - x, h: H - z.hud.y - m, single: true };
		} else {
			const w = bp === "tablet" ? 560 : 620;
			const maxH = bp === "tablet" ? 470 : 480;
			const y = z.hudBottom + 10;
			z.drawer = { x: W - drawerRight - w, y, w, h: Math.min(maxH, H - y - m) };
		}
		z.toast = { w: bp === "phone" ? 250 : 300 };
		return { bp, scale, core, top, W, H, z };
	}

	// ------------------------------------------------------------------ sample state (matches the Lune double)
	const RES = ["food", "wood", "stone", "gold"];
	const NAMES = { food: "Food", wood: "Wood", stone: "Stone", gold: "Gold" };
	const state = {
		kingdom: { name: "Aldmere", hall: 1, tiles: 6, citizens: 9, housing: 10, working: 6, building: 1, idle: 2 },
		treasury: { food: 136, wood: 85, stone: 50, gold: 50 },
		caps: { food: 500, wood: 500, stone: 300, gold: 300 },
		rates: { food: 18, wood: 18, stone: 0, gold: 0 },
		timer: "14:32",
	};
	const CATALOG = [
		{ id: "farm", name: "Farm", cat: "economy", cost: { wood: 40 }, own: 1, max: 6, sec: 15, workers: 3, prod: { food: 6 }, desc: "Workers grow food for your citizens and army." },
		{ id: "lumbercamp", name: "Lumber Camp", cat: "economy", cost: { wood: 20, food: 10 }, own: 1, max: 4, sec: 12, workers: 3, prod: { wood: 6 }, desc: "Workers fell trees and bring back wood." },
		{ id: "quarry", name: "Quarry", cat: "economy", cost: { wood: 50, food: 20 }, own: 0, max: 3, sec: 18, workers: 3, prod: { stone: 4 }, desc: "Workers cut stone for upgrades and defences." },
		{ id: "goldmine", name: "Gold Mine", cat: "economy", cost: { wood: 60, stone: 40 }, own: 0, max: 2, sec: 25, workers: 2, prod: { gold: 3 }, req: "Town Hall Lv 2", desc: "Workers dig gold to pay your army." },
	];
	const fmt = (n) => (n >= 10000 ? (n / 1000).toFixed(0) + "k" : n >= 1000 ? (n / 1000).toFixed(1).replace(/\.0$/, "") + "k" : String(n));
	const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

	// ------------------------------------------------------------------ components
	const medallion = (res, px) => {
		const c = T.resource[res];
		return `<div class="medallion" style="width:${px}px;height:${px}px;background:linear-gradient(180deg, ${c} 0%, color-mix(in srgb, ${c} 55%, #0B0F18) 100%)">${I(res === "citizens" ? "citizens" : res, Math.round(px * 0.78))}</div>`;
	};
	function pill(res, o = {}) {
		const amt = state.treasury[res];
		const cap = state.caps[res];
		const rate = state.rates[res];
		const compact = o.compact;
		const frac = Math.min(1, amt / cap);
		const cls = ["pill", compact ? "compact" : "", amt >= cap ? "full" : "", o.flash ? "flash-" + o.flash : ""].join(" ");
		return `<div class="${cls}">${medallion(res, compact ? 24 : 28)}
			<div class="stack"><div class="amt">${fmt(amt)}${compact ? "" : `<small> / ${fmt(cap)}</small>`}</div>
			${compact ? "" : `<div class="rate ${rate ? "" : "zero"}">${"+" + rate + "/min"}</div>`}</div>
			${o.delta ? `<div class="delta ${o.delta < 0 ? "neg" : "pos"}">${o.delta > 0 ? "+" : "−"}${Math.abs(o.delta)}</div>` : ""}</div>`;
	}
	function citizensPill() {
		const k = state.kingdom;
		return `<div class="pill">${medallion("citizens", 28)}<div class="stack"><div class="amt">${k.citizens}<small> / ${k.housing}</small></div>
			<div class="rate" style="color:var(--color-amber)">${k.idle} idle</div></div></div>`;
	}
	function hud(M, o) {
		const k = state.kingdom;
		const { x, y } = M.z.hud;
		const phone = M.bp === "phone";
		const deltas = o.deltas || {};
		const crestPx = phone ? 34 : 52;
		let html = `<div class="badge" style="left:${x}px;top:${y}px">
			<div class="crest" style="width:${crestPx}px;height:${crestPx}px">${I("crown", Math.round(crestPx * 0.66))}
			${phone ? `<div class="pop">${I("citizens", 11)}${k.citizens}/${k.housing}</div>` : ""}</div>
			${phone ? "" : `<div class="plate"><div class="kname" style="font-size:26px">Aldmere</div><div class="ksub">Town Hall <b>Lv ${k.hall}</b> · ${k.tiles} tiles</div></div>`}</div>`;
		const px = phone ? x + crestPx + 8 : x;
		const py = phone ? y + 2 : y + crestPx + 8;
		html += `<div class="pills" style="left:${px}px;top:${py}px">${RES.map((r) => pill(r, { compact: phone, delta: deltas[r], flash: deltas[r] ? (deltas[r] < 0 ? "neg" : "pos") : null })).join("")}${phone ? "" : citizensPill()}</div>`;
		return html;
	}
	function timer(M) {
		const phone = M.bp === "phone";
		const w = phone ? 104 : 196;
		const left = (M.top.w - w) / 2;
		return `<div class="timer" style="left:${left}px;top:${(M.top.h - 40) / 2}px;width:${w}px">${I("timer", 28)}
			<div><div class="t">${state.timer}</div>${phone ? "" : `<div class="l">until the match ends</div>`}</div></div>`;
	}
	function rail(M, sel) {
		const b = M.z.railBtn;
		const items = [
			{ id: "build", icon: "build", label: "Build" },
			{ id: "kingdom", icon: "kingdom", label: "Kingdom", count: state.kingdom.idle },
		];
		const top = (M.H - (items.length * b + (items.length - 1) * 10)) / 2;
		return `<div class="rail" style="right:${M.z.rail.right}px;top:${top}px">${items
			.map((it) => `<div class="railbtn ${sel === it.id ? "sel" : ""}" style="width:${b}px;height:${b}px">${I(it.icon, M.bp === "phone" ? 30 : 32)}
				${M.bp === "phone" ? "" : `<div class="lbl">${it.label}</div>`}${it.count ? `<div class="count">${it.count}</div>` : ""}</div>`)
			.join("")}</div>`;
	}
	function costChips(cost, have) {
		return Object.entries(cost).map(([r, v]) => `<span class="chip ${have[r] < v ? "short" : ""}">${I(r, 14)}${v}</span>`).join("");
	}
	function buildRow(e, sel, phone) {
		const locked = !!e.req;
		const tile = phone ? 34 : 40;
		return `<div class="row ${sel ? "sel" : ""} ${locked ? "locked" : ""}">
			<div class="tile ${e.cat}" style="width:${tile}px;height:${tile}px">${I(e.id, tile - 6)}</div>
			<div style="min-width:0"><div class="rname">${e.name}</div><div class="rmeta">${costChips(e.cost, state.treasury)}</div></div>
			<div class="rright ${locked ? "lock" : ""}">${locked ? I("lock", 14) + (phone ? "" : "Lv 2") : `${e.own}/${e.max}`}</div></div>`;
	}
	function ctaFor(e, mode, verb) {
		const have = state.treasury;
		const short = Object.entries(e.cost).filter(([r, v]) => have[r] < v);
		if (mode === "done") return `<div class="btn success">${I("check", 22)}Construction started</div>`;
		if (mode === "loading") return `<div class="btn primary"><span class="spin"></span>Starting…</div>`;
		if (e.req) return `<div class="btn disabled">${I("lock", 18)}Requires ${e.req}</div>`;
		if (short.length) return `<div class="btn disabled">Need ${short.map(([r, v]) => `${v - have[r]} more ${NAMES[r]}`).join(", ")}</div>`;
		return `<div class="btn primary">${I("build", 22)}${verb || "Build " + e.name}</div>`;
	}
	function buildDetail(e, M, mode, o = {}) {
		const phone = M.bp === "phone";
		const have = state.treasury;
		const rate = Object.entries(e.prod || {}).map(([r, v]) => `+${v * e.workers} ${NAMES[r]}/min`).join(" ");
		const tile = phone ? 40 : 56;
		const meta = o.meta || `${e.cat[0].toUpperCase() + e.cat.slice(1)} · Level 1 · ${e.own}/${e.max} built`;
		return `<div class="detail">
			${o.back ? `<div class="back">${I("close", 12).replace("<svg", '<svg style="transform:rotate(0)"')}<span>‹ ${o.back}</span></div>` : ""}
			<div class="dh"><div class="tile ${e.cat}" style="width:${tile}px;height:${tile}px">${I(e.id, tile - 8)}</div>
			<div style="min-width:0"><div class="dname">${o.title || e.name}</div><div class="dmeta">${meta}</div></div></div>
			<div class="dscroll">
			${phone ? "" : `<div class="ddesc">${o.desc || e.desc}</div>`}
			<div class="stats"><span class="stat">${I("timer", 16)}${mmss(e.sec)}</span>${e.workers ? `<span class="stat">${I("citizens", 16)}${e.workers} workers</span>` : ""}${rate ? `<span class="stat good">${I(Object.keys(e.prod)[0], 16)}${rate}</span>` : ""}</div>
			${e.req ? `<div class="req unmet">${I("lock", 16)}Requires ${e.req}</div>` : ""}
			${mode === "done" ? `<div class="paid">${I("check", 16)}Paid ${Object.entries(e.cost).map(([r, v]) => `${v} ${NAMES[r]}`).join(" · ")}</div>
				<div class="prog"><span>Under construction</span><div class="bar"><i style="width:3%"></i></div><b>0:18</b></div>` : `<div class="costs">${Object.entries(e.cost)
				.map(([r, v]) => {
					const s = have[r] < v;
					return `<div class="crow ${s ? "short" : ""}">${I(r, 18)}<span class="n">${NAMES[r]}</span><span class="v">${v}</span>
					<span class="h">${s ? `have ${have[r]}` : `${I("check", 12).replace("<svg", '<svg style="display:inline;vertical-align:-1px"')} ${have[r]}`}</span></div>`;
				})
				.join("")}</div>`}</div>
			<div class="cta">${ctaFor(e, mode, o.verb)}</div></div>`;
	}
	function drawer(M, title, tabs, body) {
		const d = M.z.drawer;
		const phone = M.bp === "phone";
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.w}px;height:${d.h}px">
			<div class="dhead">${phone ? "" : `<div class="dtitle">${title}</div>`}
			<div class="tabs" style="${phone ? "" : "margin-left:12px"}">${tabs.map((t) => `<div class="tab ${t.sel ? "sel" : ""}">${I(t.icon, 18)}${phone && !t.sel ? "" : t.label}</div>`).join("")}</div>
			<div class="closebtn">${I("close", 20)}</div></div>
			${phone ? "" : `<div class="ornament"></div>`}
			<div class="dbody">${body}</div></div>`;
	}
	function buildMenu(M, selId, mode, view) {
		const phone = M.bp === "phone";
		const listW = M.bp === "tablet" ? 230 : 250;
		const sel = CATALOG.find((e) => e.id === selId);
		const tabs = [
			{ label: "Economy", icon: "food", sel: true },
			{ label: "Civic", icon: "house" },
			{ label: "Military", icon: "army" },
		];
		if (phone) {
			// Phone: one pane. The list shows costs at a glance; tapping a row opens its detail (back = list).
			const body = view === "list"
				? `<div class="list fade" style="flex:1;width:auto">${CATALOG.map((e) => buildRow(e, false, false)).join("")}</div>`
				: buildDetail(sel, M, mode, { back: "Economy", meta: `Economy · Lv 1 · ${sel.own}/${sel.max} built` });
			return drawer(M, "Construction", tabs, body);
		}
		const list = `<div class="list" style="width:${listW}px">${CATALOG.map((e) => buildRow(e, e.id === selId, false)).join("")}</div>`;
		return drawer(M, "Construction", tabs, list + buildDetail(sel, M, mode));
	}
	function toast(M, kind, icon, title, body) {
		const k = { success: "var(--color-vert)", error: "var(--color-gules)", info: "var(--color-azure)", reward: "var(--color-gold400)", warning: "var(--color-amber)" }[kind];
		return `<div class="toast" style="--k:${k};width:${M.z.toast.w}px">${I(icon, 28)}<div><div class="tt">${title}</div>${body ? `<div class="tb">${body}</div>` : ""}</div></div>`;
	}
	function toasts(M, list, drawerOpen) {
		const right = drawerOpen && M.bp === "phone" ? M.W - M.z.drawer.x + 10 : M.z.margin + M.z.railBtn + 12;
		const top = M.bp === "phone" && drawerOpen ? M.z.hudBottom + 8 : M.z.hud.y; // phone: below the pills
		return `<div class="toasts" style="right:${right}px;top:${top}px">${list.join("")}</div>`;
	}
	function queue(M, items, drawerOpen) {
		const w = items.length * 210;
		const free = drawerOpen ? M.z.drawer.x : M.W; // centre of the area left of an open drawer
		return `<div class="queue" style="left:${(free - w) / 2}px;bottom:${M.z.margin}px">${items
			.map((q) => `<div class="qchip"><div class="tile ${q.cat}" style="width:28px;height:28px;border-radius:50%">${I(q.id, 20)}</div>
				<div class="qn">${q.name}</div><div class="bar" style="width:64px"><i style="width:${q.p}%"></i></div><div class="qt">${q.t}</div></div>`)
			.join("")}</div>`;
	}
	function kingdomPanel(M, tab) {
		const k = state.kingdom;
		const phone = M.bp === "phone";
		const tabs = [
			{ label: "Overview", icon: "crown", sel: tab === "overview" },
			{ label: "Buildings", icon: "townhall", sel: tab === "buildings" },
		];
		let body;
		if (tab === "overview") {
			const seg = (n, c) => `<i style="width:${(n / k.housing) * 100}%;background:${c}"></i>`;
			body = `<div style="flex:1;min-width:0;display:flex;flex-direction:column">
				${phone ? "" : `<div class="kp-banner"><div class="crest" style="width:60px;height:60px">${I("crown", 40)}</div><div><div class="kname" style="font-size:32px">Kingdom of Aldmere</div><div class="ksub">Town Hall <b>Lv 1</b> · ${k.tiles} territory tiles · Rank <b>2 of 6</b></div></div></div>`}
				<div class="section" style="margin-top:0"><div class="sh">${I("citizens", 18)}Citizens<span class="r">${k.citizens} / ${k.housing} housed</span></div>
				<div class="seg">${seg(k.working, "var(--color-vert)")}${seg(k.building, "var(--color-gold500)")}${seg(k.idle, "var(--color-amber)")}</div>
				<div class="legend"><span class="lg"><i style="background:var(--color-vert)"></i>Working <b>${k.working}</b></span><span class="lg"><i style="background:var(--color-gold500)"></i>Building <b>${k.building}</b></span><span class="lg warn"><i style="background:var(--color-amber)"></i>Idle <b>${k.idle}</b></span></div></div>
				<div class="section"><div class="sh">${I("storehouse", 18)}Production &amp; storage</div>
				${RES.map((r) => `<div class="prow">${I(r, 20)}<div class="pr ${state.rates[r] ? "" : "zero"}">${state.rates[r] ? "+" + state.rates[r] + "/min" : "—"}</div>
					<div class="bar"><i style="width:${(state.treasury[r] / state.caps[r]) * 100}%;background:${T.resource[r]}"></i></div><div class="ps">${state.treasury[r]} / ${state.caps[r]}</div></div>`).join("")}</div></div>`;
		} else {
			const rows = [
				{ id: "townhall", cat: "civic", name: "Town Hall", lv: 1, sub: `${I("citizens", 13)}Houses 6`, action: "upgrade" },
				{ id: "house", cat: "civic", name: "House", lv: 1, sub: "Under construction", progress: 45, left: "0:07" },
				{ id: "farm", cat: "economy", name: "Farm", lv: 1, sub: `${I("food", 13)}+18 Food/min`, workers: [3, 3] },
				{ id: "lumbercamp", cat: "economy", name: "Lumber Camp", lv: 1, sub: `${I("wood", 13)}+18 Wood/min`, workers: [3, 3] },
				{ id: "house", cat: "civic", name: "House", lv: 1, sub: `${I("citizens", 13)}Houses 4`, action: "upgrade" },
			];
			body = `<div class="list" style="flex:1;width:auto">${rows
				.map((b) => `<div class="brow"><div class="tile ${b.cat}" style="width:${phone ? 34 : 40}px;height:${phone ? 34 : 40}px">${I(b.id, phone ? 28 : 34)}</div>
					<div class="bmid"><div class="rname">${b.name} <span style="font:700 11px var(--font-body);color:var(--color-gold400)">Lv ${b.lv}</span></div>
					${b.progress != null ? `<div class="bsub"><div class="bar" style="flex:1"><i style="width:${b.progress}%"></i></div><b style="color:var(--color-gold300)">${b.left}</b></div>` : `<div class="bsub">${b.sub}</div>`}</div>
					${b.workers ? `<div class="stepper"><div class="stepbtn">${I("minus", 16)}</div><div class="stepv">${b.workers[0]}/${b.workers[1]}</div><div class="stepbtn off">${I("plus", 16)}</div></div>` : ""}
					${b.action ? `<div class="btn secondary small">${I("build", 16)}Upgrade</div>` : ""}</div>`)
				.join("")}</div>`;
		}
		return drawer(M, "Kingdom", tabs, body);
	}
	function upgradePanel(M) {
		// Upgrade menu = the same detail component with the next level's costs.
		const e = { id: "townhall", name: "Town Hall", cat: "civic", cost: { wood: 150, stone: 100, gold: 40 }, own: 1, max: 1, sec: 45, desc: "Level 2 unlocks the Gold Mine, Barracks and level 2 of every building. Houses 8 citizens." };
		const tabs = [
			{ label: "Overview", icon: "crown" },
			{ label: "Buildings", icon: "townhall", sel: true },
		];
		const body = buildDetail(e, M, null, { verb: "Upgrade to Lv 2", meta: "Civic · Level 1 → 2", title: "Town Hall", back: M.bp === "phone" ? "Buildings" : null });
		return drawer(M, "Kingdom", tabs, body);
	}

	// ------------------------------------------------------------------ backdrop: a stylised kingdom view
	function world(w, h) {
		const houses = [];
		const rnd = (i) => ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;
		for (let i = 0; i < 26; i++) {
			const x = 0.18 + rnd(i) * 0.64, y = 0.5 + rnd(i + 99) * 0.38;
			const s = 10 + y * 22;
			houses.push(`<g transform="translate(${x * w} ${y * h})"><rect x="${-s / 2}" y="${-s * 0.6}" width="${s}" height="${s * 0.6}" fill="#D9C9A3"/><path d="M${-s * 0.62} ${-s * 0.55} L0 ${-s * 1.05} L${s * 0.62} ${-s * 0.55} Z" fill="${i % 3 ? "#9A5233" : "#6D4630"}"/></g>`);
		}
		const fields = [];
		for (let i = 0; i < 16; i++) {
			const x = rnd(i + 7) * w, y = h * (0.55 + rnd(i + 3) * 0.4), fw = 90 + rnd(i) * 160, fh = 30 + rnd(i + 1) * 50;
			fields.push(`<rect x="${x}" y="${y}" width="${fw}" height="${fh}" rx="6" fill="${["#7FA44A", "#C9B15A", "#5E8A3A", "#A9B65A"][i % 4]}" opacity="0.85" transform="skewX(-18)"/>`);
		}
		return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
			<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FB0D9"/><stop offset="1" stop-color="#D7E3D0"/></linearGradient></defs>
			<rect width="${w}" height="${h}" fill="url(#sky)"/>
			<path d="M0 ${h * 0.34} Q ${w * 0.2} ${h * 0.22} ${w * 0.4} ${h * 0.32} T ${w * 0.8} ${h * 0.28} T ${w} ${h * 0.3} V ${h} H 0 Z" fill="#8FAE7A"/>
			<path d="M0 ${h * 0.42} Q ${w * 0.25} ${h * 0.36} ${w * 0.5} ${h * 0.44} T ${w} ${h * 0.4} V ${h} H 0 Z" fill="#6E9A4E"/>
			${fields.join("")}
			<path d="M${w * 0.62} ${h * 0.42} C ${w * 0.5} ${h * 0.6} ${w * 0.75} ${h * 0.72} ${w * 0.6} ${h}" stroke="#5C9BC7" stroke-width="${h * 0.035}" fill="none" opacity="0.9"/>
			${houses.join("")}
			<g transform="translate(${w * 0.42} ${h * 0.6})"><rect x="-40" y="-70" width="80" height="70" fill="#CFC3A6"/><rect x="-58" y="-95" width="26" height="95" fill="#BDB295"/><rect x="32" y="-95" width="26" height="95" fill="#BDB295"/><path d="M-62 -95 L-45 -125 L-28 -95 Z M28 -95 L45 -125 L62 -95 Z" fill="#3F72B5"/><path d="M-44 -70 L0 -105 L44 -70 Z" fill="#B8402E"/></g>
		</svg>`;
	}

	// ------------------------------------------------------------------ scenes
	const SCENES = {
		hud: (M) => ({ core: hud(M, {}) + rail(M) + queue(M, [{ id: "house", name: "House", cat: "civic", p: 45, t: "0:07" }]) }),
		build: (M) => ({ core: hud(M, {}) + rail(M, "build") + buildMenu(M, "quarry", null, "list") }),
		"build-detail": (M) => ({ core: hud(M, {}) + rail(M, "build") + buildMenu(M, "quarry") }),
		"build-short": (M) => {
			state.treasury.wood = 30;
			return { core: hud(M, {}) + rail(M, "build") + buildMenu(M, "quarry") };
		},
		"build-locked": (M) => ({ core: hud(M, {}) + rail(M, "build") + buildMenu(M, "goldmine") }),
		built: (M) => {
			state.treasury.wood = 35;
			state.treasury.food = 116;
			CATALOG[2].own = 1;
			return {
				core:
					hud(M, { deltas: { wood: -50, food: -20 } }) +
					rail(M, "build") +
					buildMenu(M, "quarry", "done") +
					toasts(M, [toast(M, "success", "quarry", "Quarry construction started", "Ready in 0:18 · 1 builder assigned")], true) +
					queue(M, [{ id: "quarry", name: "Quarry", cat: "economy", p: 2, t: "0:18" }], true),
			};
		},
		kingdom: (M) => ({ core: hud(M, {}) + rail(M, "kingdom") + kingdomPanel(M, "overview") }),
		"kingdom-buildings": (M) => ({ core: hud(M, {}) + rail(M, "kingdom") + kingdomPanel(M, "buildings") }),
		upgrade: (M) => ({ core: hud(M, {}) + rail(M, "kingdom") + upgradePanel(M) }),
	};

	function render() {
		const size = q.get("size") || "desktop";
		const scene = q.get("scene") || "hud";
		const d = DEVICES[size];
		const M = metrics(d);
		const out = SCENES[scene](M);
		const guides = q.get("guides") === "1";
		document.body.innerHTML = `<div class="viewport" style="width:${d.w}px;height:${d.h}px">
			<div class="world">${world(d.w, d.h)}</div>
			<div class="robloxbtn" style="left:${d.inset.l + 12}px;top:7px">R</div><div class="robloxbtn" style="left:${d.inset.l + 60}px;top:7px">≡</div>
			<div class="layer" style="left:${M.top.x}px;top:${M.top.y}px;width:${M.top.w}px;height:${M.top.h}px">${timer(M)}</div>
			<div class="layer" style="left:${M.core.x}px;top:${M.core.y}px;width:${M.core.w}px;height:${M.core.h}px">
				<div class="scaled" style="width:${M.W}px;height:${M.H}px;transform:scale(${M.scale})">${out.core}</div></div>
			${guides ? `<div class="guides">
				<div class="band" style="left:0;top:0;width:${d.inset.l}px;height:${d.h}px"><span>notch</span></div>
				<div class="band" style="right:0;top:0;width:${d.inset.r}px;height:${d.h}px"></div>
				<div class="band" style="left:0;bottom:0;width:${d.w}px;height:${d.inset.b}px"></div>
				<div class="band topbar" style="left:${d.inset.l}px;top:0;width:${d.w - d.inset.l - d.inset.r}px;height:${d.topbar}px"><span>Roblox top bar (TopbarSafeInsets = right of the controls)</span></div></div>` : ""}
		</div>`;
		document.title = `${scene} @ ${size} (${M.bp}, scale ${M.scale.toFixed(2)})`;
	}
	document.fonts.ready.then(() => {});
	render();
	window.__ready = document.fonts.ready.then(() => true);
})();
