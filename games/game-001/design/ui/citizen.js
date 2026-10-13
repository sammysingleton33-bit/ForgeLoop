// AI Kingdoms (game-001) citizen card v2 and conversation prototype (FORGE-03, FL-0088).
// URL: citizen.html?size=phone|tablet|desktop&scene=<name>
// Data shapes follow CONTRACTS G13.2 (CitizenView from Sim.Inspect) and G13.3 (Kingdom.Converse / Kingdom.Choose).
// Every sentence a citizen says (question, options, reaction, effect texts) is sample server data here: in the game it
// comes from the content library through the server, never from UI code. UI labels (Talk, Done, section titles) are ours.
// The HUD layout maths is copied from kingdom.js (FL-0059, = UI/Layout.luau) so the card sits where the game puts it.
(function () {
	const I = (name, size) => window.Icons.svg(name, size);
	const T = window.TOKENS;
	const q = new URLSearchParams(location.search);

	// ------------------------------------------------------------------ devices and layout (kingdom.js / Layout.luau)
	const DEVICES = {
		phone: { w: 844, h: 390, inset: { l: 47, r: 47, t: 0, b: 21 }, topbar: 58, controls: 104 },
		tablet: { w: 1024, h: 768, inset: { l: 0, r: 0, t: 0, b: 20 }, topbar: 58, controls: 104 },
		desktop: { w: 1920, h: 1080, inset: { l: 0, r: 0, t: 0, b: 0 }, topbar: 58, controls: 104 },
	};
	const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
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
			drawer = { x: W - drawerRight - width, y: hud.y, width, height: H - hud.y - margin };
		} else {
			const width = bp === "tablet" ? 560 : 620;
			const y = hud.bottom + 10;
			drawer = { x: W - drawerRight - width, y, width, height: Math.min(bp === "tablet" ? 470 : 480, H - y - margin) };
		}
		return { bp, scale, W, H, margin, hud, rail: { right: margin, button: railButton, gap: 10 }, drawer };
	}
	function metrics(d) {
		const core = { x: d.inset.l, y: Math.max(d.inset.t, d.topbar), w: d.w - d.inset.l - d.inset.r, h: d.h - Math.max(d.inset.t, d.topbar) - d.inset.b };
		const top = { x: d.inset.l + d.controls, y: d.inset.t, w: d.w - d.inset.l - d.inset.r - d.controls, h: d.topbar };
		return Object.assign(layout(core.w, core.h), { core, top });
	}
	// The conversation: in the drawer on tablet and desktop (the world stays visible on the left); on phones the drawer is
	// too narrow for a question and its answers, so the sheet spans from the left margin to the drawer's right edge,
	// below the resource pills (they stay visible: that is where a spend or a gain shows) and left of the rail.
	function convoRect(M) {
		if (M.bp !== "phone") return M.drawer;
		const y = M.hud.bottom + 16; // below the pills' spend/gain float (CurrencyPill Delta, 16 px under the pill)
		return { x: M.margin, y, width: M.drawer.x + M.drawer.width - M.margin, height: M.H - y - M.margin };
	}

	// Fitted panel heights: the text is measured roughly (average glyph widths, greedy word wrap) so a short exchange gets a
	// short panel; the body scrolls when the estimate is short. Same numbers as CitizenModel.luau.
	const CHAR = { question: 7.0, phoneQuestion: 6.6, option: 7.1, body: 6.9, chip: 6.4 }; // calibrated on the Luau renders
	function lines(text, width, char) {
		let n = 1, used = 0;
		for (const word of String(text).split(/\s+/).filter(Boolean)) {
			const w = word.length * char;
			if (used > 0 && used + char + w > width) { n += 1; used = w; } else used += (used > 0 ? char : 0) + w;
		}
		return n;
	}
	function convoHeight(M, r, convo, st) {
		const phone = M.bp === "phone";
		const pad = phone ? 10 : 12;
		const inner = r.width - 2 * pad;
		const chrome = 2 * pad + 38 + 8;
		let h = 8;
		const speech = (text, char, lh) => lines(text, inner - (phone ? 20 : 24), phone && char === CHAR.question ? CHAR.phoneQuestion : char) * (phone ? lh - 2 : lh) + (phone ? 16 : 20);
		const chipH = phone ? 24 : 28;
		if (st.phase === "answered") {
			const picked = convo.options.find((o) => o.id === st.picked);
			h += (phone ? 0 : lines("You: " + picked.text, inner, CHAR.body) * 16 + 6) + speech(RESULT.reaction, CHAR.question, 20) + 6 + 14 + 6;
			let rows = 1, used = 0;
			for (const e of RESULT.effects) {
				const w = 38 + e.text.length * CHAR.chip;
				if (used > 0 && used + 6 + w > inner) { rows += 1; used = w; } else used += (used > 0 ? 6 : 0) + w;
			}
			h += rows * chipH + (rows - 1) * 6 + 52;
		} else if (st.phase === "refused") {
			h += speech("They've already moved on from that.", CHAR.body, 18) + 52;
		} else {
			h += speech(convo.question, CHAR.question, 20) + 6 + 14 + 6;
			const opt = (o, w) => Math.max(44, lines(o.text, w - 24 - 34, CHAR.option) * 17 + 16);
			if (phone) {
				const colW = (inner - 8) / 2;
				for (let i = 0; i < convo.options.length; i += 2) {
					h += Math.max(opt(convo.options[i], colW), convo.options[i + 1] ? opt(convo.options[i + 1], colW) : 0) + (i > 0 ? 6 : 0);
				}
			} else convo.options.forEach((o, i) => (h += opt(o, inner) + (i > 0 ? 8 : 0)));
		}
		return Math.round(Math.min(r.height, Math.max(phone ? 150 : 220, chrome + h + 6)));
	}
	// The card: the drawer on phones; a fitted 376 px panel on tablet and desktop (the drawer's 470-480 px left a hole).
	const CARD_HEIGHT = 376;

	// ------------------------------------------------------------------ sample server data (G13.2 / G13.3 shapes)
	const EDDA = {
		entityId: 41, name: "Edda Thornbury", occupation: "Farmer", job: "farmer",
		traits: ["Hard-working", "Generous", "Stubborn"], mood: 64, loyalty: 72, obedience: 48,
		intent: "Carrying wheat to the storehouse",
		lastMemory: "You visited the farms at dawn",
		memories: ["You visited the farms at dawn", "The harvest came in early", "Bran fell ill and got better", "Soldiers marched through the east field"],
		family: ["Bran Thornbury", "Lise Thornbury"], friends: ["Osric Vale", "Mara Quill"], rivals: ["Tomas Reed"], hasRequest: true,
	};
	const OSRIC = {
		entityId: 44, name: "Osric Vale", occupation: "Woodcutter", job: "woodcutter",
		traits: ["Cautious", "Loyal"], mood: 38, loyalty: 55, obedience: 70,
		intent: "Felling pines by the river", lastMemory: "The quarry was raided", memories: ["The quarry was raided"],
		family: ["Ada Vale"], friends: ["Edda Thornbury"], rivals: [], hasRequest: false,
	};
	const SPEAKER = { name: EDDA.name, occupation: EDDA.occupation };
	const CONVOS = {
		2: { question: "My lord, the storehouse roof leaks. Shall I patch it with the spare planks?",
			options: [{ id: "patch", text: "Yes, use the planks." }, { id: "wait", text: "Not now. The planks are for the barracks." }] },
		3: { question: "My lord, the east field flooded overnight. Without help we lose a week of wheat. What should we do?",
			options: [
				{ id: "help", text: "Take workers from the quarry and save the field." },
				{ id: "bread", text: "Give her family extra bread from the storehouse." },
				{ id: "work", text: "Farmers deal with floods. Get back to work." },
			] },
		4: { question: "Two families both claim the plot by the river. Who should have it?",
			options: [
				{ id: "thornbury", text: "The Thornburys. They were here first." },
				{ id: "reed", text: "The Reeds. They have more children." },
				{ id: "split", text: "Split it between them." },
				{ id: "crown", text: "Neither. It belongs to the crown." },
			] },
		long: { question: "Forgive me for speaking out of turn, my lord, but the soldiers who marched through the east field last night trampled half of the young wheat, and my husband says that if nobody pays for the seed we will not have enough to feed the children this winter, let alone the storehouse. What will you do about it?",
			options: [
				{ id: "pay", text: "The crown pays for new seed, and the captain will apologise to your family in person before the next muster." },
				{ id: "soldiers", text: "Send the soldiers to replant the field themselves." },
				{ id: "nothing", text: "The army comes first. Plant what you can." },
			] },
	};
	const RESULT = {
		reaction: "Bless you, my lord! We'll have the field drained by nightfall.",
		effects: [
			{ kind: "wood", text: "−20 Wood" },
			{ kind: "loyalty", text: "+8 Loyalty: Edda and family" },
			{ kind: "reputation", text: "+3 Compassion" },
			{ kind: "morale", text: "Farmers work faster for 60 s" },
			{ kind: "rumour", text: "The quarry crew grumbles" },
		],
	};
	const state = { treasury: { food: 132, wood: 110, stone: 50, gold: 0 }, crown: 12 };

	// ------------------------------------------------------------------ UI vocabulary (labels only; UI/CitizenModel.luau mirrors these)
	const JOB = { idle: "Idle", farmer: "Farmer", woodcutter: "Woodcutter", miner: "Miner", builder: "Builder", hauler: "Hauler", soldier: "Soldier" };
	const JOB_ICON = { idle: "house", farmer: "farm", woodcutter: "lumbercamp", miner: "quarry", builder: "build", hauler: "storehouse", soldier: "barracks" };
	const moodBand = (n) => (n < 20 ? "Miserable" : n < 40 ? "Unhappy" : n < 60 ? "Calm" : n < 80 ? "Content" : "Joyful");
	const EFFECT = {
		food: ["food", T.resource.food], wood: ["wood", T.resource.wood], stone: ["stone", T.resource.stone], gold: ["gold", T.resource.gold],
		loyalty: ["heart", T.color.gules], reputation: ["laurel", T.color.vert], morale: ["banner", T.color.amber],
		happiness: ["mood", T.color.gold400], stability: ["keep", T.color.azure], memory: ["scroll", T.color.parchment300],
	};
	const effectStyle = (kind) => EFFECT[kind] || ["info", T.color.ink500];

	// ------------------------------------------------------------------ HUD (as kingdom.js, trimmed)
	const fmt = (n) => String(n);
	const crest = (px, extra = "") => `<div class="crest tinted k-crimson" style="width:${px}px;height:${px}px">${I("emblem_crown", Math.round(px * 0.66))}${extra}</div>`;
	const medallion = (res, px) => {
		const c = T.resource[res];
		return `<div class="medallion" style="width:${px}px;height:${px}px;background:linear-gradient(180deg, ${c} 0%, color-mix(in srgb, ${c} 55%, #0B0F18) 100%)">${I(res, Math.round(px * 0.78))}</div>`;
	};
	function hud(M, deltas = {}) {
		const h = M.hud;
		const phone = M.bp === "phone";
		const pills = ["food", "wood", "stone", "gold"].map((r) => {
			const d = deltas[r];
			return `<div class="pill ${phone ? "compact" : ""} ${d ? "flash-" + (d < 0 ? "neg" : "pos") : ""}">${medallion(r, phone ? 24 : 28)}<div class="stack"><div class="amt">${fmt(state.treasury[r])}</div>
				${phone ? "" : `<div class="rate zero">${r[0].toUpperCase() + r.slice(1)}</div>`}</div>${d ? `<div class="delta ${d < 0 ? "neg" : "pos"}">${d > 0 ? "+" : "−"}${Math.abs(d)}</div>` : ""}</div>`;
		});
		let html = `<div class="badge" style="left:${h.x}px;top:${h.y}px">${crest(h.crest, phone ? `<div class="pop cp">${I("gem", 11)}${state.crown}</div>` : "")}
			${phone ? "" : `<div class="plate"><div class="kname" style="font-size:26px">Emberhold</div><div class="ksub">Keep <b>Lv 1</b> · 1 region · <b>${state.crown}</b> Crown Points</div></div>`}</div>`;
		html += `<div class="pills" style="left:${h.pills.x}px;top:${h.pills.y}px">${pills.join("")}</div>`;
		if (h.members) {
			html += `<div class="members" style="left:${h.members.x}px;top:${h.members.y}px">${["Sam", "Mira"]
				.map((n, i) => `<div class="member ${i === 0 ? "you" : ""}" style="--k:var(--tincture-crimson)"><div class="av">${n[0]}</div>${n}${i === 0 ? ` <span class="tag">you</span>` : ""}</div>`)
				.join("")}</div>`;
		}
		const b = M.rail.button;
		const top = (M.H - (2 * b + M.rail.gap)) / 2;
		html += `<div class="rail" style="right:${M.rail.right}px;top:${top}px">${[["build", "Build"], ["kingdom", "Kingdom"]]
			.map(([id, label]) => `<div class="railbtn" style="width:${b}px;height:${b}px">${I(id, phone ? 30 : 32)}${phone ? "" : `<div class="lbl">${label}</div>`}</div>`)
			.join("")}</div>`;
		return html;
	}
	function timer(M) {
		const phone = M.bp === "phone";
		const w = phone ? 120 : 190;
		return `<div class="timer" style="left:${(M.top.w - w) / 2}px;top:${(M.top.h - 40) / 2}px;width:${w}px">${I("timer", 28)}
			<div><div class="ph">Founding</div><div class="t" style="font-size:${phone ? 15 : 18}px">3:12${phone ? "" : `<span class="l" style="margin-left:6px">match time</span>`}</div></div></div>`;
	}

	// ------------------------------------------------------------------ citizen card (drawer)
	const bar = (pct, cls = "") => `<div class="bar ${cls}"><i style="width:${Math.round(pct)}%"></i></div>`;
	function who(c, size) {
		const badge = c.hasRequest ? `<div class="abadge">!</div>` : "";
		return `<div class="avatar" style="--k:var(--tincture-crimson);width:${size}px;height:${size}px;font-size:${Math.round(size * 0.45)}px">${c.name[0]}${badge}</div>
			<div class="who"><div class="cname">${c.name}</div><div class="csub">${c.occupation}${c.occupation.toLowerCase() === c.job ? "" : " · " + JOB[c.job]}</div></div>`;
	}
	function opinion(c, phone) {
		return `<div class="box">${phone ? "" : `<div class="bh">${I("heart", 16)}How ${c.name.split(" ")[0]} sees you</div>`}
			<div class="op main"><div class="lbl">Loyalty</div>${bar(c.loyalty, "love")}<div class="v">${c.loyalty}</div></div>
			<div class="op"><div class="lbl">Mood</div>${bar(c.mood)}<div class="v"><small>${moodBand(c.mood)}</small>${c.mood}</div></div>
			<div class="op"><div class="lbl">Obedience</div>${bar(c.obedience, "cool")}<div class="v">${c.obedience}</div></div></div>`;
	}
	const intent = (c) => `<div class="intent">${I(JOB_ICON[c.job], 18)}<span><b>Now</b> ${c.intent}</span></div>`;
	const traits = (c) => `<div class="chips">${c.traits.map((t) => `<span class="tchip">${t}</span>`).join("")}</div>`;
	function relations(c) {
		const row = (k, list, cls = "") => (list.length ? `<div class="rel"><span class="k ${cls}">${k}</span><span>${list.join(", ")}</span></div>` : "");
		return `<div class="box"><div class="bh">${I("citizens", 16)}People</div>${row("Family", c.family)}${row("Friends", c.friends)}${row(c.rivals.length > 1 ? "Rivals" : "Rival", c.rivals, "rival")}</div>`;
	}
	function memories(c, max) {
		const rest = c.memories.filter((m) => m !== c.lastMemory).slice(0, max);
		return `<div class="box"><div class="bh">${I("scroll", 16)}Remembers</div>${c.lastMemory ? `<div class="mem last">${c.lastMemory}</div>` : ""}${rest.map((m) => `<div class="mem">${m}</div>`).join("")}</div>`;
	}
	function talkButton(c, st) {
		if (st === "loading") return `<div class="btn primary"><div class="spin"></div>Listening…</div>`;
		return c.hasRequest ? `<div class="btn primary">${I("talk", 22)}Talk</div>` : `<div class="btn secondary">${I("talk", 22)}Ask</div>`;
	}
	function card(M, c, o = {}) {
		const d = M.drawer;
		const phone = M.bp === "phone";
		const body = phone
			? `<div class="cscroll">${opinion(c, true)}${intent(c)}${traits(c)}${relations(c)}${memories(c, 1)}</div>`
			: `<div class="ccols"><div class="ccol">${opinion(c)}${intent(c)}${traits(c)}</div><div class="ccol">${relations(c)}${memories(c, 3)}</div></div>`;
		const height = phone ? d.height : Math.min(d.height, CARD_HEIGHT);
		return `<div class="panel drawer ${phone ? "single" : ""}" style="left:${d.x}px;top:${d.y}px;width:${d.width}px;height:${height}px">
			<div class="dhead">${who(c, phone ? 32 : 36)}<div class="closebtn">${I("close", 20)}</div></div>
			${phone ? "" : `<div class="ornament"></div>`}
			<div class="cbody" style="margin-top:${phone ? 6 : 0}px">${body}<div class="ctalk">${talkButton(c, o.talk)}</div></div></div>`;
	}

	// ------------------------------------------------------------------ conversation
	function option(o, i, st) {
		const cls = st.picked ? (st.picked === o.id ? "picked" : "off") : "";
		return `<div class="opt ${cls}"><div class="n">${i + 1}</div><span>${o.text}</span>${st.picked === o.id && st.phase === "choosing" ? `<span class="wait">${I("timer", 18)}</span>` : ""}</div>`;
	}
	function chip(e) {
		const [icon, color] = effectStyle(e.kind);
		const sign = /^[+]/.test(e.text) ? "up" : /^[−-]/.test(e.text) ? "down" : "";
		return `<span class="echip" style="--k:${color}">${I(icon, 20)}<span class="${sign}">${e.text}</span></span>`;
	}
	function conversation(M, convo, st) {
		const r = convoRect(M);
		const phone = M.bp === "phone";
		let body;
		if (st.phase === "answered") {
			const picked = convo.options.find((o) => o.id === st.picked);
			// Phones drop the echo of your answer: the reaction and what changed must fit above Done without scrolling.
			body = `<div class="cscroll">${phone ? "" : `<div class="echo">You: <b>${picked.text}</b></div>`}
				<div class="speech">${RESULT.reaction}</div>
				<div class="kicker">WHAT CHANGED</div><div class="effects">${RESULT.effects.map(chip).join("")}</div></div>
				<div class="cfoot"><div class="btn primary">${I("check", 22)}Done</div></div>`;
		} else if (st.phase === "refused") {
			body = `<div class="cscroll"><div class="speech refused">${I("warning", 18)} They've already moved on from that.</div></div>
				<div class="cfoot"><div class="btn secondary">Close</div></div>`;
		} else {
			body = `<div class="cscroll"><div class="speech">${convo.question}</div>
				<div class="kicker">YOUR ANSWER</div>
				<div class="opts ${phone ? "grid" : ""}">${convo.options.map((o, i) => option(o, i, st)).join("")}</div></div>`;
		}
		return `<div class="panel drawer convo ${phone ? "single" : ""}" style="left:${r.x}px;top:${r.y}px;width:${r.width}px;height:${convoHeight(M, r, convo, st)}px">
			<div class="dhead">${who(Object.assign({ job: "farmer" }, SPEAKER), phone ? 30 : 36)}<div class="closebtn">${I("close", 20)}</div></div>
			<div class="cbody" style="margin-top:${phone ? 4 : 6}px">${body}</div></div>`;
	}

	// ------------------------------------------------------------------ backdrop (kingdom.js world, trimmed)
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
		// A few citizens; the selected one has a gold ring and a thought bubble (FORGE-04's bubble, illustration only).
		const people = [[0.36, 0.7, true], [0.42, 0.78], [0.24, 0.82], [0.47, 0.66]]
			.map(([x, y, sel]) => `<g transform="translate(${x * w} ${y * h})">${sel ? `<ellipse cx="0" cy="2" rx="13" ry="5" fill="none" stroke="#F6DE9C" stroke-width="3"/>` : ""}
				<rect x="-4" y="-18" width="8" height="14" rx="3" fill="#B8402E"/><circle cx="0" cy="-22" r="4.5" fill="#E8C9A0"/>
				${sel ? `<g transform="translate(6 -48)"><rect x="0" y="0" width="22" height="20" rx="6" fill="#F7EFDC" stroke="#24190E" stroke-width="1.5"/><text x="11" y="15" text-anchor="middle" font-family="Montserrat" font-weight="800" font-size="14" fill="#8F6A26">!</text></g>` : ""}</g>`)
			.join("");
		return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
			<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FB0D9"/><stop offset="1" stop-color="#D7E3D0"/></linearGradient></defs>
			<rect width="${w}" height="${h}" fill="url(#sky)"/>
			<path d="M0 ${h * 0.34} Q ${w * 0.2} ${h * 0.22} ${w * 0.4} ${h * 0.32} T ${w * 0.8} ${h * 0.28} T ${w} ${h * 0.3} V ${h} H 0 Z" fill="#8FAE7A"/>
			<path d="M0 ${h * 0.42} Q ${w * 0.25} ${h * 0.36} ${w * 0.5} ${h * 0.44} T ${w} ${h * 0.4} V ${h} H 0 Z" fill="#6E9A4E"/>
			${fields.join("")}${trees.join("")}${houses.join("")}${people}
		</svg>`;
	}

	// ------------------------------------------------------------------ scenes
	const SCENES = {
		card: (M) => hud(M) + card(M, EDDA),
		"card-quiet": (M) => hud(M) + card(M, OSRIC),
		"card-asking": (M) => hud(M) + card(M, EDDA, { talk: "loading" }),
		"talk-2": (M) => hud(M) + conversation(M, CONVOS[2], { phase: "asking" }),
		"talk-3": (M) => hud(M) + conversation(M, CONVOS[3], { phase: "asking" }),
		"talk-4": (M) => hud(M) + conversation(M, CONVOS[4], { phase: "asking" }),
		"talk-long": (M) => hud(M) + conversation(M, CONVOS.long, { phase: "asking" }),
		choosing: (M) => hud(M) + conversation(M, CONVOS[3], { phase: "choosing", picked: "help" }),
		answered: (M) => {
			state.treasury.wood = 90;
			return hud(M, { wood: -20 }) + conversation(M, CONVOS[3], { phase: "answered", picked: "help" });
		},
		refused: (M) => hud(M) + conversation(M, CONVOS[3], { phase: "refused" }),
	};
	window.FL0088_SCENES = Object.keys(SCENES);

	function render() {
		const size = q.get("size") || "desktop";
		const scene = q.get("scene") || "card";
		const d = DEVICES[size];
		const M = metrics(d);
		const core = SCENES[scene](M);
		document.body.innerHTML = `<div class="viewport" style="width:${d.w}px;height:${d.h}px">
			<div class="world">${world(d.w, d.h)}</div>
			<div class="robloxbtn" style="left:${d.inset.l + 12}px;top:7px">R</div><div class="robloxbtn" style="left:${d.inset.l + 60}px;top:7px">≡</div>
			<div class="layer" style="left:${M.top.x}px;top:${M.top.y}px;width:${M.top.w}px;height:${M.top.h}px">${timer(M)}</div>
			<div class="layer" style="left:${M.core.x}px;top:${M.core.y}px;width:${M.core.w}px;height:${M.core.h}px">
				<div class="scaled" style="width:${M.W}px;height:${M.H}px;transform:scale(${M.scale})">${core}</div></div></div>`;
		document.title = `${scene} @ ${size} (${M.bp}, scale ${M.scale.toFixed(2)})`;
	}
	render();
	window.__ready = document.fonts.ready.then(() => true);
})();
