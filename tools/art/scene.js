// Shared cartoon pieces for the Moonlit Grove thumbnail and icon (rendered to PNG with Edge headless).
const NS = "http://www.w3.org/2000/svg";
function el(tag, attrs, parent) {
	const e = document.createElementNS(NS, tag);
	for (const k in attrs) e.setAttribute(k, attrs[k]);
	if (parent) parent.appendChild(e);
	return e;
}
// deterministic random
let seed = 7;
function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; }

function defs(svg) {
	const d = el("defs", {}, svg);
	d.innerHTML = `
	<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
		<stop offset="0" stop-color="#0a1238"/><stop offset="0.55" stop-color="#233a8a"/><stop offset="1" stop-color="#6a4ea8"/>
	</linearGradient>
	<radialGradient id="moonGlow"><stop offset="0" stop-color="#fff6c8" stop-opacity="0.9"/><stop offset="0.35" stop-color="#ffe38a" stop-opacity="0.35"/><stop offset="1" stop-color="#ffe38a" stop-opacity="0"/></radialGradient>
	<radialGradient id="moon" cx="0.4" cy="0.35"><stop offset="0" stop-color="#fffbe6"/><stop offset="1" stop-color="#ffd86b"/></radialGradient>
	<linearGradient id="hillBack" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d5a6e"/><stop offset="1" stop-color="#1c3b4c"/></linearGradient>
	<linearGradient id="grass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4fae4a"/><stop offset="1" stop-color="#2a6f35"/></linearGradient>
	<linearGradient id="soil" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a5a36"/><stop offset="1" stop-color="#5e3a22"/></linearGradient>
	<radialGradient id="glowWarm"><stop offset="0" stop-color="#ffd27a" stop-opacity="0.9"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient>
	<radialGradient id="glowBlue"><stop offset="0" stop-color="#9fe8ff" stop-opacity="0.95"/><stop offset="1" stop-color="#9fe8ff" stop-opacity="0"/></radialGradient>
	<radialGradient id="glowPink"><stop offset="0" stop-color="#ff9fe0" stop-opacity="0.95"/><stop offset="1" stop-color="#ff9fe0" stop-opacity="0"/></radialGradient>
	<radialGradient id="glowGold"><stop offset="0" stop-color="#fff2a0" stop-opacity="0.95"/><stop offset="1" stop-color="#fff2a0" stop-opacity="0"/></radialGradient>
	<radialGradient id="monster" cx="0.4" cy="0.3"><stop offset="0" stop-color="#b47cff"/><stop offset="1" stop-color="#6b36c8"/></radialGradient>
	<radialGradient id="bunny" cx="0.4" cy="0.3"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#dfe6ff"/></radialGradient>
	<linearGradient id="title" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff7c2"/><stop offset="0.5" stop-color="#ffd64a"/><stop offset="1" stop-color="#ff9d1f"/></linearGradient>
	<filter id="soft"><feGaussianBlur stdDeviation="6"/></filter>`;
}

function stars(svg, w, h, count) {
	for (let i = 0; i < count; i++) {
		const r = rnd() * 2.6 + 0.8;
		el("circle", { cx: rnd() * w, cy: rnd() * h, r, fill: "#fff", opacity: 0.5 + rnd() * 0.5 }, svg);
	}
}

function moon(svg, x, y, r) {
	el("circle", { cx: x, cy: y, r: r * 3, fill: "url(#moonGlow)" }, svg);
	el("circle", { cx: x, cy: y, r, fill: "url(#moon)" }, svg);
	el("circle", { cx: x - r * 0.3, cy: y + r * 0.2, r: r * 0.16, fill: "#f2c75a", opacity: 0.5 }, svg);
	el("circle", { cx: x + r * 0.35, cy: y - r * 0.25, r: r * 0.1, fill: "#f2c75a", opacity: 0.5 }, svg);
}

function tree(svg, x, y, s, color) {
	el("rect", { x: x - 6 * s, y: y - 60 * s, width: 12 * s, height: 60 * s, rx: 4 * s, fill: "#3b2a22" }, svg);
	el("circle", { cx: x, cy: y - 80 * s, r: 42 * s, fill: color }, svg);
	el("circle", { cx: x - 30 * s, cy: y - 60 * s, r: 30 * s, fill: color }, svg);
	el("circle", { cx: x + 30 * s, cy: y - 62 * s, r: 32 * s, fill: color }, svg);
}

function pine(svg, x, y, s, color) {
	el("rect", { x: x - 5 * s, y: y - 30 * s, width: 10 * s, height: 30 * s, fill: "#3b2a22" }, svg);
	for (let i = 0; i < 3; i++) {
		const w = (70 - i * 18) * s, top = y - (40 + i * 38) * s;
		el("polygon", { points: `${x - w},${top + 55 * s} ${x + w},${top + 55 * s} ${x},${top - 20 * s}`, fill: color }, svg);
	}
}

