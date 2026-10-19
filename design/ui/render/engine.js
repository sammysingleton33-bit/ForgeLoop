/*
	engine.js — Roblox GUI layout + paint emulation for the headless Luau snapshot renderer (FORGE-03).
	Runs INSIDE the page that render.js builds. Input: window.SNAPSHOT (snapshot.luau JSON) and
	window.RENDER_OPTIONS { guides, debug, backdrop, assets: { key: fileUrl } }.
	Output: DOM in #vp, window.__layout (absolute rect per GuiObject, device px), window.__warnings,
	window.__done = true when painted.

	It lays out like the engine does (our own pass, not CSS flow): every GuiObject gets a rect
	(position, size, UIScale) from Roblox rules, then is painted as an absolutely positioned div.
	The browser is only used to measure and draw text. Deviations: README.md "Known deviations".
*/
(function () {
	"use strict";
	const SNAP = window.SNAPSHOT;
	const OPT = window.RENDER_OPTIONS || {};
	const DEV = SNAP.device;
	const ASSETS = OPT.assets || {};
	const warnings = [];
	const warned = new Set();
	function warn(message) {
		if (!warned.has(message)) {
			warned.add(message);
			warnings.push(message);
		}
	}

	// ------------------------------------------------------------------ value helpers
	const arr = (v) => (Array.isArray(v) ? v : []);
	const obj = (v) => (v && typeof v === "object" && !Array.isArray(v) ? v : {});
	const num = (v, d = 0) => (v === "inf" ? Infinity : v === "-inf" ? -Infinity : typeof v === "number" && isFinite(v) ? v : d);
	const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
	const U2 = (v) => {
		v = obj(v);
		return { xs: num(v.xs), xo: num(v.xo), ys: num(v.ys), yo: num(v.yo) };
	};
	const U1 = (v) => {
		v = obj(v);
		return { s: num(v.s), o: num(v.o) };
	};
	const V2 = (v, dx = 0, dy = 0) => {
		v = obj(v);
		return { x: num(v.x, dx), y: num(v.y, dy) };
	};
	const vec = V2;
	function rgb(hex) {
		const h = String(hex || "#000000").replace("#", "");
		return [parseInt(h.slice(0, 2), 16) || 0, parseInt(h.slice(2, 4), 16) || 0, parseInt(h.slice(4, 6), 16) || 0];
	}
	const alpha = (transparency) => +clamp(1 - num(transparency, 0), 0, 1).toFixed(4);
	const rgbaOf = (c, a) => `rgba(${Math.round(c[0])},${Math.round(c[1])},${Math.round(c[2])},${+clamp(a, 0, 1).toFixed(4)})`;
	const rgba = (hex, transparency) => rgbaOf(rgb(hex), alpha(transparency));
	const px = (v) => `${+v.toFixed(3)}px`;
	const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

	// ------------------------------------------------------------------ fonts
	// FontFace.Family -> CSS family. Only the three FORGELOOP families are the real fonts.
	const FAMILIES = {
		GrenzeGotisch: ["Grenze Gotisch"],
		Merriweather: ["Merriweather"],
		Montserrat: ["Montserrat"],
		BuilderSans: ["Montserrat", "BuilderSans is not installed here: drawn with Montserrat (similar geometric sans, different metrics)"],
		GothamSSm: ["Montserrat", "Gotham is not installed here: drawn with Montserrat"],
		Gotham: ["Montserrat", "Gotham is not installed here: drawn with Montserrat"],
		LegacyArial: ["Liberation Sans", "FontFace is LegacyArial (the default: never set?): drawn with Liberation Sans"],
		Arial: ["Liberation Sans", "Arial drawn with Liberation Sans (metric-compatible)"],
		SourceSansPro: ["Liberation Sans", "SourceSansPro is not installed here: drawn with Liberation Sans"],
		Roboto: ["Liberation Sans", "Roboto is not installed here: drawn with Liberation Sans"],
		RobotoMono: ["DejaVu Sans Mono", "RobotoMono drawn with DejaVu Sans Mono"],
		Inconsolata: ["DejaVu Sans Mono", "Inconsolata drawn with DejaVu Sans Mono"],
	};
	const WEIGHTS = { Thin: 100, ExtraLight: 200, Light: 300, Regular: 400, Medium: 500, SemiBold: 600, Bold: 700, ExtraBold: 800, Heavy: 900 };
	const usedFonts = new Map();
	function fontOf(face) {
		face = obj(face);
		const family = String(face.family || "");
		const m = family.match(/families\/([A-Za-z0-9_]+)\.json$/);
		let css = "Liberation Sans";
		if (m && FAMILIES[m[1]]) {
			css = FAMILIES[m[1]][0];
			if (FAMILIES[m[1]][1]) warn(FAMILIES[m[1]][1]);
		} else {
			warn(`font family '${family}' is not mapped: drawn with Liberation Sans`);
		}
		const weight = WEIGHTS[face.weight] || 400;
		const style = face.style === "Italic" ? "italic" : "normal";
		usedFonts.set(`${style} ${weight} 16px "${css}"`, true);
		return { css, weight, style, stack: `"${css}", "Noto Color Emoji", sans-serif` };
	}

	// ------------------------------------------------------------------ rich text (subset)
	const ENTITIES = { "&lt;": "<", "&gt;": ">", "&quot;": '"', "&apos;": "'", "&amp;": "&" };
	const decode = (s) => s.replace(/&(lt|gt|quot|apos|amp);/g, (e) => ENTITIES[e]);
	function attrs(s) {
		const out = {};
		s.replace(/([a-zA-Z]+)\s*=\s*("([^"]*)"|'([^']*)')/g, (_, k, __, a, b) => {
			out[k.toLowerCase()] = a !== undefined ? a : b;
		});
		return out;
	}
	function cssColor(v) {
		if (!v) return null;
		v = v.trim();
		if (/^#[0-9a-fA-F]{6}$/.test(v)) return v;
		const m = v.match(/^rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/);
		return m ? `rgb(${m[1]},${m[2]},${m[3]})` : null;
	}
	function richToHtml(text) {
		let html = "";
		let plain = "";
		const re = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z]+)([^>]*?)(\/?)>|([^<]+)|(<)/g;
		let m;
		while ((m = re.exec(text))) {
			if (m[5] !== undefined || m[6] !== undefined) {
				const t = decode(m[5] !== undefined ? m[5] : m[6]);
				plain += t;
				html += esc(t);
				continue;
			}
			if (!m[2]) continue; // comment
			const close = m[1] === "/";
			const tag = m[2].toLowerCase();
			const a = attrs(m[3] || "");
			if (tag === "br") {
				html += "<br>";
				plain += "\n";
				continue;
			}
			if (close) {
				if (["b", "i", "u", "s", "font", "stroke", "uc", "uppercase", "sc", "smallcaps", "mark"].includes(tag)) html += "</span>";
				continue;
			}
			let style = "";
			if (tag === "b") style = "font-weight:700";
			else if (tag === "i") style = "font-style:italic";
			else if (tag === "u") style = "text-decoration:underline";
			else if (tag === "s") style = "text-decoration:line-through";
			else if (tag === "uc" || tag === "uppercase") style = "text-transform:uppercase";
			else if (tag === "sc" || tag === "smallcaps") style = "font-variant:small-caps";
			else if (tag === "mark") {
				const c = cssColor(a.color);
				style = c ? `background:${c}` : "";
			} else if (tag === "stroke") {
				warn("rich text <stroke> is drawn without its outline");
			} else if (tag === "font") {
				const c = cssColor(a.color);
				if (c) style += `color:${c};-webkit-text-fill-color:${c};`;
				if (a.size && isFinite(+a.size)) style += `font-size:${+a.size}px;`;
				if (a.weight) style += `font-weight:${WEIGHTS[a.weight] || (a.weight === "bold" ? 700 : isFinite(+a.weight) ? +a.weight : 400)};`;
				if (a.transparency && isFinite(+a.transparency)) style += `opacity:${alpha(+a.transparency)};`;
				if (a.face || a.family) warn("rich text <font face/family> is drawn in the label's font");
			} else {
				warn(`rich text tag <${tag}> is not emulated (tag dropped, text kept)`);
				continue;
			}
			html += `<span style="${style}">`;
		}
		return { html, plain };
	}

	// ------------------------------------------------------------------ text measurement
	const measurer = document.createElement("div");
	const range = document.createRange();
	const measureCache = new Map();
	function measure(t, size, wrapWidth) {
		const key = `${t.html}\u0001${t.font.stack}|${t.font.weight}|${t.font.style}|${size}|${t.lineFactor}|${wrapWidth}`;
		const hit = measureCache.get(key);
		if (hit) return hit;
		const wrap = wrapWidth != null;
		measurer.style.cssText =
			`position:absolute;left:0;top:0;visibility:hidden;display:block;font-family:${t.font.stack};font-weight:${t.font.weight};` +
			`font-style:${t.font.style};font-size:${size}px;line-height:${size * t.lineFactor}px;white-space:${wrap ? "pre-wrap" : "pre"};` +
			`overflow-wrap:${wrap ? "break-word" : "normal"};width:${wrap ? Math.max(0, wrapWidth) + "px" : "max-content"}`;
		measurer.innerHTML = t.html.length ? t.html : "&#8203;";
		const box = measurer.getBoundingClientRect();
		range.selectNodeContents(measurer);
		let right = 0;
		for (const r of range.getClientRects()) right = Math.max(right, r.right - box.left);
		const out = { w: t.html.length ? Math.ceil(right) : 0, h: Math.ceil(box.height - 0.01), scrollW: measurer.scrollWidth };
		measureCache.set(key, out);
		return out;
	}

	// ------------------------------------------------------------------ tree preparation
	const TEXT = new Set(["TextLabel", "TextButton", "TextBox"]);
	const IMAGE = new Set(["ImageLabel", "ImageButton"]);
	const KNOWN_GUI = new Set(["Frame", "ScrollingFrame", "CanvasGroup", "ViewportFrame", ...TEXT, ...IMAGE]);
	let counter = 0;

	function prep(raw, parent, viaFolder) {
		const n = {
			cls: raw.class,
			name: raw.name,
			kind: raw.kind,
			p: obj(raw.props),
			parent,
			path: parent ? `${parent.path}.${raw.name}` : raw.name,
			id: counter++,
			kids: [],
			strokes: [],
			scale: 1,
			viaFolder: !!viaFolder,
			memo: new Map(),
			viewport: raw.viewport || null,
		};
		for (const c of arr(raw.children)) addChild(n, c, false);
		if (TEXT.has(n.cls)) n.text = textInfo(n);
		return n;
	}
	function addChild(n, c, viaFolder) {
		if (c.kind === "gui") n.kids.push(prep(c, n, viaFolder));
		else if (c.kind === "folder") {
			if (arr(c.children).some((k) => k.kind === "gui" || k.kind === "folder"))
				warn(`Folder '${n.path}.${c.name}': its GuiObjects are drawn as children of '${n.name}' and left out of any layout`);
			for (const k of arr(c.children)) addChild(n, k, true);
		} else if (c.kind === "modifier") addModifier(n, c);
		else if (c.kind === "layer") warn(`nested ${c.class} '${c.name}' under '${n.path}' is not drawn`);
	}
	function addModifier(n, c) {
		const p = obj(c.props);
		const where = `${n.path}.${c.name}`;
		const once = (key) => {
			if (n[key]) {
				warn(`${where}: a second ${c.class} on the same object is ignored`);
				return false;
			}
			return true;
		};
		switch (c.class) {
			case "UICorner":
				if (once("corner")) n.corner = p;
				break;
			case "UIStroke":
				if (p.Enabled !== false) {
					const g = arr(c.children).find((k) => k.class === "UIGradient" && obj(k.props).Enabled !== false);
					n.strokes.push({ p, gradient: g ? obj(g.props) : null, where });
				}
				break;
			case "UIGradient":
				if (p.Enabled !== false && once("gradient")) n.gradient = p;
				break;
			case "UIPadding":
				if (once("padding")) n.padding = p;
				break;
			case "UIListLayout":
				if (n.grid || n.list) warn(`${where}: more than one layout under '${n.path}'; the first one is used`);
				else n.list = p;
				break;
			case "UIGridLayout":
				if (n.grid || n.list) warn(`${where}: more than one layout under '${n.path}'; the first one is used`);
				else n.grid = p;
				if (arr(c.children).length) warn(`${where}: constraints under a UIGridLayout are not emulated`);
				break;
			case "UIScale":
				if (n.scale !== 1) warn(`${where}: several UIScale under one object are multiplied`);
				n.scale *= num(p.Scale, 1);
				break;
			case "UISizeConstraint":
				if (once("sizeC")) n.sizeC = p;
				break;
			case "UIAspectRatioConstraint":
				if (once("aspect")) n.aspect = p;
				break;
			case "UITextSizeConstraint":
				if (once("textC")) n.textC = p;
				break;
			case "UIFlexItem":
				if (once("flex")) n.flex = p;
				break;
			default:
				warn(`${c.class} '${where}' is not emulated (ignored)`);
		}
	}
	function textInfo(n) {
		const p = n.p;
		let source = String(p.Text ?? "");
		let colorHex = p.TextColor3;
		if (n.cls === "TextBox" && source === "" && p.PlaceholderText) {
			source = String(p.PlaceholderText);
			colorHex = p.PlaceholderColor3 || "#b2b2b2";
		}
		let rt;
		if (p.RichText === true) rt = richToHtml(source);
		else {
			let s = source;
			const max = num(p.MaxVisibleGraphemes, -1);
			if (max >= 0 && typeof Intl !== "undefined" && Intl.Segmenter) {
				s = Array.from(new Intl.Segmenter().segment(s), (x) => x.segment).slice(0, max).join("");
			}
			rt = { html: esc(s), plain: s };
		}
		if (p.RichText === true && num(p.MaxVisibleGraphemes, -1) >= 0) warn(`${n.path}: MaxVisibleGraphemes with RichText is not emulated`);
		return {
			html: rt.html,
			plain: rt.plain,
			font: fontOf(p.FontFace),
			size: num(p.TextSize, 14),
			lineFactor: clamp(num(p.LineHeight, 1), 1, 3),
			color: colorHex || "#000000",
			transparency: num(p.TextTransparency, 0),
			xa: p.TextXAlignment || "Center",
			ya: p.TextYAlignment || "Center",
			wrapped: p.TextWrapped === true || p.TextScaled === true,
			scaled: p.TextScaled === true,
			truncate: p.TextTruncate && p.TextTruncate !== "None",
		};
	}

	// ------------------------------------------------------------------ layout
	function padOf(n, w, h) {
		if (!n.padding) return { l: 0, r: 0, t: 0, b: 0 };
		const p = n.padding;
		const f = (u, ref) => U1(u).s * ref + U1(u).o;
		return { l: f(p.PaddingLeft, w), r: f(p.PaddingRight, w), t: f(p.PaddingTop, h), b: f(p.PaddingBottom, h) };
	}

	function textBounds(n, wrapWidth) {
		const t = n.text;
		return measure(t, t.size, wrapWidth);
	}

	// Own (unscaled) size of n inside a parent content box pw x ph.
	function sizeOf(n, pw, ph) {
		const key = `${pw}|${ph}`;
		const hit = n.memo.get(key);
		if (hit) return hit;
		const S = U2(n.p.Size);
		const sc = n.p.SizeConstraint;
		const refX = sc === "RelativeYY" ? ph : pw;
		const refY = sc === "RelativeXX" ? pw : ph;
		let w = S.xs * refX + S.xo;
		let h = S.ys * refY + S.yo;
		const auto = n.p.AutomaticSize || "None";
		const ax = auto === "X" || auto === "XY";
		const ay = auto === "Y" || auto === "XY";
		if (ax || ay) {
			const maxW = n.sizeC ? vec(n.sizeC.MaxSize, Infinity, Infinity).x : Infinity;
			const c = contentSize(n, Math.max(0, w), Math.max(0, h), ax, maxW);
			if (ax) w = Math.max(w, c.w);
			if (ay) h = Math.max(h, c.h);
		}
		if (n.sizeC) {
			const mn = vec(n.sizeC.MinSize, 0, 0);
			const mx = vec(n.sizeC.MaxSize, Infinity, Infinity);
			w = clamp(w, mn.x, Math.max(mn.x, mx.x));
			h = clamp(h, mn.y, Math.max(mn.y, mx.y));
		}
		if (n.aspect) {
			const r = num(n.aspect.AspectRatio, 1) || 1;
			if ((n.aspect.AspectType || "FitWithinMaxSize") === "FitWithinMaxSize") {
				if (w / Math.max(h, 1e-9) > r) w = h * r;
				else h = w / r;
			} else if ((n.aspect.DominantAxis || "Width") === "Width") h = w / r;
			else w = h * r;
		}
		const out = { w: Math.max(0, w), h: Math.max(0, h) };
		n.memo.set(key, out);
		return out;
	}

	// Content extent (incl. padding) of n at provisional size w x h, for AutomaticSize.
	function contentSize(n, w, h, autoX, maxW) {
		const pad = padOf(n, w, h);
		let cw = 0;
		let ch = 0;
		if (n.text) {
			const t = n.text;
			let wrapWidth = null;
			if (t.wrapped) wrapWidth = autoX ? (isFinite(maxW) ? maxW - pad.l - pad.r : null) : w - pad.l - pad.r;
			if (wrapWidth != null && autoX) {
				const natural = textBounds(n, null);
				if (natural.w <= wrapWidth) wrapWidth = null;
			}
			const tb = textBounds(n, wrapWidth);
			cw = tb.w + pad.l + pad.r;
			ch = tb.h + pad.t + pad.b;
		}
		const placed = placeChildren(n, w, h);
		if (placed.content) {
			cw = Math.max(cw, placed.content.w + pad.l + pad.r);
			ch = Math.max(ch, placed.content.h + pad.t + pad.b);
		}
		for (const r of placed.rects) {
			if (placed.content && !r.n.viaFolder) continue;
			cw = Math.max(cw, r.x + r.vw + pad.r);
			ch = Math.max(ch, r.y + r.vh + pad.b);
		}
		return { w: cw, h: ch };
	}

	const visibleKids = (n) => n.kids.filter((k) => k.p.Visible !== false);
	function sorted(items, sortOrder) {
		const idx = new Map(items.map((k, i) => [k, i]));
		if (sortOrder === "Name") {
			return items.slice().sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : idx.get(a) - idx.get(b)));
		}
		if (sortOrder === "LayoutOrder") {
			return items.slice().sort((a, b) => num(a.p.LayoutOrder) - num(b.p.LayoutOrder) || idx.get(a) - idx.get(b));
		}
		return items;
	}
	function rectFor(k, x, y, size) {
		const s = k.scale;
		return { n: k, x, y, w: size.w, h: size.h, s, vw: size.w * s, vh: size.h * s };
	}

	// Rects of n's visible GuiObject children for n at size w x h, relative to n's top-left
	// (for a ScrollingFrame: relative to the canvas). Also n.canvas for ScrollingFrames.
	function placeChildren(n, w, h) {
		const kids = visibleKids(n);
		let boxW = w;
		let boxH = h;
		let canvas = null;
		if (n.cls === "ScrollingFrame") {
			canvas = canvasOf(n, w, h, kids);
			boxW = canvas.w;
			boxH = canvas.h;
		}
		return placeIn(n, kids, boxW, boxH, canvas);
	}
	function placeIn(n, kids, boxW, boxH, canvas) {
		const pad = padOf(n, boxW, boxH);
		const cx = pad.l;
		const cy = pad.t;
		const cw = Math.max(0, boxW - pad.l - pad.r);
		const ch = Math.max(0, boxH - pad.t - pad.b);
		const rects = [];
		let content = null;
		const flowing = kids.filter((k) => !k.viaFolder);
		if (n.list) content = placeList(n, flowing, cx, cy, cw, ch, rects);
		else if (n.grid) content = placeGrid(n, flowing, cx, cy, cw, ch, rects);
		for (const k of kids) {
			if ((n.list || n.grid) && !k.viaFolder) continue;
			const size = sizeOf(k, cw, ch);
			const P = U2(k.p.Position);
			const A = V2(k.p.AnchorPoint);
			const s = k.scale;
			const x = cx + P.xs * cw + P.xo - A.x * size.w * s;
			const y = cy + P.ys * ch + P.yo - A.y * size.h * s;
			rects.push(rectFor(k, x, y, size));
		}
		return { rects, content, canvas };
	}

	function canvasOf(n, w, h, kids) {
		const p = n.p;
		const C = U2(p.CanvasSize ?? { xs: 0, xo: 0, ys: 2, yo: 0 });
		// The canvas is never smaller than the window (so CanvasSize 0 + AutomaticCanvasSize Y with
		// full-width rows works as in Studio; unverified detail, see README).
		let cw = Math.max(C.xs * w + C.xo, w);
		let ch = Math.max(C.ys * h + C.yo, h);
		const auto = p.AutomaticCanvasSize || "None";
		if (auto !== "None") {
			const placed = placeIn(n, kids, Math.max(cw, 0), Math.max(ch, 0), null);
			const pad = padOf(n, cw, ch);
			let ew = 0;
			let eh = 0;
			if (placed.content) {
				ew = placed.content.w + pad.l + pad.r;
				eh = placed.content.h + pad.t + pad.b;
			}
			for (const r of placed.rects) {
				if (placed.content && !r.n.viaFolder) continue;
				ew = Math.max(ew, r.x + r.vw + pad.r);
				eh = Math.max(eh, r.y + r.vh + pad.b);
			}
			if (auto === "X" || auto === "XY") cw = Math.max(cw, ew);
			if (auto === "Y" || auto === "XY") ch = Math.max(ch, eh);
		}
		cw = Math.max(cw, 0);
		ch = Math.max(ch, 0);
		const dir = p.ScrollingDirection || "XY";
		const th = num(p.ScrollBarThickness, 12);
		const vBar = (dir === "XY" || dir === "Y") && ch > h + 0.5 && th > 0;
		const hBar = (dir === "XY" || dir === "X") && cw > w + 0.5 && th > 0;
		const cp = V2(p.CanvasPosition);
		const x = clamp(cp.x, 0, Math.max(0, cw - w));
		const y = clamp(cp.y, 0, Math.max(0, ch - h));
		if (Math.abs(x - cp.x) > 0.5 || Math.abs(y - cp.y) > 0.5) warn(`${n.path}: CanvasPosition clamped to the canvas like the engine does`);
		return { w: cw, h: ch, x, y, vBar, hBar, th };
	}

	function placeList(n, items, cx, cy, cw, ch, rects) {
		const L = n.list;
		if ((L.SortOrder || "Name") === "Name") warn(`${n.path}: UIListLayout.SortOrder is Name (Lune's default when unset; Studio inserts LayoutOrder) — sorted by Name`);
		items = sorted(items, L.SortOrder || "Name");
		const horizontal = (L.FillDirection || "Vertical") === "Horizontal";
		const mainSize = horizontal ? cw : ch;
		const crossSize = horizontal ? ch : cw;
		const G = U1(L.Padding);
		const gap = G.s * mainSize + G.o;
		const wraps = L.Wraps === true;
		const flexMode = (horizontal ? L.HorizontalFlex : L.VerticalFlex) || "None";
		const mainAlign = horizontal ? L.HorizontalAlignment || "Left" : L.VerticalAlignment || "Top";
		const crossAlign = horizontal ? L.VerticalAlignment || "Top" : L.HorizontalAlignment || "Left";
		const pos = (a) => (a === "Center" ? 0.5 : a === "Right" || a === "Bottom" ? 1 : 0);
		const entries = items.map((k) => {
			const size = sizeOf(k, cw, ch);
			const s = k.scale;
			const vw = size.w * s;
			const vh = size.h * s;
			const fm = (k.flex && k.flex.FlexMode) || "None";
			let grow = 0;
			let shrink = 0;
			if (flexMode === "Fill") grow = shrink = 1;
			if (fm === "Grow" || fm === "Fill") grow = 1;
			if (fm === "Shrink" || fm === "Fill") shrink = 1;
			if (fm === "Custom") {
				grow = num(k.flex.GrowRatio);
				shrink = num(k.flex.ShrinkRatio);
			}
			const ila = (k.flex && k.flex.ItemLineAlignment && k.flex.ItemLineAlignment !== "Automatic" ? k.flex.ItemLineAlignment : L.ItemLineAlignment) || "Automatic";
			return { k, s, size, main: horizontal ? vw : vh, cross: horizontal ? vh : vw, grow, shrink, ila };
		});
		// lines
		const lines = [];
		let line = [];
		let acc = 0;
		for (const e of entries) {
			const add = (line.length ? gap : 0) + e.main;
			if (wraps && line.length && acc + add > mainSize + 0.01) {
				lines.push(line);
				line = [];
				acc = 0;
			}
			acc += (line.length ? gap : 0) + e.main;
			line.push(e);
		}
		if (line.length) lines.push(line);
		const lineCross = lines.map((l) => (wraps ? Math.max(0, ...l.map((e) => e.cross)) : crossSize));
		const naturalMain = Math.max(0, ...lines.map((l) => l.reduce((a, e) => a + e.main, 0) + gap * (l.length - 1)));
		const naturalCross = wraps
			? lineCross.reduce((a, c) => a + c, 0) + gap * Math.max(0, lines.length - 1)
			: Math.max(0, ...entries.map((e) => e.cross));
		// cross placement of the block of lines (wrapping only; a single line spans the cross size)
		let crossCursor = wraps ? (crossSize - naturalCross) * pos(crossAlign) : 0;
		lines.forEach((l, li) => {
			let total = l.reduce((a, e) => a + e.main, 0) + gap * (l.length - 1);
			let free = mainSize - total;
			const sumGrow = l.reduce((a, e) => a + e.grow, 0);
			const sumShrink = l.reduce((a, e) => a + e.shrink * e.main, 0);
			if (free > 0 && sumGrow > 0) {
				for (const e of l) e.main += (free * e.grow) / sumGrow;
				free = 0;
			} else if (free < 0 && sumShrink > 0) {
				for (const e of l) e.main = Math.max(0, e.main + (free * e.shrink * e.main) / sumShrink);
				free = 0;
			}
			let start = 0;
			let between = gap;
			if (free > 0 && flexMode === "SpaceBetween" && l.length > 1) between = gap + free / (l.length - 1);
			else if (free > 0 && flexMode === "SpaceAround") {
				between = gap + free / l.length;
				start = free / l.length / 2;
			} else if (free > 0 && flexMode === "SpaceEvenly") {
				between = gap + free / (l.length + 1);
				start = free / (l.length + 1);
			} else start = free * pos(mainAlign);
			let cursor = start;
			const lc = lineCross[li];
			for (const e of l) {
				let cross = e.cross;
				let a = pos(crossAlign);
				if (e.ila === "Start") a = 0;
				else if (e.ila === "Center") a = 0.5;
				else if (e.ila === "End") a = 1;
				else if (e.ila === "Stretch") {
					cross = lc;
					a = 0;
				}
				const crossPos = crossCursor + (lc - cross) * a;
				const vw = horizontal ? e.main : cross;
				const vh = horizontal ? cross : e.main;
				const size = { w: vw / e.s, h: vh / e.s };
				rects.push(rectFor(e.k, horizontal ? cx + cursor : cx + crossPos, horizontal ? cy + crossPos : cy + cursor, size));
				cursor += e.main + between;
			}
			crossCursor += lc + gap;
		});
		return horizontal ? { w: naturalMain, h: naturalCross } : { w: naturalCross, h: naturalMain };
	}

	function placeGrid(n, items, cx, cy, cw, ch, rects) {
		const G = n.grid;
		items = sorted(items, G.SortOrder || "Name");
		if ((G.SortOrder || "Name") === "Name") warn(`${n.path}: UIGridLayout.SortOrder is Name (Lune's default when unset) — sorted by Name`);
		const C = U2(G.CellSize ?? { xs: 0, xo: 100, ys: 0, yo: 100 });
		const P = U2(G.CellPadding ?? { xs: 0, xo: 5, ys: 0, yo: 5 });
		const cellW = C.xs * cw + C.xo;
		const cellH = C.ys * ch + C.yo;
		const padX = P.xs * cw + P.xo;
		const padY = P.ys * ch + P.yo;
		const horizontal = (G.FillDirection || "Horizontal") === "Horizontal";
		const maxCells = Math.floor(num(G.FillDirectionMaxCells, 0));
		let per = horizontal ? Math.floor((cw + padX) / Math.max(1e-6, cellW + padX)) : Math.floor((ch + padY) / Math.max(1e-6, cellH + padY));
		per = Math.max(1, per);
		if (maxCells > 0) per = Math.min(per, maxCells);
		const count = items.length;
		const majors = Math.ceil(count / per);
		const cols = horizontal ? Math.min(count, per) : majors;
		const rows = horizontal ? majors : Math.min(count, per);
		const gridW = cols > 0 ? cols * cellW + (cols - 1) * padX : 0;
		const gridH = rows > 0 ? rows * cellH + (rows - 1) * padY : 0;
		const ha = G.HorizontalAlignment || "Left";
		const va = G.VerticalAlignment || "Top";
		const x0 = cx + (cw - gridW) * (ha === "Center" ? 0.5 : ha === "Right" ? 1 : 0);
		const y0 = cy + (ch - gridH) * (va === "Center" ? 0.5 : va === "Bottom" ? 1 : 0);
		const corner = G.StartCorner || "TopLeft";
		items.forEach((k, i) => {
			let col = horizontal ? i % per : Math.floor(i / per);
			let row = horizontal ? Math.floor(i / per) : i % per;
			if (corner === "TopRight" || corner === "BottomRight") col = cols - 1 - col;
			if (corner === "BottomLeft" || corner === "BottomRight") row = rows - 1 - row;
			const s = k.scale;
			rects.push(rectFor(k, x0 + col * (cellW + padX), y0 + row * (cellH + padY), { w: cellW / s, h: cellH / s }));
		});
		return { w: gridW, h: gridH };
	}

	// ------------------------------------------------------------------ paint helpers
	function cornerRadius(n, w, h) {
		if (!n.corner) return 0;
		const u = U1(n.corner.CornerRadius ?? { s: 0, o: 8 });
		const m = Math.min(w, h);
		return clamp(u.s * m + u.o, 0, m / 2);
	}
	function sample(kps, t, key) {
		if (!kps.length) return null;
		if (t <= kps[0].t) return kps[0][key];
		for (let i = 1; i < kps.length; i++) {
			if (t <= kps[i].t) {
				const a = kps[i - 1];
				const b = kps[i];
				const f = b.t === a.t ? 1 : (t - a.t) / (b.t - a.t);
				const va = a[key];
				const vb = b[key];
				return Array.isArray(va) ? va.map((x, j) => x + (vb[j] - x) * f) : va + (vb - va) * f;
			}
		}
		return kps[kps.length - 1][key];
	}
	// UIGradient over a base colour: Roblox multiplies colours and transparencies; a product of a
	// constant with a linear ramp is still linear, so CSS stops at the keypoint times are exact.
	function gradientCss(g, baseHex, baseTransparency, where) {
		const colors = arr(g.Color).map((k) => ({ t: num(k.t), c: rgb(k.c) }));
		const trans = arr(g.Transparency).map((k) => ({ t: num(k.t), v: num(k.v) }));
		if (!colors.length) colors.push({ t: 0, c: [255, 255, 255] }, { t: 1, c: [255, 255, 255] });
		if (!trans.length) trans.push({ t: 0, v: 0 }, { t: 1, v: 0 });
		const times = [...new Set([...colors.map((k) => k.t), ...trans.map((k) => k.t), 0, 1])].sort((a, b) => a - b);
		const base = rgb(baseHex);
		const baseA = alpha(baseTransparency);
		const rot = num(g.Rotation, 0);
		const off = V2(g.Offset);
		if (((rot % 90) + 90) % 90 !== 0) warn(`${where}: UIGradient Rotation ${rot} (not a multiple of 90) is approximated by a CSS angle`);
		if (g.Type && g.Type !== "Linear") warn(`${where}: UIGradient Type ${g.Type} drawn as Linear`);
		if (g.Scale !== undefined && num(g.Scale, 1) !== 1) warn(`${where}: UIGradient Scale is not emulated`);
		const rad = (rot * Math.PI) / 180;
		const shift = off.x * Math.cos(rad) + off.y * Math.sin(rad);
		const stops = times.map((t) => {
			const c = sample(colors, t, "c");
			const a = baseA * (1 - clamp(sample(trans, t, "v"), 0, 1));
			return `${rgbaOf([(c[0] * base[0]) / 255, (c[1] * base[1]) / 255, (c[2] * base[2]) / 255], a)} ${+((t + shift) * 100).toFixed(3)}%`;
		});
		return `linear-gradient(${rot + 90}deg, ${stops.join(", ")})`;
	}
	function gradientMask(g) {
		const trans = arr(g.Transparency).map((k) => ({ t: num(k.t), v: num(k.v) }));
		if (!trans.length || trans.every((k) => k.v === 0)) return null;
		const rot = num(g.Rotation, 0);
		const off = V2(g.Offset);
		const rad = (rot * Math.PI) / 180;
		const shift = off.x * Math.cos(rad) + off.y * Math.sin(rad);
		const stops = trans.map((k) => `rgba(0,0,0,${alpha(k.v)}) ${+((k.t + shift) * 100).toFixed(3)}%`);
		return `linear-gradient(${rot + 90}deg, ${stops.join(", ")})`;
	}
	const isWhite = (hex) => String(hex || "#ffffff").toLowerCase() === "#ffffff";

	function assetUrl(image) {
		if (!image) return null;
		if (ASSETS[image]) return ASSETS[image];
		const id = (String(image).match(/(\d{3,})/) || [])[1];
		if (id && ASSETS[id]) return ASSETS[id];
		if (/^file:\/\//.test(image)) return image;
		return null;
	}
	const imageSizes = {}; // url -> natural { w, h }, filled before layout
	function collectImages(n, out) {
		if (IMAGE.has(n.cls)) {
			const url = assetUrl(String(n.p.Image || ""));
			if (url) out.add(url);
		}
		for (const k of n.kids) collectImages(k, out);
		return out;
	}
	function loadImage(url) {
		return new Promise((resolve) => {
			const im = new Image();
			im.onload = () => {
				imageSizes[url] = { w: im.naturalWidth, h: im.naturalHeight };
				resolve();
			};
			im.onerror = () => {
				warn(`asset ${url} could not be loaded`);
				resolve();
			};
			im.src = url;
		});
	}

	// ------------------------------------------------------------------ paint
	const layout = [];
	function el(cls, style) {
		const d = document.createElement("div");
		if (cls) d.className = cls;
		if (style) d.style.cssText = style;
		return d;
	}
	function label(text, extra = "") {
		const d = el("tag", extra);
		d.textContent = text;
		return d;
	}

	function paintNode(n, r, abs) {
		const p = n.p;
		const w = r.w;
		const h = r.h;
		const g = el("g");
		g.dataset.path = n.path;
		let transform = "";
		const rot = num(p.Rotation, 0);
		if (rot) transform += `translate(${px(r.vw / 2)},${px(r.vh / 2)}) rotate(${rot}deg) translate(${px(-r.vw / 2)},${px(-r.vh / 2)}) `;
		if (r.s !== 1) transform += `scale(${r.s})`;
		g.style.cssText = `left:${px(r.x)};top:${px(r.y)};width:${px(w)};height:${px(h)};${transform ? `transform:${transform};` : ""}`;
		const me = { x: abs.x + abs.s * r.x, y: abs.y + abs.s * r.y, s: abs.s * r.s };
		n.__entry = { path: n.path, class: n.cls, x: +me.x.toFixed(2), y: +me.y.toFixed(2), w: +(w * me.s).toFixed(2), h: +(h * me.s).toFixed(2), rotation: rot || undefined };
		layout.push(n.__entry);

		const radius = n.cls === "ScrollingFrame" ? 0 : cornerRadius(n, w, h);
		if (n.cls === "ScrollingFrame" && n.corner) warn(`${n.path}: UICorner does not apply to a ScrollingFrame (creator-docs) — ignored`);
		const bgT = num(p.BackgroundTransparency, 0);
		const borderStrokes = n.strokes.filter((s) => s.p.ApplyStrokeMode === "Border" || !n.text);
		const textStrokes = n.text ? n.strokes.filter((s) => s.p.ApplyStrokeMode !== "Border") : [];

		// background (+ legacy border)
		if (bgT < 1) {
			const bg = el("bg");
			let css = `border-radius:${px(radius)};`;
			const base = p.BackgroundColor3 || "#a3a2a5";
			if (n.gradient && n.cls !== "ScrollingFrame") css += `background:${gradientCss(n.gradient, base, bgT, n.path)};`;
			else css += `background:${rgba(base, bgT)};`;
			const bsp = num(p.BorderSizePixel, 0);
			if (bsp > 0 && !n.corner && !borderStrokes.length) {
				const c = rgba(p.BorderColor3 || "#1b2a35", bgT);
				const mode = p.BorderMode || "Outline";
				css +=
					mode === "Inset"
						? `box-shadow:inset 0 0 0 ${bsp}px ${c};`
						: mode === "Middle"
							? `box-shadow:0 0 0 ${bsp / 2}px ${c}, inset 0 0 0 ${bsp / 2}px ${c};`
							: `box-shadow:0 0 0 ${bsp}px ${c};`;
			}
			bg.style.cssText = css;
			g.appendChild(bg);
		}

		// image
		if (IMAGE.has(n.cls)) paintImage(n, g, w, h, radius);

		// ViewportFrame: its parts, rasterised (FL-0099 portraits)
		if (n.cls === "ViewportFrame") paintViewport(n, g, w, h, radius, me.s);

		// border strokes (outside the box by default, like Roblox; follow the corner radius)
		for (const s of borderStrokes) {
			const sp = s.p;
			let t = num(sp.Thickness, 1);
			if (sp.StrokeSizingMode === "ScaledSize") warn(`${s.where}: StrokeSizingMode ScaledSize is drawn as pixels`);
			if (t <= 0) continue;
			const position = sp.BorderStrokePosition || "Outer";
			const bo = U1(sp.BorderOffset);
			const extra = bo.s * Math.min(w, h) + bo.o;
			const e = (position === "Outer" ? t : position === "Center" ? t / 2 : 0) + extra;
			const join = sp.LineJoinMode || "Round";
			const outerR = radius > 0 ? radius + e : join === "Round" ? Math.max(0, e) : 0;
			let color = rgba(sp.Color || "#000000", sp.Transparency);
			if (s.gradient) {
				const cs = arr(s.gradient.Color);
				const mid = cs.length ? cs[Math.floor(cs.length / 2)].c : "#ffffff";
				const m = rgb(mid);
				const b = rgb(sp.Color || "#000000");
				color = rgbaOf([(m[0] * b[0]) / 255, (m[1] * b[1]) / 255, (m[2] * b[2]) / 255], alpha(sp.Transparency));
				warn(`${s.where}: UIGradient on a UIStroke is drawn as its middle colour`);
			}
			const ring = el(
				"ring",
				`left:${px(-e)};top:${px(-e)};width:${px(w + 2 * e)};height:${px(h + 2 * e)};border:${px(t)} solid ${color};border-radius:${px(outerR)};`
			);
			g.appendChild(ring);
		}

		// text
		if (n.text) paintText(n, g, w, h, textStrokes);

		// children
		const kidsBox = el("kids");
		const clips = p.ClipsDescendants === true || n.cls === "ScrollingFrame" || n.cls === "CanvasGroup";
		if (clips) {
			kidsBox.style.overflow = "hidden";
			if (n.cls === "CanvasGroup" && radius) kidsBox.style.borderRadius = px(radius);
		}
		if (n.cls === "CanvasGroup") {
			g.style.opacity = String(alpha(p.GroupTransparency));
			if (!isWhite(p.GroupColor3)) warn(`${n.path}: CanvasGroup.GroupColor3 tint is not emulated`);
		}
		const placed = placeChildren(n, w, h);
		let host = kidsBox;
		let childAbs = me;
		if (placed.canvas) {
			const c = placed.canvas;
			host = el("canvas", `left:${px(-c.x)};top:${px(-c.y)};width:${px(c.w)};height:${px(c.h)};`);
			kidsBox.appendChild(host);
			childAbs = { x: me.x - c.x * me.s, y: me.y - c.y * me.s, s: me.s };
		}
		const ordered = placed.rects
			.map((rect, i) => ({ rect, i }))
			.sort((a, b) => num(a.rect.n.p.ZIndex, 1) - num(b.rect.n.p.ZIndex, 1) || a.i - b.i);
		for (const { rect } of ordered) host.appendChild(paintNode(rect.n, rect, childAbs));
		g.appendChild(kidsBox);

		if (placed.canvas) paintScrollbars(n, g, w, h, placed.canvas);

		if (!KNOWN_GUI.has(n.cls)) {
			g.classList.add("unknown");
			g.appendChild(label(n.cls, "left:2px;top:2px"));
			warn(`${n.cls} '${n.path}' is not emulated: drawn as a plain box`);
		}
		if (OPT.debug) {
			g.classList.add("dbg");
			g.appendChild(label(n.name, "left:1px;top:1px;background:rgba(160,0,160,.75)"));
		}
		return g;
	}

	// ------------------------------------------------------------------ ViewportFrame
	// A small z-buffered rasteriser for the parts snapshot.luau records under a ViewportFrame: Block,
	// Wedge, CornerWedge, Ball and Cylinder (axis = local X), flat-shaded as a ViewportFrame lights them
	// (Ambient + LightColor × max(0, n · −LightDirection)); 3× supersampled. A Decal "Face" on a Ball is
	// drawn as a stand-in face (two eyes and a smile: the real texture is a Roblox asset). Materials,
	// specular light, shadows and textures are not emulated.
	const V = {
		sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
		dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
		cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
		norm: (a) => {
			const l = Math.hypot(a[0], a[1], a[2]) || 1;
			return [a[0] / l, a[1] / l, a[2] / l];
		},
	};
	// CFrame components { x, y, z, r00..r22 }: world = R · local + p (columns = Right, Up, -Look).
	function xform(cf, v) {
		return [
			cf[0] + cf[3] * v[0] + cf[4] * v[1] + cf[5] * v[2],
			cf[1] + cf[6] * v[0] + cf[7] * v[1] + cf[8] * v[2],
			cf[2] + cf[9] * v[0] + cf[10] * v[1] + cf[11] * v[2],
		];
	}
	// Triangles (local space, counter-clockwise seen from outside) of one part.
	function partTriangles(shape, size) {
		const [hx, hy, hz] = [size[0] / 2, size[1] / 2, size[2] / 2];
		const tris = [];
		const quad = (a, b, c, d) => tris.push([a, b, c], [a, c, d]);
		if (shape === "Ball") {
			const r = Math.min(hx, hy, hz);
			const U = 18, W = 12;
			const pt = (i, j) => {
				const th = (i / U) * Math.PI * 2, ph = (j / W) * Math.PI;
				return [r * Math.sin(ph) * Math.cos(th), r * Math.cos(ph), r * Math.sin(ph) * Math.sin(th)];
			};
			for (let i = 0; i < U; i++) for (let j = 0; j < W; j++) quad(pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1));
			return tris;
		}
		if (shape === "Cylinder") {
			const r = Math.min(hy, hz);
			const N = 20;
			const at = (i, x) => [x, r * Math.cos((i / N) * Math.PI * 2), r * Math.sin((i / N) * Math.PI * 2)];
			for (let i = 0; i < N; i++) {
				quad(at(i, -hx), at(i + 1, -hx), at(i + 1, hx), at(i, hx));
				tris.push([[hx, 0, 0], at(i, hx), at(i + 1, hx)], [[-hx, 0, 0], at(i + 1, -hx), at(i, -hx)]);
			}
			return tris;
		}
		const c = (x, y, z) => [x * hx, y * hy, z * hz];
		if (shape === "Wedge") {
			// bottom, back (+Z), slope from the top back edge to the bottom front edge, two sides
			quad(c(-1, -1, -1), c(1, -1, -1), c(1, -1, 1), c(-1, -1, 1));
			quad(c(-1, -1, 1), c(1, -1, 1), c(1, 1, 1), c(-1, 1, 1));
			quad(c(-1, -1, -1), c(-1, 1, 1), c(1, 1, 1), c(1, -1, -1));
			tris.push([c(1, -1, -1), c(1, 1, 1), c(1, -1, 1)], [c(-1, -1, -1), c(-1, -1, 1), c(-1, 1, 1)]);
			return tris;
		}
		if (shape === "CornerWedge") {
			const top = c(1, 1, -1);
			quad(c(-1, -1, -1), c(1, -1, -1), c(1, -1, 1), c(-1, -1, 1));
			tris.push([c(1, -1, -1), top, c(1, -1, 1)], [c(1, -1, 1), top, c(-1, -1, 1)], [c(-1, -1, 1), top, c(-1, -1, -1)], [c(-1, -1, -1), top, c(1, -1, -1)]);
			return tris;
		}
		// Block
		quad(c(-1, -1, -1), c(-1, 1, -1), c(1, 1, -1), c(1, -1, -1)); // front (-Z)
		quad(c(1, -1, 1), c(1, 1, 1), c(-1, 1, 1), c(-1, -1, 1)); // back
		quad(c(-1, 1, -1), c(-1, 1, 1), c(1, 1, 1), c(1, 1, -1)); // top
		quad(c(-1, -1, 1), c(-1, -1, -1), c(1, -1, -1), c(1, -1, 1)); // bottom
		quad(c(1, -1, -1), c(1, 1, -1), c(1, 1, 1), c(1, -1, 1)); // right
		quad(c(-1, -1, 1), c(-1, 1, 1), c(-1, 1, -1), c(-1, -1, -1)); // left
		return tris;
	}
	function paintViewport(n, g, w, h, radius, scale) {
		const vp = n.viewport;
		if (!vp || !vp.camera) {
			warn(`${n.path}: ViewportFrame without a camera draws nothing`);
			return;
		}
		const SS = 3 * (scale || 1);
		const W = Math.max(1, Math.round(w * SS)), H = Math.max(1, Math.round(h * SS));
		const canvas = document.createElement("canvas");
		canvas.width = W;
		canvas.height = H;
		canvas.style.cssText = `position:absolute;left:0;top:0;width:${px(w)};height:${px(h)};border-radius:${px(radius)};`;
		const ctx = canvas.getContext("2d");
		const img = ctx.createImageData(W, H);
		const zbuf = new Float32Array(W * H).fill(Infinity);
		const cam = vp.camera.cframe;
		const eye = [cam[0], cam[1], cam[2]];
		const right = [cam[3], cam[6], cam[9]], up = [cam[4], cam[7], cam[10]], back = [cam[5], cam[8], cam[11]];
		const f = 1 / Math.tan(((num(vp.camera.fov, 70) * Math.PI) / 180) / 2); // vertical FOV
		const toCam = (pw) => {
			const d = V.sub(pw, eye);
			return [V.dot(d, right), V.dot(d, up), -V.dot(d, back)]; // z = distance in front
		};
		const project = (c) => [W / 2 + ((c[0] * f) / c[2]) * (H / 2), H / 2 - ((c[1] * f) / c[2]) * (H / 2), c[2]];
		const amb = rgb(vp.ambient || "#c8c8c8"), lc = rgb(vp.lightColor || "#8c8c8c");
		const L = V.norm(arr(vp.lightDirection).length === 3 ? vp.lightDirection : [-1, -1, -1]);
		const toLight = [-L[0], -L[1], -L[2]];
		const faces = [];
		for (const part of arr(vp.parts)) {
			if (num(part.transparency, 0) >= 1) continue;
			const base = rgb(part.color || "#a3a2a5");
			for (const t of partTriangles(part.shape, part.size)) {
				const wv = t.map((v) => xform(part.cframe, v));
				const nrm = V.norm(V.cross(V.sub(wv[1], wv[0]), V.sub(wv[2], wv[0])));
				const lit = Math.max(0, V.dot(nrm, toLight));
				const col = [0, 1, 2].map((k) => Math.min(255, base[k] * ((amb[k] + lc[k] * lit) / 255)));
				faces.push({ v: wv.map(toCam), col, a: 1 - num(part.transparency, 0) });
			}
			for (const d of arr(part.decals)) if (d.name === "Face" && part.shape === "Ball") faces.push({ face: part });
		}
		const NEAR = 0.05;
		for (const fc of faces) {
			if (fc.face) continue;
			if (fc.v.some((c) => c[2] < NEAR)) continue;
			const [a, b, c] = fc.v.map(project);
			const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
			if (area === 0) continue;
			const minX = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]))), maxX = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
			const minY = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]))), maxY = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
			for (let y = minY; y <= maxY; y++) {
				for (let x = minX; x <= maxX; x++) {
					const px0 = x + 0.5, py0 = y + 0.5;
					const w0 = ((b[0] - px0) * (c[1] - py0) - (b[1] - py0) * (c[0] - px0)) / area;
					const w1 = ((c[0] - px0) * (a[1] - py0) - (c[1] - py0) * (a[0] - px0)) / area;
					const w2 = 1 - w0 - w1;
					if (w0 < 0 || w1 < 0 || w2 < 0) continue;
					const z = 1 / (w0 / a[2] + w1 / b[2] + w2 / c[2]);
					const i = y * W + x;
					if (z >= zbuf[i]) continue;
					zbuf[i] = z;
					const o = i * 4;
					img.data[o] = fc.col[0];
					img.data[o + 1] = fc.col[1];
					img.data[o + 2] = fc.col[2];
					img.data[o + 3] = Math.round(255 * fc.a);
				}
			}
		}
		ctx.putImageData(img, 0, 0);
		// Stand-in faces: eyes and a smile on the Ball's front (-Z), where they are not hidden.
		for (const fc of faces) {
			if (!fc.face) continue;
			const part = fc.face;
			const r = Math.min(...part.size) / 2;
			const mark = (lx, ly, rad) => {
				const local = [lx * r, ly * r, -Math.sqrt(Math.max(0, 1 - lx * lx - ly * ly)) * r];
				const c = toCam(xform(part.cframe, local));
				if (c[2] < NEAR) return;
				const pr = project(c);
				const xi = Math.round(pr[0]), yi = Math.round(pr[1]);
				if (xi < 0 || yi < 0 || xi >= W || yi >= H || pr[2] > zbuf[yi * W + xi] + r * 0.2) return;
				ctx.beginPath();
				ctx.arc(pr[0], pr[1], ((rad * r * f) / c[2]) * (H / 2), 0, Math.PI * 2);
				ctx.fill();
			};
			ctx.fillStyle = "rgba(38,28,24,0.9)";
			mark(-0.3, 0.18, 0.085);
			mark(0.3, 0.18, 0.085);
			for (let k = -4; k <= 4; k++) mark(k * 0.06, -0.28 + k * k * 0.006, 0.035); // a smile: dots on a curve
		}
		g.appendChild(canvas);
	}

	function paintScrollbars(n, g, w, h, c) {
		const p = n.p;
		const color = rgba(p.ScrollBarImageColor3 || "#ffffff", p.ScrollBarImageTransparency);
		const th = c.th;
		if (c.vBar) {
			const len = Math.max(th, (h * h) / c.h);
			const top = c.h > h ? ((h - len) * c.y) / (c.h - h) : 0;
			const left = p.VerticalScrollBarPosition === "Left" ? 0 : w - th;
			g.appendChild(el("bar", `left:${px(left)};top:${px(top)};width:${px(th)};height:${px(len)};background:${color};border-radius:${px(th / 2)};`));
		}
		if (c.hBar) {
			const len = Math.max(th, (w * w) / c.w);
			const left = c.w > w ? ((w - len) * c.x) / (c.w - w) : 0;
			g.appendChild(el("bar", `left:${px(left)};top:${px(h - th)};width:${px(len)};height:${px(th)};background:${color};border-radius:${px(th / 2)};`));
		}
	}

	function paintImage(n, g, w, h, radius) {
		const p = n.p;
		const image = String(p.Image || "");
		if (!image) return;
		const url = assetUrl(image);
		const imgT = num(p.ImageTransparency, 0);
		const tint = p.ImageColor3 || "#ffffff";
		const box = el("img", `border-radius:${px(radius)};opacity:${alpha(imgT)};`);
		if (!url) {
			const c = rgb(tint);
			box.classList.add("ph");
			box.style.borderColor = rgbaOf(c, 0.85);
			box.style.background = `repeating-linear-gradient(45deg, ${rgbaOf(c, 0.22)} 0 6px, ${rgbaOf(c, 0.08)} 6px 12px)`;
			const id = (image.match(/(\d{3,})/) || [])[1];
			box.style.overflow = "hidden";
			if (w >= 18 && h >= 10) box.appendChild(label(id ? `#${id}` : image.slice(0, 24), "left:50%;top:50%;transform:translate(-50%,-50%);font-size:8px;background:rgba(0,0,0,.55)"));
			g.appendChild(box);
			return;
		}
		const scaleType = p.ScaleType || "Stretch";
		const nat = imageSizes[url];
		const rectSize = V2(p.ImageRectSize);
		const rectOff = V2(p.ImageRectOffset);
		let size = "100% 100%";
		let position = "center";
		let repeat = "no-repeat";
		if (scaleType === "Fit") size = "contain";
		else if (scaleType === "Crop") size = "cover";
		else if (scaleType === "Tile") {
			const T = U2(p.TileSize ?? { xs: 1, xo: 0, ys: 1, yo: 0 });
			size = `${px(T.xs * w + T.xo)} ${px(T.ys * h + T.yo)}`;
			position = "0 0";
			repeat = "repeat";
		}
		if (rectSize.x > 0 && rectSize.y > 0 && nat) {
			const sx = w / rectSize.x;
			const sy = h / rectSize.y;
			size = `${px(nat.w * sx)} ${px(nat.h * sy)}`;
			position = `${px(-rectOff.x * sx)} ${px(-rectOff.y * sy)}`;
			if (scaleType !== "Stretch") warn(`${n.path}: ImageRectSize with ScaleType ${scaleType} drawn stretched`);
		}
		if (scaleType === "Slice" && nat) {
			const sc = obj(p.SliceCenter);
			const ss = num(p.SliceScale, 1);
			const t = num(sc.minY);
			const l = num(sc.minX);
			const b = Math.max(0, nat.h - num(sc.maxY, nat.h));
			const r = Math.max(0, nat.w - num(sc.maxX, nat.w));
			box.style.cssText += `border-style:solid;border-image-source:url("${url}");border-image-slice:${t} ${r} ${b} ${l} fill;border-image-width:${t * ss}px ${r * ss}px ${b * ss}px ${l * ss}px;`;
			if (!isWhite(tint)) warn(`${n.path}: ImageColor3 tint on a sliced image is not emulated`);
			g.appendChild(box);
			return;
		}
		let css = `background-image:url("${url}");background-size:${size};background-position:${position};background-repeat:${repeat};`;
		if (!isWhite(tint)) {
			css += `background-color:${tint};background-blend-mode:multiply;-webkit-mask-image:url("${url}");-webkit-mask-size:${size};-webkit-mask-position:${position};-webkit-mask-repeat:${repeat};`;
		}
		if (n.gradient) {
			const m = gradientMask(n.gradient);
			if (m) warn(`${n.path}: UIGradient transparency on an image is not emulated`);
			const c = arr(n.gradient.Color);
			if (c.some((k) => !isWhite(k.c))) warn(`${n.path}: UIGradient colour on an image is not emulated`);
		}
		box.style.cssText += css;
		g.appendChild(box);
	}

	function fitTextSize(n, cw, ch) {
		const t = n.text;
		let lo = 1;
		let hi = 100;
		if (n.textC) {
			lo = Math.max(1, num(n.textC.MinTextSize, 1));
			hi = Math.max(lo, Math.min(100, num(n.textC.MaxTextSize, 100)));
		}
		const fits = (s) => {
			const m = measure(t, s, cw);
			return m.h <= ch + 0.5 && m.scrollW <= cw + 0.5;
		};
		if (!fits(lo)) return lo;
		while (lo < hi) {
			const mid = Math.ceil((lo + hi) / 2);
			if (fits(mid)) lo = mid;
			else hi = mid - 1;
		}
		return lo;
	}

	function paintText(n, g, w, h, textStrokes) {
		const t = n.text;
		if (!t.html.length) return;
		const pad = padOf(n, w, h);
		const cw = Math.max(0, w - pad.l - pad.r);
		const ch = Math.max(0, h - pad.t - pad.b);
		const size = t.scaled ? fitTextSize(n, cw, ch) : t.size;
		const lineH = size * t.lineFactor;
		// the phone-fit audit (layout.json `clipped`): the text is wider (one line) or taller (wrapped) than its box,
		// so Roblox cuts it or (TextTruncate) ends it with "…"
		if (n.__entry && !t.scaled) {
			const m = measure(t, size, t.wrapped ? cw : null);
			if ((!t.wrapped && m.w > cw + 1) || (t.wrapped && m.h > ch + 1)) n.__entry.clipped = true;
		}
		const box = el(
			"txt",
			`padding:${px(pad.t)} ${px(pad.r)} ${px(pad.b)} ${px(pad.l)};justify-content:${t.ya === "Top" ? "flex-start" : t.ya === "Bottom" ? "flex-end" : "center"};` +
				`align-items:${t.xa === "Left" ? "flex-start" : t.xa === "Right" ? "flex-end" : "center"};`
		);
		const span = document.createElement("span");
		let css =
			`font-family:${t.font.stack};font-weight:${t.font.weight};font-style:${t.font.style};font-size:${size}px;line-height:${lineH}px;` +
			`text-align:${t.xa === "Left" ? "left" : t.xa === "Right" ? "right" : "center"};`;
		if (t.wrapped) {
			const maxLines = Math.max(1, Math.floor(ch / lineH + 1e-3));
			css += `white-space:pre-wrap;overflow-wrap:break-word;width:${px(cw)};`;
			if (t.truncate) css += `display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:${maxLines};overflow:hidden;`;
			else css += `max-height:${px(maxLines * lineH)};overflow:hidden;`;
		} else {
			css += "white-space:pre;";
			if (t.truncate) css += `max-width:${px(cw)};overflow:hidden;text-overflow:ellipsis;`;
		}
		const textA = alpha(t.transparency);
		if (n.gradient) {
			box.style.background = gradientCss(n.gradient, t.color, t.transparency, n.path);
			box.style.webkitBackgroundClip = "text";
			box.style.backgroundClip = "text";
			css += "color:transparent;-webkit-text-fill-color:transparent;";
		} else {
			css += `color:${rgba(t.color, t.transparency)};`;
		}
		const shadows = [];
		const legacyT = num(n.p.TextStrokeTransparency, 1);
		if (legacyT < 1) {
			const c = rgbaOf(rgb(n.p.TextStrokeColor3 || "#000000"), alpha(legacyT) * textA);
			for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]) shadows.push(`${dx}px ${dy}px 0 ${c}`);
		}
		if (shadows.length) css += `text-shadow:${shadows.join(",")};`;
		if (textStrokes.length) {
			const s = textStrokes[0].p;
			const th = num(s.Thickness, 1);
			css += `-webkit-text-stroke:${px(th * 2)} ${rgbaOf(rgb(s.Color || "#000000"), alpha(s.Transparency) * textA)};paint-order:stroke fill;`;
			if (textStrokes.length > 1) warn(`${n.path}: only the first text UIStroke is drawn`);
		}
		span.style.cssText = css;
		span.innerHTML = t.html;
		box.appendChild(span);
		g.appendChild(box);
	}

	// ------------------------------------------------------------------ screen + layers
	function insetRect(mode) {
		const d = DEV;
		const i = d.inset;
		const coreTop = Math.max(i.top, d.topbar);
		switch (mode) {
			case "None":
				return { x: 0, y: 0, w: d.width, h: d.height };
			case "DeviceSafeInsets":
				return { x: i.left, y: i.top, w: d.width - i.left - i.right, h: d.height - i.top - i.bottom };
			case "TopbarSafeInsets":
				return { x: i.left + d.controls, y: i.top, w: d.width - i.left - i.right - d.controls, h: Math.max(0, d.topbar - i.top) };
			default:
				return { x: i.left, y: coreTop, w: d.width - i.left - i.right, h: d.height - coreTop - i.bottom };
		}
	}

	function paintLayer(n, vp) {
		const p = n.p;
		let mode = p.ScreenInsets || "CoreUISafeInsets";
		if (p.IgnoreGuiInset === true && mode === "CoreUISafeInsets") {
			mode = "DeviceSafeInsets";
			warn(`${n.path}: IgnoreGuiInset=true with ScreenInsets=CoreUISafeInsets -> DeviceSafeInsets (the engine couples the two properties)`);
		}
		const anyZ = (k) => num(k.p.ZIndex, 1) !== 1 || k.kids.some(anyZ);
		if (p.ZIndexBehavior === "Global" && n.kids.some(anyZ)) warn(`${n.path}: ZIndexBehavior is Global (Lune's default when unset; Roblox's default is Sibling) — drawn with Sibling rules`);
		const rect = insetRect(mode);
		const d = DEV;
		const i = d.inset;
		const clipSafe = p.ClipToDeviceSafeArea !== false && mode !== "None";
		const outer = clipSafe
			? el("lyr", `left:${i.left}px;top:${i.top}px;width:${d.width - i.left - i.right}px;height:${d.height - i.top - i.bottom}px;overflow:hidden;`)
			: el("lyr", "left:0;top:0;width:100%;height:100%;");
		const ox = clipSafe ? i.left : 0;
		const oy = clipSafe ? i.top : 0;
		const layer = el("lyr", `left:${rect.x - ox}px;top:${rect.y - oy}px;width:${rect.w}px;height:${rect.h}px;`);
		layer.dataset.path = n.path;
		layer.dataset.insets = mode;
		const s = n.scale;
		const host = s !== 1 ? el("lyr", `left:0;top:0;width:${rect.w}px;height:${rect.h}px;transform:scale(${s});transform-origin:0 0;`) : layer;
		if (s !== 1) {
			layer.appendChild(host);
			warn(`${n.path}: UIScale directly under a ScreenGui is drawn as a scale of the whole layer from its top-left (unverified)`);
		}
		if (n.padding) warn(`${n.path}: UIPadding directly under a ScreenGui is applied (engine behaviour unverified)`);
		const placed = placeChildren(n, rect.w, rect.h);
		const abs = { x: rect.x, y: rect.y, s };
		layout.push({ path: n.path, class: n.cls, x: rect.x, y: rect.y, w: rect.w, h: rect.h, insets: mode, displayOrder: num(p.DisplayOrder) });
		const ordered = placed.rects.map((r, k) => ({ r, k })).sort((a, b) => num(a.r.n.p.ZIndex, 1) - num(b.r.n.p.ZIndex, 1) || a.k - b.k);
		for (const { r } of ordered) host.appendChild(paintNode(r.n, r, abs));
		if (OPT.debug) layer.appendChild(label(`${n.name} · ${mode} · DisplayOrder ${num(p.DisplayOrder)}`, "right:2px;bottom:2px;background:rgba(0,90,200,.8)"));
		outer.appendChild(layer);
		vp.appendChild(outer);
	}

	function backdrop(w, h) {
		if (OPT.backdrop === "plain") return `<div style="position:absolute;inset:0;background:linear-gradient(180deg,#6f7783,#4a515c)"></div>`;
		return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="position:absolute;left:0;top:0">
			<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FB0D9"/><stop offset="1" stop-color="#D7E3D0"/></linearGradient></defs>
			<rect width="${w}" height="${h}" fill="url(#sky)"/>
			<path d="M0 ${h * 0.34} Q ${w * 0.2} ${h * 0.22} ${w * 0.4} ${h * 0.32} T ${w * 0.8} ${h * 0.28} T ${w} ${h * 0.3} V ${h} H 0 Z" fill="#8FAE7A"/>
			<path d="M0 ${h * 0.42} Q ${w * 0.25} ${h * 0.36} ${w * 0.5} ${h * 0.44} T ${w} ${h * 0.4} V ${h} H 0 Z" fill="#6E9A4E"/>
			<path d="M${w * 0.62} ${h * 0.42} C ${w * 0.5} ${h * 0.6} ${w * 0.75} ${h * 0.72} ${w * 0.6} ${h}" stroke="#5C9BC7" stroke-width="${h * 0.035}" fill="none" opacity="0.9"/>
		</svg>`;
	}

	async function run() {
		const vp = document.getElementById("vp");
		vp.style.width = `${DEV.width}px`;
		vp.style.height = `${DEV.height}px`;
		vp.innerHTML = backdrop(DEV.width, DEV.height);
		document.body.appendChild(measurer);

		const layers = arr(SNAP.guis).map((g) => prep(g, null, false));
		const urls = new Set();
		for (const n of layers) collectImages(n, urls);
		await Promise.all([...urls].map(loadImage));
		await Promise.all([...usedFonts.keys()].map((f) => document.fonts.load(f).catch(() => null)));
		await document.fonts.ready;

		const order = layers
			.map((n, i) => ({ n, i }))
			.filter(({ n }) => {
				if (n.cls !== "ScreenGui") {
					warn(`${n.cls} '${n.path}' is not a ScreenGui: not drawn`);
					return false;
				}
				return n.p.Enabled !== false;
			})
			.sort((a, b) => num(a.n.p.DisplayOrder) - num(b.n.p.DisplayOrder) || a.i - b.i);
		for (const { n } of order) paintLayer(n, vp);

		// Roblox's own top-bar buttons (CoreGui, drawn above every ScreenGui), as in the HTML prototypes.
		const i = DEV.inset;
		vp.insertAdjacentHTML(
			"beforeend",
			`<div class="robloxbtn" style="left:${i.left + 12}px;top:${i.top + 7}px">R</div><div class="robloxbtn" style="left:${i.left + 60}px;top:${i.top + 7}px">≡</div>`
		);
		if (OPT.guides) {
			const d = DEV;
			vp.insertAdjacentHTML(
				"beforeend",
				`<div class="guides">
				<div class="band" style="left:0;top:0;width:${i.left}px;height:${d.height}px"><span>${i.left ? "notch" : ""}</span></div>
				<div class="band" style="right:0;top:0;width:${i.right}px;height:${d.height}px"></div>
				<div class="band" style="left:0;bottom:0;width:${d.width}px;height:${i.bottom}px"></div>
				<div class="band topbar" style="left:${i.left}px;top:${i.top}px;width:${d.width - i.left - i.right}px;height:${Math.max(0, d.topbar - i.top)}px"><span>Roblox top bar (TopbarSafeInsets = right of the controls)</span></div></div>`
			);
		}
		const errors = arr(SNAP.errors);
		if (errors.length) {
			const b = el("errbanner");
			b.textContent = `snapshot reported ${errors.length} error(s): ${String(errors[0]).split("\n")[0].slice(0, 200)}`;
			vp.appendChild(b);
		}
		if (OPT.debug && warnings.length) {
			const b = el("warnlist");
			b.textContent = warnings.join("\n");
			vp.appendChild(b);
		}
		measurer.remove();
		window.__layout = layout;
		window.__warnings = warnings;
		window.__done = true;
	}
	run().catch((e) => {
		window.__error = String((e && e.stack) || e);
		window.__done = true;
	});
})();
