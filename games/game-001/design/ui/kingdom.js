// AI Kingdoms (game-001) kingdom HUD, build menu, placement and kingdom panel prototype (FORGE-03, FL-0059).
// URL: kingdom.html?size=phone|tablet|desktop&scene=<name>&guides=1
// The layout maths here is the spec for games/game-001/src/client/UI/Layout.luau (same breakpoints, scale and zones).
// Data shapes follow CONTRACTS G2/G8: Kingdom { id, name, rulers, crownPoints, regions, keepBuildingId },
// Building { id, kingdom, type, level, state, progress }, Treasury bag, Costs.building(type, level).
(function () {
	const T = window.TOKENS;
	const I = (name, size) => window.Icons.svg(name, size);
	const q = new URLSearchParams(location.search);

	// ------------------------------------------------------------------ emulated devices (logical px)
	// Device insets: iPhone 14 class landscape (47 / 47 / 21). Roblox top bar band: 58 px tall with
	// the left controls about 104 px wide (estimates; Studio shows the real rect).
	const DEVICES = {
		phone: { w: 844, h: 390, inset: { l: 47, r: 47, t: 0, b: 21 }, topbar: 58, controls: 104 },
		tablet: { w: 1024, h: 768, inset: { l: 0, r: 0, t: 0, b: 20 }, topbar: 58, controls: 104 },
		desktop: { w: 1920, h: 1080, inset: { l: 0, r: 0, t: 0, b: 0 }, topbar: 58, controls: 104 },
	};
	const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

	// Layout.compute(width, height) of the CoreUISafeInsets area (see Layout.luau).
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
		hud.bottom = phone ? hud.y + 36 : hud.members.y + 22;
		const drawerRight = margin + railButton + 12;
		let drawer;
		if (phone) {
			const x = hud.x + 34 + 8 + 4 * 66 + 3 * 6 + 12;
			const width = Math.max(260, W - drawerRight - x);
			drawer = { x: W - drawerRight - width, y: hud.y, width, height: H - hud.y - margin, single: true };
		} else {
			const width = bp === "tablet" ? 560 : 620;
			const y = hud.bottom + 10;
			drawer = { x: W - drawerRight - width, y, width, height: Math.min(bp === "tablet" ? 470 : 480, H - y - margin), single: false };
		}
		const place = { height: phone ? 52 : 60, bottom: margin };
		return { bp, scale, W, H, margin, hud, rail: { right: margin, button: railButton, gap: 10 }, drawer, toast: { width: phone ? 250 : 300 }, place };
	}

	function metrics(d) {
		const core = { x: d.inset.l, y: Math.max(d.inset.t, d.topbar), w: d.w - d.inset.l - d.inset.r, h: d.h - Math.max(d.inset.t, d.topbar) - d.inset.b };
		const top = { x: d.inset.l + d.controls, y: d.inset.t, w: d.w - d.inset.l - d.inset.r - d.controls, h: d.topbar };
		return Object.assign(layout(core.w, core.h), { core, top });
	}

	// ------------------------------------------------------------------ sample state (G8 shapes; matches the Lune doubles)
	const RES = ["food", "wood", "stone", "gold"];
	const NAMES = { food: "Food", wood: "Wood", stone: "Stone", gold: "Gold" };
	const EMBLEM = { crimson: "emblem_crown", azure: "emblem_star", emerald: "emblem_oak", gold: "emblem_sun" };
	const state = {
		mine: "crimson",
		kingdoms: [
			{ id: "crimson", name: "Emberhold", rulers: ["Sam", "Mira"], crownPoints: 12, regions: ["crimson_home"] },
			{ id: "azure", name: "Frostmere", rulers: ["Tobi"], crownPoints: 20, regions: ["azure_home", "ridge"] },
			{ id: "emerald", name: "Thornwood", rulers: [], crownPoints: 0, regions: ["emerald_home"] },
			{ id: "gold", name: "Sunspire", rulers: [], crownPoints: 0, regions: ["gold_home"] },
		],
		treasury: { food: 132, wood: 110, stone: 50, gold: 0 },
		match: { phase: "Founding", clock: "3:12", label: "match time" },
		buildings: [
			{ id: 1, type: "keep", level: 1, state: "complete" },
			{ id: 2, type: "storehouse", level: 1, state: "complete" },
			{ id: 3, type: "farm", level: 1, state: "complete" },
			{ id: 4, type: "lumbercamp", level: 1, state: "complete" },
			{ id: 5, type: "quarry", level: 1, state: "complete" },
			{ id: 6, type: "house", level: 1, state: "constructing", progress: 0.45 },
		],
	};
	const me = () => state.kingdoms.find((k) => k.id === state.mine);
	// Costs.luau placeholders and Kit.footprint stubs (studs).
	const CATALOG = [
		{ id: "farm", name: "Farm", cat: "economy", cost: { wood: 50 }, sec: 30, fp: [34, 28], desc: "Farmers grow food here. Food feeds every citizen and soldier." },
		{ id: "lumbercamp", name: "Lumber Camp", cat: "economy", cost: { wood: 40 }, sec: 25, fp: [22, 18], desc: "Woodcutters fell nearby trees and bring the logs here." },
		{ id: "quarry", name: "Quarry", cat: "economy", cost: { wood: 60 }, sec: 30, fp: [22, 20], desc: "Miners cut stone and dig gold close to the quarry." },
		{ id: "storehouse", name: "Storehouse", cat: "economy", cost: { wood: 60 }, sec: 30, fp: [22, 18], desc: "A drop-off point: haulers deliver goods to the nearest one." },
		{ id: "house", name: "House", cat: "civic", cost: { wood: 40 }, sec: 20, fp: [20, 16], desc: "Homes for your citizens. More houses, more people." },
		{ id: "barracks", name: "Barracks", cat: "military", cost: { wood: 120, stone: 60 }, sec: 45, fp: [30, 20], desc: "Recruits and trains soldiers for your kingdom." },
		{ id: "watchtower", name: "Watchtower", cat: "military", cost: { wood: 60, stone: 80 }, sec: 40, fp: [14, 14], desc: "A lookout over your lands." },
		{ id: "wall", name: "Wall", cat: "military", cost: { stone: 20 }, sec: 15, fp: [32, 8], desc: "A stone wall segment to close your borders." },
		{ id: "gate", name: "Gate", cat: "military", cost: { wood: 40, stone: 30 }, sec: 25, fp: [32, 12], desc: "A gate in your walls that your people can pass." },
	];
	const TYPE_NAME = { keep: "Keep", house: "House", farm: "Farm", storehouse: "Storehouse", lumbercamp: "Lumber Camp", quarry: "Quarry", barracks: "Barracks", watchtower: "Watchtower", wall: "Wall", gate: "Gate" };
	const CAT = { keep: "civic", house: "civic", farm: "economy", storehouse: "economy", lumbercamp: "economy", quarry: "economy", barracks: "military", watchtower: "military", wall: "military", gate: "military" };
	const fmt = (n) => (n >= 10000 ? (n / 1000).toFixed(0) + "k" : n >= 1000 ? (n / 1000).toFixed(1).replace(/\.0$/, "") + "k" : String(n));
	const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
	const builtCount = (type) => state.buildings.filter((b) => b.type === type).length;

	// ------------------------------------------------------------------ HUD
	const crest = (k, px, extra = "") => `<div class="crest tinted k-${k.id}" style="width:${px}px;height:${px}px">${I(EMBLEM[k.id], Math.round(px * 0.66))}${extra}</div>`;
	const medallion = (res, px) => {
		const c = T.resource[res];
		return `<div class="medallion" style="width:${px}px;height:${px}px;background:linear-gradient(180deg, ${c} 0%, color-mix(in srgb, ${c} 55%, #0B0F18) 100%)">${I(res, Math.round(px * 0.78))}</div>`;
	};
	function pill(res, o = {}) {
		const amt = state.treasury[res];
		const cls = ["pill", o.compact ? "compact" : "", o.delta ? "flash-" + (o.delta < 0 ? "neg" : "pos") : ""].join(" ");
		return `<div class="${cls}">${medallion(res, o.compact ? 24 : 28)}<div class="stack"><div class="amt">${fmt(amt)}</div>
			${o.compact ? "" : `<div class="rate zero">${NAMES[res]}</div>`}</div>
			${o.delta ? `<div class="delta ${o.delta < 0 ? "neg" : "pos"}">${o.delta > 0 ? "+" : "−"}${Math.abs(o.delta)}</div>` : ""}</div>`;
	}
	function hud(M, o = {}) {
		const k = me();
		const h = M.hud;
		const phone = M.bp === "phone";
		const keep = state.buildings.find((b) => b.type === "keep");
		const deltas = o.deltas || {};
		let html = `<div class="badge" style="left:${h.x}px;top:${h.y}px">
			${crest(k, h.crest, phone ? `<div class="pop cp">${I("gem", 11)}${k.crownPoints}</div>` : "")}
			${phone ? "" : `<div class="plate"><div class="kname" style="font-size:26px">${k.name}</div>
				<div class="ksub">Keep <b>Lv ${keep.level}</b> · ${k.regions.length} region${k.regions.length === 1 ? "" : "s"} · <b>${k.crownPoints}</b> Crown Points</div></div>`}</div>`;
		html += `<div class="pills" style="left:${h.pills.x}px;top:${h.pills.y}px" title="OnboardingTarget = HUD.Resources">${RES.map((r) => pill(r, { compact: phone, delta: deltas[r] })).join("")}</div>`;
		if (h.members) {
			html += `<div class="members" style="left:${h.members.x}px;top:${h.members.y}px">${k.rulers
				.map((n, i) => `<div class="member ${i === 0 ? "you" : ""}" style="--k:var(--tincture-${k.id})"><div class="av">${n[0]}</div>${n}${i === 0 ? ` <span class="tag">you</span>` : ""}</div>`)
				.join("")}</div>`;
		}
		return html;
	}
	function timer(M) {
		const phone = M.bp === "phone";
		const w = phone ? 120 : 190;
		const left = (M.top.w - w) / 2;
		return `<div class="timer" style="left:${left}px;top:${(M.top.h - 40) / 2}px;width:${w}px">${I("timer", 28)}
			<div><div class="ph">${state.match.phase}</div><div class="t" style="font-size:${phone ? 15 : 18}px">${state.match.clock}${phone ? "" : `<span class="l" style="margin-left:6px">${state.match.label}</span>`}</div></div></div>`;
	}
	function rail(M, sel) {
		const b = M.rail.button;
		const items = [
			{ id: "build", icon: "build", label: "Build" },
			{ id: "kingdom", icon: "kingdom", label: "Kingdom" },
		];
		const top = (M.H - (items.length * b + (items.length - 1) * M.rail.gap)) / 2;
		return `<div class="rail" style="right:${M.rail.right}px;top:${top}px">${items
			.map((it) => `<div class="railbtn ${sel === it.id ? "sel" : ""}" style="width:${b}px;height:${b}px">${I(it.icon, M.bp === "phone" ? 30 : 32)}
				${M.bp === "phone" ? "" : `<div class="lbl">${it.label}</div>`}</div>`)
			.join("")}</div>`;
	}
	function queue(M, drawerOpen) {
		const items = state.buildings.filter((b) => b.state === "constructing" || b.state === "planned");
		if (!items.length) return "";
		const w = items.length * 196;
		const free = drawerOpen ? M.drawer.x : M.W - M.rail.right - M.rail.button;
		return `<div class="queue" style="left:${(free - w) / 2}px;bottom:${M.margin}px">${items
			.map((b) => `<div class="qchip"><div class="tile ${CAT[b.type]}" style="width:28px;height:28px;border-radius:50%">${I(b.type, 20)}</div>
				<div class="qn">${TYPE_NAME[b.type]}${b.upgrade ? " ↑" : ""}</div><div class="bar" style="width:64px"><i style="width:${Math.round((b.progress || 0) * 100)}%"></i></div><div class="qt">${b.state === "planned" ? "waiting" : Math.round((b.progress || 0) * 100) + "%"}</div></div>`)
			.join("")}</div>`;
	}

	// ------------------------------------------------------------------ build menu
	const costChips = (cost) => Object.entries(cost).map(([r, v]) => `<span class="chip ${state.treasury[r] < v ? "short" : ""}">${I(r, 14)}${v}</span>`).join("");
	function buildRow(e, sel, phone) {
		const tile = phone ? 34 : 40;
		const n = builtCount(e.id);
		return `<div class="row ${sel ? "sel" : ""}">
			<div class="tile ${e.cat}" style="width:${tile}px;height:${tile}px">${I(e.id, tile - 6)}</div>
			<div style="min-width:0"><div class="rname">${e.name}</div><div class="rmeta">${costChips(e.cost)}</div></div>
			<div class="rright">${n ? n + " built" : ""}</div></div>`;
	}
	function shortText(cost) {
		const short = Object.entries(cost).filter(([r, v]) => state.treasury[r] < v);
		if (!short.length) return null;
		const parts = short.map(([r, v]) => `${v - state.treasury[r]} ${NAMES[r]}`);
		return "Need " + (parts.length > 1 ? parts.slice(0, -1).join(", ") + " and " + parts[parts.length - 1] : parts[0]);
	}
	function detail(e, M, o = {}) {
		const phone = M.bp === "phone";
		const tile = phone ? 40 : 56;
		const short = shortText(e.cost);
		const cta = o.done
			? `<div class="btn success">${I("check", 22)}${o.done}</div>`
			: short
				? `<div class="btn disabled">${short}</div>`
				: `<div class="btn primary">${I(o.ctaIcon || "build", 22)}${o.verb || "Place " + e.name}</div>`;
		return `<div class="detail">
			${o.back ? `<div class="back"><span>‹ ${o.back}</span></div>` : ""}
			<div class="dh"><div class="tile ${e.cat}" style="width:${tile}px;height:${tile}px">${I(e.id, tile - 8)}</div>
			<div style="min-width:0"><div class="dname">${o.title || e.name}</div><div class="dmeta">${o.meta || `${e.cat[0].toUpperCase() + e.cat.slice(1)} · ${e.fp[0]} × ${e.fp[1]} studs`}</div></div></div>
			<div class="dscroll">
			${phone ? "" : `<div class="ddesc">${o.desc || e.desc}</div>`}
			<div class="stats"><span class="stat">${I("timer", 16)}${mmss(e.sec)} with builders</span>${o.stats || ""}</div>
			${o.benefits ? `<div class="benefits">${o.benefits.map((b) => `<div class="ben ${b.next ? "next" : ""}"><span class="bl">${b.label}</span><span class="bt">${b.text}</span></div>`).join("")}</div>` : ""}
			<div class="costs">${Object.entries(e.cost)
				.map(([r, v]) => {
					const s = state.treasury[r] < v;
					return `<div class="crow ${s ? "short" : ""}">${I(r, 18)}<span class="n">${NAMES[r]}</span><span class="v">${v}</span>
					<span class="h">${s ? `have ${state.treasury[r]}` : `${I("check", 12).replace("<svg", '<svg style="display:inline;vertical-align:-1px"')} ${state.treasury[r]}`}</span></div>`;
				})
				.join("")}</div></div>
			<div class="cta">${cta}</div></div>`;
	}
	function drawer(M, title, tabs, body) {
		const d = M.drawer;
		const phone = M.bp === "phone";
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.width}px;height:${d.height}px">
			<div class="dhead">${phone ? "" : `<div class="dtitle">${title}</div>`}
			<div class="tabs" style="${phone ? "" : "margin-left:12px"}">${tabs.map((t) => `<div class="tab ${t.sel ? "sel" : ""}">${I(t.icon, 18)}${phone && !t.sel ? "" : t.label}</div>`).join("")}</div>
			<div class="closebtn">${I("close", 20)}</div></div>
			${phone ? "" : `<div class="ornament"></div>`}
			<div class="dbody">${body}</div></div>`;
	}
	function buildMenu(M, cat, selId, view) {
		const phone = M.bp === "phone";
		const listW = M.bp === "tablet" ? 230 : 250;
		const tabs = [
			{ id: "economy", label: "Economy", icon: "food" },
			{ id: "civic", label: "Homes", icon: "house" },
			{ id: "military", label: "Military", icon: "army" },
		].map((t) => Object.assign(t, { sel: t.id === cat }));
		const rows = CATALOG.filter((e) => e.cat === cat);
		const sel = CATALOG.find((e) => e.id === selId);
		if (phone) {
			const label = tabs.find((t) => t.sel).label;
			const body = view === "list" ? `<div class="list fade" style="flex:1;width:auto">${rows.map((e) => buildRow(e, false, true)).join("")}</div>` : detail(sel, M, { back: label });
			return drawer(M, "Build", tabs, body);
		}
		const list = `<div class="list" style="width:${listW}px">${rows.map((e) => buildRow(e, e.id === selId, false)).join("")}</div>`;
		return drawer(M, "Build", tabs, list + detail(sel, M));
	}

	// ------------------------------------------------------------------ placement
	function placebar(M, e, status) {
		const phone = M.bp === "phone";
		const btn = phone ? 44 : 48;
		const w = phone ? 460 : 520;
		const free = M.W - M.rail.right - M.rail.button;
		const st = {
			ok: `<div class="pstatus ok">${I("check", 14)}Good spot</div>`,
			bad: `<div class="pstatus bad">${I("cross", 14)}${o_reason || "Outside your territory"}</div>`,
			wait: `<div class="pstatus wait">Checking…</div>`,
		}[status];
		return `<div class="placebar" style="left:${(free - w) / 2}px;bottom:${M.place.bottom}px;width:${w}px;height:${M.place.height}px">
			<div class="tile ${e.cat}" style="width:${btn - 4}px;height:${btn - 4}px">${I(e.id, btn - 12)}</div>
			<div class="pinfo" style="flex:1"><div class="pname">${e.name} <span style="font:700 11px var(--font-body);color:var(--color-textSecondary)">${costChips(e.cost)}</span></div>${st}</div>
			<div class="pbtns"><div class="iconbtn" style="width:${btn}px;height:${btn}px">${I("rotate", 26)}</div>
			${phone ? `<div class="iconbtn" style="width:${btn}px;height:${btn}px">${I("close", 22)}</div>` : `<div class="btn secondary small" style="height:${btn}px">Cancel</div>`}
			<div class="btn ${status === "ok" ? "primary" : "disabled"} small" style="height:${btn}px">${I("check", 18)}Place</div></div>
			${phone ? "" : `<div class="hint" style="top:auto;bottom:100%;margin:0 0 8px">Move the mouse to aim · R rotates · Click places · Q cancels</div>`}</div>`;
	}
	let o_reason = null;
	// The ghost: a flat footprint box on the ground, tinted by Build.CanPlace, with an arrow for the front (rotation).
	function ghost(d, e, status, rot) {
		const px = 4; // studs → px at this zoom (illustration only)
		return `<div class="ghost ${status}" style="left:${d.w * 0.6}px;top:${d.h * 0.66}px;width:${e.fp[0] * px}px;height:${e.fp[1] * px}px;--rot:${rot * 90}deg"><div class="arrow"></div></div>`;
	}

	// ------------------------------------------------------------------ kingdom panel
	function kingdomPanel(M, tab) {
		const k = me();
		const phone = M.bp === "phone";
		const tabs = [
			{ label: "Overview", icon: "crown", sel: tab === "overview" },
			{ label: "Buildings", icon: "keep", sel: tab === "buildings" },
			{ label: "Jobs", icon: "citizens", sel: tab === "jobs" },
		];
		let body;
		if (tab === "jobs") {
			body = jobsBody(M, o_jobs);
		} else if (tab === "overview") {
			const keep = state.buildings.find((b) => b.type === "keep");
			const standings = [...state.kingdoms].sort((a, b) => b.crownPoints - a.crownPoints);
			body = `<div class="list" style="flex:1;width:auto">
				${phone ? "" : `<div class="kp-banner">${crest(k, 60)}<div><div class="kname" style="font-size:32px">${k.name}</div><div class="ksub">Keep <b>Lv ${keep.level}</b> · ${k.regions.length} region · <b>${k.crownPoints}</b> Crown Points</div></div></div>`}
				<div class="section" style="margin-top:0"><div class="sh">${I("citizens", 18)}Rulers<span class="r">${k.rulers.length} of 4</span></div>
				${k.rulers.map((n, i) => `<div class="mrow" style="--k:var(--tincture-${k.id})"><div class="av">${n[0]}</div>${n}${i === 0 ? ` <span style="color:var(--color-gold400)">(you)</span>` : ""}<span class="role">Ruler</span></div>`).join("")}</div>
				<div class="section"><div class="sh">${I("standings", 18)}Standings<span class="r">Crown Points</span></div>
				${standings.map((s, i) => `<div class="stand ${s.id === k.id ? "me" : ""}"><span class="rk">${i + 1}</span>${crest(s, 22)}<span class="nm">${s.name}${s.rulers.length ? "" : ` <span style="color:var(--color-textMuted);font-weight:600">· AI</span>`}</span><span class="rg">${I("banner", 14)}${s.regions.length}</span><span class="cp">${s.crownPoints}</span></div>`).join("")}</div></div>`;
		} else {
			body = `<div class="list" style="flex:1;width:auto">${state.buildings
				.map((b) => {
					const t = phone ? 34 : 40;
					const canUp = b.type === "keep" && b.state === "complete";
					return `<div class="brow"><div class="tile ${CAT[b.type]}" style="width:${t}px;height:${t}px">${I(b.type, t - 6)}</div>
					<div class="bmid"><div class="rname">${TYPE_NAME[b.type]} <span style="font:700 11px var(--font-body);color:var(--color-gold400)">Lv ${b.level}</span></div>
					${b.state === "constructing" ? `<div class="bsub"><div class="bar" style="flex:1"><i style="width:${b.progress * 100}%"></i></div><b style="color:var(--color-gold300)">${Math.round(b.progress * 100)}%</b></div>` : `<div class="bsub">${b.state === "complete" ? "Complete" : "Waiting for builders"}</div>`}</div>
					${canUp ? `<div class="btn secondary small">${I("build", 16)}Upgrade</div>` : ""}</div>`;
				})
				.join("")}</div>`;
		}
		return drawer(M, "Kingdom", tabs, body);
	}
	// ------------------------------------------------------------------ FL-0065: job panel (Kingdom panel tab)
	// Kingdom.Population { total, byJob, cap } (G13.2) and Kingdom.SetJobQuota(job, count) (G8). Haulers are
	// the free pool: + takes one of them, − gives one back. Soldiers are trained at the barracks (FL-0060).
	const JOBS = [
		{ id: "farmer", name: "Farmers", sub: "Grow food", icon: "food" },
		{ id: "woodcutter", name: "Woodcutters", sub: "Cut wood", icon: "wood" },
		{ id: "miner", name: "Miners", sub: "Stone and gold", icon: "stone" },
		{ id: "builder", name: "Builders", sub: "Raise buildings", icon: "build" },
	];
	let o_jobs = { byJob: { farmer: 3, woodcutter: 3, miner: 2, builder: 2, hauler: 2, soldier: 0 }, cap: 12 };
	function jobsBody(M, P) {
		const phone = M.bp === "phone";
		const b = P.byJob;
		const total = Object.values(b).reduce((a, n) => a + n, 0);
		const free = b.hauler || 0;
		const btn = 44;
		const rows = JOBS.map((j) => {
			const n = b[j.id] || 0;
			const pending = P.pending === j.id;
			const add = !pending && free > 0;
			const rem = !pending && n > 0;
			return `<div class="brow jrow"><div class="tile economy" style="width:${phone ? 34 : 40}px;height:${phone ? 34 : 40}px">${I(j.icon, phone ? 26 : 30)}</div>
				<div class="bmid"><div class="rname">${j.name}</div><div class="bsub">${pending ? `<b style="color:var(--color-gold300)">Asking… ${n} → ${P.target}</b>` : j.sub}</div></div>
				<div class="jctl"><div class="iconbtn ${rem ? "" : "off"}" style="width:${btn}px;height:${btn}px">${I("minus", 20)}</div>
				<div class="jn">${n}</div>
				<div class="iconbtn ${add ? "" : "off"}" style="width:${btn}px;height:${btn}px">${I("plus", 20)}</div></div></div>`;
		}).join("");
		const pool = `<div class="brow jrow muted"><div class="tile civic" style="width:${phone ? 34 : 40}px;height:${phone ? 34 : 40}px">${I("citizens", phone ? 26 : 30)}</div>
			<div class="bmid"><div class="rname">Free citizens</div><div class="bsub">${free > 0 ? "Carry goods · + hires one" : "None free: lower a job"}</div></div><div class="jn solo">${free}</div></div>`;
		const army = `<div class="brow jrow muted"><div class="tile military" style="width:${phone ? 34 : 40}px;height:${phone ? 34 : 40}px">${I("army", phone ? 26 : 30)}</div>
			<div class="bmid"><div class="rname">Soldiers</div><div class="bsub">Train them at the barracks</div></div><div class="jn solo">${b.soldier || 0}</div></div>`;
		const summary = `<div class="jsum">${I("citizens", 16)}<b>${total}</b> citizens · homes for <b>${P.cap}</b> · <b>${free}</b> free</div>`;
		// the free pool first: it is what + draws from (Luau UI/KingdomPanel does the same)
		return `<div class="list" style="flex:1;width:auto">${summary}${pool}${rows}${army}</div>`;
	}
	function upgradePanel(M, done) {
		const e = { id: "keep", name: "Keep", cat: "civic", cost: { wood: 150, stone: 150 }, sec: 60, desc: "A stronger keep. Your citizens nearby cheer when it is done." };
		const tabs = [
			{ label: "Overview", icon: "crown" },
			{ label: "Buildings", icon: "keep", sel: true },
		];
		return drawer(M, "Kingdom", tabs, detail(e, M, { verb: "Upgrade to Lv 2", meta: "Keep · Level 1 → 2", back: "Buildings", done: done ? "Upgrade started" : null }));
	}

	// ------------------------------------------------------------------ FL-0087: plots, plot picker, building upgrade panel
	// Plot sizes (proposal, games/game-001/src/client/UI/SlotFit.luau): the largest footprint over a type's
	// levels decides: <= 18 studs S, <= 26 M, else L; a slot takes its size and every smaller one.
	const SLOT_FIT = { watchtower: "S", house: "M", storehouse: "M", lumbercamp: "M", quarry: "M", farm: "L", barracks: "L" };
	const SIZE_NAME = { S: "Small", M: "Medium", L: "Large" };
	const BENEFITS = {
		lumbercamp: ["Woodcutters fell trees nearby", "More wood", "Even more wood"],
		house: ["Homes 4 citizens", "Homes 8 citizens"],
		storehouse: ["Drop-off point for haulers"],
		quarry: ["Miners cut stone", "More stone", "Even more stone"],
		watchtower: ["Vision over your land", "Archers"],
		farm: ["Grows food", "Food +50 %", "Food +100 %"],
		barracks: ["Recruit up to 5 soldiers", "Recruit up to 10 · faster training", "Recruit up to 15 · faster training", "Recruit up to 20 · veterans (+ morale)"],
	};
	const fits = (slot, type) => "SML".indexOf(SLOT_FIT[type]) <= "SML".indexOf(slot);
	function plotsOverlay(d, sel) {
		const plots = [
			{ id: "p1", size: "M", x: 0.18, y: 0.66 },
			{ id: "p2", size: "S", x: 0.29, y: 0.8 },
			{ id: "p3", size: "L", x: 0.42, y: 0.74 },
			{ id: "p4", size: "M", x: 0.12, y: 0.86, used: "house" },
			{ id: "p5", size: "M", x: 0.36, y: 0.58 },
		];
		const px = { S: 46, M: 64, L: 90 };
		return plots
			.map((p) => {
				const w = px[p.size] * (d.w / 1920 + 0.45);
				return `<div class="plot ${p.id === sel ? "sel" : ""} ${p.used ? "used" : ""}" style="left:${p.x * d.w}px;top:${p.y * d.h}px;width:${w}px;height:${w * 0.62}px">${p.used ? "" : `<span>${p.size}</span>`}</div>`;
			})
			.join("");
	}
	function plotPicker(M, slot, selId, view) {
		const phone = M.bp === "phone";
		const listW = M.bp === "tablet" ? 230 : 250;
		const rows = CATALOG.filter((e) => SLOT_FIT[e.id] && fits(slot, e.id));
		const sel = rows.find((e) => e.id === selId) || rows[0];
		const tabs = [{ label: `${SIZE_NAME[slot]} plot`, icon: "build", sel: true }];
		const opts = { verb: `Build ${sel.name} here`, meta: `${sel.cat[0].toUpperCase() + sel.cat.slice(1)} · fits ${SIZE_NAME[slot].toLowerCase()} plots`, benefits: [{ label: "Gives", text: BENEFITS[sel.id][0] }] };
		if (phone) {
			const body = view === "list" ? `<div class="list fade" style="flex:1;width:auto">${rows.map((e) => buildRow(e, false, true)).join("")}</div>` : detail(sel, M, Object.assign({ back: "Plot" }, opts));
			return drawer(M, "Build here", tabs, body);
		}
		const list = `<div class="list" style="width:${listW}px">${rows.map((e) => buildRow(e, e.id === sel.id, false)).join("")}</div>`;
		return drawer(M, "Build here", tabs, list + detail(sel, M, opts));
	}
	function buildingPanel(M, b, o = {}) {
		const levels = { barracks: [{ wood: 120, stone: 60 }, { wood: 100, stone: 80 }, { wood: 150, stone: 120, gold: 20 }, { wood: 200, stone: 180, gold: 50 }], watchtower: [{ wood: 60, stone: 80 }, { wood: 60, stone: 100 }] };
		const secs = { barracks: [8, 18, 35, 60], watchtower: [40, 40] };
		const max = levels[b.type].length;
		const info = CATALOG.find((e) => e.id === b.type);
		const tabs = [{ label: `${info.name} · Lv ${b.level}`, icon: info.id, sel: true }];
		const top = b.level >= max;
		const e = Object.assign({}, info, { cost: top ? {} : levels[b.type][b.level], sec: top ? 0 : secs[b.type][b.level] });
		const benefits = [{ label: "Now", text: BENEFITS[b.type][b.level - 1] }];
		if (!top) benefits.push({ label: `Lv ${b.level + 1}`, text: BENEFITS[b.type][b.level], next: true });
		if (o.foreign) {
			return drawer(M, "Building", [{ label: `${info.name} · Lv ${b.level}`, icon: info.id, sel: true }], `<div class="detail"><div class="dh"><div class="tile ${info.cat}" style="width:56px;height:56px">${I(info.id, 48)}</div><div><div class="dname">${info.name}</div><div class="dmeta">Frostmere · Level ${b.level}</div></div></div><div class="dscroll"><div class="ddesc">${info.desc}</div></div><div class="cta"><div class="btn disabled">Not your building</div></div></div>`);
		}
		return drawer(M, "Upgrade", tabs, detail(e, M, {
			verb: `Upgrade to Lv ${b.level + 1}`,
			meta: top ? `${info.name} · Level ${b.level} (highest)` : `${info.name} · Level ${b.level} → ${b.level + 1}`,
			benefits,
			done: top ? null : o.done,
		}).replace(top ? /<div class="btn [^"]*">[^]*?<\/div><\/div>$/ : /$^/, top ? `<div class="btn disabled">Highest level reached</div></div>` : ""));
	}

	// ------------------------------------------------------------------ backdrop: a stylised kingdom view
	function world(w, h) {
		const houses = [];
		const rnd = (i) => ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;
		for (let i = 0; i < 22; i++) {
			const x = 0.14 + rnd(i) * 0.4, y = 0.5 + rnd(i + 99) * 0.38;
			const s = 10 + y * 22;
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

	// ------------------------------------------------------------------ scenes
	const farm = CATALOG[0];
	const SCENES = {
		hud: (M) => ({ core: hud(M) + rail(M) + queue(M, false) }),
		build: (M) => ({ core: hud(M) + rail(M, "build") + buildMenu(M, "economy", "farm", "list") }),
		"build-detail": (M) => ({ core: hud(M) + rail(M, "build") + buildMenu(M, "economy", "farm", "detail") }),
		"build-short": (M) => ({ core: hud(M) + rail(M, "build") + buildMenu(M, "military", "barracks", "detail") }),
		placing: (M, d) => ({ world: ghost(d, farm, "ok", 0), core: hud(M) + rail(M) + placebar(M, farm, "ok") }),
		"placing-bad": (M, d) => {
			o_reason = "Outside your territory";
			return { world: ghost(d, farm, "bad", 1), core: hud(M) + rail(M) + placebar(M, farm, "bad") };
		},
		placed: (M) => {
			state.treasury.wood = 60;
			state.buildings.push({ id: 7, type: "farm", level: 1, state: "planned", progress: 0 });
			return {
				core:
					hud(M, { deltas: { wood: -50 } }) +
					rail(M) +
					queue(M, false) +
					`<div class="toasts" style="right:${M.margin + M.rail.button + 12}px;top:${M.hud.y}px">${toast(M, "success", "farm", "Farm placed", "Builders are on their way")}</div>`,
			};
		},
		kingdom: (M) => ({ core: hud(M) + rail(M, "kingdom") + kingdomPanel(M, "overview") }),
		"kingdom-buildings": (M) => ({ core: hud(M) + rail(M, "kingdom") + kingdomPanel(M, "buildings") }),
		"kingdom-jobs": (M) => {
			o_jobs = { byJob: { farmer: 3, woodcutter: 3, miner: 2, builder: 2, hauler: 2, soldier: 0 }, cap: 12, pending: "woodcutter", target: 4 };
			return { core: hud(M) + rail(M, "kingdom") + kingdomPanel(M, "jobs") };
		},
		"kingdom-jobs-full": (M) => {
			o_jobs = { byJob: { farmer: 4, woodcutter: 2, miner: 2, builder: 2, hauler: 0, soldier: 2 }, cap: 12 };
			return { core: hud(M) + rail(M, "kingdom") + kingdomPanel(M, "jobs") };
		},
		upgrade: (M) => {
			state.treasury = { food: 132, wood: 180, stone: 160, gold: 0 };
			return { core: hud(M) + rail(M, "kingdom") + upgradePanel(M) };
		},
		// FL-0087 (tap a plot / a building in the aerial view)
		"plot-pick": (M, d) => ({ world: plotsOverlay(d, "p1"), core: hud(M) + rail(M) + plotPicker(M, "M", "lumbercamp", "detail") }),
		"plot-pick-list": (M, d) => ({ world: plotsOverlay(d, "p1"), core: hud(M) + rail(M) + plotPicker(M, "M", "lumbercamp", "list") }),
		"plot-pick-large": (M, d) => ({ world: plotsOverlay(d, "p3"), core: hud(M) + rail(M) + plotPicker(M, "L", "barracks", "detail") }),
		"building-upgrade": (M, d) => {
			state.treasury = { food: 132, wood: 180, stone: 160, gold: 0 };
			return { world: plotsOverlay(d, ""), core: hud(M) + rail(M) + buildingPanel(M, { type: "barracks", level: 1 }) };
		},
		"building-max": (M, d) => ({ world: plotsOverlay(d, ""), core: hud(M) + rail(M) + buildingPanel(M, { type: "watchtower", level: 2 }) }),
		"building-foreign": (M, d) => ({ world: plotsOverlay(d, ""), core: hud(M) + rail(M) + buildingPanel(M, { type: "barracks", level: 2 }, { foreign: true }) }),
	};
	function toast(M, kind, icon, title, body) {
		const k = { success: "var(--color-vert)", error: "var(--color-gules)", info: "var(--color-azure)" }[kind];
		return `<div class="toast" style="--k:${k};width:${M.toast.width}px">${I(icon, 28)}<div><div class="tt">${title}</div>${body ? `<div class="tb">${body}</div>` : ""}</div></div>`;
	}
	window.FL0059_SCENES = Object.keys(SCENES);

	function render() {
		const size = q.get("size") || "desktop";
		const scene = q.get("scene") || "hud";
		const d = DEVICES[size];
		const M = metrics(d);
		const out = SCENES[scene](M, d);
		const guides = q.get("guides") === "1";
		document.body.innerHTML = `<div class="viewport" style="width:${d.w}px;height:${d.h}px">
			<div class="world">${world(d.w, d.h)}${out.world || ""}</div>
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
	render();
	window.__ready = document.fonts.ready.then(() => true);
})();