function fence(svg, x0, x1, y, s) {
	const g = el("g", { stroke: "#2a1d18", "stroke-width": 4 * s, "stroke-linejoin": "round" }, svg);
	el("rect", { x: x0, y: y - 46 * s, width: x1 - x0, height: 10 * s, rx: 4 * s, fill: "#f3ead8" }, g);
	el("rect", { x: x0, y: y - 22 * s, width: x1 - x0, height: 10 * s, rx: 4 * s, fill: "#f3ead8" }, g);
	for (let x = x0 + 10 * s; x < x1; x += 34 * s) {
		el("polygon", { points: `${x},${y} ${x + 20 * s},${y} ${x + 20 * s},${y - 62 * s} ${x + 10 * s},${y - 76 * s} ${x},${y - 62 * s}`, fill: "#fbf4e4" }, g);
	}
}

function cottage(svg, x, y, s) {
	const g = el("g", { stroke: "#2a1d18", "stroke-width": 5 * s, "stroke-linejoin": "round" }, svg);
	el("rect", { x: x - 120 * s, y: y - 150 * s, width: 240 * s, height: 150 * s, rx: 8 * s, fill: "#f5e6c4" }, g);
	el("polygon", { points: `${x - 150 * s},${y - 140 * s} ${x},${y - 270 * s} ${x + 150 * s},${y - 140 * s}`, fill: "#d9524a" }, g);
	el("rect", { x: x + 50 * s, y: y - 260 * s, width: 30 * s, height: 70 * s, fill: "#9c5a4a" }, g);
	el("rect", { x: x - 25 * s, y: y - 95 * s, width: 50 * s, height: 95 * s, rx: 6 * s, fill: "#7a4a2c" }, g);
	for (const wx of [-85, 50]) {
		el("circle", { cx: x + (wx + 17) * s, cy: y - 92 * s, r: 55 * s, fill: "url(#glowWarm)", stroke: "none" }, svg);
		el("rect", { x: x + wx * s, y: y - 115 * s, width: 36 * s, height: 36 * s, rx: 4 * s, fill: "#ffd977" }, g);
	}
}

function cropRow(svg, x, y, s, count, glow, fruit) {
	el("rect", { x: x, y: y, width: count * 70 * s, height: 34 * s, rx: 14 * s, fill: "url(#soil)", stroke: "#2a1d18", "stroke-width": 4 * s }, svg);
	for (let i = 0; i < count; i++) {
		const cx = x + (35 + i * 70) * s, cy = y + 4 * s;
		el("circle", { cx, cy: cy - 30 * s, r: 40 * s, fill: `url(#${glow})` }, svg);
		el("path", { d: `M${cx} ${cy} q-4 ${-22 * s} 0 ${-34 * s}`, stroke: "#2f7d2f", "stroke-width": 6 * s, fill: "none" }, svg);
		el("ellipse", { cx: cx - 12 * s, cy: cy - 18 * s, rx: 13 * s, ry: 7 * s, fill: "#4fb34a", stroke: "#1f4d22", "stroke-width": 3 * s }, svg);
		el("ellipse", { cx: cx + 12 * s, cy: cy - 22 * s, rx: 13 * s, ry: 7 * s, fill: "#4fb34a", stroke: "#1f4d22", "stroke-width": 3 * s }, svg);
		el("circle", { cx, cy: cy - 40 * s, r: 15 * s, fill: fruit, stroke: "#2a1d18", "stroke-width": 4 * s }, svg);
		el("circle", { cx: cx - 5 * s, cy: cy - 45 * s, r: 4 * s, fill: "#fff", opacity: 0.8 }, svg);
	}
}

function lantern(svg, x, y, s) {
	el("circle", { cx: x, cy: y - 120 * s, r: 90 * s, fill: "url(#glowWarm)" }, svg);
	el("rect", { x: x - 5 * s, y: y - 120 * s, width: 10 * s, height: 120 * s, fill: "#2b2b35" }, svg);
	el("rect", { x: x - 16 * s, y: y - 150 * s, width: 32 * s, height: 36 * s, rx: 6 * s, fill: "#ffe08a", stroke: "#2b2b35", "stroke-width": 5 * s }, svg);
}

