// AI Kingdoms (game-001) army drawer, objective tracker and slice summary prototype (FORGE-03, FL-0060).
// URL: army.html?size=phone|tablet|desktop&scene=<name>&guides=1
// The layout maths is the spec for the `objectives` zone added to games/game-001/src/client/UI/Layout.luau;
// the HUD drawing helpers are copied from reputation.js (FL-0089) / kingdom.js (FL-0059).
// Data shapes follow CONTRACTS G8: Army.Recruit(barracksId, "soldier", count 1..10) -> (ok, reason?);
// Army.Command({}, "capture") (event, empty unitIds = all my idle soldiers, VS-1 command);
// Army.Objectives / Army.GetObjectives = ObjectiveService:list() { id, kind, position, radius, owner?, progress };
// Match.Ended = G9 MatchEnded { winner?, standings: { { kingdom, crownPoints } }, durationSec };
// Costs.unit("soldier") = { cost = { food = 30, wood = 10 }, trainSeconds = 8, upkeepFood = 1 } (config Costs, PROVISIONAL).
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

	// Layout.compute(width, height) with the FL-0089 reputation zone and the FL-0060 objectives zone.
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
		const rep = phone
			? { x: hud.x, y: hud.y + hud.crest + 12, columns: 6, item: { w: 50, h: 22 }, gx: 3, gy: 0, pad: 4 }
			: { x: hud.x, y: hud.members.y + 22 + 6, columns: 3, item: { w: 118, h: 22 }, gx: 8, gy: 6, pad: 6 };
		if (phone) rep.item.w = clamp(Math.floor((drawer.x - hud.x - margin - 2 * rep.pad - 5 * rep.gx) / 6), 44, 50);
		const rows = 6 / rep.columns;
		rep.width = rep.columns * rep.item.w + (rep.columns - 1) * rep.gx + 2 * rep.pad;
		rep.height = rows * rep.item.h + (rows - 1) * rep.gy + 2 * rep.pad;
		hud.reputation = rep;
		hud.bottom = rep.y + rep.height;
		// FL-0060: the objective tracker hangs under the top-left stack (not part of hud.bottom: drawers keep their size).
		if (!phone) {
			const width = bp === "tablet" ? 560 : 620;
			const y = hud.bottom + 10;
			drawer = { x: W - drawerRight - width, y, width, height: Math.min(bp === "tablet" ? 470 : 480, H - y - margin), single: false };
		}
		// at most 224 / 272 px and 12 px clear of the drawer (tablet: 261 px; the Luau render found the 1 px gap)
		hud.objectives = { x: hud.x, y: hud.bottom + (phone ? 8 : 10), width: Math.max(160, Math.min(phone ? 224 : 272, drawer.x - hud.x - 12)) };
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
	const EMBLEM = { crimson: "emblem_crown", azure: "emblem_star", emerald: "emblem_oak", gold: "emblem_sun" };
	const KINGDOMS = {
		crimson: { id: "crimson", name: "Emberhold", isAI: false },
		azure: { id: "azure", name: "Frostmere", isAI: false },
		emerald: { id: "emerald", name: "Thornwood", isAI: true },
		gold: { id: "gold", name: "Sunspire", isAI: true },
	};
	const MINE = "crimson";
	const state = {
		kingdom: { id: "crimson", name: "Emberhold", rulers: ["Sam", "Mira"], crownPoints: 12 },
		treasury: { food: 132, wood: 110, stone: 50, gold: 0 },
		soldiers: 4,
	};
	const UNIT = { name: "Soldier", cost: { food: 30, wood: 10 }, train: 8, upkeep: 1 };
	const REP = { compassion: 62, honor: 48, competence: 55, courage: 40, authority: 70, fear: 15 };
	const CATS = [
		{ id: "compassion", name: "Compassion", icon: "rep_compassion", color: "vert" },
		{ id: "honor", name: "Honor", icon: "rep_honor", color: "azure" },
		{ id: "competence", name: "Competence", icon: "rep_competence", color: "amber" },
		{ id: "courage", name: "Courage", icon: "rep_courage", color: "gules" },
		{ id: "authority", name: "Authority", icon: "rep_authority", color: "purpure" },
		{ id: "fear", name: "Fear", icon: "rep_fear", color: "textSecondary" },
	];
	const OBJECTIVES = {
		capturing: [{ id: "watchtower", owner: null, progress: { crimson: 0.64, azure: 0.2 } }],
		// VS-1 has one objective; the list view is drawn with two to show how more would stack.
		list: [
			{ id: "watchtower", owner: null, progress: { crimson: 0.64, azure: 0.2, emerald: 0.08 } },
			{ id: "old_ford", owner: "azure", progress: { azure: 1, gold: 0.3 } },
		],
		neutral: [{ id: "watchtower", owner: null, progress: {} }],
	};
	const fmt = (n) => (n >= 10000 ? (n / 1000).toFixed(0) + "k" : n >= 1000 ? (n / 1000).toFixed(1).replace(/\.0$/, "") + "k" : String(n));
	const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
	const kcolor = (id) => `var(--tincture-${id})`;
	const nameOf = (id) => id.split("_").map((w) => w[0].toUpperCase() + w.slice(1)).join(" ");

	// ------------------------------------------------------------------ HUD (from reputation.js)
	const crest = (id, px, extra = "") => `<div class="crest tinted k-${id}" style="width:${px}px;height:${px}px">${I(EMBLEM[id], Math.round(px * 0.66))}${extra}</div>`;
	const medallion = (res, px) => {
		const c = T.resource[res];
		return `<div class="medallion" style="width:${px}px;height:${px}px;background:linear-gradient(180deg, ${c} 0%, color-mix(in srgb, ${c} 55%, #0B0F18) 100%)">${I(res, Math.round(px * 0.78))}</div>`;
	};
	const pill = (res, compact, delta) =>
		`<div class="pill ${compact ? "compact" : ""} ${delta ? "flash-" + (delta < 0 ? "neg" : "pos") : ""}">${medallion(res, compact ? 24 : 28)}<div class="stack"><div class="amt">${fmt(state.treasury[res])}</div>${compact ? "" : `<div class="rate zero">${NAMES[res]}</div>`}</div>
		${delta ? `<div class="delta ${delta < 0 ? "neg" : "pos"}">${delta > 0 ? "+" : "−"}${Math.abs(delta)}</div>` : ""}</div>`;
	function hud(M, o = {}) {
		const k = state.kingdom;
		const h = M.hud;
		const phone = M.bp === "phone";
		const deltas = o.deltas || {};
		let html = `<div class="badge" style="left:${h.x}px;top:${h.y}px">
			${crest(k.id, h.crest, phone ? `<div class="pop cp">${I("gem", 11)}${k.crownPoints}</div>` : "")}
			${phone ? "" : `<div class="plate"><div class="kname" style="font-size:26px">${k.name}</div>
				<div class="ksub">Keep <b>Lv 1</b> · 1 region · <b>${k.crownPoints}</b> Crown Points</div></div>`}</div>`;
		html += `<div class="pills" style="left:${h.pills.x}px;top:${h.pills.y}px">${RES.map((r) => pill(r, phone, deltas[r])).join("")}</div>`;
		if (h.members) {
			html += `<div class="members" style="left:${h.members.x}px;top:${h.members.y}px">${k.rulers
				.map((n, i) => `<div class="member ${i === 0 ? "you" : ""}" style="--k:var(--tincture-crimson)"><div class="av">${n[0]}</div>${n}${i === 0 ? ` <span class="tag">you</span>` : ""}</div>`)
				.join("")}</div>`;
		}
		const r = h.reputation;
		const compact = phone;
		html += `<div class="repstrip ${compact ? "compact" : ""}" style="left:${r.x}px;top:${r.y}px;width:${r.width}px;height:${r.height}px;--pad:${r.pad}px;--gx:${r.gx}px;--gy:${r.gy}px;grid-template-columns:repeat(${r.columns}, ${r.item.w}px)">${CATS.map(
			(c) => `<div class="it" style="width:${r.item.w}px;height:${r.item.h}px"><div class="ln">${I(c.icon, compact ? 15 : 14)}${compact ? "" : `<span class="nm">${c.name}</span>`}<span class="v">${REP[c.id]}</span></div>
				<div class="rbar"><i style="width:${REP[c.id]}%;--c:var(--color-${c.color})"></i></div></div>`
		).join("")}</div>`;
		return html;
	}
	function timer(M, phase = "Founding", clock = "3:12") {
		const phone = M.bp === "phone";
		const w = phone ? 120 : 190;
		return `<div class="timer" style="left:${(M.top.w - w) / 2}px;top:${(M.top.h - 40) / 2}px;width:${w}px">${I("timer", 28)}
			<div><div class="ph">${phase}</div><div class="t" style="font-size:${phone ? 15 : 18}px">${clock}${phone ? "" : `<span class="l" style="margin-left:6px">match time</span>`}</div></div></div>`;
	}
	// The rail gains a third button, Army (registered by ArmyPanelController).
	function rail(M, sel) {
		const b = M.rail.button;
		const items = [{ id: "build", icon: "build", label: "Build" }, { id: "kingdom", icon: "kingdom", label: "Kingdom" }, { id: "army", icon: "army", label: "Army" }];
		const top = (M.H - (items.length * b + (items.length - 1) * M.rail.gap)) / 2;
		return `<div class="rail" style="right:${M.rail.right}px;top:${top}px">${items
			.map((it) => `<div class="railbtn ${sel === it.id ? "sel" : ""}" style="width:${b}px;height:${b}px">${I(it.icon, M.bp === "phone" ? 30 : 32)}${M.bp === "phone" ? "" : `<div class="lbl">${it.label}</div>`}</div>`)
			.join("")}</div>`;
	}
	function queue(M, drawerOpen) {
		const free = drawerOpen ? M.drawer.x : M.W - M.rail.right - M.rail.button;
		const w = 196;
		return `<div class="queue" style="left:${(free - w) / 2}px;bottom:${M.margin}px"><div class="qchip"><div class="tile civic" style="width:28px;height:28px;border-radius:50%">${I("house", 20)}</div>
			<div class="qn">House</div><div class="bar" style="width:64px"><i style="width:45%"></i></div><div class="qt">45%</div></div></div>`;
	}
	function toast(M, kind, icon, title, body, top, right) {
		const k = { success: "var(--color-vert)", error: "var(--color-gules)", info: "var(--color-azure)" }[kind];
		return `<div class="toasts" style="right:${right}px;top:${top}px"><div class="toast" style="--k:${k};width:${M.toast.width}px">${I(icon, 28)}<div><div class="tt">${title}</div>${body ? `<div class="tb">${body}</div>` : ""}</div></div></div>`;
	}

	// ------------------------------------------------------------------ objective tracker (UI/ObjectiveTracker)
	// Bars: every kingdom with progress > 0, except an owner that holds it fully; mine first, then by progress.
	function bars(o) {
		return Object.entries(o.progress)
			.filter(([k, v]) => v > 0 && !(k === o.owner && v >= 1))
			.sort((a, b) => (a[0] === MINE ? -1 : b[0] === MINE ? 1 : b[1] - a[1]))
			.map(([k, v]) => ({ k, v, me: k === MINE }));
	}
	function ownerChip(o) {
		if (!o.owner) return `<div class="oowner neutral">${I("watchtower", 12)}Neutral</div>`;
		if (o.owner === MINE) return `<div class="oowner mine"><i class="sw" style="--k:${kcolor(o.owner)}"></i>Yours</div>`;
		return `<div class="oowner"><i class="sw" style="--k:${kcolor(o.owner)}"></i>${KINGDOMS[o.owner].name}</div>`;
	}
	function statusLine(o) {
		if (o.owner === MINE) return "No one is challenging you";
		if (o.owner) return "Send soldiers to take it";
		return "Send soldiers to capture it";
	}
	function orow(o, i, n, maxBars) {
		const list = bars(o);
		const shown = maxBars ? list.slice(0, maxBars) : list;
		return `<div class="orow"><div class="ohead">${n > 1 ? `<div class="onum">${i + 1}</div>` : I("watchtower", 18)}<div class="oname">${nameOf(o.id)}</div>${ownerChip(o)}</div>
			${shown.length
				? shown.map((b) => `<div class="obar ${b.me ? "me" : ""}"><i class="sw" style="--k:${kcolor(b.k)}"></i><span class="kn">${b.me ? "You" : KINGDOMS[b.k].name}</span>
					<div class="rbar"><i style="width:${Math.round(b.v * 100)}%;--c:${kcolor(b.k)}"></i></div><span class="pc">${Math.round(b.v * 100)}%</span></div>`).join("")
				: `<div class="ostatus">${statusLine(o)}</div>`}</div>`;
	}
	function tracker(M, list, o = {}) {
		const z = M.hud.objectives;
		const open = !!o.open;
		let body;
		if (open) {
			body = `<div class="otitle">${I("watchtower", 14)}Objectives<span class="r">${list.length} · tap to close ▴</span></div>` + list.map((x, i) => orow(x, i, list.length, 0)).join("");
		} else {
			const focus = list[0];
			const hidden = list.length - 1 + Math.max(0, bars(focus).length - 2);
			body = orow(focus, 0, 1, 2) + (hidden > 0 ? `<div class="omore">+${hidden} more ▾</div>` : "");
		}
		return `<div class="otrack ${open ? "open" : ""}" style="left:${z.x}px;top:${z.y}px;width:${z.width}px">${body}${o.guides ? `<div class="hitguide"></div>` : ""}</div>`;
	}

	// ------------------------------------------------------------------ army drawer (UI/ArmyPanel)
	function drawer(M, title, tabs, body) {
		const d = M.drawer;
		const phone = M.bp === "phone";
		const close = phone ? 44 : 36;
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.width}px;height:${d.height}px">
			<div class="dhead">${phone ? "" : `<div class="dtitle">${title}</div>`}
			<div class="tabs" style="${phone ? "" : "margin-left:12px"}">${tabs.map((t) => `<div class="tab ${t.sel ? "sel" : ""}">${I(t.icon, 18)}${t.label}</div>`).join("")}</div>
			<div class="closebtn" style="width:${close}px;height:${close}px">${I("close", 20)}</div></div>
			${phone ? "" : `<div class="ornament"></div>`}
			<div class="dbody">${body}</div></div>`;
	}
	function shortText(cost) {
		const short = Object.entries(cost).filter(([r, v]) => state.treasury[r] < v);
		if (!short.length) return null;
		const parts = short.map(([r, v]) => `${v - state.treasury[r]} ${NAMES[r]}`);
		return "Need " + (parts.length > 1 ? parts.slice(0, -1).join(", ") + " and " + parts[parts.length - 1] : parts[0]);
	}
	function army(M, o = {}) {
		const phone = M.bp === "phone";
		const count = o.count || 3;
		const soldiers = o.soldiers === undefined ? state.soldiers : o.soldiers;
		const cost = Object.fromEntries(Object.entries(UNIT.cost).map(([r, v]) => [r, v * count]));
		const short = shortText(cost);
		const barracks = o.barracks !== false;
		const recruitCta = !barracks
			? `<div class="btn disabled">Build a Barracks first</div>`
			: short
				? `<div class="btn disabled">${short}</div>`
				: `<div class="btn primary">${I("militia", 22)}Recruit ${count} soldier${count === 1 ? "" : "s"}</div>`;
		const sendCta = soldiers === 0
			? `<div class="btn disabled">No soldiers yet</div>`
			: o.sent
				? `<div class="btn success">${I("check", 22)}Sent</div>`
				: `<div class="btn primary">${I("banner", 22)}Send to capture</div>`;
		const status = o.sent
			? `<div class="astatus ok">${I("check", 14)}Sent to the nearest tower</div>`
			: soldiers === 0
				? `<div class="astatus">Recruit soldiers first</div>`
				: `<div class="astatus">Idle soldiers march to the nearest tower</div>`;
		const costRows = Object.entries(cost)
			.map(([r, v]) => {
				const s = state.treasury[r] < v;
				return `<div class="crow ${s ? "short" : ""}">${I(r, 18)}<span class="n">${NAMES[r]}</span><span class="v">${v}</span><span class="h">${s ? `have ${state.treasury[r]}` : `✓ ${state.treasury[r]}`}</span></div>`;
			})
			.join("");
		const tabs = barracks ? [{ label: "Barracks · Lv 1", icon: "barracks" }, { label: "Army", icon: "army", sel: true }] : [{ label: "Army", icon: "army", sel: true }];
		const obj = OBJECTIVES.capturing[0];
		if (phone) {
			const lines = Object.entries(cost)
				.map(([r, v]) => {
					const s = state.treasury[r] < v;
					return `<div class="cline ${s ? "short" : ""}">${I(r, 16)}${v}<span class="h">${s ? `have ${state.treasury[r]}` : `✓ ${state.treasury[r]}`}</span></div>`;
				})
				.join("");
			const body = `<div class="aphone">
				<div class="aline"><div class="tile military" style="width:40px;height:40px">${I("army", 30)}</div><div class="acount" style="flex:1"><div class="k">Your army</div><div class="n"><b>${soldiers}</b>soldier${soldiers === 1 ? "" : "s"}</div></div>
					<div style="width:176px">${sendCta}</div></div>
				${status}
				<div class="adiv"></div>
				${barracks
					? `<div class="unitline">${I("militia", 16)}Recruit soldiers<span class="m">· ${mmss(UNIT.train)} each · ${UNIT.upkeep} Food/min</span></div>
						<div class="aline"><div class="stepper big"><div class="stepbtn ${count <= 1 ? "off" : ""}">${I("minus", 20)}</div><div class="stepv">${count}</div><div class="stepbtn ${count >= 10 ? "off" : ""}">${I("plus", 20)}</div></div><div class="ccol">${lines}</div></div>
						${recruitCta}`
					: `<div class="notice">${I("barracks", 24)}Build a Barracks to recruit soldiers.</div>`}</div>`;
			return drawer(M, "Army", tabs, body);
		}
		const recruit = barracks
			? `<div class="acard" style="flex:1.25">
				<div class="dh"><div class="tile military" style="width:48px;height:48px">${I("militia", 40)}</div><div style="min-width:0"><div class="dname">Soldier</div><div class="dmeta">Recruit at Barracks Lv 1</div></div></div>
				<div class="ddesc">Soldiers march, fight and capture towers for your kingdom.</div>
				<div class="stats"><span class="stat">${I("timer", 16)}${mmss(UNIT.train)} each</span><span class="stat">${I("food", 16)}Upkeep ${UNIT.upkeep} Food/min each</span></div>
				<div class="howmany"><span class="hl">How many</span><div class="stepper mid"><div class="stepbtn ${count <= 1 ? "off" : ""}">${I("minus", 18)}</div><div class="stepv">${count}</div><div class="stepbtn ${count >= 10 ? "off" : ""}">${I("plus", 18)}</div></div></div>
				<div class="costs">${costRows}</div><div class="spacer"></div>${recruitCta}</div>`
			: `<div class="acard" style="flex:1.25"><div class="kicker">${I("militia", 14)}Recruit</div><div class="notice">${I("barracks", 28)}Build a Barracks to recruit soldiers. Its tab here lets you train them.</div><div class="spacer"></div>${recruitCta}</div>`;
		const own = `<div class="acard" style="flex:1">
			<div class="kicker">${I("army", 14)}Your army</div>
			<div class="bignum"><b>${soldiers}</b>soldier${soldiers === 1 ? "" : "s"}</div>
			<div class="asub">Upkeep ${soldiers * UNIT.upkeep} Food/min</div>
			<div class="adiv"></div>
			<div class="sh">${I("banner", 16)}Send to capture</div>
			<div class="pt">Idle soldiers march to the nearest tower you don't hold and take it.</div>
			<div class="target">${I("watchtower", 20)}<div><div>${nameOf(obj.id)}</div><div class="tm">Neutral · you ${Math.round(obj.progress.crimson * 100)}%</div></div></div>
			<div class="spacer"></div>${o.sent || soldiers === 0 ? status : ""}${sendCta}</div>`;
		return drawer(M, "Army", tabs, `<div class="acols">${recruit}${own}</div>`);
	}
	// The barracks' upgrade panel (FL-0087) with its new Army tab.
	function upgradeTab(M) {
		const phone = M.bp === "phone";
		const tabs = [{ label: "Barracks · Lv 1", icon: "barracks", sel: true }, { label: "Army", icon: "army" }];
		const body = `<div class="detail"><div class="dh"><div class="tile military" style="width:${phone ? 40 : 56}px;height:${phone ? 40 : 56}px">${I("barracks", phone ? 32 : 48)}</div>
			<div><div class="dname">Barracks</div><div class="dmeta">Barracks · Level 1 → 2</div></div></div>
			<div class="stats"><span class="stat">${I("timer", 16)}0:18 with builders</span></div>
			<div class="costs"><div class="crow">${I("wood", 18)}<span class="n">Wood</span><span class="v">100</span><span class="h">✓ 110</span></div>
			<div class="crow short">${I("stone", 18)}<span class="n">Stone</span><span class="v">80</span><span class="h">have 50</span></div></div>
			<div class="spacer"></div><div class="cta"><div class="btn disabled">Need 30 Stone</div></div></div>`;
		return drawer(M, "Upgrade", tabs, body);
	}

	// ------------------------------------------------------------------ slice summary (UI/SliceSummary)
	const STANDINGS = [
		{ kingdom: "azure", crownPoints: 120 },
		{ kingdom: "crimson", crownPoints: 112 },
		{ kingdom: "emerald", crownPoints: 40 },
		{ kingdom: "gold", crownPoints: 0 },
	];
	function summary(d, M, winner, standings) {
		const phone = M.bp === "phone";
		const mineWins = winner === MINE;
		const kick = mineWins ? `<div class="skick win">${I("laurel", 14)}Victory</div>` : `<div class="skick">${I("standings", 14)}Match over</div>`;
		const head = winner
			? `<div class="swin">${crest(winner, phone ? 48 : 60)}<div><div class="sname" style="font-size:${phone ? 30 : 36}px">${KINGDOMS[winner].name}</div><div class="ssub ${mineWins ? "mine" : ""}">${mineWins ? "Your kingdom wins" : "wins the match"}</div></div></div>`
			: `<div class="swin"><div class="crest" style="width:${phone ? 48 : 60}px;height:${phone ? 48 : 60}px;background:linear-gradient(180deg,var(--color-ink600),var(--color-ink900))">${I("standings", phone ? 30 : 38)}</div><div><div class="sname" style="font-size:${phone ? 30 : 36}px">No winner</div><div class="ssub">Nobody won the match</div></div></div>`;
		const rows = standings
			.map((s, i) => {
				const k = KINGDOMS[s.kingdom];
				const me = s.kingdom === MINE;
				return `<div class="srow ${me ? "me" : ""}"><span class="rk">${i + 1}${s.kingdom === winner ? I("laurel", 14) : ""}</span>${crest(s.kingdom, 22)}<span class="nm">${k.name}</span>
					${me ? `<span class="tagc you">you</span>` : ""}${k.isAI ? `<span class="tagc ai">AI</span>` : ""}<span class="cp">${s.crownPoints}</span></div>`;
			})
			.join("");
		const table = `<div class="shead">${I("standings", 14)}Standings<span class="r">Crown Points</span></div><div class="srows">${rows}</div>`;
		const duration = `<div class="stats" style="margin:0"><span class="stat">${I("timer", 16)}Lasted 12:34</span></div>`;
		const btn = `<div class="btn primary">${I("check", 22)}Continue</div>`;
		const w = phone ? 600 : 460;
		const h = phone ? 262 : 392; // tablet/desktop: fitted to the content (4 standings)
		const body = phone
			? `<div class="lcol">${kick}${head}${duration}<div class="spacer"></div>${btn}</div><div class="rcol">${table}</div>`
			: `${kick}${head}${duration}${table}<div class="spacer" style="flex:1;min-height:4px"></div>${btn}`;
		// The modal layer is ScreenInsets.None: the scrim covers the notch strips; the panel is centred on the device.
		const LW = d.w / M.scale, LH = d.h / M.scale; // the modal root is the whole device in logical px
		return `<div class="scrimall"></div><div class="panel summary ${phone ? "two" : ""}" style="left:${Math.floor((LW - w) / 2)}px;top:${Math.floor((LH - h) / 2)}px;width:${w}px;height:${h}px">${body}</div>`;
	}

	// ------------------------------------------------------------------ backdrop (as reputation.js)
	function world(w, h) {
		const rnd = (i) => ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;
		const houses = [];
		for (let i = 0; i < 22; i++) {
			const x = 0.14 + rnd(i) * 0.4, y = 0.5 + rnd(i + 99) * 0.38, s = 10 + y * 22;
			houses.push(`<g transform="translate(${x * w} ${y * h})"><rect x="${-s / 2}" y="${-s * 0.6}" width="${s}" height="${s * 0.6}" fill="#E9DCB8"/><path d="M${-s * 0.62} ${-s * 0.55} L0 ${-s * 1.05} L${s * 0.62} ${-s * 0.55} Z" fill="${i % 3 ? "#B8402E" : "#7D2E22"}"/></g>`);
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
			${trees.join("")}
			<path d="M${w * 0.5} ${h * 0.42} C ${w * 0.44} ${h * 0.6} ${w * 0.56} ${h * 0.72} ${w * 0.48} ${h}" stroke="#5C9BC7" stroke-width="${h * 0.035}" fill="none" opacity="0.9"/>
			${houses.join("")}
			<g transform="translate(${w * 0.62} ${h * 0.44})"><rect x="-9" y="-62" width="18" height="62" fill="#CFC3A6"/><rect x="-14" y="-74" width="28" height="14" fill="#BDB295"/><path d="M-16 -74 L0 -94 L16 -74 Z" fill="#8E8E8E"/>
				<ellipse cx="0" cy="0" rx="54" ry="18" fill="none" stroke="#F7EFDC" stroke-width="2.5" stroke-dasharray="6 5" opacity="0.85"/></g>
		</svg>`;
	}

	// ------------------------------------------------------------------ scenes
	const OB = OBJECTIVES;
	const toastRight = (M, open) => (open && M.bp === "phone" ? M.W - M.drawer.x + 10 : M.margin + M.rail.button + 12);
	function toastTop(M, open, trackerBottom) {
		if (open && M.bp === "phone") return (trackerBottom || M.hud.bottom) + 8;
		return M.hud.y;
	}
	const SCENES = {
		hud: (M, d, g) => hud(M) + tracker(M, OB.capturing, { guides: g }) + rail(M) + queue(M, false),
		"hud-open": (M) => hud(M) + tracker(M, OB.list, { open: true }) + rail(M) + queue(M, false),
		army: (M, d, g) => hud(M) + tracker(M, OB.capturing, { guides: g }) + rail(M, "army") + army(M, { count: 3 }),
		"army-short": (M) => hud(M) + tracker(M, OB.capturing) + rail(M, "army") + army(M, { count: 5 }),
		"army-none": (M) => hud(M) + tracker(M, OB.neutral) + rail(M, "army") + army(M, { count: 1, soldiers: 0 }),
		"army-sent": (M) => {
			// tracker bottom (phone) = y + one row with two bars (6 + 20 + 2 * 18 + 6 = 68)
			const top = toastTop(M, true, M.hud.objectives.y + 68);
			return hud(M) + tracker(M, OB.capturing) + rail(M, "army") + army(M, { count: 3, sent: true }) + toast(M, "success", "banner", "Soldiers sent", "They march to the nearest tower", top, toastRight(M, true));
		},
		"army-nobarracks": (M) => hud(M) + tracker(M, OB.neutral) + rail(M, "army") + army(M, { barracks: false, soldiers: 0 }),
		"upgrade-tab": (M) => hud(M) + tracker(M, OB.capturing) + rail(M) + upgradeTab(M),
		summary: (M, d) => hud(M) + tracker(M, [{ id: "watchtower", owner: "azure", progress: { azure: 1 } }]) + rail(M) + summary(d, M, "azure", STANDINGS),
		"summary-win": (M, d) => hud(M) + tracker(M, [{ id: "watchtower", owner: "crimson", progress: { crimson: 1 } }]) + rail(M) + summary(d, M, "crimson", [STANDINGS[1], STANDINGS[0], STANDINGS[2], STANDINGS[3]].map((s, i) => (i === 0 ? { kingdom: "crimson", crownPoints: 212 } : s))),
		"summary-none": (M, d) => hud(M) + tracker(M, OB.neutral) + rail(M) + summary(d, M, null, STANDINGS),
	};
	window.FL0060_SCENES = Object.keys(SCENES);

	function render() {
		const size = q.get("size") || "desktop";
		const scene = q.get("scene") || "hud";
		const d = DEVICES[size];
		const M = metrics(d);
		const guides = q.get("guides") === "1";
		const out = SCENES[scene](M, d, guides);
		// The summary lives on the modal layer (ScreenInsets.None): split it out of the core layer.
		const split = out.indexOf('<div class="scrimall">');
		const core = split >= 0 ? out.slice(0, split) : out;
		const modal = split >= 0 ? out.slice(split) : "";
		document.body.innerHTML = `<div class="viewport" style="width:${d.w}px;height:${d.h}px">
			<div class="world">${world(d.w, d.h)}</div>
			<div class="robloxbtn" style="left:${d.inset.l + 12}px;top:7px">R</div><div class="robloxbtn" style="left:${d.inset.l + 60}px;top:7px">≡</div>
			<div class="layer" style="left:${M.top.x}px;top:${M.top.y}px;width:${M.top.w}px;height:${M.top.h}px">${timer(M, scene.startsWith("summary") ? "Results" : "Founding")}</div>
			<div class="layer" style="left:${M.core.x}px;top:${M.core.y}px;width:${M.core.w}px;height:${M.core.h}px">
				<div class="scaled" style="width:${M.W}px;height:${M.H}px;transform:scale(${M.scale})">${core}</div></div>
			${modal ? `<div class="layer" style="left:0;top:0;width:${d.w}px;height:${d.h}px"><div class="scaled" style="width:${d.w / M.scale}px;height:${d.h / M.scale}px;transform:scale(${M.scale})">${modal}</div></div>` : ""}
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