function bunny(svg, x, y, s) {
	const g = el("g", { stroke: "#2a1d18", "stroke-width": 6 * s, "stroke-linejoin": "round" }, svg);
	el("circle", { cx: x, cy: y - 110 * s, r: 150 * s, fill: "url(#glowBlue)", stroke: "none" }, svg);
	el("ellipse", { cx: x, cy: y - 8 * s, rx: 80 * s, ry: 14 * s, fill: "#000", opacity: 0.25, stroke: "none" }, svg);
	// ears
	for (const sx of [-1, 1]) {
		el("ellipse", { cx: x + sx * 32 * s, cy: y - 215 * s, rx: 22 * s, ry: 62 * s, fill: "url(#bunny)", transform: `rotate(${sx * 12} ${x + sx * 32 * s} ${y - 215 * s})` }, g);
		el("ellipse", { cx: x + sx * 32 * s, cy: y - 210 * s, rx: 10 * s, ry: 42 * s, fill: "#ffb3c9", stroke: "none", transform: `rotate(${sx * 12} ${x + sx * 32 * s} ${y - 210 * s})` }, svg);
	}
	el("ellipse", { cx: x, cy: y - 60 * s, rx: 78 * s, ry: 62 * s, fill: "url(#bunny)" }, g);
	el("circle", { cx: x, cy: y - 135 * s, r: 66 * s, fill: "url(#bunny)" }, g);
	// face
	for (const sx of [-1, 1]) {
		el("ellipse", { cx: x + sx * 24 * s, cy: y - 140 * s, rx: 11 * s, ry: 15 * s, fill: "#1b1530", stroke: "none" }, svg);
		el("circle", { cx: x + sx * 24 * s - 4 * s, cy: y - 146 * s, r: 4.5 * s, fill: "#fff", stroke: "none" }, svg);
		el("ellipse", { cx: x + sx * 44 * s, cy: y - 115 * s, rx: 13 * s, ry: 8 * s, fill: "#ff9fbf", opacity: 0.8, stroke: "none" }, svg);
	}
	el("path", { d: `M${x - 9 * s} ${y - 118 * s} q${9 * s} ${10 * s} ${18 * s} 0`, fill: "none", stroke: "#2a1d18", "stroke-width": 5 * s }, svg);
	el("ellipse", { cx: x, cy: y - 124 * s, rx: 7 * s, ry: 5 * s, fill: "#ff7aa8", stroke: "none" }, svg);
	// sparkles (mutation glow)
	for (const [dx, dy, r] of [[-110, -200, 14], [105, -185, 10], [95, -60, 8], [-100, -70, 9]]) {
		el("path", { d: `M${x + dx * s} ${y + (dy - r) * s} L${x + (dx + r * 0.3) * s} ${y + (dy - r * 0.3) * s} L${x + (dx + r) * s} ${y + dy * s} L${x + (dx + r * 0.3) * s} ${y + (dy + r * 0.3) * s} L${x + dx * s} ${y + (dy + r) * s} L${x + (dx - r * 0.3) * s} ${y + (dy + r * 0.3) * s} L${x + (dx - r) * s} ${y + dy * s} L${x + (dx - r * 0.3) * s} ${y + (dy - r * 0.3) * s}Z`, fill: "#fffbe0" }, svg);
	}
}

function monster(svg, x, y, s) {
	const g = el("g", { stroke: "#1a0f2e", "stroke-width": 6 * s, "stroke-linejoin": "round" }, svg);
	el("circle", { cx: x, cy: y - 90 * s, r: 140 * s, fill: "url(#glowPink)", opacity: 0.55, stroke: "none" }, svg);
	// horns
	for (const sx of [-1, 1]) {
		el("path", { d: `M${x + sx * 40 * s} ${y - 150 * s} q${sx * 10 * s} ${-50 * s} ${sx * 45 * s} ${-60 * s} q${-sx * 5 * s} ${35 * s} ${-sx * 15 * s} ${60 * s}Z`, fill: "#ffe9b0" }, g);
	}
	el("path", { d: `M${x - 95 * s} ${y} q0 ${-170 * s} ${95 * s} ${-170 * s} q${95 * s} 0 ${95 * s} ${170 * s} q${-25 * s} ${-14 * s} ${-48 * s} 0 q${-23 * s} ${-14 * s} ${-47 * s} 0 q${-24 * s} ${-14 * s} ${-47 * s} 0 q${-24 * s} ${-14 * s} ${-48 * s} 0Z`, fill: "url(#monster)" }, g);
	for (const sx of [-1, 1]) {
		el("circle", { cx: x + sx * 32 * s, cy: y - 100 * s, r: 24 * s, fill: "url(#glowGold)", stroke: "none" }, svg);
		el("ellipse", { cx: x + sx * 32 * s, cy: y - 100 * s, rx: 17 * s, ry: 20 * s, fill: "#fff3a6" }, g);
		el("ellipse", { cx: x + sx * 30 * s, cy: y - 96 * s, rx: 7 * s, ry: 11 * s, fill: "#1a0f2e", stroke: "none" }, svg);
	}
	el("path", { d: `M${x - 34 * s} ${y - 55 * s} q${34 * s} ${26 * s} ${68 * s} 0`, fill: "#3a1460" }, g);
	el("polygon", { points: `${x - 22 * s},${y - 50 * s} ${x - 14 * s},${y - 36 * s} ${x - 6 * s},${y - 47 * s}`, fill: "#fff", stroke: "none" }, svg);
	el("polygon", { points: `${x + 22 * s},${y - 50 * s} ${x + 14 * s},${y - 36 * s} ${x + 6 * s},${y - 47 * s}`, fill: "#fff", stroke: "none" }, svg);
}

function title(svg, x, y, size, text) {
	const t = el("text", {
		x, y, "text-anchor": "middle", "font-family": "'Segoe UI Black','Arial Black',sans-serif", "font-weight": 900,
		"font-size": size, fill: "url(#title)", stroke: "#2a1050", "stroke-width": size * 0.12, "paint-order": "stroke",
		"stroke-linejoin": "round", "letter-spacing": size * 0.02,
	}, svg);
	t.textContent = text;
	return t;
}
